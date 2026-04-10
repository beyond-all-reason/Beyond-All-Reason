
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Holdfire Fix",
		desc      = "Holdfire holds fire immediately",
		author    = "Niobium",
		date      = "3 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


-- Localized Spring API for performance
local spGetGameFrame = SpringShared.GetGameFrame
local spGetMyTeamID = Spring.GetMyTeamID

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_INSERT = CMD.INSERT
local CMD_STOP = CMD.STOP
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local spGiveOrderToUnit = SpringSynced.GiveOrderToUnit
local gameStarted
local myTeam

local function DropCurrentTarget(unitID)
	-- STOP clears attack orders, UNIT_CANCEL_TARGET clears an active weapon lock
	spGiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_STOP, 0}, {"alt"})
	spGiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_UNIT_CANCEL_TARGET, 0}, {"alt"})
end

function maybeRemoveSelf()
    if SpringUnsynced.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	myTeam = spGetMyTeamID()
    maybeRemoveSelf()
end

function widget:Initialize()
	myTeam = spGetMyTeamID()
    if SpringUnsynced.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID == myTeam and cmdID == CMD_FIRE_STATE and cmdParams and cmdParams[1] == 0 then
		DropCurrentTarget(unitID)
	end
end
