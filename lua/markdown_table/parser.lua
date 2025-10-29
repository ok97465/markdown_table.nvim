local ts_parser = require("markdown_table.parsers.treesitter")

local M = {}

---Locate the markdown table block at the provided row.
---@param buf integer
---@param row integer
---@return {start_line: integer, end_line: integer, lines: string[], rows: table[], source: string}|nil
function M.block_at(buf, row)
  return ts_parser.block_at(buf, row)
end

return M
