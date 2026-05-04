local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "Taxi Guard",
        desc    = "Object-oriented transporter guard system with taxi service",
        author  = "Robert82",
        date    = "July 2025",
        license = "GNU GPL, v2 or later",
        version = "2.0",
        layer   = 9999,
        enabled = true,
        handler = true
    }
end

-- Configuration
local custom_keybind_mode = false
local auto_mode = true
local transportUnits = {'armatlas', 'armdfly', 'corseah', 'corvalk'}

-- Debug system
local Debugmode = false
local Debugmode1 = true
local DebugCategories = {}

function Log(Message, Category)
    if Debugmode then
        local DoLog = false
        if Category then
            for i = 1, #DebugCategories do
                if Category == DebugCategories[i] then
                    DoLog = true
                    break
                end
            end
        else
            DoLog = true
        end
        if DoLog then
            Spring.Echo(Message)
        end
    end
end

function Log1(Message)
    if Debugmode1 then
        Spring.Echo(Message)
    end
end

-- Transporter class
local Transporter = {
    unitid = 0,
    unitDef = nil,
    targetpoint = {},
    guardedUnit = -1,
    isTransportUnit = false
}

function Transporter:new(unitID)
    local o = {}
    setmetatable(o, {__index = self})
    o.unitid = unitID
    o.unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
    o.targetpoint = {}
    o.guardedUnit = -1
    o.isTransportUnit = self:checkIsTransportUnit(unitID)
    return o
end

function Transporter:checkIsTransportUnit(unitID)
    local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
    if unitDef then
        for _, transportUnit in ipairs(transportUnits) do
            if unitDef.name == transportUnit then
                return true
            end
        end
    end
    return false
end

function Transporter:update()
    if not self.isTransportUnit then
        return
    end
    
    local PU = {Spring.GetUnitPosition(self.unitid)}
    if not PU[1] then return end
    
    Log1("Transporter ID: " .. tostring(self.unitid))
    
    local transportedUnits = Spring.GetUnitIsTransporting(self.unitid)
    local guarding, firstTime, P_GUARD_C, newGUARDtargetID = self:findFirstCommand(CMD.GUARD)
    local loading, firstTimeL, P_LOAD_UNITS_C, newLOAD_UNITStargetID = self:findFirstCommand(CMD.LOAD_UNITS)
    
    -- Always handle normal operation (enemy avoidance removed)
    self:handleNormalOperation(PU, guarding, newGUARDtargetID, transportedUnits, loading)
end

function Transporter:handleNormalOperation(PU, guarding, newGUARDtargetID, transportedUnits, loading)
    if not guarding then return end
    
    local PGT = {Spring.GetUnitPosition(newGUARDtargetID)}
    if not PGT[1] then return end
    
    local SUGT = self:XZseparation(PU, PGT)
    local GTcommands = Spring.GetUnitCommands(newGUARDtargetID, -1)
    
    -- Follow guarded unit if no cargo and not loading
    if #transportedUnits == 0 and not loading then
        if SUGT > 80 then
            Log1("Following guarded unit - distance: " .. tostring(SUGT))
            Spring.GiveOrderToUnit(self.unitid, CMD.MOVE, PGT, {})
            Spring.GiveOrderToUnit(self.unitid, CMD.GUARD, {newGUARDtargetID}, {"shift"})
        end
    end
    
    -- Check if we should transport the guarded unit
    if #GTcommands > 0 then
        self:handleTransportDecision(PU, PGT, GTcommands, newGUARDtargetID)
    end
end

function Transporter:handleTransportDecision(PU, PGT, GTcommands, newGUARDtargetID)
    local hGTC = GTcommands[1].params
    local PGTC, targetID = self:savePosition_UnitID(hGTC)
    
    if not PGTC then return end
    
    local SUGTC = self:XZseparation(PGT, PGTC)
    local moveOnYourOwn = 200
    local unloaddistance = 80
    
    -- Adjust unload distance for nano units
    if targetID then
        local targetDef = UnitDefs[Spring.GetUnitDefID(targetID)]
        if targetDef and (targetDef.name == "armnanotc" or targetDef.name == "cornanotc") then
            Log1("Transporting a Nano")
            unloaddistance = 120
        end
    end
    
    Log1("Distance to target: " .. tostring(SUGTC))
    if SUGTC > moveOnYourOwn then
        Log1("Will transport this unit")
        local P_Unload_C = self:pointAtScaledSeparation(PGTC, PGT, unloaddistance)
        Spring.GiveOrderToUnit(self.unitid, CMD.LOAD_UNITS, {newGUARDtargetID}, {})
        Spring.GiveOrderToUnit(self.unitid, CMD.UNLOAD_UNITS, P_Unload_C, {"shift"})
        Spring.GiveOrderToUnit(self.unitid, CMD.GUARD, {newGUARDtargetID}, {"shift"})
    end
end

-- Utility functions for Transporter class
function Transporter:findFirstCommand(cmdType)
    local commands = Spring.GetUnitCommands(self.unitid, -1)
    for i = 1, #commands do
        if commands[i].id == cmdType then
            local position, targetID = self:savePosition_UnitID(commands[i].params)
            if position then
                return true, i, position, targetID
            end
        end
    end
    return false, nil, nil, nil
end

function Transporter:savePosition_UnitID(params)
    local x, y, z = unpack(params)
    local targetID = nil
    if x and not y then
        targetID = x
        x, y, z = Spring.GetUnitPosition(x)
    end
    if not x then
        return nil
    end
    return {x, y, z}, targetID
end

function Transporter:XZseparation(P1, P2)
    return math.sqrt((P2[1] - P1[1])^2 + (P2[3] - P1[3])^2)
end

function Transporter:separation(P1, P2)
    return math.sqrt((P2[1] - P1[1])^2 + (P2[2] - P1[2])^2 + (P2[3] - P1[3])^2)
end

function Transporter:normalize(V)
    local d = self:separation({0, 0, 0}, V)
    return {V[1]/d, V[2]/d, V[3]/d}
end

function Transporter:addVectors(V1, V2)
    return {V1[1] + V2[1], V1[2] + V2[2], V1[3] + V2[3]}
end

function Transporter:scaleVector(V, length)
    local normalizedVector = self:normalize(V)
    return {normalizedVector[1] * length, normalizedVector[2] * length, normalizedVector[3] * length}
end

function Transporter:vectorBetween(P1, P2)
    return {P2[1] - P1[1], P2[2] - P1[2], P2[3] - P1[3]}
end

function Transporter:scaledVectorBetween(P1, P2, length)
    local V = self:vectorBetween(P1, P2)
    return self:scaleVector(V, length)
end

function Transporter:pointAtScaledSeparation(P1, P2, length)
    local scaledV = self:scaledVectorBetween(P1, P2, length)
    return self:addVectors(P1, scaledV)
end

-- Unit class
local Unit = {
    unitid = 0,
    targetpoint = nil,
    unitDef = nil,
    isBuilder = false,
    guardUnit = -1,
    builderID = -1,
}

function Unit:new(unitID)
    local o = {}
    setmetatable(o, {__index = self})
    o.unitid = unitID
    o.targetpoint = nil
    o.unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
    o.isBuilder = o.unitDef.isBuilder
    o.guardUnit = -1
    o.builderID = -1
    return o
end

function Unit:setTargetPoint(params)
    self.targetpoint = params
end

-- Manager class
local GuardTransportManager = {
    transporters = {},
    units = {},
    myTeamID = nil,
    lastUpdate = 0,
    icon = "LuaUI/Images/groupicons/weaponexplo.png"
}

function GuardTransportManager:new()
    local o = {}
    setmetatable(o, {__index = self})
    o.transporters = {}
    o.units = {}
    o.myTeamID = Spring.GetMyTeamID()
    o.lastUpdate = os.clock() - 10
    return o
end

function GuardTransportManager:findTransporter(unitID)
    for i, transporter in ipairs(self.transporters) do
        if transporter.unitid == unitID then
            return i, transporter
        end
    end
    return nil, nil
end

function GuardTransportManager:findUnit(unitID)
    for i, unit in ipairs(self.units) do
        if unit.unitid == unitID then
            return i, unit
        end
    end
    return nil, nil
end

function GuardTransportManager:addTransporter(unitID)
    local _, existing = self:findTransporter(unitID)
    if not existing then
        local transporter = Transporter:new(unitID)
        table.insert(self.transporters, transporter)
        Log("Added transporter: " .. tostring(unitID))
    end
end

function GuardTransportManager:removeTransporter(unitID)
    local index, _ = self:findTransporter(unitID)
    if index then
        table.remove(self.transporters, index)
        Log("Removed transporter: " .. tostring(unitID))
    end
end

function GuardTransportManager:addUnit(unitID)
    local _, existing = self:findUnit(unitID)
    if not existing then
        local unit = Unit:new(unitID)
        table.insert(self.units, unit)
        Log("Added unit: " .. tostring(unitID))
    end
end

function GuardTransportManager:removeUnit(unitID)
    local index, _ = self:findUnit(unitID)
    if index then
        table.remove(self.units, index)
        Log("Removed unit: " .. tostring(unitID))
    end
end

function GuardTransportManager:toggleProtector(unitID)
    local index, transporter = self:findTransporter(unitID)
    if transporter then
        self:removeTransporter(unitID)
        local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
        Log("Unit " .. tostring(unitID) .. " (" .. unitDef.name .. ") removed from guard overwatch")
    else
        self:addTransporter(unitID)
        local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
        Log("Unit " .. tostring(unitID) .. " (" .. unitDef.name .. ") added to guard overwatch")
    end
end

function GuardTransportManager:update()
    if self.lastUpdate + 0.6 < os.clock() then
        self.lastUpdate = os.clock()
        for _, transporter in ipairs(self.transporters) do
            transporter:update()
        end
    end
end

function GuardTransportManager:drawWorld()
    for _, transporter in ipairs(self.transporters) do
        local x, y, z = Spring.GetUnitPosition(transporter.unitid)
        if x then
            gl.PushMatrix()
            gl.Translate(x, y, z)
            gl.Billboard()
            gl.Color(0.3, 0.5, 1, 1)
            gl.Texture(self.icon)
            gl.TexRect(0, 20, 10, 30)
            gl.PopMatrix()
        end
    end
end

function GuardTransportManager:isTransporter(unitID)
    local unitDefID = Spring.GetUnitDefID(unitID)
    if unitDefID then
        return UnitDefs[unitDefID].isTransport
    end
    return false
end

-- Global manager instance
local manager = GuardTransportManager:new()

-- Widget functions
function widget:Initialize()
    widgetHandler.actionHandler:AddAction(self, "protectorToggle", 
        function() 
            local selUnits = Spring.GetSelectedUnits()
            for _, unitID in ipairs(selUnits) do
                manager:toggleProtector(unitID)
            end
        end, nil, "p")
end

function widget:KeyPress(key, mods, isRepeat)
    if custom_keybind_mode then return end
    if (key == 103) and (mods.alt) then -- alt + g
        local selUnits = Spring.GetSelectedUnits()
        for _, unitID in ipairs(selUnits) do
            manager:toggleProtector(unitID)
        end
    end
end

function widget:Update(dt)
    manager:update()
end

function widget:DrawWorld()
    manager:drawWorld()
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    manager:removeTransporter(unitID)
    manager:removeUnit(unitID)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
    if auto_mode and unitTeam == manager.myTeamID then
        if manager:isTransporter(unitID) then
            manager:addTransporter(unitID)
        else
            manager:addUnit(unitID)
        end
    end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if auto_mode and unitTeam == manager.myTeamID then
        if manager:isTransporter(unitID) then
            manager:addTransporter(unitID)
        else
            manager:addUnit(unitID)
        end
    end
end

function widget:UnitCaptured(unitID, unitDefID, unitTeam, oldTeam)
    if auto_mode and unitTeam == manager.myTeamID then
        if manager:isTransporter(unitID) then
            manager:addTransporter(unitID)
        else
            manager:addUnit(unitID)
        end
    end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
    local _, unit = manager:findUnit(unitID)
    if unit then
        if cmdID == CMD.MOVE then
            unit:setTargetPoint(cmdParams)
            Log("Unit " .. unitID .. " received move command")
        elseif cmdID == CMD.FIGHT or cmdID == CMD.ATTACK then
            local unitDef = UnitDefs[unitDefID]
            if unitDef.canMove then
                unit:setTargetPoint(cmdParams)
                Log("Unit " .. unitID .. " received attack/fight command")
            end
        end
    end
end
