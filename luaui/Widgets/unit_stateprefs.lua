--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "State Prefs V2",
		desc = "Sets pre-defined units states. Hold bindable action 'stateprefs_record' while clicking a unit's state commands to define the preferred state for newly produced units of its type. V2 fixes bug, improves console output to show unit and state change details.",
		author = "Errrrrrr, quantum + Doo, sneyed, Chronographer",
		date = "April 21, 2023",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnits = Spring.GetSelectedUnits
local spEcho = Spring.Echo

--[[------------------------------------------------------------------------------

Usage:
Bind actions to a key of your choice in /Beyond-All-Reason/data/uikeys.txt
stateprefs_record 		will save the preferred state for the selected unit/units for the selected command.
stateprefs_clear 		will clears the preferred state for the selected unit/units for the selected command.
stateprefs_clearunit 	will clears all saved states for the selected unit/units for all commands.

e.g. 
bind alt 	stateprefs_clear
bind ctrl 	stateprefs_record
bind sc_\ 	stateprefs_clearunit

--]]------------------------------------------------------------------------------
local unitArray = {}
local unitName = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name
end

local unitSet = {}
local chunk, err = loadfile("LuaUI/config/StatesPrefs.lua")
if chunk then
	local tmp = {}
	setfenv(chunk, tmp)
	unitArray = chunk()
end

local clearSound = 'LuaUI/Sounds/switchoff.wav'
local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local isRecordPressed = false
local isClearPressed = false

--------------------------------------------------------------------------------
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

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widget:GameOver()
	end
end

function widget:Initialize()
	unitArray = unitArray or {}
	for i, v in pairs(unitArray) do
		unitSet[i] = v
	end
	if Spring.IsReplay() then
		widget:GameOver()
	end

	widgetHandler:AddAction("stateprefs_record", onRecordPress, nil, "p")
	widgetHandler:AddAction("stateprefs_record", onRecordRelease, nil, "r")
	widgetHandler:AddAction("stateprefs_clear", onClearPress, nil, "p")
	widgetHandler:AddAction("stateprefs_clear", onClearRelease, nil, "r")
	widgetHandler:AddAction("stateprefs_clearunit", doClearUnit, nil, "p")
	
end

function onRecordPress()
  isRecordPressed = true
end

function onRecordRelease()
  isRecordPressed = false
end

function onClearPress()
  isClearPressed = true
end

function onClearRelease()
  isClearPressed = false
end

function saveStatePrefs()
	table.save(unitSet, "LuaUI/config/StatesPrefs.lua", "--States prefs")
end

function doClearUnit()
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		local name = unitName[unitDefID]
		unitSet[name] = {}
		spEcho("All state prefs removed for unit: " .. name)
	end
	Spring.PlaySoundFile(clearSound , 0.6, 'ui')
	saveStatePrefs()
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

	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		local name = unitName[unitDefID]
		unitSet[name] = unitSet[name] or {}
		
		if #cmdParams == 1 and isClearPressed then
			unitSet[name][cmdID] = nil
			spEcho("State pref removed: " .. name .. ", " .. command.name)
			saveStatePrefs()
		elseif #cmdParams == 1 and not (unitSet[name][cmdID] == cmdParams[1]) then
			unitSet[name][cmdID] = cmdParams[1]
			spEcho("State pref changed:  " .. name .. ",  " .. command.name .. " " .. cmdParams[1])
			saveStatePrefs()
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	local cmdOpts = GetCmdOpts(false, false, false, true, false)

	local name = unitName[unitDefID]

	unitSet[name] = unitSet[unitName[unitDefID]] or {}
	if unitTeam == Spring.GetMyTeamID() then
		for cmdID, cmdParam in pairs(unitSet[name]) do
			if cmdID == 115 then
				return
			end -- we're skipping "repeat" command here for now
			local success = Spring.GiveOrderToUnit(unitID, cmdID, { cmdParam }, cmdOpts)
			--spEcho("".. name .. ", " .. tostring(cmdID) .. ", " .. tostring(cmdParam) .. " success: ".. tostring(success))
		end
	end
end

function widget:GameOver()
	spEcho("Recorded States Prefs")
	saveStatePrefs()
	widgetHandler:RemoveWidget()
end

function widget:Shutdown()
	widgetHandler:RemoveAction("stateprefs_record")
	widgetHandler:RemoveAction("stateprefs_clear")
	widgetHandler:RemoveAction("stateprefs_clearunit")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
