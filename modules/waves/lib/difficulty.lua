--- Two unrelated things that both answer "how hard is this right now".
---
--- Dynamic difficulty is the SHORT loop: a live comparison of the director's
--- peak power against the players', folded into a multiplier that nudges wave
--- size and roster tier. It never saves — it is recomputed every wave.
---
--- NextCycle is the LONG loop: endless mode's reloop, which walks the
--- difficulty ladder a rung and hands back a FRESH params table. The monolith
--- mutated its config in place, which is exactly what made the endless path
--- unsaveable; returning a new table is the whole fix.

local Difficulty = {}

---Per-player scaling, the shape every roster number uses: a fixed share plus
---a share that multiplies by how many teams are playing.
---@param base number
---@param perPlayer number 0..1, how much of the number scales with team count
---@param teamCount integer
---@param spawnMultiplier number
---@param cap integer|nil clamp on team count (burrows cap at 8, wave sizes do not)
---@return number
function Difficulty.PerPlayer(base, perPlayer, teamCount, spawnMultiplier, cap)
	local teams = cap and math.min(teamCount, cap) or teamCount
	return ((base * (1 - perPlayer)) + (base * perPlayer) * teams) * spawnMultiplier
end

---How outgunned the players are, as a multiplier in [min, max].
---
---Below the lower power ratio the director is losing and gets the full
---bonus; above the upper it is winning and gets the penalty. Returns nil when
---either side reports no power at all — usually the opening seconds, and the
---caller must skip the wave rather than treat "unknown" as "easy".
---@param peakPower number|nil the director team's peak
---@param playerPower number|nil every player team, summed
---@param bounds { min: number, max: number, lower: number, upper: number }
---@return number|nil
function Difficulty.Multiplier(peakPower, playerPower, bounds)
	if not peakPower or peakPower == 0 or not playerPower or playerPower == 0 then
		return nil
	end
	local ratio = peakPower / playerPower
	local normalised
	if ratio >= bounds.upper then
		normalised = 0
	elseif ratio <= bounds.lower then
		normalised = 1
	else
		normalised = (bounds.upper - ratio) / (bounds.upper - bounds.lower)
	end
	return bounds.min + (normalised * (bounds.max - bounds.min))
end

---@param params WaveParams
---@return WaveParams shallow copy, with the nested dials copied too
local function copyParams(params)
	local out = {}
	for key, value in pairs(params) do
		out[key] = value
	end
	if params.dynamicDifficulty then
		out.dynamicDifficulty = {
			min = params.dynamicDifficulty.min,
			max = params.dynamicDifficulty.max,
			lower = params.dynamicDifficulty.lower,
			upper = params.dynamicDifficulty.upper,
		}
	end
	return out
end

---The boss died and endless mode is on: climb a rung and start over.
---
---Past the top of the ladder the ladder repeats, but every repeat compounds —
---one more spawn multiplier, half a step more boss resistance, a quarter more
---damage and health. That is what makes cycle nine different from cycle six
---on a ladder only six rungs long. The boss also arrives faster every cycle.
---@param params WaveParams
---@param cycle integer the cycle being entered (2 on the first reloop)
---@param t number game seconds — the fresh grace period anchors here
---@return WaveParams fresh table; the caller swaps it into state
function Difficulty.NextCycle(params, cycle, t)
	local next = copyParams(params)
	local rows = params.difficultyRows
	if rows == nil or #rows == 0 then
		return next
	end

	local index = (params.difficultyIndex or 1) + 1
	local row = rows[index]
	if row ~= nil then
		next.bossResistanceMult = row.bossResistanceMult
		next.damageMod = row.damageMod
		next.healthMod = row.healthMod
	else
		-- Off the top: stay on the last rung and compound instead.
		index = index - 1
		row = rows[index]
		next.spawnMultiplier = params.spawnMultiplier + 1
		next.bossResistanceMult = (params.bossResistanceMult or 1) + 0.5
		next.damageMod = (params.damageMod or 1) + 0.25
		next.healthMod = (params.healthMod or 1) + 0.25
	end
	next.difficultyIndex = index

	next.bossName = row.bossName
	next.spawnChance = row.spawnChance
	next.maxXP = row.maxXP
	next.angerBonus = row.angerBonus
	next.turretSpawnRate = row.turretSpawnRate
	next.spawnRate = row.spawnRate
	next.bossStagger = row.bossStagger

	-- Grace restarts HERE, one second back so the tech clock is already live:
	-- the players do not get a second opening, they get a breath.
	next.gracePeriod = t - 1
	next.gracePeriodRamped = next.gracePeriod
	next.graceRamp = false
	next.bossTimeSpan = math.ceil(row.bossTime / (cycle / 2))
	next.bossTime = next.bossTimeSpan + next.gracePeriod
	next.techAngerBossTime = next.bossTime

	next.maxBurrows = Difficulty.PerPlayer(row.maxBurrows, params.perPlayerMultiplier, params.teamCount, next.spawnMultiplier, 8)
	next.maxWaveSize = Difficulty.PerPlayer(row.maxScavs, params.perPlayerMultiplier, params.teamCount, next.spawnMultiplier)
	next.minWaveSize = Difficulty.PerPlayer(row.minScavs, params.perPlayerMultiplier, params.teamCount, next.spawnMultiplier)
	next.burrowSpawnRate = row.burrowSpawnRate

	return next
end

return Difficulty
