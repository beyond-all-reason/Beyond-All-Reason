--[[
	validate_mission.lua  –  standalone mission-validation tool

	Run from the BAR.sdd root directory:

	    lua tools/validate_mission.lua <mission_script.lua> [options]

	Options:
	    --strict-defs        Also check weapon and feature def names against the source
	                         tree. Off by default: both are generated at runtime, from
	                         unit defs, so the source tree does not list them all and
	                         valid missions would be reported as broken. Unit def names
	                         are always checked, since those are files in units/.
	    --teams <n>          Number of teams and ally teams the mission is played with,
	                         since a standalone run has no game setup to read. Default 2.
	    --verbose            Print informational output as well as the validation result.
	    --help               Show this help and exit.

	Exit codes: 0 = no errors, 1 = validation errors found, 2 = usage / load error.
]]

--------------------------------------------------------------------------------
-- Argument parsing
--------------------------------------------------------------------------------

local args = { ... }

local function eprint(message)
	io.stderr:write(message .. "\n")
end

local EXIT_OK      = 0
local EXIT_INVALID = 1
local EXIT_ERROR   = 2

local missionPath    = nil
local strictDefs     = false
local verbose        = false
local teamCount      = 2

local argIndex = 1
while argIndex <= #args do
	local arg = args[argIndex]
	if arg == "--help" then
		-- The extra parentheses keep gsub's match count out of the printed output.
		print((([[
Usage: lua tools/validate_mission.lua <mission_script.lua> [options]

  <mission_script.lua>   Path to a mission Lua file (relative to BAR.sdd root).
  --strict-defs          Also check weapon and feature def names against the source
                         tree, which under-reports them since both are generated at
                         runtime. Unit def names are always checked.
  --teams <n>            Number of teams and ally teams to assume (default 2).
  --verbose              Print informational output as well as the validation result.
  --help                 Show this help and exit.
]]):gsub("^\n", "")))
		os.exit(EXIT_OK)
	elseif arg == "--strict-defs" then
		strictDefs = true
	elseif arg == "--verbose" then
		verbose = true
	elseif arg == "--teams" then
		argIndex = argIndex + 1
		teamCount = tonumber(args[argIndex])
		if not teamCount then
			eprint("--teams needs a number")
			os.exit(EXIT_ERROR)
		end
	elseif missionPath == nil then
		missionPath = arg
	else
		eprint("Unknown argument: " .. arg)
		os.exit(EXIT_ERROR)
	end
	argIndex = argIndex + 1
end

if missionPath == nil then
	eprint("Usage: lua tools/validate_mission.lua <mission_script.lua> [--strict-defs] [--teams <n>] [--verbose]")
	os.exit(EXIT_ERROR)
end

--------------------------------------------------------------------------------
-- Bootstrap: table.* helpers are used everywhere, so they are loaded first.
--------------------------------------------------------------------------------

local tableFunctions, tableFunctionsError = loadfile("common/tablefunctions.lua")
if not tableFunctions then
	eprint("ERROR: Could not load common/tablefunctions.lua: " .. tostring(tableFunctionsError))
	eprint("Make sure you run this script from the BAR.sdd root directory.")
	os.exit(EXIT_ERROR)
end
tableFunctions()

--------------------------------------------------------------------------------
-- Engine global mocks
--------------------------------------------------------------------------------

_G.LOG = {
	ERROR      = "ERROR",
	WARNING    = "WARNING",
	INFO       = "INFO",
	DEBUG      = "DEBUG",
	DEPRECATED = "DEPRECATED",
}

-- Validation returns its messages, so nothing needs to be captured from these.
_G.Spring = {
	Log  = function() end,
	Echo = function() end,
}

--- Teams and ally teams come from the game setup, which a standalone run does not
--- have, so a mission is checked against the team count given on the command line.
function Spring.GetTeamAllyTeamID(teamID)
	return (teamID >= 0 and teamID < teamCount) and 0 or nil
end

function Spring.GetAllyTeamList()
	local allyTeamIDs = {}
	for allyTeamID = 0, teamCount - 1 do
		allyTeamIDs[#allyTeamIDs + 1] = allyTeamID
	end
	return allyTeamIDs
end

_G.GG = {}
_G.unpack = _G.unpack or table.unpack

--------------------------------------------------------------------------------
-- VFS
--------------------------------------------------------------------------------

_G.VFS = {}

_G.VFS.FileExists = function(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

_G.VFS.Include = function(path)
	local chunk, loadError = loadfile(path)
	if not chunk then
		eprint("VFS.Include: could not load '" .. path .. "': " .. tostring(loadError))
		return {}
	end

	local succeeded, result = pcall(chunk)
	if not succeeded then
		eprint("VFS.Include: error running '" .. path .. "': " .. tostring(result))
		return {}
	end
	return result
end

_G.VFS.LoadFile = function(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local data = file:read("*a")
	file:close()
	return data
end

_G.VFS.UnpackU32 = function(bytes)
	local b1, b2, b3, b4 = bytes:byte(1, 4)
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

_G.VFS.UnpackU16 = function(bytes)
	local b1, b2 = bytes:byte(1, 2)
	return b1 + b2 * 256
end

_G.VFS.DirList = function(directory, pattern)
	local files = {}
	local handle = io.popen('find "' .. directory .. '" -maxdepth 1 -type f -name "' .. (pattern or "*") .. '" | sort')
	if handle then
		for line in handle:lines() do
			files[#files + 1] = line
		end
		handle:close()
	end
	return files
end

_G.VFS.SubDirs = function(directory)
	local directories = {}
	local handle = io.popen('find "' .. directory .. '" -mindepth 1 -maxdepth 1 -type d | sort')
	if handle then
		for line in handle:lines() do
			directories[#directories + 1] = line
		end
		handle:close()
	end
	return directories
end

--------------------------------------------------------------------------------
-- Commands, which order validation checks against
--------------------------------------------------------------------------------

-- The engine's CMD table maps both ways, name -> id and id -> name, which is what
-- the known-command lookup in the order validators relies on.
_G.CMD = {}
for index, name in ipairs({
	"STOP", "INSERT", "REMOVE", "WAIT", "TIMEWAIT", "DEATHWAIT", "SQUADWAIT", "GATHERWAIT",
	"MOVE", "PATROL", "FIGHT", "ATTACK", "AREA_ATTACK", "GUARD", "AISELECT", "GROUPSELECT",
	"GROUPADD", "GROUPCLEAR", "REPAIR", "FIRE_STATE", "MOVE_STATE", "SETBASE", "INTERNAL",
	"SELFD", "LOAD_UNITS", "UNLOAD_UNITS", "UNLOAD_UNIT", "ONOFF", "RECLAIM", "CLOAK",
	"STOCKPILE", "DGUN", "RESTORE", "RESURRECT", "CAPTURE", "AUTOREPAIRLEVEL",
	"LOOPBACKATTACK", "DO_SEISMICPING",
}) do
	_G.CMD[name]  = index
	_G.CMD[index] = name
end

_G.GameCMD = VFS.Include("modules/customcommands.lua").GameCMD or {}

--------------------------------------------------------------------------------
-- Def names, scanned from the source tree
--------------------------------------------------------------------------------

local function scanDefsFromDir(directory)
	local defs = {}
	local handle = io.popen('find "' .. directory .. '" -type f -name "*.lua"')
	if handle then
		for line in handle:lines() do
			local name = line:match("([^/\\]+)%.lua$")
			if name then
				defs[name] = { id = 0 }
			end
		end
		handle:close()
	end
	return defs
end

local function anyDefName()
	return setmetatable({}, { __index = function() return { id = 0 } end })
end

-- Unit defs are files in units/, so they can always be checked. Weapon and feature
-- defs are generated at runtime from those unit defs, so unless strictness is asked
-- for they are accepted as-is rather than reported as invalid.
_G.UnitDefNames    = scanDefsFromDir("units")
_G.WeaponDefNames  = strictDefs and scanDefsFromDir("weapons") or anyDefName()
_G.FeatureDefNames = strictDefs and scanDefsFromDir("features") or anyDefName()

if verbose then
	print(string.format("[validate_mission] Scanned %d unit def names", table.count(_G.UnitDefNames)))
	if strictDefs then
		print(string.format("[validate_mission] Scanned %d weapon and %d feature def names",
			table.count(_G.WeaponDefNames), table.count(_G.FeatureDefNames)))
	end
end

--------------------------------------------------------------------------------
-- Mission API definitions, which mission files read when they are loaded
--------------------------------------------------------------------------------

local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

-- Definition files read the parameter types from GG when they are included.
_G.GG["MissionAPI"] = { Modules = { ParameterTypes = parameterTypes } }

local actionDefinitions  = VFS.Include("luarules/mission_api/actions_loader.lua").LoadActionDefinitions()
local triggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

_G.GG["MissionAPI"].ActionDefinitions  = actionDefinitions
_G.GG["MissionAPI"].TriggerDefinitions = triggerDefinitions
_G.GG["MissionAPI"].Difficulty         = 0

--------------------------------------------------------------------------------
-- Load the mission
--------------------------------------------------------------------------------

local missionChunk, missionLoadError = loadfile(missionPath)
if not missionChunk then
	eprint("ERROR: Could not load mission file '" .. missionPath .. "': " .. tostring(missionLoadError))
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

--------------------------------------------------------------------------------
-- Validate, on the raw mission data, exactly as api_missions.lua does
--------------------------------------------------------------------------------

local validation = VFS.Include("luarules/mission_api/validation/mission_validation.lua")

local result = validation.ValidateMission(mission, {
	ParameterTypes     = parameterTypes,
	ActionDefinitions  = actionDefinitions,
	TriggerDefinitions = triggerDefinitions,
})

for _, message in ipairs(result.warnings) do
	print("  [WARNING] " .. message)
end

if result.ok then
	print(string.format("OK – no validation errors in: %s (%d warning(s))", missionPath, #result.warnings))
	os.exit(EXIT_OK)
end

eprint(string.format("FAILED – %d validation error(s) in: %s", #result.errors, missionPath))
for _, message in ipairs(result.errors) do
	eprint("  [ERROR] " .. message)
end
os.exit(EXIT_INVALID)
