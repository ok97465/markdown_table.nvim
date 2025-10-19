local state = require("markdown_table.state")
local highlight = require("markdown_table.highlight")
local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local automations = require("markdown_table.autocmd")
local creator = require("markdown_table.creator")
local indicator = require("markdown_table.indicator")
local column = require("markdown_table.column")
local buffer = require("markdown_table.buffer")
local navigation = require("markdown_table.navigation")

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

local function post_column_change(buf, was_active)
  if not was_active then
    M.enable(buf)
    return
  end

  refresh_highlight(buf)
  indicator.show(buf)
  state.record_undo_state(buf)
end

local function prepare_column_change(buf)
  local active = state.is_active(buf)
  local suppress = active and state.config().auto_align
  if suppress then
    state.defer_auto_align(buf)
  end
  return active, suppress
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
    indicator.show(buf)
  else
    automations.deactivate(buf)
    indicator.hide(buf)
  end
  state.record_undo_state(buf)
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

  vim.api.nvim_create_user_command("MarkdownTableCreate", function(cmd)
    M.create(cmd.buf)
  end, {
    desc = "Interactively create a markdown table",
  })

  vim.api.nvim_create_user_command("MarkdownTableColumnDelete", function(cmd)
    M.delete_column(cmd.buf)
  end, {
    desc = "Delete the table column under the cursor",
  })

  vim.api.nvim_create_user_command("MarkdownTableColumnInsertLeft", function(cmd)
    M.insert_column_left(cmd.buf)
  end, {
    desc = "Insert a table column to the left of the cursor",
  })

  vim.api.nvim_create_user_command("MarkdownTableColumnInsertRight", function(cmd)
    M.insert_column_right(cmd.buf)
  end, {
    desc = "Insert a table column to the right of the cursor",
  })
end

function M.setup(opts)
  state.setup(opts)
  if configured then
    -- Re-apply settings for active buffers when configuration changes.
    for _, entry in ipairs(state.current_buffers()) do
      if entry.data.active then
        refresh_highlight(entry.buf)
        indicator.show(entry.buf)
      else
        indicator.hide(entry.buf)
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

  local changed = buffer.replace(target, block.start_line, block.end_line, lines)
  refresh_highlight(target)
  indicator.show(target)
  state.record_undo_state(target)
  return changed or true
end

---Delete the column under the cursor.
---@param buf integer|nil
function M.delete_column(buf)
  local target = resolve_buffer(buf)
  local was_active, deferred = prepare_column_change(target)
  local success = column.delete(target)
  if not success then
    if deferred then
      state.consume_auto_align(target)
    end
    return false
  end

  post_column_change(target, was_active)
  return true
end

---Insert an empty column to the left of the cursor.
---@param buf integer|nil
function M.insert_column_left(buf)
  local target = resolve_buffer(buf)
  local was_active, deferred = prepare_column_change(target)
  local success = column.insert_left(target)
  if not success then
    if deferred then
      state.consume_auto_align(target)
    end
    return false
  end

  post_column_change(target, was_active)
  return true
end

---Insert an empty column to the right of the cursor.
---@param buf integer|nil
function M.insert_column_right(buf)
  local target = resolve_buffer(buf)
  local was_active, deferred = prepare_column_change(target)
  local success = column.insert_right(target)
  if not success then
    if deferred then
      state.consume_auto_align(target)
    end
    return false
  end

  post_column_change(target, was_active)
  return true
end

---Create a markdown table at the cursor (interactive).
---@param buf integer|nil
function M.create(buf)
  local target = resolve_buffer(buf)
  creator.interactive_create(target)
end

---Programmatic creation helper for tests.
---@param buf integer
---@param opts table
function M.create_table(buf, opts)
  creator.insert(resolve_buffer(buf), opts)
end

---Move the cursor to the previous table cell on the current row.
---@param buf integer|nil
---@return boolean
function M.move_cell_left(buf)
  local target = resolve_buffer(buf)
  return navigation.move_left(target)
end

---Move the cursor to the next table cell on the current row.
---@param buf integer|nil
---@return boolean
function M.move_cell_right(buf)
  local target = resolve_buffer(buf)
  return navigation.move_right(target)
end

return M
