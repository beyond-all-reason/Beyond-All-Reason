local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function moveUnits(unitName, posx, posz, dirx, dirz, randomRadius, alwaysAboveSea)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if randomRadius and randomRadius > 0 then
                Spring.SetUnitPosition(unitID, posx+math.random(-randomRadius, randomRadius), posz+math.random(-randomRadius, randomRadius), alwaysAboveSea)
            else
                Spring.SetUnitPosition(unitID, posx, posz, alwaysAboveSea)
            end
            
            if dirx and dirz then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                Spring.SetUnitDirection(unitID, dirx-testposx, 0, dirz-testposz)
            end
        end
    end
end

return {
    {
	    type = 'MoveUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'posx', required = true, type = ParameterTypes.Number },
            { name = 'posz', required = true, type = ParameterTypes.Number },
            { name = 'dirx', required = false, type = ParameterTypes.Number }, -- Point on the map towards which the unit rotates
            { name = 'dirz', required = false, type = ParameterTypes.Number },  -- Point on the map towards which the unit rotates
            { name = 'randomRadius', required = false, type = ParameterTypes.Number }, -- Spread teleported units around in radius this big.
            { name = 'alwaysAboveSea', required = false, type = ParameterTypes.Boolean },
	    },
	    actionFunction = moveUnits,
    },
}