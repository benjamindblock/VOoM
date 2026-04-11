-- Treesitter query definition for Ruby outlines.
--
-- Captures classes, modules, methods, and singleton methods.
-- Level is derived from structural nesting depth — a method inside a class
-- inside a module is level 3.

local M = {}

M.lang = "ruby"

M.query_string = [[
(class) @class
(module) @module
(method) @method
(singleton_method) @singleton_method
]]

-- ===========================================================================
-- Private helpers
-- ===========================================================================

-- Node types that count as structural containers for nesting depth.
local CONTAINER_TYPES = {
  class  = true,
  module = true,
  method = true,
  singleton_method = true,
}

local function structural_depth(node)
  local count = 0
  local parent = node:parent()
  while parent do
    if CONTAINER_TYPES[parent:type()] then
      count = count + 1
    end
    parent = parent:parent()
  end
  return count
end

-- Return the text of the first `constant` child (class/module name)
-- or `identifier` child (method name).
local function find_name_child(node, child_type, bufnr)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == child_type then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return "?"
end

-- ===========================================================================
-- extract
-- ===========================================================================

function M.extract(captures, query, bufnr)
  local entries = {}

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    local node = cap.node
    local start_row = node:range()
    local lnum = start_row + 1

    local name, level

    if capture_name == "class" then
      name = "class " .. find_name_child(node, "constant", bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "module" then
      name = "module " .. find_name_child(node, "constant", bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "method" then
      name = "def " .. find_name_child(node, "identifier", bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "singleton_method" then
      -- Singleton methods are typically self.method_name
      local method_name = find_name_child(node, "identifier", bufnr)
      name = "def self." .. method_name
      level = structural_depth(node) + 1

    else
      goto continue
    end

    table.insert(entries, { level = level, name = name, lnum = lnum })

    ::continue::
  end

  return entries
end

-- ===========================================================================
-- outline_state
-- ===========================================================================

function M.outline_state(_entries, _lines)
  return { use_hash = false, use_close_hash = false }
end

return M
