local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setAiMexCap(teamID, share, countsAllies)
	GG["CampaignAI"].SetMexCap(share, countsAllies or false, teamID)
end

local function setAiMilitaryQuota(teamID, scouts, attackPower, raidPower)
	GG["CampaignAI"].SetMilitaryQuota(scouts, attackPower, raidPower, teamID)
end

local function setUnitDefRetreatThreshold(unitDefName, threshold, teamID)
	GG["CampaignAI"].SetUnitDefRetreat(UnitDefNames[unitDefName].id, threshold, teamID)
end

return {
	{
		type = "SetAiMexCap",
		parameters = {
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "share", required = true, type = ParameterTypes.Fraction }, -- of the map's metal spots; 1 is no cap
			{ name = "countsAllies", required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = setAiMexCap,
	},
	{
		type = "SetAiMilitaryQuota",
		parameters = {
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "scouts", required = false, type = ParameterTypes.Quantity }, -- the most at once
			{ name = "attackPower", required = false, type = ParameterTypes.Quantity }, -- the least an attack group sets out with
			{ name = "raidPower", required = false, type = ParameterTypes.Quantity }, -- the least a raid sets out with
			requiresOneOf = { "scouts", "attackPower", "raidPower" },
		},
		actionFunction = setAiMilitaryQuota,
	},
	{
		type = "SetUnitDefRetreatThreshold",
		parameters = {
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "threshold", required = true, type = ParameterTypes.Fraction }, -- of a unit's health
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = setUnitDefRetreatThreshold,
	},
}
