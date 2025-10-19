local AlignmentService = require("markdown_table.alignment_service")
local position = require("markdown_table.position")

local M = {}
local align_service = AlignmentService.new()

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
  return align_service:align_block(buf, block, { record_undo = false })
end

local function adjust_block(buf, cursor, mutate)
  local context = position.locate(buf, cursor)
  if not context then
    return false
  end

  local ok = mutate(context.block, context.column, context.total_columns)
  if not ok then
    return false
  end

  return write_block(buf, context.block)
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
