local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function transferUnits(unitName, newTeam, captured)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
		local given = Spring.GetUnitAllyTeam(unitID) == Spring.GetTeamAllyTeamID(newTeam)
		GG['MissionAPI'].transferringUnits = true
		GG['MissionAPI'].capturingUnits = captured or nil
		Spring.TransferUnit(unitID, newTeam, given)
		GG['MissionAPI'].transferringUnits = nil
		GG['MissionAPI'].capturingUnits = nil
	end
end

return {
	{
		type = 'TransferUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'newTeam', required = true, type = ParameterTypes.TeamID },
			{ name = 'captured', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = transferUnits,
	}
}
