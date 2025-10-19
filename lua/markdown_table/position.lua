local parser = require("markdown_table.parser")

local M = {}

local function max_columns(block)
  local columns = 0
  for _, row in ipairs(block.rows or {}) do
    if row.cells and #row.cells > columns then
      columns = #row.cells
    end
    if row.alignments and #row.alignments > columns then
      columns = #row.alignments
    end
  end
  return columns
end

local function clamp_column(count, index)
  if count == 0 then
    return nil
  end
  if index < 1 then
    return 1
  end
  if index > count then
    return count
  end
  return index
end

local function column_from_cursor(block, cursor_row, cursor_col, total_columns)
  if total_columns == 0 then
    return nil
  end

  local row_index = cursor_row - block.start_line + 1
  if row_index < 1 or row_index > #block.lines then
    row_index = 1
  end

  local line = block.lines[row_index]
  if not line then
    return nil
  end

  local col = math.max(cursor_col or 0, 0)
  local upto
  if col >= #line then
    upto = line
  else
    upto = line:sub(1, col + 1)
  end

  local pipe_count = select(2, upto:gsub("%|", ""))
  if pipe_count == 0 then
    return 1
  end

  return clamp_column(total_columns, pipe_count)
end

local function compute_entry_target(line, left_pipe, right_pipe)
  if left_pipe + 1 >= right_pipe then
    return left_pipe
  end

  local content = line:sub(left_pipe + 1, right_pipe - 1)
  local first_non_space = content:find("%S")
  if first_non_space then
    return left_pipe + first_non_space
  end

  local fallback = left_pipe + 2
  if fallback > right_pipe - 1 then
    fallback = right_pipe - 1
  end
  if fallback < left_pipe + 1 then
    fallback = left_pipe + 1
  end
  return fallback
end

function M.max_columns(block)
  return max_columns(block)
end

function M.column_from_cursor(block, cursor_row, cursor_col, total_columns)
  return column_from_cursor(block, cursor_row, cursor_col, total_columns)
end

function M.locate(buf, cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  if type(cursor) ~= "table" or #cursor < 2 then
    return nil
  end

  local absolute_row = cursor[1] - 1
  local block = parser.block_at(buf, absolute_row)
  if not block then
    return nil
  end

  local total_columns = max_columns(block)
  if total_columns == 0 then
    return nil
  end

  local column = column_from_cursor(block, absolute_row, cursor[2], total_columns)
  if not column then
    return nil
  end

  local row_index = absolute_row - block.start_line + 1
  if row_index < 1 then
    row_index = 1
  elseif row_index > #block.lines then
    row_index = #block.lines
  end

  return {
    block = block,
    total_columns = total_columns,
    column = column,
    row = row_index,
    cursor = {
      line = cursor[1],
      col = cursor[2],
    },
    absolute_row = absolute_row,
  }
end

function M.cell_targets(line)
  if type(line) ~= "string" then
    return {}
  end

  local pipe_positions = {}
  local search_start = 1
  while true do
    local idx = line:find("|", search_start, true)
    if not idx then
      break
    end
    pipe_positions[#pipe_positions + 1] = idx
    search_start = idx + 1
  end

  if #pipe_positions < 2 then
    return {}
  end

  local cells = {}
  for i = 1, #pipe_positions - 1 do
    local left_pipe = pipe_positions[i]
    local right_pipe = pipe_positions[i + 1]
    local entry = compute_entry_target(line, left_pipe, right_pipe)
    cells[i] = {
      left = left_pipe - 1,
      right = right_pipe - 1,
      entry = entry - 1,
    }
  end
  return cells
end

return M
