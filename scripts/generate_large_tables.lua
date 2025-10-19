local uv = vim.loop

local function ensure_package_paths()
  local root = vim.fn.getcwd()
  local paths = {
    root .. "/lua/?.lua",
    root .. "/lua/?/init.lua",
    root .. "/scripts/?.lua",
  }
  local joined = table.concat(paths, ";")
  if not package.path:match(root .. "/scripts/%?%.lua") then
    package.path = joined .. ";" .. package.path
  end
end

ensure_package_paths()

local aligner = require("markdown_table.align")
local parser = require("markdown_table.parser")

local M = {}

---Generate deterministic sample data with mixed widths.
---@return string[] unaligned_lines
local function build_unaligned_lines()
  math.randomseed(20240525)
  local headers = {
    "ID",
    "이름",
    "Role",
    "Team",
    "Location",
    "Score",
    "Notes",
  }
  local alignment = {
    " ---:",
    " :---",
    " :---:",
    " ---",
    " :---:",
    " ---:",
    " ---",
  }

  local lines = {}
  lines[#lines + 1] = "|" .. table.concat(headers, "|") .. "|"
  lines[#lines + 1] = "|" .. table.concat(alignment, "|") .. "|"

  local roles = { "Lead", "Dev", "QA", "PM", "Ops", "Design" }
  local teams = { "Ares", "Boreas", "Cronus", "Demeter", "Eos", "Fortuna" }
  local cities = { "Seoul", "Busan", "Daejeon", "New York", "Tokyo", "Berlin" }
  local notes = {
    "긴 메모",
    "Pending review",
    "필드 확인 필요",
    "Ready",
    "추가 조사",
    "Stable",
  }

  for idx = 1, 600 do
    local id = string.format("EMP-%04d", idx)
    local name
    if idx % 5 == 0 then
      name = "박영희"
    elseif idx % 3 == 0 then
      name = "김철수"
    elseif idx % 7 == 0 then
      name = "이민수"
    else
      name = "User" .. idx
    end

    local role = roles[(idx % #roles) + 1]
    local team = teams[(idx * 3 % #teams) + 1]
    local city = cities[(idx * 5 % #cities) + 1]
    local score = tostring(50 + (idx * 7) % 50)
    local memo = notes[(idx * 11 % #notes) + 1]

    local row = string.format(
      "|%s|%s|%s|%s|%s|%s|%s|",
      id,
      name,
      role,
      team,
      city,
      score,
      memo
    )
    lines[#lines + 1] = row
  end

  return lines
end

---Write lines to a file.
---@param path string
---@param lines string[]
local function write_file(path, lines)
  local ok, err = pcall(vim.fn.writefile, lines, path)
  if not ok then
    error(string.format("failed to write %s: %s", path, err))
  end
end

---Align unaligned lines using the plugin.
---@param lines string[]
---@return string[]
local function align_lines(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local block = parser.block_at(buf, 0)
  local result = aligner.align_block(block)
  if not result then
    error("aligner returned nil for generated table")
  end
  return result
end

function M.run()
  local root = vim.fn.getcwd()
  local unaligned = build_unaligned_lines()
  local aligned = align_lines(unaligned)

  local data_dir = root .. "/tests/data"
  if uv.fs_stat(data_dir) == nil then
    uv.fs_mkdir(data_dir, 493) -- 0755
  end

  write_file(data_dir .. "/large_table_unaligned.md", unaligned)
  write_file(data_dir .. "/large_table_aligned.md", aligned)
end

M.run()

return M
