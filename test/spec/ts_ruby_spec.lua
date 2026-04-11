-- Tests for the Treesitter Ruby query definition.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  return require("voom.ts").build_mode("ruby")
end

-- ==============================================================================
-- Smoke tests
-- ==============================================================================

T["ruby ts mode"] = MiniTest.new_set()

T["ruby ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.ruby")
  end)
end

T["ruby ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

-- ==============================================================================
-- Outline extraction from sample.rb
-- ==============================================================================

T["ruby ts mode"]["sample.rb"] = MiniTest.new_set()

local lines = nil
local result = nil

T["ruby ts mode"]["sample.rb"]["before"] = function()
  lines = H.load_fixture("sample.rb")
  result = get_mode().make_outline(lines, "sample.rb")
end

T["ruby ts mode"]["sample.rb"]["produces seven entries"] = function()
  -- module Animals, class Dog, def speak, def self.species, class Cat, def purr, def top_level_helper
  MiniTest.expect.equality(#result.bnodes, 7)
end

T["ruby ts mode"]["sample.rb"]["levels are correct"] = function()
  -- Animals(1), Dog(2), speak(3), self.species(3), Cat(1), purr(2), top_level_helper(1)
  MiniTest.expect.equality(result.levels, { 1, 2, 3, 3, 1, 2, 1 })
end

T["ruby ts mode"]["sample.rb"]["line numbers are correct"] = function()
  -- Animals=1, Dog=2, speak=3, self.species=7, Cat=13, purr=14, top_level_helper=19
  MiniTest.expect.equality(result.bnodes, { 1, 2, 3, 7, 13, 14, 19 })
end

T["ruby ts mode"]["sample.rb"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("module Animals",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("class Dog",         1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("def speak",         1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[4]:find("def self.species",  1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[5]:find("class Cat",         1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[6]:find("def purr",          1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[7]:find("def top_level_helper", 1, true) ~= nil, true)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["ruby ts mode"]["edge cases"] = MiniTest.new_set()

T["ruby ts mode"]["edge cases"]["empty document"] = function()
  local r = get_mode().make_outline({}, "empty.rb")
  MiniTest.expect.equality(#r.bnodes, 0)
end

T["ruby ts mode"]["edge cases"]["no definitions"] = function()
  local r = get_mode().make_outline({ "puts 'hello'", "x = 1" }, "flat.rb")
  MiniTest.expect.equality(#r.bnodes, 0)
end

return T
