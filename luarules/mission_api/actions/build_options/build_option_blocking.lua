-- Greys a build option out for a team, optionally for one builder type only (GG.BuildBlocking, reason 'mission').
-- A team-wide block with hidden also gets the reason 'hidden', which takes the type out of the build menu.
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local MISSION_REASON = 'mission'
local HIDDEN_REASON = 'hidden'

local function disableBuildOption(builtDefName, builderDefName, teamID, hidden)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.AddBlockedUnit(builtUnitDefID, teamID, MISSION_REASON, builderUnitDefID)

	if hidden and not builderUnitDefID then
		GG.BuildBlocking.AddBlockedUnit(builtUnitDefID, teamID, HIDDEN_REASON)
	end
end

local function enableBuildOption(builtDefName, builderDefName, teamID)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	local builderUnitDefID = builderDefName and UnitDefNames[builderDefName].id
	GG.BuildBlocking.RemoveBlockedUnit(builtUnitDefID, teamID, MISSION_REASON, builderUnitDefID)
	if not builderUnitDefID then
		GG.BuildBlocking.RemoveBlockedUnit(builtUnitDefID, teamID, HIDDEN_REASON)
	end
end

return {
	{
		type = 'DisableBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamID', required = true, type = ParameterTypes.TeamID },
			-- Ignored with builderDefName: the build menu hides team-wide blocks only.
			{ name = 'hidden', required = false, type = ParameterTypes.Boolean },
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
