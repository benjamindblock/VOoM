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
--   * body leaves → close its tree (the original scenario — `:q` on the
--     body, fzf replacing the buffer, `-` to netrw).
--   * tree leaves → close the tree AND the body's window (same three
--     scenarios, invoked from the tree side).
-- The mode filter, when `auto_close` is a table, is always applied to the
-- body's registered mode, so both directions share one filter.
vim.api.nvim_create_autocmd("BufWinLeave", {
  group = voom_augroup,
  callback = function(args)
    local config = require("voom.config")
    local auto_close = config.options.auto_close
    if not auto_close then
      return
    end

    local state = require("voom.state")

    local body_buf, close_body_windows
    if state.is_body(args.buf) then
      body_buf = args.buf
      close_body_windows = false
    elseif state.is_tree(args.buf) then
      body_buf = state.get_body(args.buf)
      close_body_windows = true
    else
      return
    end
    if not body_buf then
      return
    end

    -- Per-mode filtering when auto_close is a table.
    if type(auto_close) == "table"
       and not mode_allowed(auto_close, state.get_mode(body_buf)) then
      return
    end

    -- When we're closing from the tree side, snapshot the body's windows
    -- now.  voom.close will wipe the tree buffer on the next tick, which
    -- can cascade window changes we'd rather isolate from this list.
    local body_wins = {}
    if close_body_windows then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win)
           and vim.api.nvim_win_get_buf(win) == body_buf then
          table.insert(body_wins, win)
        end
      end
    end

    vim.schedule(function()
      require("voom").close(body_buf)
      -- `force = false` — if the body has unsaved changes, skip the
      -- window close rather than discard the user's work.  They can
      -- save and close it themselves; we've already torn down the tree.
      for _, win in ipairs(body_wins) do
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_close, win, false)
        end
      end
    end)
  end,
})
