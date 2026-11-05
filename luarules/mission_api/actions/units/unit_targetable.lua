local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local tracking = GG['MissionAPI'].Modules.Tracking

local function setTargetable(unitName, targetable)
	if tracking.IsUnitNameUntracked(unitName) then return end

	local untargetable = not targetable
	for unitID in pairs(GG['MissionAPI'].trackedUnitIDs[unitName]) do
		GG.SetUnitUntargetable(unitID, untargetable)
	end
end

return {
	{
		type = 'UnitTargetable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'targetable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setTargetable,
	}
}
