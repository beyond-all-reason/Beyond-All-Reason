local Hooks = {}

local CMD_CLOAK_SHIELD = 37382

---@param config table what defs_build produced
---@param behaviourByID table<integer, WaveBehaviour>
---@return WaveHooks
function Hooks.New(config, behaviourByID)
	return {
		---@param defID integer
		behaviourOf = function(defID)
			return behaviourByID[defID]
		end,

		onUnitTeleported = function(_, defID, fromX, fromY, fromZ, toX, toY, toZ)
			if GG.ScavengersSpawnEffectUnitDefID then
				GG.ScavengersSpawnEffectUnitDefID(defID, fromX, fromY, fromZ)
				GG.ScavengersSpawnEffectUnitDefID(defID, toX, toY, toZ)
			end
		end,

		---@param unitID integer
		---@param defName UnitDefName
		onUnitSpawned = function(unitID, defName)
			local unitDef = UnitDefNames[defName]
			if unitDef == nil then
				return
			end
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { config.defaultRaptorFirestate }, 0)
			if unitDef.canCloak then
				Spring.GiveOrderToUnit(unitID, CMD_CLOAK_SHIELD, { 1 }, 0)
			end
		end,

		---@param bossID integer
		---@param state WaveDirectorState
		onBossSpawned = function(bossID, state)
			Spring.SetUnitExperience(bossID, 0)
			if state.boss.spawned == 1 and GG.Waves and #config.miniBosses > 0 then
				for burrowID in pairs(state.burrows) do
					if burrowID ~= bossID and math.random() < config.spawnChance then
						local miniboss = config.miniBosses[math.random(1, #config.miniBosses)]
						GG.Waves.SpawnNamed(state.name, burrowID, miniboss, 1)
					end
				end
			end
		end,

		---@param bossID integer
		---@param state WaveDirectorState
		---@param staggered boolean
		onBossTick = function(bossID, state, staggered)
			if staggered or GG.Waves == nil or math.random() >= config.spawnChance / 15 then
				return
			end
			local defID = Spring.GetUnitDefID(bossID)
			local minions = defID and config.raptorMinions[UnitDefs[defID].name]
			if minions == nil then
				return
			end
			for _ = 1, (config.queenSpawnMult or 1) * 2 do
				GG.Waves.SpawnNamed(state.name, bossID, minions[math.random(1, #minions)], 4)
			end
		end,

		onCycleComplete = function(state)
			config.queenName = state.params.bossName
			config.queenResistanceMult = state.params.bossResistanceMult
			config.queenStagger = state.params.bossStagger
			if GG.Raptors and GG.Raptors.OnCycleComplete then
				GG.Raptors.OnCycleComplete()
			end
		end,

		---The chance is divided by how many of that def are alive, so a swarm of spawners does not multiply.
		---@param unitID integer
		---@param defID integer
		---@param state WaveDirectorState
		onUnitTick = function(unitID, defID, state)
			local minions = config.raptorMinions[UnitDefs[defID].name]
			if minions == nil or GG.Waves == nil then
				return
			end
			local team = Spring.GetUnitTeam(unitID)
			local alive = math.max(1, Spring.GetTeamUnitDefCount(team, defID))
			if math.random(1, math.ceil(33 * alive)) == 1 and math.random() < config.spawnChance then
				GG.Waves.SpawnNamed(state.name, unitID, minions[math.random(1, #minions)], 4)
			end
		end,
	}
end

return Hooks
