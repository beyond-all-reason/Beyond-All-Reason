local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function rotateUnits(unitName, dirx, dirz)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if dirx and dirz then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                Spring.SetUnitDirection(unitID, dirx-testposx, 0, dirz-testposz)
            end
        end
    end
end

return {
    {
	    type = 'RotateUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'dirx', required = false, type = ParameterTypes.Number }, -- Point on the map towards which the unit rotates
            { name = 'dirz', required = false, type = ParameterTypes.Number },  -- Point on the map towards which the unit rotates
	    },
	    actionFunction = rotateUnits,
    },
}