-- Tests for the Treesitter Go query definition.

local H = dofile("test/helpers.lua")

local T = MiniTest.new_set()

local function get_mode()
  return require("voom.ts").build_mode("go")
end

-- ==============================================================================
-- Smoke tests
-- ==============================================================================

T["go ts mode"] = MiniTest.new_set()

T["go ts mode"]["query module loads without error"] = function()
  MiniTest.expect.no_error(function()
    require("voom.ts.queries.go")
  end)
end

T["go ts mode"]["build_mode returns table with make_outline"] = function()
  local mode = get_mode()
  MiniTest.expect.equality(type(mode), "table")
  MiniTest.expect.equality(type(mode.make_outline), "function")
end

-- ==============================================================================
-- Outline extraction from sample.go
-- ==============================================================================

T["go ts mode"]["sample.go"] = MiniTest.new_set()

local lines = nil
local result = nil

T["go ts mode"]["sample.go"]["before"] = function()
  lines = H.load_fixture("sample.go")
  result = get_mode().make_outline(lines, "sample.go")
end

T["go ts mode"]["sample.go"]["produces five entries"] = function()
  -- Animal, Speak, Mover, NewAnimal, main
  MiniTest.expect.equality(#result.bnodes, 5)
end

T["go ts mode"]["sample.go"]["levels are correct"] = function()
  -- Animal(1), Speak(2 — method on *Animal), Mover(1), NewAnimal(1), main(1)
  MiniTest.expect.equality(result.levels, { 1, 2, 1, 1, 1 })
end

T["go ts mode"]["sample.go"]["line numbers are correct"] = function()
  -- Animal=5, Speak=9, Mover=13, NewAnimal=17, main=21
  MiniTest.expect.equality(result.bnodes, { 5, 9, 13, 17, 21 })
end

T["go ts mode"]["sample.go"]["display names are correct"] = function()
  MiniTest.expect.equality(result.tlines[1]:find("type Animal",   1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[2]:find("Speak",         1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[3]:find("type Mover",    1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[4]:find("NewAnimal",     1, true) ~= nil, true)
  MiniTest.expect.equality(result.tlines[5]:find("main",          1, true) ~= nil, true)
end

-- ==============================================================================
-- Edge cases
-- ==============================================================================

T["go ts mode"]["edge cases"] = MiniTest.new_set()

T["go ts mode"]["edge cases"]["empty document"] = function()
  local r = get_mode().make_outline({}, "empty.go")
  MiniTest.expect.equality(#r.bnodes, 0)
end

T["go ts mode"]["edge cases"]["package only"] = function()
  local r = get_mode().make_outline({ "package main" }, "pkg.go")
  MiniTest.expect.equality(#r.bnodes, 0)
end

return T
