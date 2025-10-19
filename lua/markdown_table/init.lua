local state = require("markdown_table.state")
local highlight = require("markdown_table.highlight")
local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local automations = require("markdown_table.autocmd")

local M = {}
local configured = false

---Validate the buffer handle and default to current buffer.
---@param buf integer|nil
---@return integer
local function resolve_buffer(buf)
  local target = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target) then
    error("markdown_table: invalid buffer handle " .. tostring(target))
  end
  return target
end

---Update highlights for the provided buffer.
---@param buf integer
local function refresh_highlight(buf)
  if not state.is_active(buf) then
    highlight.clear(buf)
    return
  end

  if not state.config().highlight then
    highlight.clear(buf)
    return
  end

  local ranges = nil
  if buf == vim.api.nvim_get_current_buf() then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local block = parser.block_at(buf, cursor[1] - 1)
    if block then
      ranges = { { start_line = block.start_line, end_line = block.end_line } }
    end
  end

  highlight.apply(buf, ranges)
end

local function apply_activation(buf, active)
  state.set_active(buf, active)
  if active and state.config().highlight then
    refresh_highlight(buf)
  else
    highlight.clear(buf)
  end

  if active then
    automations.activate(buf)
  else
    automations.deactivate(buf)
  end
end

local function create_commands()
  vim.api.nvim_create_user_command("MarkdownTableToggle", function(cmd)
    M.toggle(cmd.buf)
  end, {
    desc = "Toggle markdown table mode for the current buffer",
  })

  vim.api.nvim_create_user_command("MarkdownTableAlign", function(cmd)
    M.align(cmd.buf)
  end, {
    desc = "Align the markdown table at the cursor",
  })
end

function M.setup(opts)
  state.setup(opts)
  if configured then
    -- Re-apply settings for active buffers when configuration changes.
    for _, entry in ipairs(state.current_buffers()) do
      if entry.data.active then
        refresh_highlight(entry.buf)
      end
    end
    return
  end

  configured = true
  create_commands()
end

function M.enable(buf)
  local target = resolve_buffer(buf)
  if state.is_active(target) then
    return true
  end

  apply_activation(target, true)
  return true
end

function M.disable(buf)
  local target = resolve_buffer(buf)
  if not state.is_active(target) then
    return false
  end

  apply_activation(target, false)
  return true
end

function M.toggle(buf)
  local target = resolve_buffer(buf)
  if state.is_active(target) then
    return M.disable(target)
  else
    return M.enable(target)
  end
end

function M.is_active(buf)
  return state.is_active(resolve_buffer(buf))
end

---Align the table under the cursor for the given buffer.
---@param buf integer|nil
function M.align(buf)
  local target = resolve_buffer(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local block = parser.block_at(target, cursor[1] - 1)
  if not block then
    return false
  end

  local lines = aligner.align_block(block)
  if not lines then
    return false
  end

  vim.api.nvim_buf_set_lines(target, block.start_line, block.end_line, false, lines)
  refresh_highlight(target)
  return true
end

return M
