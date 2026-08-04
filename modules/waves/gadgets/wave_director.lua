local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Wave Director",
		desc = "Hosts named PvE wave directors: anger clocks, wave composition, burrow/boss lifecycle, squad AI",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------
	-- The unsynced half is a wire, not a feature: a director's events reach
	-- LuaUI under the name its spec asked for, and only while some widget has
	-- said it wants them.
	--------------------------------------------------------------------------
	-- Enabled by default: a panel that wants these events already declares a
	-- handler, and the handler's existence is the real gate. The toggle stays
	-- because the panels that predate this module flip it, and because a
	-- panel that goes quiet should be able to stop the traffic.
	local wanted = setmetatable({}, {
		__index = function()
			return true
		end,
	})

	local function forward(_, eventName, kind, number, tech)
		if not wanted[eventName] then
			return
		end
		local handler = Script.LuaUI[eventName]
		if handler == nil then
			return
		end
		local args = {}
		if kind ~= nil then
			args.type = kind
		end
		if number ~= nil then
			args.number = number
		end
		if tech ~= nil then
			args.tech = tech
		end
		handler(args)
	end

	---`/waveevents <EventName> <0|1>` — the toggle a stats panel flips when it
	---loads, so a game with no such panel pays nothing for the wire.
	local function setWanted(_, _, words)
		local name = words[1]
		if name ~= nil and name ~= "" then
			wanted[name] = words[2] ~= "0"
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("WaveEvent", forward)
		gadgetHandler:AddChatAction("waveevents", setWanted, "waves: /waveevents <EventName> <0|1>")
		-- The wire's own surface, so a flavor module can keep its legacy
		-- toggle name working without a second sync action on the same event.
		GG.WaveEvents = {
			---@param eventName string
			---@param enabled boolean
			SetWanted = function(eventName, enabled)
				wanted[eventName] = enabled
			end,
		}
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("WaveEvent")
		gadgetHandler:RemoveChatAction("waveevents")
		GG.WaveEvents = nil
	end

	return
end

--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------

local LOG_TAG = "wave_director"

local Anger = VFS.Include("modules/waves/lib/anger.lua")
local Director = VFS.Include("modules/waves/lib/director.lua")
local Drain = VFS.Include("modules/waves/spring/drain.lua")
local Placement = VFS.Include("modules/waves/spring/placement.lua")
local Squads = VFS.Include("modules/waves/spring/squads.lua")
local Structures = VFS.Include("modules/waves/spring/structures.lua")

local positionChecks = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
-- NOT `Placement`: that name is already this file's own spring/placement.lua,
-- and shadowing it would break Placement.New two lines down.
local PlacementApi = VFS.Include("modules/placement/api.lua")
local enemyLib = VFS.Include("luarules/gadgets/include/SpawnerEnemyLib.lua")

local placement = Placement.New({
	positionChecks = positionChecks,
	nearestValid = PlacementApi.NearestValid,
	enemyLib = enemyLib,
	mapSizeX = Game.mapSizeX,
	mapSizeZ = Game.mapSizeZ,
})
local squads = Squads.New()
local drain = Drain.New({ squads = squads })
local structures = Structures.New({ positionChecks = positionChecks })

-- The gadget is inert until asked: every callin returns immediately while
-- these are empty.
local hosts = {} ---@type table<string, table>
local hostNames = {} ---@type string[] sorted; pairs order is not a wire value

-- What is worth attacking, maintained once for every director that did not
-- bring its own targetsOf. Immobile only — a squad chasing a scout is a squad
-- doing nothing.
local targets = {} ---@type integer[]
local highValueTargets = {} ---@type integer[]
local isTarget = {} ---@type table<integer, boolean>

local gameOverFrame = nil ---@type integer|nil

--------------------------------------------------------------------------------
-- GameRulesParam names. The prefix reproduces a flavor's legacy names exactly
-- — "scav" gives scavTechAnger, ScavBossAngerGain_Base, scav_hiveCount — so a
-- UI panel written against the monolith keeps reading the same keys.
--------------------------------------------------------------------------------

---@param prefix string
---@return table<string, string>
local function rulesNames(prefix)
	local titled = prefix:sub(1, 1):upper() .. prefix:sub(2)
	return {
		techAnger = prefix .. "TechAnger",
		bossAnger = prefix .. "BossAnger",
		bossTime = prefix .. "BossTime",
		gracePeriod = prefix .. "GracePeriod",
		difficulty = prefix .. "Difficulty",
		bossHealth = prefix .. "BossHealth",
		hiveCount = prefix .. "_hiveCount",
		kills = prefix .. "Kills",
		bossesKilled = prefix .. "BossesKilled",
		aggressionLevel = prefix .. "PlayerAggressionLevel",
		angerGainBase = titled .. "BossAngerGain_Base",
		angerGainAggression = titled .. "BossAngerGain_Aggression",
		angerGainEco = titled .. "BossAngerGain_Eco",
		-- New names, for the counters the monolith kept to itself. A panel
		-- that wants to say "wave 12" had no way to ask before.
		waveNumber = prefix .. "WaveNumber",
		wavesCleared = prefix .. "WavesCleared",
		intensity = prefix .. "Intensity",
	}
end

--------------------------------------------------------------------------------
-- The shared target registry
--------------------------------------------------------------------------------

---@param teamID integer
---@return boolean
local function isDirectorTeam(teamID)
	for _, name in ipairs(hostNames) do
		if hosts[name].spec.teamID == teamID then
			return true
		end
	end
	return false
end

---@param unitDefID integer
---@return boolean
local function isHighValue(unitDefID)
	for _, name in ipairs(hostNames) do
		local highValue = hosts[name].spec.targets and hosts[name].spec.targets.highValue
		if highValue and highValue[unitDefID] then
			return true
		end
	end
	return false
end

---@generic T
---@param list T[]
---@param value T
local function removeFrom(list, value)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
			return
		end
	end
end

---@param unitID integer
local function dropTarget(unitID)
	if not isTarget[unitID] then
		return
	end
	isTarget[unitID] = nil
	removeFrom(targets, unitID)
	removeFrom(highValueTargets, unitID)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------

local HOT_CALLINS = { "GameFrame", "UnitCreated", "UnitDestroyed", "UnitDamaged", "GameOver" }
local hot = {} ---@type table<string, function>

---Install the hot callins, once, and leave them installed.
---
---NOT the "don't hook what you don't use" toggle this started as. The handler
---DEFERS list updates while it is inside a callin (callinDepth > 0) but the
---method field goes nil immediately, so a gadget that unhooks itself from
---inside a callin sits in the handler's list with a nil method until the loop
---ends — and the next gadget:GameFrame call in that same loop is a hard error.
---A director stopping mid-GameFrame is an ordinary thing here (a mission's
---Waves.End, the last boss dying), so the toggle had to go.
---
---What is left costs one comparison per callin while no director exists.
local function installCallins()
	for _, name in ipairs(HOT_CALLINS) do
		if gadget[name] == nil then
			gadget[name] = hot[name]
			gadgetHandler:UpdateCallIn(name)
		end
	end
end

--------------------------------------------------------------------------------
-- Executing orders
--------------------------------------------------------------------------------

---@param host table
---@param missionEvent string|nil the mission-bus name, when this event has one
---@param kind string|nil the LuaUI payload kind
---@param number number|nil
---@param tech number|nil
local function notify(host, missionEvent, kind, number, tech)
	if host.spec.events.toLuaUI ~= nil and kind ~= nil then
		SendToUnsynced("WaveEvent", host.spec.events.toLuaUI, kind, number, tech)
	end
	-- The mission bus is optional: a multiplayer game has no missions gadget,
	-- and a director must not care either way.
	if missionEvent ~= nil and GG.Missions ~= nil and GG.Missions.OnEvent ~= nil then
		GG.Missions.OnEvent(missionEvent)
	end
end

---@param host table
local function publish(host)
	local state = host.director.state
	local names = host.names
	Spring.SetGameRulesParam(names.techAnger, math.floor(state.anger.techAnger))
	Spring.SetGameRulesParam(names.bossAnger, math.floor(state.anger.bossAnger))
	Spring.SetGameRulesParam(names.aggressionLevel, math.floor(state.anger.aggression))
	local fromAggression, fromEco = Anger.Gains(state.params, state.anger)
	Spring.SetGameRulesParam(names.angerGainAggression, fromAggression)
	Spring.SetGameRulesParam(names.angerGainEco, fromEco)
	Spring.SetGameRulesParam(names.waveNumber, state.waveNumber)
	Spring.SetGameRulesParam(names.wavesCleared, state.wavesCleared)
	-- A rulesparam is a number: the dial travels x1000 so a tenth survives.
	Spring.SetGameRulesParam(names.intensity, math.floor(state.intensity * 1000))

	-- The same counters again, keyed by the DIRECTOR'S OWN NAME. The prefixed
	-- names above are a flavor's wire contract ("scav" for the panels that
	-- predate this module); a mission addresses a director by the pack it
	-- named, and has no way to know a prefix. Both, so neither side has to
	-- learn the other's vocabulary.
	local own = "waves_" .. state.name .. "_"
	Spring.SetGameRulesParam(own .. "wave", state.waveNumber)
	Spring.SetGameRulesParam(own .. "cleared", state.wavesCleared)
	Spring.SetGameRulesParam(own .. "bosses", state.boss.killed)
	Spring.SetGameRulesParam(own .. "active", state.stopped and 0 or 1)
end

---@param host table
---@return integer[]
local function burrowList(host)
	local list = {}
	for burrowID in pairs(host.director.state.burrows) do
		list[#list + 1] = burrowID
	end
	table.sort(list)
	return list
end

---@param host table
---@param frame integer
---@return WaveWorld
local function makeWorld(host, frame)
	local spec = host.spec
	return {
		frame = frame,
		time = frame / Game.gameSpeed,
		random = math.random,
		burrows = burrowList(host),
		surfaceOf = function(burrowID)
			local x, y, z = Spring.GetUnitPosition(burrowID)
			if x == nil then
				return "death"
			end
			if spec.hooks.surfaceOf then
				return spec.hooks.surfaceOf(x, y, z, spec.burrows.size)
			end
			return positionChecks.LandOrSeaCheck(x, y, z, spec.burrows.size)
		end,
		unitDefCount = function(defName)
			local unitDef = UnitDefNames[defName]
			return unitDef and Spring.GetTeamUnitDefCount(spec.teamID, unitDef.id) or 0
		end,
		teamUnitCount = Spring.GetTeamUnitCount(spec.teamID) or 0,
		peakPower = GG.PowerLib and GG.PowerLib.TeamPeakPower(spec.teamID) or nil,
		playerPower = GG.PowerLib and GG.PowerLib.TotalPlayerTeamsPower() or nil,
	}
end

---@param host table
---@param world WaveWorld
local function spawnBurrow(host, world)
	local state = host.director.state
	local burrowID, x, y, z = placement.TrySpawnBurrow(host.spec, state, world.time, state.anger.techAnger)
	if burrowID == nil then
		return
	end
	state.burrows[burrowID] = true
	state.owned[burrowID] = true
	Spring.SetUnitBlocking(burrowID, false, false)
	drain.SetExperience(state, burrowID)
	Spring.SetGameRulesParam(host.names.hiveCount, #burrowList(host))
	if host.spec.hooks.onBurrowSpawned then
		host.spec.hooks.onBurrowSpawned(burrowID, x, y, z)
	end
	-- A fresh burrow throws out an escort immediately, or the players would
	-- have a free minute to walk over and kill it.
	host.director.ComposeOffWave(world, burrowID)
end

---@param host table
---@param world WaveWorld
local function spawnBoss(host, world)
	local spec = host.spec
	local state = host.director.state
	local x, y, z = placement.BossPosition(spec, state)
	if x == nil then
		return
	end
	local defName = state.params.bossName or spec.boss.defName
	-- CreateUnit raises on an unknown def, and this is inside GameFrame.
	if UnitDefNames[defName] == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "no such boss def: " .. tostring(defName))
		return
	end
	local bossID = Spring.CreateUnit(defName, x, y, z, math.random(0, 3), spec.teamID)
	if bossID == nil then
		return
	end

	local _, maxHealth = Spring.GetUnitHealth(bossID)
	state.owned[bossID] = true
	host.director.OnBossSpawned(bossID, maxHealth)
	Spring.SetUnitHealth(
		bossID,
		math.max(maxHealth * (state.anger.techAnger * 0.01), maxHealth * spec.boss.minHealthFraction)
	)
	Spring.SetUnitExperience(bossID, 0)
	Spring.SetUnitAlwaysVisible(bossID, true)
	Spring.SetUnitBlocking(bossID, false, false)
	Spring.SetGameRulesParam("BossFightStarted", 1)

	-- The boss counts as a burrow: squads keep a door to come out of, and the
	-- boss itself is a squad of one that never ages out.
	state.burrows[bossID] = true
	local pending = Squads.NewPending(spec, state)
	pending.units = { bossID }
	pending.life = 999999
	pending.role = "raid"
	squads.Create(spec, state, pending)
	state.spawnQueue = {}
	state.timeOfLastWave = world.time

	notify(host, "waves.boss_spawned", "boss")
	if state.boss.spawned == 1 then
		-- The first boss brings the whole map with it.
		for _, burrowID in ipairs(world.burrows) do
			host.director.ComposeOffWave(world, burrowID)
		end
	end
end

---The sweep over the director's own units.
---
---Two jobs, both cheap only because they are sampled: retire expired flee
---cooldowns, and point idle units at something. An idle wave unit is the
---most visible failure mode a spawner has — it is what "the scavs just
---stand there" means — so the check is on every unit, and the ACTION is
---behind a coin so fifty units do not all re-path on the same frame.
---@param host table
---@param world WaveWorld
local function sweepUnits(host, world)
	local spec, state = host.spec, host.director.state
	for _, unitID in ipairs(Spring.GetTeamUnits(spec.teamID) or {}) do
		-- Only what this director created. In a mission it shares a team with
		-- the mission's own roster, and ordering the enclave commander around
		-- is emphatically not the director's business.
		if state.owned[unitID] then
			local defID = Spring.GetUnitDefID(unitID)
			if defID ~= nil and spec.hooks.onUnitTick then
				spec.hooks.onUnitTick(unitID, defID, state)
			end
			local cooldown = state.cowardCooldown[unitID]
			if cooldown ~= nil and world.frame > cooldown and math.random(1, 10) == 1 then
				state.cowardCooldown[unitID] = nil
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
			end
			-- A boss is never left idle: it is the fight, and a boss standing
			-- still is the fight not happening.
			local nudge = math.random(1, 10) == 1 or state.boss.ids[unitID]
			if nudge and Spring.GetUnitCommandCount(unitID) == 0 then
				squads.NudgeIdle(spec, state, unitID, world.frame)
			end
		end
	end
end

---@param host table
---@param world WaveWorld
---@param waveOrder WaveOrder
local function execute(host, world, waveOrder)
	local spec = host.spec
	local state = host.director.state
	local kind = waveOrder.kind

	if kind == "publish" then
		publish(host)
	elseif kind == "drain" then
		drain.Run(spec, state, function(unitID, entry)
			host.director.OnUnitSpawned(unitID, entry)
		end)
	elseif kind == "burrow" then
		spawnBurrow(host, world)
	elseif kind == "wave" then
		-- Squad lifetimes are measured in waves, so a wave landing IS the tick.
		squads.AgeAll(spec, state)
		notify(host, "waves.wave_spawned", spec.events.useWaveMsg and "wave" or nil, waveOrder.count)
	elseif kind == "boss" then
		spawnBoss(host, world)
	elseif kind == "structures" then
		structures.SpawnWave(spec, state, world.time, function(unitID)
			state.owned[unitID] = true
			drain.SetExperience(state, unitID)
		end)
	elseif kind == "squads" then
		squads.Pulse(spec, state, world.frame)
		squads.ManageAll(spec, state)
	elseif kind == "sweep" then
		sweepUnits(host, world)
	elseif kind == "box" then
		placement.UpdateBox(state, state.anger.techAnger)
	elseif kind == "event" then
		notify(host, nil, waveOrder.name, waveOrder.number, waveOrder.tech)
	end
end

--------------------------------------------------------------------------------
-- Hot callins
--------------------------------------------------------------------------------

hot.GameFrame = function(_, frame)
	if gameOverFrame ~= nil or #hostNames == 0 then
		return
	end
	for _, name in ipairs(hostNames) do
		local host = hosts[name]
		local world = makeWorld(host, frame)
		for _, waveOrder in ipairs(host.director.Tick(world)) do
			execute(host, world, waveOrder)
		end
	end
end

hot.UnitCreated = function(_, unitID, unitDefID, unitTeam)
	if #hostNames == 0 then
		return
	end
	for _, name in ipairs(hostNames) do
		local host = hosts[name]
		if unitTeam ~= host.spec.teamID then
			host.director.OnEcoStructure(unitDefID, 1)
		end
	end
	local unitDef = UnitDefs[unitDefID]
	if unitDef ~= nil and not unitDef.canMove and not isTarget[unitID] and not isDirectorTeam(unitTeam) then
		isTarget[unitID] = true
		targets[#targets + 1] = unitID
		if isHighValue(unitDefID) then
			highValueTargets[#highValueTargets + 1] = unitID
		end
	end
end

hot.UnitDamaged = function(_, unitID, _, _, _, _, _, _, attackerID)
	if #hostNames == 0 then
		return
	end
	-- A squad in a fight is not a squad that is stuck: give it its life back
	-- so the anti-stalemate valve does not fire mid-engagement.
	for _, name in ipairs(hostNames) do
		local state = hosts[name].director.state
		squads.ResetLifetime(state, unitID)
		if attackerID then
			squads.ResetLifetime(state, attackerID)
		end
	end
end

---@param host table
---@param unitID integer
---@param attackerID integer|nil
local function burrowDestroyed(host, unitID, attackerID)
	local spec, state = host.spec, host.director.state
	if not state.burrows[unitID] then
		return
	end
	state.burrows[unitID] = nil
	if attackerID and Spring.GetUnitTeam(attackerID) ~= spec.teamID then
		host.director.OnBurrowKilled()
	end
	-- Anything queued behind a dead burrow has nowhere to come out of.
	for i = #state.spawnQueue, 1, -1 do
		if state.spawnQueue[i].burrow == unitID then
			table.remove(state.spawnQueue, i)
		end
	end
	Spring.SetGameRulesParam(host.names.hiveCount, #burrowList(host))
end

---@param host table
---@param unitID integer
local function bossDestroyed(host, unitID)
	local state = host.director.state
	if not state.boss.ids[unitID] then
		return
	end
	local cycleComplete = host.director.OnBossKilled(unitID)
	Spring.SetGameRulesParam(host.names.bossesKilled, state.boss.killed)
	notify(host, "waves.boss_defeated", "bossKilled")
	if not cycleComplete then
		return
	end
	Spring.SetGameRulesParam("BossFightStarted", 0)
	if state.params.endless then
		host.director.NextCycle(Spring.GetGameSeconds())
		publish(host)
	else
		-- The director's job is done. Whether that ends the MATCH is
		-- matchflow's call, not a spawner's.
		host.director.Stop()
	end
end

hot.UnitDestroyed = function(_, unitID, unitDefID, unitTeam, _, _, attackerID)
	if #hostNames == 0 then
		return
	end
	dropTarget(unitID)
	for _, name in ipairs(hostNames) do
		local host = hosts[name]
		local spec, state = host.spec, host.director.state

		if unitTeam ~= spec.teamID then
			host.director.OnEcoStructure(unitDefID, -1)
		else
			Spring.SetGameRulesParam(host.names.kills, (Spring.GetGameRulesParam(host.names.kills) or 0) + 1)
		end

		squads.Forget(spec, state, unitID)
		if host.director.OnUnitDestroyed(unitID) then
			notify(host, "waves.wave_cleared", nil)
		end
		bossDestroyed(host, unitID)
		burrowDestroyed(host, unitID, attackerID)
	end
end

hot.GameOver = function()
	gameOverFrame = Spring.GetGameFrame()
end

--------------------------------------------------------------------------------
-- The module surface
--------------------------------------------------------------------------------

---@param spec WaveSpec
---@return table host
local function makeHost(spec)
	local director = Director.New(spec, math.random)
	local state = director.state

	-- Squad-side state the pure director has no opinion about.
	state.pendingSquad = Squads.NewPending(spec, state)
	state.targetPool = {}
	state.cowardCooldown = {}
	state.teleportCooldown = {}
	state.params.bossName = spec.boss and spec.boss.defName or nil

	-- The default target provider. A flavor that knows better replaces it;
	-- most do not need to.
	if spec.hooks.targetsOf == nil then
		spec.hooks.targetsOf = function()
			return targets, highValueTargets
		end
	end

	local host = { spec = spec, names = rulesNames(spec.rulesParamPrefix), director = director }

	placement.InitialBox(spec, state)
	placement.UpdateBox(state, 0)

	local names = host.names
	Spring.SetGameRulesParam(names.bossTime, state.params.bossTime)
	Spring.SetGameRulesParam(names.gracePeriod, state.params.gracePeriod)
	Spring.SetGameRulesParam(names.techAnger, 0)
	Spring.SetGameRulesParam(names.bossAnger, 0)
	Spring.SetGameRulesParam(names.angerGainBase, 100 / state.params.bossTimeSpan)
	Spring.SetGameRulesParam(names.angerGainAggression, 0)
	Spring.SetGameRulesParam(names.angerGainEco, 0)
	Spring.SetGameRulesParam(names.waveNumber, 0)
	Spring.SetGameRulesParam(names.wavesCleared, 0)
	Spring.SetGameRulesParam(names.intensity, 1000)
	if state.params.difficultyIndex then
		Spring.SetGameRulesParam(names.difficulty, state.params.difficultyIndex)
	end
	return host
end

---@param spec WaveSpec
---@return boolean started
local function start(spec)
	if type(spec) ~= "table" or type(spec.name) ~= "string" then
		Spring.Log(LOG_TAG, LOG.ERROR, "Waves.Start expects a spec table with a name")
		return false
	end
	if hosts[spec.name] ~= nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "a director named " .. spec.name .. " is already running")
		return false
	end
	if spec.allyTeamID == nil then
		spec.allyTeamID = select(6, Spring.GetTeamInfo(spec.teamID, false))
	end

	-- A malformed spec must not take the gadget down with it: a flavor module
	-- that miscomputed a dial gets a log line, and the game keeps running.
	local ok, host = pcall(makeHost, spec)
	if not ok then
		Spring.Log(LOG_TAG, LOG.ERROR, "Waves.Start(" .. spec.name .. "): " .. tostring(host))
		return false
	end

	hosts[spec.name] = host
	hostNames[#hostNames + 1] = spec.name
	table.sort(hostNames)
	installCallins()
	Spring.Echo("[" .. LOG_TAG .. "] director started: " .. spec.name .. " (team " .. tostring(spec.teamID) .. ")")
	return true
end

---@param name string
---@return boolean stopped
local function stop(name)
	local host = hosts[name]
	if host == nil then
		return false
	end
	host.director.Stop()
	-- Say so before the host goes: a mission condition or an editor probe
	-- watching this director would otherwise read the last live value forever.
	publish(host)
	hosts[name] = nil
	removeFrom(hostNames, name)
	return true
end

function gadget:Initialize()
	GG.Waves = {
		-- Register a spec and start its director. The spec is immutable from
		-- here on; everything that changes lives in the director's state.
		Start = start,
		Stop = stop,
		---@param name string
		---@return boolean
		IsActive = function(name)
			local host = hosts[name]
			return host ~= nil and not host.director.state.stopped
		end,
		---@param name string
		---@return WaveStatus|nil
		Status = function(name)
			local host = hosts[name]
			return host and host.director.Status() or nil
		end,
		---@param name string
		---@param intensity number
		SetIntensity = function(name, intensity)
			local host = hosts[name]
			if host ~= nil then
				host.director.SetIntensity(intensity)
				-- Republish now rather than at the next slow tick: a mission
				-- that turns the dial and reads it back should not see the
				-- old value for the rest of the second.
				publish(host)
			end
		end,
		---@param name string
		---@param overrides table|nil
		Surge = function(name, overrides)
			local host = hosts[name]
			if host ~= nil then
				host.director.Surge(overrides)
			end
		end,
		---Queue a named spawn at a spawner the flavor picked — the minion
		---path, where the roster names exactly what it wants.
		---@param name string director name
		---@param burrowID integer where it comes out
		---@param defName UnitDefName
		---@param count integer
		SpawnNamed = function(name, burrowID, defName, count)
			local host = hosts[name]
			if host ~= nil then
				host.director.ComposeNamed(burrowID, defName, count, math.random)
			end
		end,
		---@return string[]
		Names = function()
			local out = {}
			for i, name in ipairs(hostNames) do
				out[i] = name
			end
			return out
		end,
		---The savegame pile: plain tables, no closures, no def indexes.
		---@return table<string, WaveDirectorState>
		GetState = function()
			local saved = {}
			for _, name in ipairs(hostNames) do
				saved[name] = hosts[name].director.GetState()
			end
			return saved
		end,
		---@param name string
		---@param saved WaveDirectorState
		SetState = function(name, saved)
			local host = hosts[name]
			if host ~= nil then
				host.director.SetState(saved)
			end
		end,
	}
	installCallins()
end

function gadget:Shutdown()
	for i = #hostNames, 1, -1 do
		stop(hostNames[i])
	end
	GG.Waves = nil
end
