local position = require("markdown_table.position")

local M = {}

local function clamp_exclusive(end_col, start_col, ensure_width)
  if end_col < start_col then
    end_col = start_col
  end
  if ensure_width and end_col <= start_col then
    end_col = start_col + 1
  end
  return end_col
end

local function char_at(text, col)
  if col < 0 then
    return ""
  end
  return text:sub(col + 1, col + 1)
end

local function is_space_char(char)
  return char == " " or char == "\t"
end

local function extract_ranges(buf, cursor)
  local info = position.locate(buf, cursor)
  if not info then
    return nil
  end

  local row = info.block.rows[info.row]
  if not row then
    return nil
  end

  local spans = row.cell_spans or {}
  local span = spans[info.column]
  if not span then
    return nil
  end

  local start_col = span.start_col or 0
  local end_col = span.end_col or start_col
  local line_index = row.line

  if not line_index then
    line_index = info.block.start_line + info.row - 1
  end

  local line = row.raw
  if type(line) ~= "string" then
    line = info.block.lines[info.row]
  end
  if type(line) ~= "string" then
    line = vim.api.nvim_buf_get_lines(buf, line_index, line_index + 1, false)[1] or ""
  end

  local line_len = #line
  if end_col > line_len then
    end_col = line_len
  end

  local around_start = start_col
  while around_start > 0 do
    local left_char = char_at(line, around_start - 1)
    if is_space_char(left_char) then
      around_start = around_start - 1
    elseif left_char == "|" then
      around_start = around_start - 1
      break
    else
      break
    end
  end
  local around_end = clamp_exclusive(end_col, start_col, true)
  while around_end < line_len do
    local right_char = char_at(line, around_end)
    if is_space_char(right_char) then
      around_end = around_end + 1
    elseif right_char == "|" then
      around_end = around_end + 1
      while around_end < line_len and is_space_char(char_at(line, around_end)) do
        around_end = around_end + 1
      end
      break
    else
      break
    end
  end
  local around = {
    start_row = line_index,
    start_col = around_start,
    end_row = line_index,
    end_col = around_end,
    ensure_width = true,
  }

  local inner_start = start_col
  local inner_end = start_col

  if end_col > start_col then
    local segment = line:sub(start_col + 1, end_col)
    if #segment > 0 then
      local first = segment:find("%S")
      if first then
        inner_start = start_col + first - 1
        local rev = segment:reverse():find("%S")
        if rev then
          local last = #segment - rev + 1
          inner_end = start_col + last
        else
          inner_end = inner_start
        end
      end
    end
  end

  local inner = {
    start_row = line_index,
    start_col = inner_start,
    end_row = line_index,
    end_col = clamp_exclusive(inner_end, inner_start, false),
    ensure_width = false,
  }

  return {
    around = around,
    inner = inner,
  }
end

local function to_mark_pos(row, col)
  return row + 1, col
end

local function store_marks(range)
  local buf = vim.api.nvim_get_current_buf()
  local start_line, start_col = to_mark_pos(range.start_row, range.start_col)
  local end_line = range.end_row + 1
  local end_col = clamp_exclusive(range.end_col, range.start_col, range.ensure_width)
  if end_col > range.start_col then
    end_col = end_col - 1
  else
    end_col = range.start_col
  end

  local opts = {}
  vim.api.nvim_buf_set_mark(buf, "<", start_line, start_col, opts)
  vim.api.nvim_buf_set_mark(buf, ">", end_line, end_col, opts)
  vim.api.nvim_buf_set_mark(buf, "[", start_line, start_col, opts)
  vim.api.nvim_buf_set_mark(buf, "]", end_line, end_col, opts)
end

local function ensure_range(kind)
  local buf = vim.api.nvim_get_current_buf()
  local ranges = extract_ranges(buf, vim.api.nvim_win_get_cursor(0))
  if not ranges then
    return nil
  end
  local selection = ranges[kind or "inner"]
  if not selection then
    return nil
  end
  return vim.deepcopy(selection)
end

local function current_register()
  local reg = vim.v.register
  if not reg or reg == "" then
    return '"'
  end
  return reg
end

local function get_text(buf, range)
  return vim.api.nvim_buf_get_text(
    buf,
    range.start_row,
    range.start_col,
    range.end_row,
    range.end_col,
    {}
  )
end

local function join_lines(lines)
  if #lines == 0 then
    return ""
  end
  return table.concat(lines, "\n")
end

-- Store yank text in the current register and return metadata about it.
local function set_charwise_register(text, contents)
  local register = current_register()
  vim.fn.setreg(register, text, "c")
  local regtype = vim.fn.getregtype(register)
  local regcontents = contents or {}
  if #regcontents == 0 then
    regcontents = vim.split(text, "\n", { plain = true })
  end
  return {
    name = register,
    type = regtype,
    contents = regcontents,
  }
end

local function fallback(keys)
  if not keys or keys == "" then
    return
  end
  local literal = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(literal, "n", false)
end

-- Emit TextYankPost so highlight-on-yank (and similar) integrations run.
local function notify_yank(buf, yank)
  if not yank or not yank.name then
    return
  end
  local event_payload = {
    regtype = yank.type,
    regname = yank.name,
    regcontents = yank.contents,
    operator = "y",
    visual = false,
  }

  local function with_yank_event(fn)
    local wrappers = {}

    local function wrap(tbl)
      if not tbl then
        return
      end
      local original = tbl.on_yank
      if type(original) ~= "function" then
        return
      end
      local wrapped = function(opts)
        opts = opts or {}
        if opts.event == nil then
          opts.event = event_payload
        end
        return original(opts)
      end
      table.insert(wrappers, { tbl, original })
      tbl.on_yank = wrapped
    end

    wrap(vim.highlight)
    if vim.hl and vim.hl ~= vim.highlight then
      wrap(vim.hl)
    end

    local ok, err = pcall(fn)

    for i = #wrappers, 1, -1 do
      local entry = wrappers[i]
      entry[1].on_yank = entry[2]
    end

    if not ok then
      error(err)
    end
  end

  local function run_autocmds()
    local exec_autocmds = vim.api.nvim_exec_autocmds
    local need_fallback = true
    if type(exec_autocmds) == "function" then
      local ok, err = pcall(exec_autocmds, "TextYankPost", {
        buffer = buf,
        data = event_payload,
      })
      if ok then
        need_fallback = false
      else
        vim.schedule(function()
          vim.notify(string.format("markdown_table: failed to emit TextYankPost via exec_autocmds: %s", err), vim.log.levels.DEBUG)
        end)
      end
    end
    if need_fallback then
      local ok, err = pcall(function()
        vim.api.nvim_buf_call(buf, function()
          vim.cmd("silent doautocmd <nomodeline> TextYankPost")
        end)
      end)
      if not ok then
        vim.schedule(function()
          vim.notify(string.format("markdown_table: failed to emit TextYankPost via doautocmd: %s", err), vim.log.levels.DEBUG)
        end)
      end
    end
  end

  local ok_run, err_run = pcall(function()
    with_yank_event(run_autocmds)
  end)
  if not ok_run then
    vim.schedule(function()
      vim.notify(string.format("markdown_table: yank autocmd dispatch failed: %s", err_run), vim.log.levels.DEBUG)
    end)
  end
end

local function yank_range(kind, fallback_keys)
  local buf = vim.api.nvim_get_current_buf()
  local range = ensure_range(kind)
  if not range then
    fallback(fallback_keys)
    return false
  end
  local lines = get_text(buf, range)
  local text = join_lines(lines)
  local yank = set_charwise_register(text, lines)
  store_marks(range)
  notify_yank(buf, yank)
  return true
end

local function replace_range(range, replacement)
  local buf = vim.api.nvim_get_current_buf()
  local lines = type(replacement) == "table" and replacement or { replacement or "" }
  vim.api.nvim_buf_set_text(
    buf,
    range.start_row,
    range.start_col,
    range.end_row,
    range.end_col,
    lines
  )
end

local function delete_range(kind, fallback_keys, opts)
  local buf = vim.api.nvim_get_current_buf()
  local range = ensure_range(kind)
  if not range then
    fallback(fallback_keys)
    return false
  end

  local captured = join_lines(get_text(buf, range))
  set_charwise_register(captured)

  replace_range(range, "")
  store_marks(range)

  local cursor_target = { range.start_row + 1, range.start_col }
  vim.api.nvim_win_set_cursor(0, cursor_target)

  if opts and opts.insert_mode then
    vim.schedule(function()
      if vim.api.nvim_get_mode().mode == "n" then
        vim.api.nvim_feedkeys("i", "n", false)
      end
    end)
  end

  return true
end

local function select_range(kind)
  local range = ensure_range(kind)
  if not range then
    local cancel = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
    vim.api.nvim_feedkeys(cancel, "n", false)
    return false
  end
  store_marks(range)

  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { range.start_row + 1, range.start_col })
    vim.cmd("normal! gv")
  end

  return true
end

function M.range(buf, cursor, kind)
  buf = buf or vim.api.nvim_get_current_buf()
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  local ranges = extract_ranges(buf, cursor)
  if not ranges then
    return nil
  end
  local selection = ranges[kind or "inner"]
  if not selection then
    return nil
  end
  return vim.deepcopy(selection)
end

function M.select(kind)
  return select_range(kind or "inner")
end

function M.yank_inner()
  return yank_range("inner", "yi|")
end

function M.yank_around()
  return yank_range("around", "ya|")
end

function M.delete_inner(opts)
  return delete_range("inner", "di|", opts)
end

function M.change_inner()
  return delete_range("inner", "ci|", { insert_mode = true })
end

local function ensure_mappings(mappings)
  for _, mapping in ipairs(mappings) do
    if mapping.lhs then
      vim.keymap.set(mapping.mode, mapping.lhs, mapping.rhs, mapping.opts)
    end
  end
end

function M.setup(opts)
  opts = opts or {}
  local keymaps = opts.keymaps or {}
  local inner = keymaps.inner
  local around = keymaps.around

  if inner == nil then
    inner = "i|"
  end
  if around == nil then
    around = "a|"
  end

  if inner and inner ~= "" then
    ensure_mappings({
      {
        mode = "n",
        lhs = "yi|",
        rhs = function()
          return M.yank_inner()
        end,
        opts = { desc = "Yank markdown table cell (inner)", silent = true },
      },
      {
        mode = "n",
        lhs = "di|",
        rhs = function()
          return M.delete_inner()
        end,
        opts = { desc = "Delete markdown table cell (inner)", silent = true },
      },
      {
        mode = "n",
        lhs = "ci|",
        rhs = function()
          return M.change_inner()
        end,
        opts = { desc = "Change markdown table cell (inner)", silent = true },
      },
      {
        mode = { "o", "x" },
        lhs = inner,
        rhs = function()
          if not M.select("inner") then
            return vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          end
          return vim.api.nvim_replace_termcodes("<Ignore>", true, false, true)
        end,
        opts = { desc = "Markdown table cell (inner)", silent = true, expr = true, replace_keycodes = true },
      },
    })
  end

  if around and around ~= "" then
    ensure_mappings({
      {
        mode = "n",
        lhs = "ya|",
        rhs = function()
          return M.yank_around()
        end,
        opts = { desc = "Yank markdown table cell (around)", silent = true },
      },
      {
        mode = { "o", "x" },
        lhs = around,
        rhs = function()
          if not M.select("around") then
            return vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          end
          return vim.api.nvim_replace_termcodes("<Ignore>", true, false, true)
        end,
        opts = { desc = "Markdown table cell (around)", silent = true, expr = true, replace_keycodes = true },
      },
    })
  end
end

return M
