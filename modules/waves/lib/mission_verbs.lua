
local Events = VFS.Include("modules/waves/lib/events.lua")

local WavesVerbs = {}

---@param status WaveStatus|nil
---@param field string
---@param threshold integer
---@return boolean
local function reached(status, field, threshold)
	return status ~= nil and (status[field] or 0) >= threshold
end

---@param pack MissionWavePack
---@param verb string
---@param count integer|nil
---@return integer
local function threshold(pack, verb, count)
	assert(
		count == nil or (type(count) == "number" and count >= 1),
		pack.name .. "." .. verb .. " expects a count of at least 1"
	)
	return count or 1
end

---@param ref WavePackRef
---@return MissionWavePack
function WavesVerbs.Pack(ref)
	assert(
		type(ref) == "table"
			and type(ref.name) == "string"
			and type(ref.module) == "string"
			and type(ref.pack) == "string",
		"WavesVerbs.Pack expects a pack ref { name, module, pack }"
	)
	local pack = { domain = ref.domain, name = ref.name, module = ref.module, pack = ref.pack }
	local label = ref.name

	---@return MissionWavesChain
	pack.Begin = function()
		local request = { pack = ref.name, module = ref.module, builder = ref.pack, intensity = 1 }
		local chain = {}

		---@param ctx MissionContext
		chain.execute = function(ctx)
			assert(request.against ~= nil, label .. ".Begin() needs .Against(Team.…)")
			ctx.StartWaves(request)
		end

		---Whose problem these waves are. The director spawns for the team
		---opposing this one, which is what makes a mission's pressure hostile
		---without the file naming an enemy team that may not exist yet.
		---@param team MissionTeam
		---@return MissionWavesChain
		chain.Against = function(team)
			assert(
				type(team) == "table" and type(team.teamID) == "number",
				label .. ".Begin().Against expects a Team handle (e.g. Team.Player)"
			)
			request.against = team.teamID
			request.againstAllyTeam = team.allyTeam
			return chain
		end

		---Where the pressure comes from, as map fractions — the same units
		---units.lua positions in, so a mission never hard-codes a map size.
		---@param fx number
		---@param fz number
		---@return MissionWavesChain
		chain.From = function(fx, fz)
			assert(type(fx) == "number" and type(fz) == "number", label .. ".Begin().From expects two map fractions")
			request.origin = { fx = fx, fz = fz }
			return chain
		end

		---@param intensity number
		---@return MissionWavesChain
		chain.Intensity = function(intensity)
			assert(
				type(intensity) == "number" and intensity >= 0,
				label .. ".Begin().Intensity expects a non-negative number"
			)
			request.intensity = intensity
			return chain
		end

		return chain
	end

	---@param intensity number
	---@return MissionEffect
	pack.Intensify = function(intensity)
		assert(type(intensity) == "number" and intensity >= 0, label .. ".Intensify expects a non-negative number")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SetWaveIntensity(ref.name, intensity)
			end,
		}
	end

	---@return MissionEffect
	pack.Surge = function()
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SurgeWaves(ref.name)
			end,
		}
	end

	---Stop the pressure. Units already on the field stay: the mission ends
	---the SPAWNER, and killing what is already fighting you is the player's
	---job, not a trigger's.
	---@return MissionEffect
	pack.End = function()
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.StopWaves(ref.name)
			end,
		}
	end

	---A named squad now, out of any live burrow. Nothing comes out while the
	---director has no burrow: the pressure has to have arrived first.
	---@param defName UnitDefName
	---@param count integer
	---@return MissionEffect
	pack.Spawn = function(defName, count)
		assert(type(defName) == "string" and defName ~= "", label .. ".Spawn expects a unit def name")
		assert(type(count) == "number" and count >= 1, label .. ".Spawn expects a count of at least 1")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SpawnWaveUnits(ref.name, defName, count)
			end,
		}
	end

	---An off-wave squad: what a fresh burrow throws, on the mission's cue.
	---@return MissionEffect
	pack.OffWave = function()
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SpawnWaveOffWave(ref.name)
			end,
		}
	end

	---A structure wave now, outside the cadence.
	---@return MissionEffect
	pack.Structures = function()
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SpawnWaveStructures(ref.name)
			end,
		}
	end

	---Aggression the mission adds to the director's own sources: the boss
	---clock runs faster for a while.
	---@param amount number
	---@return MissionEffect
	pack.Aggression = function(amount)
		assert(type(amount) == "number" and amount > 0, label .. ".Aggression expects a positive amount")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.AddWaveAggression(ref.name, amount)
			end,
		}
	end

	---The roster clock has reached this anger. No event marks the moment,
	---so the condition is polled.
	---@param anger number
	---@return MissionCondition
	pack.AngerAtLeast = function(anger)
		assert(type(anger) == "number" and anger >= 0, label .. ".AngerAtLeast expects a non-negative anger")
		return {
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(ref.name), "techAnger", anger)
			end,
		}
	end

	---@param count integer|nil default 1
	---@return MissionCondition
	pack.Spawned = function(count)
		local need = threshold(pack, "Spawned", count)
		return {
			inputs = { Events.WaveSpawned },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(ref.name), "waveNumber", need)
			end,
		}
	end

	---The counters only climb, so the answer is latched by construction: a mission cannot miss the
	---edge by evaluating one cadence late.
	---@param count integer|nil default 1
	---@return MissionCondition
	pack.Cleared = function(count)
		local need = threshold(pack, "Cleared", count)
		return {
			inputs = { Events.WaveCleared },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(ref.name), "wavesCleared", need)
			end,
		}
	end

	---@param count integer|nil default 1
	---@return MissionCondition
	pack.BossDefeated = function(count)
		local need = threshold(pack, "BossDefeated", count)
		return {
			inputs = { Events.BossDefeated },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(ref.name), "bossesKilled", need)
			end,
		}
	end

	return pack
end

return WavesVerbs
