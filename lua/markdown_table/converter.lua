local parser = require("markdown_table.parser")
local AlignmentService = require("markdown_table.alignment_service")
local ui = require("markdown_table.ui")
local state = require("markdown_table.state")

local M = {}

local align_service = AlignmentService.new()

local function escape_csv_value(value)
  local text = value or ""
  if text:find('[",\r\n]') then
    text = '"' .. text:gsub('"', '""') .. '"'
  end
  return text
end

local function trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function detect_mode(lines)
  for _, line in ipairs(lines) do
    if line:find(",", 1, true) then
      return "csv"
    end
  end
  return "whitespace"
end

local function split_csv(line)
  local cells = {}
  local current = {}
  local quoted = false
  local in_quotes = false
  local len = #line
  local idx = 1

  local function push_cell()
    local value = table.concat(current)
    if quoted then
      value = value:gsub('""', '"')
    else
      value = trim(value)
    end
    cells[#cells + 1] = value
    current = {}
    quoted = false
  end

  while idx <= len do
    local ch = line:sub(idx, idx)
    if ch == '"' then
      if not in_quotes and #current == 0 then
        in_quotes = true
        quoted = true
      elseif in_quotes and idx < len and line:sub(idx + 1, idx + 1) == '"' then
        current[#current + 1] = '"'
        idx = idx + 1
      elseif in_quotes then
        in_quotes = false
      else
        current[#current + 1] = ch
      end
    elseif ch == "," and not in_quotes then
      push_cell()
    else
      current[#current + 1] = ch
    end
    idx = idx + 1
  end

  push_cell()
  return cells
end

local function split_whitespace(line)
  local stripped = trim(line)
  if stripped == "" then
    return {}
  end
  return vim.split(stripped, "%s+", { trimempty = true })
end

local function parse_rows(lines)
  local mode = detect_mode(lines)
  local rows = {}

  for _, line in ipairs(lines) do
    local stripped = trim(line)
    if stripped ~= "" then
      local cells
      if mode == "csv" then
        cells = split_csv(line)
      else
        cells = split_whitespace(line)
      end
      rows[#rows + 1] = cells
    end
  end

  if #rows == 0 then
    return nil, "markdown_table: no non-empty lines selected"
  end

  local column_count = 0
  for _, row in ipairs(rows) do
    if #row > column_count then
      column_count = #row
    end
  end

  if column_count == 0 then
    return nil, "markdown_table: selection did not contain any fields"
  end

  return rows, column_count
end

local function make_table_lines(rows, columns)
  local function pad_row(values)
    local cells = {}
    for col = 1, columns do
      local value = values[col]
      if value == nil then
        value = ""
      end
      cells[col] = value
    end
    return cells
  end

  local function build_line(values)
    return "| " .. table.concat(values, " | ") .. " |"
  end

  local lines = {}
  lines[#lines + 1] = build_line(pad_row(rows[1]))

  local separator = {}
  for col = 1, columns do
    separator[col] = "---"
  end
  lines[#lines + 1] = build_line(separator)

  for idx = 2, #rows do
    lines[#lines + 1] = build_line(pad_row(rows[idx]))
  end

  return lines
end

---Build CSV lines for the supplied table block.
---@param block table
---@return string[]|nil, string|nil
local function csv_lines_from_block(block)
  local max_columns = 0
  for _, row in ipairs(block.rows) do
    if row.kind ~= "separator" and #row.cells > max_columns then
      max_columns = #row.cells
    end
  end

  if max_columns == 0 then
    return nil, "markdown_table: table block does not contain any data rows"
  end

  local csv_lines = {}
  for _, row in ipairs(block.rows) do
    if row.kind ~= "separator" then
      local values = {}
      for col = 1, max_columns do
        local cell = row.cells[col]
        local text = cell and cell.text or ""
        values[col] = escape_csv_value(text)
      end
      csv_lines[#csv_lines + 1] = table.concat(values, ",")
    end
  end

  if #csv_lines == 0 then
    return nil, "markdown_table: table block does not contain convertible rows"
  end

  return csv_lines, nil
end

---Convert a range of lines into a markdown table inserted after the range.
---@param buf integer
---@param first_line integer 0-based inclusive
---@param last_line integer 0-based inclusive
---@return boolean
function M.insert_from_range(buf, first_line, last_line)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  if last_line < first_line then
    first_line, last_line = last_line, first_line
  end

  local lines = vim.api.nvim_buf_get_lines(buf, first_line, last_line + 1, false)
  local rows, columns = parse_rows(lines)
  if not rows then
    vim.notify(columns or "markdown_table: unable to parse selection", vim.log.levels.WARN)
    return false
  end

  local table_lines = make_table_lines(rows, columns)
  if #table_lines == 0 then
    vim.notify("markdown_table: failed to build table from selection", vim.log.levels.WARN)
    return false
  end

  local last_selected = lines[#lines]
  local add_blank = last_selected ~= nil and not last_selected:match("^%s*$")
  local insertion_index = last_line + 1

  local to_insert = {}
  if add_blank then
    to_insert[#to_insert + 1] = ""
  end
  for _, line in ipairs(table_lines) do
    to_insert[#to_insert + 1] = line
  end

  vim.api.nvim_buf_set_lines(buf, insertion_index, insertion_index, false, to_insert)

  local table_start = insertion_index + (add_blank and 1 or 0)
  local block = parser.block_at(buf, table_start)
  if block then
    align_service:align_block(buf, block, {
      record_undo = false,
      on_success = function()
        ui.highlight_block(buf, block)
      end,
      on_noop = function(_, _, reason)
        if reason == "unchanged" then
          ui.highlight_block(buf, block)
        end
      end,
    })
  end

  if state.is_active(buf) then
    ui.show_indicator(buf)
  end
  state.record_undo_state(buf)
  return true
end

---Insert CSV lines derived from the supplied table block directly after the block.
---@param buf integer
---@param block table
---@return boolean
function M.insert_csv_after_block(buf, block)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local csv_lines, err = csv_lines_from_block(block)
  if not csv_lines then
    vim.notify(err or "markdown_table: unable to convert table to CSV", vim.log.levels.WARN)
    return false
  end

  local insertion_index = block.end_line
  vim.api.nvim_buf_set_lines(buf, insertion_index, insertion_index, false, csv_lines)

  state.record_undo_state(buf)
  return true
end

return M
