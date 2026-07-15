local ModuleHandler = VFS.Include("modules/module_handler.lua")

--- Entry points for evaluating this module's policy pipelines
--- (modules/sharing/policies/<category>/, filename order, first result wins).
--- Pipelines load lazily and once per Lua state.

local M = {}

local pipelines ---@type table<string, PolicyDescriptor[]>|nil
local function getPipelines()
	if not pipelines then
		pipelines = ModuleHandler.LoadPolicies("sharing")
	end
	return pipelines
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function M.CalcResourcePolicy(ctx, resourceType)
	return ModuleHandler.Evaluate(getPipelines().resource or {}, ctx, resourceType) --[[@as ResourcePolicyResult]]
end

---Build per-pair policy (expose) from context
---@param ctx PolicyContext
---@return UnitPolicyResult
function M.GetUnitPolicy(ctx)
	return ModuleHandler.Evaluate(getPipelines().unit or {}, ctx) --[[@as UnitPolicyResult]]
end

return M
