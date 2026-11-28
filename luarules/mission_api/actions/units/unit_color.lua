local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

local function setUnitColor(unitName, color)
	local tracking = GG["MissionAPI"].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then
		return
	end

	local unitColor = GG["MissionAPI"].Modules.UnitColor
	for unitID in pairs(GG["MissionAPI"].trackedUnitIDs[unitName]) do
		unitColor.Set(unitID, color)
	end
end

local function clearUnitColor(unitName)
	setUnitColor(unitName, nil)
end

return {
	{
		type = "SetUnitColor",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
			{ name = "color", required = true, type = ParameterTypes.Color },
		},
		actionFunction = setUnitColor,
	},
	{
		type = "ClearUnitColor",
		parameters = {
			{ name = "unitName", required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = clearUnitColor,
	},
}
