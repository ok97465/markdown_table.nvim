local M = {}

local function lines_equal(a, b)
  if #a ~= #b then
    return false
  end
  for idx = 1, #a do
    if a[idx] ~= b[idx] then
      return false
    end
  end
  return true
end

---Replace buffer lines only when content changes.
---@param buf integer
---@param start_line integer
---@param end_line integer
---@param lines string[]
---@param opts {undojoin: boolean|nil}|nil
---@return boolean changed
function M.replace(buf, start_line, end_line, lines, opts)
  local existing = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
  if lines_equal(existing, lines) then
    return false
  end

  opts = opts or {}
  if opts.undojoin then
    pcall(vim.api.nvim_buf_call, buf, function()
      pcall(vim.cmd, "silent! undojoin")
    end)
  end

  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, lines)
  return true
end

return M
