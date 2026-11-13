local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function defineAiRegion(regionName, teamID, area)
	local modules = GG["MissionAPI"].Modules
	local polygon = modules.AreaPolygons.FromArea(area)
	local regionID = modules.AiRegions.Define(regionName, teamID, polygon)
	if regionID then
		GG["CampaignAI"].DefineAiRegion(regionID, polygon, teamID)
	end
end

local function clearAiRegion(regionName)
	local regionID, teamID = GG["MissionAPI"].Modules.AiRegions.Clear(regionName)
	if regionID then
		GG["CampaignAI"].ClearAiRegion(regionID, teamID)
	end
end

return {
	{
		type = "DefineAiRegion",
		parameters = {
			{ name = "regionName", required = true, type = ParameterTypes.RegionName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "area", required = true, type = ParameterTypes.Area },
		},
		actionFunction = defineAiRegion,
	},
	{
		type = "ClearAiRegion",
		parameters = {
			{ name = "regionName", required = true, type = ParameterTypes.RegionName },
		},
		actionFunction = clearAiRegion,
	},
}
