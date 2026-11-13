local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local AI_DEFAULT_RETREAT = -1 -- each unit by its own type's setting

-- One unit, the one with the lowest ID, so every run picks the same.
local function getUnitID(unitName)
	local unitIDs = table.keys(GG["MissionAPI"].trackedUnitIDs[unitName] or {})
	table.sort(unitIDs)
	return unitIDs[1]
end

local function setSquadRetreatThreshold(squadName, threshold)
	local squadID, teamID, isAssembled = GG["MissionAPI"].Modules.Squads.Get(squadName)
	if squadID then
		GG["CampaignAI"].SetSquadRetreat(squadID, threshold or AI_DEFAULT_RETREAT, isAssembled, teamID)
	end
end

local function setSquadTarget(squadName, unitName)
	local unitID = getUnitID(unitName)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.GetAssembled(squadName)
	if squadID and unitID then
		GG["CampaignAI"].SetSquadTarget(squadID, unitID, teamID)
	end
end

local function setSquadEscort(squadName, unitName)
	local unitID = getUnitID(unitName)
	local squadID, teamID = GG["MissionAPI"].Modules.Squads.GetAssembled(squadName)
	if squadID and unitID then
		GG["CampaignAI"].SetSquadEscort(squadID, unitID, teamID)
	end
end

return {
	{
		type = "SetSquadRetreatThreshold",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
			{ name = "threshold", required = false, type = ParameterTypes.Fraction }, -- of a unit's health; 0 never retreats
		},
		actionFunction = setSquadRetreatThreshold,
	},
	{
		type = "SetSquadTarget",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = setSquadTarget,
	},
	{
		type = "SetSquadEscort",
		parameters = {
			{ name = "squadName", required = true, type = ParameterTypes.SquadName },
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = setSquadEscort,
	},
}
