-- Greys a build option out for a team, optionally for one builder type only (GG.BuildBlocking, reason 'mission').
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local MISSION_REASON = 'mission'

local function disableBuildOption(builtDefName, builderDefName, teamID)
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.AddBlockedUnit(UnitDefNames[builtDefName].id, teamID, MISSION_REASON, builderUnitDefID)
end

local function enableBuildOption(builtDefName, builderDefName, teamID)
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.RemoveBlockedUnit(UnitDefNames[builtDefName].id, teamID, MISSION_REASON, builderUnitDefID)
end

return {
	{
		type = 'DisableBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = disableBuildOption,
	},
	{
		type = 'EnableBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
		},
		actionFunction = enableBuildOption,
	},
}
