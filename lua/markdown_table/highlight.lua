local state = require("markdown_table.state")

local M = {}

local namespace = vim.api.nvim_create_namespace("markdown_table/highlight")

---Highlight active tables (placeholder for future enhancements).
---@param buf integer
---@param ranges table[]|nil
function M.apply(buf, ranges)
  if not state.config().highlight then
    M.clear(buf)
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  -- No ranges yet; this keeps the API surface ready.
  if not ranges or #ranges == 0 then
    return
  end

  local hl_group = state.config().highlight_group or "CursorLine"
  for _, range in ipairs(ranges) do
    ---@cast range {start_line: integer, end_line: integer}
    vim.api.nvim_buf_set_extmark(buf, namespace, range.start_line, 0, {
      end_row = range.end_line,
      end_col = 0,
      hl_group = hl_group,
      hl_eol = true,
    })
  end
end

function M.clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
end

return M
