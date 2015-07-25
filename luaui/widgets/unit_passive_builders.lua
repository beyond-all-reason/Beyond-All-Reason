function widget:GetInfo()
    return {
        name      = "Passive builders v3",
        desc      = "All builders + factories (except commander) are set to Passive mode",
        author    = "[teh]decay",
        date      = "20 jun 2015",
        license   = "The BSD License",
        layer     = 0,
        version   = 3,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/SpringWidgets/passive-builders

-- Changelog:
-- v2 [teh]decay Fixed bug with rezz bots and spys
-- v3 [teh]decay exclude Commando from "passive" builders

local CMD_PASSIVE       = 34571
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetTeamUnits    = Spring.GetTeamUnits
local spGetUnitDefID    = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local coreCommando = UnitDefNames["commando"]

local function isBuilder(ud)
    return ud and ud.isBuilder and not ud.canManualFire and ud.canAssist and ud.id ~= coreCommando.id
end

local function passivateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {1}, {})
end


function widget:Initialize()
    local myUnits = spGetTeamUnits(spGetMyTeamID())
    for _,unitID in ipairs(myUnits) do
        local unitDefID = spGetUnitDefID(unitID)
        if (isBuilder(UnitDefs[unitDefID])) then
            passivateBuilder(unitID)
        end
    end
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

