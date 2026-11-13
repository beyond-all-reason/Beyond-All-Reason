local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local DEFAULT_BUILDS_AT_ONCE = 3 -- all at once, the AI's own default, can wall its builders in

local function defineBuildArea(buildAreaName, teamID, area, unitDefName, facing, buildsAtOnce)
	if not UnitDefNames[unitDefName].isImmobile then
		local message = "[Mission API] Build area needs a structure, not " .. unitDefName .. ": " .. buildAreaName
		Spring.Log("build_area.lua", LOG.WARNING, message)
		return
	end

	local modules = GG["MissionAPI"].Modules
	local buildAreaID = modules.BuildAreas.Define(buildAreaName, teamID)
	if not buildAreaID then
		return
	end

	local polygon = modules.AreaPolygons.FromArea(area)
	local unitDefID = UnitDefNames[unitDefName].id
	facing = BAR.Utilities.FacingToNumber(facing or 0)
	buildsAtOnce = buildsAtOnce or DEFAULT_BUILDS_AT_ONCE
	GG["CampaignAI"].DefineBuildArea(buildAreaID, polygon, unitDefID, facing, buildsAtOnce, teamID)
end

return {
	{
		type = "DefineBuildArea",
		parameters = {
			{ name = "buildAreaName", required = true, type = ParameterTypes.BuildAreaName },
			{ name = "teamName", required = true, type = ParameterTypes.TeamName },
			{ name = "area", required = true, type = ParameterTypes.Area },
			{ name = "unitDefName", required = true, type = ParameterTypes.UnitDefName },
			{ name = "facing", required = false, type = ParameterTypes.Facing },
			{ name = "buildsAtOnce", required = false, type = ParameterTypes.PositiveInteger },
		},
		actionFunction = defineBuildArea,
	},
}
