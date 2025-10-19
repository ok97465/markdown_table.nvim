local aligner = require("markdown_table.align")
local parser = require("markdown_table.parser")
local buffer = require("markdown_table.buffer")
local state = require("markdown_table.state")

local AlignmentService = {}
AlignmentService.__index = AlignmentService

local function clone_options(opts)
  if not opts then
    return {}
  end
  local copy = {}
  for key, value in pairs(opts) do
    copy[key] = value
  end
  return copy
end

---Create a new alignment service with optional dependency overrides.
---@param deps table|nil
---@return table
function AlignmentService.new(deps)
  deps = deps or {}
  local self = {
    aligner = deps.aligner or aligner,
    parser = deps.parser or parser,
    buffer = deps.buffer or buffer,
    record_undo = deps.record_undo or state.record_undo_state,
  }
  return setmetatable(self, AlignmentService)
end

---Align a parsed block and write updates to the buffer.
---@param buf integer
---@param block table|nil
---@param opts {replace_opts: table|nil, on_success: fun(buf: integer, block: table, lines: string[])|nil, on_noop: fun(buf: integer, block: table, reason: string)|nil, record_undo: boolean|nil}|nil
---@return boolean
function AlignmentService:align_block(buf, block, opts)
  if not block or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  local lines = self.aligner.align_block(block)
  if not lines then
    if opts and opts.on_noop then
      opts.on_noop(buf, block, "aligner")
    end
    return false
  end

  local replace_opts = nil
  if opts and opts.replace_opts then
    replace_opts = opts.replace_opts
  end

  local changed = self.buffer.replace(
    buf,
    block.start_line,
    block.end_line,
    lines,
    replace_opts
  )

  if not changed then
    if opts and opts.on_noop then
      opts.on_noop(buf, block, "unchanged")
    end
    if not opts or opts.record_undo ~= false then
      self.record_undo(buf)
    end
    return false
  end

  if opts and opts.on_success then
    opts.on_success(buf, block, lines)
  end
  if not opts or opts.record_undo ~= false then
    self.record_undo(buf)
  end

  return true
end

---Align the table block that is under the provided cursor.
---@param buf integer
---@param opts {cursor: integer[]|nil, win: integer|nil, replace_opts: table|nil, on_success: fun(buf: integer, block: table, lines: string[])|nil, on_noop: fun(buf: integer, block: table, reason: string)|nil, record_undo: boolean|nil}|nil
---@return boolean
function AlignmentService:align_at_cursor(buf, opts)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  opts = clone_options(opts)
  local cursor = opts.cursor
  if not cursor then
    local win = opts.win or vim.api.nvim_get_current_win()
    if not vim.api.nvim_win_is_valid(win) then
      win = vim.api.nvim_get_current_win()
    end
    cursor = vim.api.nvim_win_get_cursor(win)
  end

  if type(cursor) ~= "table" or #cursor < 2 then
    return false
  end

  local block = self.parser.block_at(buf, cursor[1] - 1)
  return self:align_block(buf, block, opts)
end

return AlignmentService
