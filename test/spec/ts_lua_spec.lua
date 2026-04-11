-- Tests for the Treesitter Lua query definition.
--
-- Verifies that the Lua outline correctly captures named functions,
-- local functions, dot-indexed functions, and assignment-based functions.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  return require("voom.ts").build_mode("lua")
end

-- ==============================================================================
-- Smoke tests
-- ==============================================================================

T["lua ts mode"] = MiniTest.new_set()

T["lua ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.lua")
  end)
end

T["lua ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

T["lua ts mode"]["capabilities match code template"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(mode.capabilities.insert, false)
  MiniTest.expect.equality(mode.capabilities.promote, false)
  MiniTest.expect.equality(mode.capabilities.move, true)
end

-- ==============================================================================
-- Outline extraction from sample.lua
-- ==============================================================================

T["lua ts mode"]["sample.lua"] = MiniTest.new_set()

local lines = nil
local result = nil

T["lua ts mode"]["sample.lua"]["before"] = function()
  lines = H.load_fixture("sample.lua")
  result = get_mode().make_outline(lines, "sample.lua")
end

T["lua ts mode"]["sample.lua"]["produces seven entries"] = function()
  -- top_level, helper, M.setup, M.run, cb, M.nested, inner
  MiniTest.expect.equality(#result.bnodes, 7)
end

T["lua ts mode"]["sample.lua"]["levels are correct"] = function()
  -- top_level(1), helper(1), M.setup(1), M.run(1), cb(1), M.nested(1), inner(2)
  MiniTest.expect.equality(result.levels, { 1, 1, 1, 1, 1, 1, 2 })
end

T["lua ts mode"]["sample.lua"]["line numbers are correct"] = function()
  -- top_level=1, helper=5, M.setup=11, M.run=15, cb=19, M.nested=23, inner=24
  MiniTest.expect.equality(result.bnodes, { 1, 5, 11, 15, 19, 23, 24 })
end

T["lua ts mode"]["sample.lua"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("top_level",   1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("local helper", 1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("M.setup",     1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[4]:find("M.run",       1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[5]:find("local cb",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[6]:find("M.nested",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[7]:find("local inner", 1, true) ~= nil, true)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["lua ts mode"]["edge cases"] = MiniTest.new_set()

T["lua ts mode"]["edge cases"]["empty document"] = function()
  local r = get_mode().make_outline({}, "empty.lua")
  MiniTest.expect.equality(#r.bnodes, 0)
end

T["lua ts mode"]["edge cases"]["no functions"] = function()
  local r = get_mode().make_outline({ "local x = 1", "print(x)" }, "flat.lua")
  MiniTest.expect.equality(#r.bnodes, 0)
end

T["lua ts mode"]["edge cases"]["single function"] = function()
  local r = get_mode().make_outline({ "function greet()", '  print("hi")', "end" }, "one.lua")
  MiniTest.expect.equality(#r.bnodes, 1)
  MiniTest.expect.equality(r.levels[1], 1)
end

return T
