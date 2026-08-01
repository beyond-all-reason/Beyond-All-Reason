--- A generic PvE mode grammar, parameterized by wire-key names.
---
--- Every PvE flavor exposes the same six dials — difficulty, boss, grace,
--- pace, placement, endless — under different modoption keys, because those
--- keys are wire values a lobby and a SPADS config already know. So this file
--- ships the GRAMMAR and the flavor supplies the KEYS: raptors can bind
--- `raptor_*` to the same verbs the day it moves onto waves, and neither the
--- verbs nor the presets written against them change.
---
--- Usage, from a flavor module's own mode_dsl.lua:
---
---     local Pve = VFS.Include("modules/waves/mode_dsl.lua")
---     M.Mode = ModeBuilder.Grammar({
---         category = "scav_defense_options",
---         serializers = Pve.SerializersFor({ difficulty = "scav_difficulty", ... }),
---         verbs = Pve.Verbs,
---     })

local ModeBuilder = VFS.Include("modules/mode_builder.lua")

local Pve = {}

--- Which modoption key each dial serializes to. A flavor may omit any of
--- them; the matching verb then serializes nothing, which is how a flavor
--- with no endless mode simply has no endless option.
---@class PveModeKeys
---@field difficulty string|nil
---@field bossCount string|nil
---@field bossTime string|nil
---@field grace string|nil
---@field waveTime string|nil the "how often" dial
---@field waveCount string|nil the "how many" dial
---@field placement string|nil
---@field endless string|nil

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

---Build the serializer registry for one flavor's key names.
---
---Structural choices (which difficulty row, where beacons appear, whether the
---game loops) take the structure lock; the numeric multipliers stay
---host-tunable unless a preset says .Locked().
---@param keys PveModeKeys
---@return table<string, fun(params: table, lock: table): table<string, ModOptionConfig>>
function Pve.SerializersFor(keys)
	return {
		["waves.difficulty"] = function(p, lock)
			return option(keys.difficulty, p.difficulty, lock.structure)
		end,
		["waves.boss"] = function(p, lock)
			return merge(
				option(keys.bossCount, p.count, lock.dial),
				option(keys.bossTime, p.timeMultiplier, lock.dial)
			)
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
	}
end

---@param modeName string
---@param noun table
---@param verb string
local function checkPack(modeName, verb, noun)
	ModeBuilder.DomainOf(modeName, verb, noun, { waves = true }, "<Flavor>.<Pack>")
end

--- The six verbs. Each takes the flavor's pack noun first, so a mode file
--- reads as "this preset sets the Horde pack's difficulty to normal" and a
--- flavor with several packs can dial them independently.
Pve.Verbs = {
	---Which difficulty row the pack starts on.
	---@param modeName string
	---@param noun table
	---@param difficulty string
	Difficulty = function(modeName, noun, difficulty)
		checkPack(modeName, "Difficulty", noun)
		return { "waves.difficulty", difficulty = difficulty }
	end,

	---How many bosses, and how quickly the countdown to them runs.
	---@param modeName string
	---@param noun table
	---@param count integer
	---@param timeMultiplier number|nil
	Boss = function(modeName, noun, count, timeMultiplier)
		checkPack(modeName, "Boss", noun)
		return { "waves.boss", count = count, timeMultiplier = timeMultiplier or 1 }
	end,

	---How long the players get before anything happens.
	---@param modeName string
	---@param noun table
	---@param multiplier number
	Grace = function(modeName, noun, multiplier)
		checkPack(modeName, "Grace", noun)
		return { "waves.grace", multiplier = multiplier }
	end,

	---The two halves of pressure: how often waves come, and how big they are.
	---@param modeName string
	---@param noun table
	---@param timeMultiplier number
	---@param countMultiplier number
	Pace = function(modeName, noun, timeMultiplier, countMultiplier)
		checkPack(modeName, "Pace", noun)
		return { "waves.pace", timeMultiplier = timeMultiplier, countMultiplier = countMultiplier }
	end,

	---Where the pack's spawners appear.
	---@param modeName string
	---@param noun table
	---@param placement WaveBurrowPlacement
	Placement = function(modeName, noun, placement)
		checkPack(modeName, "Placement", noun)
		return { "waves.placement", placement = placement }
	end,

	---Whether killing the boss ends it or starts the next cycle.
	---@param modeName string
	---@param noun table
	---@param endless boolean
	Endless = function(modeName, noun, endless)
		checkPack(modeName, "Endless", noun)
		return { "waves.endless", endless = endless }
	end,
}

return Pve
