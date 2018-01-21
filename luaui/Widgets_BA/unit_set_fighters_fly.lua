--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Set fighters on Fly mode",
        desc      = "Setting fighters on Fly mode",
        author    = "Floris (original unit_air_allways_fly widget by [teh]Decay)",
        date      = "july 2017",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

-- this widget is a variant of unit_air_allways_fly: project page on github: https://github.com/jamerlan/unit_air_allways_fly


--------------------------------------------------------------------------------
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyTeamId = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local cmdFly = 145
--------------------------------------------------------------------------------


function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if(teamID == spGetMyTeamId()) then
        switchToFlyMode(unitID, unitDefID)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if(newTeam == spGetMyTeamId()) then
        switchToFlyMode(unitID, unitDefID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if(unitTeam == spGetMyTeamId()) then
        switchToFlyMode(unitID, unitDefID)
    end
end

function switchToFlyMode(unitID, unitDefID)
    if (unitDefID == UnitDefNames["armfig"].id  or unitDefID == UnitDefNames["armsfig"].id or unitDefID == UnitDefNames["armhawk"].id or
        unitDefID == UnitDefNames["corveng"].id or unitDefID == UnitDefNames["corsfig"].id or unitDefID == UnitDefNames["corvamp"].id) then
        spGiveOrderToUnit(unitID, cmdFly, { 0 }, {})
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
    local _, _, _, teamId = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
    for _, unitID in ipairs(spGetTeamUnits(teamId)) do  -- init existing labs
        switchToFlyMode(unitID, spGetUnitDefID(unitID))
    end
end

function widget:GameStart()
    widget:PlayerChanged()
end


