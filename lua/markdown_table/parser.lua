local M = {}

---Check whether a string likely represents a markdown table row.
---@param line string|nil
---@return boolean
local function is_table_line(line)
  if not line or line:match("^%s*$") then
    return false
  end

  local pipe_count = select(2, line:gsub("%|", ""))
  if pipe_count < 2 then
    return false
  end

  -- Require at least one visible character between pipes to avoid headings.
  if not line:match("%|%s*[^%s|][^|]*%|") then
    return false
  end

  return true
end

local function trim(text)
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function parse_alignment(text)
  local stripped = trim(text)
  if stripped == "" then
    return nil
  end

  if not stripped:match("^:?-+:?$") then
    return nil
  end

  local left = stripped:sub(1, 1) == ":"
  local right = stripped:sub(-1, -1) == ":"
  local align
  if left and right then
    align = "center"
  elseif right then
    align = "right"
  elseif left then
    align = "left"
  else
    align = "none"
  end

  return {
    align = align,
    colon_left = left,
    colon_right = right,
  }
end

---Parse a single markdown table line into cells.
---@param line string
---@return table row
local function parse_row(line)
  local indent = line:match("^%s*") or ""
  local content = line:sub(#indent + 1)

  -- Remove trailing pipe and whitespace for consistent parsing.
  content = content:gsub("%s+$", "")
  if content:sub(1, 1) == "|" then
    content = content:sub(2)
  end
  if content:sub(-1, -1) == "|" then
    content = content:sub(1, -2)
  end

  local cells = vim.split(content, "|", { plain = true })
  local parsed_cells = {}
  for _, cell in ipairs(cells) do
    table.insert(parsed_cells, {
      raw = cell,
      text = trim(cell),
    })
  end

  local alignments = {}
  local separator = true
  for idx, cell in ipairs(parsed_cells) do
    local info = parse_alignment(cell.text)
    alignments[idx] = info
    if not info then
      separator = false
    end
  end

  local kind = separator and "separator" or "data"
  return {
    indent = indent,
    raw = line,
    kind = kind,
    cells = parsed_cells,
    alignments = alignments,
  }
end

---Collect a contiguous table block around `row`.
---@param buf integer
---@param row integer 0-based row
---@return {start_line: integer, end_line: integer, lines: string[], rows: table[]}|nil
function M.block_at(buf, row)
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if row < 0 or row >= line_count then
    return nil
  end

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not is_table_line(line) then
    return nil
  end

  local first = row
  while first > 0 do
    local prev = vim.api.nvim_buf_get_lines(buf, first - 1, first, false)[1]
    if not is_table_line(prev) then
      break
    end
    first = first - 1
  end

  local last = row
  while last < line_count - 1 do
    local next_line = vim.api.nvim_buf_get_lines(buf, last + 1, last + 2, false)[1]
    if not is_table_line(next_line) then
      break
    end
    last = last + 1
  end

  local lines = vim.api.nvim_buf_get_lines(buf, first, last + 1, false)
  local rows = {}
  for _, row_line in ipairs(lines) do
    table.insert(rows, parse_row(row_line))
  end

  return {
    start_line = first,
    end_line = last + 1,
    lines = lines,
    rows = rows,
  }
end

return M
