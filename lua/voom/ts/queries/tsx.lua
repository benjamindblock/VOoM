-- Treesitter query definition for TSX outlines.
--
-- TSX uses the same grammar as TypeScript with JSX extensions.
-- This module reuses the TypeScript query definition wholesale,
-- overriding only the parser language name.

local ts_query = require("voom.ts.queries.typescript")

local M = {}

for k, v in pairs(ts_query) do
  M[k] = v
end

M.lang = "tsx"

return M
