local M = {}

---Helper to define fixtures in a concise form.
---@param value string|string[]
---@return string[]
local function to_lines(value)
  if type(value) == "table" then
    return value
  end

  -- Remove leading/trailing blank lines.
  local text = value:gsub("^%s*\n", ""):gsub("\n%s*$", "")

  -- Dedent common indentation.
  local indent
  for line in text:gmatch("[^\n]+") do
    local spaces = line:match("^(%s*)%S")
    if spaces then
      local count = #spaces
      if not indent or count < indent then
        indent = count
      end
    end
  end

  if indent and indent > 0 then
    local pattern = "\n" .. string.rep(" ", indent)
    text = text:gsub(pattern, "\n")
    if text:sub(1, indent) == string.rep(" ", indent) then
      text = text:sub(indent + 1)
    end
  end

  local lines = {}
  for line in text:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end

  return lines
end

local NBSP = "\194\160"
local PLACEHOLDER_WIDTH = 6

local function join_row(columns, value)
  local cells = {}
  for col = 1, columns do
    cells[col] = value
  end
  return "| " .. table.concat(cells, " | ") .. " |"
end

local function blank_table_lines(columns, rows)
  local placeholder = NBSP:rep(PLACEHOLDER_WIDTH)
  local separator = join_row(columns, string.rep("-", PLACEHOLDER_WIDTH))
  local lines = { join_row(columns, placeholder), separator }
  for _ = 1, rows do
    lines[#lines + 1] = join_row(columns, placeholder)
  end
  return lines
end

M.cases = {
  {
    name = "basic_alignment",
    cursor = 1,
    expect_block = true,
    input = [[
      | Name|Age|City|
      |--|:--:|---:|
      | Alice | 24 | Seattle|
      |Bob|  31| New York |
      | Charlie | 5 | Boston|
    ]],
    expected = [[
      | Name    |  Age |       City |
      | ------- | :--: | ---------: |
      | Alice   |  24  |    Seattle |
      | Bob     |  31  |   New York |
      | Charlie |   5  |     Boston |
    ]],
  },
  {
    name = "empty_cells",
    cursor = 1,
    expect_block = true,
    input = [[
      | Key | Value | Note |
      | --- | :-----: | ---: |
      | foo |       | memo |
      | bar | 42    |      |
      |     | 13    | skip |
    ]],
    expected = [[
      | Key | Value |   Note |
      | --- | :---: | -----: |
      | foo |       |   memo |
      | bar |   42  |        |
      |     |   13  |   skip |
    ]],
  },
  {
    name = "missing_column_cells",
    cursor = 1,
    expect_block = true,
    input = [[
      | Item | Count | Description |
      | --- | --- | --- |
      | Apples | 5 |
      | Pears | 10 | Fresh |
      | | 2 | TBD |
    ]],
    expected = [[
      | Item   | Count | Description |
      | ------ | ----- | ----------- |
      | Apples | 5     |             |
      | Pears  | 10    | Fresh       |
      |        | 2     | TBD         |
    ]],
  },
  {
    name = "non_table_lines",
    cursor = 2,
    expect_block = false,
    input = {
      "Regular sentence with no table",
      "| Just one pipe",
      "Another plain line",
    },
  },
  {
    name = "create_table_generation",
    create = { columns = 3, rows = 2 },
    expected = blank_table_lines(3, 2),
  },
  {
    name = "delete_column_middle",
    cursor = { line = 3, col = 10 },
    operation = "delete_column",
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | Name | Age | City |
      | --- | ---: | --- |
      | Alice | 24 | Seattle |
      | Bob | 31 | Portland |
    ]],
    undo_expected = [[
      | Name | Age | City |
      | --- | ---: | --- |
      | Alice | 24 | Seattle |
      | Bob | 31 | Portland |
    ]],
    expected = [[
      | Name  | City     |
      | ----- | -------- |
      | Alice | Seattle  |
      | Bob   | Portland |
    ]],
  },
  {
    name = "insert_column_left",
    cursor = { line = 3, col = 10 },
    operation = "insert_left",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | Item | Quantity |
      | --- | --- |
      | Pens | 10 |
      | Paper | 25 |
    ]],
    undo_expected = [[
      | Item | Quantity |
      | --- | --- |
      | Pens | 10 |
      | Paper | 25 |
    ]],
    expected = [[
      | Item  |      | Quantity |
      | ----- | ---- | -------- |
      | Pens  |      | 10       |
      | Paper |      | 25       |
    ]],
  },
  {
    name = "insert_column_right",
    cursor = { line = 3, col = 3 },
    operation = "insert_right",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | Task | DoneDone |
      | --- | :---: |
      | Write | yes |
      | Review | no |
    ]],
    undo_expected = [[
      | Task | DoneDone |
      | --- | :---: |
      | Write | yes |
      | Review | no |
    ]],
    expected = [[
      | Task   |      | DoneDone |
      | ------ | ---- | :------: |
      | Write  |      |    yes   |
      | Review |      |    no    |
    ]],
  },
  {
    name = "insert_column_left_alignment_copy",
    cursor = { line = 3, col = 6 },
    operation = "insert_left",
    verify_aligned = true,
    activate_before = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | Left | Center | Right |
      | :--- | :---: | ---: |
      | A | B | C |
    ]],
    undo_expected = [[
      | Left | Center | Right |
      | :--- | :---: | ---: |
      | A | B | C |
    ]],
    expected = [[
      | Left   |      | Center |   Right |
      | :----- | :--: | :----: | ------: |
      | A      |      |    B   |       C |
    ]],
  },
  {
    name = "cell_edit_single_undo",
    cursor = { line = 3, col = 2 },
    activate_before = true,
    expect_active = true,
    expect_active_after_undo = true,
    edit_cell = {
      line = 3,
      start_col = 2,
      end_col = 5,
      text = "Bobby",
      wait_ms = 250,
    },
    input = [[
      | Name | Age |
      | --- | --- |
      | Bob | 31 |
    ]],
    expected = [[
      | Name  | Age |
      | ----- | --- |
      | Bobby | 31  |
    ]],
    undo_expected = [[
      | Name | Age |
      | --- | --- |
      | Bob | 31 |
    ]],
  },
}

for _, case in ipairs(M.cases) do
  if case.input then
    case.input = to_lines(case.input)
  end
  if case.expected then
    case.expected = to_lines(case.expected)
  end
  if case.undo_expected then
    case.undo_expected = to_lines(case.undo_expected)
  end
end

return M
