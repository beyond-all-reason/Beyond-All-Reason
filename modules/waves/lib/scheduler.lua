
local Anger = VFS.Include("modules/waves/lib/anger.lua")
local Boss = VFS.Include("modules/waves/lib/boss.lua")
local Difficulty = VFS.Include("modules/waves/lib/difficulty.lua")
local Wheel = VFS.Include("modules/waves/lib/wheel.lua")

local Scheduler = {}

local DRAIN_PERIOD = 5
local DRAIN_PHASE = 4
local SLOW_PERIOD = 30
local SLOW_PHASE = 16
-- The sweep over the director's own units. Seven, out of phase with
-- everything else, so the expensive callins never land on the same frame.
local SWEEP_PERIOD = 7
local SWEEP_PHASE = 3
local STRUCTURES_MIN_FRAME = 900
local BURROW_RETRY_GAP = 10
local WAVE_START_DELAY = 5

---@param state WaveDirectorState
---@return { size: number, pace: number }
function Scheduler.Scale(state)
	local intensity = state.intensity or 1
	if intensity <= 0 then
		return { size = 0, pace = math.huge }
	end
	return { size = intensity, pace = 1 / intensity }
end

---@param orders WaveOrder[]
---@param order WaveOrder
local function emit(orders, order)
	orders[#orders + 1] = order
end

---@param spec WaveSpec immutable — read for shape, never written
---@param state WaveDirectorState
---@param world WaveWorld
---@param orders WaveOrder[]
local function slowTick(spec, state, world, orders)
	local params = state.params
	local anger = state.anger
	local t = world.time
	local burrowCount = #world.burrows
	local scale = Scheduler.Scale(state)

	Anger.Decay(anger)
	anger.techAnger = Anger.Tech(params, t, anger.pastFirstBoss)
	local bossAnger, minBurrows = Anger.Boss(params, anger, t, state.boss.spawned)
	anger.bossAnger = bossAnger

	emit(orders, { kind = "publish" })

	-- The first wave is worth announcing exactly once: it is the moment grace
	-- ends, and a player who missed it has no other cue.
	if not state.announcedFirstWave and t > params.gracePeriod then
		state.announcedFirstWave = true
		emit(orders, { kind = "event", name = "firstWave" })
	end

	if
		spec.boss ~= nil
		and Boss.IsDue(bossAnger, burrowCount, t, params.gracePeriod)
		and Boss.CanSpawnMore(state.boss, spec.boss)
	then
		emit(orders, { kind = "boss" })
	end

	-- Two burrow rules, and they are not the same rule. The first keeps the
	-- map from emptying out; the second is the steady expansion up to the cap.
	if burrowCount < minBurrows then
		emit(orders, { kind = "burrow", minBurrows = minBurrows })
	end

	local sinceBurrow = t - state.timeOfLastBurrow
	local floorRule = t > params.burrowSpawnRate
		and burrowCount < minBurrows
		and (sinceBurrow > BURROW_RETRY_GAP or burrowCount == 0)
	local growthRule = params.burrowSpawnRate < sinceBurrow and burrowCount < params.maxBurrows
	if floorRule or growthRule then
		-- The growing box stops being an opening allowance once grace is over.
		if params.placement == "initialbox" and t > params.gracePeriod then
			params.placement = "initialbox_post"
		end
		emit(orders, { kind = "burrow", minBurrows = minBurrows })
		emit(orders, { kind = "event", name = "burrowSpawn" })
	elseif params.burrowSpawnRate < sinceBurrow and burrowCount >= params.maxBurrows then
		-- At the cap the clock still resets, or the moment one burrow dies the
		-- director would spawn a replacement in the same second.
		state.timeOfLastBurrow = t
	end

	-- A wave needs somewhere to come from, a clear queue (so waves never
	-- overlap into one endless stream), and either its cadence elapsed or the
	-- opening wave's fixed appointment reached.
	local due
	if state.firstWaveDue ~= nil then
		due = t >= state.firstWaveDue
	else
		due = (params.spawnRate * state.shape.timeMultiplier * scale.pace) < (t - state.timeOfLastWave)
	end
	if t > params.gracePeriod + WAVE_START_DELAY and burrowCount > 0 and #state.spawnQueue == 0 and due then
		state.firstWaveDue = nil
		Wheel.Tick(state.wheel)

		local difficulty = 1
		if params.dynamicDifficulty then
			local computed = Difficulty.Multiplier(world.peakPower, world.playerPower, params.dynamicDifficulty)
			if computed == nil then
				-- Power is unknown, not low. Skipping is the honest answer:
				-- treating it as "easy" is how the opening seconds used to
				-- produce a wave the roster could not fill.
				return
			end
			difficulty = computed
		end

		local shape
		if state.surge ~= nil then
			shape = state.surge
			state.surge = nil
		else
			shape = Wheel.Shape(state.wheel, {
				techAnger = anger.techAnger,
				waveTechAnger = state.shape.techAnger,
				airStartAnger = params.airStartAnger,
				spawnChance = params.spawnChance,
				tier2MinAnger = params.tier2MinAnger,
			}, world.random)
		end

		shape.techAnger = math.min(999, anger.techAnger * difficulty)
		shape.sizeMultiplier = shape.sizeMultiplier * difficulty
		state.shape = shape

		state.waveNumber = state.waveNumber + 1
		state.timeOfLastWave = t
		-- The opening waves may be boosted: the multiplier decays by one per
		-- wave, so a boost of 3 is 3x, 2x, then the roster's own size.
		local boost = math.max(1, params.firstWavesBoost or 1)
		emit(orders, {
			kind = "wave",
			ceiling = Anger.WaveCeiling(params, anger.techAnger, state.boss.spawned)
				* shape.sizeMultiplier
				* scale.size
				* boost,
		})
		params.firstWavesBoost = math.max(1, boost - 1)
	end

	emit(orders, { kind = "box" })
end

---@param spec WaveSpec
---@param state WaveDirectorState
---@param world WaveWorld
---@return WaveOrder[]
function Scheduler.Tick(spec, state, world)
	local orders = {}
	if state.stopped then
		return orders
	end
	local frame = world.frame

	-- The drain is deliberately NOT gated on anything but the unit cap: a wave
	-- already composed must reach the field even while the director is busy.
	-- A boosted opening drains every frame: the boost is meant to be felt
	-- at once, not trickled out at the ordinary pace.
	local boosted = (state.params.firstWavesBoost or 1) > 1
	if (boosted or frame % DRAIN_PERIOD == DRAIN_PHASE) and world.teamUnitCount < state.params.unitCap then
		emit(orders, { kind = "drain" })
	end

	if frame % SLOW_PERIOD == SLOW_PHASE then
		slowTick(spec, state, world, orders)
	end

	local turretPeriod = math.max(1, math.ceil(state.params.turretSpawnRate)) * 30
	if
		spec.structures ~= nil
		and frame % turretPeriod == 0
		and frame > STRUCTURES_MIN_FRAME
		and world.teamUnitCount < state.params.unitCap
	then
		emit(orders, { kind = "structures" })
	end

	if frame % SWEEP_PERIOD == SWEEP_PHASE then
		emit(orders, { kind = "sweep" })
	end

	emit(orders, { kind = "squads" })
	return orders
end

return Scheduler
