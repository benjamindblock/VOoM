-- Treesitter query definition for Bash outlines.
--
-- Captures function definitions.  Bash functions are almost always
-- top-level, so all entries are level 1.  Both `name() { ... }` and
-- `function name { ... }` forms use the same `function_definition`
-- node type in the Bash TS grammar.

local M = {}

M.lang = "bash"

M.query_string = [[(function_definition) @function]]

-- ===========================================================================
-- extract
-- ===========================================================================

function M.extract(captures, query, bufnr)
  local entries = {}

  for _, cap in ipairs(captures) do
    local capture_name = query.captures[cap.id]
    if capture_name ~= "function" then
      goto continue
    end

    local node = cap.node
    local start_row = node:range()
    local lnum = start_row + 1

    -- The function name is stored in a `word` child node.
    local name = "?"
    for i = 0, node:child_count() - 1 do
      local child = node:child(i)
      if child:type() == "word" then
        name = vim.treesitter.get_node_text(child, bufnr)
        break
      end
    end

    table.insert(entries, { level = 1, name = name .. "()", lnum = lnum })

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
