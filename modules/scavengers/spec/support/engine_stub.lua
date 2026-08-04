--- A stubbed engine, just deep enough to load a roster.
---
--- The point is that the SAME stub feeds both the frozen legacy config and
--- lib/defs_build.lua, so any disagreement between them is a real difference
--- in the port and not a difference in what the two were told about the
--- world.
---
--- UnitDefNames fabricates a def for any name asked of it. That is deliberate:
--- the roster names roughly three thousand units, and a stub that only knew
--- the ones a spec thought to list would quietly send both sides down the
--- "this unit does not exist" branch and prove nothing.

local EngineStub = {}

---A pure name -> id hash. Pure matters: the two builds reach the same names
---in different orders, and an id assigned by a counter would then differ.
---Kept well inside 2^53 so the arithmetic stays exact in a double.
---@param name string
---@return integer
function EngineStub.DefID(name)
	local hash = 5381
	for i = 1, #name do
		hash = (hash * 131 + name:byte(i)) % 1099511627776 -- 2^40
	end
	-- Never zero, and never colliding with the "no such def" answer.
	return hash + 1
end

---@param overrides table<string, table>|nil defs to answer with verbatim
---@return table<string, table>
function EngineStub.UnitDefNames(overrides)
	local cache = {}
	for name, def in pairs(overrides or {}) do
		cache[name] = def
	end
	return setmetatable({}, {
		__index = function(_, name)
			if type(name) ~= "string" then
				return nil
			end
			if cache[name] == nil then
				cache[name] = {
					id = EngineStub.DefID(name),
					name = name,
					health = 10000,
					canFly = false,
					isFactory = false,
					xsize = 8,
					zsize = 8,
					customParams = {},
				}
			end
			return cache[name]
		end,
	})
end

---A default modoption snapshot: every dial at the value a fresh lobby shows.
---@param overrides table|nil
---@return table
function EngineStub.ModOptions(overrides)
	local options = {
		scav_difficulty = "normal",
		scav_graceperiodmult = 1,
		scav_bosstimemult = 1,
		scav_spawntimemult = 1,
		scav_spawncountmult = 1,
		scav_boss_count = 1,
		scav_endless = false,
		scav_scavstart = "initialbox",
		multiplier_resourceincome = 1,
		multiplier_metalextraction = 1,
		multiplier_energyconversion = 1,
		multiplier_energyproduction = 1,
		startmetal = 1000,
		startenergy = 1000,
	}
	for key, value in pairs(overrides or {}) do
		options[key] = value
	end
	return options
end

---Load a file in a sandbox that looks like the synced Lua state. Deliberately
---NOT VFS.Include: that memoizes by path, and this file is loaded twice with
---different modoptions.
---@param path string
---@param env table
---@return any
function EngineStub.Load(path, env)
	local chunk = assert(loadfile(path))
	setmetatable(env, { __index = _G })
	setfenv(chunk, env)
	return chunk()
end

---The environment the frozen legacy config expects to find around it.
---@param modOptions table
---@param unitDefNames table
---@return table
function EngineStub.Env(modOptions, unitDefNames)
	return {
		Spring = setmetatable({
			GetModOptions = function()
				return modOptions
			end,
			GetTeamList = function()
				return { 0, 1 }
			end,
			GetTeamLuaAI = function(teamID)
				return teamID == 1 and "ScavengersAI" or ""
			end,
		}, { __index = _G.Spring }),
		UnitDefNames = unitDefNames,
		UnitDefs = {},
		gadget = {
			GetInfo = function()
				return { name = "Scav Defense Spawner" }
			end,
		},
	}
end

return EngineStub
