local M = {}

local defaults = {
  highlight = true,
  highlight_group = "CursorLine",
  auto_align = true,
  debounce_ms = 120,
}

local buffers = setmetatable({}, { __mode = "k" })

---Fetch or initialize buffer scoped state.
---@param buf integer
---@return table
local function ensure(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error("markdown_table: invalid buffer id " .. tostring(buf))
  end

  local entry = buffers[buf]
  if not entry then
    entry = {
      active = false,
      options = {},
    }
    buffers[buf] = entry
  end
  return entry
end

function M.setup(opts)
  defaults = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.config()
  return defaults
end

function M.current_buffers()
  local list = {}
  for buf, data in pairs(buffers) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      list[#list + 1] = { buf = buf, data = data }
    end
  end
  return list
end

function M.data(buf)
  return ensure(buf)
end

function M.is_active(buf)
  return ensure(buf).active
end

function M.set_active(buf, active)
  ensure(buf).active = active
end

return M
