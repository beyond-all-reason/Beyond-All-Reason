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
		handler = true,
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

local clearSound = 'LuaUI/Sounds/switchoff.wav'
local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local isRecordPressed = false
local isClearPressed = false
local spawnInitialFrame = Game.spawnInitialFrame
local spawnWarpInFrame = Game.spawnWarpInFrame
local spectatingState = select(1, Spring.GetSpectatingState())
local CMD_WANT_CLOAK = GameCMD.WANT_CLOAK

local uDefID2UnitName = {}
for udid, ud in pairs(UnitDefs) do
	uDefID2UnitName[udid] = ud.name
end

local unitSet = {}

local function pruneUnitPrefs(name)
	if unitSet[name] and next(unitSet[name]) == nil then
		unitSet[name] = nil
	end
end

local function pruneAllUnitPrefs(unitSetData)
	for name, prefs in pairs(unitSetData) do
		if type(prefs) ~= "table" or next(prefs) == nil then
			unitSetData[name] = nil
		end
	end
end

-----------------------------------------------------------------------------------
-- preset helpers

local bombers = {}
local builderFactories = {}
local factories = {}
local fighters = {}
local landFactories = {}
local constructors = {}
local nanoTurrets = {}

local function UnitDefIsBomber(unitDef) -- stolen from old bomber default hold fire widget
	if not unitDef or not unitDef.weapons then
		return false
	end

	for i = 1, #unitDef.weapons do
		local wname = unitDef.weapons[i].weaponDef
		local weaponDef = WeaponDefs[wname]
		if weaponDef then
			if weaponDef.type == "AircraftBomb" then
				return true
			end
		end
	end

	return false
end

for unitName, unitDef in pairs(UnitDefNames) do
	if UnitDefIsBomber(unitDef) then
		bombers[unitName] = true
	end
	if unitDef.isFactory then -- code stolen from old factory guard pref widget
		local buildOptions = unitDef.buildOptions

		for i = 1, #buildOptions do
			local buildOptDefID = buildOptions[i]
			local buildOpt = UnitDefs[buildOptDefID]

			if (buildOpt and buildOpt.isBuilder and buildOpt.canAssist) then
				builderFactories[unitName] = true  -- only factories that can build builders are included
				break
			end
		end
	end
	if unitDef.customParams.fighter or unitDef.customParams.drone or unitDef.customParams.flyingcarrier then -- code from old fighter default fly pref widget
        fighters[unitName] = true
    end
	if unitDef.isFactory and not unitDef.customParams.airfactory then
		landFactories[unitName] = true
	end
	if unitDef.isBuilder and unitDef.canMove and unitDef.canAssist and not unitDef.isFactory and unitDef.customParams.iscommander then
		constructors[unitName] = true
	end
	if unitDef.isBuilder and unitDef.isFactory then
		factories[unitName] = true
	end
	if unitDef.isBuilder and not unitDef.isFactory and not unitDef.canMove then
		nanoTurrets[unitName] = true
	end
end

local presets = { -- CMD_ID, state_false, state_true, units
	bombers_default_hold_fire = {CMD.FIRE_STATE, nil, 0, bombers}, -- state_false can evaluate to false, since fake ternary only has issues with the second argument
	factoryguard = {GameCMD.FACTORY_GUARD, nil, 1, builderFactories},
	fighters_default_fly = {CMD.IDLEMODE, nil, 0, fighters},
	factory_hold_position = {CMD.MOVE_STATE, nil, 0, landFactories},
	constructors_priority = {GameCMD.PRIORITY, 0, 1, constructors},
	factories_priority = {GameCMD.PRIORITY, 0, 1, factories},
	nano_turrets_priority = {GameCMD.PRIORITY, 0, 1, nanoTurrets},
}

local function togglePreset(presetName, state, force)
	unitSet.presets = unitSet.presets or {}
	unitSet.presets[presetName] = state
	for unitName, _ in pairs(presets[presetName][4]) do
		if force or not unitSet[unitName] or not unitSet[unitName][presets[presetName][1]] then
			unitSet[unitName] = unitSet[unitName] or {}
			unitSet[unitName][presets[presetName][1]] = state and presets[presetName][3] or presets[presetName][2]
		end
	end
end

-------------------------------------------------------------------------------------------
-- The config was previously using a seperate file, but after a bug with this file
-- it was decided to simply use the widgetHandler shared config instead.
local function migrateOldConfig()
	local oldConfigPath = "LuaUI/config/StatesPrefs.lua"
	local chunk = loadfile(oldConfigPath)
	if not chunk then
		-- no old config/already migrated
		return nil
	end

	setfenv(chunk, {})
	local merged = chunk()
	-- in case a widgetHandler config exists, we want those to take preference, since they are definitely newer, but we still want to use
	-- the old ones if there's no entry for that unit. This is mainly just for users that move config files, for example from an old backup.
	table.mergeInPlace(merged, unitSet)
	os.remove(oldConfigPath)
	return merged
end

function widget:GetConfigData()
	local saveUnitSet = migrateOldConfig() or table.copy(unitSet) -- remove this line and the migration function once sufficient time has passed (implemented 2026-06-03)

	--clean for units not set to state not corresponding to preset
	for presetName, presetData in pairs(presets) do
		local presetState = unitSet.presets and unitSet.presets[presetName]
		if presetState ~= nil then
			for unitName, _ in pairs(presetData[4]) do
				if saveUnitSet[unitName] and saveUnitSet[unitName][presetData[1]] == (presetState and presetData[3] or presetData[2]) then
					saveUnitSet[unitName][presetData[1]] = nil
				end
			end
		end
	end
	pruneAllUnitPrefs(saveUnitSet)
	return saveUnitSet
end

function widget:SetConfigData(data)
	unitSet = data
	pruneAllUnitPrefs(unitSet)

	unitSet.presets = unitSet.presets or {} -- handle presets for groups of units like bombers defaulting on hold fire
	for presetName, state in pairs(unitSet.presets) do
		togglePreset(presetName, state, false)
	end

	if unitSet.presets.constructors_priority == nil then
		if widgetHandler.configData["Builder Priority"] then
			unitSet.presets = unitSet.presets or {}
			unitSet.presets.constructors_priority = not widgetHandler.configData["Builder Priority"].lowpriorityLabs
			togglePreset("constructors_priority", unitSet.presets.constructors_priority, false)

			unitSet.presets.nano_turrets_priority = not widgetHandler.configData["Builder Priority"].lowpriorityNanos
			togglePreset("nano_turrets_priority", unitSet.presets.nano_turrets_priority, false)

			unitSet.presets.constructors_priority = not widgetHandler.configData["Builder Priority"].lowpriorityCons
			togglePreset("constructors_priority", unitSet.presets.constructors_priority, false)
		else
			unitSet.presets.constructors_priority = true
			togglePreset("constructors_priority", unitSet.presets.constructors_priority, false)

			unitSet.presets.nano_turrets_priority = false
			togglePreset("nano_turrets_priority", unitSet.presets.nano_turrets_priority, false)
			
			unitSet.presets.constructors_priority = false
			togglePreset("constructors_priority", unitSet.presets.constructors_priority, false)
		end
	end

	-- handle porting of config from old auto cloak widget, can be removed after some time (implemented 2026-07)
	if widgetHandler.configData["Auto Cloak Units"] and widgetHandler.configData["Auto Cloak Units"].unitdefConfig then
		for unitName, cloak in pairs(widgetHandler.configData["Auto Cloak Units"].unitdefConfig) do
			if not unitSet[unitName] or not unitSet[unitName][CMD_WANT_CLOAK] then
				unitSet[unitName] = unitSet[unitName] or {}
				unitSet[unitName][CMD_WANT_CLOAK] = cloak and 1 or 0
			end
		end
	end
end


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
	if Spring.IsReplay() then
		widgetHandler:RemoveWidget()
		return
	end

	widgetHandler.actionHandler:AddAction(self, "stateprefs_record", onRecordPress, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "stateprefs_record", onRecordRelease, nil, "r")
	widgetHandler.actionHandler:AddAction(self, "stateprefs_clear", onClearPress, nil, "p")
	widgetHandler.actionHandler:AddAction(self, "stateprefs_clear", onClearRelease, nil, "r")
	widgetHandler.actionHandler:AddAction(self, "stateprefs_clearunit", doClearUnit, nil, "p")

	WG['stateprefs'] = {}
	WG['stateprefs'].getUnitDefaultState = function(unitName, cmdID) -- use unitName instead of unitDefID in case of not loaded units (like legion)
		if unitSet[unitName] then
			return unitSet[unitName][cmdID]
		end
	end
	WG['stateprefs'].setUnitDefaultState = function(unitName, cmdID, state)
		if not cmdID then
			unitName, cmdID, state = unitName[1], unitName[2], unitName[3]
		end
		unitSet[unitName] = unitSet[unitName] or {}
		unitSet[unitName][cmdID] = state
	end
	WG['stateprefs'].getPresetState = function(presetName)
		if unitSet.presets then
			return unitSet.presets[presetName]
		end
	end
	WG['stateprefs'].setPresetState = function(presetName, state)
		unitSet.presets = unitSet.presets or {}
		unitSet.presets[presetName] = state
		togglePreset(presetName, state, true)
	end
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


function doClearUnit()
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		local name = uDefID2UnitName[unitDefID]
		unitSet[name] = nil
		spEcho("All state prefs removed for unit: " .. name)
	end
	Spring.PlaySoundFile(clearSound , 0.6, 'ui')
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
		local name = uDefID2UnitName[unitDefID]
		local prefs = unitSet[name]

		if #cmdParams == 1 and isClearPressed then
			if prefs and prefs[cmdID] ~= nil then
				prefs[cmdID] = nil
				pruneUnitPrefs(name)
				spEcho("State pref removed: " .. name .. ", " .. command.name)
			end
		elseif #cmdParams == 1 then
			prefs = prefs or {}
			if prefs[cmdID] ~= cmdParams[1] then
				prefs[cmdID] = cmdParams[1]
				unitSet[name] = prefs
				spEcho("State pref changed:  " .. name .. ",  " .. command.name .. " " .. cmdParams[1])
			end
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	local cmdOpts = GetCmdOpts(false, false, false, true, false)

	local name = uDefID2UnitName[unitDefID]
	local prefs = unitSet[name]
	if unitTeam == Spring.GetMyTeamID() then
		for cmdID, cmdParam in pairs(prefs or {}) do
			if cmdID == 115 then
				return
			end -- we're skipping "repeat" command here for now
			Spring.GiveOrderToUnit(unitID, cmdID, { cmdParam }, cmdOpts)
		end
	end
end

local function ApplyUnitStates()
	local teamID = (not spectatingState) and Spring.GetMyTeamID()
	local units = (teamID and Spring.GetTeamUnits(teamID)) or Spring.GetAllUnits()
	if units then
		for i = 1, #units do
			widget:UnitCreated(units[i], Spring.GetUnitDefID(units[i]), teamID or Spring.GetUnitTeam(units[i]))
		end
	end
end

function widget:GameFrame(n)
	if Spring.GetGameState then
		local finishedLoading, loadedFromSave, locallyPaused, lagging = Spring.GetGameState()
		if loadedFromSave then
			widgetHandler:RemoveWidgetCallIn("GameFrame", self)
			return
		end
	end
	if n <= spawnInitialFrame then
		return
	end
	ApplyUnitStates()
	widgetHandler:RemoveWidgetCallIn("GameFrame", self)
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end

function widget:Shutdown()
	WG['stateprefs'] = nil
	widgetHandler.actionHandler:RemoveAction(self, "stateprefs_record")
	widgetHandler.actionHandler:RemoveAction(self, "stateprefs_clear")
	widgetHandler.actionHandler:RemoveAction(self, "stateprefs_clearunit")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
