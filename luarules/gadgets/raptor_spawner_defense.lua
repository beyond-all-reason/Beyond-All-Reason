
if Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers() then
	Spring.Log("Raptor Defense Spawner", LOG.INFO, "Raptor Defense Spawner Activated!")
else
	Spring.Log("Raptor Defense Spawner", LOG.INFO, "Raptor Defense Spawner Deactivated!")
	return false
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Raptor Defense Spawner",
		desc = "Spawns burrows and raptors",
		author = "TheFatController/quantum, Damgam",
		date = "27 February, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local config = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua')
local EnemyLib = VFS.Include('LuaRules/Gadgets/Include/SpawnerEnemyLib.lua')

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	-- SYNCED CODE
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Speed-ups
	if tracy == nil then
		--Spring.Echo("Gadgetside tracy: No support detected, replacing tracy.* with function stubs.")
		tracy = {}
		tracy.ZoneBeginN = function () return end
		tracy.ZoneBegin = function () return end
		tracy.ZoneEnd = function () return end --Spring.Echo("No Tracy") return end
		tracy.Message = function () return end
		tracy.ZoneName = function () return end
		tracy.ZoneText = function () return end
	end
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
	local nKilledQueens = 0
	local nSpawnedQueens = 0
	local nTotalQueens = Spring.GetModOptions().raptor_queen_count or 1
	local maxTries = 30
	local raptorUnitCap = math.floor(Game.maxUnits*0.8)
	local minBurrows = 1
	local timeOfLastSpawn = -999999
	local timeOfLastWave = 0
	local t = 0 -- game time in secondstarget
	local queenAnger = 0
	local techAnger = 0
	local aliveBossesMaxHealth = 0
	local playerAggression = 0
	local playerAggressionLevel = 0
	local playerAggressionEcoValue = 0
	local queenAngerAggressionLevel = 0
	local difficultyCounter = config.difficulty
	local waveParameters = {
		waveCounter = 0,
		firstWavesBoost = Spring.GetModOptions().raptor_firstwavesboost,
		baseCooldown = 5,
		waveSizeMultiplier = 1,
		waveTimeMultiplier = 1,
		waveAirPercentage = 20,
		waveSpecialPercentage = 33,
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
		}
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
	local queenResistance = {}
	local queenIDs = {}
	local bosses = {resistances = queenResistance, statuses = {}, playerDamages = {}}
	local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
	local raptorAllyTeamID = Spring.Utilities.GetRaptorAllyTeamID()
	local lsx1, lsz1, lsx2, lsz2
	local burrows = {}
	local heroRaptor = {}
	local aliveEggsTable = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadTargetsByEcoWeight = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local unitTeleportCooldown = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = math.ceil(10*Spring.GetModOptions().raptor_spawntimemult),
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = math.ceil(10*Spring.GetModOptions().raptor_spawntimemult),
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}


	local isObject = {}
	for udefID, def in ipairs(UnitDefs) do
		if def.modCategories['object'] or def.customParams.objectify then
			isObject[udefID] = true
		end
	end

	--------------------------------------------------------------------------------
	-- Teams
	--------------------------------------------------------------------------------

	local teams = GetTeamList()
	for _, teamID in ipairs(teams) do
		local teamLuaAI = GetTeamLuaAI(teamID)
		if teamID ~= raptorTeamID then
			humanTeams[teamID] = true
		end
	end

	local gaiaTeamID = GetGaiaTeamID()

	humanTeams[gaiaTeamID] = nil

	local function PutRaptorAlliesInRaptorTeam(n)
		local players = Spring.GetPlayerList()
		for i = 1,#players do
			local player = players[i]
			local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
			if allyTeamID == raptorAllyTeamID and (not spectator) then
				Spring.AssignPlayerToTeam(player, raptorTeamID)
				local units = GetTeamUnits(teamID)
				raptorteamhasplayers = true
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
				end
				Spring.KillTeam(teamID)
			end
		end

		local raptorAllies = Spring.GetTeamList(raptorAllyTeamID)
		for i = 1,#raptorAllies do
			local _,_,_,AI = Spring.GetTeamInfo(raptorAllies[i])
			local LuaAI = Spring.GetTeamLuaAI(raptorAllies[i])
			if (AI or LuaAI) and raptorAllies[i] ~= raptorTeamID then
				local units = GetTeamUnits(raptorAllies[i])
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(raptorAllies[i])
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Utility

	local SetListUtilities = VFS.Include('common/SetList.lua')

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
		-- Pre-opt: 224 us, sigma 105 us!
		-- Post-opt: 3 us, sigma 1us
		tracy.ZoneBeginN("Raptors:getRandomEnemyPos")
		local pos = {}
		local pickedTarget = nil

		local ecoTierMaxProbability = 1

		for weight,units in pairs(squadTargetsByEcoWeight) do
			ecoTierMaxProbability = ecoTierMaxProbability + weight * units.count
		end

		local random = mRandom(1, ecoTierMaxProbability)
		ecoTierMaxProbability = 1

		-- 10 tries to find a valid target
		for try = 1, 10 do

			for weight,units in pairs(squadTargetsByEcoWeight) do
				if units.count then
					ecoTierMaxProbability = ecoTierMaxProbability + weight * units.count

					if random <= ecoTierMaxProbability then
						local target = units:GetRandom()
						if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
							-- Spring.Echo("Targetting eco: " .. random .. " found " .. UnitDefs[Spring.GetUnitDefID(target)].name);

							local x,y,z = Spring.GetUnitPosition(target)
							pos = {x = x+mRandom(-32,32), y = y, z = z+mRandom(-32,32)}
							pickedTarget = target
							break
						end
					end
				end
			end

			if pos.x then
				break
			end
		end

		if not pos.x then
			pos = getRandomMapPos()
		end
		tracy.ZoneEnd()
		return pos, pickedTarget
	end

	function setRaptorXP(unitID)
		local maxXP = config.maxXP
		local queenAnger = queenAnger or 0
		local xp = mRandom(0, math.ceil((queenAnger*0.01) * maxXP * 1000))*0.001
		SetUnitExperience(unitID, xp)
		return xp
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Difficulty
    --

	local maxBurrows = ((config.maxBurrows*(1-config.raptorPerPlayerMultiplier))+(config.maxBurrows*config.raptorPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8)))*config.raptorSpawnMultiplier
	local queenTime = (config.queenTime + config.gracePeriod)
	if config.difficulty == config.difficulties.survival then
		queenTime = math.ceil(queenTime*0.5)
	end
	local maxWaveSize = ((config.maxRaptors*(1-config.raptorPerPlayerMultiplier))+(config.maxRaptors*config.raptorPerPlayerMultiplier)*SetCount(humanTeams))*config.raptorSpawnMultiplier
	local minWaveSize = ((config.minRaptors*(1-config.raptorPerPlayerMultiplier))+(config.minRaptors*config.raptorPerPlayerMultiplier)*SetCount(humanTeams))*config.raptorSpawnMultiplier
	local currentMaxWaveSize = minWaveSize
	local endlessLoopCounter = 1
	local pastFirstQueen = false
	function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		queenAnger = 0  -- reenable raptor spawning
		techAnger = 0
		playerAggression = 0
		queenAngerAggressionLevel = 0
		pastFirstQueen = true
		nSpawnedQueens = 0
		nKilledQueens = 0
		queenResistance = {}
		aliveBossesMaxHealth = 0
		bosses.resistances = queenResistance
		bosses.statuses = {}
		SetGameRulesParam("raptorQueenAnger", math.floor(queenAnger))
		SetGameRulesParam("raptorTechAnger", math.floor(techAnger))
		local nextDifficulty
		difficultyCounter = difficultyCounter + 1
		endlessLoopCounter = endlessLoopCounter + 1
		if config.difficultyParameters[difficultyCounter] then
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.queenResistanceMult = nextDifficulty.queenResistanceMult
			config.damageMod = nextDifficulty.damageMod
			config.healthMod = nextDifficulty.healthMod
		else
			difficultyCounter = difficultyCounter - 1
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.raptorSpawnMultiplier = config.raptorSpawnMultiplier+1
			config.queenResistanceMult = config.queenResistanceMult+0.5
			config.damageMod = config.damageMod+0.25
			config.healthMod = config.healthMod+0.25
		end
		config.queenName = nextDifficulty.queenName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.turretSpawnRate = nextDifficulty.turretSpawnRate
		config.queenSpawnMult = nextDifficulty.queenSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxRaptors = nextDifficulty.maxRaptors
		config.minRaptors = nextDifficulty.minRaptors
		config.maxBurrows = nextDifficulty.maxBurrows
		config.maxXP = nextDifficulty.maxXP
		config.angerBonus = nextDifficulty.angerBonus
		config.queenTime = math.ceil(nextDifficulty.queenTime/endlessLoopCounter)

		queenTime = (config.queenTime + config.gracePeriod)
		maxBurrows = ((config.maxBurrows*(1-config.raptorPerPlayerMultiplier))+(config.maxBurrows*config.raptorPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8)))*config.raptorSpawnMultiplier
		maxWaveSize = ((config.maxRaptors*(1-config.raptorPerPlayerMultiplier))+(config.maxRaptors*config.raptorPerPlayerMultiplier)*SetCount(humanTeams))*config.raptorSpawnMultiplier
		minWaveSize = ((config.minRaptors*(1-config.raptorPerPlayerMultiplier))+(config.minRaptors*config.raptorPerPlayerMultiplier)*SetCount(humanTeams))*config.raptorSpawnMultiplier
		config.raptorSpawnRate = nextDifficulty.raptorSpawnRate
		currentMaxWaveSize = minWaveSize
		SetGameRulesParam("RaptorQueenAngerGain_Base", 100/config.queenTime)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game Rules
	--

	SetGameRulesParam("raptorQueenTime", queenTime)
	SetGameRulesParam("raptorQueenAnger", math.floor(queenAnger))
	SetGameRulesParam("raptorTechAnger", math.floor(techAnger))
	SetGameRulesParam("raptorGracePeriod", config.gracePeriod)
	SetGameRulesParam("raptorDifficulty", config.difficulty)
	SetGameRulesParam("RaptorQueenAngerGain_Base", 100/config.queenTime)
	SetGameRulesParam("RaptorQueenAngerGain_Aggression", 0)
	SetGameRulesParam("RaptorQueenAngerGain_Eco", 0)


	local function raptorEvent(type, num, tech)
		SendToUnsynced("RaptorEvent", type, num, tech)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Spawn Dynamics
	--

	local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
	local RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = EnemyLib.GetAdjustedStartBox(raptorAllyTeamID, config.burrowSize*1.5*spawnAreaMultiplier)

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

			if squadsTable[i].squadLife <= 0 then
				-- Spring.Echo("Life is 0, time to do some killing")
				if SetCount(squadsTable[i].squadUnits) > 0 and SetCount(burrows) > 2 then
					if squadsTable[i].squadBurrow and nSpawnedQueens == 0 then
						if Spring.GetUnitTeam(squadsTable[i].squadBurrow) == raptorTeamID then
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
						if Spring.GetUnitTeam(destroyQueue[j]) == raptorTeamID then
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
		tracy.ZoneBeginN("Raptors:squadCommanderGiveOrders")
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
							if role == "assault" or role == "healer" or role == "artillery" then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "raid" then
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "aircraft" or role == "kamikaze" then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x, pos.y, pos.z} , {})
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
		tracy.ZoneEnd()
	end

	function refreshSquad(squadID) -- Get new target for a squad
		tracy.ZoneBeginN("Raptors:refreshSquad")
		local pos, pickedTarget = getRandomEnemyPos()
		--Spring.Echo(pos.x, pos.y, pos.z, pickedTarget)
		unitTargetPool[squadID] = pickedTarget
		squadsTable[squadID].target = pos
		-- Spring.MarkerAddPoint (squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z, "Squad #" .. squadID .. " target")
		local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
		squadsTable[squadID].squadNeedsRefresh = true
		--squadCommanderGiveOrders(squadID, targetx, targety, targetz)
		tracy.ZoneEnd()
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
				newSquad.life = math.ceil(10*Spring.GetModOptions().raptor_spawntimemult)
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

			-- Spring.Echo("Created Raptor Squad, containing " .. #squadsTable[squadID].squadUnits .. " units!")
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


	function getRaptorSpawnLoc(burrowID, size)
		if not burrowID then
			return false
		end
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

	function SpawnRandomOffWaveSquad(burrowID, raptorType, count)
		if gameOver then
			return
		end
		local squadCounter = 0
		if raptorType then
			if not count then count = 1 end
			if UnitDefNames[raptorType] then
				for j = 1, count, 1 do
					if mRandom() <= config.spawnChance or j == 1 then
						squadCounter = squadCounter + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = raptorType, team = raptorTeamID, squadID = squadCounter })
					end
				end
			elseif not UnitDefNames[raptorType] then
				Spring.Echo("[ERROR] Invalid Raptor Unit Name", raptorType)
			else
				Spring.Echo("[ERROR] Invalid Raptor Squad", raptorType)
			end
		else
			squadCounter = 0
			local squad
			local specialRandom = mRandom(1,100)
			for _ = 1,1000 do
				if specialRandom <= waveParameters.waveSpecialPercentage then
					local potentialSquad = squadSpawnOptions.special[mRandom(1, #squadSpawnOptions.special)]
					if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
					or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
						squad = potentialSquad
						break
					end
				else
					local potentialSquad = squadSpawnOptions.basic[mRandom(1, #squadSpawnOptions.basic)]
					if potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger then
						squad = potentialSquad
						break
					end
				end
			end
			if squad then
				for _, squadTable in pairs(squad.units) do
					local unitNumber = squadTable.count
					local raptorName = squadTable.unit
					if UnitDefNames[raptorName] and unitNumber and unitNumber > 0 then
						for j = 1, unitNumber, 1 do
							if mRandom() <= config.spawnChance or j == 1 then
								squadCounter = squadCounter + 1
								table.insert(spawnQueue, { burrow = burrowID, unitName = raptorName, team = raptorTeamID, squadID = squadCounter })
							end
						end
					elseif not UnitDefNames[raptorName] then
						Spring.Echo("[ERROR] Invalid Raptor Unit Name", raptorName)
					else
						Spring.Echo("[ERROR] Invalid Raptor Squad", raptorName)
					end
				end
			end
		end
		return squadCounter
	end

	function SetupBurrow(unitID, x, y, z)
		burrows[unitID] = 0
		SetUnitBlocking(unitID, false, false)
		setRaptorXP(unitID)
	end

	function SpawnBurrow(number)
		local foundLocation = false
		tracy.ZoneBeginN("Raptors:SpawnBurrow")
		for i = 1, (number or 1) do
			local canSpawnBurrow = false
			local spread = config.burrowSize*1.5
			local spawnPosX, spawnPosY, spawnPosZ

			if config.useScum then -- Attempt #1, find position in creep/scum (skipped if creep is disabled or alwaysbox is enabled)
				if spread < MAPSIZEX - spread and spread < MAPSIZEZ - spread then
					for _ = 1,100 do
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
						if canSpawnBurrow then
							break
						end
					end
				end
			end

			if (not canSpawnBurrow) and config.burrowSpawnType ~= "avoid" then -- Attempt #2 Force spawn in Startbox, ignore any kind of player vision
				for _ = 1,100 do
					spawnPosX = mRandom(RaptorStartboxXMin + spread, RaptorStartboxXMax - spread)
					spawnPosZ = mRandom(RaptorStartboxZMin + spread, RaptorStartboxZMax - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow and noRaptorStartbox then -- this is for case where they have no startbox. We don't want them spawning on top of your stuff.
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, true, true)
					end
					if canSpawnBurrow then
						break
					end
				end
			end

			if (not canSpawnBurrow) then -- Attempt #3 Find some good position in Spawnbox (not Startbox)
				for _ = 1,100 do
					spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
					spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, true, true)
					end
					if canSpawnBurrow then
						canSpawnBurrow = not (positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, false, false)) -- we need to reverse result of this, because we want this to be true when pos is in LoS of Raptor team, and the visibility check does the opposite.
					end
					if canSpawnBurrow then
						break
					end
				end
			end

			if config.burrowSpawnType == "avoid" then -- Last Resort for Avoid Players burrow setup. Spawns anywhere that isn't in player sensor range

				for _ = 1,100 do -- Attempt #1 Avoid all sensors
					spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
					spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, true, true)
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
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, true, false)
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
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, false, false)
						end
						if canSpawnBurrow then
							break
						end
					end
				end
			end
			if (canSpawnBurrow and GetGameSeconds() < config.gracePeriod*0.9) or (canSpawnBurrow and config.burrowSpawnType == "avoid") then -- Don't spawn new burrows in existing creep during grace period - Force them to spread as much as they can..... AT LEAST THAT'S HOW IT'S SUPPOSED TO WORK, lol.
				canSpawnBurrow = not GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
			end

			if canSpawnBurrow then
				foundLocation = true
				local burrowID = CreateUnit(config.burrowName, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), raptorTeamID)
				if burrowID then
					SetupBurrow(burrowID, spawnPosX, spawnPosY, spawnPosZ)
				end
			else
				timeOfLastSpawn = GetGameSeconds()
				--playerAggression = playerAggression + (config.angerBonus*(queenAnger*0.01))
			end
		end
		tracy.ZoneEnd()
		return foundLocation
	end

	function updateQueenHealth()
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

		SetGameRulesParam("raptorQueenHealth", math.floor(0.5 + ((totalHealth / totalMaxHealth) * 100)))
		SetGameRulesParam("pveBossInfo", Json.encode(bosses))
		end

	function SpawnQueen()
		local bestScore = 0
		local bestBurrowID
		local sx, sy, sz
		for burrowID, _ in pairs(burrows) do
			-- Try to spawn the queen at the 'best' burrow
			local x, y, z = GetUnitPosition(burrowID)
			if x and y and z and not queenIDs[burrowID] then
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
			return CreateUnit(config.queenName, sx, sy, sz, mRandom(0,3), raptorTeamID), burrowID
		end

		local x, z, y
		local tries = 0
		local canSpawnQueen = false
		repeat
			x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
			z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
			y = GetGroundHeight(x, z)
			tries = tries + 1
			canSpawnQueen = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)

			if canSpawnQueen then
				if tries < maxTries*3 then
					canSpawnQueen = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, raptorAllyTeamID, true, true, true)
				else
					canSpawnQueen = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, raptorAllyTeamID, true, true, false)
				end
			end

			if canSpawnQueen then
				canSpawnQueen = positionCheckLibrary.OccupancyCheck(x, y, z, config.burrowSize*0.25)
			end

			if canSpawnQueen then
				canSpawnQueen = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
			end

		until (canSpawnQueen == true or tries >= maxTries * 6)

		if canSpawnQueen then
			return CreateUnit(config.queenName, x, y, z, mRandom(0,3), raptorTeamID)
		else
			for i = 1,100 do
				x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
				z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
				y = GetGroundHeight(x, z)

				canSpawnQueen = positionCheckLibrary.StartboxCheck(x, y, z, raptorAllyTeamID)
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)
				end
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
				end
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
				end
				if canSpawnQueen then
					return CreateUnit(config.queenName, x, y, z, mRandom(0,3), raptorTeamID)
				end
			end
		end
		return nil
	end

	function Wave()


		if gameOver then
			return
		end

		squadManagerKillerLoop()
		waveParameters.waveCounter = waveParameters.waveCounter + 1
		waveParameters.baseCooldown = waveParameters.baseCooldown - 1
		waveParameters.airWave.cooldown = waveParameters.airWave.cooldown - 1
		waveParameters.basicWave.cooldown = waveParameters.basicWave.cooldown - 1
		waveParameters.specialWave.cooldown = waveParameters.specialWave.cooldown - 1
		waveParameters.smallWave.cooldown = waveParameters.smallWave.cooldown - 1
		waveParameters.largerWave.cooldown = waveParameters.largerWave.cooldown - 1
		waveParameters.hugeWave.cooldown = waveParameters.hugeWave.cooldown - 1
		waveParameters.epicWave.cooldown = waveParameters.epicWave.cooldown - 1

		waveParameters.waveSpecialPercentage = mRandom(5,25)
		waveParameters.waveAirPercentage = mRandom(5,33)

		waveParameters.waveSizeMultiplier = mRandom(5,20)*0.1
		waveParameters.waveTimeMultiplier = mRandom(5,20)*0.1

		if waveParameters.baseCooldown <= 0 then
			-- special waves
			if techAnger > config.airStartAnger and waveParameters.airWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.airWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = mRandom(5,25)
				waveParameters.waveAirPercentage = 75
				waveParameters.waveSizeMultiplier = 2
				waveParameters.waveTimeMultiplier = 2

			elseif waveParameters.specialWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.specialWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 50
				waveParameters.waveAirPercentage = mRandom(5,33)

				waveParameters.waveSizeMultiplier = 2
				waveParameters.waveTimeMultiplier = 2

			elseif waveParameters.basicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.basicWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 0
				waveParameters.waveAirPercentage = 0

				waveParameters.waveSizeMultiplier = 2
				waveParameters.waveTimeMultiplier = 2

			elseif waveParameters.smallWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.smallWave.cooldown = mRandom(0,10)

				waveParameters.waveSizeMultiplier = 0.5
				waveParameters.waveTimeMultiplier = 0.5

			elseif waveParameters.largerWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.largerWave.cooldown = mRandom(0,25)

				waveParameters.waveSizeMultiplier = 1.5
				waveParameters.waveTimeMultiplier = 1.5

				waveParameters.waveAirPercentage = mRandom(5,20)
				waveParameters.waveSpecialPercentage = mRandom(5,20)

			elseif waveParameters.hugeWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.hugeWave.cooldown = mRandom(0,50)

				waveParameters.waveSizeMultiplier = 3
				waveParameters.waveTimeMultiplier = 2

				waveParameters.waveAirPercentage = mRandom(5,15)
				waveParameters.waveSpecialPercentage = mRandom(5,15)

			elseif waveParameters.epicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.epicWave.cooldown = mRandom(0,100)

				waveParameters.waveSizeMultiplier = 5
				waveParameters.waveTimeMultiplier = 2.5

				waveParameters.waveAirPercentage = mRandom(5,10)
				waveParameters.waveSpecialPercentage = mRandom(5,10)

			end

		end

		waveParameters.waveSizeMultiplier = waveParameters.waveSizeMultiplier*waveParameters.firstWavesBoost

		local cCount = 0
		local loopCounter = 0
		local squadCounter = 0

		repeat
			loopCounter = loopCounter + 1
			for burrowID in pairs(burrows) do
				if mRandom() <= config.spawnChance then
					squadCounter = 0
					local airRandom = mRandom(1,100)
					local specialRandom = mRandom(1,100)
					local squad
					if techAnger > config.airStartAnger and airRandom <= waveParameters.waveAirPercentage then
						for _ = 1,1000 do
							if specialRandom <= waveParameters.waveSpecialPercentage then
								local potentialSquad = squadSpawnOptions.specialAir[mRandom(1, #squadSpawnOptions.specialAir)]
								if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
								or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							else
								local potentialSquad = squadSpawnOptions.basicAir[mRandom(1, #squadSpawnOptions.basicAir)]
								if potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger then
									squad = potentialSquad
									break
								end
							end
						end
					else
						for _ = 1,1000 do
							if specialRandom <= waveParameters.waveSpecialPercentage then
								local potentialSquad = squadSpawnOptions.special[mRandom(1, #squadSpawnOptions.special)]
								if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
								or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							else
								local potentialSquad = squadSpawnOptions.basic[mRandom(1, #squadSpawnOptions.basic)]
								if potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger then
									squad = potentialSquad
									break
								end
							end
						end
					end
					if squad then
						for _, squadTable in pairs(squad.units) do
							local unitNumber = squadTable.count
							local raptorName = squadTable.unit
							if UnitDefNames[raptorName] and unitNumber and unitNumber > 0 then
								for j = 1, unitNumber, 1 do
									if mRandom() <= config.spawnChance or j == 1 then
										squadCounter = squadCounter + 1
										table.insert(spawnQueue, { burrow = burrowID, unitName = raptorName, team = raptorTeamID, squadID = squadCounter })
										cCount = cCount + 1
									end
								end
							elseif not UnitDefNames[raptorName] then
								Spring.Echo("[ERROR] Invalid Raptor Unit Name", raptorName)
							else
								Spring.Echo("[ERROR] Invalid Raptor Squad", raptorName)
							end
						end
					end
					if loopCounter <= 1 then
						squad = nil
						squadCounter = 0
						for _ = 1,1000 do
							local potentialSquad = squadSpawnOptions.healer[mRandom(1, #squadSpawnOptions.healer)]
							if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger) then -- Super Squad
								squad = potentialSquad
								break
							end
						end
						if squad then
							for _, squadTable in pairs(squad.units) do
								local unitNumber = squadTable.count
								local raptorName = squadTable.unit
								if UnitDefNames[raptorName] and unitNumber and unitNumber > 0 then
									for j = 1, unitNumber, 1 do
										if mRandom() <= config.spawnChance or j == 1 then
											squadCounter = squadCounter + 1
											table.insert(spawnQueue, { burrow = burrowID, unitName = raptorName, team = raptorTeamID, squadID = squadCounter })
											cCount = cCount + 1
										end
									end
								elseif not UnitDefNames[raptorName] then
									Spring.Echo("[ERROR] Invalid Raptor Unit Name", raptorName)
								else
									Spring.Echo("[ERROR] Invalid Raptor Squad", raptorName)
								end
							end
						end
					end
				end
			end
		until (cCount > currentMaxWaveSize*waveParameters.waveSizeMultiplier or loopCounter >= 200*config.raptorSpawnMultiplier)

		if config.useWaveMsg then
			raptorEvent("wave", cCount)
		end

		waveParameters.firstWavesBoost = math.max(1, waveParameters.firstWavesBoost - 1)

		return cCount
	end

	function spawnCreepStructure(unitDefName, spread)
		tracy.ZoneBeginN("Raptors:spawnCreepStructure")
		local canSpawnStructure = false
		spread = spread or 128
		local spawnPosX, spawnPosY, spawnPosZ

		if config.useScum then -- If creep/scum is enabled, only allow to spawn turrets on the creep
			if spread < MAPSIZEX - spread and spread < MAPSIZEZ - spread then
				local flatCheck, occupancyCheck, scumCheck = 0,0,0
				for _ = 1,5 do
					spawnPosX = mRandom(spread, MAPSIZEX - spread)
					spawnPosZ = mRandom(spread, MAPSIZEZ - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true) -- 90% of map should be flat
					flatCheck = flatCheck + 1
					if canSpawnStructure then
						canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread) -- spread about 96 is suspicious, Probably this fails the most ofte
						occupancyCheck = occupancyCheck + 1
					end
					if canSpawnStructure then
						canSpawnStructure = GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ) -- this is a func of creep coverage, assume ~50 % of map covered
						scumCheck = scumCheck + 1
					end
					if canSpawnStructure then
						break
					end
				end
			end
			if tracy then
				--tracy.Message(string.format("spawnCreepStructure: %s, flatCheck=%d, occupancyCheck=%d, scumCheck=%d", unitDefName, flatCheck, occupancyCheck, scumCheck))
				-- testing determined that its mostly occupancy and scum check failing, as expected
			end
		else -- Otherwise use Raptor LoS as creep with Players sensors being the safety zone
			for _ = 1,5 do
				spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
				spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
				spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
				canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				end
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, true, true)
				end
				if canSpawnStructure then
					canSpawnStructure = not (positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, raptorAllyTeamID, true, false, false)) -- we need to reverse result of this, because we want this to be true when pos is in LoS of Raptor team, and the visibility check does the opposite.
				end
				if canSpawnStructure then
					break
				end
			end
		end

		if canSpawnStructure then
			local structureUnitID = Spring.CreateUnit(unitDefName, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), raptorTeamID)
			if structureUnitID then
				SetUnitBlocking(structureUnitID, false, false)
				tracy.ZoneEnd()
				return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
			else
				if tracy then
					tracy.Message(string.format("spawnCreepStructure: Failed to spawn %s at %d*%d*%d ", unitDefName, spawnPosX, spawnPosY, spawnPosZ ))
				end
			end
		end
		tracy.ZoneEnd()
	end

	function spawnCreepStructuresWave()
		tracy.ZoneBeginN("Raptors:spawnCreepStructuresWave")
		for uName, uSettings in pairs(config.raptorTurrets) do
			if not uSettings.maxQueenAnger then uSettings.maxQueenAnger = uSettings.minQueenAnger + 100 end
			if uSettings.minQueenAnger <= techAnger and uSettings.maxQueenAnger >= techAnger then
				local numOfTurrets = (uSettings.spawnedPerWave*(1-config.raptorPerPlayerMultiplier))+(uSettings.spawnedPerWave*config.raptorPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8))
				local maxExisting = (uSettings.maxExisting*(1-config.raptorPerPlayerMultiplier))+(uSettings.maxExisting*config.raptorPerPlayerMultiplier)*(math.min(SetCount(humanTeams), 8))
				local maxAllowedToSpawn
				if techAnger <= 100 then  -- i don't know how this works but it does. scales maximum amount of turrets allowed to spawn with techAnger.
					maxAllowedToSpawn = math.ceil(maxExisting*((techAnger-uSettings.minQueenAnger)/(math.min(100-uSettings.minQueenAnger, uSettings.maxQueenAnger-uSettings.minQueenAnger))))
				else
					maxAllowedToSpawn = math.ceil(maxExisting*(techAnger*0.01))
				end
				--Spring.Echo(uName,"MaxExisting",maxExisting,"MaxAllowed",maxAllowedToSpawn)
				local currentCountOfTurretDef = Spring.GetTeamUnitDefCount(raptorTeamID, UnitDefNames[uName].id)

				if currentCountOfTurretDef < UnitDefNames[uName].maxThisUnit then  -- cause nutty raptors sets maxThisUnit which results in nil returns from Spring.CreateUnit!
					for i = 1, math.ceil(numOfTurrets) do
						if mRandom() < config.spawnChance*math.min((GetGameSeconds()/config.gracePeriod),1) and (currentCountOfTurretDef <= maxAllowedToSpawn) then
							if i <= numOfTurrets or math.random() <= numOfTurrets%1 then
								local attempts = 0
								local footprintX = UnitDefNames[uName].xsize -- why the fuck is this footprint *2??????
								local footprintZ = UnitDefNames[uName].zsize -- why the fuck is this footprint *2??????
								local footprintAvg = 128
								if footprintX and footprintZ then
									footprintAvg = ((footprintX+footprintZ))*4 -- this is about (8 + 8) * 4 == 64 on average
								end
								repeat
									attempts = attempts + 1
									local turretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(uName, footprintAvg+32) -- call with 96 on average
									if turretUnitID then
										currentCountOfTurretDef = currentCountOfTurretDef + 1
										setRaptorXP(turretUnitID)
										Spring.GiveOrderToUnit(turretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
									end
								until turretUnitID or attempts > 10
							end
						end
					end
				end
			end
		end
		tracy.ZoneEnd()
	end

	function SpawnMinions(unitID, unitDefID)
		local unitName = UnitDefs[unitDefID].name
		if config.raptorMinions[unitName] then
			local minion = config.raptorMinions[unitName][mRandom(1,#config.raptorMinions[unitName])]
			SpawnRandomOffWaveSquad(unitID, minion, 4)
		end
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)

		local unitDef = UnitDefs[unitDefID]

		if unitTeam == raptorTeamID then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{config.defaultRaptorFirestate},0)
			if unitDef.canCloak then
				Spring.GiveOrderToUnit(unitID,37382,{1},0)
			end
			return
		end

		-- For each squadTargetsByEcoWeight, remove them
		for _,unitList in pairs(squadTargetsByEcoWeight) do
			unitList:Remove(unitID)
		end

		-- If a wall
		if isObject[unitDefID] then
			return
		end

		if not unitDef.canMove or (unitDef.customParams and unitDef.customParams.iscommander) then
			-- Calculate an eco value based on energy and metal production
			local ecoValue = 1
			if unitDef.energyMake then
				ecoValue = ecoValue + unitDef.energyMake
			end
			if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
				ecoValue = ecoValue - unitDef.energyUpkeep
			end
			if unitDef.windGenerator then
				ecoValue = ecoValue + unitDef.windGenerator*0.75
			end
			if unitDef.tidalGenerator then
				ecoValue = ecoValue + unitDef.tidalGenerator*15
			end
			if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
				ecoValue = ecoValue + 200
			end
			if unitDef.customParams and unitDef.customParams.energyconv_capacity then
				ecoValue = ecoValue + tonumber(unitDef.customParams.energyconv_capacity) / 2
			end

			-- Decoy fusion support
			if unitDef.customParams and unitDef.customParams.decoyfor == "armfus" then
				ecoValue = ecoValue + 1000
			end

			-- Make it extra risky to build T2 eco
			if unitDef.customParams and unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) > 1 then
				ecoValue = ecoValue * tonumber(unitDef.customParams.techlevel) * 2
			end

			-- Anti-nuke - add value to force players to go T2 economy, rather than staying T1
			if unitDef.customParams and (unitDef.customParams.unitgroup == "antinuke" or unitDef.customParams.unitgroup == "nuke") then
				ecoValue = 1000
			end
			-- Spring.Echo("Built units eco value: " .. ecoValue)

			-- Ends up building an object like:
			-- {
			--  0: [non-eco]
			--	25: [t1 windmill, t1 solar, t1 mex],
			--	75: [adv solar]
			--	1000: [fusion]
			--	3000: [adv fusion]
			-- }

			if not squadTargetsByEcoWeight[ecoValue] then
				squadTargetsByEcoWeight[ecoValue] = SetListUtilities.NewSetListNoTable()
			end

			squadTargetsByEcoWeight[ecoValue]:Add(unitID)
		end

		if config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue + (config.ecoBuildingsPenalty[unitDefID]/(config.queenTime/3600)) -- scale to 60minutes = 3600seconds queen time
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if unitTeam == raptorTeamID then
			if attackerTeam == raptorTeamID and (not (attackerDefID and config.raptorBehaviours.ALLOWFRIENDLYFIRE[attackerDefID])) then
				return 0
			end

			damage = damage / config.healthMod
		end

		if attackerTeam == raptorTeamID then
			damage = damage * config.damageMod
		end

		if heroRaptor[unitID] then
			damage = (damage * heroRaptor[unitID])
		end

		if queenIDs[unitID] then -- Queen Resistance
			if attackerDefID then
				if weaponID == -1 and damage > 1 then
					damage = 1
				end
				attackerDefID = tostring(attackerDefID)
				if not queenResistance[attackerDefID] then
					queenResistance[attackerDefID] = {
						damage = damage * 4 * config.queenResistanceMult,
						notify = 0
					}
				end
				local resistPercent = math.min((queenResistance[attackerDefID].damage) / aliveBossesMaxHealth, 0.95)
				if resistPercent > 0.5 then
					if queenResistance[attackerDefID].notify == 0 then
						raptorEvent("queenResistance", tonumber(attackerDefID))
						queenResistance[attackerDefID].notify = 1
						if mRandom() < config.spawnChance then
							local squad
							local squadCounter = 0
							for _ = 1,1000 do
								local potentialSquad = squadSpawnOptions.healer[mRandom(1, #squadSpawnOptions.healer)]
								if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							end
							if squad then
								for _, squadTable in pairs(squad.units) do
									local unitNumber = squadTable.count
									local raptorName = squadTable.unit
									if UnitDefNames[raptorName] and unitNumber and unitNumber > 0 then
										for j = 1, unitNumber, 1 do
											if mRandom() <= config.spawnChance or j == 1 then
												squadCounter = squadCounter + 1
												table.insert(spawnQueue, { burrow = unitID, unitName = raptorName, team = raptorTeamID, squadID = squadCounter })
											end
										end
									elseif not UnitDefNames[raptorName] then
										Spring.Echo("[ERROR] Invalid Raptor Unit Name", raptorName)
									else
										Spring.Echo("[ERROR] Invalid Raptor Squad", raptorName)
									end
								end
							end
						end
						for _ = 1,SetCount(humanTeams) do
							if mRandom() < config.spawnChance then
								SpawnMinions(unitID, Spring.GetUnitDefID(unitID))
							end
						end
						spawnCreepStructuresWave()
					end

				end
				damage = damage - (damage * resistPercent)
				queenResistance[attackerDefID].damage = queenResistance[attackerDefID].damage + (damage * 4 * config.queenResistanceMult)
				queenResistance[attackerDefID].percent = resistPercent
			else
				damage = 1
			end
			return damage
		end
		return damage, 1
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		if config.raptorBehaviours.SKIRMISH[attackerDefID] and (unitTeam ~= raptorTeamID) and attackerID and (mRandom() < config.raptorBehaviours.SKIRMISH[attackerDefID].chance) and unitTeam ~= attackerTeam then
			local ux, uy, uz = GetUnitPosition(unitID)
			local x, y, z = GetUnitPosition(attackerID)
			if x and ux then
				local angle = math.atan2(ux - x, uz - z)
				local distance = mRandom(math.ceil(config.raptorBehaviours.SKIRMISH[attackerDefID].distance*0.75), math.floor(config.raptorBehaviours.SKIRMISH[attackerDefID].distance*1.25))
				if config.raptorBehaviours.SKIRMISH[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x, y, z)
					Spring.SetUnitPosition(attackerID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
					Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance))
					unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.raptorBehaviours.SKIRMISH[attackerDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
				end
				unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
			end
		elseif config.raptorBehaviours.COWARD[unitDefID] and (unitTeam == raptorTeamID) and attackerID and (mRandom() < config.raptorBehaviours.COWARD[unitDefID].chance) and unitTeam ~= attackerTeam then
			local curH, maxH = GetUnitHealth(unitID)
			if curH and maxH and curH < (maxH * 0.8) then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				if x and ax then
					local angle = math.atan2(ax - x, az - z)
					local distance = mRandom(math.ceil(config.raptorBehaviours.COWARD[unitDefID].distance*0.75), math.floor(config.raptorBehaviours.COWARD[unitDefID].distance*1.25))
					if config.raptorBehaviours.COWARD[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
						GG.ScavengersSpawnEffectUnitDefID(unitDefID, x, y, z)
						Spring.SetUnitPosition(unitID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
						Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
						GG.ScavengersSpawnEffectUnitDefID(unitDefID, x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance))
						unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.raptorBehaviours.COWARD[unitDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					end
					unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
				end
			end
		elseif config.raptorBehaviours.BERSERK[unitDefID] and (unitTeam == raptorTeamID) and attackerID and (mRandom() < config.raptorBehaviours.BERSERK[unitDefID].chance) and unitTeam ~= attackerTeam then
			local ax, ay, az = GetUnitPosition(attackerID)
			local x, y, z = GetUnitPosition(unitID)
			local separation = Spring.GetUnitSeparation(unitID, attackerID)
			if ax and separation < (config.raptorBehaviours.BERSERK[unitDefID].distance or 10000) then
				if config.raptorBehaviours.BERSERK[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
					GG.ScavengersSpawnEffectUnitDefID(unitDefID, x, y, z)
					ax = ax + mRandom(-64,64)
					az = az + mRandom(-64,64)
					Spring.SetUnitPosition(unitID, ax, ay, az)
					Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, ax, ay, az)
					unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.raptorBehaviours.BERSERK[unitDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
				end
				unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
			end
		elseif config.raptorBehaviours.BERSERK[attackerDefID] and (unitTeam ~= raptorTeamID) and attackerID and (mRandom() < config.raptorBehaviours.BERSERK[attackerDefID].chance) and unitTeam ~= attackerTeam then
			local ax, ay, az = GetUnitPosition(unitID)
			local x, y, z = GetUnitPosition(attackerID)
			local separation = Spring.GetUnitSeparation(unitID, attackerID)
			if ax and separation < (config.raptorBehaviours.BERSERK[attackerDefID].distance or 10000) then
				if config.raptorBehaviours.BERSERK[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
					GG.ScavengersSpawnEffectUnitDefID(attackerDefID, x, y, z)
					ax = ax + mRandom(-64,64)
					az = az + mRandom(-64,64)
					Spring.SetUnitPosition(attackerID, ax, ay, az)
					Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
					GG.ScavengersSpawnEffectUnitDefID(unitDefID, ax, ay, az)
					unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.raptorBehaviours.BERSERK[attackerDefID].teleportcooldown*30
				else
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
				end
				unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
			end
		end
		if queenIDs[unitID] then
			local curH, maxH = GetUnitHealth(unitID)
			if curH and maxH then
				curH = math.max(curH, maxH*0.05)
				local spawnChance = math.max(0, math.ceil(curH/maxH*10000))
				if mRandom(0,spawnChance) == 1 then
					SpawnMinions(unitID, Spring.GetUnitDefID(unitID))
					SpawnMinions(unitID, Spring.GetUnitDefID(unitID))
				end
			end
			if attackerTeam and attackerTeam ~= raptorTeamID then
				bosses.playerDamages[tostring(attackerTeam)] = (bosses.playerDamages[tostring(attackerTeam)] or 0) + damage
			end
		end
		if unitTeam == raptorTeamID or attackerTeam == raptorTeamID then
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
			local _, _, _, _, _, luaAllyID = Spring.GetTeamInfo(raptorTeamID, false)
			if luaAllyID then
				lsx1, lsz1, lsx2, lsz2 = RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax
				if not lsx1 or not lsz1 or not lsx2 or not lsz2 then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Raptor start box available, Burrow Placement set to 'Avoid Players'")
					noRaptorStartbox = true
				elseif lsx1 == 0 and lsz1 == 0 and lsx2 == Game.mapSizeX and lsz2 == Game.mapSizeX then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Raptor start box available, Burrow Placement set to 'Avoid Players'")
					noRaptorStartbox = true
				end
			end
		end
		if not lsx1 then lsx1 = 0 end
		if not lsz1 then lsz1 = 0 end
		if not lsx2 then lsx2 = Game.mapSizeX end
		if not lsz2 then lsz2 = Game.mapSizeZ end
	end

	local function SpawnRaptors()
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
			local x, y, z = getRaptorSpawnLoc(defs.burrow, config.raptorBehaviours.PROBE_UNIT)
			if not x or not y or not z then
				spawnQueue[i] = nil
				return
			end
			local unitID = CreateUnit(defs.unitName, x, y, z, mRandom(0,3), defs.team)

			if unitID then
				if (not defs.squadID) or (defs.squadID and defs.squadID == 1) then
					if #squadCreationQueue.units > 0 then
						if mRandom(1,5) == 1 then
							squadCreationQueue.regroupenabled = false
						end
						createSquad(squadCreationQueue)
						squadDone = true
					end
				end
				if defs.burrow and (not squadCreationQueue.burrow) then
					squadCreationQueue.burrow = defs.burrow
				end
				squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
				if config.raptorBehaviours.HEALER[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "healer"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().raptor_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().raptor_spawntimemult)
					end
				end
				if config.raptorBehaviours.ARTILLERY[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "artillery"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().raptor_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().raptor_spawntimemult)
					end
				end
				if config.raptorBehaviours.KAMIKAZE[UnitDefNames[defs.unitName].id] then
					squadCreationQueue.role = "kamikaze"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().raptor_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().raptor_spawntimemult)
					end
				end
				if UnitDefNames[defs.unitName].canFly then
					squadCreationQueue.role = "aircraft"
					squadCreationQueue.regroupenabled = false
					if squadCreationQueue.life < math.ceil(100*Spring.GetModOptions().raptor_spawntimemult) then
						squadCreationQueue.life = math.ceil(100*Spring.GetModOptions().raptor_spawntimemult)
					end
				end

				GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, { "shift" })
				GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })
				GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })

				setRaptorXP(unitID)
				if mRandom() < 0.1 then
					local mod = 0.75 - (mRandom() * 0.25)
					if mRandom() < 0.1 then
						mod = mod - (mRandom() * 0.2)
						if mRandom() < 0.1 then
							mod = mod - (mRandom() * 0.2)
						end
					end
					heroRaptor[unitID] = mod
				end
			end
			spawnQueue[i] = nil
		until squadDone == true
	end

	local function updateSpawnQueen()
		if nSpawnedQueens < nTotalQueens and not gameOver then
			-- spawn queen if not exists
			local queenID = SpawnQueen()
			if queenID then
				nSpawnedQueens = nSpawnedQueens + 1
				queenIDs[queenID] = true
				bosses.statuses[tostring(queenID)] = {}

				local queenSquad = table.copy(squadCreationQueueDefaults)
				queenSquad.life = 999999
				queenSquad.role = "raid"
				queenSquad.units = {queenID}
				createSquad(queenSquad)
				spawnQueue = {}
				raptorEvent("queen") -- notify unsynced about queen spawn
				local _, queenMaxHP = GetUnitHealth(queenID)
				Spring.SetUnitHealth(queenID, math.max(queenMaxHP*(techAnger*0.01), queenMaxHP*0.2))
				SetUnitExperience(queenID, 0)
				timeOfLastWave = t
				for burrowID, _ in pairs(burrows) do
					if mRandom() < config.spawnChance then
						SpawnRandomOffWaveSquad(burrowID, config.miniBosses[mRandom(1,#config.miniBosses)], 1)
						SpawnRandomOffWaveSquad(burrowID)
					else
						SpawnRandomOffWaveSquad(burrowID)
					end
				end
				Spring.SetGameRulesParam("BossFightStarted", 1)
				Spring.SetUnitAlwaysVisible(queenID, true)
			end
			return
		end

		for queenID, _ in pairs(queenIDs) do
			if mRandom() < config.spawnChance / 15 then
				for i = 1,config.queenSpawnMult do
					SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
					SpawnMinions(queenID, Spring.GetUnitDefID(queenID))

				end
			end
		end
	end

	function updateRaptorSpawnBox()
		if config.burrowSpawnType == "initialbox_post" then
			lsx1 = math.max(RaptorStartboxXMin - ((MAPSIZEX*0.01) * techAnger), 0)
			lsz1 = math.max(RaptorStartboxZMin - ((MAPSIZEZ*0.01) * techAnger), 0)
			lsx2 = math.min(RaptorStartboxXMax + ((MAPSIZEX*0.01) * techAnger), MAPSIZEX)
			lsz2 = math.min(RaptorStartboxZMax + ((MAPSIZEZ*0.01) * techAnger), MAPSIZEZ)
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

	local raptorEggColors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}

	function spawnRandomEgg(x,y,z,name)

		local unit = UnitDefNames[name]

		local featureValueMetal = math.ceil(unit.metalCost)
		local featureValueEnergy = featureValueMetal

		local size
		local color
		local chance

		if featureValueMetal <= 1500 then
			size = "s"
			chance = 0.33
		elseif featureValueMetal <= 7500 then
			size = "m"
			chance = 0.66
			featureValueMetal = math.ceil(featureValueMetal*0.66)
			featureValueEnergy = math.ceil(featureValueEnergy*0.66)
		else
			size = "l"
			chance = 1
			featureValueMetal = math.ceil(featureValueMetal*0.33)
			featureValueEnergy = math.ceil(featureValueEnergy*0.33)
		end

		if mRandom() <= chance then

			if config.raptorEggs[name] and config.raptorEggs[name] ~= "" then
				color = config.raptorEggs[name]
			else
				color = raptorEggColors[mRandom(1,#raptorEggColors)]
			end

			local egg = Spring.CreateFeature("raptor_egg_"..size.."_"..color, x, y + 20, z, mRandom(-999999,999999), raptorTeamID)
			if egg then
				Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
				Spring.SetFeatureVelocity(egg, mRandom(-30,30)*0.01, mRandom(150,350)*0.01, mRandom(-30,30)*0.01)
				Spring.SetFeatureResources(egg, featureValueMetal, featureValueEnergy, featureValueMetal*10, 1.0, featureValueMetal, featureValueEnergy)
			end

		end

	end

	function decayRandomEggs()
		tracy.ZoneBeginN("Raptors:decayRandomEggs")
		for eggID, _ in pairs(aliveEggsTable) do
			if mRandom(1,18) == 1 then -- scaled to decay 1000hp egg in about 1 and half minutes +/- RNG
				--local fx, fy, fz = Spring.GetFeaturePosition(eggID)
				Spring.SetFeatureHealth(eggID, Spring.GetFeatureHealth(eggID) - 40)
				if Spring.GetFeatureHealth(eggID) <= 0 then
					Spring.DestroyFeature(eggID)
				end
			end
		end
		tracy.ZoneEnd()
	end

	function gadget:TrySpawnBurrow(t)
		local maxSpawnRetries = math.floor((config.gracePeriod-t)/spawnRetryTimeDiv)
		local spawned = SpawnBurrow()
		timeOfLastSpawn = t
		if not fullySpawned then
			local burrowCount = SetCount(burrows)
			if burrowCount > 1 then
				fullySpawned = true
			elseif spawnRetries >= maxSpawnRetries or firstSpawn then
				spawnAreaMultiplier = spawnAreaMultiplier + 1
				RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = EnemyLib.GetAdjustedStartBox(raptorAllyTeamID, config.burrowSize*1.5*spawnAreaMultiplier)
				gadget:SetInitialSpawnBox()
				spawnRetries = 0
			else
				spawnRetries = spawnRetries + 1
			end
		end
		if firstSpawn and spawned then
			timeOfLastWave = (config.gracePeriod + 10) - config.raptorSpawnRate
			firstSpawn = false
		end
	end

	local announcedFirstWave = false
	function gadget:GameFrame(n)

		if announcedFirstWave == false and GetGameSeconds() > config.gracePeriod then
			raptorEvent("firstWave")
			announcedFirstWave = true
		end
		-- remove initial commander (no longer required)
		if n == 1 then
			PutRaptorAlliesInRaptorTeam(n)
			local units = GetTeamUnits(raptorTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			return
		end

		local raptorTeamUnitCount = GetTeamUnitCount(raptorTeamID) or 0
		if raptorTeamUnitCount < raptorUnitCap and (n%5 == 4 or waveParameters.firstWavesBoost > 1) then
			tracy.ZoneBeginN("Raptors:SpawnRaptors")
			SpawnRaptors()
			tracy.ZoneEnd()
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
			SetGameRulesParam("raptorPlayerAggressionLevel", playerAggressionLevel)
			if nSpawnedQueens == 0 then
				currentMaxWaveSize = (minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))
			else
				currentMaxWaveSize = math.ceil((minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))*(config.bossFightWaveSizeScale*0.01))
			end
			if pastFirstQueen or Spring.GetModOptions().raptor_graceperiodmult <= 1 then
				techAnger = (t - config.gracePeriod) / ((queenTime/(Spring.GetModOptions().raptor_queentimemult)) - config.gracePeriod) * 100
			else
				techAnger = (t - (config.gracePeriod/Spring.GetModOptions().raptor_graceperiodmult)) / ((queenTime/(Spring.GetModOptions().raptor_queentimemult)) - (config.gracePeriod/Spring.GetModOptions().raptor_graceperiodmult)) * 100
			end
			techAnger = math.clamp(techAnger, 0, 999)

			techAnger = math.ceil(techAnger*((config.economyScale*0.5)+0.5))

			if t < config.gracePeriod then
				queenAnger = 0
				minBurrows = math.ceil(math.max(4, 2*(math.min(SetCount(humanTeams), 8)))*(t/config.gracePeriod))
			else
				if nSpawnedQueens == 0 then
					queenAnger = math.clamp(math.ceil((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100) + queenAngerAggressionLevel, 0, 100)
					minBurrows = 1
				else
					queenAnger = 100
					if Spring.GetModOptions().raptor_endless then
						minBurrows = 4
					else
						minBurrows = 1
					end
				end
				queenAngerAggressionLevel = queenAngerAggressionLevel + ((playerAggression*0.01)/(config.queenTime/3600)) + playerAggressionEcoValue
				SetGameRulesParam("RaptorQueenAngerGain_Aggression", (playerAggression*0.01)/(config.queenTime/3600))
				SetGameRulesParam("RaptorQueenAngerGain_Eco", playerAggressionEcoValue)
			end
			SetGameRulesParam("raptorQueenAnger", math.floor(queenAnger))
			SetGameRulesParam("raptorTechAnger", math.floor(techAnger))

			if queenAnger >= 100 or (burrowCount <= 1 and t > config.gracePeriod) then
				-- check if the queen should be alive
				updateSpawnQueen()
			end
			updateQueenHealth()

			if burrowCount < minBurrows then
				gadget:TrySpawnBurrow(t)
			end

			if (t > config.burrowSpawnRate and burrowCount < minBurrows and (t > timeOfLastSpawn + 10 or burrowCount == 0)) or (config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if (config.burrowSpawnType == "initialbox") and (t > config.gracePeriod) then
					config.burrowSpawnType = "initialbox_post"
				end
				gadget:TrySpawnBurrow(t)
				raptorEvent("burrowSpawn")
				SetGameRulesParam("raptor_hiveCount", SetCount(burrows))
			elseif config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount >= maxBurrows then
				timeOfLastSpawn = t
			end

			if t > config.gracePeriod+5 then
				if burrowCount > 0
				and SetCount(spawnQueue) == 0
				and ((config.raptorSpawnRate*waveParameters.waveTimeMultiplier) < (t - timeOfLastWave)) then
					Wave()
					timeOfLastWave = t
				end
			end

			updateRaptorSpawnBox()
		end
		if n%((math.ceil(config.turretSpawnRate))*30) == 0 and n > 900 and raptorTeamUnitCount < raptorUnitCap then
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
			local raptors = GetTeamUnits(raptorTeamID)
			for i = 1,#raptors do
				if mRandom(1,math.ceil((33*math.max(1, Spring.GetTeamUnitDefCount(raptorTeamID, Spring.GetUnitDefID(raptors[i])))))) == 1 and mRandom() < config.spawnChance then
					SpawnMinions(raptors[i], Spring.GetUnitDefID(raptors[i]))
				end
				if mRandom(1,60) == 1 then
					if unitCowardCooldown[raptors[i]] and (Spring.GetGameFrame() > unitCowardCooldown[raptors[i]]) then
						unitCowardCooldown[raptors[i]] = nil
						Spring.GiveOrderToUnit(raptors[i], CMD.STOP, 0, 0)
					end
					if Spring.GetUnitCommandCount(raptors[i]) == 0 then
						if unitCowardCooldown[raptors[i]] then
							unitCowardCooldown[raptors[i]] = nil
						end
						local squadID = unitSquadTable[raptors[i]]
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
							Spring.GiveOrderToUnit(raptors[i], CMD.FIGHT, {pos.x, pos.y, pos.z}, {})
						end
					end
				end
			end
		end
		if n%6 == 2 then
			decayRandomEggs()
		end
		manageAllSquads()
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)

		if unitTeam == raptorTeamID then
			if config.useEggs then
				local x,y,z = Spring.GetUnitPosition(unitID)
				spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
			end
			if unitDefID == config.burrowDef then
				if mRandom() <= config.spawnChance then
					spawnCreepStructuresWave()
				end
			end
		end

		if heroRaptor[unitID] then
			heroRaptor[unitID] = nil
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

		for _,unitList in pairs(squadTargetsByEcoWeight) do
			unitList:Remove(unitID)
		end

		for squad in ipairs(unitTargetPool) do
			if unitTargetPool[squad] == unitID then
				refreshSquad(squad)
			end
		end

		if unitTeam == raptorTeamID then
			local kills = GetGameRulesParam("raptor" .. "Kills") or 0
			SetGameRulesParam("raptor" .. "Kills", kills + 1)
		end

		if queenIDs[unitID] then
			nKilledQueens = nKilledQueens + 1
			queenIDs[unitID] = nil
			table.mergeInPlace(bosses.statuses, {[tostring(unitID)] = {isDead = true, health = 0}})
			SetGameRulesParam("raptorQueensKilled", nKilledQueens)

			if nKilledQueens >= nTotalQueens then
				Spring.SetGameRulesParam("BossFightStarted", 0)
				if Spring.GetModOptions().raptor_endless then
					updateDifficultyForSurvival()
				else
					gameOver = GetGameFrame() + 200
					spawnQueue = {}

					if not killedRaptorsAllyTeam then
						killedRaptorsAllyTeam = true

						-- kill raptor team
						Spring.KillTeam(raptorTeamID)

						-- check if scavengers are in the same allyteam and alive
						local scavengersFoundAlive = false
						for _, teamID in ipairs(Spring.GetTeamList(raptorAllyTeamID)) do
							local luaAI = Spring.GetTeamLuaAI(teamID)
							if luaAI and luaAI:find("Scavengers") and not select(3, Spring.GetTeamInfo(teamID, false)) then
								scavengersFoundAlive = true
							end
						end

						-- kill whole allyteam
						if not scavengersFoundAlive then
							for _, teamID in ipairs(Spring.GetTeamList(raptorAllyTeamID)) do
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
			local kills = GetGameRulesParam(config.burrowName .. "Kills") or 0
			SetGameRulesParam(config.burrowName .. "Kills", kills + 1)

			burrows[unitID] = nil
			if attackerID and Spring.GetUnitTeam(attackerID) ~= raptorTeamID then
				playerAggression = playerAggression + (config.angerBonus/config.raptorSpawnMultiplier)
				config.maxXP = config.maxXP*1.01
			end

			for i, defs in pairs(spawnQueue) do
				if defs.burrow == unitID then
					spawnQueue[i] = nil
				end
			end

			SetGameRulesParam("raptor_hiveCount", SetCount(burrows))
		elseif unitTeam == raptorTeamID and UnitDefs[unitDefID].isBuilding and (attackerID and Spring.GetUnitTeam(attackerID) ~= raptorTeamID) then
			playerAggression = playerAggression + ((config.angerBonus/config.raptorSpawnMultiplier)*0.1)
		end
		if unitTeleportCooldown[unitID] then
			unitTeleportCooldown[unitID] = nil
		end
		if unitTeam ~= raptorTeamID and config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue - (config.ecoBuildingsPenalty[unitDefID]/(config.queenTime/3600)) -- scale to 60minutes = 3600seconds queen time
		end
	end

	function gadget:TeamDied(teamID)
		humanTeams[teamID] = nil
		--computerTeams[teamID] = nil
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
		if newTeam == raptorTeamID then
			return false
		else
			return true
		end
	end

	function gadget:FeatureCreated(featureID, featureAllyTeamID)
		if featureAllyTeamID == raptorAllyTeamID then
			local egg = string.find(FeatureDefs[Spring.GetFeatureDefID(featureID)].name, "raptor_egg")
			if egg then
				aliveEggsTable[featureID] = true
			end
		end
	end

	function gadget:FeatureDestroyed(featureID, featureAllyTeamID)
		if aliveEggsTable[featureID] then
			aliveEggsTable[featureID] = nil
		end
	end

	function gadget:GameOver()
		-- don't end game in survival mode
		if config.difficulty ~= config.difficulties.survival then
			gameOver = GetGameFrame()
		end
	end

	-- function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- 	if teamID == raptorTeamID and cmdID == CMD.SELFD then
	-- 		return false
	-- 	else
	-- 		return true
	-- 	end
	-- end

else	-- UNSYNCED

	local hasRaptorEvent = false
	local mRandom = math.random

	local function HasRaptorEvent(ce)
		hasRaptorEvent = (ce ~= "0")
	end

	local function WrapToLuaUI(_, type, num, tech)
		if hasRaptorEvent then
			local raptorEventArgs = {}
			if type ~= nil then
				raptorEventArgs["type"] = type
			end
			if num ~= nil then
				raptorEventArgs["number"] = num
			end
			if tech ~= nil then
				raptorEventArgs["tech"] = tech
			end
			Script.LuaUI.RaptorEvent(raptorEventArgs)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('RaptorEvent', WrapToLuaUI)
		gadgetHandler:AddChatAction("HasRaptorEvent", HasRaptorEvent, "toggles hasRaptorEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasRaptorEvent")
	end


	local nocolorshift = {0,0,0}
	local colorshiftcache = {0,0,0}
	if gl.SetUnitBufferUniforms then
		function gadget:UnitCreated(unitID, unitDefID, unitTeam)
			if string.find(UnitDefs[unitDefID].name, "raptor") then
				gl.SetUnitBufferUniforms(unitID, nocolorshift, 8)
				colorshiftcache[1] = mRandom(-100,100)*0.0001 -- hue (hue hue)
				colorshiftcache[2] = mRandom(-200,200)*0.0001 -- saturation
				colorshiftcache[3] = mRandom(-200,200)*0.0001 -- brightness
				gl.SetUnitBufferUniforms(unitID, colorshiftcache, 8)
			end
		end
	end

end
