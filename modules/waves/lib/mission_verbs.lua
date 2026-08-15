--- Waves' mission-sandbox verbs, pure half. Effects act through the ctx the
--- engine is handed (ctx.StartWaves resolves the pack where Spring exists),
--- so this specs under busted.
---
--- Missions name PACKS, not compositions. A pack is a flavor module's noun —
--- Scavengers.Skirmish — and what it contains is defined once, in that
--- module, not re-authored per mission. What a mission file DOES get is the
--- dials: who the pressure is aimed at, where it comes from, and how hard.

local WavesVerbs = {}

---@param pack table
---@param verb string
local function checkPack(pack, verb)
	assert(
		type(pack) == "table" and type(pack.name) == "string" and type(pack.module) == "string",
		verb .. " expects a wave pack (e.g. Scavengers.Skirmish)"
	)
end

---@param status WaveStatus|nil
---@param field string
---@param threshold integer
---@return boolean
local function reached(status, field, threshold)
	return status ~= nil and (status[field] or 0) >= threshold
end

---Build the Waves verbs. Nothing here is per-file: waves arms no lifetimes
---at load, so every trigger file can share one vocabulary table.
---@return WavesActions
function WavesVerbs.MakeWaves()
	local waves = {}

	---Begin returns a CHAIN, because starting a director needs more than a
	---noun: without a target it has nobody to attack, and .Against is the
	---only required link. The chain is dot-only and closure-free, so a
	---trigger file reads as one statement.
	---@param pack table
	---@return MissionWavesChain
	waves.Begin = function(pack)
		checkPack(pack, "Waves.Begin")
		local request = { pack = pack.name, module = pack.module, builder = pack.pack, intensity = 1 }
		local chain = {}

		---@param ctx MissionContext
		chain.execute = function(ctx)
			assert(request.against ~= nil, "Waves.Begin(" .. pack.name .. ") needs .Against(Team.…)")
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
				"Waves.Begin(...).Against expects a Team handle (e.g. Team.Player)"
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
			assert(type(fx) == "number" and type(fz) == "number", "Waves.Begin(...).From expects two map fractions")
			request.origin = { fx = fx, fz = fz }
			return chain
		end

		---@param intensity number
		---@return MissionWavesChain
		chain.Intensity = function(intensity)
			assert(
				type(intensity) == "number" and intensity >= 0,
				"Waves.Begin(...).Intensity expects a non-negative number"
			)
			request.intensity = intensity
			return chain
		end

		return chain
	end

	---Turn the dial on a running pack. The beat between objectives.
	---@param pack table
	---@param intensity number
	---@return MissionEffect
	waves.Intensify = function(pack, intensity)
		checkPack(pack, "Waves.Intensify")
		assert(type(intensity) == "number" and intensity >= 0, "Waves.Intensify expects a non-negative number")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SetWaveIntensity(pack.name, intensity)
			end,
		}
	end

	---One wave, now, and bigger. The scripted spike a beat lands on.
	---@param pack table
	---@return MissionEffect
	waves.Surge = function(pack)
		checkPack(pack, "Waves.Surge")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.SurgeWaves(pack.name)
			end,
		}
	end

	---Stop the pressure. Units already on the field stay: the mission ends
	---the SPAWNER, and killing what is already fighting you is the player's
	---job, not a trigger's.
	---@param pack table
	---@return MissionEffect
	waves.End = function(pack)
		checkPack(pack, "Waves.End")
		return {
			---@param ctx MissionContext
			execute = function(ctx)
				ctx.StopWaves(pack.name)
			end,
		}
	end

	---@param pack table
	---@param count integer|nil default 1
	---@return MissionCondition
	waves.Spawned = function(pack, count)
		checkPack(pack, "Waves.Spawned")
		local threshold = count or 1
		return {
			inputs = { "waves.wave_spawned" },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(pack.name), "waveNumber", threshold)
			end,
		}
	end

	---True once `count` waves have been wiped out. The counters only climb,
	---so the answer is latched by construction — a mission cannot miss the
	---edge by evaluating one cadence late.
	---@param pack table
	---@param count integer|nil default 1
	---@return MissionCondition
	waves.Cleared = function(pack, count)
		checkPack(pack, "Waves.Cleared")
		local threshold = count or 1
		return {
			inputs = { "waves.wave_cleared" },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(pack.name), "wavesCleared", threshold)
			end,
		}
	end

	---@param pack table
	---@param count integer|nil default 1
	---@return MissionCondition
	waves.BossDefeated = function(pack, count)
		checkPack(pack, "Waves.BossDefeated")
		local threshold = count or 1
		return {
			inputs = { "waves.boss_defeated" },
			---@param ctx MissionContext
			evaluate = function(ctx)
				return reached(ctx.WaveStatus(pack.name), "bossesKilled", threshold)
			end,
		}
	end

	return waves
end

return WavesVerbs
