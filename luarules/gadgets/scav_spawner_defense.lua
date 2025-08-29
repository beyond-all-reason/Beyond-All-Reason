local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Scav Defense Spawner",
		desc = "Spawns burrows and scavs",
		author = "TheFatController/quantum, Damgam",
		date = "27 February, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if Spring.Utilities.Gametype.IsScavengers() and not Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Deactivated!")
	return false
end
Spring.SetLogSectionFilterLevel("Dynamic Difficulty", LOG.INFO)

local config = VFS.Include('LuaRules/Configs/scav_spawn_defs.lua')
local EnemyLib = VFS.Include('LuaRules/Gadgets/Include/SpawnerEnemyLib.lua')
local PveTargeting = VFS.Include('LuaRules/Gadgets/Include/PveTargeting.lua')

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	-- SYNCED CODE
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Speed-ups
	--

	local ValidUnitID = Spring.ValidUnitID
	local GetUnitNeutral = Spring.GetUnitNeutral
	local GetTeamList = Spring.GetTeamList
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local GetGaiaTeamID = Spring.GetGaiaTeamID
	local SetGameRulesParam = Spring.SetGameRulesParam
	local GetGameRulesParam = Spring.GetGameRulesParam
	local GetTeamUnitCount = Spring.GetTeamUnitCount
	local GetGameFrame = Spring.GetGameFrame
	local GetGameSeconds = Spring.GetGameSeconds
	local DestroyUnit = Spring.DestroyUnit
	local GetTeamUnits = Spring.GetTeamUnits
	local GetUnitPosition = Spring.GetUnitPosition
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local TestBuildOrder = Spring.TestBuildOrder
	local GetGroundBlocked = Spring.GetGroundBlocked
	local CreateUnit = Spring.CreateUnit
	local SetUnitBlocking = Spring.SetUnitBlocking
	local GetGroundHeight = Spring.GetGroundHeight
	local GetUnitHealth = Spring.GetUnitHealth
	local SetUnitExperience = Spring.SetUnitExperience
	local GetUnitIsDead = Spring.GetUnitIsDead

	local mRandom = math.random
	local math = math
	local Game = Game
	local table = table
	local ipairs = ipairs
	local pairs = pairs

	local MAPSIZEX = Game.mapSizeX
	local MAPSIZEZ = Game.mapSizeZ

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	Spring.SetGameRulesParam("BossFightStarted", 0)
	local nKilledBosses = 0
	local nSpawnedBosses = 0
	local nTotalBosses = Spring.GetModOptions().scav_boss_count or 1
	local maxTries = 30
	local scavUnitCap = math.floor(Game.maxUnits*0.80)
	local minBurrows = 1
	local timeOfLastSpawn = -999999
	local timeOfLastWave = 0
	local t = 0 -- game time in secondstarget
	local bossAnger = 0
	local techAnger = 0
	local aliveBossesMaxHealth = 0
	local playerAggression = 0
	local playerAggressionLevel = 0
	local playerAggressionEcoValue = 0
	local bossAngerAggressionLevel = 0
	local difficultyCounter = config.difficulty
	local waveParameters = {
		baseCooldown = 5,
		waveSizeMultiplier = 1,
		waveTimeMultiplier = 1,
		waveAirPercentage = 20,
		waveSpecialPercentage = 33,
		waveTechAnger = 0,
		airWave = {
			cooldown = mRandom(5,15),
		},
		specialWave = {
			cooldown = mRandom(5,15),
		},
		basicWave = {
			cooldown = mRandom(5,15),
		},
		smallWave = {
			cooldown = mRandom(5,15),
		},
		largerWave = {
			cooldown = mRandom(10,30),
		},
		hugeWave = {
			cooldown = mRandom(15,50),
		},
		epicWave = {
			cooldown = mRandom(20,75),
		},
		--frontbusters = {
		--	cooldown = mRandom(5,10),
		--	units = {},
		--	unitCount = 0,
		--}
		commanders = {
			waveCommanders = {},
			waveCommanderCount = 0,
			waveDecoyCommanders = {},
			waveDecoyCommanderCount = 0,
		},
		lastBackupSquadSpawnFrame = 0,
	}
	local squadSpawnOptions = config.squadSpawnOptionsTable
	--local miniBossCooldown = 0
	local firstSpawn = true
	local fullySpawned = false
	local spawnRetries = 0
	local spawnRetryTimeDiv = 20
	local spawnAreaMultiplier = 2
	local gameOver = nil
	local humanTeams = {}
	local spawnQueue = {}
	local deathQueue = {}
	local bossResistance = {}
	local bossIDs = {}
	local bosses = {resistances = bossResistance, statuses = {}, playerDamages = {}}
	local scavTeamID = Spring.Utilities.GetScavTeamID()
	local scavAllyTeamID = Spring.Utilities.GetScavAllyTeamID()
	local lsx1, lsz1, lsx2, lsz2
	local burrows = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadPotentialTarget = {}
	local squadPotentialHighValueTarget = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local unitTeleportCooldown = {}
	capturableUnits = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = math.ceil(10*Spring.GetModOptions().scav_spawntimemult),
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = math.ceil(10*Spring.GetModOptions().scav_spawntimemult),
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}
	CommandersPopulation = 0
	DecoyCommandersPopulation = 0
	--FrontbusterPopulation = 0
	HumanTechLevel = 0

	--dynamic difficulty stuff
	local dynamicDifficulty
	local dynamicDifficultyClamped
	local peakScavPower
	local totalPlayerTeamPower

	--config calculateDifficultyMultiplier
	local lowerScavPowerRatio = 1/6
	local upperScavPowerRatio = 1/2
	local minDynamicDifficulty = 0.85
	local maxDynamicDifficulty = 1.05

	-- Targeting system rework
	local useEcoTargeting = Spring.GetModOptions().scav_targeting_rework == "1" or Spring.GetModOptions().scav_targeting_rework == true
	local targetingContext = nil
	local lastSquadRebalanceFrame = 0
	local squadRebalanceInterval = 10 * Game.gameSpeed -- 10 seconds

	--[[
		* damageEfficiencyAreas set to 0 for temporarily disabling it until it is tested.
		* eco and tech weights are set to try to mimic the behavior implemented for raptors where ecoValue is multiplied by tech level.
			In raptors tech level is afaik meant to counter-act the relative low count in high eco buildings but also as a way to detect players that are ahead of the curve in eco,
			or will be because of the tech level achieved.
		* evenPlayerSpread is untested but is meant to balance between challenging good players (low value) and evening out the workload between players (high value).
		* unitRandom is set to 0 for temporarily disabling it until it is tested.
	--]]
	local scavTargetingWeights = {
		damageEfficiencyAreas = 0,
		eco = 0.7,
		evenPlayerSpread = 0.3,
		tech = 0.5,
		unitRandom = 0,
	}

	--------------------------------------------------------------------------------
	-- Teams
	--------------------------------------------------------------------------------

	local teams = GetTeamList()
	for _,teamID in ipairs(teams) do
		if teamID ~= scavTeamID then
			humanTeams[teamID] = true
		end
	end

	local gaiaTeamID = GetGaiaTeamID()
	if not scavTeamID then
		scavTeamID = gaiaTeamID
		scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID))
	end

	humanTeams[gaiaTeamID] = nil

	-- Initialize targeting system if rework is enabled
	if useEcoTargeting then
		targetingContext = PveTargeting.Initialize(scavTeamID, scavAllyTeamID, {
			gadgetWeights = scavTargetingWeights
		})
	end

	function PutScavAlliesInScavTeam(n)
		local players = Spring.GetPlayerList()
		for i = 1,#players do
			local player = players[i]
			local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
			if allyTeamID == scavAllyTeamID and (not spectator) then
				Spring.AssignPlayerToTeam(player, scavTeamID)
				local units = GetTeamUnits(teamID)
				scavteamhasplayers = true
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
				end
				Spring.KillTeam(teamID)
			end
		end

		local scavAllies = Spring.GetTeamList(scavAllyTeamID)
		for i = 1,#scavAllies do
			local _,_,_,AI = Spring.GetTeamInfo(scavAllies[i])
			local LuaAI = Spring.GetTeamLuaAI(scavAllies[i])
			if (AI or LuaAI) and scavAllies[i] ~= scavTeamID then
				local units = GetTeamUnits(scavAllies[i])
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(scavAllies[i])
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Utility
	--

	function SetToList(set)
		local list = {}
		local count = 0
		for k in pairs(set) do
			count = count + 1
			list[count] = k
		end
		return list
	end

	function SetCount(set)
		if set.count then
			return set.count
		end
		local count = 0
		for k in pairs(set) do
			count = count + 1
		end
		return count
	end

	function getRandomMapPos()
		local x = mRandom(16, MAPSIZEX - 16)
		local z = mRandom(16, MAPSIZEZ - 16)
		local y = GetGroundHeight(x, z)
		return { x = x, y = y, z = z }
	end

	function getRandomEnemyPos()

		if useEcoTargeting and targetingContext then
			local targetPos = PveTargeting.GetRandomTargetPosition(targetingContext, {
				positionSpread = 32,
				targetType = nil
			})

			if targetPos and targetPos.target then
				return {x = targetPos.x, y = targetPos.y, z = targetPos.z}, targetPos.target.unitID
			elseif targetPos then
				return {x = targetPos.x, y = targetPos.y, z = targetPos.z}, nil
			end
		end

		local loops = 0
		local targetCount = SetCount(squadPotentialTarget)
		local highValueTargetCount = SetCount(squadPotentialHighValueTarget)
		local pos = {}
		local pickedTarget = nil
		local highValueTargetPickChance = math.min(0.75, highValueTargetCount*0.15)
		repeat
			loops = loops + 1
			if highValueTargetCount > 0 and mRandom() <= highValueTargetPickChance then
				for target in pairs(squadPotentialHighValueTarget) do
					if mRandom(1,highValueTargetCount) == 1 then
						if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
							local x,y,z = Spring.GetUnitPosition(target)
							pos = {x = x+mRandom(-32,32), y = y, z = z+mRandom(-32,32)}
							pickedTarget = target
							break
						end
					end
				end
			else
				for target in pairs(squadPotentialTarget) do
					if mRandom(1,targetCount) == 1 then
						if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
							local x,y,z = Spring.GetUnitPosition(target)
							pos = {x = x+mRandom(-32,32), y = y, z = z+mRandom(-32,32)}
							pickedTarget = target
							break
						end
					end
				end
			end

		until pos.x or loops >= 10

		if not pos.x then
			pos = getRandomMapPos()
		end

		return pos, pickedTarget
	end

	function setScavXP(unitID)
		local maxXP = config.maxXP
		local bossAnger = bossAnger or 0
		local xp = mRandom(0, math.ceil((bossAnger*0.01) * maxXP * 1000))*0.001
		SetUnitExperience(unitID, xp)
		return xp
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Difficulty
    --

	local maxBurrows = ((config.maxBurrows*(1-config.scavPerPlayerMultiplier))+(config.maxBurrows*config.scavPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8)))*config.scavSpawnMultiplier
	local bossTime = (config.bossTime + config.gracePeriod)
	if config.difficulty == config.difficulties.survival then
		bossTime = math.ceil(bossTime*0.5)
	end
	local maxWaveSize = ((config.maxScavs*(1-config.scavPerPlayerMultiplier))+(config.maxScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
	local minWaveSize = ((config.minScavs*(1-config.scavPerPlayerMultiplier))+(config.minScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
	local currentMaxWaveSize = minWaveSize
	local endlessLoopCounter = 1
	function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		bossAnger = 0  -- reenable scav spawning
		techAnger = 0
		waveParameters.waveTechAnger = 0
		playerAggression = 0
		bossAngerAggressionLevel = 0
		pastFirstBoss = true
		nSpawnedBosses = 0
		nKilledBosses = 0
		bossResistance = {}
		aliveBossesMaxHealth = 0
		bosses.resistances = bossResistance
		bosses.statuses = {}
		SetGameRulesParam("scavBossAnger", math.floor(bossAnger))
		SetGameRulesParam("scavTechAnger", math.floor(techAnger))
		local nextDifficulty
		difficultyCounter = difficultyCounter + 1
		endlessLoopCounter = endlessLoopCounter + 1
		if config.difficultyParameters[difficultyCounter] then
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.bossResistanceMult = nextDifficulty.bossResistanceMult
			config.damageMod = nextDifficulty.damageMod
			config.healthMod = nextDifficulty.healthMod
		else
			difficultyCounter = difficultyCounter - 1
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.scavSpawnMultiplier = config.scavSpawnMultiplier+1
			config.bossResistanceMult = config.bossResistanceMult+0.5
			config.damageMod = config.damageMod+0.25
			config.healthMod = config.healthMod+0.25
		end
		config.bossName = nextDifficulty.bossName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.turretSpawnRate = nextDifficulty.turretSpawnRate
		config.bossSpawnMult = nextDifficulty.bossSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxScavs = nextDifficulty.maxScavs
		config.minScavs = nextDifficulty.minScavs
		config.maxBurrows = nextDifficulty.maxBurrows
		config.maxXP = nextDifficulty.maxXP
		config.angerBonus = nextDifficulty.angerBonus
		config.bossTime = math.ceil(nextDifficulty.bossTime/endlessLoopCounter)

		bossTime = (config.bossTime + config.gracePeriod)
		maxBurrows = ((config.maxBurrows*(1-config.scavPerPlayerMultiplier))+(config.maxBurrows*config.scavPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8)))*config.scavSpawnMultiplier
		maxWaveSize = ((config.maxScavs*(1-config.scavPerPlayerMultiplier))+(config.maxScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
		minWaveSize = ((config.minScavs*(1-config.scavPerPlayerMultiplier))+(config.minScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
		config.scavSpawnRate = nextDifficulty.scavSpawnRate
		currentMaxWaveSize = minWaveSize
		SetGameRulesParam("ScavBossAngerGain_Base", 100/config.bossTime)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game Rules
	--

	SetGameRulesParam("scavBossTime", bossTime)
	SetGameRulesParam("scavBossAnger", math.floor(bossAnger))
	SetGameRulesParam("scavTechAnger", math.floor(techAnger))
	SetGameRulesParam("scavGracePeriod", config.gracePeriod)
	SetGameRulesParam("scavDifficulty", config.difficulty)
	SetGameRulesParam("ScavBossAngerGain_Base", 100/config.bossTime)
	SetGameRulesParam("ScavBossAngerGain_Aggression", 0)
	SetGameRulesParam("ScavBossAngerGain_Eco", 0)


	function scavEvent(type, num, tech)
		SendToUnsynced("ScavEvent", type, num, tech)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Spawn Dynamics
	--

	local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
	local ScavStartboxXMin, ScavStartboxZMin, ScavStartboxXMax, ScavStartboxZMax = EnemyLib.GetAdjustedStartBox(scavAllyTeamID, config.burrowSize*1.5)

	--[[

		-> table containing all squads
		squadsTable = {
			[1] = {
				squadRole = "assault"/"raid"
				squadUnits = {unitID, unitID, unitID}
				squadLife = numberOfWaves
			}
		}

		-> refference table to quickly check which unit is in which squad, and if it has a squad at all.
		unitSquadTable = {
			[unitID] = [squadID]
		}


	]]
	function squadManagerKillerLoop() -- Kills squads that have been alive for too long (most likely stuck somewhere on the map)
		--squadsTable
		for i = 1,#squadsTable do

			squadsTable[i].squadLife = squadsTable[i].squadLife - 1
			if squadsTable[i].squadLife < 3 and squadsTable[i].squadRegroupEnabled then
				squadsTable[i].squadRegroupEnabled = false
			end
			-- Spring.Echo("SquadLifeReport - SquadID: #".. i .. ", LifetimeRemaining: ".. squadsTable[i].squadLife)

			if squadsTable[i].squadLife == 0 then
				-- Spring.Echo("Life is 0, time to do some killing")
				if SetCount(squadsTable[i].squadUnits) > 0 and SetCount(burrows) > 2 then
					if squadsTable[i].squadBurrow and nSpawnedBosses == 0 then
						if Spring.GetUnitTeam(squadsTable[i].squadBurrow) == scavTeamID then
							Spring.DestroyUnit(squadsTable[i].squadBurrow, true, false)
						elseif Spring.GetUnitIsDead(squadsTable[i].squadBurrow) == false then
							squadsTable[i].squadBurrow = nil
						end
					end
					-- Spring.Echo("There are some units to kill, so let's kill them")
					-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
					local destroyQueue = {}
					for j, unitID in pairs(squadsTable[i].squadUnits) do
						if unitID then
							destroyQueue[#destroyQueue+1] = unitID
							-- Spring.Echo("Killing old unit. ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
						end
					end
					for j = 1,#destroyQueue do
						-- Spring.Echo("Destroying Unit. ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
						if Spring.GetUnitTeam(destroyQueue[j]) == scavTeamID then
							Spring.DestroyUnit(destroyQueue[j], true, false)
						end
					end
					destroyQueue = nil
					-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
				end
			end
		end
	end


	--or Spring.GetGameSeconds() <= config.gracePeriod
	function squadCommanderGiveOrders(squadID, targetx, targety, targetz)
		local units = squadsTable[squadID].squadUnits
		local role = squadsTable[squadID].squadRole
		if SetCount(units) > 0 and squadsTable[squadID].target and squadsTable[squadID].target.x then
			if squadsTable[squadID].squadRegroupEnabled then
				local xmin = 999999
				local xmax = 0
				local zmin = 999999
				local zmax = 0
				local xsum = 0
				local zsum = 0
				local count = 0
				for i, unitID in pairs(units) do
					if ValidUnitID(unitID) and not GetUnitIsDead(unitID) and not GetUnitNeutral(unitID) then
						local x,y,z = Spring.GetUnitPosition(unitID)
						if x < xmin then xmin = x end
						if z < zmin then zmin = z end
						if x > xmax then xmax = x end
						if z > zmax then zmax = z end
						xsum = xsum + x
						zsum = zsum + z
						count = count + 1
					end
				end
				-- Calculate average unit position
				if count > 0 then
					local xaverage = xsum/count
					local zaverage = zsum/count
					if xmin < xaverage-512 or xmax > xaverage+512 or zmin < zaverage-512 or zmax > zaverage+512 then
						targetx = xaverage
						targetz = zaverage
						targety = Spring.GetGroundHeight(targetx, targetz)
						role = "raid"
						squadsTable[squadID].squadNeedsRegroup = true
					else
						squadsTable[squadID].squadNeedsRegroup = false
					end
				end
			else
				squadsTable[squadID].squadNeedsRegroup = false
			end


			if (squadsTable[squadID].squadNeedsRefresh) or (squadsTable[squadID].squadNeedsRegroup == true and squadsTable[squadID].squadRegrouping == false) or (squadsTable[squadID].squadNeedsRegroup == false and squadsTable[squadID].squadRegrouping == true) then
				for i, unitID in pairs(units) do
					if ValidUnitID(unitID) and not GetUnitIsDead(unitID) and not GetUnitNeutral(unitID) then
						-- Spring.Echo("GiveOrderToUnit #" .. i)
						if not unitCowardCooldown[unitID] then
							if config.scavBehaviours.ALWAYSMOVE[Spring.GetUnitDefID(unitID)] then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							elseif config.scavBehaviours.ALWAYSFIGHT[Spring.GetUnitDefID(unitID)] then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							elseif role == "assault" or role == "artillery" then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "raid" then
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "aircraft" then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {})
							elseif role == "kamikaze" then
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "healer" then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(unitID, CMD.REPAIR, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							end
						end
					end
				end
				squadsTable[squadID].squadNeedsRefresh = false
				if squadsTable[squadID].squadNeedsRegroup == true then
					squadsTable[squadID].squadRegrouping = true
				elseif squadsTable[squadID].squadNeedsRegroup == false then
					squadsTable[squadID].squadRegrouping = false
				end
			end
		end
	end

	function refreshSquad(squadID) -- Get new target for a squad
		local pos, pickedTarget = getRandomEnemyPos()
		--Spring.Echo(pos.x, pos.y, pos.z, pickedTarget)
		unitTargetPool[squadID] = pickedTarget
		squadsTable[squadID].target = pos
		-- Spring.MarkerAddPoint (squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z, "Squad #" .. squadID .. " target")
		squadsTable[squadID].squadNeedsRefresh = true
	end

	function createSquad(newSquad)
		-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
		-- Check if there's any free squadID to recycle
		local squadID = 0
		if #squadsTable == 0 then
			squadID = 1
			-- Spring.Echo("First squad, #".. squadID)
		else
			for i = 1,#squadsTable do
				-- Spring.Echo("Attempt to recycle squad #" .. i .. ". Containing " .. SetCount(squadsTable[i].squadUnits) .. " units.")
				if SetCount(squadsTable[i].squadUnits) == 0 then -- Yes, we found one empty squad to recycle
					squadID = i
					-- Spring.Echo("Recycled squad, #".. squadID)
					break
				elseif i == #squadsTable then -- No, there's no empty squad, we need to create new one
					squadID = i+1
					-- Spring.Echo("Created new squad, #".. squadID)
				end
			end
		end

		if squadID ~= 0 then -- If it's 0 then we f***** up somewhere
			local role = "assault"
			if not newSquad.role then
				if mRandom(0,100) <= 60 then
					role = "raid"
				end
			else
				role = newSquad.role
			end
			if not newSquad.life then
				newSquad.life = math.ceil(10*Spring.GetModOptions().scav_spawntimemult)
			end


			squadsTable[squadID] = {
				squadUnits = newSquad.units,
				squadLife = newSquad.life,
				squadRole = role,
				squadRegroupEnabled = newSquad.regroupenabled,
				squadRegrouping = newSquad.regrouping,
				squadNeedsRegroup = newSquad.needsregroup,
				squadNeedsRefresh = newSquad.needsrefresh,
				squadBurrow = newSquad.burrow,
			}

			-- Spring.Echo("Created Scav Squad, containing " .. #squadsTable[squadID].squadUnits .. " units!")
			-- Spring.Echo("Role: " .. squadsTable[squadID].squadRole)
			-- Spring.Echo("Lifetime: " .. squadsTable[squadID].squadLife)
			for i = 1,SetCount(squadsTable[squadID].squadUnits) do
				local unitID = squadsTable[squadID].squadUnits[i]
				unitSquadTable[unitID] = squadID
				-- Spring.Echo("#".. i ..", ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
			end
			refreshSquad(squadID)
		else
			-- Spring.Echo("Failed to create new squad, something went wrong")
		end
		squadCreationQueue = table.copy(squadCreationQueueDefaults)
		return squadID
		-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
	end

	function manageAllSquads() -- Get new target for all squads that need it
		for i = 1,#squadsTable do
			if mRandom(1,100) == 1 then
				local hasTarget = false
				for squad, target in pairs(unitTargetPool) do
					if i == squad then
						hasTarget = true
						break
					end
				end
				if not hasTarget then
					refreshSquad(i)
				end
			end
		end
	end

	function distributeDistanceSquadTargets()
		if not useEcoTargeting or not targetingContext then
			return
		end

		-- Build squad data for the generic redistribution function
		local squadData = {}
		for i = 1, #squadsTable do
			local squad = squadsTable[i]
			if squad and SetCount(squad.squadUnits) > 0 and squad.target and squad.target.x then
				-- Calculate squad center position
				local sumX, sumY, sumZ = 0, 0, 0
				local validUnits = 0

				for _, unitID in pairs(squad.squadUnits) do
					if ValidUnitID(unitID) and not GetUnitIsDead(unitID) then
						local x, y, z = Spring.GetUnitPosition(unitID)
						if x then
							sumX = sumX + x
							sumY = sumY + y
							sumZ = sumZ + z
							validUnits = validUnits + 1
						end
					end
				end

				if validUnits > 0 then
					squadData[#squadData + 1] = {
						squadID = i,
						x = sumX / validUnits,
						y = sumY / validUnits,
						z = sumZ / validUnits,
						currentTarget = {
							x = squad.target.x,
							y = squad.target.y,
							z = squad.target.z,
							unitID = unitTargetPool[i] -- Store original unit ID if available
						},
						unitCount = validUnits,
						role = squad.squadRole
					}
				end
			end
		end

		if #squadData == 0 then
			return
		end

		local assignments = PveTargeting.RedistributeSquadTargets(squadData, {
			allowMultipleUnitsPerTarget = false, -- Each target should only be assigned to one squad for better distribution
			maxDistance = math.huge -- Don't limit distance since these are existing targets
		})

		local assignedCount = 0
		for squadID, assignment in pairs(assignments) do
			if squadsTable[squadID] and assignment.target then
				squadsTable[squadID].target = {
					x = assignment.target.x,
					y = assignment.target.y,
					z = assignment.target.z
				}
				squadCommanderGiveOrders(squadID, squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z)

				-- Restore original unit ID if available
				if assignment.metadata and assignment.metadata.unitID then
					unitTargetPool[squadID] = assignment.metadata.unitID
				end

				assignedCount = assignedCount + 1
			end
		end
	end


	function getScavSpawnLoc(burrowID, size)
		local x, y, z
		local bx, by, bz = GetUnitPosition(burrowID)
		if not bx or not bz then
			return false
		end

		local tries = 0
		local s = config.spawnSquare

		repeat
			x = mRandom(bx - s, bx + s)
			z = mRandom(bz - s, bz + s)
			s = s + config.spawnSquareIncrement
			tries = tries + 1
			if x >= MAPSIZEX then
				x = (MAPSIZEX - mRandom(1, 40))
			elseif (x <= 0) then
				x = mRandom(1, 40)
			end
			if z >= MAPSIZEZ then
				z = (MAPSIZEZ - mRandom(1, 40))
			elseif (z <= 0) then
				z = mRandom(1, 40)
			end
		until (TestBuildOrder(size, x, by, z, 1) == 2 and not GetGroundBlocked(x, z)) or (tries > maxTries)

		y = GetGroundHeight(x, z)
		return x, y, z

	end

	function getNearestScavBeacon(tx, ty, tz)
		local nearestBurrow = nil
		local nearestDistance = 999999
		for burrowID, burrow in pairs(burrows) do
			local bx, by, bz = GetUnitPosition(burrowID)
			if bx and by and bz and burrow.lastBackupSpawn + 1800 <= Spring.GetGameFrame() then
				local distance = math.ceil((math.abs(tx-bx) + math.abs(ty-by) + math.abs(tz-bz))*0.5)
				if distance < nearestDistance then
					nearestDistance = distance
					nearestBurrow = burrowID
				end
			end
		end
		return nearestBurrow, nearestDistance
	end

	function SpawnRandomOffWaveSquad(burrowID, scavType, count)
		if gameOver then
			return
		end

		waveParameters.commanders.waveCommanderCount = 0
		waveParameters.commanders.waveDecoyCommanderCount = 0

		local squadCounter = 0
		if scavType then
			if not count then count = 1 end
			if UnitDefNames[scavType] then
				for j = 1, count, 1 do
					if mRandom() <= config.spawnChance or j == 1 then
						squadCounter = squadCounter + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = scavType, team = scavTeamID, squadID = squadCounter })
					end
				end
			elseif not UnitDefNames[scavType] then
				Spring.Echo("[ERROR] Invalid Scav Unit Name", scavType)
			else
				Spring.Echo("[ERROR] Invalid Scav Squad", scavType)
			end
		else
			squadCounter = 0
			local squad
			local airRandom = mRandom(1,100)
			local specialRandom = mRandom(1,100)
			local burrowX, burrowY, burrowZ = Spring.GetUnitPosition(burrowID)
			local surface = positionCheckLibrary.LandOrSeaCheck(burrowX, burrowY, burrowZ, config.burrowSize)

			if waveParameters.waveTechAnger > config.airStartAnger and airRandom <= waveParameters.waveAirPercentage then
				for _ = 1,1000 do
					local potentialSquad
					if specialRandom <= waveParameters.waveSpecialPercentage then
						if surface == "land" then
							potentialSquad = squadSpawnOptions.specialAirLand[mRandom(1, #squadSpawnOptions.specialAirLand)]
						elseif surface == "sea" then
							potentialSquad = squadSpawnOptions.specialAirSea[mRandom(1, #squadSpawnOptions.specialAirSea)]
						end
					else
						if surface == "land" then
							potentialSquad = squadSpawnOptions.basicAirLand[mRandom(1, #squadSpawnOptions.basicAirLand)]
						elseif surface == "sea" then
							potentialSquad = squadSpawnOptions.basicAirSea[mRandom(1, #squadSpawnOptions.basicAirSea)]
						end
					end
					if potentialSquad then
						if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
						or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
							squad = potentialSquad
							break
						end
					end
				end
			else
				for _ = 1,1000 do
					local potentialSquad
					if specialRandom <= waveParameters.waveSpecialPercentage then
						if surface == "land" then
							potentialSquad = squadSpawnOptions.specialLand[mRandom(1, #squadSpawnOptions.specialLand)]
						elseif surface == "sea" then
							potentialSquad = squadSpawnOptions.specialSea[mRandom(1, #squadSpawnOptions.specialSea)]
						end
						if potentialSquad then
							if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
							or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
								squad = potentialSquad
								break
							end
						end
					else
						if surface == "land" then
							potentialSquad = squadSpawnOptions.basicLand[mRandom(1, #squadSpawnOptions.basicLand)]
						elseif surface == "sea" then
							potentialSquad = squadSpawnOptions.basicSea[mRandom(1, #squadSpawnOptions.basicSea)]
						end
						if potentialSquad then
							if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
							or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
								squad = potentialSquad
								break
							end
						end
					end
				end
			end
			if squad then
				for _, squadTable in pairs(squad.units) do
					local unitNumber = squadTable.count
					local scavName = squadTable.unit
					if UnitDefNames[scavName] and unitNumber and unitNumber > 0 then
						for j = 1, unitNumber, 1 do
							if mRandom() <= config.spawnChance or j == 1 then
								squadCounter = squadCounter + 1
								table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
							end
						end
					elseif not UnitDefNames[scavName] then
						Spring.Echo("[ERROR] Invalid Scav Unit Name", scavName)
					else
						Spring.Echo("[ERROR] Invalid Scav Squad", scavName)
					end
				end
			end
			if mRandom() <= config.spawnChance then
				squad = nil
				squadCounter = 0
				for _ = 1,1000 do
					local potentialSquad
					if surface == "land" then
						potentialSquad = squadSpawnOptions.healerLand[mRandom(1, #squadSpawnOptions.healerLand)]
					elseif surface == "sea" then
						potentialSquad = squadSpawnOptions.healerSea[mRandom(1, #squadSpawnOptions.healerSea)]
					end
					if potentialSquad then
						if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger) then -- Super Squad
							squad = potentialSquad
							break
						end
					end
				end
				if squad then
					for _, squadTable in pairs(squad.units) do
						local unitNumber = squadTable.count
						local scavName = squadTable.unit
						if UnitDefNames[scavName] and unitNumber and unitNumber > 0 then
							for j = 1, unitNumber, 1 do
								if mRandom() <= config.spawnChance or j == 1 then
									squadCounter = squadCounter + 1
									table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
								end
							end
						elseif not UnitDefNames[scavName] then
							Spring.Echo("[ERROR] Invalid Scav Unit Name", scavName)
						else
							Spring.Echo("[ERROR] Invalid Scav Squad", scavName)
						end
					end
				end
			end
			if mRandom() <= 0.5 then
				for name, data in pairs(squadSpawnOptions.commanders) do
					if mRandom() <= config.spawnChance and mRandom(1, SetCount(squadSpawnOptions.commanders)) == 1 and (not waveParameters.commanders.waveCommanders[name]) and data.minAnger <= waveParameters.waveTechAnger and data.maxAnger >= waveParameters.waveTechAnger and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[name].id) < data.maxAlive and CommandersPopulation+waveParameters.commanders.waveCommanderCount < SetCount(humanTeams)*(waveParameters.waveTechAnger*0.005) then
						waveParameters.commanders.waveCommanders[name] = true
						waveParameters.commanders.waveCommanderCount = waveParameters.commanders.waveCommanderCount + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = name, team = scavTeamID, squadID = 1 })
						break
					end
				end
			else
				for name, data in pairs(squadSpawnOptions.decoyCommanders) do
					if mRandom() <= config.spawnChance and mRandom(1, SetCount(squadSpawnOptions.decoyCommanders)) == 1 and (not waveParameters.commanders.waveDecoyCommanders[name]) and data.minAnger <= waveParameters.waveTechAnger and data.maxAnger >= waveParameters.waveTechAnger and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[name].id) < data.maxAlive and DecoyCommandersPopulation+waveParameters.commanders.waveDecoyCommanderCount < SetCount(humanTeams)*(waveParameters.waveTechAnger*0.005) then
						waveParameters.commanders.waveDecoyCommanders[name] = true
						waveParameters.commanders.waveDecoyCommanderCount = waveParameters.commanders.waveDecoyCommanderCount + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = name, team = scavTeamID, squadID = 1 })
						break
					end
				end
			end
		end
		return squadCounter
	end

	function SetupBurrow(unitID, x, y, z)
		burrows[unitID] = {
			lastBackupSpawn = Spring.GetGameFrame()
		}
		SetUnitBlocking(unitID, false, false)
		setScavXP(unitID)
	end

	function SpawnBurrow(number)
		local foundLocation = false
		for i = 1, (number or 1) do
			local canSpawnBurrow = false
			local spread = config.burrowSize*1.5
			local spawnPosX, spawnPosY, spawnPosZ

			if config.burrowSpawnType ~= "avoid" then
				if config.useScum and (canSpawnBurrow and GetGameSeconds() >= config.gracePeriod) then -- Attempt #1, find position in creep/scum (skipped if creep is disabled)
					if spread < MAPSIZEX - spread and spread < MAPSIZEZ - spread then
						for _ = 1,1000 do
							spawnPosX = mRandom(spread, MAPSIZEX - spread)
							spawnPosZ = mRandom(spread, MAPSIZEZ - spread)
							spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
							canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
							end
							if canSpawnBurrow then
								canSpawnBurrow = GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
							end
							if canSpawnBurrow then -- this is for case where they have no startbox. We don't want them spawning on top of your stuff.
								canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
							end
							if canSpawnBurrow then
								break
							end
						end
					end
				end

				if (not canSpawnBurrow) then -- Attempt #3 Find some good position in Spawnbox (not Startbox)
					if lsx1 + spread < lsx2 - spread and lsz1 + spread < lsz2 - spread then
						for _ = 1,1000 do
							spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
							spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
							spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
							canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
							end
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
							end
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, false, false)
							end
							if canSpawnBurrow then
								break
							end
						end
					end
				end

				if (not canSpawnBurrow) then -- Attempt #2 Force spawn in Startbox, ignore any kind of player vision
					if ScavStartboxXMin + spread < ScavStartboxXMax - spread and ScavStartboxZMin + spread < ScavStartboxZMax - spread then
						for _ = 1,100 do
							spawnPosX = mRandom(ScavStartboxXMin + spread, ScavStartboxXMax - spread)
							spawnPosZ = mRandom(ScavStartboxZMin + spread, ScavStartboxZMax - spread)
							spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
							canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
							end
							if canSpawnBurrow and noScavStartbox then -- this is for case where they have no startbox. We don't want them spawning on top of your stuff.
								canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
							end
							if canSpawnBurrow then
								break
							end
						end
					end
				end

			else -- Avoid Players burrow setup. Spawns anywhere that isn't in player sensor range.

				if lsx1 + spread < lsx2 - spread and lsz1 + spread < lsz2 - spread then
					for _ = 1,100 do  -- Attempt #1 Avoid all sensors
						spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
						spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
						spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
						canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
						if canSpawnBurrow then
							canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
						end
						if canSpawnBurrow then
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
						end
						if canSpawnBurrow then
							break
						end
					end

					if (not canSpawnBurrow) then -- Attempt #2 Don't avoid radars
						for _ = 1,100 do
							spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
							spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
							spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
							canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
							end
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, false)
							end
							if canSpawnBurrow then
								break
							end
						end
					end

					if (not canSpawnBurrow) then -- Attempt #3 Only avoid LoS
						for _ = 1,100 do
							spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
							spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
							spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
							canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
							end
							if canSpawnBurrow then
								canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, false, false)
							end
							if canSpawnBurrow then
								break
							end
						end
					end
				end
			end

			if canSpawnBurrow and (positionCheckLibrary.LandOrSeaCheck(spawnPosX, spawnPosY, spawnPosZ, config.burrowSize) == "mixed" or positionCheckLibrary.LandOrSeaCheck(spawnPosX, spawnPosY, spawnPosZ, config.burrowSize) == "death") then
				canSpawnBurrow = false
			end

			if (canSpawnBurrow and GetGameSeconds() < config.gracePeriod*0.9) then -- Don't spawn new burrows in existing creep during grace period - Force them to spread as much as they can..... AT LEAST THAT'S HOW IT'S SUPPOSED TO WORK, lol.
				canSpawnBurrow = not GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
			end

			if canSpawnBurrow then
				foundLocation = true
				for name,data in pairs(config.burrowUnitsList) do
					if math.random() <= config.spawnChance and data.minAnger < math.max(1, techAnger) and data.maxAnger > math.max(1, techAnger) then
						local burrowID = CreateUnit(name, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), scavTeamID)
						if burrowID then
							SetupBurrow(burrowID, spawnPosX, spawnPosY, spawnPosZ)
							Spring.SpawnCEG("commander-spawn-alwaysvisible", spawnPosX, spawnPosY, spawnPosZ, 0, 0, 0)
							Spring.PlaySoundFile("commanderspawn-mono", 0.15, spawnPosX, spawnPosY, spawnPosZ, 0, 0, 0, "sfx")
							GG.ComSpawnDefoliate(spawnPosX, spawnPosY, spawnPosZ)
							break
						end
					end
				end
			else
				timeOfLastSpawn = GetGameSeconds()
				--playerAggression = playerAggression + (config.angerBonus*(bossAnger*0.01))
			end
		end
		return foundLocation
	end

	function updateBossLife()
		local totalHealth = 0
		local totalMaxHealth = 0
		aliveBossesMaxHealth = 0
		for bossID, status in pairs(bosses.statuses) do
			if status.isDead then
				totalMaxHealth = totalMaxHealth + status.maxHealth
			else
				local health, maxHealth = GetUnitHealth(bossID)
				table.mergeInPlace(status, {health = health, maxHealth = maxHealth})

				totalHealth = totalHealth + health
				aliveBossesMaxHealth = aliveBossesMaxHealth + maxHealth
				totalMaxHealth = totalMaxHealth + maxHealth
			end
		end

		SetGameRulesParam("scavBossHealth", math.floor(0.5 + ((totalHealth / totalMaxHealth) * 100)))
		SetGameRulesParam("pveBossInfo", Json.encode(bosses))
	end

	function SpawnBoss()
		local bestScore = 0
		local bestBurrowID
		local sx, sy, sz
		for burrowID, _ in pairs(burrows) do
			-- Try to spawn the boss at the 'best' burrow
			local x, y, z = GetUnitPosition(burrowID)
			if x and y and z and not bossIDs[burrowID] then
				local score = 0
				score = mRandom(1,1000)
				if score > bestScore then
					bestScore = score
					bestBurrowID = burrowID
					sx = x
					sy = y
					sz = z
				end
			end
		end

		if sx and sy and sz then
			if bestBurrowID then
				Spring.DestroyUnit(bestBurrowID, true, false)
			end
			return CreateUnit(config.bossName, sx, sy, sz, mRandom(0,3), scavTeamID), bestBurrowID
		end

		local x, z, y
		local tries = 0
		local canSpawnBoss = false
		repeat
			x = mRandom(ScavStartboxXMin, ScavStartboxXMax)
			z = mRandom(ScavStartboxZMin, ScavStartboxZMax)
			y = GetGroundHeight(x, z)
			tries = tries + 1
			canSpawnBoss = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)

			if canSpawnBoss then
				if tries < maxTries*3 then
					canSpawnBoss = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, scavAllyTeamID, true, true, true)
				else
					canSpawnBoss = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, scavAllyTeamID, true, true, false)
				end
			end

			if canSpawnBoss then
				canSpawnBoss = positionCheckLibrary.OccupancyCheck(x, y, z, config.burrowSize*0.25)
			end

			if canSpawnBoss then
				canSpawnBoss = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
			end

		until (canSpawnBoss == true or tries >= maxTries * 6)

		if canSpawnBoss then
			return CreateUnit(config.bossName, x, y, z, mRandom(0,3), scavTeamID)
		else
			for i = 1,100 do
				x = mRandom(ScavStartboxXMin, ScavStartboxXMax)
				z = mRandom(ScavStartboxZMin, ScavStartboxZMax)
				y = GetGroundHeight(x, z)

				canSpawnBoss = positionCheckLibrary.StartboxCheck(x, y, z, scavAllyTeamID)
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)
				end
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
				end
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
				end
				if canSpawnBoss then
					return CreateUnit(config.bossName, x, y, z, mRandom(0,3), scavTeamID)
				end
			end
		end
		return nil
	end

	local function calculateDifficultyMultiplier(peakScavPower, totalPlayerTeamPower)
		local ratio = peakScavPower / totalPlayerTeamPower
		if peakScavPower == 0 or peakScavPower == nil or totalPlayerTeamPower == 0  or totalPlayerTeamPower == nil then
			return
		end
		if ratio >= upperScavPowerRatio then
			dynamicDifficulty = 0
		elseif ratio <= lowerScavPowerRatio then
			dynamicDifficulty = 1
		else
			dynamicDifficulty = (upperScavPowerRatio - ratio) / (upperScavPowerRatio - lowerScavPowerRatio)
		end

		dynamicDifficultyClamped = minDynamicDifficulty + (dynamicDifficulty * (maxDynamicDifficulty - minDynamicDifficulty))
	end

	function Wave()

		if gameOver then
			return
		end

		peakScavPower = GG.PowerLib.TeamPeakPower(scavTeamID)
		totalPlayerTeamPower = GG.PowerLib.TotalPlayerTeamsPower()
		calculateDifficultyMultiplier(peakScavPower, totalPlayerTeamPower)
		Spring.Log("Dynamic Difficulty", LOG.INFO, 'Scavengers dynamicDifficultyClamped:  ' .. tostring(dynamicDifficultyClamped))
		squadManagerKillerLoop()

		waveParameters.baseCooldown = waveParameters.baseCooldown - 1
		waveParameters.airWave.cooldown = waveParameters.airWave.cooldown - 1
		waveParameters.basicWave.cooldown = waveParameters.basicWave.cooldown - 1
		waveParameters.specialWave.cooldown = waveParameters.specialWave.cooldown - 1
		waveParameters.smallWave.cooldown = waveParameters.smallWave.cooldown - 1
		waveParameters.largerWave.cooldown = waveParameters.largerWave.cooldown - 1
		waveParameters.hugeWave.cooldown = waveParameters.hugeWave.cooldown - 1
		waveParameters.epicWave.cooldown = waveParameters.epicWave.cooldown - 1
		--waveParameters.frontbusters.cooldown = waveParameters.frontbusters.cooldown - 1

		waveParameters.waveSpecialPercentage = mRandom(5,50)
		waveParameters.waveAirPercentage = mRandom(10,25)

		waveParameters.waveSizeMultiplier = 1
		waveParameters.waveTimeMultiplier = 1

		--waveParameters.frontbusters.units = {}
		--waveParameters.frontbusters.unitCount = 0

		waveParameters.commanders.waveCommanders = {}
		waveParameters.commanders.waveCommanderCount = 0

		waveParameters.commanders.waveDecoyCommanders = {}
		waveParameters.commanders.waveDecoyCommanderCount = 0



		if waveParameters.baseCooldown <= 0 or math.max(1, techAnger) < config.tierConfiguration[2].minAnger then
			-- special waves
			if math.max(1, techAnger) < config.tierConfiguration[2].minAnger then

				waveParameters.waveSizeMultiplier = math.min(waveParameters.waveSizeMultiplier, math.max(1, techAnger)*0.1)
				waveParameters.waveTimeMultiplier = math.min(waveParameters.waveTimeMultiplier, math.max(1, techAnger)*0.1)

				waveParameters.waveAirPercentage = 20
				waveParameters.waveSpecialPercentage = 0

			elseif waveParameters.waveTechAnger > config.airStartAnger and waveParameters.airWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.airWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 0
				waveParameters.waveAirPercentage = 50
				waveParameters.waveSizeMultiplier = 2
				waveParameters.waveTimeMultiplier = 0.5

			elseif waveParameters.specialWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.specialWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 50
				waveParameters.waveAirPercentage = 0

			elseif waveParameters.basicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.basicWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 0
				waveParameters.waveAirPercentage = 0

			elseif waveParameters.smallWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.smallWave.cooldown = mRandom(0,10)

				waveParameters.waveSizeMultiplier = 0.5
				waveParameters.waveTimeMultiplier = 0.5

			elseif waveParameters.largerWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.largerWave.cooldown = mRandom(0,25)

				waveParameters.waveSizeMultiplier = 1.5
				waveParameters.waveTimeMultiplier = 1.25

				waveParameters.waveAirPercentage = mRandom(5,20)
				waveParameters.waveSpecialPercentage = mRandom(5,40)

			elseif waveParameters.hugeWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.hugeWave.cooldown = mRandom(0,50)

				waveParameters.waveSizeMultiplier = 3
				waveParameters.waveTimeMultiplier = 1.5

				waveParameters.waveAirPercentage = mRandom(5,15)
				waveParameters.waveSpecialPercentage = mRandom(5,25)

			elseif waveParameters.epicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.epicWave.cooldown = mRandom(0,100)

				waveParameters.waveSizeMultiplier = 5
				waveParameters.waveTimeMultiplier = 2.5

				waveParameters.waveAirPercentage = mRandom(5,10)
				waveParameters.waveSpecialPercentage = mRandom(5,10)

			end
		end

		local cCount = 0
		local loopCounter = 0
		local squadCounter = 0

		waveParameters.waveTechAnger = math.min(999, techAnger*dynamicDifficultyClamped)
		waveParameters.waveSizeMultiplier = waveParameters.waveSizeMultiplier*dynamicDifficultyClamped

		repeat
			loopCounter = loopCounter + 1
			for burrowID in pairs(burrows) do
				if mRandom() <= config.spawnChance then
					squadCounter = 0
					local airRandom = mRandom(1,100)
					local specialRandom = mRandom(1,100)
					local squad
					local burrowX, burrowY, burrowZ = Spring.GetUnitPosition(burrowID)
					local surface = positionCheckLibrary.LandOrSeaCheck(burrowX, burrowY, burrowZ, config.burrowSize)
					if waveParameters.waveTechAnger > config.airStartAnger and airRandom <= waveParameters.waveAirPercentage then
						for _ = 1,1000 do
							local potentialSquad
							if specialRandom <= waveParameters.waveSpecialPercentage then
								if surface == "land" then
									potentialSquad = squadSpawnOptions.specialAirLand[mRandom(1, #squadSpawnOptions.specialAirLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.specialAirSea[mRandom(1, #squadSpawnOptions.specialAirSea)]
								end
							else
								if surface == "land" then
									potentialSquad = squadSpawnOptions.basicAirLand[mRandom(1, #squadSpawnOptions.basicAirLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.basicAirSea[mRandom(1, #squadSpawnOptions.basicAirSea)]
								end
							end
							if potentialSquad then
								if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
								or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							end
						end
					else
						for _ = 1,1000 do
							local potentialSquad
							if specialRandom <= waveParameters.waveSpecialPercentage then
								if surface == "land" then
									potentialSquad = squadSpawnOptions.specialLand[mRandom(1, #squadSpawnOptions.specialLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.specialSea[mRandom(1, #squadSpawnOptions.specialSea)]
								end
								if potentialSquad then
									if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
									or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
										squad = potentialSquad
										break
									end
								end
							else
								if surface == "land" then
									potentialSquad = squadSpawnOptions.basicLand[mRandom(1, #squadSpawnOptions.basicLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.basicSea[mRandom(1, #squadSpawnOptions.basicSea)]
								end
								if potentialSquad then
									if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger)
									or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= waveParameters.waveTechAnger and math.max(40, potentialSquad.maxAnger-30) >= waveParameters.waveTechAnger) then -- Super Squad
										squad = potentialSquad
										break
									end
								end
							end
						end
					end
					if squad then
						for _, squadTable in pairs(squad.units) do
							local unitNumber = squadTable.count
							local scavName = squadTable.unit
							if UnitDefNames[scavName] and unitNumber and unitNumber > 0 then
								for j = 1, unitNumber, 1 do
									if mRandom() <= config.spawnChance or j == 1 then
										squadCounter = squadCounter + 1
										table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
										cCount = cCount + 1
									end
								end
							elseif not UnitDefNames[scavName] then
								Spring.Echo("[ERROR] Invalid Scav Unit Name", scavName)
							else
								Spring.Echo("[ERROR] Invalid Scav Squad", scavName)
							end
						end
					end
					if mRandom() <= config.spawnChance and loopCounter == 1 then
						squad = nil
						squadCounter = 0
						for _ = 1,1000 do
							local potentialSquad
							if surface == "land" then
								potentialSquad = squadSpawnOptions.healerLand[mRandom(1, #squadSpawnOptions.healerLand)]
							elseif surface == "sea" then
								potentialSquad = squadSpawnOptions.healerSea[mRandom(1, #squadSpawnOptions.healerSea)]
							end
							if potentialSquad then
								if (potentialSquad.minAnger <= waveParameters.waveTechAnger and potentialSquad.maxAnger >= waveParameters.waveTechAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							end
						end
						if squad then
							for _, squadTable in pairs(squad.units) do
								local unitNumber = squadTable.count
								local scavName = squadTable.unit
								if UnitDefNames[scavName] and unitNumber and unitNumber > 0 then
									for j = 1, unitNumber, 1 do
										if mRandom() <= config.spawnChance or j == 1 then
											squadCounter = squadCounter + 1
											table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
											cCount = cCount + 1
										end
									end
								elseif not UnitDefNames[scavName] then
									Spring.Echo("[ERROR] Invalid Scav Unit Name", scavName)
								else
									Spring.Echo("[ERROR] Invalid Scav Squad", scavName)
								end
							end
						end
					end
					if mRandom() <= 0.5 then
						for name, data in pairs(squadSpawnOptions.commanders) do
							if mRandom() <= config.spawnChance and mRandom(1, SetCount(squadSpawnOptions.commanders)) == 1 and (not waveParameters.commanders.waveCommanders[name]) and data.minAnger <= waveParameters.waveTechAnger and data.maxAnger >= waveParameters.waveTechAnger and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[name].id) < data.maxAlive and CommandersPopulation+waveParameters.commanders.waveCommanderCount < SetCount(humanTeams)*(waveParameters.waveTechAnger*0.005) then
								waveParameters.commanders.waveCommanders[name] = true
								waveParameters.commanders.waveCommanderCount = waveParameters.commanders.waveCommanderCount + 1
								table.insert(spawnQueue, { burrow = burrowID, unitName = name, team = scavTeamID, squadID = 1 })
								cCount = cCount + 1
								break
							end
						end
					else
						for name, data in pairs(squadSpawnOptions.decoyCommanders) do
							if mRandom() <= config.spawnChance and mRandom(1, SetCount(squadSpawnOptions.decoyCommanders)) == 1 and (not waveParameters.commanders.waveDecoyCommanders[name]) and data.minAnger <= waveParameters.waveTechAnger and data.maxAnger >= waveParameters.waveTechAnger and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[name].id) < data.maxAlive and DecoyCommandersPopulation+waveParameters.commanders.waveDecoyCommanderCount < SetCount(humanTeams)*(waveParameters.waveTechAnger*0.005) then
								waveParameters.commanders.waveDecoyCommanders[name] = true
								waveParameters.commanders.waveDecoyCommanderCount = waveParameters.commanders.waveDecoyCommanderCount + 1
								table.insert(spawnQueue, { burrow = burrowID, unitName = name, team = scavTeamID, squadID = 1 })
								cCount = cCount + 1
								break
							end
						end
					end
					--if mRandom() <= config.spawnChance and waveParameters.frontbusters.cooldown <= 0 then
					--	for attempt = 1,10 do
					--		local squad = squadSpawnOptions.frontbusters[math.random(1, #squadSpawnOptions.frontbusters)]
					--		if squad and squad.surface and ((surface == "land" and squad.surface ~= "sea") or (surface == "sea" and squad.surface ~= "land")) then
					--			if mRandom() <= config.spawnChance and (not waveParameters.frontbusters.units[squad.name]) and squad.minAnger <= waveParameters.waveTechAnger and squad.maxAnger >= waveParameters.waveTechAnger and Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[squad.name].id) < squad.maxAlive and waveParameters.frontbusters.unitCount == 0 then
					--				for i = 1, math.ceil(squad.squadSize*config.spawnChance*((SetCount(humanTeams)*config.scavPerPlayerMultiplier)+(1-config.scavPerPlayerMultiplier))) do
					--					waveParameters.frontbusters.units[squad.name] = true
					--					waveParameters.frontbusters.unitCount = waveParameters.frontbusters.unitCount + 1
					--					table.insert(spawnQueue, { burrow = burrowID, unitName = squad.name, team = scavTeamID, squadID = 1, alwaysVisible = true })
					--					cCount = cCount + 1
					--				end
					--				waveParameters.frontbusters.cooldown = math.random(3,5)
					--				break
					--			end
					--		end
					--	end
					--end
				end
			end
		until (cCount > currentMaxWaveSize*waveParameters.waveSizeMultiplier or loopCounter >= 200*config.scavSpawnMultiplier)

		if config.useWaveMsg then
			scavEvent("wave", cCount)
		end

		return cCount
	end

	function spawnCreepStructure(unitDefName, unitSettings, spread)
		local canSpawnStructure = false
		spread = spread or 128
		local spawnPosX, spawnPosY, spawnPosZ

		if config.useScum then -- If creep/scum is enabled, only allow to spawn turrets on the creep
			if spread < MAPSIZEX - spread and spread < MAPSIZEZ - spread then
				for _ = 1,5 do
					spawnPosX = mRandom(spread, MAPSIZEX - spread)
					spawnPosZ = mRandom(spread, MAPSIZEZ - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnStructure then
						canSpawnStructure = GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
					end
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
					end
					if canSpawnStructure then
						break
					end
				end
			end
		else -- Otherwise use Scav LoS as creep with Players sensors being the safety zone
			for _ = 1,5 do
				spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
				spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
				spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
				canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				end
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
				end
				if canSpawnStructure then
					canSpawnStructure = not (positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, false, false)) -- we need to reverse result of this, because we want this to be true when pos is in LoS of Scav team, and the visibility check does the opposite.
				end
				if canSpawnStructure then
					break
				end
			end
		end
		if (unitSettings.surfaceType == "land" and spawnPosY <= 0) or (unitSettings.surfaceType == "sea" and spawnPosY > 0) then
			canSpawnStructure = false
		end

		if canSpawnStructure then
			local structureUnitID = Spring.CreateUnit(unitDefName, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), scavTeamID)
			if structureUnitID then
				SetUnitBlocking(structureUnitID, false, false)
				return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
			end
		end
	end

	function spawnCreepStructuresWave()
		for uName, uSettings in pairs(config.scavTurrets) do
			if not uSettings.maxBossAnger then uSettings.maxBossAnger = uSettings.minBossAnger + 100 end
			if uSettings.minBossAnger <= waveParameters.waveTechAnger and uSettings.maxBossAnger >= waveParameters.waveTechAnger then
				local numOfTurrets = (uSettings.spawnedPerWave*(1-config.scavPerPlayerMultiplier))+(uSettings.spawnedPerWave*config.scavPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8))
				local maxExisting = (uSettings.maxExisting*(1-config.scavPerPlayerMultiplier))+(uSettings.maxExisting*config.scavPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8))
				local maxAllowedToSpawn
				if waveParameters.waveTechAnger <= 100 then  -- i don't know how this works but it does. scales maximum amount of turrets allowed to spawn with techAnger.
					maxAllowedToSpawn = math.ceil(maxExisting*((waveParameters.waveTechAnger-uSettings.minBossAnger)/(math.min(100-uSettings.minBossAnger, uSettings.maxBossAnger-uSettings.minBossAnger))))
				else
					maxAllowedToSpawn = math.ceil(maxExisting*(waveParameters.waveTechAnger*0.01))
				end
				--Spring.Echo(uName,"MaxExisting",maxExisting,"MaxAllowed",maxAllowedToSpawn)
				for i = 1, math.ceil(numOfTurrets) do
					if mRandom() < config.spawnChance*math.min((GetGameSeconds()/config.gracePeriod),1) and UnitDefNames[uName] and (Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[uName].id) <= maxAllowedToSpawn) then
						if i <= numOfTurrets or math.random() <= numOfTurrets%1 then
							local attempts = 0
							local footprintX = UnitDefNames[uName].xsize -- why the fuck is this footprint *2??????
							local footprintZ = UnitDefNames[uName].zsize -- why the fuck is this footprint *2??????
							local footprintAvg = 128
							if footprintX and footprintZ then
								footprintAvg = ((footprintX+footprintZ))*4
							end
							repeat
								attempts = attempts + 1
								local turretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(uName, uSettings, footprintAvg+32)
								if turretUnitID then
									setScavXP(turretUnitID)
									if UnitDefNames[uName].isFactory then
										Spring.GiveOrderToUnit(turretUnitID, CMD.FIGHT, {spawnPosX + mRandom(-256,256), spawnPosY, spawnPosZ + mRandom(-256,256)}, {"meta"})
									else
										Spring.GiveOrderToUnit(turretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
									end
								end
							until turretUnitID or attempts > 10
						end
					end
				end
			end
		end
	end

	function SpawnMinions(unitID, unitDefID)
		local unitName = UnitDefs[unitDefID].name
		if config.scavMinions[unitName] then
			local minion = config.scavMinions[unitName][mRandom(1,#config.scavMinions[unitName])]
			SpawnRandomOffWaveSquad(unitID, minion, 4)
		end
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------
	local createUnitQueue = {}
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == scavTeamID then
			local _, maxH = Spring.GetUnitHealth(unitID)
			Spring.SetUnitHealth(unitID, maxH)
			local x,y,z = Spring.GetUnitPosition(unitID)
			if not UnitDefs[unitDefID].customParams.isscavenger then
				--Spring.Echo(UnitDefs[unitDefID].name, "unit created swap", UnitDefs[unitDefID].customParams.scav_swap_override_created)
				if not UnitDefs[unitDefID].customParams.scav_swap_override_created then
					if UnitDefs[unitDefID] and UnitDefs[unitDefID].name and UnitDefNames[UnitDefs[unitDefID].name .. "_scav"] then
						createUnitQueue[#createUnitQueue+1] = {UnitDefs[unitDefID].name .. "_scav", x, y, z, Spring.GetUnitBuildFacing(unitID) or 0, scavTeamID}
						Spring.DestroyUnit(unitID, true, true)
					end
				elseif UnitDefs[unitDefID].customParams.scav_swap_override_created ~= "null" then
					if UnitDefNames[UnitDefs[unitDefID].customParams.scav_swap_override_created] then
						createUnitQueue[#createUnitQueue+1] = {UnitDefs[unitDefID].customParams.scav_swap_override_created, x, y, z, Spring.GetUnitBuildFacing(unitID) or 0, scavTeamID}
					end
					Spring.DestroyUnit(unitID, true, true)
				elseif UnitDefs[unitDefID].customParams.scav_swap_override_created == "delete" then
					Spring.DestroyUnit(unitID, true, true)
				end
				return
			else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{config.defaultScavFirestate},0)
				GG.ScavengersSpawnEffectUnitID(unitID)
				if UnitDefs[unitDefID].canCloak then
					Spring.GiveOrderToUnit(unitID,37382,{1},0)
				end
				if squadSpawnOptions.commanders[UnitDefs[unitDefID].name] then
					CommandersPopulation = CommandersPopulation + 1
				end
				if squadSpawnOptions.decoyCommanders[UnitDefs[unitDefID].name] then
					DecoyCommandersPopulation = DecoyCommandersPopulation + 1
				end
				return
			end
		end

		capturableUnits[unitID] = true
		if squadPotentialTarget[unitID] or squadPotentialHighValueTarget[unitID] then
			squadPotentialTarget[unitID] = nil
			squadPotentialHighValueTarget[unitID] = nil
		end
		if not UnitDefs[unitDefID].canMove then
			squadPotentialTarget[unitID] = true
			if config.highValueTargets[unitDefID] then
				squadPotentialHighValueTarget[unitID] = true
			end
		end
		if config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue + (config.ecoBuildingsPenalty[unitDefID]/(config.bossTime/3600)) -- scale to 60minutes = 3600seconds boss time
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if attackerTeam == scavTeamID then
			damage = damage * config.damageMod
		end

		if unitTeam == scavTeamID then
			damage = damage / config.healthMod

			if math.random(0,600) == 0 and math.random() <= config.spawnChance and attackerTeam ~= gaiaTeamID and waveParameters.lastBackupSquadSpawnFrame+300 < Spring.GetGameFrame() and attackerID and UnitDefs[unitDefID].canMove then
				local ux, uy, uz = Spring.GetUnitPosition(attackerID)
				local burrow, distance = getNearestScavBeacon(ux, uy, uz)
				--Spring.Echo("Nearest Beacon Distance", distance)
				if ux and burrow and distance and distance < 2500 then
					waveParameters.lastBackupSquadSpawnFrame = Spring.GetGameFrame()
					--Spring.Echo("Spawning Backup Squad - Unit Damaged", Spring.GetGameFrame())
					for i = 1, SetCount(humanTeams) do
						if mRandom() <= config.spawnChance then
							SpawnRandomOffWaveSquad(burrow)
							burrows[burrow].lastBackupSpawn = Spring.GetGameFrame() + math.random(-300,1800)
						end
					end
				end
			end
		end

		if bossIDs[unitID] then -- Boss Resistance
			if attackerDefID then
				if weaponID == -1 and damage > 1 then
					damage = 1
				end
				attackerDefID = tostring(attackerDefID)
				if not bossResistance[attackerDefID] then
					bossResistance[attackerDefID] = {
						damage = damage * 4 * config.bossResistanceMult,
						notify = 0
					}
				end
				local resistPercent = math.min((bossResistance[attackerDefID].damage) / aliveBossesMaxHealth, 0.98)
				if resistPercent > 0.5 then
					if bossResistance[attackerDefID].notify == 0 then
						scavEvent("bossResistance", tonumber(attackerDefID))
						bossResistance[attackerDefID].notify = 1
						spawnCreepStructuresWave()
					end
					damage = damage - (damage * resistPercent)

				end
				bossResistance[attackerDefID].damage = bossResistance[attackerDefID].damage + (damage * 4 * config.bossResistanceMult)
				bossResistance[attackerDefID].percent = resistPercent
			else
				damage = 1
			end
			return damage
		end
		return damage, 1
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		-- Update targeting system damage statistics if beta is enabled
		if useEcoTargeting and targetingContext then
			if attackerTeam == scavTeamID and unitTeam ~= scavTeamID then
				-- Scav damaged enemy - count as damage dealt
				local x, y, z = Spring.GetUnitPosition(unitID)
				if x then
					PveTargeting.UpdateDamageStats(targetingContext, damage, 0, {x = x, y = y, z = z})
				end
			elseif unitTeam == scavTeamID and attackerTeam ~= scavTeamID and attackerTeam ~= gaiaTeamID then
				-- Enemy damaged scav - count as damage taken
				local x, y, z = Spring.GetUnitPosition(unitID)
				if x then
					PveTargeting.UpdateDamageStats(targetingContext, 0, damage, {x = x, y = y, z = z})
				end
			end
		end

		if config.scavBehaviours.SKIRMISH[attackerDefID] and (unitTeam ~= scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.SKIRMISH[attackerDefID].chance) and unitTeam ~= attackerTeam then
			local ux, uy, uz = GetUnitPosition(unitID)
			local x, y, z = GetUnitPosition(attackerID)
			if x and ux then
				local angle = math.atan2(ux - x, uz - z)
				local distance = mRandom(math.ceil(config.scavBehaviours.SKIRMISH[attackerDefID].distance*0.75), math.floor(config.scavBehaviours.SKIRMISH[attackerDefID].distance*1.25))
				if config.scavBehaviours.SKIRMISH[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x, y, z)
					Spring.SetUnitPosition(attackerID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
					Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance))
					unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.scavBehaviours.SKIRMISH[attackerDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
				end
				unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
			end
		elseif config.scavBehaviours.COWARD[unitDefID] and (unitTeam == scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.COWARD[unitDefID].chance) and unitTeam ~= attackerTeam then
			local curH, maxH = GetUnitHealth(unitID)
			if curH and maxH and curH < (maxH * 0.8) then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				if x and ax then
					local angle = math.atan2(ax - x, az - z)
					local distance = mRandom(math.ceil(config.scavBehaviours.COWARD[unitDefID].distance*0.75), math.floor(config.scavBehaviours.COWARD[unitDefID].distance*1.25))
					if config.scavBehaviours.COWARD[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
						GG.ScavengersSpawnEffectUnitDefID(unitDefID, x, y, z)
						Spring.SetUnitPosition(unitID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
						Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
						GG.ScavengersSpawnEffectUnitDefID(unitDefID, x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance))
						unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.scavBehaviours.COWARD[unitDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					end
					unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
				end
			end
		elseif config.scavBehaviours.BERSERK[unitDefID] and (unitTeam == scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.BERSERK[unitDefID].chance) and unitTeam ~= attackerTeam then
			local ax, ay, az = GetUnitPosition(attackerID)
			local x, y, z = GetUnitPosition(unitID)
			local separation = Spring.GetUnitSeparation(unitID, attackerID)
			if ax and separation < (config.scavBehaviours.BERSERK[unitDefID].distance or 10000) then
				if config.scavBehaviours.BERSERK[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
					GG.ScavengersSpawnEffectUnitDefID(unitDefID, x, y, z)
					ax = ax + mRandom(-256,256)
					az = az + mRandom(-256,256)
					Spring.SetUnitPosition(unitID, ax, ay, az)
					Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, ax, ay, az)
					unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.scavBehaviours.BERSERK[unitDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
				end
				unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
			end
		elseif config.scavBehaviours.BERSERK[attackerDefID] and (unitTeam ~= scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.BERSERK[attackerDefID].chance) and unitTeam ~= attackerTeam then
			local ax, ay, az = GetUnitPosition(unitID)
			local x, y, z = GetUnitPosition(attackerID)
			local separation = Spring.GetUnitSeparation(unitID, attackerID)
			if ax and separation < (config.scavBehaviours.BERSERK[attackerDefID].distance or 10000) then
				if config.scavBehaviours.BERSERK[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x, y, z)
					ax = ax + mRandom(-256,256)
					az = az + mRandom(-256,256)
					Spring.SetUnitPosition(attackerID, ax, ay, az)
					Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(unitDefID, ax, ay, az)
					unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.scavBehaviours.BERSERK[attackerDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
				end
				unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
			end
		end
		if bossIDs[unitID] then
			local curH, maxH = GetUnitHealth(unitID)
			if curH and maxH then
				curH = math.max(curH, maxH*0.05)
				local spawnChance = math.max(0, math.ceil(curH/maxH*10000))
				if mRandom(0,spawnChance) == 1 then
					SpawnMinions(unitID, Spring.GetUnitDefID(unitID))
					SpawnMinions(unitID, Spring.GetUnitDefID(unitID))
				end
			end
			if attackerTeam and attackerTeam ~= scavTeamID then
				bosses.playerDamages[tostring(attackerTeam)] = (bosses.playerDamages[tostring(attackerTeam)] or 0) + damage
			end
		end
		if unitTeam == scavTeamID or attackerTeam == scavTeamID then
			if (unitID and unitSquadTable[unitID] and squadsTable[unitSquadTable[unitID]] and squadsTable[unitSquadTable[unitID]].squadLife and squadsTable[unitSquadTable[unitID]].squadLife < 10) then
				squadsTable[unitSquadTable[unitID]].squadLife = 10
			end
			if (attackerID and unitSquadTable[attackerID] and squadsTable[unitSquadTable[attackerID]] and squadsTable[unitSquadTable[attackerID]].squadLife and squadsTable[unitSquadTable[attackerID]].squadLife < 10) then
				squadsTable[unitSquadTable[attackerID]].squadLife = 10
			end
		end
	end

	function gadget:GameStart()
		gadget:SetInitialSpawnBox()
	end

	function gadget:SetInitialSpawnBox()
		if config.burrowSpawnType == "initialbox" or config.burrowSpawnType == "alwaysbox" or config.burrowSpawnType == "initialbox_post" then
			local _, _, _, _, _, luaAllyID = Spring.GetTeamInfo(scavTeamID, false)
			if luaAllyID then
				lsx1, lsz1, lsx2, lsz2 = ScavStartboxXMin, ScavStartboxZMin, ScavStartboxXMax, ScavStartboxZMax
				if not lsx1 or not lsz1 or not lsx2 or not lsz2 then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Scav start box available, Burrow Placement set to 'Avoid Players'")
					noScavStartbox = true
				elseif lsx1 == 0 and lsz1 == 0 and lsx2 == Game.mapSizeX and lsz2 == Game.mapSizeX then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Scav start box available, Burrow Placement set to 'Avoid Players'")
					noScavStartbox = true
				end
			end
		end
		if not lsx1 then lsx1 = 0 end
		if not lsz1 then lsz1 = 0 end
		if not lsx2 then lsx2 = Game.mapSizeX end
		if not lsz2 then lsz2 = Game.mapSizeZ end
	end

	function SpawnScavs()
		local squadDone = false
		repeat
			local i, defs = next(spawnQueue)
			if not i or not defs then
				if #squadCreationQueue.units > 0 then
					if mRandom(1,5) == 1 then
						squadCreationQueue.regroupenabled = false
					end
					local squadID = createSquad(squadCreationQueue)
					squadDone = true
					squadCreationQueue.units = {}
					refreshSquad(squadID)
					-- Spring.Echo("[RAPTOR] Number of active Squads: ".. #squadsTable)
					-- Spring.Echo("[RAPTOR] Wave spawn complete.")
					-- Spring.Echo(" ")
				end
				return
			end

			local unitID

			local x,y,z
			if UnitDefNames[defs.unitName] then
				x, y, z = getScavSpawnLoc(defs.burrow, UnitDefNames[defs.unitName].id)
				if not x or not y or not z then
					spawnQueue[i] = nil
					return
				end
				unitID = CreateUnit(defs.unitName, x, y, z, mRandom(0,3), defs.team)
			else
				--Spring.Echo("Error: Cannot spawn unit " .. defs.unitName .. ", invalid name.")
				spawnQueue[i] = nil
				return
			end

			if unitID then
				if (not defs.squadID) or (defs.squadID and defs.squadID == 1) then
					if #squadCreationQueue.units > 0 then
						createSquad(squadCreationQueue)
						squadDone = true
					end
				end
				if defs.burrow and (not squadCreationQueue.burrow) then
					squadCreationQueue.burrow = defs.burrow
				end
				squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
				if config.scavBehaviours.HEALER[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "healer"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(20*Spring.GetModOptions().scav_spawntimemult) then
						squadCreationQueue.life = math.ceil(20*Spring.GetModOptions().scav_spawntimemult)
					end
				end
				if config.scavBehaviours.ARTILLERY[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "artillery"
					squadCreationQueue.regroupenabled = false
				end
				if config.scavBehaviours.KAMIKAZE[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "kamikaze"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().scav_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().scav_spawntimemult)
					end
				end
				if UnitDefNames[defs.unitName].canFly then
					squadCreationQueue.role = "aircraft"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().scav_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().scav_spawntimemult)
					end
				end
				if defs.alwaysVisible then
					Spring.SetUnitAlwaysVisible(unitID, true)
				end

				GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
				GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, 0)
				GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })
				GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })

				setScavXP(unitID)
			end
			spawnQueue[i] = nil
		until squadDone == true
	end

	function updateSpawnBoss()
		if nSpawnedBosses < nTotalBosses and not gameOver then
			-- spawn boss if not exists
			local bossID = SpawnBoss()
			if bossID then
				nSpawnedBosses = nSpawnedBosses + 1
				bossIDs[bossID] = true
				bosses.statuses[tostring(bossID)] = {}

				local bossSquad = table.copy(squadCreationQueueDefaults)
				bossSquad.life = 999999
				bossSquad.role = "raid"
				bossSquad.units = {bossID}
				createSquad(bossSquad)
				spawnQueue = {}
				scavEvent("boss") -- notify unsynced about boss spawn
				local _, bossMaxHP = GetUnitHealth(bossID)
				Spring.SetUnitHealth(bossID, math.max(bossMaxHP*(techAnger*0.01), bossMaxHP*0.2))
				SetUnitExperience(bossID, 0)
				timeOfLastWave = t
				burrows[bossID] = {
					lastBackupSpawn = Spring.GetGameFrame()
				}
				SetUnitBlocking(bossID, false, false)
				for burrowID, _ in pairs(burrows) do
					if mRandom() < config.spawnChance then
						SpawnRandomOffWaveSquad(burrowID)
					else
						SpawnRandomOffWaveSquad(burrowID)
					end
				end
				Spring.SetGameRulesParam("BossFightStarted", 1)
				Spring.SetUnitAlwaysVisible(bossID, true)
			end
		end
	end

	function updateScavSpawnBox()
		if config.burrowSpawnType == "initialbox_post" or config.burrowSpawnType == "initialbox" then
			lsx1 = math.max(ScavStartboxXMin - ((MAPSIZEX*0.01) * (techAnger+15)), 0)
			lsz1 = math.max(ScavStartboxZMin - ((MAPSIZEZ*0.01) * (techAnger+15)), 0)
			lsx2 = math.min(ScavStartboxXMax + ((MAPSIZEX*0.01) * (techAnger+15)), MAPSIZEX)
			lsz2 = math.min(ScavStartboxZMax + ((MAPSIZEZ*0.01) * (techAnger+15)), MAPSIZEZ)
			if not lsx2 or lsx2-lsx1 < 512 then
				lsx1 = math.max(0, math.floor((lsx1 + lsx2) / 2) - 256)
				lsx2 = lsx1 + 512
			end
			if not lsz2 or lsz2-lsz1 < 512 then
				lsz1 = math.max(0, math.floor((lsz1 + lsz2) / 2) - 256)
				lsz2 = lsz1 + 512
			end
		end
	end

	function gadget:TrySpawnBurrow()
		local maxSpawnRetries = math.floor((config.gracePeriod-t)/spawnRetryTimeDiv)
		local spawned = SpawnBurrow()
		timeOfLastSpawn = t
		if not fullySpawned then
			local burrowCount = SetCount(burrows)
			if burrowCount > 1 then
				fullySpawned = true
			elseif spawnRetries >= maxSpawnRetries or firstSpawn then
				spawnAreaMultiplier = spawnAreaMultiplier + 1
				ScavStartboxXMin, ScavStartboxZMin, ScavStartboxXMax, ScavStartboxZMax = EnemyLib.GetAdjustedStartBox(scavAllyTeamID, config.burrowSize*1.5*spawnAreaMultiplier)
				gadget:SetInitialSpawnBox()
				spawnRetries = 0
			else
				spawnRetries = spawnRetries + 1
			end
		end
		if firstSpawn and spawned then
			timeOfLastWave = (config.gracePeriod + 10) - config.scavSpawnRate
			firstSpawn = false
		end
	end

	local announcedFirstWave = false
	function gadget:GameFrame(n)

		if #createUnitQueue > 0 then
			for i = 1,#createUnitQueue do
				Spring.CreateUnit(createUnitQueue[i][1],createUnitQueue[i][2],createUnitQueue[i][3],createUnitQueue[i][4],createUnitQueue[i][5],createUnitQueue[i][6])
			end
			createUnitQueue = {}
		end

		if announcedFirstWave == false and GetGameSeconds() > config.gracePeriod then
			scavEvent("firstWave")
			announcedFirstWave = true
		end
		-- remove initial commander (no longer required)
		if n == 1 then
			PutScavAlliesInScavTeam(n)
			local units = GetTeamUnits(scavTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			return
		end

		local scavTeamUnitCount = GetTeamUnitCount(scavTeamID) or 0
		if scavTeamUnitCount < scavUnitCap and n%5 == 4 then
			SpawnScavs()
		end

		for unitID, defs in pairs(deathQueue) do
			if ValidUnitID(unitID) and not GetUnitIsDead(unitID) then
				DestroyUnit(unitID, defs.selfd or false, defs.reclaimed or false)
			end
		end

		if n%30 == 16 then
			t = GetGameSeconds()
			local burrowCount = SetCount(burrows)
			playerAggression = playerAggression*0.995
			playerAggressionLevel = math.floor(playerAggression)
			SetGameRulesParam("scavPlayerAggressionLevel", playerAggressionLevel)

			if useEcoTargeting and n >= lastSquadRebalanceFrame + squadRebalanceInterval then
				lastSquadRebalanceFrame = n
				distributeDistanceSquadTargets()
			end
			if nSpawnedBosses == 0 then
				currentMaxWaveSize = (minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))
			else
				currentMaxWaveSize = math.ceil((minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))*(config.bossFightWaveSizeScale*0.01))
			end
			techAnger = math.max(math.min((t - config.gracePeriod) / ((bossTime/(Spring.GetModOptions().scav_bosstimemult)) - config.gracePeriod) * 100, 999), 0)
			techAnger = math.ceil(techAnger*((config.economyScale*0.5)+0.5))
			if t < config.gracePeriod then
				bossAnger = 0
				minBurrows = math.ceil(math.max(4, 2*(math.min(SetCount(humanTeams), 8)))*(t/config.gracePeriod))
			else
				if nSpawnedBosses == 0 then
					bossAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / (bossTime - config.gracePeriod) * 100) + bossAngerAggressionLevel, 100), 0)
					minBurrows = 1
				else
					bossAnger = 100
					if Spring.GetModOptions().scav_endless then
						minBurrows = 4
					else
						minBurrows = 1
					end
				end
				bossAngerAggressionLevel = bossAngerAggressionLevel + ((playerAggression*0.01)/(config.bossTime/3600)) + playerAggressionEcoValue
				SetGameRulesParam("ScavBossAngerGain_Aggression", (playerAggression*0.01)/(config.bossTime/3600))
				SetGameRulesParam("ScavBossAngerGain_Eco", playerAggressionEcoValue)
			end
			SetGameRulesParam("scavBossAnger", math.floor(bossAnger))
			SetGameRulesParam("scavTechAnger", math.floor(techAnger))

			if bossAnger >= 100 or (burrowCount <= 1 and t > config.gracePeriod) then
				-- check if the boss should be alive
				updateSpawnBoss()
			end
			updateBossLife()

			if burrowCount < minBurrows then
				gadget:TrySpawnBurrow(t)
			end

			if (t > config.burrowSpawnRate and burrowCount < minBurrows and (t > timeOfLastSpawn + 10 or burrowCount == 0)) or (config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if (config.burrowSpawnType == "initialbox") and (t > config.gracePeriod) then
					config.burrowSpawnType = "initialbox_post"
				end
				gadget:TrySpawnBurrow(t)
				scavEvent("burrowSpawn")
				SetGameRulesParam("scav_hiveCount", SetCount(burrows))
			elseif config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount >= maxBurrows then
				timeOfLastSpawn = t
			end

			if t > config.gracePeriod+5 then
				if burrowCount > 0
				and SetCount(spawnQueue) == 0
				and ((config.scavSpawnRate*waveParameters.waveTimeMultiplier) < (t - timeOfLastWave)) then
					Wave()
					timeOfLastWave = t
				end
			end

			updateScavSpawnBox()
		end
		if n%((math.ceil(config.turretSpawnRate))*30) == 0 and n > 900 and scavTeamUnitCount < scavUnitCap then
			spawnCreepStructuresWave()
		end
		local squadID = ((n % (#squadsTable*2))+1)/2 --*2 and /2 for lowering the rate of commands
		if squadID and squadsTable[squadID] and squadsTable[squadID].squadRegroupEnabled then
			local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
			if targetx then
				squadCommanderGiveOrders(squadID, targetx, targety, targetz)
			else
				refreshSquad(squadID)
			end
		end
		if n%7 == 3 then
			local scavs = GetTeamUnits(scavTeamID)
			for i = 1,#scavs do
				if mRandom(1,math.ceil((33*math.max(1, Spring.GetTeamUnitDefCount(scavTeamID, Spring.GetUnitDefID(scavs[i])))))) == 1 and mRandom() < config.spawnChance then
					SpawnMinions(scavs[i], Spring.GetUnitDefID(scavs[i]))
				end
				if mRandom(1,60) == 1 then
					if unitCowardCooldown[scavs[i]] and (Spring.GetGameFrame() > unitCowardCooldown[scavs[i]]) then
						unitCowardCooldown[scavs[i]] = nil
						Spring.GiveOrderToUnit(scavs[i], CMD.STOP, 0, 0)
					end
					if Spring.GetUnitCommandCount(scavs[i]) == 0 then
						if unitCowardCooldown[scavs[i]] then
							unitCowardCooldown[scavs[i]] = nil
						end
						local squadID = unitSquadTable[scavs[i]]
						if squadID then
							local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
							if targetx then
								squadsTable[squadID].squadNeedsRefresh = true
								squadCommanderGiveOrders(squadID, targetx, targety, targetz)
							else
								refreshSquad(squadID)
							end
						else
							local pos = getRandomEnemyPos()
							Spring.GiveOrderToUnit(scavs[i], CMD.STOP, {}, {})
							if Spring.GetUnitDefID(scavs[i]) and config.scavBehaviours.HEALER[Spring.GetUnitDefID(scavs[i])] then
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(scavs[i], CMD.RESURRECT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(scavs[i], CMD.CAPTURE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								if math.random() < 0.75 then
									Spring.GiveOrderToUnit(scavs[i], CMD.REPAIR, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
								end
								Spring.GiveOrderToUnit(scavs[i], CMD.RESURRECT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 20000} , {"shift"})
							end
							if config.scavBehaviours.ALWAYSMOVE[Spring.GetUnitDefID(scavs[i])] then
								Spring.GiveOrderToUnit(scavs[i], CMD.MOVE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							elseif config.scavBehaviours.ALWAYSFIGHT[Spring.GetUnitDefID(scavs[i])] then
								Spring.GiveOrderToUnit(scavs[i], CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							elseif mRandom() <= 0.5 and Spring.GetUnitDefID(scavs[i]) and (
								config.scavBehaviours.SKIRMISH[Spring.GetUnitDefID(scavs[i])] or
								config.scavBehaviours.COWARD[Spring.GetUnitDefID(scavs[i])] or
								config.scavBehaviours.HEALER[Spring.GetUnitDefID(scavs[i])] or
								config.scavBehaviours.ARTILLERY[Spring.GetUnitDefID(scavs[i])]) then
									Spring.GiveOrderToUnit(scavs[i], CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift", "meta"})
							else
								Spring.GiveOrderToUnit(scavs[i], CMD.MOVE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {"shift"})
							end
						end
					end
				end
			end
		end

		if n%7 == 2 then
			if not captureRuns then captureRuns = 0 end
			captureRuns = (captureRuns + 1)%4

			for unitID, _ in pairs(capturableUnits) do
				if unitID%4 == captureRuns then
					local ux, uy, uz = Spring.GetUnitPosition(unitID)
					local health, maxHealth, _, captureLevel = Spring.GetUnitHealth(unitID)
					if health then
						local captureProgress = 0.016667 * (3/math.ceil(math.sqrt(math.sqrt(UnitDefs[Spring.GetUnitDefID(unitID)].health)))) * math.max(0.1, (techAnger/100)) -- really wack formula that i really don't want to explain.
						if health < maxHealth then
							captureProgress = captureProgress/math.max(0.000001, (health/maxHealth)^3)
						end
						captureProgress = math.min(0.05, captureProgress)
						if Spring.GetUnitTeam(unitID) ~= scavTeamID and GG.IsPosInRaptorScum(ux, uy, uz) then
							if captureLevel+captureProgress >= 0.99 then
								Spring.TransferUnit(unitID, scavTeamID, false)
								Spring.SetUnitHealth(unitID, {capture = 0.95})
								Spring.SetUnitHealth(unitID, {health = maxHealth})
								SendToUnsynced("unitCaptureFrame", unitID, 0.95)
								GG.ScavengersSpawnEffectUnitID(unitID)
								Spring.SpawnCEG("scavmist", ux, uy+100, uz, 0,0,0)
								Spring.SpawnCEG("scavradiation", ux, uy+100, uz, 0,0,0)
								Spring.SpawnCEG("scavradiation-lightning", ux, uy+100, uz, 0,0,0)

								GG.addUnitToCaptureDecay(unitID)
							else
								Spring.SetUnitHealth(unitID, {capture = math.min(captureLevel+captureProgress, 1)})
								SendToUnsynced("unitCaptureFrame", unitID, math.min(captureLevel+captureProgress, 1))
								Spring.SpawnCEG("scaspawn-trail", ux, uy, uz, 0,0,0)
								GG.ScavengersSpawnEffectUnitID(unitID)
								if math.random() <= 0.1 then
									Spring.SpawnCEG("scavmist", ux, uy+100, uz, 0,0,0)
								end
								if math.random(0,60) == 0 and math.random() <= config.spawnChance and Spring.GetUnitTeam(unitID) ~= gaiaTeamID and waveParameters.lastBackupSquadSpawnFrame+300 < Spring.GetGameFrame() then
									local burrow, distance = getNearestScavBeacon(ux, uy, uz)
									--Spring.Echo("Nearest Beacon Distance", distance)
									if ux and burrow and distance and distance < 2500 then
										--Spring.Echo("Spawning Backup Squad - Unit Cloud Capture", Spring.GetGameFrame())
										for i = 1, SetCount(humanTeams) do
											if mRandom() <= config.spawnChance then
												SpawnRandomOffWaveSquad(burrow)
												burrows[burrow].lastBackupSpawn = Spring.GetGameFrame() + math.random(-300,1800)
											end
										end
									end
								end
								GG.addUnitToCaptureDecay(unitID)
							end
						elseif Spring.GetUnitTeam(unitID) == scavTeamID and captureLevel > 0 then
							GG.addUnitToCaptureDecay(unitID)
						end
					end
				end
			end
		end
		manageAllSquads()
	end

	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)

		if oldTeam == scavTeamID then
			if unitSquadTable[unitID] then
				for index, id in ipairs(squadsTable[unitSquadTable[unitID]].squadUnits) do
					if id == unitID then
						table.remove(squadsTable[unitSquadTable[unitID]].squadUnits, index)
					end
				end
				unitSquadTable[unitID] = nil
			end
			capturableUnits[unitID] = true
		end

		if newTeam == scavTeamID then
			squadPotentialTarget[unitID] = nil
			squadPotentialHighValueTarget[unitID] = nil
			capturableUnits[unitID] = nil
			for squad in ipairs(unitTargetPool) do
				if unitTargetPool[squad] == unitID then
					refreshSquad(squad)
				end
			end

			local x,y,z = Spring.GetUnitPosition(unitID)
			if not UnitDefs[unitDefID].customParams.isscavenger then
				--Spring.Echo(UnitDefs[unitDefID].name, "unit captured swap", UnitDefs[unitDefID].customParams.scav_swap_override_captured)
				if not UnitDefs[unitDefID].customParams.scav_swap_override_captured then
					if UnitDefs[unitDefID] and UnitDefs[unitDefID].name and UnitDefNames[UnitDefs[unitDefID].name .. "_scav"] then
						createUnitQueue[#createUnitQueue+1] = {UnitDefs[unitDefID].name .. "_scav", x, y, z, Spring.GetUnitBuildFacing(unitID) or 0, scavTeamID}
						Spring.DestroyUnit(unitID, true, true)
					end
				elseif UnitDefs[unitDefID].customParams.scav_swap_override_captured ~= "null" then
					if UnitDefNames[UnitDefs[unitDefID].customParams.scav_swap_override_captured] then
						createUnitQueue[#createUnitQueue+1] = {UnitDefs[unitDefID].customParams.scav_swap_override_captured, x, y, z, Spring.GetUnitBuildFacing(unitID) or 0, scavTeamID}
					end
					Spring.DestroyUnit(unitID, true, true)
				elseif UnitDefs[unitDefID].customParams.scav_swap_override_captured == "delete" then
					Spring.DestroyUnit(unitID, true, true)
				end
				return
			else
				Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{config.defaultScavFirestate},0)
				GG.ScavengersSpawnEffectUnitID(unitID)
				if UnitDefs[unitDefID].canCloak then
					Spring.GiveOrderToUnit(unitID,37382,{1},0)
				end
				if squadSpawnOptions.commanders[UnitDefs[unitDefID].name] then
					CommandersPopulation = CommandersPopulation + 1
				end
				if squadSpawnOptions.decoyCommanders[UnitDefs[unitDefID].name] then
					DecoyCommandersPopulation = DecoyCommandersPopulation + 1
				end
				return
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
		if unitTeam == scavTeamID then
			if string.find(UnitDefs[unitDefID].name, "scavbeacon") then
				if mRandom() <= config.spawnChance then
					spawnCreepStructuresWave()
				end
			end
			if UnitDefs[unitDefID].isscavenger then
				if squadSpawnOptions.commanders[UnitDefs[unitDefID].name] then
					CommandersPopulation = CommandersPopulation - 1
				end
				if squadSpawnOptions.decoyCommanders[UnitDefs[unitDefID].name] then
					DecoyCommandersPopulation = DecoyCommandersPopulation - 1
				end
			end
		end

		if unitSquadTable[unitID] then
			for index, id in ipairs(squadsTable[unitSquadTable[unitID]].squadUnits) do
				if id == unitID then
					table.remove(squadsTable[unitSquadTable[unitID]].squadUnits, index)
					break
				end
			end
			unitSquadTable[unitID] = nil
		end

		for index, _ in ipairs(squadsTable) do
			if squadsTable[index].squadBurrow == unitID then
				squadsTable[index].squadBurrow = nil
			end
		end

		squadPotentialTarget[unitID] = nil
		squadPotentialHighValueTarget[unitID] = nil
		capturableUnits[unitID] = nil
		for squad in ipairs(unitTargetPool) do
			if unitTargetPool[squad] == unitID then
				refreshSquad(squad)
			end
		end

		if unitTeam == scavTeamID then
			local kills = GetGameRulesParam("scav" .. "Kills") or 0
			SetGameRulesParam("scav" .. "Kills", kills + 1)
		end

		if bossIDs[unitID] then
			nKilledBosses = nKilledBosses + 1
			bossIDs[unitID] = nil
			table.mergeInPlace(bosses.statuses, {[tostring(unitID)] = {isDead = true, health = 0}})
			SetGameRulesParam("scavBossesKilled", nKilledBosses)

			if nKilledBosses >= nTotalBosses then
				Spring.SetGameRulesParam("BossFightStarted", 0)

				if Spring.GetModOptions().scav_endless then
					updateDifficultyForSurvival()
				else
					gameOver = GetGameFrame() + 200
					spawnQueue = {}

					if not killedScavsAllyTeam then
						killedScavsAllyTeam = true

						-- kill scav team
						Spring.KillTeam(scavTeamID)

						-- check if scavengers are in the same allyteam and alive
						local scavengersFoundAlive = false
						for _, teamID in ipairs(Spring.GetTeamList(scavAllyTeamID)) do
							local luaAI = Spring.GetTeamLuaAI(teamID)
							if luaAI and luaAI:find("Scavengers") and not select(3, Spring.GetTeamInfo(teamID, false)) then
								scavengersFoundAlive = true
							end
						end

						-- kill whole allyteam
						if not scavengersFoundAlive then
							for _, teamID in ipairs(Spring.GetTeamList(scavAllyTeamID)) do
								if not select(3, Spring.GetTeamInfo(teamID, false)) then
									Spring.KillTeam(teamID)
								end
							end
						end
					end
				end
			end
		end

		if burrows[unitID] and not gameOver then

			burrows[unitID] = nil
			if attackerID and Spring.GetUnitTeam(attackerID) ~= scavTeamID then
				playerAggression = playerAggression + (config.angerBonus/config.scavSpawnMultiplier)
				config.maxXP = config.maxXP*1.01
			end

			for i, defs in pairs(spawnQueue) do
				if defs.burrow == unitID then
					spawnQueue[i] = nil
				end
			end

			SetGameRulesParam("scav_hiveCount", SetCount(burrows))
		-- elseif unitTeam == scavTeamID and UnitDefs[unitDefID].isBuilding and (attackerID and Spring.GetUnitTeam(attackerID) ~= scavTeamID) then
		-- 	playerAggression = playerAggression + ((config.angerBonus/config.scavSpawnMultiplier)*0.01)
		end
		if unitTeleportCooldown[unitID] then
			unitTeleportCooldown[unitID] = nil
		end
		if unitTeam ~= scavTeamID and config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue - (config.ecoBuildingsPenalty[unitDefID]/(config.bossTime/3600)) -- scale to 60minutes = 3600seconds boss time
		end
	end

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if unitTeam ~= scavTeamID and unitTeam ~= gaiaTeamID then
			local unitTech = tonumber(UnitDefs[unitDefID].customParams.techlevel)
			HumanTechLevel = math.max(HumanTechLevel, unitTech)
		end
		if unitTeam ~= scavTeamID then
			capturableUnits[unitID] = true
		end
	end

	function gadget:TeamDied(teamID)
		humanTeams[teamID] = nil
		--computerTeams[teamID] = nil
	end

	function gadget:FeatureCreated(featureID, featureAllyTeamID)

	end

	function gadget:FeatureDestroyed(featureID, featureAllyTeamID)

	end

	function gadget:GameOver()
		-- don't end game in survival mode
		if config.difficulty ~= config.difficulties.survival then
			gameOver = GetGameFrame()
		end
	end

	-- function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- 	if teamID == scavTeamID and cmdID == CMD.SELFD then
	-- 		return false
	-- 	else
	-- 		return true
	-- 	end
	-- end

else	-- UNSYNCED

	local hasScavEvent = false

	function HasScavEvent(ce)
		hasScavEvent = (ce ~= "0")
	end

	function WrapToLuaUI(_, type, num, tech)
		if hasScavEvent then
			local scavEventArgs = {}
			if type ~= nil then
				scavEventArgs["type"] = type
			end
			if num ~= nil then
				scavEventArgs["number"] = num
			end
			if tech ~= nil then
				scavEventArgs["tech"] = tech
			end
			Script.LuaUI.ScavEvent(scavEventArgs)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('ScavEvent', WrapToLuaUI)
		gadgetHandler:AddChatAction("HasScavEvent", HasScavEvent, "toggles hasScavEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasScavEvent")
	end

end
