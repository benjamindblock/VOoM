-- Treesitter query definition for Go outlines.
--
-- Captures type declarations, function declarations, and method
-- declarations.  Go has no nesting, so all constructs live at the
-- package level.  Methods are placed at level 2 under their receiver
-- type to give them visual hierarchy in the outline.

local M = {}

M.lang = "go"

M.query_string = [[
(type_declaration) @type_decl
(function_declaration) @function
(method_declaration) @method
]]

-- ===========================================================================
-- Private helpers
-- ===========================================================================

-- Extract the type name from a type_declaration's type_spec child.
local function type_name(node, bufnr)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == "type_spec" then
      for j = 0, child:child_count() - 1 do
        local spec_child = child:child(j)
        if spec_child:type() == "type_identifier" then
          return vim.treesitter.get_node_text(spec_child, bufnr)
        end
      end
    end
  end
  return "?"
end

-- Extract the function name from a function_declaration.
local function func_name(node, bufnr)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == "identifier" then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return "?"
end

-- Extract the method name (field_identifier) and receiver text from a
-- method_declaration.  The receiver is the first parameter_list child;
-- the method name is the field_identifier child.
local function method_info(node, bufnr)
  local name = "?"
  local receiver = ""

  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    local ct = child:type()
    if ct == "field_identifier" then
      name = vim.treesitter.get_node_text(child, bufnr)
    elseif ct == "parameter_list" and receiver == "" then
      -- First parameter_list is the receiver; extract its text and
      -- strip the outer parens for display.
      receiver = vim.treesitter.get_node_text(child, bufnr)
    end
  end

  return name, receiver
end

-- ===========================================================================
-- extract
-- ===========================================================================

function M.extract(captures, query, bufnr)
  local entries = {}

  -- First pass: collect type declarations so we can assign methods
  -- level 2 when their receiver matches a known type.
  local known_types = {}

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    if capture_name == "type_decl" then
      local tname = type_name(cap.node, bufnr)
      known_types[tname] = true
    end
  end

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    local node = cap.node
    local start_row = node:range()
    local lnum = start_row + 1

    local name, level

    if capture_name == "type_decl" then
      name = "type " .. type_name(node, bufnr)
      level = 1

    elseif capture_name == "function" then
      name = "func " .. func_name(node, bufnr)
      level = 1

    elseif capture_name == "method" then
      local mname, receiver = method_info(node, bufnr)
      name = "func " .. receiver .. " " .. mname
      -- Methods whose receiver type (after stripping pointer) is a
      -- known type get level 2; otherwise level 1.
      level = 1
      -- Extract the base type from the receiver, e.g. "(a *Animal)" -> "Animal"
      local base = receiver:match("%*(%w+)") or receiver:match("%s(%w+)")
      if base and known_types[base] then
        level = 2
      end

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
