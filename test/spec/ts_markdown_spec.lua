-- Golden-master tests for the Treesitter Markdown parser.
--
-- Phase 1 / WI-1: these tests are intentionally RED until WI-2 through WI-4
-- implement the TS engine and query.  They establish the contract: the TS
-- parser must produce output identical to the existing regex parser for every
-- Markdown fixture.
--
-- Once WI-2–WI-4 are complete the tests will go green; they then serve as the
-- regression safety net for the Phase 2 registry switch (WI-6).

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

-- ==============================================================================
-- Helper: load the TS mode (fails gracefully so we get readable test errors)
-- ==============================================================================

local function get_ts_mode()
  local ok, ts = pcall(require, "voom.ts")
  if not ok then
    error("voom.ts not found — implement WI-2 first: " .. tostring(ts))
  end
  return ts.build_mode("markdown")
end

-- ==============================================================================
-- TS engine unit tests (also red in WI-1 phase)
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
-- Golden-master tests: TS output must match regex parser for every fixture
-- ==============================================================================

-- Compare TS parser output against the regex parser for a given fixture file.
-- Asserts that bnodes, levels, tlines, use_hash, and use_close_hash all match.
local function golden_master_check(fixture_name)
  local lines   = H.load_fixture(fixture_name)
  local regex   = require("voom.modes.markdown")
  local ts_mode = get_ts_mode()

  local expected = regex.make_outline(lines, fixture_name)
  local actual   = ts_mode.make_outline(lines, fixture_name)

  MiniTest.expect.equality(actual.bnodes,          expected.bnodes,
    fixture_name .. ": bnodes mismatch")
  MiniTest.expect.equality(actual.levels,          expected.levels,
    fixture_name .. ": levels mismatch")
  MiniTest.expect.equality(actual.tlines,          expected.tlines,
    fixture_name .. ": tlines mismatch")
  MiniTest.expect.equality(actual.use_hash,        expected.use_hash,
    fixture_name .. ": use_hash mismatch")
  MiniTest.expect.equality(actual.use_close_hash,  expected.use_close_hash,
    fixture_name .. ": use_close_hash mismatch")
end

T["golden-master"] = MiniTest.new_set()

T["golden-master"]["sample.md"] = function()
  golden_master_check("sample.md")
end

T["golden-master"]["edge_cases.md"] = function()
  golden_master_check("edge_cases.md")
end

T["golden-master"]["readme_outline.md"] = function()
  golden_master_check("readme_outline.md")
end

T["golden-master"]["session_outline.md"] = function()
  golden_master_check("session_outline.md")
end

return T
