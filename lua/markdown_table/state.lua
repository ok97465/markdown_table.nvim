local M = {}

local defaults = {
  highlight = true,
  highlight_group = "CursorLine",
  auto_align = true,
  debounce_ms = 120,
  indicator = {
    enable = true,
    text = "[Table Mode]",
    highlight = "Title",
  },
}

local buffers = setmetatable({}, { __mode = "k" })

---Fetch or initialize buffer scoped state.
---@param buf integer
---@return table
local function ensure(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    error("markdown_table: invalid buffer id " .. tostring(buf))
  end

  local entry = buffers[buf]
  if not entry then
    entry = {
      active = false,
      options = {},
      pending_auto_align = 0,
      undo_seq = nil,
    }
    buffers[buf] = entry
  end
  return entry
end

function M.setup(opts)
  defaults = vim.tbl_deep_extend("force", defaults, opts or {})
end

function M.config()
  return defaults
end

function M.current_buffers()
  local list = {}
  for buf, data in pairs(buffers) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      list[#list + 1] = { buf = buf, data = data }
    end
  end
  return list
end

function M.data(buf)
  return ensure(buf)
end

function M.is_active(buf)
  return ensure(buf).active
end

function M.set_active(buf, active)
  ensure(buf).active = active
end

---Schedule suppression for the next automatic align.
---@param buf integer
---@param count integer|nil
function M.defer_auto_align(buf, count)
  local entry = ensure(buf)
  local amount = count or 1
  if amount <= 0 then
    return
  end
  entry.pending_auto_align = (entry.pending_auto_align or 0) + amount
end

---Consume a pending automatic align suppression.
---@param buf integer
---@return boolean
function M.consume_auto_align(buf)
  local entry = ensure(buf)
  local pending = entry.pending_auto_align or 0
  if pending > 0 then
    entry.pending_auto_align = pending - 1
    return true
  end
  return false
end

---Return the number of pending automatic align suppressions.
---@param buf integer
---@return integer
function M.pending_auto_align(buf)
  return ensure(buf).pending_auto_align or 0
end

local function current_undo_sequence(buf)
  local ok, seq = pcall(vim.api.nvim_buf_call, buf, function()
    local ok_tree, tree = pcall(vim.fn.undotree)
    if not ok_tree or type(tree) ~= "table" then
      return nil
    end
    return tree.seq_cur
  end)
  if not ok or seq == nil then
    return nil
  end
  return seq
end

---Refresh the cached undo sequence for the buffer.
---@param buf integer
function M.record_undo_state(buf)
  local seq = current_undo_sequence(buf)
  if seq == nil then
    return
  end
  ensure(buf).undo_seq = seq
end

---Check whether the buffer recently triggered an undo operation.
---@param buf integer
---@return boolean
function M.did_undo(buf)
  local seq = current_undo_sequence(buf)
  if seq == nil then
    return false
  end
  local entry = ensure(buf)
  local previous = entry.undo_seq
  entry.undo_seq = seq
  if not previous then
    return false
  end
  return seq < previous
end

return M
