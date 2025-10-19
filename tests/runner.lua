local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local fixtures = require("tests.fixtures")
local markdown_table = require("markdown_table")
local automations = require("markdown_table.autocmd")

local M = {}

local function assert_equal(actual, expected, context)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual:   %s", context or "Assertion failed", expected, actual))
  end
end

local function assert_lines(name, actual, expected)
  if #actual ~= #expected then
    error(string.format("%s: line count mismatch (%d ~= %d)", name, #actual, #expected))
  end

  for idx = 1, #expected do
    assert_equal(actual[idx], expected[idx], string.format("%s – mismatch on line %d", name, idx))
  end
end

local function resolve_cursor(case)
  if type(case.cursor) == "table" then
    local line = case.cursor.line or case.cursor[1] or 1
    local col = case.cursor.col or case.cursor[2] or 0
    return math.max(line, 1), math.max(col, 0)
  end
  local line = math.max(case.cursor or 1, 1)
  return line, 0
end

local function run_case(case)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  if case.input then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.input)
    local ok, old_levels = pcall(vim.api.nvim_buf_get_option, buf, "undolevels")
    if ok then
      vim.api.nvim_buf_set_option(buf, "undolevels", -1)
      vim.api.nvim_buf_set_option(buf, "undolevels", old_levels)
    end
  end

  if case.create then
    markdown_table.create_table(buf, case.create)
    if case.expected then
      local actual = vim.api.nvim_buf_get_lines(buf, 0, #case.expected, false)
      assert_lines(case.name, actual, case.expected)
    end
    return
  end

  local cursor_line, cursor_col = resolve_cursor(case)
  vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_col })

  if case.activate_before then
    markdown_table.enable(buf)
  end

  if case.edit_cell then
    markdown_table.enable(buf)
    local edit = case.edit_cell
    local line = edit.line or cursor_line
    local start_col = edit.start_col or cursor_col
    local end_col = edit.end_col or start_col
    vim.api.nvim_buf_set_text(buf, line - 1, start_col, line - 1, end_col, { edit.text or "" })
    if edit.wait_ms and edit.wait_ms > 0 then
      vim.cmd(string.format("sleep %dm", edit.wait_ms))
    end
    automations._align_for_test(buf)

    if case.expected then
      local line_count = vim.api.nvim_buf_line_count(buf)
      local actual = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
      assert_lines(case.name, actual, case.expected)
    end

    if case.expect_active ~= nil then
      local active = markdown_table.is_active(buf)
      assert_equal(active, case.expect_active, string.format("%s: unexpected Table Mode state", case.name))
    end

    if case.undo_expected then
      vim.cmd("silent undo")
      vim.cmd("sleep 200m")
      local after_undo = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert_lines(case.name .. " (after undo)", after_undo, case.undo_expected)
      if case.expect_active_after_undo ~= nil then
        local active_after = markdown_table.is_active(buf)
        assert_equal(active_after, case.expect_active_after_undo, string.format("%s: unexpected Table Mode state after undo", case.name))
      end
    end
    return
  end

  if case.operation then
    local ok
    if case.operation == "delete_column" then
      ok = markdown_table.delete_column(buf)
    elseif case.operation == "insert_left" then
      ok = markdown_table.insert_column_left(buf)
    elseif case.operation == "insert_right" then
      ok = markdown_table.insert_column_right(buf)
    else
      error(string.format("%s: unknown operation '%s'", case.name, tostring(case.operation)))
    end

    if case.expect_success ~= nil then
      assert_equal(ok, case.expect_success, string.format("%s: unexpected success state", case.name))
    end

    if case.expected then
      local line_count = vim.api.nvim_buf_line_count(buf)
      local actual = vim.api.nvim_buf_get_lines(buf, 0, line_count, false)
      assert_lines(case.name, actual, case.expected)
    end

    if case.verify_aligned then
      local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local aligned = markdown_table.align(buf)
      assert_equal(aligned, true, string.format("%s: align should succeed post-operation", case.name))
      local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert_lines(case.name .. " (post-align check)", after, before)
    end

    if case.expect_active ~= nil then
      local active = markdown_table.is_active(buf)
      assert_equal(active, case.expect_active, string.format("%s: unexpected Table Mode state", case.name))
    end

    if case.undo_expected then
      vim.cmd("silent undo")
      vim.cmd("sleep 200m")
      local after_undo = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert_lines(case.name .. " (after undo)", after_undo, case.undo_expected)
      if case.expect_active_after_undo ~= nil then
        local active_after = markdown_table.is_active(buf)
        assert_equal(active_after, case.expect_active_after_undo, string.format("%s: unexpected Table Mode state after undo", case.name))
      end
    end
    return
  end

  local block = parser.block_at(buf, cursor_line - 1)
  if case.expect_block == false then
    if block then
      error(string.format("%s: expected no table block but one was found", case.name))
    end
    return
  end

  if not block then
    error(string.format("%s: expected table block but none found", case.name))
  end

  if case.expected then
    local aligned = aligner.align_block(block)
    if not aligned then
      error(string.format("%s: aligner returned nil lines", case.name))
    end
    assert_lines(case.name, aligned, case.expected)
  end
end

function M.main()
  for _, case in ipairs(fixtures.cases) do
    run_case(case)
  end
  print("All tests passed")
end

return M
