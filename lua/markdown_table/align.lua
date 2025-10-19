local M = {}

local strwidth = vim.strwidth or vim.fn.strdisplaywidth
-- Ensure freshly inserted columns render with a visible six-character cell (width + padding).
local MIN_EMPTY_COLUMN_WIDTH = 4
local space_cache = { [0] = "" }

local ALIGN_DEFAULT = -1
local ALIGN_LEFT = 0
local ALIGN_RIGHT = 1
local ALIGN_CENTER = 2
local NON_ASCII_PATTERN = "[\128-\255]"

local function spaces(count)
  if count <= 0 then
    return ""
  end
  local cached = space_cache[count]
  if cached then
    return cached
  end
  local value = string.rep(" ", count)
  space_cache[count] = value
  return value
end

local function calc_width(text)
  -- Use an ASCII fast path to avoid the expensive vim.strwidth call when possible.
  if text == "" then
    return 0
  end
  if not text:find(NON_ASCII_PATTERN) then
    return #text
  end
  return strwidth(text)
end

local function pad_cell(text, text_width, width, align_mode)
  local content = text or ""
  local display_width = text_width or 0
  if display_width == 0 and content ~= "" then
    display_width = calc_width(content)
  end
  local excess = width - display_width
  if excess < 0 then
    excess = 0
  end

  if align_mode == ALIGN_RIGHT then
    return spaces(excess) .. content
  elseif align_mode == ALIGN_CENTER then
    local left = math.ceil(excess / 2)
    local right = excess - left
    return spaces(left) .. content .. spaces(right)
  else
    return content .. spaces(excess)
  end
end

local function separator_token(width, colon_left, colon_right)
  local colon_count = 0
  if colon_left then
    colon_count = colon_count + 1
  end
  if colon_right then
    colon_count = colon_count + 1
  end
  local dash_count = width - colon_count
  if dash_count < 1 then
    dash_count = 1
  end
  local body = string.rep("-", dash_count)
  local token = body
  if colon_left then
    token = ":" .. token
  end
  if colon_right then
    token = token .. ":"
  end
  return token
end

---Compute column metadata from parsed rows.
---@param rows table[]
---@return integer[] widths, integer[] align_modes, boolean[] colon_left, boolean[] colon_right
local function analyze_columns(rows)
  local column_count = 0
  for idx = 1, #rows do
    local row = rows[idx]
    local cells = row.cells
    if cells and #cells > column_count then
      column_count = #cells
    end
  end

  local align_modes = {}
  local colon_left = {}
  local colon_right = {}
  local data_widths = {}
  local has_content = {}
  for col = 1, column_count do
    align_modes[col] = ALIGN_DEFAULT
    colon_left[col] = false
    colon_right[col] = false
    data_widths[col] = 0
    has_content[col] = false
  end

  for row_idx = 1, #rows do
    local row = rows[row_idx]
    if row.kind == "separator" then
      local alignments = row.alignments
      if alignments then
        for idx = 1, #alignments do
          local info = alignments[idx]
          if info then
            local align = info.align
            if align == "center" then
              align_modes[idx] = ALIGN_CENTER
            elseif align == "right" then
              align_modes[idx] = ALIGN_RIGHT
            elseif align == "left" then
              align_modes[idx] = ALIGN_LEFT
            else
              align_modes[idx] = ALIGN_DEFAULT
            end
            colon_left[idx] = info.colon_left and true or false
            colon_right[idx] = info.colon_right and true or false
          end
        end
      end
    elseif row.cells then
      local cells = row.cells
      for idx = 1, #cells do
        local cell = cells[idx]
        local text = cell.text or ""
        local width = cell.display_width
        if not width then
          width = calc_width(text)
          cell.display_width = width
        end
        if width > (data_widths[idx] or 0) then
          data_widths[idx] = width
        end
        if text ~= "" then
          has_content[idx] = true
        end
      end
    end
  end

  local widths = {}
  for idx = 1, column_count do
    local data_width = data_widths[idx] or 0
    local colon_count = 0
    if colon_left[idx] then
      colon_count = colon_count + 1
    end
    if colon_right[idx] then
      colon_count = colon_count + 1
    end

    local width = data_width
    local mode = align_modes[idx]
    if mode == ALIGN_RIGHT or mode == ALIGN_LEFT then
      width = data_width + 2
    elseif mode == ALIGN_CENTER then
      width = math.max(data_width, colon_count * 2)
    end

    if colon_count > 0 then
      width = math.max(width, colon_count * 2)
    end

    if not has_content[idx] then
      width = math.max(width, MIN_EMPTY_COLUMN_WIDTH)
    end

    width = math.max(width, colon_count + 1)
    widths[idx] = width
  end

  return widths, align_modes, colon_left, colon_right
end

---Format parsed rows into aligned markdown table strings.
---@param block {rows: table[]}
---@return string[]|nil
function M.align_block(block)
  if not block or not block.rows or #block.rows == 0 then
    return nil
  end

  local rows = block.rows
  local widths, align_modes, colon_left, colon_right = analyze_columns(rows)
  local column_count = widths and #widths or 0
  local lines = {}

  for row_idx = 1, #rows do
    local row = rows[row_idx]
    local cells = {}
    if row.kind == "separator" then
      for idx = 1, column_count do
        local token = separator_token(widths[idx], colon_left[idx], colon_right[idx])
        cells[idx] = " " .. token .. " "
      end
    else
      local row_cells = row.cells
      for idx = 1, column_count do
        local cell = row_cells and row_cells[idx] or nil
        local cell_text = cell and cell.text or ""
        local cell_width = cell and cell.display_width or 0
        local padded = pad_cell(cell_text, cell_width, widths[idx], align_modes[idx] or ALIGN_DEFAULT)
        cells[idx] = " " .. padded .. " "
      end
    end

    lines[row_idx] = row.indent .. "|" .. table.concat(cells, "|") .. "|"
  end

  return lines
end

return M
