local uv = vim.loop

local aligner = require("markdown_table.align")
local parser = require("markdown_table.parser")

local M = {}

---Read file lines relative to repository root.
---@param path string
---@return string[]
local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    error(string.format("failed to read %s: %s", path, lines))
  end
  return lines
end

---Compute basic statistics for a numeric sample.
---@param values number[]
---@return table
local function stats(values)
  local sorted = { unpack(values) }
  table.sort(sorted)
  local count = #sorted
  local sum = 0
  for _, val in ipairs(sorted) do
    sum = sum + val
  end

  local mean = sum / count
  local median = count % 2 == 1 and sorted[(count + 1) / 2]
    or (sorted[count / 2] + sorted[count / 2 + 1]) / 2

  return {
    count = count,
    min = sorted[1],
    max = sorted[#sorted],
    mean = mean,
    median = median,
  }
end

---Run a single benchmark iteration, returning elapsed milliseconds.
---@param lines string[]
---@param expected string[]
---@return number
local function run_iteration(lines, expected)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local block = parser.block_at(buf, 0)
  if not block then
    error("block_at failed to detect generated table")
  end

  local start = uv.hrtime()
  local result = aligner.align_block(block)
  local elapsed_ms = (uv.hrtime() - start) / 1e6

  if not result then
    error("align_block returned nil")
  end

  if expected then
    local mismatch
    if #result ~= #expected then
      mismatch = string.format("line count mismatch (%d ~= %d)", #result, #expected)
    else
      for idx = 1, #expected do
        if result[idx] ~= expected[idx] then
          mismatch = string.format("line %d diverged", idx)
          break
        end
      end
    end
    if mismatch then
      error("alignment result diverged from reference: " .. mismatch)
    end
  end

  return elapsed_ms
end

local function print_summary(timings)
  local count = #timings
  if count == 0 then
    return
  end
  if count == 1 then
    print(string.format("align_block: 1 run | %.3f ms", timings[1]))
    return
  end

  local summary = stats(timings)
  local fmt = "align_block: %d runs | mean %.3f ms | median %.3f ms | min %.3f ms | max %.3f ms"
  print(string.format(fmt, summary.count, summary.mean, summary.median, summary.min, summary.max))
end

function M.main(opts)
  opts = opts or {}
  local root = vim.fn.getcwd()
  local unaligned = read_lines(root .. "/tests/data/large_table_unaligned.md")
  local reference = read_lines(root .. "/tests/data/large_table_aligned.md")

  local iterations = tonumber(opts.iterations) or tonumber(vim.env.BENCH_ITERATIONS) or 10
  if iterations < 1 then
    error("iterations must be >= 1")
  end

  local warmup = opts.warmup
  if warmup == nil then
    warmup = math.min(3, math.max(iterations - 1, 0))
  end
  warmup = math.max(warmup, 0)

  for _ = 1, warmup do
    run_iteration(unaligned, reference)
  end

  local timings = {}
  for _ = 1, iterations do
    timings[#timings + 1] = run_iteration(unaligned, reference)
  end

  local drop_first = tonumber(opts.drop_first) or 0
  if drop_first < 0 then
    drop_first = 0
  end
  if drop_first >= #timings then
    error(string.format("drop_first (%d) must be < iterations (%d)", drop_first, #timings))
  end

  if drop_first > 0 then
    local trimmed = {}
    for idx = drop_first + 1, #timings do
      trimmed[#trimmed + 1] = timings[idx]
    end
    timings = trimmed
  end

  print_summary(timings)
end

return M
