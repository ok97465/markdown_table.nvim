local AlignmentService = require("markdown_table.alignment_service")

local M = {}

local registry = {}

local function resolve_alignment_service()
  if not registry.alignment_service then
    registry.alignment_service = AlignmentService.new()
  end
  return registry.alignment_service
end

---Return a shared alignment service instance.
---@return table
function M.alignment_service()
  return resolve_alignment_service()
end

---Override the alignment service instance (useful for tests).
---@param service table|nil
function M.set_alignment_service(service)
  registry.alignment_service = service
end

---Clear registered dependencies to force re-initialization.
function M.reset()
  registry = {}
end

return M
