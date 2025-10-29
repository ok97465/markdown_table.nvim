local util = require("markdown_table.parsers.treesitter.util")

local M = {}

local ts = vim.treesitter

local function safe_get_parser(buf)
  local parser = ts.get_parser(buf, "markdown")
  if not parser then
    error("markdown_table: Tree-sitter markdown parser is required")
  end
  return parser
end

local function named_child_iter(node)
  local count = node:named_child_count()
  local index = 0
  return function()
    if index >= count then
      return nil
    end
    local child = node:named_child(index)
    index = index + 1
    return child
  end
end

local function collect_cells(buf, row_node, line_number)
  local cells = {}
  local spans = {}

  for child in named_child_iter(row_node) do
    local type_name = child:type()
    if type_name == "pipe_table_cell" or type_name == "pipe_table_delimiter_cell" then
      local text = ts.get_node_text(child, buf) or ""
      local start_row, start_col, end_row, end_col = child:range()
      if start_row ~= line_number then
        start_col = 0
      end
      if end_row ~= line_number then
        end_col = start_col
      end
      local span = {
        start_col = start_col,
        end_col = end_col,
      }
      spans[#spans + 1] = span
      cells[#cells + 1] = {
        raw = text,
        text = util.trim(text),
        span = span,
      }
    end
  end

  return cells, spans
end

local function build_data_row(buf, node)
  local start_row = node:start()
  local raw_line = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1] or ""
  local indent = raw_line:match("^%s*") or ""

  if not raw_line:find("|", 1, true) then
    return nil
  end

  local cells, spans = collect_cells(buf, node, start_row)
  return {
    indent = indent,
    raw = raw_line,
    kind = "data",
    cells = cells,
    alignments = {},
    cell_spans = spans,
    line = start_row,
    source = "treesitter",
  }
end

local function build_delimiter_row(buf, node)
  local row = build_data_row(buf, node)
  if not row then
    return nil
  end
  row.kind = "separator"
  local alignments = {}
  for idx, cell in ipairs(row.cells) do
    alignments[idx] = util.parse_alignment(cell.text)
  end
  row.alignments = alignments
  return row
end

local function has_nested_row(node)
  for child in named_child_iter(node) do
    local child_type = child:type()
    if child_type ~= "pipe_table_delimiter_row" and child_type:match("^pipe_table_.*row$") then
      return true
    end
  end
  return false
end

local function append_rows_from_node(buf, accumulator, node)
  local type_name = node:type()
  if type_name == "pipe_table_delimiter_row" then
    local row = build_delimiter_row(buf, node)
    if row then
      accumulator[#accumulator + 1] = row
    end
    return
  end

  if type_name:match("^pipe_table_.*row$") then
    local row = build_data_row(buf, node)
    if row then
      accumulator[#accumulator + 1] = row
    end
    return
  end

  if type_name == "pipe_table_header" and not has_nested_row(node) then
    local row = build_data_row(buf, node)
    if row then
      accumulator[#accumulator + 1] = row
    end
    return
  end

  for child in named_child_iter(node) do
    append_rows_from_node(buf, accumulator, child)
  end
end

local function build_block(buf, table_node)
  local start_row, _, end_row = table_node:range()
  local rows = {}

  for child in named_child_iter(table_node) do
    append_rows_from_node(buf, rows, child)
  end

  if #rows == 0 then
    return nil
  end

  table.sort(rows, function(a, b)
    return (a.line or 0) < (b.line or 0)
  end)

  local first_line = rows[1].line or start_row
  local last_line = rows[#rows].line or first_line
  local lines = {}
  for idx = 1, #rows do
    lines[idx] = rows[idx].raw
  end

  return {
    start_line = first_line,
    end_line = last_line + 1,
    lines = lines,
    rows = rows,
    source = "treesitter",
    tree = {
      node = table_node,
    },
  }
end

---Return a table block using Tree-sitter when available.
---@param buf integer
---@param row integer
---@return {start_line: integer, end_line: integer, lines: string[], rows: table[], source: string}|nil
function M.block_at(buf, row)
  local parser = safe_get_parser(buf)
  local trees = parser:parse()
  local tree = trees[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local end_col = math.max(#line, 1)
  local target = root:named_descendant_for_range(row, 0, row, end_col)
  while target and target:type() ~= "pipe_table" do
    target = target:parent()
  end

  if not target then
    return nil
  end

  return build_block(buf, target)
end

return M
