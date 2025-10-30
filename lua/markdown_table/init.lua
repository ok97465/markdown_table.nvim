local state = require("markdown_table.state")
local mode = require("markdown_table.mode")
local creator = require("markdown_table.creator")
local column = require("markdown_table.column")
local navigation = require("markdown_table.navigation")
local converter = require("markdown_table.converter")
local parser = require("markdown_table.parser")
local textobject = require("markdown_table.textobject")

local M = {}
local configured = false
local textobjects_configured = false

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

  vim.api.nvim_create_user_command("MarkdownTableToCsv", function(cmd)
    M.export_csv(cmd.buf)
  end, {
    desc = "Convert the markdown table at the cursor into CSV appended after the table",
  })
end

function M.setup(opts)
  state.setup(opts)

  local config = state.config()
  local textobject_config = config.textobject or {}
  if textobject_config.enable ~= false and not textobjects_configured then
    textobject.setup(textobject_config)
    textobjects_configured = true
  end

  if configured then
    mode.reapply_config()
    return
  end

  configured = true
  create_commands()
end

function M.enable(buf)
  return mode.enable(buf)
end

function M.disable(buf)
  return mode.disable(buf)
end

function M.toggle(buf)
  return mode.toggle(buf)
end

function M.is_active(buf)
  return mode.is_active(buf)
end

---Align the table under the cursor for the given buffer.
---@param buf integer|nil
function M.align(buf)
  return mode.align(buf)
end

---Delete the column under the cursor.
---@param buf integer|nil
function M.delete_column(buf)
  local context = mode.begin_column_mutation(buf)
  local target = context.buf
  if not column.delete(target) then
    mode.cancel_column_mutation(context)
    return false
  end
  mode.commit_column_mutation(context)
  return true
end

---Insert an empty column to the left of the cursor.
---@param buf integer|nil
function M.insert_column_left(buf)
  local context = mode.begin_column_mutation(buf)
  local target = context.buf
  if not column.insert_left(target) then
    mode.cancel_column_mutation(context)
    return false
  end
  mode.commit_column_mutation(context)
  return true
end

---Insert an empty column to the right of the cursor.
---@param buf integer|nil
function M.insert_column_right(buf)
  local context = mode.begin_column_mutation(buf)
  local target = context.buf
  if not column.insert_right(target) then
    mode.cancel_column_mutation(context)
    return false
  end
  mode.commit_column_mutation(context)
  return true
end

---Create a markdown table at the cursor (interactive).
---@param buf integer|nil
function M.create(buf)
  local target = mode.resolve_buffer(buf)
  creator.interactive_create(target)
end

---Convert the given line range into a markdown table appended after the selection.
---@param buf integer|nil
---@param first_line integer|nil 1-based inclusive
---@param last_line integer|nil 1-based inclusive
---@return boolean
function M.convert_selection(buf, first_line, last_line)
  local target = mode.resolve_buffer(buf)
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

---Convert the table at the cursor into CSV lines appended after the table block.
---@param buf integer|nil
---@return boolean
function M.export_csv(buf)
  local target = mode.resolve_buffer(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local block = parser.block_at(target, row)
  if not block then
    vim.notify("markdown_table: cursor is not positioned on a table", vim.log.levels.WARN)
    return false
  end

  return converter.insert_csv_after_block(target, block)
end

---Programmatic creation helper for tests.
---@param buf integer
---@param opts table
function M.create_table(buf, opts)
  creator.insert(mode.resolve_buffer(buf), opts)
end

---Move the cursor to the previous table cell on the current row.
---@param buf integer|nil
---@return boolean
function M.move_cell_left(buf)
  local target = mode.resolve_buffer(buf)
  return navigation.move_left(target)
end

---Move the cursor to the next table cell on the current row.
---@param buf integer|nil
---@return boolean
function M.move_cell_right(buf)
  local target = mode.resolve_buffer(buf)
  return navigation.move_right(target)
end

M.textobject = textobject

return M
