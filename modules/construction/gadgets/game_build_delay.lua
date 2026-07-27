
function gadget:GetInfo()
	return {
		name = "Construction Build Delay",
		desc = "Holds delayed builders off build steps until their delay expires",
		author = "BAR modules",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Debuff = VFS.Include("modules/construction/lib/build_debuff.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

local pipelines = ModuleHandler.LoadPolicies(Modules.Construction) ---@type ConstructionPipelines

---@param ctx ConstructionBuildContext
---@return boolean
local function mayBuild(ctx)
	ctx.delayed = Debuff.IsDelayed(ctx.builderID)
	return ModuleHandler.Evaluate(pipelines.build, ctx) == true
end

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

---@param frame integer
function gadget:GameFrame(frame)
	Debuff.Expire(frame)
end

---@param unitID integer
function gadget:UnitDestroyed(unitID)
	Debuff.Release(unitID)
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
	if spGetUnitIsBeingBuilt(unitID) then
		return mayBuild({
			builderID = builderID,
			builderTeam = builderTeam,
			delayed = false,
			unitID = unitID,
			unitDefID = unitDefID,
			part = part,
		})
	end
	return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	return mayBuild({
		builderID = builderID,
		builderTeam = builderTeam,
		delayed = false,
		featureID = featureID,
		part = part,
	})
end
