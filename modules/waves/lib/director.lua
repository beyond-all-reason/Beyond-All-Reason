
local Anger = VFS.Include("modules/waves/lib/anger.lua")
local Boss = VFS.Include("modules/waves/lib/boss.lua")
local Composer = VFS.Include("modules/waves/lib/composer.lua")
local Difficulty = VFS.Include("modules/waves/lib/difficulty.lua")
local Scheduler = VFS.Include("modules/waves/lib/scheduler.lua")
local Wheel = VFS.Include("modules/waves/lib/wheel.lua")

local Director = {}

---@class WaveWorld
---@field frame integer
---@field time number game seconds
---@field random WaveRng
---@field burrows integer[] live burrow ids, in a stable order
---@field surfaceOf fun(burrowID: integer): WaveSurface
---@field unitDefCount fun(defName: UnitDefName): integer
---@field teamUnitCount integer
---@field peakPower number|nil
---@field playerPower number|nil

---@class WaveDirector
---@field spec WaveSpec
---@field state WaveDirectorState
---@field Tick fun(world: WaveWorld): WaveOrder[]
---@field Status fun(): WaveStatus
---@field SetIntensity fun(intensity: number)
---@field Surge fun(overrides: table|nil)
---@field Stop fun()
---@field OnBurrowKilled fun()
---@field OnEcoStructure fun(defID: integer, sign: 1|-1)
---@field OnBossSpawned fun(unitID: integer, maxHealth: number)
---@field OnBossKilled fun(unitID: integer): boolean cycleComplete
---@field OnUnitSpawned fun(unitID: integer, entry: WaveQueueEntry)
---@field OnUnitDestroyed fun(unitID: integer)
---@field NextCycle fun(t: number)
---@field GetState fun(): WaveDirectorState
---@field SetState fun(saved: WaveDirectorState)

---Population tables arrive keyed by def name. pairs order is not a wire
---value in a synced director, so they are flattened to sorted lists ONCE —
---composition then draws from an index whose order is the same everywhere.
---@param populations table<string, table<UnitDefName, WavePopulationEntry>>
---@return table<string, WavePopulationSlot[]>
function Director.IndexPopulations(populations)
	local indexed = {}
	for key, entries in pairs(populations or {}) do
		local names = {}
		for def in pairs(entries) do
			names[#names + 1] = def
		end
		table.sort(names)
		local slots = {}
		for _, def in ipairs(names) do
			local entry = entries[def]
			slots[#slots + 1] = {
				def = def,
				minAnger = entry.minAnger,
				maxAnger = entry.maxAnger,
				maxAlive = entry.maxAlive,
			}
		end
		indexed[key] = slots
	end
	return indexed
end

---@param spec WaveSpec
---@param rng WaveRng
---@return WaveDirectorState
function Director.NewState(spec, rng)
	local params = {}
	for key, value in pairs(spec.params) do
		params[key] = value
	end
	-- The burrow dials mutate (the placement flip, the endless reloop), so
	-- they live in the mutable copy and not in the immutable spec.
	params.placement = spec.burrows.placement
	params.burrowSpawnRate = spec.burrows.spawnRate
	params.maxBurrows = spec.burrows.maxBurrows

	return {
		name = spec.name,
		anger = Anger.NewState(),
		wheel = Wheel.New(rng),
		params = params,
		shape = { sizeMultiplier = 1, timeMultiplier = 1, airPercentage = 20, specialPercentage = 0, techAnger = 0 },
		intensity = 1,
		surge = nil,
		waveNumber = 0,
		wavesCleared = 0,
		cycle = 1,
		timeOfLastWave = 0,
		timeOfLastBurrow = -999999,
		-- Set when the first spawner lands: the opening wave keeps a fixed
		-- appointment, later ones follow the cadence.
		firstWaveDue = nil,
		announcedFirstWave = false,
		spawnQueue = {},
		squads = {},
		unitSquad = {},
		burrows = {},
		spawnBox = nil,
		startBox = nil,
		spawnAreaMultiplier = 2,
		spawnRetries = 0,
		firstSpawn = true,
		fullySpawned = false,
		waveAlive = {},
		waveUnits = {},
		-- Everything this director created. A mission's director shares a team
		-- with the mission's own roster, so "on my team" is not "mine" — and
		-- commanding the mission's enclave commander is not the director's job.
		owned = {},
		boss = Boss.NewState(),
		stopped = false,
	}
end

---@param spec WaveSpec
---@param rng WaveRng used once, for the wheel's opening cooldowns
---@return WaveDirector
function Director.New(spec, rng)
	assert(type(spec) == "table" and type(spec.name) == "string", "Waves.Start expects a spec with a name")
	assert(type(spec.params) == "table", spec.name .. ": spec.params must be a table of resolved numbers")

	local director = {}
	director.spec = spec
	director.state = Director.NewState(spec, rng)
	local populations = Director.IndexPopulations(spec.populations)

	---@param world WaveWorld
	---@param ceiling number
	---@param capScale number
	---@param burrows integer[]
	---@return WaveComposeInput
	local function composeInput(world, ceiling, capScale, burrows)
		local state = director.state
		local counts = {}
		for key, slots in pairs(populations) do
			local alive = 0
			for _, slot in ipairs(slots) do
				alive = alive + world.unitDefCount(slot.def)
			end
			counts[key] = alive
		end
		return {
			buckets = spec.buckets,
			populations = populations,
			burrows = burrows,
			surfaceOf = world.surfaceOf,
			unitDefCount = world.unitDefCount,
			shape = state.shape,
			ceiling = ceiling,
			spawnChance = state.params.spawnChance,
			spawnMultiplier = state.params.spawnMultiplier,
			airStartAnger = state.params.airStartAnger,
			techAnger = state.anger.techAnger,
			teamCount = state.params.teamCount,
			teamID = spec.teamID,
			wave = state.waveNumber,
			rng = world.random,
			populationCounts = counts,
			capScale = capScale,
		}
	end

	---@param entries WaveQueueEntry[]
	local function enqueue(entries)
		local queue = director.state.spawnQueue
		for _, entry in ipairs(entries) do
			queue[#queue + 1] = entry
		end
	end

	---@param world WaveWorld
	---@return WaveOrder[]
	director.Tick = function(world)
		local state = director.state
		local orders = Scheduler.Tick(spec, state, world)
		for _, order in ipairs(orders) do
			if order.kind == "wave" then
				local composed = Composer.ComposeWave(composeInput(world, order.ceiling, 1, world.burrows))
				enqueue(composed.entries)
				order.entries = composed.entries
				order.count = composed.count
				state.waveAlive[state.waveNumber] = 0
				if spec.hooks.onWaveComposed then
					spec.hooks.onWaveComposed(state, composed.count)
				end
			end
		end
		return orders
	end

	---@param world WaveWorld
	---@param burrowID integer
	---@return integer count
	director.ComposeOffWave = function(world, burrowID)
		local composed = Composer.ComposeOffWave(composeInput(world, 0, 0.5, { burrowID }))
		enqueue(composed.entries)
		return composed.count
	end

	---@param burrowID integer
	---@param defName UnitDefName
	---@param count integer
	director.ComposeNamed = function(burrowID, defName, count, rng)
		local state = director.state
		enqueue(
			Composer.ComposeNamed(
				burrowID,
				defName,
				count,
				spec.teamID,
				state.params.spawnChance,
				state.waveNumber,
				rng
			)
		)
	end

	---@return WaveStatus
	director.Status = function()
		local state = director.state
		return {
			techAnger = state.anger.techAnger,
			bossAnger = state.anger.bossAnger,
			waveNumber = state.waveNumber,
			wavesCleared = state.wavesCleared,
			bossesKilled = state.boss.killed,
			bossesSpawned = state.boss.spawned,
			cycle = state.cycle,
			intensity = state.intensity,
			active = not state.stopped,
		}
	end

	---Intensity is state, so it serializes.
	---@param intensity number
	director.SetIntensity = function(intensity)
		assert(type(intensity) == "number" and intensity >= 0, "Waves.SetIntensity expects a non-negative number")
		director.state.intensity = intensity
	end

	---A surge override is consumed by one wave and then the wheel takes over again.
	---@param overrides table|nil
	director.Surge = function(overrides)
		local state = director.state
		local shape = {
			sizeMultiplier = 3,
			timeMultiplier = 1,
			airPercentage = state.shape.airPercentage,
			specialPercentage = 50,
			techAnger = state.shape.techAnger,
		}
		for key, value in pairs(overrides or {}) do
			shape[key] = value
		end
		state.surge = shape
		-- Bring the cadence forward too: a surge you wait two minutes for is
		-- not a surge.
		state.timeOfLastWave = -999999
	end

	director.Stop = function()
		director.state.stopped = true
	end

	director.OnBurrowKilled = function()
		local state = director.state
		Anger.OnBurrowKilled(state.params, state.anger)
	end

	---@param defID integer
	---@param sign 1|-1
	director.OnEcoStructure = function(defID, sign)
		local penalty = spec.aggression and spec.aggression.ecoPenalty and spec.aggression.ecoPenalty[defID]
		if penalty then
			Anger.OnEcoStructure(director.state.params, director.state.anger, penalty, sign)
		end
	end

	---@param unitID integer
	---@param maxHealth number
	director.OnBossSpawned = function(unitID, maxHealth)
		local state = director.state
		state.boss.spawned = state.boss.spawned + 1
		state.boss.ids[unitID] = true
		state.boss.aliveMaxHealth = state.boss.aliveMaxHealth + (maxHealth or 0)
		if spec.hooks.onBossSpawned then
			spec.hooks.onBossSpawned(unitID, state)
		end
	end

	---@param unitID integer
	---@return boolean cycleComplete every boss of this cycle is down
	director.OnBossKilled = function(unitID)
		local state = director.state
		if not state.boss.ids[unitID] then
			return false
		end
		state.boss.ids[unitID] = nil
		state.boss.killed = state.boss.killed + 1
		if spec.hooks.onBossKilled then
			spec.hooks.onBossKilled(unitID, state)
		end
		return spec.boss ~= nil and Boss.CycleComplete(state.boss, spec.boss)
	end

	---A queued spawn reached the field. The wave tag is what makes "wave
	---cleared" answerable: count up here, down in OnUnitDestroyed.
	---@param unitID integer
	---@param entry WaveQueueEntry
	director.OnUnitSpawned = function(unitID, entry)
		local state = director.state
		state.owned[unitID] = true
		local wave = entry.wave
		if wave ~= nil then
			state.waveUnits[unitID] = wave
			state.waveAlive[wave] = (state.waveAlive[wave] or 0) + 1
		end
		if spec.hooks.onUnitSpawned then
			spec.hooks.onUnitSpawned(unitID, entry.unitName, state)
		end
	end

	---@param unitID integer
	---@return boolean cleared the last unit of some wave just died
	director.OnUnitDestroyed = function(unitID)
		local state = director.state
		state.owned[unitID] = nil
		local wave = state.waveUnits[unitID]
		if wave == nil then
			return false
		end
		state.waveUnits[unitID] = nil
		local alive = (state.waveAlive[wave] or 1) - 1
		state.waveAlive[wave] = alive
		if alive > 0 then
			return false
		end
		state.waveAlive[wave] = nil
		state.wavesCleared = state.wavesCleared + 1
		return true
	end

	---Params are REPLACED, not edited — the fresh table is what makes the
	---reloop saveable.
	---@param t number game seconds
	director.NextCycle = function(t)
		local state = director.state
		state.cycle = state.cycle + 1
		state.params = Difficulty.NextCycle(state.params, state.cycle, t)
		Anger.Reset(state.anger)
		state.boss = Boss.NewState()
		state.spawnQueue = {}
		state.announcedFirstWave = true
		if spec.hooks.onCycleComplete then
			spec.hooks.onCycleComplete(state)
		end
	end

	---@return WaveDirectorState
	director.GetState = function()
		return director.state
	end

	---Lay saved progress over a spec the flavor module just rebuilt. Hooks are
	---code and come from the spec; only the numbers travel.
	---@param saved WaveDirectorState
	director.SetState = function(saved)
		director.state = saved
	end

	return director
end

return Director
