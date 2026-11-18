local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Player Input Lock",
		desc = "Locks the player out of the game while synced code asks for it: only Esc, the quit menu and the menu buttons keep working",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
		hidden = true, -- not in the widget selector: the player cannot switch it off
	}
end

local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt
local spSetActiveCommand = Spring.SetActiveCommand
local spGetGameRulesParam = Spring.GetGameRulesParam

local REASON = "playerInputLock"
-- Synced code locks with Spring.SetGameRulesParam("playerInputLock", 1) and unlocks with 0. Only
-- synced code can set it, so no player's widget can lock or unlock, and a /luaui reload or a
-- rejoin picks the lock up again. Read every Update rather than GameFrame: synced code runs
-- between frames too, so a change made during a pause takes effect at once.
local RULES_PARAM = "playerInputLock"
-- This widget keeps itself drawn because MouseWheel only reaches allowed widgets, and it is the
-- one eating the wheel. The menu buttons, the way back to the quit dialog, every hide keeps.
local KEEP = { "Player Input Lock" }
-- Edge scrolling moves the camera without any call-in a widget could refuse, so it is
-- switched off in the config overlay (not persisted) for the lock's duration.
local EDGE_MOVE_KEYS = { "WindowedEdgeMove", "FullscreenEdgeMove" }

local locked = false
local gameOver = false
local savedEdgeMove = {} -- config key -> value before the lock

local function lock()
	widgetHandler:HideInterface(REASON, KEEP)
	widgetHandler:LockKeyboard(REASON)
	spSetActiveCommand(0) -- else its build ghost and range previews keep following the pointer
	for _, key in ipairs(EDGE_MOVE_KEYS) do
		savedEdgeMove[key] = spGetConfigInt(key, 1)
		spSetConfigInt(key, 0, true)
	end
	locked = true
end

local function unlock()
	widgetHandler:ShowInterface(REASON)
	widgetHandler:UnlockKeyboard(REASON)
	for key, value in pairs(savedEdgeMove) do
		spSetConfigInt(key, value, true)
	end
	savedEdgeMove = {}
	locked = false
end

local function followRulesParam()
	local wanted = not gameOver and (spGetGameRulesParam(RULES_PARAM) or 0) ~= 0
	if wanted and not locked then
		lock()
	elseif locked and not wanted then
		unlock()
	end
end

function widget:Update()
	followRulesParam()
end

function widget:GameOver()
	gameOver = true
	followRulesParam()
end

-- Eats the wheel so the camera does not zoom. Being first in the handler's wheel order (lowest
-- layer) it steps aside while a kept window is showing, as the keyboard lock does for keys.
function widget:MouseWheel()
	if locked and not widgetHandler:IsAnyWindowOpen() then
		---@diagnostic disable-next-line: return-type-mismatch, redundant-return-value
		return true
	end
end

function widget:Initialize()
	gameOver = Spring.IsGameOver()
	followRulesParam()
end

function widget:Shutdown()
	if locked then
		unlock()
	end
end
