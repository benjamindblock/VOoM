-- Tests for the Treesitter TypeScript query definition.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  return require("voom.ts").build_mode("typescript")
end

-- ==============================================================================
-- Smoke tests
-- ==============================================================================

T["typescript ts mode"] = MiniTest.new_set()

T["typescript ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.typescript")
  end)
end

T["typescript ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

T["typescript ts mode"]["tsx query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.tsx")
  end)
end

T["typescript ts mode"]["tsx build_mode works"] = function()
  local mode = require("voom.ts").build_mode("tsx")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

-- ==============================================================================
-- Outline extraction from sample.ts
-- ==============================================================================

T["typescript ts mode"]["sample.ts"] = MiniTest.new_set()

local lines = nil
local result = nil

T["typescript ts mode"]["sample.ts"]["before"] = function()
  lines = H.load_fixture("sample.ts")
  result = get_mode().make_outline(lines, "sample.ts")
end

T["typescript ts mode"]["sample.ts"]["produces eight entries"] = function()
  -- Greeter, ID, Color, Person, greet, walk, createPerson, helper
  MiniTest.expect.equality(#result.bnodes, 8)
end

T["typescript ts mode"]["sample.ts"]["levels are correct"] = function()
  -- Greeter(1), ID(1), Color(1), Person(1), greet(2), walk(2), createPerson(1), helper(1)
  MiniTest.expect.equality(result.levels, { 1, 1, 1, 1, 2, 2, 1, 1 })
end

T["typescript ts mode"]["sample.ts"]["line numbers are correct"] = function()
  -- Greeter=1, ID=5, Color=7, Person=13, greet=14, walk=18, createPerson=23, helper=27
  MiniTest.expect.equality(result.bnodes, { 1, 5, 7, 13, 14, 18, 23, 27 })
end

T["typescript ts mode"]["sample.ts"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("interface Greeter",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("type ID",             1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("enum Color",          1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[4]:find("class Person",        1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[5]:find("greet()",             1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[6]:find("walk()",              1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[7]:find("function createPerson", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[8]:find("helper()",            1, true) ~= nil, true)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["typescript ts mode"]["edge cases"] = MiniTest.new_set()

T["typescript ts mode"]["edge cases"]["empty document"] = function()
  local r = get_mode().make_outline({}, "empty.ts")
  MiniTest.expect.equality(#r.bnodes, 0)
end

return T
