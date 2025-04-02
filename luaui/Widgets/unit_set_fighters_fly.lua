--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "Set fighters on Fly mode",
        desc      = "Setting fighters on Fly mode",
        author    = "Floris (original unit_air_allways_fly widget by [teh]Decay)",
        date      = "july 2017",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true
    }
end

-- this widget is a variant of unit_air_allways_fly: project page on github: https://github.com/jamerlan/unit_air_allways_fly


--------------------------------------------------------------------------------

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local cmdFly = 145
local myTeamID = Spring.GetMyTeamID()

local isFighter = {}
for udid, ud in pairs(UnitDefs) do
    if ud.customParams.fighter or ud.customParams.drone then
        isFighter[udid] = true
    end
end

--------------------------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if isFighter[unitDefID] and teamID == myTeamID then
        spGiveOrderToUnit(unitID, cmdFly, { 0 }, 0)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if isFighter[unitDefID] and newTeam == myTeamID then
        spGiveOrderToUnit(unitID, cmdFly, { 0 }, 0)
    end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if isFighter[unitDefID] and unitTeam == myTeamID then
        spGiveOrderToUnit(unitID, cmdFly, { 0 }, 0)
    end
end

function widget:PlayerChanged(playerID)
    myTeamID = Spring.GetMyTeamID()
    if Spring.GetSpectatingState() then
        widgetHandler:RemoveWidget()
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end
    for _, unitID in ipairs(spGetTeamUnits(myTeamID)) do  -- init existing labs
        if isFighter[spGetUnitDefID(unitID)] then
            spGiveOrderToUnit(unitID, cmdFly, { 0 }, 0)
        end
    end
end

function widget:GameStart()
    widget:PlayerChanged()
end


