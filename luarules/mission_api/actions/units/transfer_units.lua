local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function transferUnits(unitName, newTeamName)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end
	local newTeamID = GG['MissionAPI'].Teams[newTeamName]

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
		local given = Spring.GetUnitAllyTeam(unitID) == Spring.GetTeamAllyTeamID(newTeamID)
		Spring.TransferUnit(unitID, newTeamID, given)
	end
end

return {
	{
		type = 'TransferUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'newTeamName', required = true, type = ParameterTypes.TeamName },
		},
		actionFunction = transferUnits,
	}
}
