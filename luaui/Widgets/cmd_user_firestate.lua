--DEFEND FIRESTATE REWORK: Remove guard; widget always intercepts firestate clicks
if not Spring.GetModOptions().experimental_defend_firestate then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "User Firestate",
		desc = "Maps user-facing firestate orders to custom firestate states",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE
local Firestates = VFS.Include("modules/firestates.lua")
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray

local userFirestateByEngineFirestate = {
	[Firestates.ENGINE_HOLD_FIRE] = Firestates.PASSIVE,
	[Firestates.ENGINE_RETURN_FIRE] = Firestates.DEFEND,
	[Firestates.ENGINE_FIRE_AT_WILL] = Firestates.AGGRESSIVE,
}

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_FIRE_STATE or not cmdParams then
		return false
	end
	local userFirestate = userFirestateByEngineFirestate[cmdParams[1]]
	if userFirestate == nil then
		return false
	end
	spGiveOrderToUnitArray(spGetSelectedUnits(), CMD_USER_FIRESTATE, { userFirestate }, 0)
	return true
end
