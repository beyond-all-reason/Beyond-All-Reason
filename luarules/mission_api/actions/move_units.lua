local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function moveUnits(unitName, position, direction, randomRadius, alwaysAboveSea)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if randomRadius and randomRadius > 0 then
                Spring.SetUnitPosition(unitID, position.x+math.random(-randomRadius, randomRadius), position.z+math.random(-randomRadius, randomRadius), alwaysAboveSea)
            else
                Spring.SetUnitPosition(unitID, position.x, position.z, alwaysAboveSea)
            end
            
            if direction then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                Spring.SetUnitDirection(unitID, direction.x-testposx, 0, direction.z-testposz)
            end
        end
    end
end

return {
    {
	    type = 'MoveUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'position', required = true, type = ParameterTypes.Position },
            { name = 'direction', required = false, type = ParameterTypes.Position }, -- Point on the map towards which the unit rotates
            { name = 'randomRadius', required = false, type = ParameterTypes.Number }, -- Spread teleported units around in radius this big.
            { name = 'alwaysAboveSea', required = false, type = ParameterTypes.Boolean },
	    },
	    actionFunction = moveUnits,
    },
}