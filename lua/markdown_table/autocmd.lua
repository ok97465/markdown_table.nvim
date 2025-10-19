local state = require("markdown_table.state")
local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local highlight = require("markdown_table.highlight")

local M = {}

local group_name = "MarkdownTableMode"
local debounce_handles = {}

---Align the table under the cursor, returning true if it changed.
---@param buf integer
---@param win integer|nil
---@return boolean
local function align_current(buf, win)
  if not state.is_active(buf) then
    return false
  end

  local target_win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(target_win) then
    target_win = vim.api.nvim_get_current_win()
  end

  local cursor = vim.api.nvim_win_get_cursor(target_win)
  local block = parser.block_at(buf, cursor[1] - 1)
  if not block then
    return false
  end

  local lines = aligner.align_block(block)
  if not lines then
    return false
  end

  vim.api.nvim_buf_set_lines(buf, block.start_line, block.end_line, false, lines)
  highlight.apply(buf, {
    {
      start_line = block.start_line,
      end_line = block.end_line,
    },
  })
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

  vim.api.nvim_create_autocmd({ "BufLeave", "BufUnload" }, {
    group = augroup_name,
    buffer = buf,
    callback = function()
      clear_debounce(buf)
      highlight.clear(buf)
    end,
  })
end

function M.deactivate(buf)
  clear_debounce(buf)
  pcall(vim.api.nvim_del_augroup_by_name, group_name .. buf)
  highlight.clear(buf)
end

return M
