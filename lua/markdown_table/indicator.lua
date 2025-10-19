local state = require("markdown_table.state")

local M = {}

local previous_winbar = setmetatable({}, { __mode = "k" })

local function active_config()
  local cfg = state.config().indicator or {}
  return {
    enable = cfg.enable ~= false,
    text = cfg.text or "[Table Mode]",
    highlight = cfg.highlight or "Title",
  }
end

local function windows_for_buffer(buf)
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function set_winbar(win, value)
  vim.api.nvim_set_option_value("winbar", value, { scope = "local", win = win })
end

function M.show(buf)
  local cfg = active_config()
  if not cfg.enable then
    M.hide(buf)
    return
  end

  local decorated = string.format(" %%#%s#%s%%*", cfg.highlight, cfg.text)

  for _, win in ipairs(windows_for_buffer(buf)) do
    if previous_winbar[win] == nil then
      previous_winbar[win] = vim.api.nvim_get_option_value("winbar", { scope = "local", win = win })
    end
    set_winbar(win, decorated)
  end
end

function M.hide(buf)
  for _, win in ipairs(windows_for_buffer(buf)) do
    local prev = previous_winbar[win]
    if prev ~= nil then
      set_winbar(win, prev)
    else
      set_winbar(win, "")
    end
    previous_winbar[win] = nil
  end
end

function M.refresh(buf)
  if state.is_active(buf) then
    M.show(buf)
  else
    M.hide(buf)
  end
end

return M

