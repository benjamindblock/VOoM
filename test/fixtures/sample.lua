function top_level()
  return 1
end

local function helper()
  return 2
end

local M = {}

function M.setup(opts)
  M.opts = opts
end

M.run = function()
  return true
end

local cb = function()
  return false
end

function M.nested()
  local function inner()
    return 3
  end
  return inner
end

return M
