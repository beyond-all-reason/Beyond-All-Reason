if not gadgetHandler:IsSyncedCode() then
	return false
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Block ventless geo",
		desc    = "Fixes an engine bug that lets you place geos anywhere",
		author  = "Sprung",
		date    = "2023-10-16",
		license = "Public Domain",
		layer   = 0,
		enabled = not Script.IsEngineMinVersion(105, 0, 2032),
	}
end

local function isNearGeo(x, z)
	-- modded geos can be bigger than 40 elmo but w/e, this gadget only lives
	-- until next engine anyway, plus centered placement still works
	local features = Spring.GetFeaturesInCylinder(x, z, 40*math.sqrt(2))
	for i = 1, #features do
		if FeatureDefs[Spring.GetFeatureDefID(features[i])].geoThermal then
			return true
		end
	end

	return false
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.BUILD)
	gadgetHandler:RegisterAllowCommand(CMD.INSERT)
end

local CMD_INSERT = CMD.INSERT
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_INSERT then
		return gadget:AllowCommand(unitID, unitDefID, teamID, cmdParams[2], {cmdParams[4], cmdParams[5], cmdParams[6]}, cmdParams[3])
	else
		return not UnitDefs[-cmdID].needGeo or isNearGeo(cmdParams[1], cmdParams[3])
	end
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	return not UnitDefs[unitDefID].needGeo or isNearGeo(x, z)
end
