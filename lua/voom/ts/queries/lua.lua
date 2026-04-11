-- Treesitter query definition for Lua outlines.
--
-- Captures three forms of function definition:
--
--   1. Named function declarations:  function foo() ... end
--      Also covers local functions:  local function bar() ... end
--      (the Lua TS grammar uses `function_declaration` for both)
--
--   2. Dot-indexed declarations:     function M.setup() ... end
--      (also `function_declaration`, with a `dot_index_expression` name)
--
--   3. Assignment-based functions:   M.setup = function() ... end
--      (an `assignment_statement` or `variable_declaration` whose RHS
--      is a `function_definition`)
--
-- Display names mirror the source: `M.setup`, `local bar`, `foo`.

local M = {}

M.lang = "lua"

M.query_string = [[
(function_declaration) @function_decl
(variable_declaration
  (assignment_statement
    (expression_list
      (function_definition)))) @var_func
(assignment_statement
  (expression_list
    (function_definition))) @assign_func
]]

-- ===========================================================================
-- Private helpers
-- ===========================================================================

-- Count ancestor nodes that are themselves function declarations or
-- assignment-based function definitions.  This gives structural nesting
-- depth (0 = top-level).
local function structural_depth(node)
  local count = 0
  local parent = node:parent()
  while parent do
    local pt = parent:type()
    if pt == "function_declaration" or pt == "function_definition" then
      count = count + 1
    end
    parent = parent:parent()
  end
  return count
end

-- Extract the display name from a function_declaration node.
-- Returns the name string and whether the function is local.
local function decl_name(node, bufnr)
  local is_local = false
  local name_node = nil

  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    local ct = child:type()
    if ct == "local" then
      is_local = true
    elseif ct == "identifier" or ct == "dot_index_expression" then
      name_node = child
    end
  end

  if name_node then
    local text = vim.treesitter.get_node_text(name_node, bufnr)
    if is_local then
      return "local " .. text
    end
    return text
  end

  return is_local and "local ?" or "?"
end

-- Extract the LHS name from an assignment_statement or
-- variable_declaration that wraps a function_definition.
local function assignment_name(node, bufnr)
  local is_local = false
  local nt = node:type()

  if nt == "variable_declaration" then
    is_local = true
    -- The actual assignment_statement is the child
    for i = 0, node:child_count() - 1 do
      local child = node:child(i)
      if child:type() == "assignment_statement" then
        node = child
        break
      end
    end
  end

  -- Find the variable_list to get the LHS name
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == "variable_list" then
      local text = vim.treesitter.get_node_text(child, bufnr)
      if is_local then
        return "local " .. text
      end
      return text
    end
  end

  return is_local and "local ?" or "?"
end

-- ===========================================================================
-- extract
-- ===========================================================================

function M.extract(captures, query, bufnr)
  local entries = {}
  -- Track which lines we've already emitted to avoid duplicates.
  -- A `variable_declaration` containing an `assignment_statement` with a
  -- function RHS will match both @var_func and @assign_func; we only
  -- want the outermost one.
  local seen = {}

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    local node = cap.node
    local start_row = node:range()
    local lnum = start_row + 1

    -- Skip duplicates: if we already have an entry at this line, the
    -- outermost capture (variable_declaration) was already processed.
    if seen[lnum] then
      goto continue
    end

    local name, level

    if capture_name == "function_decl" then
      name = decl_name(node, bufnr)
      level = structural_depth(node) + 1

    elseif capture_name == "var_func" or capture_name == "assign_func" then
      name = assignment_name(node, bufnr)
      level = structural_depth(node) + 1

    else
      goto continue
    end

    seen[lnum] = true
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
