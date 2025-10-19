local M = {}

local strwidth = vim.strwidth or vim.fn.strdisplaywidth

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
    local left = math.floor(excess / 2)
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
  local dashes = math.max(3, width)
  local body = string.rep("-", dashes)
  if meta.colon_left and meta.colon_right then
    return ":" .. body .. ":"
  elseif meta.colon_right then
    return body .. ":"
  elseif meta.colon_left then
    return ":" .. body
  else
    return body
  end
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
  local widths = {}
  for col = 1, column_count do
    meta[col] = normalize_align(nil)
    widths[col] = 0
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
        local w = strwidth(cell.text or "")
        if w > widths[idx] then
          widths[idx] = w
        end
      end
    end
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

