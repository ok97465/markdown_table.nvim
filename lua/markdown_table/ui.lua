local state = require("markdown_table.state")
local parser = require("markdown_table.parser")
local highlight = require("markdown_table.highlight")
local indicator = require("markdown_table.indicator")

local M = {}

---Refresh highlight for the currently focused table, clearing when disabled.
---@param buf integer
function M.refresh_highlight(buf)
  if not state.is_active(buf) then
    highlight.clear(buf)
    return
  end

  if not state.config().highlight then
    highlight.clear(buf)
    return
  end

  local ranges = nil
  if buf == vim.api.nvim_get_current_buf() then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local block = parser.block_at(buf, cursor[1] - 1)
    if block then
      ranges = {
        {
          start_line = block.start_line,
          end_line = block.end_line,
        },
      }
    end
  end

  highlight.apply(buf, ranges)
end

---Highlight a specific table block using the configured settings.
---@param buf integer
---@param block {start_line: integer, end_line: integer}|nil
function M.highlight_block(buf, block)
  if not block then
    return
  end

  if not state.config().highlight then
    highlight.clear(buf)
    return
  end

  highlight.apply(buf, {
    {
      start_line = block.start_line,
      end_line = block.end_line,
    },
  })
end

function M.show_indicator(buf)
  indicator.show(buf)
end

function M.hide_indicator(buf)
  indicator.hide(buf)
end

function M.clear_highlight(buf)
  highlight.clear(buf)
end

return M

