-- Treesitter query definition for TypeScript outlines.
--
-- Extends the JavaScript captures with TypeScript-specific constructs:
-- interface declarations, type alias declarations, and enum declarations.
--
-- This query definition is used for both .ts and .tsx files — the mode
-- registry maps both filetypes here, using "typescript" as the TS parser
-- language for .ts and "tsx" for .tsx.

local M = {}

-- The `lang` field is set dynamically by build_mode_ts() depending on
-- the filetype.  Default to "typescript" for .ts files.
M.lang = "typescript"

M.query_string = [[
(class_declaration) @class
(function_declaration) @function
(method_definition) @method
(interface_declaration) @interface
(type_alias_declaration) @type_alias
(enum_declaration) @enum
(lexical_declaration
  (variable_declarator
    value: (arrow_function)) @arrow_var)
(lexical_declaration
  (variable_declarator
    value: (function_expression)) @func_var)
]]

-- ===========================================================================
-- Private helpers
-- ===========================================================================

local CONTAINER_TYPES = {
  class_declaration = true,
  function_declaration = true,
  method_definition = true,
  arrow_function = true,
  function_expression = true,
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

local function find_child_text(node, child_type, bufnr)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == child_type then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return "?"
end

-- TypeScript uses type_identifier for class names, interface names, and
-- type alias names, but plain identifier for function/enum names.
local function find_name(node, bufnr)
  return find_child_text(node, "type_identifier", bufnr)
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
      name = "class " .. find_name(node, bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "function" then
      name = "function " .. find_child_text(node, "identifier", bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "method" then
      local mname = find_child_text(node, "property_identifier", bufnr)
      name = mname .. "()"
      level = structural_depth(node) + 1

    elseif capture_name == "interface" then
      name = "interface " .. find_name(node, bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "type_alias" then
      name = "type " .. find_name(node, bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "enum" then
      name = "enum " .. find_child_text(node, "identifier", bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "arrow_var" or capture_name == "func_var" then
      local vname = find_child_text(node, "identifier", bufnr)
      name = vname .. "()"
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
