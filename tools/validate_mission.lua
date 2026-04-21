--[[
	validate_mission.lua  –  standalone mission-validation tool
	Run from the BAR.sdd root directory:

	    lua tools/validate_mission.lua <mission_script.lua> [options]

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
Usage: lua tools/validate_mission.lua <mission_script.lua> [options]

  <mission_script.lua>   Path to a mission Lua file (relative to BAR.sdd root).
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
	eprint("Usage: lua tools/validate_mission.lua <mission_script.lua> [--permissive-defs] [--verbose]")
	os.exit(EXIT_ERROR)
end

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
}

--- GG (Gadget Globals shared table) ---
_G.GG = {}

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
		eprint("VFS.Include: could not load '" .. path .. "': " .. tostring(err))
		_vfsCache[path] = {}
		return {}
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
	GROUPADD     = 40,
	GROUPCLEAR   = 45,
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
-- Fix collisions caused by sharing values: reassign carefully.
-- (The exact numeric values don't matter for validation; they just need
-- to be distinct non-nil integers so the command validator table keys work.)
do
	local next_id = 1
	local seen = {}
	for name, _ in pairs(_G.CMD) do
		_G.CMD[name] = next_id
		next_id = next_id + 1
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
-- Load the mission script and extract allyTeams / teams / ais / players
--------------------------------------------------------------------------------

-- We need TriggerTypes / ActionTypes available when the mission file executes
-- (missions do things like `local triggerTypes = GG['MissionAPI'].TriggerTypes`).
local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
local actionsSchema  = VFS.Include('luarules/mission_api/actions_schema.lua')

_G.GG['MissionAPI'] = {
	TriggerTypes = triggersSchema.Types,
	ActionTypes  = actionsSchema.Types,
	Triggers     = {},
	Actions      = {},
	AllyTeams    = {},
	Teams        = {},
	AIs          = {},
	Players      = {},
	Difficulty   = 0,
}

local missionChunk, loadErr = loadfile(missionPath)
if not missionChunk then
	eprint("ERROR: Could not load mission file '" .. missionPath .. "': " .. tostring(loadErr))
	os.exit(EXIT_ERROR)
end

local missionOk, mission = pcall(missionChunk)
if not missionOk then
	eprint("ERROR: Error executing mission file '" .. missionPath .. "': " .. tostring(mission))
	os.exit(EXIT_ERROR)
end

if type(mission) ~= "table" then
	eprint("ERROR: Mission file did not return a table (got " .. type(mission) .. ").")
	os.exit(EXIT_ERROR)
end

local rawTriggers = mission.Triggers
local rawActions  = mission.Actions
local startScript = mission.StartScript or {}

if not rawTriggers or type(rawTriggers) ~= "table" then
	eprint("ERROR: Mission file is missing a 'Triggers' table.")
	os.exit(EXIT_ERROR)
end
if not rawActions or type(rawActions) ~= "table" then
	eprint("ERROR: Mission file is missing an 'Actions' table.")
	os.exit(EXIT_ERROR)
end

-- Extract AllyTeams / Teams / AIs / Players from startScript so that
-- validators for TeamName / AllyTeamName work correctly.
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
	print("[validate_mission] AllyTeams: " .. table.concat(at, ", "))
	print("[validate_mission] Teams: "     .. table.concat(tm, ", "))
end

--------------------------------------------------------------------------------
-- Run the validation pipeline (mirrors api_missions.lua:loadMission)
--------------------------------------------------------------------------------

local triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
local actionsController  = VFS.Include('luarules/mission_api/actions_loader.lua')


local processOk, processErr

processOk, processErr = pcall(function()
	_G.GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers, rawActions)
end)
if not processOk then
	eprint("ERROR: ProcessRawTriggers failed: " .. tostring(processErr))
	os.exit(EXIT_ERROR)
end

processOk, processErr = pcall(function()
	_G.GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)
end)
if not processOk then
	eprint("ERROR: ProcessRawActions failed: " .. tostring(processErr))
	os.exit(EXIT_ERROR)
end

local validateReferences = VFS.Include('luarules/mission_api/validation.lua').ValidateReferences

processOk, processErr = pcall(validateReferences)
if not processOk then
	eprint("ERROR: ValidateReferences failed: " .. tostring(processErr))
	os.exit(EXIT_ERROR)
end

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
	print("OK – no validation errors found in: " .. missionPath)
	os.exit(EXIT_OK)
else
	eprint(string.format("FAILED – %d validation error(s) in: %s", #errorMessages, missionPath))
	for _, message in ipairs(errorMessages) do
		eprint("  [ERROR] " .. message)
	end
	os.exit(EXIT_INVALID)
end
