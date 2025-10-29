local state = require("markdown_table.state")
local deps = require("markdown_table.deps")
local ui = require("markdown_table.ui")

local M = {}

local group_name = "MarkdownTableMode"
local debounce_handles = {}

local function alignment_service()
  -- Retrieve the shared alignment service to honour current configuration.
  return deps.alignment_service()
end

---Align the table under the cursor, returning true if it changed.
---@param buf integer
---@param win integer|nil
---@return boolean
local function align_current(buf, win)
  if not state.is_active(buf) then
    return false
  end

  if state.consume_auto_align(buf) then
    return false
  end

  if state.did_undo(buf) then
    return false
  end

  local target_win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(target_win) then
    target_win = vim.api.nvim_get_current_win()
  end

  local service = alignment_service()
  local changed = service:align_at_cursor(buf, {
    win = target_win,
    replace_opts = { undojoin = true },
    on_success = function(_, block)
      ui.highlight_block(buf, block)
      ui.show_indicator(buf)
    end,
  })

  if not changed then
    return false
  end

  return true
end

local function clear_debounce(buf)
  local handle = debounce_handles[buf]
  if handle then
    handle:close()
    debounce_handles[buf] = nil
  end
end

---Debounce alignment for the provided buffer.
---@param buf integer
---@param win integer|nil
local function request_debounced_align(buf, win)
  clear_debounce(buf)

  local timeout = state.config().debounce_ms or 120
  local timer = vim.defer_fn(function()
    debounce_handles[buf] = nil
    align_current(buf, win)
  end, timeout)

  debounce_handles[buf] = timer
end

function M.activate(buf)
  local augroup_name = group_name .. buf
  vim.api.nvim_create_augroup(augroup_name, { clear = true })

  local config = state.config()

  if config.auto_align then
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedP" }, {
      group = augroup_name,
      buffer = buf,
      callback = function()
        request_debounced_align(buf, vim.api.nvim_get_current_win())
      end,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
      group = augroup_name,
      buffer = buf,
      callback = function()
        clear_debounce(buf)
        align_current(buf, vim.api.nvim_get_current_win())
      end,
    })
  end

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup_name,
    buffer = buf,
    callback = function(args)
      ui.show_indicator(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "BufUnload" }, {
    group = augroup_name,
    buffer = buf,
    callback = function()
      clear_debounce(buf)
      ui.clear_highlight(buf)
      ui.hide_indicator(buf)
    end,
  })
end

function M.deactivate(buf)
  clear_debounce(buf)
  pcall(vim.api.nvim_del_augroup_by_name, group_name .. buf)
  ui.clear_highlight(buf)
  ui.hide_indicator(buf)
end

function M._align_for_test(buf)
  return align_current(buf, vim.api.nvim_get_current_win())
end

return M
