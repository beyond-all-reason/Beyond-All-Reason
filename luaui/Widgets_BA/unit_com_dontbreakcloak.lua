
function widget:GetInfo()
	return {
		name      = 'Com DontBreakCloak',
		desc      = 'Sets commanders to hold fire when cloaked',
		author    = 'Niobium',
		version   = '1.0',
		date      = 'April 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true,  --  loaded by default?
	}
end

----------------------------------------------------------------
-- Var
----------------------------------------------------------------
local isCommander = {
    [UnitDefNames.armcom.id] = true,
    [UnitDefNames.corcom.id] = true,
}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local CMD_CLOAK = 37382
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_INSERT = CMD.INSERT
local CMD_OPT_ALT = CMD.OPT_ALT
local spGetMyTeamID = Spring.GetMyTeamID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSpectatingState = Spring.GetSpectatingState

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:UnitCommand(uID, uDefID, uTeam, cmdID, cmdParams, cmdOpts)
	if (cmdID == CMD_CLOAK) and isCommander[uDefID] and (uTeam == spGetMyTeamID()) then
        if spGetSpectatingState() then
            widgetHandler:RemoveWidget(self)
            return
        end
		if cmdParams[1] == 1 then
			spGiveOrderToUnit(uID, CMD_FIRE_STATE, {0}, 0)
            spGiveOrderToUnit(uID, CMD_INSERT, {0, 0, 0}, CMD_OPT_ALT)
		else
			spGiveOrderToUnit(uID, CMD_FIRE_STATE, {2}, 0) 
		end
	end
end
