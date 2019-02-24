function widget:GetInfo()
    return {
        name      = "Passive builders",
        desc      = "Allows to set builders (nanos, labs and cons) on passive mode",
        author    = "[teh]decay",
        date      = "20 aug 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        version   = 6,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/SpringWidgets/passive-builders

-- Changelog:
-- v2 [teh]decay Fixed bug with rezz bots and spys
-- v3 [teh]decay exclude Commando from "passive" builders
-- v4 [teh]decay add ability to select which builders to put on passive mode: nanos, cons, labs
-- v5 [teh]Flow restyled + relative position + bugfix
-- v6 [teh]Flow removed GUI, options widget handles that part now

-- some code was used from "Wind Speed" widget. Thx to Jazcash and Floris!

local CMD_PASSIVE       	= 34571
local spGetMyTeamID     	= Spring.GetMyTeamID
local spGetTeamUnits    	= Spring.GetTeamUnits
local spGetUnitDefID    	= Spring.GetUnitDefID
local spGiveOrderToUnit 	= Spring.GiveOrderToUnit
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetPlayerInfo		= Spring.GetPlayerInfo

local coreCommando = UnitDefNames["cormando"]

local passiveLabs = false;
local passiveNanos = true;
local passiveCons = false;

local function isBuilder(ud)
    if not passiveCons and not passiveLabs and not passiveNanos then
        return false
    end

    --nano
    if ud and ud.isBuilder and not ud.canMove and not ud.isFactory then
        if passiveNanos then
            return true
        else
            return false
        end
    end

    --factory
    if ud and ud.isBuilder and ud.isFactory then
        if passiveLabs then
            return true
        else
            return false
        end
    end

    --cons
    if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist
            and (coreCommando ~= nil and ud.id ~= coreCommando.id) and not ud.isFactory and ud.canMove then
        if passiveCons then
            return true
        else
            return false
        end
    end

    return false
end

local function passivateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {1}, {})
end

local function activateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {0}, {})
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
    if (unitTeam ~= spGetMyTeamID()) then
        return
    end

    if (isBuilder(UnitDefs[unitDefID])) then
        passivateBuilder(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:GetConfigData()
    return {
        passiveLabs = passiveLabs,
        passiveNanos = passiveNanos,
        passiveCons = passiveCons,
    }
end

function widget:SetConfigData(data)
    if data.passiveLabs ~= nil then
        passiveLabs = data.passiveLabs
    else
        passiveLabs = false
    end

    if data.passiveNanos ~= nil then
        passiveNanos = data.passiveNanos
    else
        passiveNanos = true
    end

    if data.passiveCons ~= nil then
        passiveCons = data.passiveCons
    else
        passiveCons = false
    end

    refreshUnits()
end

function refreshUnits()
    local _, _, spec, _ = spGetPlayerInfo(spGetMyPlayerID())
    if spec then
        return
    end

    local myUnits = spGetTeamUnits(spGetMyTeamID())
    for _, unitID in ipairs(myUnits) do
        local unitDefID = spGetUnitDefID(unitID)
        local ud = UnitDefs[unitDefID];

        -- re-activate all builders
        if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist and (coreCommando ~= nil and ud.id ~= coreCommando.id) then
            activateBuilder(unitID)
        end

        -- passivate only required builders
        if (isBuilder(ud)) then
            passivateBuilder(unitID)
        end
    end
end


function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() then
       widgetHandler:RemoveWidget(self)
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end

    WG['passivebuilders'] = {}
    WG['passivebuilders'].getPassiveNanos = function()
        return passiveNanos
    end
    WG['passivebuilders'].setPassiveNanos = function(value)
        passiveNanos = value
        refreshUnits()
    end
    WG['passivebuilders'].getPassiveLabs = function()
        return passiveLabs
    end
    WG['passivebuilders'].setPassiveLabs = function(value)
        passiveLabs = value
        refreshUnits()
    end
    WG['passivebuilders'].getPassiveCons = function()
        return passiveCons
    end
    WG['passivebuilders'].setPassiveCons = function(value)
        passiveCons = value
        refreshUnits()
    end
end

function widget:GameStart()
    widget:PlayerChanged()
end

function widget:Shutdown()
    WG['passivebuilders'] = nil
end

