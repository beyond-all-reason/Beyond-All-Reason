local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "BombersManualTargeting",
        desc    = "Sets produced bombers to Manual Targeting after leaving an airlab. Also hides the Move mode for bombers.",
        author  = "Pexo",
        date    = "2026-02-27",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true,
    }
end

local CMD_BOMBER_TARGETING = GameCMD.BOMBER_TARGETING
local gameStarted = false
local isBomber = {}

local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID
local spGiveOrder = Spring.GiveOrderToUnit
local myTeamID = spGetMyTeamID()

local function UnitDefIsBomber(ud)
    if not ud or not ud.weapons then
        return false
    end
    
    if ud.name and (string.find(ud.name, 'armstil')) then -- excluding Stiletto. It's an EMP bomber so friendly fire is not that much of a concern
        return false
    end

    for i = 1, #ud.weapons do
        local wname = ud.weapons[i].weaponDef
        local weaponDef = WeaponDefs[wname]
        if weaponDef then
            if weaponDef.type == "AircraftBomb" then
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
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
    if unitTeam ~= myTeamID then
        return
    end
    if isBomber[unitDefID] then
       spGiveOrder(unitID, CMD_BOMBER_TARGETING, { 0 }, 0)
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