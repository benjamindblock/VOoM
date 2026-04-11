-- Tests for the Treesitter Python query definition.
--
-- Verifies that the Python outline correctly captures classes, top-level
-- functions, methods, nested functions, and decorated definitions, and
-- assigns the right nesting level to each.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  local ts = require("voom.ts")
  return ts.build_mode("python")
end

-- ==============================================================================
-- Basic module / build_mode smoke tests
-- ==============================================================================

T["python ts mode"] = MiniTest.new_set()

T["python ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.python")
  end)
end

T["python ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

T["python ts mode"]["capabilities match code template"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(mode.capabilities.insert, false)
  MiniTest.expect.equality(mode.capabilities.promote, false)
  MiniTest.expect.equality(mode.capabilities.move, true)
  MiniTest.expect.equality(mode.capabilities.cut, true)
  MiniTest.expect.equality(mode.capabilities.sort, true)
end

-- ==============================================================================
-- Outline extraction from sample.py
-- ==============================================================================

T["python ts mode"]["sample.py"] = MiniTest.new_set()

-- Load sample.py once and share it across the subtests.
local lines = nil
local result = nil

T["python ts mode"]["sample.py"]["before"] = function()
  lines = H.load_fixture("sample.py")
  result = get_mode().make_outline(lines, "sample.py")
end

T["python ts mode"]["sample.py"]["produces eight entries"] = function()
  MiniTest.expect.equality(#result.bnodes, 8)
  MiniTest.expect.equality(#result.levels, 8)
  MiniTest.expect.equality(#result.tlines, 8)
end

T["python ts mode"]["sample.py"]["levels are correct"] = function()
  -- TopLevel(1), method(2), another_method(2), nested(3),
  -- top_function(1), decorated_function(1), DecoratedClass(1), decorated_method(2)
  MiniTest.expect.equality(result.levels, { 1, 2, 2, 3, 1, 1, 1, 2 })
end

T["python ts mode"]["sample.py"]["line numbers are correct"] = function()
  -- TopLevel=1, method=4, another_method=8, nested=9,
  -- top_function=14, decorated_function=19 (@decorator line),
  -- DecoratedClass=24 (@decorator line), decorated_method=26
  MiniTest.expect.equality(result.bnodes, { 1, 4, 8, 9, 14, 19, 24, 26 })
end

T["python ts mode"]["sample.py"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("class TopLevel",        1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("def method",            1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("def another_method",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[4]:find("def nested",            1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[5]:find("def top_function",      1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[6]:find("def decorated_function",1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[7]:find("class DecoratedClass",  1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[8]:find("def decorated_method",  1, true) ~= nil, true)
end

T["python ts mode"]["sample.py"]["use_hash and use_close_hash are false"] = function()
  MiniTest.expect.equality(result.use_hash, false)
  MiniTest.expect.equality(result.use_close_hash, false)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["python ts mode"]["edge cases"] = MiniTest.new_set()

T["python ts mode"]["edge cases"]["empty document produces empty outline"] = function()
  local r = get_mode().make_outline({}, "empty.py")
  MiniTest.expect.equality(#r.tlines, 0)
  MiniTest.expect.equality(#r.bnodes, 0)
  MiniTest.expect.equality(#r.levels, 0)
end

T["python ts mode"]["edge cases"]["file with no classes or functions"] = function()
  local r = get_mode().make_outline({ "x = 1", "y = 2", "print(x + y)" }, "flat.py")
  MiniTest.expect.equality(#r.tlines, 0)
end

T["python ts mode"]["edge cases"]["single top-level class"] = function()
  local r = get_mode().make_outline({ "class Foo:", "    pass" }, "one_class.py")
  MiniTest.expect.equality(#r.bnodes, 1)
  MiniTest.expect.equality(r.levels[1], 1)
  MiniTest.expect.equality(r.tlines[1]:find("class Foo", 1, true) ~= nil, true)
end

T["python ts mode"]["edge cases"]["single top-level function"] = function()
  local r = get_mode().make_outline({ "def greet():", "    return 'hello'" }, "one_fn.py")
  MiniTest.expect.equality(#r.bnodes, 1)
  MiniTest.expect.equality(r.levels[1], 1)
  MiniTest.expect.equality(r.tlines[1]:find("def greet", 1, true) ~= nil, true)
end

return T
