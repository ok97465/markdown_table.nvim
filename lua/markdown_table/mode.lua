local state = require("markdown_table.state")
local automations = require("markdown_table.autocmd")
local ui = require("markdown_table.ui")
local deps = require("markdown_table.deps")

local M = {}

local function alignment_service()
  -- Keep a single alignment service instance to respect dependency inversion.
  return deps.alignment_service()
end

---Resolve a buffer handle, defaulting to the current buffer.
---@param buf integer|nil
---@return integer
function M.resolve_buffer(buf)
  local target = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(target) then
    error("markdown_table: invalid buffer handle " .. tostring(target))
  end
  return target
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

---Enable table mode for the buffer.
---@param buf integer|nil
---@return boolean
function M.enable(buf)
  local target = M.resolve_buffer(buf)
  if state.is_active(target) then
    return true
  end
  apply_activation(target, true)
  return true
end

---Disable table mode for the buffer.
---@param buf integer|nil
---@return boolean
function M.disable(buf)
  local target = M.resolve_buffer(buf)
  if not state.is_active(target) then
    return false
  end
  apply_activation(target, false)
  return true
end

---Toggle table mode for the buffer.
---@param buf integer|nil
---@return boolean
function M.toggle(buf)
  local target = M.resolve_buffer(buf)
  if state.is_active(target) then
    return M.disable(target)
  end
  return M.enable(target)
end

---Check whether table mode is enabled.
---@param buf integer|nil
---@return boolean
function M.is_active(buf)
  return state.is_active(M.resolve_buffer(buf))
end

local function refresh_ui(buf)
  ui.refresh_highlight(buf)
  ui.show_indicator(buf)
end

---Align the table under the cursor for the buffer.
---@param buf integer|nil
---@return boolean
function M.align(buf)
  local target = M.resolve_buffer(buf)
  local handled = false
  local service = alignment_service()

  local changed = service:align_at_cursor(target, {
    on_success = function()
      handled = true
      refresh_ui(target)
    end,
    on_noop = function(_, _, reason)
      if reason == "unchanged" then
        handled = true
        refresh_ui(target)
      end
    end,
  })

  if changed or handled then
    return true
  end

  return false
end

---Prepare the buffer for a column mutation and return context.
---@param buf integer|nil
---@return table
function M.begin_column_mutation(buf)
  local target = M.resolve_buffer(buf)
  local was_active = state.is_active(target)
  local deferred = false
  if was_active and state.config().auto_align then
    state.defer_auto_align(target)
    deferred = true
  end
  return {
    buf = target,
    was_active = was_active,
    deferred = deferred,
  }
end

---Finalize a column mutation using the provided context.
---@param context {buf: integer, was_active: boolean, deferred: boolean}|nil
function M.commit_column_mutation(context)
  if not context or not context.buf then
    return
  end
  local target = context.buf
  if not context.was_active then
    M.enable(target)
    return
  end
  refresh_ui(target)
  state.record_undo_state(target)
end

---Cancel a pending mutation context, consuming deferred state when needed.
---@param context {buf: integer, was_active: boolean, deferred: boolean}|nil
function M.cancel_column_mutation(context)
  if not context or not context.deferred then
    return
  end
  state.consume_auto_align(context.buf)
end

---Reapply visuals for all buffers (e.g. after configuration changes).
function M.reapply_config()
  for _, entry in ipairs(state.current_buffers()) do
    if entry.data.active then
      refresh_ui(entry.buf)
    else
      ui.hide_indicator(entry.buf)
    end
  end
end

return M
