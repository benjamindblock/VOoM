-- Treesitter query definition for Python outlines.
--
-- Captures classes, functions, and decorated definitions at all nesting depths.
-- Methods, nested functions, and nested classes are distinguished by their
-- structural nesting level (number of class/function ancestors).
--
-- Each entry returned by extract() carries:
--   level  int     structural depth (1 = top-level, 2 = inside class/function, …)
--   name   string  display name: "class ClassName" or "def func_name(...)"
--   lnum   int     1-indexed body line of the definition (or decorator for
--                  decorated_definition nodes)

local M = {}

M.lang = "python"

-- Capture all three node kinds with distinct capture names so extract() can
-- route them through the right display-name logic.
M.query_string = [[(class_definition) @class
(function_definition) @function
(decorated_definition) @decorated]]

-- ===========================================================================
-- Private helpers
-- ===========================================================================

-- Walk up the ancestor chain and count how many class or function definition
-- nodes exist above `node`.  Returns 0 for top-level definitions.
--
-- We count only class_definition and function_definition (not
-- decorated_definition) so that a decorated class or function at top-level
-- still gets level 1, and a decorated method inside a class still gets level 2.
local function structural_depth(node)
  local count = 0
  local parent = node:parent()
  while parent do
    local pt = parent:type()
    if pt == "class_definition" or pt == "function_definition" then
      count = count + 1
    end
    parent = parent:parent()
  end
  return count
end

-- Return the text of the first `identifier` child of `node`.  For both
-- class_definition and function_definition, this is the declared name.
local function def_name(node, bufnr)
  for i = 0, node:child_count() - 1 do
    local child = node:child(i)
    if child:type() == "identifier" then
      return vim.treesitter.get_node_text(child, bufnr)
    end
  end
  return "?"
end

-- Derive display name and level for a class or function definition node.
local function entry_for_def(node, node_type, bufnr)
  local name
  if node_type == "class_definition" then
    name = "class " .. def_name(node, bufnr)
  else
    name = "def " .. def_name(node, bufnr) .. "(...)"
  end
  return name, structural_depth(node) + 1
end

-- ===========================================================================
-- extract
-- ===========================================================================

function M.extract(captures, query, bufnr)
  local entries = {}

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    local node = cap.node
    local node_type = node:type()

    -- Skip class/function definitions that are direct children of a
    -- decorated_definition — the decorated_definition node is already
    -- captured separately and will be emitted in their place.
    if node_type == "class_definition" or node_type == "function_definition" then
      local parent = node:parent()
      if parent and parent:type() == "decorated_definition" then
        goto continue
      end
    end

    local name, level
    local start_row = node:range()  -- returns start_row, start_col, end_row, end_col
    local lnum = start_row + 1      -- convert 0-indexed row → 1-indexed line

    if node_type == "class_definition" or node_type == "function_definition" then
      name, level = entry_for_def(node, node_type, bufnr)

    elseif node_type == "decorated_definition" then
      -- Find the inner class or function definition to derive the display name.
      -- The decorator nodes come first; the class/function is always last.
      local inner_node, inner_type
      for i = 0, node:child_count() - 1 do
        local child = node:child(i)
        local ct = child:type()
        if ct == "class_definition" or ct == "function_definition" then
          inner_node = child
          inner_type = ct
          break
        end
      end

      -- Decorated_definitions that wrap neither a class nor function are
      -- unusual (parser bug?); skip them safely.
      if not inner_node then
        goto continue
      end

      -- The decorated_definition node's start row is the first decorator
      -- line — that is the right lnum to use so the tree entry jumps the
      -- user to the whole definition including its decorators.
      --
      -- Level is computed from the decorated_definition node itself, not
      -- the inner node, to count structural ancestors correctly.
      level = structural_depth(node) + 1
      name, _ = entry_for_def(inner_node, inner_type, bufnr)
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

-- Python outlines have no Markdown-style heading markers, so use_hash and
-- use_close_hash are always false.
function M.outline_state(_entries, _lines)
  return { use_hash = false, use_close_hash = false }
end

return M
