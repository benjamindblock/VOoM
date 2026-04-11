-- Tests for the Treesitter Bash query definition.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  return require("voom.ts").build_mode("bash")
end

-- ==============================================================================
-- Smoke tests
-- ==============================================================================

T["bash ts mode"] = MiniTest.new_set()

T["bash ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.bash")
  end)
end

T["bash ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

-- ==============================================================================
-- Outline extraction from sample.bash
-- ==============================================================================

T["bash ts mode"]["sample.bash"] = MiniTest.new_set()

local lines = nil
local result = nil

T["bash ts mode"]["sample.bash"]["before"] = function()
  lines = H.load_fixture("sample.bash")
  result = get_mode().make_outline(lines, "sample.bash")
end

T["bash ts mode"]["sample.bash"]["produces three entries"] = function()
  -- greet, farewell, setup
  MiniTest.expect.equality(#result.bnodes, 3)
end

T["bash ts mode"]["sample.bash"]["all entries are level 1"] = function()
  MiniTest.expect.equality(result.levels, { 1, 1, 1 })
end

T["bash ts mode"]["sample.bash"]["line numbers are correct"] = function()
  -- greet=3, farewell=7, setup=11
  MiniTest.expect.equality(result.bnodes, { 3, 7, 11 })
end

T["bash ts mode"]["sample.bash"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("greet()",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("farewell()", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("setup()",    1, true) ~= nil, true)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["bash ts mode"]["edge cases"] = MiniTest.new_set()

T["bash ts mode"]["edge cases"]["empty document"] = function()
  local r = get_mode().make_outline({}, "empty.bash")
  MiniTest.expect.equality(#r.bnodes, 0)
end

T["bash ts mode"]["edge cases"]["no functions"] = function()
  local r = get_mode().make_outline({ "#!/bin/bash", "echo hello" }, "flat.bash")
  MiniTest.expect.equality(#r.bnodes, 0)
end

return T
