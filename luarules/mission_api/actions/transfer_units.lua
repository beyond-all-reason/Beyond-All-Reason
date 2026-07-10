local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function transferUnits(unitName, newTeam)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local trackedUnitIDs = table.copy((GG['MissionAPI'].trackedUnitIDs or {})[unitName] or {})
	for unitID in pairs(trackedUnitIDs) do
		local given = Spring.GetUnitAllyTeam(unitID) == Spring.GetTeamAllyTeamID(newTeam)
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

return {
	name = 'TransferUnits',
	parameters = {
		{ name = 'unitName', required = true, type = Types.UnitName },
		{ name = 'newTeam', required = true, type = Types.TeamID },
	},
	execute = transferUnits,
}
