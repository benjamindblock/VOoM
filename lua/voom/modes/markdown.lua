-- Markdown mode for VOoM: parses Markdown headings and builds an outline tree.
--
-- This module is a Lua port of the outline-generation logic from the legacy
-- Python implementation in:
--   legacy/autoload/voom/voom_vimplugin2657/voom_mode_markdown.py
--
-- Scope for this port: make_outline (hook_makeOutline equivalent) only.
-- The editing hooks (hook_newHeadline, hook_doBodyAfterOop) are deferred to
-- later tasks.
--
-- TODO: root node contract — the Python hook_makeOutline did NOT prepend a
-- root node (the buffer name at level 1, bnode 1). The caller in voom.py
-- injected it separately. make_outline follows the same contract: callers are
-- responsible for prepending the root node when building the full tree.

local M = {}

-- Maps heading level (int) -> underline character, for the two underline-style
-- heading levels that Markdown supports.
M.LEVELS_ADS = { [1] = "=", [2] = "-" }

-- Maps underline character -> heading level (inverse of LEVELS_ADS).
M.ADS_LEVELS = { ["="] = 1, ["-"] = 2 }

-- ==============================================================================
-- Private helpers
-- ==============================================================================

-- Return true if `s` is a non-empty string consisting entirely of '=' or '-'.
-- These are the only two adornment characters Markdown defines for underline-
-- style (setext) headings.
local function is_adornment(s)
  if s == "" then
    return false
  end
  local ch = s:sub(1, 1)
  if ch ~= "=" and ch ~= "-" then
    return false
  end
  -- Match the entire string against repetitions of that single character.
  return s:match("^" .. ch .. "+$") ~= nil
end

-- Strip leading and trailing whitespace from `s`.
local function strip(s)
  return s:match("^%s*(.-)%s*$")
end

-- ==============================================================================
-- Public API
-- ==============================================================================

-- Parse Markdown headings from `lines` and return outline data.
--
-- Recognises two heading styles:
--
--   Hash-style (levels 1–6):
--     ## My Heading
--     ## My Heading ##   (optional closing hashes)
--
--   Underline-style / setext (levels 1–2 only):
--     My Heading
--     ==========         (level 1)
--
--     My Heading
--     ----------         (level 2)
--
-- @param lines    table   1-indexed array of strings (buffer lines)
-- @param buf_name string  display name for the buffer (unused during parsing;
--                         included so the caller contract matches across modes)
-- @return table
--   {
--     tlines        = { string },  -- formatted tree display lines
--     bnodes        = { int    },  -- 1-indexed body line numbers for each node
--     levels        = { int    },  -- heading depth (1–6) for each node
--     use_hash      = bool,        -- true if first level-1/2 heading used '#' style
--     use_close_hash = bool,       -- true if first hash heading had closing '#'
--   }
function M.make_outline(lines, buf_name)
  local tlines = {}
  local bnodes = {}
  local levels = {}

  -- Style preference flags: detected from the first heading at level 1 or 2.
  -- We use a separate `_set` boolean so we can distinguish "not yet seen" from
  -- "seen and false" — replacing the Python implementation's 0/1/2 sentinel
  -- integer pattern with an explicit two-variable form.
  local use_hash = false
  local use_hash_set = false
  local use_close_hash = true -- default matches Python: assume closing hashes
  local use_close_hash_set = false

  local Z = #lines

  -- Seed the look-ahead variable with the first line so the loop body can
  -- always reference both L1 (current) and L2 (next) without a bounds check.
  -- Trailing whitespace is stripped once here so we don't repeat it inside.
  local L2 = Z > 0 and lines[1]:gsub("%s+$", "") or ""

  for i = 1, Z do
    local L1 = L2
    -- Advance the look-ahead: strip trailing whitespace to simplify comparisons.
    L2 = (i + 1 <= Z) and lines[i + 1]:gsub("%s+$", "") or ""

    -- Blank lines are never headings; skip immediately.
    if L1 == "" then
      goto continue
    end

    local lev, head

    if is_adornment(L2) then
      -- ===========================================================
      -- Underline-style heading: L1 is the title, L2 is the adornment.
      -- ===========================================================
      lev = M.ADS_LEVELS[L2:sub(1, 1)]
      head = strip(L1)

      -- Consume the adornment by blanking the look-ahead so the next
      -- iteration does not re-read the adornment line as a title candidate.
      -- This mirrors the `L2 = ''` sentinel in the Python implementation.
      L2 = ""

      -- Record style preference the first time we observe a level-1 or
      -- level-2 heading.
      if not use_hash_set then
        use_hash = false
        use_hash_set = true
      end
    elseif L1:sub(1, 1) == "#" then
      -- ===========================================================
      -- Hash-style heading: count leading '#' characters for the level.
      -- ===========================================================
      local hashes = L1:match("^(#+)")
      lev = #hashes

      -- Strip leading hashes and spaces, then trailing spaces and optional
      -- closing hashes. This handles "## heading", "## heading ##", and the
      -- degenerate "## heading##" that Python's str.strip('#') would also clean.
      head = L1:gsub("^#+%s*", ""):gsub("%s*#+%s*$", "")

      -- Record hash-style preference the first time we see a level-1 or
      -- level-2 heading.
      if not use_hash_set and lev < 3 then
        use_hash = true
        use_hash_set = true
      end

      -- Record whether closing hashes are present, from the first hash
      -- heading of any level.
      if not use_close_hash_set then
        use_close_hash = L1:sub(-1) == "#"
        use_close_hash_set = true
      end
    else
      -- Not a heading line; skip.
      goto continue
    end

    -- Format the tree display line. Indentation is two leading spaces plus
    -- one ". " pair per level beyond 1, followed by "|" and the heading text.
    -- Example: level 3 → "  . . |My Heading"
    table.insert(tlines, "  " .. string.rep(". ", lev - 1) .. "|" .. head)
    table.insert(bnodes, i)
    table.insert(levels, lev)

    ::continue::
  end

  return {
    tlines = tlines,
    bnodes = bnodes,
    levels = levels,
    use_hash = use_hash,
    use_close_hash = use_close_hash,
  }
end

return M
