local position = require("markdown_table.position")

local M = {}

local function move(buf, cursor, delta)
  buf = buf or vim.api.nvim_get_current_buf()
  cursor = cursor or vim.api.nvim_win_get_cursor(0)

  local info = position.locate(buf, cursor)
  if not info then
    return false
  end

  local line = info.block.lines[info.row]
  if not line then
    return false
  end

  local cells = position.cell_targets(line)
  if #cells == 0 then
    return false
  end

  local target_column = info.column + delta
  if target_column < 1 or target_column > #cells then
    return false
  end

  local target = cells[target_column]
  if not target or type(target.entry) ~= "number" then
    return false
  end

  local win = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    win = 0
  end

  local new_col = math.max(target.entry, 0)
  vim.api.nvim_win_set_cursor(win, { info.cursor.line, new_col })
  return true
end

function M.move_left(buf, cursor)
  return move(buf, cursor, -1)
end

function M.move_right(buf, cursor)
  return move(buf, cursor, 1)
end

return M
