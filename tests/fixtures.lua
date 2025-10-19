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
    name = "align_multiple_tables_current_only",
    cursor = { line = 8, col = 6 },
    operation = "align",
    input = [[
      Intro line
      | First|Table|
      |--|--|
      |A|100|

      Between tables
      | Name | Score |
      | --- | ---: |
      | Ann | 5 |
      | Bobby | 12 |

      Ending line
    ]],
    expected = [[
      Intro line
      | First|Table|
      |--|--|
      |A|100|

      Between tables
      | Name  |   Score |
      | ----- | ------: |
      | Ann   |       5 |
      | Bobby |      12 |

      Ending line
    ]],
  },
  {
    name = "delete_column_with_neighbor_tables",
    cursor = { line = 10, col = 10 },
    operation = "delete_column",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      Header text
      | ID | Name | Note |
      | --- | --- | --- |
      | A | Alpha | keep |
      | B | Beta | drop |

      Middle comment
      | Product | Price | Stock |
      | --- | ---: | --- |
      | Pen | 500 | 20 |
      | Paper | 1200 | 5 |
      | Ruler | 300 | 15 |
      Footer line
    ]],
    expected = [[
      Header text
      | ID | Name | Note |
      | --- | --- | --- |
      | A | Alpha | keep |
      | B | Beta | drop |

      Middle comment
      | Product | Stock |
      | ------- | ----- |
      | Pen     | 20    |
      | Paper   | 5     |
      | Ruler   | 15    |
      Footer line
    ]],
  },
  {
    name = "insert_column_right_with_neighbor_tables",
    cursor = { line = 4, col = 9 },
    operation = "insert_right",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      Overview
      | Task | Owner |
      | --- | --- |
      | Spec | Ann |
      | Code | Bob |

      Details
      | First | Second |
      | --- | --- |
      | 1 | 2 |
      | 3 | 4 |
    ]],
    undo_expected = [[
      Overview
      | Task | Owner |
      | --- | --- |
      | Spec | Ann |
      | Code | Bob |

      Details
      | First | Second |
      | --- | --- |
      | 1 | 2 |
      | 3 | 4 |
    ]],
    expected = [[
      Overview
      | Task | Owner |      |
      | ---- | ----- | ---- |
      | Spec | Ann   |      |
      | Code | Bob   |      |

      Details
      | First | Second |
      | --- | --- |
      | 1 | 2 |
      | 3 | 4 |
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
    name = "hangul_alignment_mixed_width",
    cursor = 1,
    expect_block = true,
    input = [[
      | 이름 | 역할 | 도시 |
      | :--- | :---: | ---: |
      | 김철수 | 팀장 | 서울 |
      | Jane | 디자이너 | 부산 |
      | 박영희 | QA | 대전 |
    ]],
    expected = [[
      | 이름     |   역할   |   도시 |
      | :------- | :------: | -----: |
      | 김철수   |   팀장   |   서울 |
      | Jane     | 디자이너 |   부산 |
      | 박영희   |    QA    |   대전 |
    ]],
  },
  {
    name = "hangul_alignment_extended",
    cursor = 1,
    expect_block = true,
    input = [[
      | 구분 | Status | 메모 | Count |
      | --- | :---: | ---: | :--- |
      | 준비 | ready | 없음 | 3 |
      | 진행중 | in progress | 비고 | 12 |
      | 완료 | done | 현황 점검 | 2 |
    ]],
    expected = [[
      | 구분   |    Status   |        메모 | Count   |
      | ------ | :---------: | ----------: | :------ |
      | 준비   |    ready    |        없음 | 3       |
      | 진행중 | in progress |        비고 | 12      |
      | 완료   |     done    |   현황 점검 | 2       |
    ]],
  },
  {
    name = "hangul_missing_cells_alignment",
    cursor = 1,
    expect_block = true,
    input = [[
      | 항목 | 설명 | 수치 | 참고 |
      | --- | ---: | :---: | --- |
      | Alpha | 데이터 | 10 | |
      | Beta | | 200 | 메모 |
      | 감자 | 길이가 긴 설명 | | 추가 |
    ]],
    expected = [[
      | 항목  |             설명 | 수치 | 참고 |
      | ----- | ---------------: | :--: | ---- |
      | Alpha |           데이터 |  10  |      |
      | Beta  |                  |  200 | 메모 |
      | 감자  |   길이가 긴 설명 |      | 추가 |
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
    name = "insert_column_right_hangul",
    cursor = { line = 3, col = 7 },
    operation = "insert_right",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | 제품 | 단가 | 수량 |
      | ---: | --- | ---: |
      | 연필 | 500 | 20 |
      | Notebook | 1200 | 5 |
      | 펜 | 800 | 12 |
    ]],
    undo_expected = [[
      | 제품 | 단가 | 수량 |
      | ---: | --- | ---: |
      | 연필 | 500 | 20 |
      | Notebook | 1200 | 5 |
      | 펜 | 800 | 12 |
    ]],
    expected = [[
      |       제품 |      | 단가 |   수량 |
      | ---------: | ---: | ---- | -----: |
      |       연필 |      | 500  |     20 |
      |   Notebook |      | 1200 |      5 |
      |         펜 |      | 800  |     12 |
    ]],
  },
  {
    name = "insert_column_left_hangul",
    cursor = { line = 3, col = 5 },
    operation = "insert_left",
    verify_aligned = true,
    expect_active = true,
    expect_active_after_undo = true,
    input = [[
      | 상태 | 설명 |
      | :---: | --- |
      | 예정 | 일정 확인 |
      | 완료 | 마감 |
    ]],
    undo_expected = [[
      | 상태 | 설명 |
      | :---: | --- |
      | 예정 | 일정 확인 |
      | 완료 | 마감 |
    ]],
    expected = [[
      |      | 상태 | 설명      |
      | :--: | :--: | --------- |
      |      | 예정 | 일정 확인 |
      |      | 완료 | 마감      |
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
    name = "move_cell_right_basic",
    cursor = { line = 3, col = 2 },
    move = "right",
    expect_success = true,
    expected_cursor = { line = 3, col = 8 },
    input = [[
      | Name | Age | City |
      | --- | --- | --- |
      | Bob | 31 | NYC |
    ]],
  },
  {
    name = "move_cell_left_basic",
    cursor = { line = 3, col = 8 },
    move = "left",
    expect_success = true,
    expected_cursor = { line = 3, col = 2 },
    input = [[
      | Name | Age | City |
      | --- | --- | --- |
      | Bob | 31 | NYC |
    ]],
  },
  {
    name = "move_cell_blank_left",
    cursor = { line = 3, col = 7 },
    move = "left",
    expect_success = true,
    expected_cursor = { line = 3, col = 2 },
    input = [[
      | Key | Value | Note |
      | --- | --- | --- |
      |     | data |     |
    ]],
  },
  {
    name = "move_cell_right_blocked",
    cursor = { line = 3, col = 13 },
    move = "right",
    expect_success = false,
    expected_cursor = { line = 3, col = 13 },
    input = [[
      | Name | Age | City |
      | --- | --- | --- |
      | Bob | 31 | NYC |
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
  {
    name = "hangul_edit_alignment_growth",
    cursor = { line = 3, col = 2 },
    activate_before = true,
    expect_active = true,
    expect_active_after_undo = true,
    edit_cell = {
      line = 3,
      start_col = 2,
      end_col = 5,
      text = "김철수",
      wait_ms = 250,
    },
    input = [[
      | 이름 | 점수 |
      | --- | ---: |
      | Kim | 82 |
      | Lee | 90 |
      | Park | 77 |
    ]],
    expected = [[
      | 이름   |   점수 |
      | ------ | -----: |
      | 김철수 |     82 |
      | Lee    |     90 |
      | Park   |     77 |
    ]],
    undo_expected = [[
      | 이름 | 점수 |
      | --- | ---: |
      | Kim | 82 |
      | Lee | 90 |
      | Park | 77 |
    ]],
  },
  {
    name = "convert_selection_csv",
    convert_selection = { line1 = 1, line2 = 3 },
    input = {
      "Name,Age,City",
      "Alice,24,Seattle",
      "Bob,31,\"New York\"",
    },
    expected = {
      "Name,Age,City",
      "Alice,24,Seattle",
      "Bob,31,\"New York\"",
      "",
      "| Name  | Age | City     |",
      "| ----- | --- | -------- |",
      "| Alice | 24  | Seattle  |",
      "| Bob   | 31  | New York |",
    },
  },
  {
    name = "convert_selection_whitespace",
    convert_selection = { line1 = 2, line2 = 4 },
    input = {
      "ignore this line",
      "Lang Score Level",
      "Lua 98 Advanced",
      "Rust 75 Intermediate",
      "Python 88 Expert",
    },
    expected = {
      "ignore this line",
      "Lang Score Level",
      "Lua 98 Advanced",
      "Rust 75 Intermediate",
      "",
      "| Lang | Score | Level        |",
      "| ---- | ----- | ------------ |",
      "| Lua  | 98    | Advanced     |",
      "| Rust | 75    | Intermediate |",
      "Python 88 Expert",
    },
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
