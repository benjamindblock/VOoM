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
-- Auto-open / auto-close / unified horizontal splits
-- ==============================================================================
--
-- All three callbacks are cheap when their flag is off — a single config
-- table lookup and early return.  They're gated on the `auto_open`,
-- `auto_close`, and `unified_horizontal_splits` config fields
-- respectively; the first two default to false, the third to true (it
-- corrects an otherwise-broken layout that users almost never want).
-- Users who never opt in to the first two pay no runtime cost beyond
-- registration.

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

    if type(auto_close) == "table" and not mode_allowed(auto_close, state.get_mode(body_buf)) then
      return
    end

    local tree_buf = state.get_tree(body_buf)
    local target_buf = leaving_is_body and tree_buf or body_buf

    -- Snapshot the windows to close before deferring — the window list
    -- can shift during the `args.buf` teardown that's already in flight.
    local target_wins = {}
    if target_buf then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
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

-- ==============================================================================
-- Unified horizontal splits
-- ==============================================================================
--
-- Default `:split` inside an active voom session produces a layout that
-- almost no user actually wants:
--
--   before:  {row, [{leaf, tree}, {leaf, body}]}
--   :sp in body →
--            {row, [{leaf, tree}, {col, [{leaf, new}, {leaf, body}]}]}
--
-- The tree-side and body-side rows are now out of sync: body is half
-- height while tree keeps its full height, and `:sp` issued from the
-- *tree* side leaves the user staring at two duplicate tree windows.
--
-- We intercept `WinNew`, locate the new window's parent in
-- `vim.fn.winlayout()`, and — if that parent is a `"col"` (horizontal
-- split) sharing a sibling with the tree or body pane — run
-- `wincmd K` / `wincmd J` to lift the new window to a full-width
-- sibling above or below the entire tree+body row.  The choice
-- between K and J honors where the user's split actually landed:
-- `:split` (with default `splitbelow=false`) and `:abo split` go to
-- the top, `:bel split` (or `:split` with `splitbelow=true`) goes to
-- the bottom.
--
-- Vertical splits (`{"row"}` parent) are out of scope and left
-- untouched — voom's own tree-pane creation is a vertical split, so
-- this guard also keeps us from disturbing the plugin's own setup
-- when WinNew fires inside `tree.create()`.

-- Walk a winlayout tree and return (parent_kind, siblings) for the
-- node `target_win` if found.  `parent_kind` is the layout type of
-- the immediate parent ("col" or "row"); `siblings` is the parent's
-- child list.  Returns nil for a not-found target or when the target
-- is the root window of the tabpage.
local function find_layout_parent(layout, target_win)
  if layout[1] == "leaf" then
    return nil
  end
  for _, child in ipairs(layout[2]) do
    if child[1] == "leaf" and child[2] == target_win then
      return layout[1], layout[2]
    end
    local pkind, sibs = find_layout_parent(child, target_win)
    if pkind then
      return pkind, sibs
    end
  end
  return nil
end

-- Return (tree_win, body_win) for the first registered voom pair whose
-- *both* windows are present in `tabpage`, or nil if none.  `exclude_win`
-- is omitted from the candidate set: when WinNew fires for a `:split`
-- inside a body or tree pane, the freshly-created split window inherits
-- the same buffer as its source, and a naïve buf→win map would let it
-- masquerade as the canonical body/tree window — making the handler
-- bail out as "new is pair member" instead of fixing up the layout.
-- Excluding the new window lets us find the *original* tree and body
-- panes underneath the duplicated buffer.  Multiple pairs in one tab
-- aren't a documented use case, so first-match is acceptable.
local function find_voom_pair_in_tab(tabpage, exclude_win)
  local state = require("voom.state")
  if not vim.api.nvim_tabpage_is_valid(tabpage) then
    return nil
  end

  -- Build buffer→windows lists limited to this tab so we don't pick up
  -- the same body shown in another tab as a false match.  We track all
  -- windows per buffer (not just one) so that the exclude-win filter
  -- still leaves a candidate when two windows display the same buffer.
  local buf_to_wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.api.nvim_win_is_valid(win) and win ~= exclude_win then
      local b = vim.api.nvim_win_get_buf(win)
      buf_to_wins[b] = buf_to_wins[b] or {}
      table.insert(buf_to_wins[b], win)
    end
  end

  local function any(wins)
    return wins and wins[1] or nil
  end

  for _, body_buf in ipairs(state.registered_body_bufs()) do
    local tree_buf = state.get_tree(body_buf)
    local body_win = any(buf_to_wins[body_buf])
    local tree_win = tree_buf and any(buf_to_wins[tree_buf]) or nil
    if body_win and tree_win then
      return tree_win, body_win
    end
  end
  return nil
end

vim.api.nvim_create_autocmd("WinNew", {
  group = voom_augroup,
  callback = function()
    local config = require("voom.config")
    if not config.options.unified_horizontal_splits then
      return
    end

    -- Capture the originating tabpage synchronously.  By the time the
    -- scheduled callback runs `:tabnew`-style commands could have moved
    -- focus to a different tab; we only want to fix layouts in the tab
    -- where the split actually happened.
    local tab = vim.api.nvim_get_current_tabpage()

    -- Defer until Neovim has finished settling the new window's
    -- position.  At WinNew firing time the new window exists in the
    -- layout tree but `:split`'s focus-transfer hasn't run yet, so
    -- `nvim_get_current_win()` would return the *source* pane.  After
    -- one event-loop tick, focus is in the new window — exactly what
    -- we need to operate on.
    vim.schedule(function()
      if not vim.api.nvim_tabpage_is_valid(tab) then
        return
      end

      local new_win = vim.api.nvim_get_current_win()
      if not vim.api.nvim_win_is_valid(new_win) then
        return
      end
      if vim.api.nvim_win_get_tabpage(new_win) ~= tab then
        return
      end

      local tree_win, body_win = find_voom_pair_in_tab(tab, new_win)
      if not (tree_win and body_win) then
        return
      end

      -- Defensive: `find_voom_pair_in_tab` already excludes new_win, but
      -- if voom's own `init` re-uses the body window for a fresh tree
      -- pair, the registered windows might still coincide with new_win.
      -- Bail in that case rather than fight the plugin's own setup.
      if new_win == tree_win or new_win == body_win then
        return
      end

      local layout = vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tab))
      local parent_kind, siblings = find_layout_parent(layout, new_win)

      -- "col" = children stacked vertically = horizontal split.
      -- "row" = children side-by-side = vertical split (not our problem).
      if parent_kind ~= "col" then
        return
      end

      -- Only fix up splits that *broke* the tree+body row.  If the
      -- new window's siblings are some other pair (e.g. a previously-
      -- fixed full-width bottom split that the user split again from),
      -- the tree+body invariant still holds and we leave the layout
      -- alone.
      local source_pane_win
      for _, child in ipairs(siblings) do
        if child[1] == "leaf" and (child[2] == tree_win or child[2] == body_win) then
          source_pane_win = child[2]
          break
        end
      end
      if not source_pane_win then
        return
      end

      -- Honor the split's vertical orientation: if the new window
      -- landed *above* the source pane (default `:split` without
      -- `splitbelow`, or `:abo split`), promote it to a full-width
      -- top sibling; otherwise to a full-width bottom sibling.  Read
      -- positions inside the call rather than caching them outside,
      -- because the layout may have shifted while we were waiting on
      -- `vim.schedule`.
      local new_pos = vim.api.nvim_win_get_position(new_win)
      local source_pos = vim.api.nvim_win_get_position(source_pane_win)
      local cmd = (new_pos[1] < source_pos[1]) and "wincmd K" or "wincmd J"

      pcall(function()
        vim.api.nvim_win_call(new_win, function()
          vim.cmd(cmd)
        end)
      end)
    end)
  end,
})
