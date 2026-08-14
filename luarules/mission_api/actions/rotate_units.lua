local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types



local function rotateUnits(unitName, direction)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if direction.x then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                if math.abs(direction.x-testposx) >= 0.001 or math.abs(direction.z-testposz) >= 0.001 then
                    Spring.SetUnitDirection(unitID, direction.x-testposx, direction.y, direction.z-testposz)
                end
            elseif direction.angle then
                -- Thanks AI. This makes sure no matter what angle someone gives, it's results gets normalised to between 0 and 360.
                local heading = math.floor(((360 - (((direction.angle % 360) + 360) % 360)) % 360) * 65535 / 360 - 32768)
                Spring.SetUnitHeadingAndUpDir(unitID, heading, 0, 1, 0)
            end
        end
    end
end

return {
    {
	    type = 'RotateUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
            { name = 'direction', required = true, type = ParameterTypes.Direction },
	    },
	    actionFunction = rotateUnits,
    },
}