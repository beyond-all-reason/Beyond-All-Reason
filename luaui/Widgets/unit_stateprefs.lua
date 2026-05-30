--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "State Prefs V2",
		desc = "Sets pre-defined units states. Hold bindable action 'stateprefs_record' while clicking a unit's state commands to define the preferred state for newly produced units of its type. V2 fixes bug, improves console output, and exposes a comprehensive WG.StatePrefs API for other widgets.",
		author = "Errrrrrr, quantum + Doo, sneyed, Chronographer, uBdead",
		date = "April 21, 2023",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamUnits = Spring.GetTeamUnits
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spEcho = Spring.Echo

--[[------------------------------------------------------------------------------

Usage (key bindings):
Bind actions to a key of your choice in /Beyond-All-Reason/data/uikeys.txt
stateprefs_record 		will save the preferred state for the selected unit/units for the selected command.
stateprefs_clear 		will clears the preferred state for the selected unit/units for the selected command.
stateprefs_clearunit 	will clears all saved states for the selected unit/units for all commands.
stateprefs_savecurrent	will snapshot ALL current states of the selected unit/units as their prefs.

e.g.
bind alt 	stateprefs_clear
bind ctrl 	stateprefs_record
bind sc_\ 	stateprefs_clearunit

Usage (WG.StatePrefs API, for other widgets):
	local api = WG.StatePrefs
	-- queries
	api.getAllPrefs()                      -> { [unitName] = { [cmdID] = stateIndex } }  (copy)
	api.getUnitPrefs(unitDefID|unitName)   -> { [cmdID] = stateIndex }                   (copy or nil)
	api.hasPrefs(unitDefID|unitName)       -> boolean
	-- live capture
	api.captureUnitStates(unitID)          -> { [cmdID] = stateIndex }
	api.saveSelected()                     -> number of unit types saved
	api.saveUnits(unitIDs)                 -> number of unit types saved
	-- granular mutation (persisted)
	api.setState(unitDefID|unitName, cmdID, stateIndex)
	api.clearState(unitDefID|unitName, cmdID)
	api.clearUnit(unitDefID|unitName)
	api.clearAll()                         -- wipe all saved prefs for every unit type
	api.recordSelected(cmdID, stateIndex)  -- like the record key action
	api.clearStateSelected(cmdID)          -- like the clear key action
	api.clearSelected()                    -- like the clearunit key action
	-- persistence / application
	api.save()                             -- force-write the config to disk
	api.reload()                           -- reload the config from disk
	api.applyToUnit(unitID[, unitDefID])   -- apply stored prefs to one unit
	api.applyToTeam([teamID])              -- apply stored prefs to all of a team's units

--]]------------------------------------------------------------------------------

local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local CMD_REPEAT = CMD.REPEAT -- skipped when applying (handled by repeat command itself)

local CONFIG_PATH = "LuaUI/config/StatesPrefs.lua"
local CONFIG_HEADER = "--States prefs"
local clearSound = 'LuaUI/Sounds/switchoff.wav'
local saveSound = 'LuaUI/Sounds/switchon.wav'

-- unitDefID -> internal name (used as unitSet key), human name (used for display)
local unitName = {}
local unitHumanName = {}
local validName = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name or ("unitDefID_" .. udid)
	unitHumanName[udid] = ud.translatedHumanName or unitName[udid]
	validName[ud.name] = true
end

-- name -> { [cmdID] = stateIndex }
local unitSet = {}

local wasRecordPressed = false
local isRecordPressed = false
local isClearPressed = false
local spawnInitialFrame = Game.spawnInitialFrame
local spectatingState = select(1, Spring.GetSpectatingState())

--------------------------------------------------------------------------------
-- Config persistence
--------------------------------------------------------------------------------
local function loadStatePrefs()
	local chunk = loadfile(CONFIG_PATH)
	if chunk then
		setfenv(chunk, {})
		local ok, result = pcall(chunk)
		if ok and type(result) == "table" then
			return result
		end
	end
	return {}
end

local function saveStatePrefs()
	table.save(unitSet, CONFIG_PATH, CONFIG_HEADER)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function GetCmdOpts(alt, ctrl, meta, shift, right)
	local opts = { alt = alt, ctrl = ctrl, meta = meta, shift = shift, right = right }
	local coded = 0

	if alt then
		coded = coded + CMD.OPT_ALT
	end
	if ctrl then
		coded = coded + CMD.OPT_CTRL
	end
	if meta then
		coded = coded + CMD.OPT_META
	end
	if shift then
		coded = coded + CMD.OPT_SHIFT
	end
	if right then
		coded = coded + CMD.OPT_RIGHT
	end

	opts.coded = coded
	return opts
end

local applyCmdOpts = GetCmdOpts(false, false, false, true, false)

-- Accepts a unitDefID (number) or a unit name (string), returns a valid name or nil.
local function resolveName(unitDefIDorName)
	local t = type(unitDefIDorName)
	if t == "number" then
		return unitName[unitDefIDorName]
	elseif t == "string" and validName[unitDefIDorName] then
		return unitDefIDorName
	end
	return nil
end

local function copyStates(states)
	local out = {}
	for cmdID, value in pairs(states) do
		out[cmdID] = value
	end
	return out
end

-- Snapshots every ICON_MODE state command (fire state, move state, repeat,
-- on/off, cloak, trajectory, ...) of a unit into a { [cmdID] = stateIndex } table.
local function captureUnitStates(unitID)
	local states = {}
	local cmdDescs = spGetUnitCmdDescs(unitID)
	if cmdDescs then
		for i = 1, #cmdDescs do
			local cmd = cmdDescs[i]
			if cmd.type == CMDTYPE_ICON_MODE and cmd.params then
				local current = tonumber(cmd.params[1])
				if current then
					states[cmd.id] = current
				end
			end
		end
	end
	return states
end

local function applyToUnit(unitID, unitDefID, unitTeam)
	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	if spectatingState or unitTeam ~= spGetMyTeamID() then
		return
	end
	local name = unitName[unitDefID]
	local states = name and unitSet[name]
	if not states then
		return
	end
	for cmdID, stateIndex in pairs(states) do
		if cmdID ~= CMD_REPEAT then
			spGiveOrderToUnit(unitID, cmdID, { stateIndex }, applyCmdOpts)
		end
	end
end

local function applyToTeam(teamID)
	teamID = teamID or ((not spectatingState) and spGetMyTeamID())
	local units = (teamID and spGetTeamUnits(teamID)) or spGetAllUnits()
	if units then
		for i = 1, #units do
			local unitID = units[i]
			applyToUnit(unitID, spGetUnitDefID(unitID), teamID or spGetUnitTeam(unitID))
		end
	end
end

--------------------------------------------------------------------------------
-- Core mutation operations (update in-memory + persist)
--------------------------------------------------------------------------------
local function setState(unitDefIDorName, cmdID, stateIndex)
	local name = resolveName(unitDefIDorName)
	if not name or type(cmdID) ~= "number" then
		return false
	end
	unitSet[name] = unitSet[name] or {}
	if unitSet[name][cmdID] == stateIndex then
		return false
	end
	unitSet[name][cmdID] = stateIndex
	saveStatePrefs()
	return true
end

local function clearState(unitDefIDorName, cmdID)
	local name = resolveName(unitDefIDorName)
	if not name or not unitSet[name] then
		return false
	end
	if unitSet[name][cmdID] == nil then
		return false
	end
	unitSet[name][cmdID] = nil
	saveStatePrefs()
	return true
end

local function clearUnit(unitDefIDorName)
	local name = resolveName(unitDefIDorName)
	if not name then
		return false
	end
	unitSet[name] = {}
	saveStatePrefs()
	return true
end

-- Wipes every saved state pref for all unit types, restoring defaults.
local function clearAll()
	unitSet = {}
	saveStatePrefs()
	spEcho("All state prefs reset to defaults")
	return true
end

-- Saves the full current state snapshot of each selected unit type.
local function saveUnits(units)
	if not units or #units == 0 then
		return 0
	end
	local savedNames = {}
	local saved = 0
	for i = 1, #units do
		local unitID = units[i]
		local udid = spGetUnitDefID(unitID)
		local name = unitName[udid]
		if name and not savedNames[name] then
			unitSet[name] = captureUnitStates(unitID)
			savedNames[name] = true
			saved = saved + 1
			spEcho("State prefs saved for unit: " .. unitHumanName[udid])
		end
	end
	if saved > 0 then
		saveStatePrefs()
		Spring.PlaySoundFile(saveSound, 0.6, 'ui')
	end
	return saved
end

local function saveSelected()
	return saveUnits(spGetSelectedUnits())
end

--------------------------------------------------------------------------------
-- Selection-based operations (mirror the original key actions)
--------------------------------------------------------------------------------
local function recordSelectedState(cmdID, command, value)
	local selectedUnits = spGetSelectedUnits()
	local changed = false
	for i = 1, #selectedUnits do
		local udid = spGetUnitDefID(selectedUnits[i])
		local name = unitName[udid]
		if name then
			unitSet[name] = unitSet[name] or {}
			if unitSet[name][cmdID] ~= value then
				unitSet[name][cmdID] = value
				spEcho("State pref changed:  " .. unitHumanName[udid] .. ",  " .. (command or cmdID) .. " " .. tostring(value))
				changed = true
			end
		end
	end
	if changed then
		saveStatePrefs()
	end
end

local function clearSelectedState(cmdID, command)
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local udid = spGetUnitDefID(selectedUnits[i])
		local name = unitName[udid]
		if name and unitSet[name] then
			unitSet[name][cmdID] = nil
			spEcho("State pref removed: " .. unitHumanName[udid] .. ", " .. (command or cmdID))
		end
	end
	saveStatePrefs()
end

local function clearSelectedUnits()
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local udid = spGetUnitDefID(selectedUnits[i])
		local name = unitName[udid]
		if name then
			unitSet[name] = {}
			spEcho("All state prefs removed for unit: " .. unitHumanName[udid])
		end
	end
	Spring.PlaySoundFile(clearSound, 0.6, 'ui')
	saveStatePrefs()
end

--------------------------------------------------------------------------------
-- Public WG API
--------------------------------------------------------------------------------
local function buildAPI()
	return {
		-- queries
		getAllPrefs = function()
			local out = {}
			for name, states in pairs(unitSet) do
				out[name] = copyStates(states)
			end
			return out
		end,
		getUnitPrefs = function(unitDefIDorName)
			local name = resolveName(unitDefIDorName)
			local states = name and unitSet[name]
			return states and copyStates(states) or nil
		end,
		hasPrefs = function(unitDefIDorName)
			local name = resolveName(unitDefIDorName)
			local states = name and unitSet[name]
			return states ~= nil and next(states) ~= nil
		end,

		-- live capture
		captureUnitStates = captureUnitStates,
		saveSelected = saveSelected,
		saveUnits = saveUnits,

		-- granular mutation
		setState = setState,
		clearState = clearState,
		clearUnit = clearUnit,
		clearAll = clearAll,
		recordSelected = function(cmdID, value)
			recordSelectedState(cmdID, nil, value)
		end,
		clearStateSelected = function(cmdID)
			clearSelectedState(cmdID, nil)
		end,
		clearSelected = clearSelectedUnits,

		-- persistence / application
		save = saveStatePrefs,
		reload = function()
			unitSet = loadStatePrefs()
		end,
		applyToUnit = applyToUnit,
		applyToTeam = applyToTeam,
	}
end

--------------------------------------------------------------------------------
-- Action callbacks
--------------------------------------------------------------------------------
function onRecordPress()
	if not wasRecordPressed then
		wasRecordPressed = true
		Spring.PlaySoundFile("LuaUI/Sounds/buildbar_add.wav", 1, 'ui')
		Spring.Echo("State Prefs: Record mode ON - click a state command (e.g. fire state)")
	end

	isRecordPressed = true
end

function onRecordRelease()
	isRecordPressed = false
	wasRecordPressed = false
	Spring.PlaySoundFile("LuaUI/Sounds/buildbar_rem.wav", 1, 'ui')
	Spring.Echo("State Prefs: Record mode OFF")
end

function onClearPress()
	isClearPressed = true
end

function onClearRelease()
	isClearPressed = false
end

function doClearUnit()
	clearSelectedUnits()
end

function doSaveCurrent()
	saveSelected()
end

--------------------------------------------------------------------------------
-- Widget call-ins
--------------------------------------------------------------------------------
function widget:PlayerChanged(playerID)
	spectatingState = select(1, Spring.GetSpectatingState())
	if spectatingState then
		widget:GameOver()
	end
end

function widget:Initialize()
	unitSet = loadStatePrefs()
	spectatingState = select(1, Spring.GetSpectatingState())

	if Spring.IsReplay() then
		widget:GameOver()
	end

	widgetHandler:AddAction("stateprefs_record", onRecordPress, nil, "p")
	widgetHandler:AddAction("stateprefs_record", onRecordRelease, nil, "r")
	widgetHandler:AddAction("stateprefs_clear", onClearPress, nil, "p")
	widgetHandler:AddAction("stateprefs_clear", onClearRelease, nil, "r")
	widgetHandler:AddAction("stateprefs_clearunit", doClearUnit, nil, "p")
	widgetHandler:AddAction("stateprefs_savecurrent", doSaveCurrent, nil, "p")

	WG.StatePrefs = buildAPI()
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not isRecordPressed and not isClearPressed then
		return false
	end

	local index = Spring.GetCmdDescIndex(cmdID)
	local command = Spring.GetActiveCmdDesc(index)
	-- need to filter only state commands!
	if type(command) ~= "table" or command.type ~= CMDTYPE_ICON_MODE then
		return
	end

	if #cmdParams == 1 then
		if isClearPressed then
			clearSelectedState(cmdID, command.name)
		else
			recordSelectedState(cmdID, command.name, cmdParams[1])
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	applyToUnit(unitID, unitDefID, unitTeam)
end

function widget:GameFrame(n)
	if Spring.GetGameState then
		local finishedLoading, loadedFromSave, locallyPaused, lagging = Spring.GetGameState()
		if loadedFromSave then
			widgetHandler:RemoveCallIn("GameFrame", self)
			return
		end
	end
	if n <= spawnInitialFrame then
		return
	end
	applyToTeam()
	widgetHandler:RemoveCallIn("GameFrame", self)
end

function widget:GameOver()
	spEcho("Recorded States Prefs")
	saveStatePrefs()
	widgetHandler:RemoveWidget()
end

function widget:Shutdown()
	WG.StatePrefs = nil
	widgetHandler:RemoveAction("stateprefs_record")
	widgetHandler:RemoveAction("stateprefs_clear")
	widgetHandler:RemoveAction("stateprefs_clearunit")
	widgetHandler:RemoveAction("stateprefs_savecurrent")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
