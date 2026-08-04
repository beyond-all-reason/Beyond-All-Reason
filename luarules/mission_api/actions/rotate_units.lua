local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function rotateUnits(unitName, direction)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if direction then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                if not (direction.x-testposx == 0 and direction.z-testposz == 0) then
                    Spring.SetUnitDirection(unitID, direction.x-testposx, direction.y, direction.z-testposz)
                end
            end
        end
    end
end

return {
    {
	    type = 'RotateUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'direction', required = true, type = ParameterTypes.Position }, -- Point on the map towards which the unit rotates
	    },
	    actionFunction = rotateUnits,
    },
}