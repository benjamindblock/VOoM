local M = {}

-- Default configuration. Users override via require("voom").setup({...}).
M.defaults = {
  -- Width of the tree pane in columns.
  tree_width = 40,
  -- Default markup mode when none is specified.
  default_mode = "markdown",
  -- Which side of the editor the tree pane opens on: "left" or "right".
  tree_position = "left",
  -- Automatically open the tree pane for matching filetypes whenever the
  -- body buffer is displayed in a window (on BufWinEnter — covers first
  -- load, :edit of an already-loaded buffer, hidden-buffer re-display, and
  -- netrw selection round-trips).
  -- false  → never auto-open
  -- true   → auto-open for all supported modes
  -- table  → auto-open only for the listed mode names, e.g. {"markdown"}
  auto_open = false,
  -- Automatically close the voom two-pane setup when *either* pane
  -- leaves its window (e.g. `:q`, fzf replacing the buffer, `-` to
  -- netrw).  Body leaving → its tree closes.  Tree leaving → the tree
  -- closes AND the body's window closes, so `-`/fzf/`:q` invoked from
  -- the tree side tears down the whole pair.  The body buffer itself
  -- is never wiped, only its window is closed; if the body has unsaved
  -- changes the window-close is skipped so work is preserved.
  -- false  → never auto-close
  -- true   → auto-close for all supported modes
  -- table  → auto-close only for the listed mode names, e.g. {"markdown"}
  auto_close = false,
  -- When the user creates a horizontal split (`:split`, `:sp`, `<C-w>s`,
  -- `:new`, …) inside either pane of an active voom session, reshape the
  -- resulting layout so the new window spans the full width *beneath*
  -- (or above, for `:abo split`) the entire tree+body row, instead of
  -- splitting only the pane the user was focused in.  Without this,
  -- `:sp` leaves the tree-side and body-side columns out of sync —
  -- e.g. `:sp` from the tree pane creates a duplicate tree window above
  -- the original tree while leaving the body un-split, which is rarely
  -- what a two-pane outliner user wants.
  --
  -- Implemented by intercepting `WinNew` and running `wincmd K` /
  -- `wincmd J` on the new window when its parent in `winlayout` is a
  -- horizontal-split node containing the tree or body pane.  Vertical
  -- splits (`:vsplit`) are untouched.
  --
  -- false → leave splits as Neovim's default (broken layout)
  -- true  → fix up horizontal splits to span both panes
  unified_horizontal_splits = true,
  -- Whether moving the cursor in the tree automatically scrolls the body
  -- window to the corresponding heading without moving focus.
  cursor_follow = true,
  -- Virtual-text fold-state indicators shown next to each tree node.
  -- Set enabled=false to turn them off entirely.
  -- Icons are rendered via nvim_buf_set_extmark (Neovim-only).
  fold_indicators = {
    enabled = true,
    icons = { open = "▼", closed = "▶", leaf = "·" },
  },
  -- Vertical guide lines rendered at each ancestor column of nested headings.
  -- Set enabled=false to turn them off entirely.
  -- The guide character is overlaid via nvim_buf_set_extmark; any single
  -- display-column character can be used.
  indent_guides = {
    enabled = true,
    char = "│", -- U+2502 box-drawing vertical bar
  },
  -- End-of-line "+N" descendant-count badges shown on collapsed nodes.
  badges = {
    enabled = true,
  },
  -- Override or disable individual tree-pane keymaps.
  -- Set a key to false to disable it; set to a string to remap the action
  -- to that key.  Setting the entire table to false disables all plugin
  -- keymaps, allowing the user to define their own via autocommands.
  -- TODO: implement keymap override/disable logic in set_keymaps().
  keymaps = {},
  -- Callback invoked after the tree pane is created.
  -- Signature: function(body_buf, tree_buf)
  -- Useful for applying buffer-local options or additional keymaps.
  on_open = nil,
  -- Options for the :VoomSort command.
  sort = {
    -- Default sort flags passed to :VoomSort when the user provides no
    -- arguments (e.g. "i" to always sort case-insensitively).
    default_opts = "",
  },
}

-- Merged config, populated by setup().
M.options = {}

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
