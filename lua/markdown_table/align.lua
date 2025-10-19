local M = {}

local strwidth = vim.strwidth or vim.fn.strdisplaywidth
-- Ensure freshly inserted columns render with a visible six-character cell (width + padding).
local MIN_EMPTY_COLUMN_WIDTH = 4

local function pad_cell(text, width, align)
  local cleaned = text or ""
  local trimmed = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
  local excess = width - strwidth(trimmed)
  if excess < 0 then
    excess = 0
  end

  if align == "right" then
    return string.rep(" ", excess) .. trimmed
  elseif align == "center" then
    local left = math.ceil(excess / 2)
    local right = excess - left
    return string.rep(" ", left) .. trimmed .. string.rep(" ", right)
  else
    return trimmed .. string.rep(" ", excess)
  end
end

local function normalize_align(meta)
  if not meta then
    return { align = "default", colon_left = false, colon_right = false }
  end
  local align = meta.align
  if align == "none" then
    align = "default"
  end
  return {
    align = align,
    colon_left = meta.colon_left,
    colon_right = meta.colon_right,
  }
end

local function data_align(meta)
  if not meta or meta.align == "default" then
    return "left"
  end
  return meta.align
end

local function separator_token(width, meta)
  local colon_left = meta.colon_left and true or false
  local colon_right = meta.colon_right and true or false
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
---@return table[], table[]
local function analyze_columns(rows)
  local column_count = 0
  for _, row in ipairs(rows) do
    if row.cells and #row.cells > column_count then
      column_count = #row.cells
    end
  end

  local meta = {}
  local data_widths = {}
  local has_content = {}
  for col = 1, column_count do
    meta[col] = normalize_align(nil)
    data_widths[col] = 0
    has_content[col] = false
  end

  for _, row in ipairs(rows) do
    if row.kind == "separator" then
      for idx, align in ipairs(row.alignments or {}) do
        if align then
          meta[idx] = normalize_align(align)
        end
      end
    elseif row.cells then
      for idx, cell in ipairs(row.cells) do
        local text = cell.text or ""
        local width = strwidth(text)
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
    local info = meta[idx]
    local data_width = data_widths[idx] or 0
    local colon_count = 0
    if info.colon_left then
      colon_count = colon_count + 1
    end
    if info.colon_right then
      colon_count = colon_count + 1
    end

    local width = data_width
    if info.align == "right" or info.align == "left" then
      width = data_width + 2
    elseif info.align == "center" then
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

  return meta, widths
end

---Format parsed rows into aligned markdown table strings.
---@param block {rows: table[]}
---@return string[]|nil
function M.align_block(block)
  if not block or not block.rows or #block.rows == 0 then
    return nil
  end

  local meta, widths = analyze_columns(block.rows)
  local lines = {}

  for _, row in ipairs(block.rows) do
    local cells = {}
    if row.kind == "separator" then
      for idx = 1, #meta do
        local cell_meta = meta[idx]
        local token = separator_token(widths[idx], cell_meta)
        cells[idx] = " " .. token .. " "
      end
    else
      for idx = 1, #meta do
        local cell = row.cells[idx]
        local cell_text = cell and cell.text or ""
        local padded = pad_cell(cell_text, widths[idx], data_align(meta[idx]))
        cells[idx] = " " .. padded .. " "
      end
    end

    local line = row.indent .. "|" .. table.concat(cells, "|") .. "|"
    table.insert(lines, line)
  end

  return lines
end

return M
