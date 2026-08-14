local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types



local function rotateUnits(unitName, headingAngle, direction)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs[unitName]

    for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if direction then
                local testposx, _, testposz = Spring.GetUnitPosition(unitID)
                if math.abs(direction.x-testposx) >= 0.001 or math.abs(direction.z-testposz) >= 0.001 then
                    Spring.SetUnitDirection(unitID, direction.x-testposx, direction.y, direction.z-testposz)
                end
            elseif headingAngle then
                -- Thanks AI. This makes sure no matter what angle someone gives, it's results gets normalised to between 0 and 360.
                local heading = math.floor(((360 - (((headingAngle % 360) + 360) % 360)) % 360) * 65535 / 360 - 32768)
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
            { name = 'headingAngle', required = false, type = ParameterTypes.Number }, -- Angle in Degrees, with 0 and 360 being north. Counter-clockwise.   ||NEVER USE BOTH||
            { name = 'direction', required = false, type = ParameterTypes.Position }, -- Point on the map towards which the unit rotates.                    ||NEVER USE BOTH||
            requiresOneOf = { 'headingAngle', 'direction' },
	    },
	    actionFunction = rotateUnits,
    },
}