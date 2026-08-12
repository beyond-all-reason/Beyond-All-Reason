local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Firestate API",
		desc = "Central ally-filtered firestate cache for widgets",
		author = "SethDGamre",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -1000, -- has to be lower than consumer widgets, arbitrary value
		enabled = true,
		handler = true,
	}
end

local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")
local UNKNOWN = CustomFirestateDefs.UNKNOWN

local firestateByUnitId = {}
local firestateChangedListeners = {}

local function notifyFirestateChanged(unitID, state)
	for index = 1, #firestateChangedListeners do
		firestateChangedListeners[index](unitID, state)
	end
	local onFirestateChanged = WG['firestate'] and WG['firestate'].onFirestateChanged
	if onFirestateChanged then
		onFirestateChanged(unitID, state)
	end
end

local function getUnitFirestate(unitID)
	local state = firestateByUnitId[unitID]
	if state == nil then
		return UNKNOWN
	end
	return state
end

local function setCachedFirestate(unitID, state)
	if firestateByUnitId[unitID] == state then
		return
	end
	firestateByUnitId[unitID] = state
	notifyFirestateChanged(unitID, state)
end

local function addFirestateChangedListener(listener)
	if type(listener) ~= "function" then
		return
	end
	firestateChangedListeners[#firestateChangedListeners + 1] = listener
end

local function removeFirestateChangedListener(listener)
	for index = #firestateChangedListeners, 1, -1 do
		if firestateChangedListeners[index] == listener then
			table.remove(firestateChangedListeners, index)
		end
	end
end

function widget:FirestateUpdate(unitID, state)
	setCachedFirestate(unitID, state)
end

function widget:Initialize()
	WG['firestate'] = WG['firestate'] or {}
	WG['firestate'].byUnitID = firestateByUnitId
	WG['firestate'].getUnitFirestate = getUnitFirestate
	WG['firestate'].addFirestateChangedListener = addFirestateChangedListener
	WG['firestate'].removeFirestateChangedListener = removeFirestateChangedListener
	VFS.Include("luaui/Include/user_firestate_commands.lua")
end

function widget:Shutdown()
	if WG['firestate'] then
		WG['firestate'].byUnitID = nil
		WG['firestate'].getUnitFirestate = nil
		WG['firestate'].addFirestateChangedListener = nil
		WG['firestate'].removeFirestateChangedListener = nil
	end
end

function widget:UnitDestroyed(unitID)
	setCachedFirestate(unitID, UNKNOWN)
end
