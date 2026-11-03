-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
-- Unit defs are shared by every team, so for one team the option is hidden from its build menus instead, and shown
-- again (GG.BuildBlocking, reason 'hidden': not buildable and out of the menus).
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local HIDDEN_REASON = 'hidden'

local function addBuildOption(builtDefName, builderDefName, buildMenuPosition, teamID)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	if teamID then
		GG.BuildBlocking.RemoveBlockedUnit(builtUnitDefID, teamID, HIDDEN_REASON)
		return
	end
	GG.DynamicBuildOptions.Add(builtUnitDefID, UnitDefNames[builderDefName].id, buildMenuPosition)
end

local function removeBuildOption(builtDefName, builderDefName, teamID)
	local builtUnitDefID = UnitDefNames[builtDefName].id
	if teamID then
		GG.BuildBlocking.AddBlockedUnit(builtUnitDefID, teamID, HIDDEN_REASON)
		return
	end
	GG.DynamicBuildOptions.Remove(builtUnitDefID, UnitDefNames[builderDefName].id)
end

return {
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			-- One of builderDefName (every team) or teamName (every builder of that team, undoing its RemoveBuildOption).
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'buildMenuPosition', required = false, type = ParameterTypes.PositiveInteger },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			requiresOneOf = { 'builderDefName', 'teamName' },
		},
		actionFunction = addBuildOption,
	},
	{
		type = 'RemoveBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
			-- One of builderDefName (every team) or teamName (every builder of that team).
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			requiresOneOf = { 'builderDefName', 'teamName' },
		},
		actionFunction = removeBuildOption,
	},
}
