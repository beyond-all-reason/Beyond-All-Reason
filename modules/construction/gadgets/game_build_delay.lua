
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
	if Debuff.IsDelayed(builderID) and spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	return not Debuff.IsDelayed(builderID)
end
