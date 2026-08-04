
local Anger = {}

---Lua 5.1 has no math.clamp; the engine's extension is not in scope here.
---@param value number
---@param low number
---@param high number
---@return number
local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

---@return WaveAngerState
function Anger.NewState()
	return {
		techAnger = 0,
		bossAnger = 0,
		aggression = 0,
		aggressionLevel = 0,
		ecoValue = 0,
		pastFirstBoss = false,
	}
end

---Ceil'd before the clamp so a fresh game reads 0 and not -0.4.
---@param params WaveParams
---@param t number game seconds
---@param pastFirstBoss boolean
---@return number
function Anger.Tech(params, t, pastFirstBoss)
	-- Before the first boss a stretched grace period also stretches the clock
	-- it is measured against; after it, grace is grace and the ramp is gone.
	local grace = params.gracePeriod
	if params.graceRamp and not pastFirstBoss then
		grace = params.gracePeriodRamped
	end
	local span = params.techAngerBossTime - grace
	if span <= 0 then
		return 0
	end
	local anger = (t - grace) / span * 100
	anger = math.ceil(anger * ((params.economyScale * 0.5) + 0.5))
	return clamp(anger, 0, 999)
end

---@param params WaveParams
---@param state WaveAngerState mutated: aggressionLevel integrates
---@param t number game seconds
---@param bossesSpawned integer
---@return number bossAnger
---@return number minBurrows
function Anger.Boss(params, state, t, bossesSpawned)
	if t < params.gracePeriod then
		-- The burrow floor ramps in so the map is not empty when the first wave is due.
		local floor = math.max(4, 2 * math.min(params.teamCount, 8))
		return 0, math.ceil(floor * (t / params.gracePeriod))
	end

	local bossAnger, minBurrows
	if bossesSpawned == 0 then
		local span = params.bossTime - params.gracePeriod
		local ratio = span > 0 and ((t - params.gracePeriod) / span * 100) or 100
		bossAnger = math.max(math.ceil(ratio + state.aggressionLevel), 0)
		minBurrows = 1
	else
		bossAnger = 100
		minBurrows = params.endless and 4 or 1
	end

	local hours = params.bossTimeSpan / 3600
	if hours > 0 then
		state.aggressionLevel = state.aggressionLevel + ((state.aggression * 0.01) / hours) + state.ecoValue
	end
	return bossAnger, minBurrows
end

---@param params WaveParams
---@param state WaveAngerState
---@return number fromAggression
---@return number fromEco
function Anger.Gains(params, state)
	local hours = params.bossTimeSpan / 3600
	if hours <= 0 then
		return 0, state.ecoValue
	end
	return (state.aggression * 0.01) / hours, state.ecoValue
end

---@param state WaveAngerState
function Anger.Decay(state)
	state.aggression = state.aggression * 0.995
end

---@param params WaveParams mutated: maxXP drifts up, so survivors get veteran
---@param state WaveAngerState
function Anger.OnBurrowKilled(params, state)
	state.aggression = state.aggression + (params.angerBonus / params.spawnMultiplier)
	params.maxXP = params.maxXP * 1.01
end

---Normalised to a 60 minute boss so a short game feels the same pressure.
---@param params WaveParams
---@param state WaveAngerState
---@param penalty number
---@param sign 1|-1
function Anger.OnEcoStructure(params, state, penalty, sign)
	local hours = params.bossTimeSpan / 3600
	if hours <= 0 then
		return
	end
	state.ecoValue = state.ecoValue + sign * (penalty / hours)
end

---@param params WaveParams
---@param techAnger number
---@param bossesSpawned integer
---@return number
function Anger.WaveCeiling(params, techAnger, bossesSpawned)
	local ceiling = params.minWaveSize + math.ceil((techAnger * 0.01) * (params.maxWaveSize - params.minWaveSize))
	if bossesSpawned > 0 then
		ceiling = math.ceil(ceiling * (params.bossFightWaveSizeScale * 0.01))
	end
	return ceiling
end

---@param state WaveAngerState
function Anger.Reset(state)
	state.techAnger = 0
	state.bossAnger = 0
	state.aggression = 0
	state.aggressionLevel = 0
	state.pastFirstBoss = true
end

return Anger
