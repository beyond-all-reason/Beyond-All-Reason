local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function moveUnits(unitName, position, direction, randomRadius)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            Spring.SetUnitPosition(unitID, position.x, position.y, position.z)
            if direction then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                if math.abs(direction.x-testposx) > 0.001 or math.abs(direction.z-testposz) > 0.001 then
                    Spring.SetUnitDirection(unitID, direction.x-testposx, direction.y, direction.z-testposz)
                end
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
	    },
	    actionFunction = moveUnits,
    },
}