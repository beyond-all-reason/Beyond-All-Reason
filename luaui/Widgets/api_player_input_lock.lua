local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Player Input Lock",
		desc = "Lets scripts lock the player out of the game: only Esc and the menu buttons keep working",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = -99000,
		enabled = true,
	}
end

local KEYSYMS = require("luaui/Include/keybind_keysyms")

local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt

local REASON = "playerInputLock"
-- The menu buttons are the way back to the quit dialog. This widget keeps itself on the list
-- because MouseWheel only reaches allowed widgets, and it is the one eating the wheel.
local KEEP_ALWAYS = { "Top Bar Buttons", "Player Input Lock" }
-- Edge scrolling moves the camera without any call-in a widget could refuse, so it is
-- switched off in the config overlay (not persisted) for the lock's duration.
local EDGE_MOVE_KEYS = { "WindowedEdgeMove", "FullscreenEdgeMove" }

local locked = false
local savedEdgeMove = {} -- config key -> value before the lock

---Hide the interface and drop every key but Esc until Unlock. Locking again replaces the keep list.
---The lock does not survive /luaui reload: Shutdown releases it and nothing re-asserts it.
---@param keepInterface string[]? names of widgets that stay drawn and clickable, besides the menu buttons
local function lock(keepInterface)
	local keep = table.copy(KEEP_ALWAYS)
	for _, name in ipairs(keepInterface or {}) do
		keep[#keep + 1] = name
	end
	widgetHandler:HideInterface(REASON, keep)
	widgetHandler:LockKeyboard(REASON, { KEYSYMS.ESCAPE })
	if not locked then
		for _, key in ipairs(EDGE_MOVE_KEYS) do
			savedEdgeMove[key] = spGetConfigInt(key, 1)
			spSetConfigInt(key, 0, true)
		end
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

local function isLocked()
	return locked
end

-- A showing window may want the wheel (a scrollable page a mission keeps up), as with keys.
function widget:MouseWheel()
	---@diagnostic disable-next-line: return-type-mismatch, redundant-return-value
	return locked and not widgetHandler:IsAnyWindowOpen()
end

function widget:Initialize()
	WG.playerInputLock = {
		Lock = lock,
		Unlock = unlock,
		IsLocked = isLocked,
	}
end

function widget:Shutdown()
	unlock()
	WG.playerInputLock = nil
end
