-- Adds or removes a build option of a builder or factory type, for its current and future units (GG.DynamicBuildOptions).
-- With teamName it is blocked for that team instead (GG.BuildBlocking, reason 'hidden': also out of the build menus).
local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local HIDDEN_REASON = 'hidden'

local function dropQueuedBuilds(builtUnitDefID, teamID)
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef.isBuilder then
			-- ctrl: a factory's own build queue, not the orders for its new units
			local options = unitDef.isFactory and { 'alt', 'ctrl' } or { 'alt' }
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, { -builtUnitDefID }, options)
		end
	end
end

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
		dropQueuedBuilds(builtUnitDefID, teamID)
		return
	end
	GG.DynamicBuildOptions.Remove(builtUnitDefID, UnitDefNames[builderDefName].id)
end

return {
	{
		type = 'AddBuildOption',
		parameters = {
			{ name = 'builtDefName', required = true, type = ParameterTypes.UnitDefName },
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
			{ name = 'builderDefName', required = false, type = ParameterTypes.UnitDefName },
			{ name = 'teamName', required = false, type = ParameterTypes.TeamName },
			requiresOneOf = { 'builderDefName', 'teamName' },
		},
		actionFunction = removeBuildOption,
	},
}
