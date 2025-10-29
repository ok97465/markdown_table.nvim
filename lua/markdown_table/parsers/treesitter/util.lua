local M = {}

---Trim leading and trailing whitespace from text.
---@param text string
---@return string
function M.trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

---Parse a markdown alignment token (":---:" etc.) into alignment metadata.
---@param text string
---@return {align: string, colon_left: boolean, colon_right: boolean}|nil
function M.parse_alignment(text)
  local stripped = M.trim(text or "")
  if stripped == "" then
    return nil
  end

  if not stripped:match("^:?-+:?$") then
    return nil
  end

  local left = stripped:sub(1, 1) == ":"
  local right = stripped:sub(-1, -1) == ":"
  local align
  if left and right then
    align = "center"
  elseif right then
    align = "right"
  elseif left then
    align = "left"
  else
    align = "none"
  end

  return {
    align = align,
    colon_left = left,
    colon_right = right,
  }
end

return M
