local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")

local M = {}

local function clone_alignment(info)
  if type(info) ~= "table" then
    return nil
  end
  return {
    align = info.align,
    colon_left = info.colon_left,
    colon_right = info.colon_right,
  }
end

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

local function ensure_cells(row, count)
  row.cells = row.cells or {}
  while #row.cells < count do
    row.cells[#row.cells + 1] = { raw = "", text = "" }
  end
end

local function ensure_alignment_slots(row, count)
  if not row.alignments then
    return
  end
  while #row.alignments < count do
    row.alignments[#row.alignments + 1] = false
  end
end

local function insert_alignment(row, column, template)
  if not row.alignments then
    return
  end
  ensure_alignment_slots(row, column - 1)
  local value = false
  if row.kind == "separator" and template then
    value = clone_alignment(template)
  end
  table.insert(row.alignments, column, value)
end

---Fetch alignment metadata and token to reuse for a newly inserted column.
---@param block table
---@param index integer|nil
---@return {meta: table|nil, token: string|nil}|nil
local function alignment_template(block, index)
  if not index then
    return nil
  end
  for _, row in ipairs(block.rows or {}) do
    if row.kind == "separator" then
      local meta = nil
      if row.alignments and row.alignments[index] then
        meta = clone_alignment(row.alignments[index])
      end
      local token = nil
      if row.cells and row.cells[index] and row.cells[index].text and row.cells[index].text ~= "" then
        token = row.cells[index].text
      end
      if meta or token then
        return { meta = meta, token = token }
      end
    end
  end
  return nil
end

local function write_block(buf, block)
  local lines = aligner.align_block(block)
  if not lines then
    return false
  end
  vim.api.nvim_buf_set_lines(buf, block.start_line, block.end_line, false, lines)
  return true
end

local function adjust_block(buf, cursor, mutate)
  local row = cursor[1] - 1
  local block = parser.block_at(buf, row)
  if not block then
    return false
  end

  local total_columns = max_columns(block)
  if total_columns == 0 then
    return false
  end

  local column = column_from_cursor(block, row, cursor[2], total_columns)
  if not column then
    return false
  end

  local ok = mutate(block, column, total_columns)
  if not ok then
    return false
  end

  return write_block(buf, block)
end

function M.delete(buf, cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  return adjust_block(buf, cursor, function(block, column, total_columns)
    if total_columns <= 1 then
      return false
    end

    for _, row in ipairs(block.rows) do
      if row.cells and column <= #row.cells then
        table.remove(row.cells, column)
      end
      if row.alignments and column <= #row.alignments then
        table.remove(row.alignments, column)
      end
    end

    return true
  end)
end

---Insert a blank column into the parsed table block.
---@param block table
---@param column integer
---@param opts {template: {meta: table|nil, token: string|nil}|nil}|nil
local function insert_column(block, column, opts)
  opts = opts or {}
  local template = opts.template or {}

  for _, row in ipairs(block.rows) do
    if row.cells then
      ensure_cells(row, column - 1)
      local cell = { raw = "", text = "" }
      if row.kind == "separator" and template.token then
        cell = { raw = template.token, text = template.token }
      end
      table.insert(row.cells, column, cell)
    end
    insert_alignment(row, column, template.meta)
  end
end

function M.insert_left(buf, cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  return adjust_block(buf, cursor, function(block, column)
    local template = alignment_template(block, column)
    insert_column(block, column, { template = template })
    return true
  end)
end

function M.insert_right(buf, cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  return adjust_block(buf, cursor, function(block, column, total_columns)
    local target_index = math.min(column + 1, total_columns + 1)
    local template = alignment_template(block, column)
    insert_column(block, target_index, { template = template })
    return true
  end)
end

return M
