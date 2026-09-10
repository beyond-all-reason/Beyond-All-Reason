local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function transferUnits(unitName, newTeam, captured)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])

	local newAllyTeamID = Spring.GetTeamAllyTeamID(newTeam)

	GG['MissionAPI'].transferringUnits = true
	for unitID in pairs(trackedUnitIDs) do
		-- Gift units to allies even with captured=true to comply with sharing rules.
		local given = Spring.GetUnitAllyTeam(unitID) == newAllyTeamID
		GG['MissionAPI'].capturingUnits = captured
		Spring.TransferUnit(unitID, newTeam, given)
		GG['MissionAPI'].capturingUnits = nil
	end
	GG['MissionAPI'].transferringUnits = nil
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
