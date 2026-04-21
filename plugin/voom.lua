-- Guard against double-loading, following Neovim plugin conventions.
if vim.g.loaded_voom then
  return
end
vim.g.loaded_voom = true

-- Defer requiring the module until a command is actually invoked,
-- keeping startup time impact at zero.
vim.api.nvim_create_user_command("Voom", function(opts)
  require("voom").init(opts.args)
end, {
  nargs = "?",
  complete = function(arglead, _, _)
    return require("voom").complete(arglead)
  end,
})

vim.api.nvim_create_user_command("VoomToggle", function(opts)
  require("voom").toggle(opts.args)
end, { nargs = "?" })

vim.api.nvim_create_user_command("Voomhelp", function()
  require("voom").help()
end, {})

vim.api.nvim_create_user_command("Voomlog", function()
  require("voom").log_init()
end, {})

vim.api.nvim_create_user_command("VoomGrep", function(opts)
  require("voom").grep(opts.args)
end, { nargs = 1 })

vim.api.nvim_create_user_command("Voominfo", function()
  require("voom").voominfo()
end, {})

vim.api.nvim_create_user_command("VoomSort", function(opts)
  require("voom.oop").sort(vim.api.nvim_get_current_buf(), opts.args)
end, { nargs = "?" })

-- ==============================================================================
-- Auto-open / auto-close
-- ==============================================================================
--
-- Both callbacks are cheap when their flag is off — a single config table
-- lookup and early return.  They're gated on the `auto_open` / `auto_close`
-- config fields respectively, both of which default to false, so users who
-- never opt in pay no runtime cost beyond registration.

local voom_augroup = vim.api.nvim_create_augroup("voom_auto", { clear = true })

-- Shared filter: given a flag value (true or table of mode names) and a
-- resolved mode name, return true if the flag enables this mode.
local function mode_allowed(flag, mode)
  if flag == true then
    return true
  end
  if type(flag) == "table" then
    for _, m in ipairs(flag) do
      if m == mode then
        return true
      end
    end
  end
  return false
end

-- `BufWinEnter` fires on every display-in-window (first load, :edit of an
-- already-loaded buffer, hidden-buffer re-display, netrw selection), which
-- matches the "open the tree whenever a matching body becomes visible"
-- semantics.  `FileType` would miss the netrw round-trip case entirely —
-- filetype is already set on the re-displayed buffer, so FileType does not
-- re-fire, and the tree would stay closed after the user returns.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = voom_augroup,
  callback = function(args)
    local config = require("voom.config")
    local auto_open = config.options.auto_open
    if not auto_open then
      return
    end

    local mode = require("voom.modes").resolve_filetype(vim.bo[args.buf].filetype)
    if not mode then
      return
    end
    if not mode_allowed(auto_open, mode) then
      return
    end

    -- Defer so we don't open a new split inside another buffer's
    -- BufWinEnter dispatch; gives Neovim a chance to finish settling
    -- window state before voom creates its tree split.
    local body_buf = args.buf
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(body_buf) then
        require("voom").init(mode)
      end
    end)
  end,
})

-- `auto_close` is bidirectional: either pane leaving its window tears down
-- the whole voom pair.
--   * body leaves → close the tree's window.
--   * tree leaves → close the body's window.
-- We close the *other pane's window* (rather than merely wiping the other
-- pane's buffer) for two reasons:
--
--   1. If we only wipe the tree buffer when the body leaves, Neovim
--      needs to pick a new buffer for the still-open tree window and
--      reaches for the just-hidden body — visible to the user as a
--      flicker where the body appears to come back.
--   2. If we only try nvim_win_close(body_win, false) when the tree
--      leaves, and the body is the last window in the last tab,
--      Neovim refuses (E444); the pair ends up half-dead.
--
-- Running `:quit` inside the target window via nvim_win_call handles both
-- cases correctly: it closes the window when there's somewhere to fall
-- back to, exits Neovim when it was the last window (which is what the
-- user asked for by dismissing the pair), and raises E37 rather than
-- discarding unsaved body changes.
--
-- State is unregistered *synchronously* (before the scheduled callback)
-- so the window-close cascade inside the scheduled tick doesn't re-enter
-- this handler with stale is_body / is_tree truths.
--
-- The mode filter, when `auto_close` is a table, is always matched
-- against the body's registered mode, so both directions share one rule.
vim.api.nvim_create_autocmd("BufWinLeave", {
  group = voom_augroup,
  callback = function(args)
    local config = require("voom.config")
    local auto_close = config.options.auto_close
    if not auto_close then
      return
    end

    local state = require("voom.state")
    local leaving_is_body = state.is_body(args.buf)
    local body_buf
    if leaving_is_body then
      body_buf = args.buf
    elseif state.is_tree(args.buf) then
      body_buf = state.get_body(args.buf)
    else
      return
    end
    if not body_buf then
      return
    end

    if type(auto_close) == "table"
       and not mode_allowed(auto_close, state.get_mode(body_buf)) then
      return
    end

    local tree_buf = state.get_tree(body_buf)
    local target_buf = leaving_is_body and tree_buf or body_buf

    -- Snapshot the windows to close before deferring — the window list
    -- can shift during the `args.buf` teardown that's already in flight.
    local target_wins = {}
    if target_buf then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win)
           and vim.api.nvim_win_get_buf(win) == target_buf then
          table.insert(target_wins, win)
        end
      end
    end

    -- Pull the plug on voom state right now so the `:quit` cascade below
    -- doesn't re-trigger this handler with `is_body` / `is_tree` still
    -- returning true.  The tree buffer itself is still wiped, but we do
    -- it manually on the next tick to avoid E937 ("buffer in use")
    -- inside the event dispatch.
    state.unregister(body_buf)

    vim.schedule(function()
      for _, win in ipairs(target_wins) do
        if vim.api.nvim_win_is_valid(win) then
          pcall(function()
            vim.api.nvim_win_call(win, function()
              vim.cmd("quit")
            end)
          end)
        end
      end
      if tree_buf and vim.api.nvim_buf_is_valid(tree_buf) then
        pcall(vim.api.nvim_buf_delete, tree_buf, { force = true })
      end
    end)
  end,
})
