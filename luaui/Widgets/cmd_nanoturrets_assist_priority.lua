function widget:GetInfo()
	return {
		name         = "Priority Construction Turrets",
		desc         = "When a new turret is started, local turrets on patrol will target it",
		author       = "Phinks",
		date         = "2023-05-05",
		layer        = 0,
		enabled      = true
	}
end

local GetUnitPosition = Spring.GetUnitPosition
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitCommands = Spring.GetUnitCommands
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitDefID = Spring.GetUnitDefID
local UnitDefs = UnitDefs
local CMD_REPAIR = CMD.REPAIR
local CMD_FIGHT = CMD.FIGHT

local nanoNames = {
    armnanotc = true,
    cornanotc = true,
    armnanotct2 = true,
    cornanotct2 = true,
    armnanotcplat = true,
    cornanotcplat = true,
    armrespawn = true,
    correspawn = true,
}
local nanoDefs = {}

function widget:Initialize()
    -- Spring.Echo(helloWorld)
    for unitDefID, def in ipairs(UnitDefs) do
        if nanoNames[def.name] then
            nanoDefs[unitDefID] = def.buildDistance
        end
    end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if (nanoDefs[unitDefID] ~= nil) then
        -- Echo(turretCreatedMessage .. ": " .. unitID)
        local pos = {GetUnitPosition(unitID)}
        local unitsNear = GetUnitsInSphere(pos[1], pos[2], pos[3], nanoDefs[unitDefID])
        -- Echo("found units nearby: " .. unitsNear)
        for _, id in ipairs(unitsNear) do
            if (nanoDefs[GetUnitDefID(id)] ~= nil) then 
                local commandQueue = GetUnitCommands(id, 10)
                if (commandQueue[2] ~= nil and commandQueue[2]["id"] == CMD_FIGHT) or commandQueue[2] == nil then
                    -- Echo("giving repair command to " .. id)
                    GiveOrderToUnit(id, CMD_REPAIR, unitID, {})
                end
            end
        end
    end
end
