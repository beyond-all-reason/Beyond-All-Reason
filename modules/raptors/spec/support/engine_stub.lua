
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

---Fabricates a def for any name: a stub that only knew the names a spec listed would send both
---sides down the "this unit does not exist" branch and prove nothing.
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
					isBuilding = false,
					metalCost = 100,
					xsize = 8,
					zsize = 8,
					customParams = {},
				}
			end
			return cache[name]
		end,
	})
end

---@param overrides table|nil
---@return table
function EngineStub.ModOptions(overrides)
	local options = {
		raptor_difficulty = "normal",
		raptor_graceperiodmult = 1,
		raptor_queentimemult = 1,
		raptor_spawntimemult = 1,
		raptor_spawncountmult = 1,
		raptor_queen_count = 1,
		raptor_endless = false,
		raptor_raptorstart = "initialbox",
		raptor_firstwavesboost = 1,
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

return EngineStub
