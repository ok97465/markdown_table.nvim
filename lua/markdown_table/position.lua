local parser = require("markdown_table.parser")

local M = {}

local function max_columns(block)
  local columns = 0
  for _, row in ipairs(block.rows) do
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
  if row_index < 1 then
    row_index = 1
  elseif row_index > #block.rows then
    row_index = #block.rows
  end

  local row = block.rows[row_index]
  if not row.cell_spans or #row.cell_spans == 0 then
    return nil
  end

  local col = math.max(cursor_col or 0, 0)
  for idx, span in ipairs(row.cell_spans) do
    local start_col = span.start_col or 0
    local end_col = span.end_col or start_col
    if col < start_col then
      return clamp_column(total_columns, idx)
    end
    if col < end_col then
      return clamp_column(total_columns, idx)
    end
  end

  return clamp_column(total_columns, #row.cell_spans)
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
  elseif row_index > #block.rows then
    row_index = #block.rows
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

local function targets_from_spans(line, row)
  local spans = row.cell_spans or {}
  if #spans == 0 then
    return {}
  end

  local result = {}
  for idx, span in ipairs(spans) do
    local start_col = span.start_col or 0
    local end_col = span.end_col or start_col
    if end_col < start_col then
      end_col = start_col
    end

    local entry = start_col
    if type(line) == "string" and #line > 0 then
      local segment = line:sub(start_col + 1, math.max(end_col, start_col))
      local non_space = segment:find("%S")
      if non_space then
        entry = start_col + non_space - 1
      elseif end_col > start_col then
        entry = math.min(start_col + 1, end_col)
      end
    end

    result[idx] = {
      left = math.max(start_col - 1, 0),
      right = math.max(end_col, start_col),
      entry = entry,
    }
  end
  return result
end

function M.cell_targets(line, row)
  return targets_from_spans(line, row)
end

return M
