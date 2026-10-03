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

local Debuff = require("modules/construction/lib/build_debuff")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

---@param ctx ConstructionBuildContext
---@return boolean
local function mayBuild(ctx)
	---@type ConstructionContract
	local Construction = ModuleHandler.Contract(Modules.Construction)
	ctx.delayed = Debuff.IsDelayed(ctx.builderID)
	return ModuleHandler.Evaluate(Construction.Build, ctx) == true
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
