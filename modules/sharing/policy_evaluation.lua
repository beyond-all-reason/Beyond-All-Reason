local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Enums = VFS.Include("modules/sharing/enums.lua")

local PolicyCategory = Enums.PolicyCategory

--- Entry points for evaluating this module's policy pipelines
--- (modules/sharing/policies/<category>/, filename order, first result wins).
--- Pipelines load lazily and once per Lua state.

local M = {}

local pipelines ---@type table<string, PolicyDescriptor[]>|nil

---@param category string
---@return PolicyDescriptor[]
local function pipeline(category)
	if not pipelines then
		pipelines = ModuleHandler.LoadPolicies("sharing")
	end
	local found = pipelines[category]
	if not found then
		error(string.format("sharing: no policy pipeline %q (expected modules/sharing/policies/%s.lua)", category, category))
	end
	return found
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function M.CalcResourcePolicy(ctx, resourceType)
	return ModuleHandler.Evaluate(pipeline(PolicyCategory.Resource), ctx, resourceType) --[[@as ResourcePolicyResult]]
end

---Build per-pair policy (expose) from context
---@param ctx PolicyContext
---@return UnitPolicyResult
function M.GetUnitPolicy(ctx)
	return ModuleHandler.Evaluate(pipeline(PolicyCategory.Unit), ctx) --[[@as UnitPolicyResult]]
end

return M
