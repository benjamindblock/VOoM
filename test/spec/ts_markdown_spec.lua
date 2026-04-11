-- Snapshot tests for the Treesitter Markdown parser.
--
-- These snapshots were generated from the regex parser's output on each
-- fixture.  They are now frozen — the TS parser must match them exactly.
-- This preserves the regression safety net after the regex parser is
-- deleted (WI-16).

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

-- ==============================================================================
-- Helper: load the TS mode
-- ==============================================================================

local function get_ts_mode()
  return require("voom.ts").build_mode("markdown")
end

-- ==============================================================================
-- TS engine unit tests
-- ==============================================================================

T["ts engine"] = MiniTest.new_set()

T["ts engine"]["module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts")
  end)
end

T["ts engine"]["build_mode returns table with make_outline"] = function()
  local ts = require("voom.ts")
  local mode = ts.build_mode("markdown")
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

T["ts engine"]["make_outline from lines array (temp buffer path)"] = function()
  local mode = get_ts_mode()
  local result = mode.make_outline({ "# Hello", "", "## World" }, "test.md")
  MiniTest.expect.equality(type(result), "table")
  MiniTest.expect.equality(#result.bnodes, 2)
  MiniTest.expect.equality(#result.levels, 2)
  MiniTest.expect.equality(#result.tlines, 2)
end

T["ts engine"]["make_outline from real buffer (bufnr path)"] = function()
  local mode = get_ts_mode()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Hello", "", "## World" })
  local result = mode.make_outline(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    "test.md",
    buf
  )
  vim.api.nvim_buf_delete(buf, { force = true })
  MiniTest.expect.equality(#result.bnodes, 2)
end

T["ts engine"]["empty document produces empty outline"] = function()
  local mode = get_ts_mode()
  local result = mode.make_outline({}, "empty.md")
  MiniTest.expect.equality(#result.tlines, 0)
  MiniTest.expect.equality(#result.bnodes, 0)
  MiniTest.expect.equality(#result.levels, 0)
end

T["ts engine"]["document with no headings produces empty outline"] = function()
  local mode = get_ts_mode()
  local result = mode.make_outline(
    { "Just prose.", "", "No headings here." },
    "no_headings.md"
  )
  MiniTest.expect.equality(#result.tlines, 0)
  MiniTest.expect.equality(#result.bnodes, 0)
  MiniTest.expect.equality(#result.levels, 0)
end

-- ==============================================================================
-- Frozen snapshots (generated from the regex parser's final output)
-- ==============================================================================

local snapshots = {}

-- Snapshot for sample.md
snapshots["sample.md"] = {
  bnodes = { 1, 6, 10, 16, 20, 24, 28, 34, 40, 45 },
  levels = { 1, 2, 3, 3, 2, 1, 1, 2, 2, 6 },
  tlines = {
    " · Project Overview",
    "   · Installation",
    "     · Requirements",
    "     · Platform Notes",
    "   · Usage",
    " · Advanced Topics",
    " · Underline Level One",
    "   · Underline Level Two",
    "   · Mixed Hash Section",
    "           · Deep Heading",
  },
  use_hash = true,
  use_close_hash = false,
}

-- Snapshot for edge_cases.md
snapshots["edge_cases.md"] = {
  bnodes = { 3, 5, 7, 9, 11, 13, 16, 19 },
  levels = { 1, 2, 3, 4, 2, 1, 2, 1 },
  tlines = {
    " · Root",
    "   · Child One",
    "     · Grandchild",
    "       · Great Grandchild",
    "   · Empty Child",
    " · Setext Parent",
    "   · Setext Child",
    " · Tail",
  },
  use_hash = true,
  use_close_hash = false,
}

-- Snapshot for readme_outline.md
snapshots["readme_outline.md"] = {
  bnodes = { 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29 },
  levels = { 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 2, 2 },
  tlines = {
    " · nvim-voom",
    "   · Installation",
    "   · Commands",
    "   · Supported markup modes",
    "   · Tree pane",
    "   · Keymaps — tree pane",
    "     · Navigation",
    "     · Folding",
    "     · Display",
    "     · Editing",
    "   · Keymaps — body pane",
    "   · Live cursor-follow",
    "   · VoomGrep",
    "   · VoomSort",
    "   · Development",
  },
  use_hash = true,
  use_close_hash = false,
}

-- Snapshot for session_outline.md
snapshots["session_outline.md"] = {
  bnodes = { 1, 3 },
  levels = { 1, 2 },
  tlines = {
    " · VOoM Session Notes",
    "   · Bugs / Issues / Missing Features",
  },
  use_hash = true,
  use_close_hash = false,
}

-- ==============================================================================
-- Snapshot comparison tests
-- ==============================================================================

local function snapshot_check(fixture_name)
  local lines   = H.load_fixture(fixture_name)
  local ts_mode = get_ts_mode()
  local actual   = ts_mode.make_outline(lines, fixture_name)
  local expected = snapshots[fixture_name]

  MiniTest.expect.equality(actual.bnodes,         expected.bnodes)
  MiniTest.expect.equality(actual.levels,         expected.levels)
  MiniTest.expect.equality(actual.tlines,         expected.tlines)
  MiniTest.expect.equality(actual.use_hash,       expected.use_hash)
  MiniTest.expect.equality(actual.use_close_hash, expected.use_close_hash)
end

T["snapshots"] = MiniTest.new_set()

T["snapshots"]["sample.md"] = function()
  snapshot_check("sample.md")
end

T["snapshots"]["edge_cases.md"] = function()
  snapshot_check("edge_cases.md")
end

T["snapshots"]["readme_outline.md"] = function()
  snapshot_check("readme_outline.md")
end

T["snapshots"]["session_outline.md"] = function()
  snapshot_check("session_outline.md")
end

return T
