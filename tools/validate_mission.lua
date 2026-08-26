--[[
	validate_mission.lua  –  standalone mission-validation tool
	Run from the BAR.sdd root directory:

	    lua tools/validate_mission.lua <missionFolder> [options]

	<missionFolder> is a mission folder, e.g.
	    missions/campaigns/armada/sound_test

	The mission.json inside it is read to resolve team and ally team names.

	Options:
	    --permissive-defs    Accept any WeaponDefName / FeatureDefName (useful when
	                         weapon/feature defs are not fully indexed from source).
	    --verbose            Print all log messages, not just errors.
	    --help               Show this help and exit.

	Exit codes: 0 = no errors, 1 = validation errors found, 2 = usage / load error.
]]

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

local args = { ... }

local function eprint(msg) io.stderr:write(msg .. "\n") end

local EXIT_OK      = 0
local EXIT_INVALID = 1
local EXIT_ERROR   = 2

local missionPath    = nil
local permissiveDefs = false
local verbose        = false

for _, a in ipairs(args) do
	if a == "--help" then
		print(([[
Usage: lua tools/validate_mission.lua <missionFolder> [options]

  <missionFolder>        Path to a mission folder (relative to BAR.sdd root).
                         The mission.json inside it is read to resolve team and
                         ally team names.
  --permissive-defs      Skip validation of WeaponDefNames and FeatureDefNames
                         (always treat them as valid). UnitDefNames are still
                         validated from the units/ directory on disk.
  --verbose              Print informational log messages in addition to errors.
  --help                 Show this help and exit.
]]):gsub("^\n", ""))
		os.exit(EXIT_OK)
	elseif a == "--permissive-defs" then
		permissiveDefs = true
	elseif a == "--verbose" then
		verbose = true
	elseif missionPath == nil then
		missionPath = a
	else
		eprint("Unknown argument: " .. a)
		os.exit(EXIT_ERROR)
	end
end

if missionPath == nil then
	eprint("Usage: lua tools/validate_mission.lua <missionFolder> [--permissive-defs] [--verbose]")
	os.exit(EXIT_ERROR)
end

-- Only a mission folder is accepted; tolerate a trailing slash from tab completion.
local missionDir = missionPath:gsub("/+$", "")
local missionDataPath   = missionDir .. "/mission.json"

------------------------------------------------------------------------------------------------------------------------
-- Bootstrap: load common/tablefunctions.lua so table.* helpers are available before any other file is touched.
------------------------------------------------------------------------------------------------------------------------

local _vfsCache = {}

local function _loadFile(path)
	if _vfsCache[path] then
		return _vfsCache[path]
	end
	local chunk, err = loadfile(path)
	if not chunk then
		-- try lowercased path as a fallback
		local lower = path:lower()
		chunk, err = loadfile(lower)
	end
	if not chunk then
		return nil, err
	end
	local ok, result = pcall(chunk)
	if not ok then
		return nil, result
	end
	_vfsCache[path] = result
	return result
end

-- Load tablefunctions first (no VFS dependency inside it).
local tfOk, tfErr = loadfile("common/tablefunctions.lua")
if not tfOk then
	eprint("ERROR: Could not load common/tablefunctions.lua: " .. tostring(tfErr))
	eprint("Make sure you run this script from the BAR.sdd root directory.")
	os.exit(EXIT_ERROR)
end
tfOk()

------------------------------------------------------------------------------------------------------------------------
-- Engine global mocks
------------------------------------------------------------------------------------------------------------------------

_G.LOG = {
	ERROR      = "ERROR",
	WARNING    = "WARNING",
	INFO       = "INFO",
	DEBUG      = "DEBUG",
	DEPRECATED = "DEPRECATED",
}

--- Collected validation errors (and optionally all messages) ---
local logs = {}

--- Spring ---
_G.Spring = {
	Log = function(tag, level, message)
		if message == nil then message = level; level = LOG.INFO end
		local bucket = logs[level]
		if not bucket then bucket = {}; logs[level] = bucket end
		bucket[#bucket + 1] = message
	end,
	Echo = function() end,

	-- detection_levels reads the allyTeam layout as it loads. Validation is static and
	-- never evaluates detection, so an empty layout is enough to get the module loaded.
	GetGaiaTeamID = function() return nil end,
	GetTeamAllyTeamID = function() return nil end,
	GetAllyTeamList = function() return {} end,
}

--- GG (Gadget Globals shared table) ---
_G.GG = {}

--- Game (engine constants). Trigger and action definitions read these while
--- being loaded, so this has to exist before any of them are included.
--- envDamageTypes values are placeholders: definitions only compare them against
--- runtime damage types, which never occur during static validation.
_G.Game = {
	gameSpeed = 30,
	squareSize = 8,
	maxUnits = 32000,
	envDamageTypes = {
		FactoryCancel = -6,
		FactoryKilled = -5,
	},
}

--- unpack compatibility ---
_G.unpack = _G.unpack or table.unpack

--- VFS ---
_G.VFS = {}

_G.VFS.FileExists = function(path)
	local f = io.open(path, "r")
	if f then f:close(); return true end
	return false
end

_G.VFS.Include = function(path)
	if _vfsCache[path] then
		return _vfsCache[path]
	end
	local result, err = _loadFile(path)
	if result == nil and err then
		-- Returning an empty table here would surface much later as a confusing
		-- error in whichever loader consumed the file, so stop right away.
		eprint("ERROR: could not load '" .. path .. "': " .. tostring(err))
		os.exit(EXIT_ERROR)
	end
	-- _loadFile already stores in cache
	if result == nil then result = {} end
	_vfsCache[path] = result
	return result
end

_G.VFS.LoadFile = function(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- Shell out for directory listings; the loaders use these to discover the trigger and action definition files.
local function popenLines(command)
	local results = {}
	local handle = io.popen(command)
	if handle then
		for line in handle:lines() do
			results[#results + 1] = line
		end
		handle:close()
	end
	table.sort(results)
	return results
end

_G.VFS.DirList = function(dir, pattern)
	local namePattern = (pattern or "*"):gsub("^%*", "*")
	return popenLines(("find %s -maxdepth 1 -type f -name '%s' 2>/dev/null"):format(dir, namePattern))
end

_G.VFS.SubDirs = function(dir)
	local subDirs = popenLines(("find %s -mindepth 1 -maxdepth 1 -type d 2>/dev/null"):format(dir))
	for i, path in ipairs(subDirs) do
		subDirs[i] = path .. "/" -- engine returns trailing slashes
	end
	return subDirs
end

-- Little-endian integer unpack helpers (mirror engine VFS.UnpackU32/U16).
_G.VFS.UnpackU32 = function(s)
	local a, b, c, d = s:byte(1, 4)
	return a + b * 256 + c * 65536 + d * 16777216
end
_G.VFS.UnpackU16 = function(s)
	local a, b = s:byte(1, 2)
	return a + b * 256
end

-- ReadWAV will be defined by common/wav.lua (included by validation.lua).
-- We stub it here in case common/wav.lua is not loadable.
_G.ReadWAV = function(fname)
	local data = VFS.LoadFile(fname)
	if not data or #data < 12 then return nil end
	local chunkID = data:sub(1, 4)
	local format  = data:sub(9, 12)
	if chunkID == "RIFF" and format == "WAVE" then
		return { valid = true }
	end
	return nil
end

--- CMD (standard Spring engine commands, subset used by validation) ---
_G.CMD = {
	STOP         = 0,
	INSERT       = 1,
	REMOVE       = 2,
	WAIT         = 5,
	TIMEWAIT     = 6,
	DEATHWAIT    = 7,
	SQUADWAIT    = 8,
	GATHERWAIT   = 9,
	MOVE         = 10,
	PATROL       = 15,
	FIGHT        = 16,
	ATTACK       = 20,
	AREA_ATTACK  = 21,
	GUARD        = 25,
	AISELECT     = 30,
	GROUPSELECT  = 35,
	GROUPADD     = 36,
	GROUPCLEAR   = 37,
	REPAIR       = 40,
	FIRE_STATE   = 45,
	MOVE_STATE   = 50,
	SETBASE      = 55,
	INTERNAL     = 60,
	SELFD        = 65,
	LOAD_UNITS   = 75,
	UNLOAD_UNITS = 80,
	UNLOAD_UNIT  = 81,
	ONOFF        = 85,
	RECLAIM      = 90,
	CLOAK        = 95,
	STOCKPILE    = 100,
	DGUN         = 105,
	RESTORE      = 110,
	RESURRECT    = 115,
	CAPTURE      = 120,
	AUTOREPAIRLEVEL = 125,
	LOOPBACKATTACK  = 130,
	DO_SEISMICPING  = 135,
}
-- The engine's CMD table maps both ways (name -> id and id -> name), and validation.lua builds its set of known command
-- IDs from the table's keys. Without the reverse entries every numeric command ID looks unknown.
do
	local reverse = {}
	for name, id in pairs(_G.CMD) do
		reverse[id] = name
	end
	for id, name in pairs(reverse) do
		_G.CMD[id] = name
	end
end

--- GameCMD (BAR-specific custom commands, loaded from modules/customcommands.lua) ---
local customCommandsModule = VFS.Include('modules/customcommands.lua')
_G.GameCMD = customCommandsModule.GameCMD

--------------------------------------------------------------------------------
-- Build UnitDefNames from the units/ directory (filename → { id = n })
--------------------------------------------------------------------------------

local function scanDefsFromDir(dir)
	local defs = {}
	-- Portable recursive scan: use 'find' on Unix, 'dir' on Windows.
	local isWindows = package.config:sub(1, 1) == '\\'
	local cmd = isWindows
		and 'dir /b /s "' .. dir .. '\\*.lua" 2>nul'
		or  'find ' .. dir .. ' -type f -name "*.lua"'
	local handle = io.popen(cmd)
	if handle then
		for line in handle:lines() do
			local name = line:match("([^/\\]+)%.lua$")
			if name then
				defs[name] = { id = 0 } -- truthy placeholder
			end
		end
		handle:close()
	end
	return defs
end

_G.UnitDefNames    = scanDefsFromDir("units")
_G.WeaponDefNames  = permissiveDefs
	and setmetatable({}, { __index = function() return { id = 0 } end })
	or  scanDefsFromDir("weapons")
_G.FeatureDefNames = permissiveDefs
	and setmetatable({}, { __index = function() return { id = 0 } end })
	or  scanDefsFromDir("features")

if not permissiveDefs then
	local unitCount    = table.count(_G.UnitDefNames)
	local weaponCount  = table.count(_G.WeaponDefNames)
	local featureCount = table.count(_G.FeatureDefNames)
	if verbose then
		print(string.format("[validate_mission] Loaded %d UnitDefNames, %d WeaponDefNames, %d FeatureDefNames",
			unitCount, weaponCount, featureCount))
	end
	if weaponCount == 0 then
		eprint("WARNING: No WeaponDefNames found in weapons/. Consider --permissive-defs.")
	end
	if featureCount == 0 then
		eprint("WARNING: No FeatureDefNames found in features/. Consider --permissive-defs.")
	end
end

--------------------------------------------------------------------------------
-- Load the mission script and extract allyTeams / teams from mission.json
--------------------------------------------------------------------------------

-- Missions reference GG['MissionAPI'].TriggerDefinitions / ActionDefinitions at
-- load time, so the definitions have to exist before the mission file runs.
_G.GG['MissionAPI'] = {
	Triggers          = {},
	Actions           = {},
	Stages            = {},
	Objectives        = {},
	ManagedObjectives = {},
	AllyTeams         = {},
	Teams             = {},
	AIs               = {},
	Players           = {},
	Difficulty        = 0,
	Modules           = {
		ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua'),
	},
}

-- The detection triggers read these two at their own load time, in the order the
-- gadget sets them up: detection_levels reads SeismicContacts as it loads.
_G.GG['MissionAPI'].Modules.SeismicContacts = VFS.Include('luarules/mission_api/seismic_contacts.lua')
_G.GG['MissionAPI'].Modules.DetectionLevels = VFS.Include('luarules/mission_api/detection_levels.lua')

local stagesController     = VFS.Include('luarules/mission_api/stages_loader.lua')
local objectivesController = VFS.Include('luarules/mission_api/objectives_loader.lua')
local triggersController   = VFS.Include('luarules/mission_api/triggers_loader.lua')
local actionsController    = VFS.Include('luarules/mission_api/actions_loader.lua')

_G.GG['MissionAPI'].TriggerDefinitions = triggersController.LoadTriggerDefinitions()
_G.GG['MissionAPI'].ActionDefinitions  = actionsController.LoadActionDefinitions()


-- Same loader the gadget uses: every *.lua in the mission folder is a part.
local missionLoader = VFS.Include('luarules/mission_api/mission_loader.lua')

local missionOk, mission = pcall(missionLoader.LoadMissionFiles, missionDir)
if not missionOk then
	eprint("ERROR: Could not load mission '" .. missionDir .. "': " .. tostring(mission))
	os.exit(EXIT_ERROR)
end

if type(mission) ~= "table" then
	eprint("ERROR: Mission did not load to a table (got " .. type(mission) .. ").")
	os.exit(EXIT_ERROR)
end

if verbose then
	print(string.format("[validate_mission] Loaded %d trigger types, %d action types",
		table.count(_G.GG['MissionAPI'].TriggerDefinitions.Types),
		table.count(_G.GG['MissionAPI'].ActionDefinitions.Types)))
end


local initialStage   = mission.InitialStage
local rawStages      = mission.Stages or {}
local rawObjectives  = mission.Objectives or {}
local rawTriggers    = mission.Triggers or {}
local rawActions     = mission.Actions or {}
local unitLoadout    = mission.UnitLoadout
local featureLoadout = mission.FeatureLoadout

if type(rawTriggers) ~= "table" then
	eprint("ERROR: Mission file 'Triggers' must be a table, got " .. type(rawTriggers) .. ".")
	os.exit(EXIT_ERROR)
end
if type(rawActions) ~= "table" then
	eprint("ERROR: Mission file 'Actions' must be a table, got " .. type(rawActions) .. ".")
	os.exit(EXIT_ERROR)
end
if type(rawStages) ~= "table" then
	eprint("ERROR: Mission file 'Stages' must be a table, got " .. type(rawStages) .. ".")
	os.exit(EXIT_ERROR)
end
if type(rawObjectives) ~= "table" then
	eprint("ERROR: Mission file 'Objectives' must be a table, got " .. type(rawObjectives) .. ".")
	os.exit(EXIT_ERROR)
end

-- Team and ally team names live in mission.json (the lobby facing half of the
-- mission); the validators for TeamName / AllyTeamName parameters need them.
local json = VFS.Include('common/luaUtilities/json.lua')

local missionDataText = VFS.LoadFile(missionDataPath)
if not missionDataText then
	eprint("ERROR: Could not read mission data '" .. missionDataPath .. "'.")
	os.exit(EXIT_ERROR)
end

local missionDataOk, missionData = pcall(json.decode, missionDataText)
if not missionDataOk or type(missionData) ~= "table" then
	eprint("ERROR: Could not parse '" .. missionDataPath .. "': " .. tostring(missionData))
	os.exit(EXIT_ERROR)
end

local startScript = missionData.startScript or {}

local function extractAllyTeams(ss)
	local allyTeams = {}
	if type(ss.allyTeams) == "table" then
		for name, _ in pairs(ss.allyTeams) do
			allyTeams[name] = true
		end
	end
	return allyTeams
end

local function extractTeams(ss)
	local teams = {}
	if type(ss.allyTeams) == "table" then
		for _, allyTeam in pairs(ss.allyTeams) do
			if type(allyTeam) == "table" and type(allyTeam.teams) == "table" then
				for teamName, _ in pairs(allyTeam.teams) do
					teams[teamName] = true
				end
			end
		end
	end
	return teams
end

_G.GG['MissionAPI'].AllyTeams = extractAllyTeams(startScript)
_G.GG['MissionAPI'].Teams     = extractTeams(startScript)

if verbose then
	local at = {}
	for k in pairs(_G.GG['MissionAPI'].AllyTeams) do at[#at+1] = k end
	local tm = {}
	for k in pairs(_G.GG['MissionAPI'].Teams) do tm[#tm+1] = k end
	table.sort(at)
	table.sort(tm)
	print("[validate_mission] AllyTeams: " .. table.concat(at, ", "))
	print("[validate_mission] Teams: "     .. table.concat(tm, ", "))
end

--------------------------------------------------------------------------------
-- Run the validation pipeline (mirrors api_missions.lua:loadMission)
--------------------------------------------------------------------------------

local validation = VFS.Include('luarules/mission_api/validation.lua')

-- Run a single pipeline step, aborting with a clear message if it errors.
local function runStep(label, fn)
	local ok, err = pcall(fn)
	if not ok then
		eprint("ERROR: " .. label .. " failed: " .. tostring(err))
		os.exit(EXIT_ERROR)
	end
end

-- Processing order mirrors api_missions.lua:loadMission. ProcessRawObjectives
-- mutates rawTriggers/rawActions (it synthesizes a trigger and action for each
-- non-managed objective), so it must run before the trigger/action processors.
_G.GG['MissionAPI'].CurrentStageID = initialStage

runStep("ProcessRawStages", function()
	_G.GG['MissionAPI'].Stages = stagesController.ProcessRawStages(rawStages)
end)
runStep("ProcessRawObjectives", function()
	_G.GG['MissionAPI'].Objectives =
		objectivesController.ProcessRawObjectives(rawObjectives, rawTriggers, rawActions, rawStages)
end)
runStep("ProcessRawTriggers", function()
	_G.GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers)
end)
runStep("ProcessRawActions", function()
	_G.GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)
end)
_G.GG['MissionAPI'].UnitLoadout    = unitLoadout
_G.GG['MissionAPI'].FeatureLoadout = featureLoadout

-- Run the full validation suite (mirrors api_missions.lua:loadMission).
runStep("ValidateStages",       function() validation.ValidateStages(_G.GG['MissionAPI'].Stages) end)
runStep("ValidateObjectives",   function() validation.ValidateObjectives(_G.GG['MissionAPI'].Objectives) end)
runStep("ValidateInitialStage", function() validation.ValidateInitialStage(initialStage) end)
runStep("ValidateTriggers",     function() validation.ValidateTriggers(_G.GG['MissionAPI'].Triggers, rawActions) end)
runStep("ValidateActions",      function() validation.ValidateActions(_G.GG['MissionAPI'].Actions) end)
runStep("ValidateReferences",   function() validation.ValidateReferences() end)

--------------------------------------------------------------------------------
-- Output
--------------------------------------------------------------------------------

if verbose then
	for level, messages in pairs(logs) do
		if level ~= LOG.ERROR then
			for _, message in ipairs(messages) do
				print(string.format("[%s] %s", level, message))
			end
		end
	end
end

local errorMessages = logs[LOG.ERROR] or {}
if #errorMessages == 0 then
	print("OK – no validation errors found in: " .. missionDir)
	os.exit(EXIT_OK)
else
	eprint(string.format("FAILED – %d validation error(s) in: %s", #errorMessages, missionDir))
	for _, message in ipairs(errorMessages) do
		eprint("  [ERROR] " .. message)
	end
	os.exit(EXIT_INVALID)
end
