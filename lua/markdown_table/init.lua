local state = require("markdown_table.state")
local automations = require("markdown_table.autocmd")
local creator = require("markdown_table.creator")
local column = require("markdown_table.column")
local navigation = require("markdown_table.navigation")
local AlignmentService = require("markdown_table.alignment_service")
local ui = require("markdown_table.ui")
local converter = require("markdown_table.converter")

local M = {}
local configured = false
local align_service = AlignmentService.new()

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

local function post_column_change(buf, was_active)
  if not was_active then
    M.enable(buf)
    return
  end
  ui.refresh_highlight(buf)
  ui.show_indicator(buf)
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
  if active then
    automations.activate(buf)
    ui.refresh_highlight(buf)
    ui.show_indicator(buf)
  else
    automations.deactivate(buf)
    ui.clear_highlight(buf)
    ui.hide_indicator(buf)
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

  vim.api.nvim_create_user_command("MarkdownTableFromSelection", function(cmd)
    M.convert_selection(cmd.buf, cmd.line1, cmd.line2)
  end, {
    range = true,
    desc = "Convert the selected lines into a markdown table inserted after the selection",
  })
end

function M.setup(opts)
  state.setup(opts)
  if configured then
    -- Re-apply settings for active buffers when configuration changes.
    for _, entry in ipairs(state.current_buffers()) do
      if entry.data.active then
        ui.refresh_highlight(entry.buf)
        ui.show_indicator(entry.buf)
      else
        ui.hide_indicator(entry.buf)
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
  local handled = false

  local function refresh_ui()
    ui.refresh_highlight(target)
    ui.show_indicator(target)
  end

  local changed = align_service:align_at_cursor(target, {
    on_success = function()
      handled = true
      refresh_ui()
    end,
    on_noop = function(_, _, reason)
      if reason == "unchanged" then
        handled = true
        refresh_ui()
      end
    end,
  })

  if changed then
    return true
  end

  if handled then
    return true
  end

  return false
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

---Convert the given line range into a markdown table appended after the selection.
---@param buf integer|nil
---@param first_line integer|nil 1-based inclusive
---@param last_line integer|nil 1-based inclusive
---@return boolean
function M.convert_selection(buf, first_line, last_line)
  local target = resolve_buffer(buf)
  local start_line = tonumber(first_line) or vim.fn.line("'<")
  local end_line = tonumber(last_line) or vim.fn.line("'>")

  if not start_line or start_line < 1 then
    start_line = vim.fn.line(".")
  end
  if not end_line or end_line < 1 then
    end_line = start_line
  end

  return converter.insert_from_range(target, start_line - 1, end_line - 1)
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
