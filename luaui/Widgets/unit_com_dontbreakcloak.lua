
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

local isCommander = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

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
local spec = spGetSpectatingState()
local myTeam = spGetMyTeamID()
local gameStarted
----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function maybeRemoveSelf()
    if spec and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	spec = spGetSpectatingState()
	myTeam = spGetMyTeamID()
	maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if (cmdID == CMD_CLOAK) and isCommander[unitDefID] and (teamID == myTeam) then
		if cmdParams[1] == 1 then
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, {0}, 0)
            spGiveOrderToUnit(unitID, CMD_INSERT, {0, 0, 0}, CMD_OPT_ALT)
		else
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, {2}, 0)
		end
	end
end
