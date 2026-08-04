
local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local Pve = {}

---@class PveModeKeys
---@field difficulty string|nil
---@field bossCount string|nil
---@field bossTime string|nil
---@field grace string|nil
---@field waveTime string|nil the "how often" dial
---@field waveCount string|nil the "how many" dial
---@field placement string|nil
---@field endless string|nil
---@field firstWaveBoost string|nil early-wave size boost, for flavors that have one

---@param key string|nil
---@param value any
---@param locked boolean
---@return table<string, ModOptionConfig>
local function option(key, value, locked)
	if key == nil or value == nil then
		return {}
	end
	return { [key] = { value = value, locked = locked } }
end

---@param a table<string, ModOptionConfig>
---@param b table<string, ModOptionConfig>
---@return table<string, ModOptionConfig>
local function merge(a, b)
	for key, value in pairs(b) do
		a[key] = value
	end
	return a
end

---Structural choices take the structure lock; the numeric multipliers stay
---host-tunable unless a preset says .Locked().
---@param keys PveModeKeys
---@return table<string, fun(params: table, lock: table): table<string, ModOptionConfig>>
function Pve.SerializersFor(keys)
	return {
		["waves.difficulty"] = function(p, lock)
			return option(keys.difficulty, p.difficulty, lock.structure)
		end,
		["waves.boss"] = function(p, lock)
			return merge(option(keys.bossCount, p.count, lock.dial), option(keys.bossTime, p.timeMultiplier, lock.dial))
		end,
		["waves.grace"] = function(p, lock)
			return option(keys.grace, p.multiplier, lock.dial)
		end,
		["waves.pace"] = function(p, lock)
			return merge(
				option(keys.waveTime, p.timeMultiplier, lock.dial),
				option(keys.waveCount, p.countMultiplier, lock.dial)
			)
		end,
		["waves.placement"] = function(p, lock)
			return option(keys.placement, p.placement, lock.structure)
		end,
		["waves.endless"] = function(p, lock)
			return option(keys.endless, p.endless, lock.structure)
		end,
		["waves.boost"] = function(p, lock)
			return option(keys.firstWaveBoost, p.multiplier, lock.dial)
		end,
	}
end

---@param modeName string
---@param noun table
---@param verb string
local function checkPack(modeName, verb, noun)
	ModeBuilder.DomainOf(modeName, verb, noun, { waves = true }, "<Flavor>.<Pack>")
end

Pve.Verbs = {
	---@param modeName string
	---@param noun table
	---@param difficulty string
	Difficulty = function(modeName, noun, difficulty)
		checkPack(modeName, "Difficulty", noun)
		return { "waves.difficulty", difficulty = difficulty }
	end,

	---@param modeName string
	---@param noun table
	---@param count integer
	---@param timeMultiplier number|nil
	Boss = function(modeName, noun, count, timeMultiplier)
		checkPack(modeName, "Boss", noun)
		return { "waves.boss", count = count, timeMultiplier = timeMultiplier or 1 }
	end,

	---@param modeName string
	---@param noun table
	---@param multiplier number
	Grace = function(modeName, noun, multiplier)
		checkPack(modeName, "Grace", noun)
		return { "waves.grace", multiplier = multiplier }
	end,

	---@param modeName string
	---@param noun table
	---@param timeMultiplier number
	---@param countMultiplier number
	Pace = function(modeName, noun, timeMultiplier, countMultiplier)
		checkPack(modeName, "Pace", noun)
		return { "waves.pace", timeMultiplier = timeMultiplier, countMultiplier = countMultiplier }
	end,

	---@param modeName string
	---@param noun table
	---@param placement WaveBurrowPlacement
	Placement = function(modeName, noun, placement)
		checkPack(modeName, "Placement", noun)
		return { "waves.placement", placement = placement }
	end,

	---@param modeName string
	---@param noun table
	---@param endless boolean
	Endless = function(modeName, noun, endless)
		checkPack(modeName, "Endless", noun)
		return { "waves.endless", endless = endless }
	end,

	---@param modeName string
	---@param noun table
	---@param multiplier number
	Boost = function(modeName, noun, multiplier)
		checkPack(modeName, "Boost", noun)
		return { "waves.boost", multiplier = multiplier }
	end,
}

return Pve
