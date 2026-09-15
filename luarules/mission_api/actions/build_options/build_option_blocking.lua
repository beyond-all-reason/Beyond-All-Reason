-- DisableBuildOption greys a build option out for a team, EnableBuildOption lifts that
-- again (GG.BuildBlocking, api_build_blocking.lua). With builderUnitDefID only orders
-- from that builder unit type are refused. Blocks stack per reason key, so enabling
-- only removes the mission's own block, never terrain or modoption restrictions.
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local MISSION_REASON = 'mission'

local function disableBuildOption(builtUnitDefID, builderUnitDefID, teamID)
	GG.BuildBlocking.AddBlockedUnit(builtUnitDefID, teamID, MISSION_REASON, builderUnitDefID)
end

local function enableBuildOption(builtUnitDefID, builderUnitDefID, teamID)
	GG.BuildBlocking.RemoveBlockedUnit(builtUnitDefID, teamID, MISSION_REASON, builderUnitDefID)
end

return {
	{
		type = 'DisableBuildOption',
		parameters = {
			{ name = 'builtUnitDefID', required = true, type = ParameterTypes.UnitDefID },
			{ name = 'builderUnitDefID', required = false, type = ParameterTypes.UnitDefID },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableBuildOption,
	},
	{
		type = 'EnableBuildOption',
		parameters = {
			{ name = 'builtUnitDefID', required = true, type = ParameterTypes.UnitDefID },
			{ name = 'builderUnitDefID', required = false, type = ParameterTypes.UnitDefID },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableBuildOption,
	},
}
