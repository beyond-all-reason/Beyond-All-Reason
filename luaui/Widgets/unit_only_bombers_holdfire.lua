local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "OnlyBombersHoldFire",
        desc    = "Sets produced bombers to Hold Position after leaving airlab.",
        author  = "Pexo",
        date    = "2026-02-27",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true,
    }
end

local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local myTeamID = spGetMyTeamID()
local gameStarted = false

local isBomber = {}
local airFactories = {}

local function UnitDefIsBomber(ud)
    if not ud or not ud.weapons then
        return false
    end
    if ud.name and (string.find(ud.name, 'armstil') then -- excluding Stiletto as it's an EMP bomber, friednly fire's not that much of a concern
        return false
    end
    for i = 1, #ud.weapons do
        local wname = ud.weapons[i].weaponDef
        if wname and WeaponDefs and WeaponDefs[wname] then
            local wdef = WeaponDefs[wname]
            local wtype = wdef.type or wdef.weapontype
            if wtype == "AircraftBomb" then
                return true
            end
        end
    end
    return false
end

for udid, ud in pairs(UnitDefs) do
    if UnitDefIsBomber(ud) then
        isBomber[udid] = true
    end
    if ud.isFactory and ud.customParams and ud.customParams.airfactory then
        airFactories[udid] = true
    end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
    if unitTeam ~= myTeamID then
        return
    end
    if userOrders then
        return
    end
    if not airFactories[factDefID] then
        return
    end
    if isBomber[unitDefID] then
        Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0) -- Hold Fire
        Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0) -- Hold Position
    end
end

local function maybeRemoveSelf()
    if Spring.IsReplay() or (Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted)) then
        widgetHandler:RemoveWidget()
    end
end

function widget:PlayerChanged(playerID)
    myTeamID = spGetMyTeamID()
    maybeRemoveSelf()
end

function widget:Initialize()
    maybeRemoveSelf()
end

function widget:GameStart()
    gameStarted = true
    widget:PlayerChanged()
end