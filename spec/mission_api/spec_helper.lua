-- Ambient state that the mission_api modules read at load time, kept out of the shared
-- root spec_helper. new() builds a SpecEnv that holds it, include() loads a module into
-- that env, and registerModules() loads the shared modules the way the gadget does.

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

-- A spec that needs defs installs its own before loading.
_G.UnitDefs = _G.UnitDefs or {}
_G.WeaponDefs = _G.WeaponDefs or {}

-- math.bit_and is one of Recoil's MathExtra additions, not standard Lua, so it needs a
-- stand-in here. Engine-side it takes a varargs list and folds it over 24-bit integers.
local function bitAnd(...)
	local result
	for _, value in ipairs({ ... }) do
		if result == nil then
			result = value
		else
			local folded, bit = 0, 1
			while result > 0 and value > 0 do
				if result % 2 == 1 and value % 2 == 1 then
					folded = folded + bit
				end
				result = math.floor(result / 2)
				value = math.floor(value / 2)
				bit = bit * 2
			end
			result = folded
		end
	end
	return result or 0
end

-- Command ids and option bits, as numbered in rts/Sim/Units/CommandAI/Command.h.
-- Modules that key a table by a command id at load fail on a bare `CMD = {}` with
-- "table index is nil", so the ids specs rely on are filled in here.
local function commandIDs()
	return {
		MOVE = 10,
		REPAIR = 40,
		OPT_META = 4,
		OPT_INTERNAL = 8,
		OPT_RIGHT = 16,
		OPT_SHIFT = 32,
		OPT_CTRL = 64,
		OPT_ALT = 128,
	}
end

-- Team layout, for modules that read it once at load rather than per call. Two playing
-- allyTeams and Gaia on its own, which is the arrangement a mission likely runs under.
local function teamLayout()
	return {
		GetGaiaTeamID = function()
			return 2
		end,
		GetAllyTeamList = function()
			return { 0, 1, 2 }
		end,
		GetTeamAllyTeamID = function(teamID)
			return teamID
		end,
	}
end

local function ignoreWrite() end

local MissionSpecEnv = {}

---A SpecEnv holding the mission stubs. Its GG is the spec file's own, which is where
---Builders.MissionApi installs GG['MissionAPI'].
---@param overrides table|nil globals for the env; a table for Spring, CMD or math is
---merged over the mission stubs for it rather than replacing them.
---@return table
function MissionSpecEnv.new(overrides)
	local globals = {
		GG = GG,
		math = { bit_and = bitAnd },
		CMD = commandIDs(),
		Spring = teamLayout(),
	}

	for name, value in pairs(overrides or {}) do
		local stubs = globals[name]
		if name ~= "GG" and type(stubs) == "table" and type(value) == "table" then
			for key, stub in pairs(value) do
				stubs[key] = stub
			end
		else
			globals[name] = value
		end
	end

	local env = SpecEnv.new(globals)

	env.GG.UnitAttributes = {
		SetUnitDefAttribute = ignoreWrite,
		SetUnitAttribute = ignoreWrite,
		SetUnitDefModifier = ignoreWrite,
		SetUnitModifier = ignoreWrite,
		SetUnitDefWeaponAttribute = ignoreWrite,
		SetUnitWeaponAttribute = ignoreWrite,
		SetUnitDefWeaponModifier = ignoreWrite,
		SetUnitWeaponModifier = ignoreWrite,
		WEAPON_DEATH = -1,
		WEAPON_SELFD = -2,
	}

	return env
end

MissionSpecEnv.include = SpecEnv.include

---Load the shared modules into the env, in the order the gadget loads them.
---@param env table
---@return table modules GG['MissionAPI'].Modules
function MissionSpecEnv.registerModules(env)
	local GG = env.GG
	GG["MissionAPI"] = GG["MissionAPI"] or {}
	local modules = GG["MissionAPI"].Modules or {}
	GG["MissionAPI"].Modules = modules
	local function include(path)
		return SpecEnv.include(env, path)
	end
	modules.ParameterTypes = modules.ParameterTypes or include("luarules/mission_api/parameter_types.lua")
	modules.Difficulty = modules.Difficulty or include("luarules/mission_api/difficulty.lua")
	modules.Variables = modules.Variables or include("luarules/mission_api/variables.lua")
	modules.UnitQuery = modules.UnitQuery or include("luarules/mission_api/unit_query.lua")
	modules.SeismicContacts = modules.SeismicContacts or include("luarules/mission_api/seismic_contacts.lua")
	modules.DetectionLevels = modules.DetectionLevels or include("luarules/mission_api/detection_levels.lua")
	return modules
end

return MissionSpecEnv
