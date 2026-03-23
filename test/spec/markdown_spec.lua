local T = MiniTest.new_set()

-- ==============================================================================
-- Helpers
-- ==============================================================================

-- Load a fixture file into a 1-indexed table of strings (no trailing newline
-- per line), matching the format that nvim_buf_get_lines() returns.
local function load_fixture(name)
  local path = vim.fn.getcwd() .. "/test/fixtures/" .. name
  local lines = {}
  for line in io.lines(path) do
    table.insert(lines, line)
  end
  return lines
end

-- ==============================================================================
-- Module loading
-- ==============================================================================

T["loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.modes.markdown")
  end)
end

-- ==============================================================================
-- make_outline: return shape
-- ==============================================================================

T["make_outline"] = MiniTest.new_set()

T["make_outline"]["returns table with required keys"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({}, "test.md")
  MiniTest.expect.equality(type(result.tlines), "table")
  MiniTest.expect.equality(type(result.bnodes), "table")
  MiniTest.expect.equality(type(result.levels), "table")
  MiniTest.expect.equality(type(result.use_hash), "boolean")
  MiniTest.expect.equality(type(result.use_close_hash), "boolean")
end

T["make_outline"]["empty buffer produces empty outline"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({}, "empty.md")
  MiniTest.expect.equality(#result.tlines, 0)
  MiniTest.expect.equality(#result.bnodes, 0)
  MiniTest.expect.equality(#result.levels, 0)
end

-- ==============================================================================
-- make_outline: hash-style headings
-- ==============================================================================

T["make_outline"]["hash level 1 detected"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({ "# Hello" }, "test.md")
  MiniTest.expect.equality(#result.tlines, 1)
  MiniTest.expect.equality(result.levels[1], 1)
  MiniTest.expect.equality(result.tlines[1], "  |Hello")
  MiniTest.expect.equality(result.bnodes[1], 1)
end

T["make_outline"]["hash level 2 detected"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({ "## Section" }, "test.md")
  MiniTest.expect.equality(result.levels[1], 2)
  MiniTest.expect.equality(result.tlines[1], "  . |Section")
end

T["make_outline"]["hash level 3 detected"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({ "### Sub" }, "test.md")
  MiniTest.expect.equality(result.levels[1], 3)
  MiniTest.expect.equality(result.tlines[1], "  . . |Sub")
end

T["make_outline"]["hash strips closing hashes"] = function()
  local md = require("voom.modes.markdown")
  local result = md.make_outline({ "## Section ##" }, "test.md")
  MiniTest.expect.equality(result.tlines[1], "  . |Section")
end

T["make_outline"]["hash correct bnode line numbers"] = function()
  local md = require("voom.modes.markdown")
  -- Headings at lines 1 and 3; line 2 is non-heading content.
  local lines = { "# First", "some content", "## Second" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(#result.bnodes, 2)
  MiniTest.expect.equality(result.bnodes[1], 1)
  MiniTest.expect.equality(result.bnodes[2], 3)
end

-- ==============================================================================
-- make_outline: underline-style headings
-- ==============================================================================

T["make_outline"]["underline level 1 with ==="] = function()
  local md = require("voom.modes.markdown")
  local lines = { "Title", "=====" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(#result.tlines, 1)
  MiniTest.expect.equality(result.levels[1], 1)
  MiniTest.expect.equality(result.tlines[1], "  |Title")
  MiniTest.expect.equality(result.bnodes[1], 1)
end

T["make_outline"]["underline level 2 with ---"] = function()
  local md = require("voom.modes.markdown")
  local lines = { "Section", "-------" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(result.levels[1], 2)
  MiniTest.expect.equality(result.tlines[1], "  . |Section")
end

T["make_outline"]["underline adornment line not treated as title"] = function()
  local md = require("voom.modes.markdown")
  -- Two back-to-back underline headings; the adornment lines must not be
  -- parsed as the titles of subsequent headings.
  local lines = { "Title", "=====", "Next Heading", "------------" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(#result.tlines, 2)
  MiniTest.expect.equality(result.tlines[1], "  |Title")
  MiniTest.expect.equality(result.tlines[2], "  . |Next Heading")
end

T["make_outline"]["underline bnode points to title not adornment"] = function()
  local md = require("voom.modes.markdown")
  -- Preamble text at line 1; title at line 2; adornment at line 3.
  local lines = { "preamble text", "Title", "=====" }
  local result = md.make_outline(lines, "test.md")
  -- bnode must be 2 (the title line), not 3 (the adornment).
  MiniTest.expect.equality(result.bnodes[1], 2)
end

-- ==============================================================================
-- make_outline: style preference detection
-- ==============================================================================

T["make_outline"]["use_hash false when first level-1/2 is underline"] = function()
  local md = require("voom.modes.markdown")
  local lines = { "Title", "=====" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(result.use_hash, false)
end

T["make_outline"]["use_hash true when first level-1/2 is hash"] = function()
  local md = require("voom.modes.markdown")
  local lines = { "# Title" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(result.use_hash, true)
end

T["make_outline"]["use_close_hash true when closing hashes present"] = function()
  local md = require("voom.modes.markdown")
  local lines = { "## Section ##" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(result.use_close_hash, true)
end

T["make_outline"]["use_close_hash false when no closing hashes"] = function()
  local md = require("voom.modes.markdown")
  local lines = { "## Section" }
  local result = md.make_outline(lines, "test.md")
  MiniTest.expect.equality(result.use_close_hash, false)
end

-- ==============================================================================
-- Fixture integration tests
-- ==============================================================================

T["fixture"] = MiniTest.new_set()

T["fixture"]["parses expected heading count"] = function()
  local md = require("voom.modes.markdown")
  local lines = load_fixture("sample.md")
  local result = md.make_outline(lines, "sample.md")
  -- sample.md has 10 headings: 4 hash (levels 1,1,2,6) + 4 hash nested
  -- (levels 2,3,3,2) + 2 underline (levels 1,2). See fixture for details.
  MiniTest.expect.equality(#result.tlines, 10)
end

T["fixture"]["first heading is Project Overview at level 1"] = function()
  local md = require("voom.modes.markdown")
  local lines = load_fixture("sample.md")
  local result = md.make_outline(lines, "sample.md")
  MiniTest.expect.equality(result.tlines[1], "  |Project Overview")
  MiniTest.expect.equality(result.levels[1], 1)
  MiniTest.expect.equality(result.bnodes[1], 1)
end

T["fixture"]["underline heading detected in results"] = function()
  local md = require("voom.modes.markdown")
  local lines = load_fixture("sample.md")
  local result = md.make_outline(lines, "sample.md")
  local found = false
  for _, t in ipairs(result.tlines) do
    if t:find("Underline Level One", 1, true) then
      found = true
      break
    end
  end
  MiniTest.expect.equality(found, true)
end

T["fixture"]["use_hash false because first heading is hash style"] = function()
  -- sample.md starts with "# Project Overview" so use_hash should be true.
  local md = require("voom.modes.markdown")
  local lines = load_fixture("sample.md")
  local result = md.make_outline(lines, "sample.md")
  MiniTest.expect.equality(result.use_hash, true)
end

-- ==============================================================================
-- Modes registry integration
-- ==============================================================================

T["modes registry"] = MiniTest.new_set()

T["modes registry"]["get markdown returns a module"] = function()
  local modes = require("voom.modes")
  local md = modes.get("markdown")
  MiniTest.expect.equality(type(md), "table")
end

T["modes registry"]["markdown module has make_outline function"] = function()
  local modes = require("voom.modes")
  local md = modes.get("markdown")
  MiniTest.expect.equality(type(md.make_outline), "function")
end

return T
