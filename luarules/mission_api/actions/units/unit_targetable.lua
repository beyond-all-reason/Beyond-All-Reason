local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local tracking = GG['MissionAPI'].Modules.Tracking

local function setTargetable(unitName, targetable)
	if tracking.IsUnitNameUntracked(unitName) then return end
	GG.SetUnitUntargetable(GG['MissionAPI'].trackedUnitIDs[unitName], not targetable)
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
