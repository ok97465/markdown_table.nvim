local state = require("markdown_table.state")
local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local highlight = require("markdown_table.highlight")

local M = {}

local NBSP = (vim and vim.fn and vim.fn.nr2char(0xA0)) or string.char(0xC2, 0xA0)
local placeholder_width = 6

local function sanitize_count(value, fallback)
  local num = tonumber(value)
  if not num or num < 1 then
    return fallback
  end
  return math.floor(num)
end

---Generate a markdown table skeleton.
---@param columns integer
---@param rows integer
---@return string[]
function M.generate(columns, rows)
  columns = sanitize_count(columns, 1)
  rows = sanitize_count(rows, 1)

  local lines = {}
  local function build_row(cells)
    return "| " .. table.concat(cells, " | ") .. " |"
  end

  local function blank_row()
    local cells = {}
    local placeholder = NBSP:rep(placeholder_width)
    for col = 1, columns do
      cells[col] = placeholder
    end
    return build_row(cells)
  end

  local separator_cells = {}
  for col = 1, columns do
    separator_cells[col] = "---"
  end

  lines[#lines + 1] = blank_row()
  lines[#lines + 1] = build_row(separator_cells)

  for _ = 1, rows do
    lines[#lines + 1] = blank_row()
  end

  return lines
end

local function align_block(buf, start_line)
  local block = parser.block_at(buf, start_line)
  if not block then
    return
  end

  local aligned = aligner.align_block(block)
  if not aligned then
    return
  end

  vim.api.nvim_buf_set_lines(buf, block.start_line, block.end_line, false, aligned)

  if state.config().highlight then
    highlight.apply(buf, {
      {
        start_line = block.start_line,
        end_line = block.end_line,
      },
    })
  end
end

---Insert a generated table at the current cursor.
---@param buf integer
---@param opts {columns: integer, rows: integer}
function M.insert(buf, opts)
  local columns = sanitize_count(opts.columns, 1)
  local rows = sanitize_count(opts.rows, 1)

  local lines = M.generate(columns, rows)
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row0 = cursor[1] - 1

  vim.api.nvim_buf_set_lines(buf, row0, row0, false, lines)
  align_block(buf, row0)

  vim.api.nvim_win_set_cursor(win, { row0 + 3, 0 })
end

local function prompt_number(prompt, default, cb)
  vim.ui.input({ prompt = prompt, default = tostring(default) }, function(value)
    if value == nil then
      cb(nil)
      return
    end
    local num = sanitize_count(value, nil)
    if not num then
      vim.notify("Invalid number: " .. value, vim.log.levels.WARN)
      cb(nil)
      return
    end
    cb(num)
  end)
end

function M.interactive_create(buf)
  prompt_number("Number of columns: ", 3, function(columns)
    if not columns then
      return
    end
    prompt_number("Number of data rows: ", 2, function(rows)
      if not rows then
        return
      end
      M.insert(buf, { columns = columns, rows = rows })
    end)
  end)
end

return M
