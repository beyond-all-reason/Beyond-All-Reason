-- The real unit defs, loaded through gamedata/unitdefs.lua as the engine does, in a private
-- env because the loader and the def files write globals as they go.

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function getUnitDefRequireModoptionDefaults()
	return {
		-- Multipliers
		multiplier_maxvelocity = 1,
		multiplier_turnrate = 1,
		multiplier_builddistance = 1,
		multiplier_buildpower = 1,
		multiplier_metalextraction = 1,
		multiplier_resourceincome = 1,
		multiplier_energyproduction = 1,
		multiplier_energyconversion = 1,
		multiplier_losrange = 1,
		multiplier_radarrange = 1,
		multiplier_shieldpower = 1,
		multiplier_weaponrange = 1,
		multiplier_weapondamage = 1,

		-- Unit restrictions
		unit_restrictions_notech2 = false,
		unit_restrictions_notech3 = false,
		unit_restrictions_noair = false,
		unit_restrictions_nobots = false,
		unit_restrictions_nocons = false,
		unit_restrictions_nodrops = false,
		unit_restrictions_noecon = false,
		unit_restrictions_nofactory = false,
		unit_restrictions_nogh = false,
		unit_restrictions_nohover = false,
		unit_restrictions_nokbot = false,
		unit_restrictions_nonavy = false,
		unit_restrictions_noradarvh = false,
		unit_restrictions_notank = false,
		unit_restrictions_nouber = false,
		unit_restrictions_nowall = false,
		unit_restrictions_noxp = false,
		unit_restrictions_nosuperweapons = false,

		-- Commander perks
		commander = 0,
		commtype = 0,
		commanderstorage = 0,
		automatic_swarm = 0,
		automatic_factory = 0,

		-- Other features
		unithats = false,
		scavunitsforplayers = false,
		releasecandidates = false,
		ruins = "disabled",
		forceallunits = false,
		transportenemy = "all",
		animationcleanup = false,
		xmas = false,
		assistdronesbuildpowermultiplier = 1,

		gamespeed = 30,
	}
end

-- The engine ships gamedata/system.lua and the repo does not; every def file runs behind it.
local function systemStub(env)
	return {
		lowerkeys = function(t)
			return t
		end,
		reftable = function(ref, tbl)
			tbl = tbl or {}
			setmetatable(tbl, { __index = ref })
			return tbl
		end,
		VFS = env.VFS,
		Spring = env.Spring,
		pairs = pairs,
		ipairs = ipairs,
		math = math,
		table = table,
		string = string,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = unpack or table.unpack,
		print = print,
		error = error,
		pcall = pcall,
		select = select,
		next = next,
		require = require,
	}
end

local function normalizeUnitDef(unitDef)
	if not unitDef then
		return
	end
	local cp = unitDef.customParams or unitDef.customparams
	if not cp then
		cp = {}
	end
	unitDef.customParams = cp
	unitDef.customparams = cp
	if cp.unitgroup == nil and unitDef.unitgroup then
		cp.unitgroup = unitDef.unitgroup
	end
	if unitDef.buildOptions == nil and unitDef.buildoptions ~= nil then
		unitDef.buildOptions = unitDef.buildoptions
	elseif unitDef.buildoptions == nil and unitDef.buildOptions ~= nil then
		unitDef.buildoptions = unitDef.buildOptions
	end
	if unitDef.canAssist == nil and unitDef.canassist ~= nil then
		unitDef.canAssist = unitDef.canassist
	elseif unitDef.canassist == nil and unitDef.canAssist ~= nil then
		unitDef.canassist = unitDef.canAssist
	end
	if unitDef.builder ~= nil and unitDef.isBuilder == nil then
		unitDef.isBuilder = unitDef.builder
	end
end

local function cacheKey(modOptions)
	local parts = {}
	for key, value in pairs(modOptions) do
		parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
	end
	table.sort(parts)

	return table.concat(parts, ";")
end

local function newDefsEnv(modOptions, holidays, gametypes)
	local options = getUnitDefRequireModoptionDefaults()
	for key, value in pairs(modOptions) do
		options[key] = value
	end

	local env
	env = SpecEnv.new({
		Spring = {
			GetModOptions = function()
				return options
			end,
			GetGameFrame = function()
				return 0
			end,
			IsCheatingEnabled = function()
				return false
			end,
			GetTeamLuaAI = function()
				return ""
			end,
			GetConfigInt = function(_, default)
				return default or 0
			end,
			TimeCheck = function(_, check)
				return check()
			end,
			GetTeamList = function()
				return { 0, 1, 2, 3 } -- Two players (0, 1), the scavenger team, and gaia.
			end,
		},
		Engine = {
			FeatureSupport = {},
		},
		Game = {
			speedModClasses = { Tank = 0, KBot = 1, Hover = 2, Boat = 3, Ship = 3 },
		},
		math = {
			clamp = function(value, low, high)
				return math.min(math.max(value, low), high)
			end,
		},
		BAR = {
			Utilities = {
				Gametype = {
					IsScavengers = function()
						return gametypes.scavengers == true
					end,
					IsRaptors = function()
						return gametypes.raptors == true
					end,
					GetCurrentHolidays = function()
						return holidays
					end,
				},
			},
		},
		includes = {
			["init.lua"] = true,
			["gamedata/system.lua"] = function()
				return systemStub(env)
			end,
		},
	})

	return env
end

local function parse(modOptions, holidays)
	local env = newDefsEnv(modOptions, holidays, {})
	local defs = SpecEnv.include(env, "gamedata/unitdefs.lua")
	if type(defs) ~= "table" then
		error("gamedata/unitdefs.lua did not return a table of unit defs", 0)
	end

	for _, def in pairs(defs) do
		normalizeUnitDef(def)
	end

	return defs
end

local RealUnitDefs = {}

local parsed = {}

---The real unit defs by name. gamedata never fills UnitDefNames, so there are no numeric IDs.
---@param modOptions table|nil  merged over the defaults the def files require
---@param holidays table<string, boolean>|nil  the holiday events running, as GetCurrentHolidays reports them
---@return table
function RealUnitDefs.byName(modOptions, holidays)
	modOptions = modOptions or {}
	holidays = holidays or {}

	local key = cacheKey(modOptions) .. "|" .. cacheKey(holidays)
	if parsed[key] == nil then
		parsed[key] = parse(modOptions, holidays)
	end

	-- A copy, so a caller adding or dropping a def does not change what the next one gets.
	local byName = {}
	for name, def in pairs(parsed[key]) do
		byName[name] = def
	end

	return byName
end

---Every def table, loaded through gamedata/defs.lua as the engine does. Not cached.
---@param modOptions table|nil
---@param gametypes { scavengers: boolean?, raptors: boolean? }|nil
---@return { unitdefs: table, featuredefs: table, weapondefs: table, armordefs: table, movedefs: table }
function RealUnitDefs.allDefs(modOptions, gametypes)
	local env = newDefsEnv(modOptions or {}, {}, gametypes or {})
	return SpecEnv.include(env, "gamedata/defs.lua")
end

return RealUnitDefs
