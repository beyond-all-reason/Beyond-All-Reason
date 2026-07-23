local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function despawnUnits(unitName, selfDestruct, reclaimed)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	-- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
	local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
		if Spring.GetUnitIsDead(unitID) == false then
			Spring.DestroyUnit(unitID, selfDestruct, reclaimed)
		end
	end
end

return {
	type = 'DespawnUnits',
	parameters = {
		{ name = 'unitName', required = true, type = Types.UnitName },
		{ name = 'selfDestruct', required = false, type = Types.Boolean },
		{ name = 'reclaimed', required = false, type = Types.Boolean },
	},
	actionFunction = despawnUnits,
}
