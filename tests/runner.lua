local parser = require("markdown_table.parser")
local aligner = require("markdown_table.align")
local fixtures = require("tests.fixtures")
local markdown_table = require("markdown_table")

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

local function run_case(case)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  if case.input then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.input)
  end

  if case.create then
    markdown_table.create_table(buf, case.create)
    if case.expected then
      local actual = vim.api.nvim_buf_get_lines(buf, 0, #case.expected, false)
      assert_lines(case.name, actual, case.expected)
    end
    return
  end

  local cursor_line = math.max(case.cursor or 1, 1)
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
