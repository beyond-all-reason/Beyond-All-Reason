local widget = widget ---@type Widget

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
local myTeam = Spring.GetMyTeamID()

local nanoDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
		nanoDefs[unitDefID] = unitDef.buildDistance
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if unitTeam ~= myTeam then
        return
    end
    if (nanoDefs[unitDefID] ~= nil) then
        -- Echo(turretCreatedMessage .. ": " .. unitID)
        local pos = {GetUnitPosition(unitID)}
        local unitsNear = GetUnitsInSphere(pos[1], pos[2], pos[3], nanoDefs[unitDefID], -3)
        -- Echo("found units nearby: " .. unitsNear)
        for _, id in ipairs(unitsNear) do
            if (nanoDefs[GetUnitDefID(id)] ~= nil) then 
                local commandQueue = GetUnitCommands(id, 10)
                if (commandQueue[2] ~= nil and commandQueue[2]["id"] == CMD_FIGHT) or (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_FIGHT) or commandQueue[1] == nil then
                    -- Echo("giving repair command to " .. id)
                    GiveOrderToUnit(id, CMD_REPAIR, unitID, {})
                end
            end
        end
    end
end
