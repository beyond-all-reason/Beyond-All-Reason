function gadget:GetInfo()
	return {
		name = "Chicken Defense Spawner",
		desc = "Spawns burrows and chickens",
		author = "TheFatController/quantum, Damgam",
		date = "27 February, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if Spring.Utilities.Gametype.IsChickens() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Chicken Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Chicken Defense Spawner Deactivated!")
	return false
end

local config = VFS.Include('LuaRules/Configs/chicken_spawn_defs.lua')

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
	local GetTeamUnitsCounts = Spring.GetTeamUnitsCounts
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
	local queenLifePercent = 100
	local maxTries = 30
	local chickenUnitCap = math.floor(Game.maxUnits*0.95)
	local damageMod = config.damageMod
	local currentWave = 1
	local lastWaveUnitCount = 0
	local minBurrows = 1
	local timeOfLastSpawn = 0
	local timeOfLastFakeSpawn = 0
	local timeOfLastWave = 0
	local chickenCount = 0
	local t = 0 -- game time in secondstarget
	local timeCounter = 0
	local queenAnger = 0
	local techAnger = 0
	local queenMaxHP = 0
	local playerAgression = 0
	local playerAgressionLevel = 0
	local queenAngerAgressionLevel = 0
	local difficultyCounter = 0
	local firstSpawn = true
	local gameOver = nil
	local humanTeams = {}
	local spawnQueue = {}
	local deathQueue = {}
	local queenResistance = {}
	local queenID
	local chickenTeamID, chickenAllyTeamID
	local lsx1, lsz1, lsx2, lsz2
	local burrows = {}
	local heroChicken = {}
	local broodRaptors1 = {}
	local broodRaptors2 = {}
	local broodRaptors3 = {}
	local unitName = {}
	local unitShortName = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadPotentialTarget = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local unitTeleportCooldown = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = 10,
		regroup = true,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = 10,
		regroup = true,
	}
	
	heavyTurret = "chicken_turretl"
	lightTurret = "chicken_turrets"
	specialHeavyTurrets = {
		"chicken_turretl_acid",
		"chicken_turretl_electric",
	}
	specialLightTurrets = {
		"chicken_turrets_acid",
		"chicken_turrets_electric",
	}

	miniQueenMinions = {
		["chicken_miniqueen_electric"] = {
			"chickene1",
			"chickene2",
			"chickenearty1",
			"chickenelectricallterrain",
			"chickenelectricallterrainassault",
		},
		["chicken_miniqueen_acid"] = {
			"chickenacidswarmer",
			"chickenacidassault",
			"chickenacidarty",
			"chickenacidallterrain",
			"chickenacidallterrainassault",
		},
		["chicken_miniqueen_healer"] = {
			"chickenh1",
			"chickenh1b",
		},
	}

	for unitDefID, unitDef in pairs(UnitDefs) do
		unitName[unitDefID] = unitDef.name
		unitShortName[unitDefID] = string.match(unitDef.name, "%D*")
	end

	--------------------------------------------------------------------------------
	-- Teams
	--------------------------------------------------------------------------------

	local teams = GetTeamList()
	for _, teamID in ipairs(teams) do
		local teamLuaAI = GetTeamLuaAI(teamID)
		if (teamLuaAI and string.find(teamLuaAI, "Chickens")) then
			chickenTeamID = teamID
			chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
			--computerTeams[teamID] = true
		else
			humanTeams[teamID] = true
		end
	end

	local gaiaTeamID = GetGaiaTeamID()
	if not chickenTeamID then
		chickenTeamID = gaiaTeamID
		chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
	else
		--computerTeams[gaiaTeamID] = nil
	end

	humanTeams[gaiaTeamID] = nil

	function PutChickenAlliesInChickenTeam(n)
		local players = Spring.GetPlayerList()
		for i = 1,#players do
			local player = players[i]
			local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
			if allyTeamID == chickenAllyTeamID and (not spectator) then
				Spring.AssignPlayerToTeam(player, chickenTeamID)
				local units = GetTeamUnits(teamID)
				chickenteamhasplayers = true
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
				end
				Spring.KillTeam(teamID)
			end
		end

		local chickenAllies = Spring.GetTeamList(chickenAllyTeamID)
		for i = 1,#chickenAllies do
			local _,_,_,AI = Spring.GetTeamInfo(chickenAllies[i])
			local LuaAI = Spring.GetTeamLuaAI(chickenAllies[i])
			if (AI or LuaAI) and chickenAllies[i] ~= chickenTeamID then
				local units = GetTeamUnits(chickenAllies[i])
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(chickenAllies[i])
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Utility
	--

	local function SetToList(set)
		local list = {}
		local count = 0
		for k in pairs(set) do
			count = count + 1
			list[count] = k
		end
		return list
	end

	local function SetCount(set)
		local count = 0
		for k in pairs(set) do
			count = count + 1
		end
		return count
	end

	local function getRandomMapPos()
		local x = mRandom(16, MAPSIZEX - 16)
		local z = mRandom(16, MAPSIZEZ - 16)
		local y = GetGroundHeight(x, z)
		return { x = x, y = y, z = z }
	end

	local function getRandomEnemyPos()
		local loops = 0
		local targetCount = SetCount(squadPotentialTarget)
		local pos = {}
		local pickedTarget = nil
		repeat
			loops = loops + 1
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

		until pos.x or loops >= 10
		
		if not pos.x then
			pos = getRandomMapPos()
		end

		return pos, pickedTarget
	end

	local function setChickenXP(unitID)
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

	if config.swarmMode then
		config.maxChickens = config.maxChickens*10
		config.minChickens = config.minChickens*10
		config.chickenMaxSpawnRate = config.chickenMaxSpawnRate*10
	end
	-- local expIncrement = ((SetCount(humanTeams) * config.expStep) / config.queenTime)
	local maxBurrows = ((config.maxBurrows*0.75)+(config.maxBurrows*0.25)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	local queenTime = (config.queenTime + config.gracePeriod)
	local maxWaveSize = ((config.maxChickens*0.75)+(config.maxChickens*0.25)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	local currentMaxWaveSize = config.minChickens
	local function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		queenTime = (config.queenTime + config.gracePeriod)
		queenAnger = 0  -- reenable chicken spawning
		techAnger = 0
		playerAgression = 0
		queenAngerAgressionLevel = 0
		SetGameRulesParam("queenAnger", queenAnger)
		local nextDifficulty
		local difficultyCounter = difficultyCounter + 1
		if difficultyCounter == 1 then
			nextDifficulty = config.difficultyParameters[1]
		elseif difficultyCounter == 2 then
			nextDifficulty = config.difficultyParameters[2]
		elseif difficultyCounter == 3 then
			nextDifficulty = config.difficultyParameters[3]
		elseif difficultyCounter == 4 then
			nextDifficulty = config.difficultyParameters[4]
		elseif difficultyCounter == 5 then
			nextDifficulty = config.difficultyParameters[5]
		elseif difficultyCounter > 5 then -- We're already at Epic, just multiply some numbers to make it even harder
			nextDifficulty = config.difficultyParameters[5]
			config.chickenSpawnMultiplier = config.chickenSpawnMultiplier*2
		end
		config.chickenMaxSpawnRate = nextDifficulty.chickenMaxSpawnRate
		config.queenName = nextDifficulty.queenName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.turretSpawnRate = nextDifficulty.turretSpawnRate
		config.queenSpawnMult = nextDifficulty.queenSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxChickens = nextDifficulty.maxChickens
		config.minChickens = nextDifficulty.minChickens
		config.maxBurrows = nextDifficulty.maxBurrows
		config.maxXP = nextDifficulty.maxXP
		config.queenResistanceMult = nextDifficulty.queenResistanceMult
		config.angerBonus = nextDifficulty.angerBonus
		if config.swarmMode then
			config.maxChickens = config.maxChickens*10
			config.minChickens = config.minChickens*10
			config.chickenMaxSpawnRate = config.chickenMaxSpawnRate*10
		end
		-- expIncrement = ((SetCount(humanTeams) * config.expStep) / config.queenTime)
		maxBurrows = ((config.maxBurrows*0.75)+(config.maxBurrows*0.25)*SetCount(humanTeams))*config.chickenSpawnMultiplier
		maxWaveSize = ((config.maxChickens*0.5)+(config.maxChickens*0.5)*SetCount(humanTeams))*config.chickenSpawnMultiplier
		currentMaxWaveSize = config.minChickens
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game Rules
	--

	local UPDATE = 16

	local unitCounts = {}

	local chickenDefTypes = {}
	for unitName in pairs(config.chickenTypes) do
		chickenDefTypes[UnitDefNames[unitName].id] = unitName
		unitCounts[string.sub(unitName, 1, -2)] = { count = 0, lastCount = 0 }
	end

	local function SetupUnit(unitName)
		SetGameRulesParam(unitName .. "Count", 0)
		SetGameRulesParam(unitName .. "Kills", 0)
	end

	SetGameRulesParam("queenTime", queenTime)
	SetGameRulesParam("queenLife", queenLifePercent)
	SetGameRulesParam("queenAnger", queenAnger)
	SetGameRulesParam("gracePeriod", config.gracePeriod)

	for unitName in pairs(config.chickenTypes) do
		SetupUnit(string.sub(unitName, 1, -2))
	end

	for unitName in pairs(config.defenders) do
		SetupUnit(string.sub(unitName, 1, -2))
	end

	SetupUnit(config.burrowName)

	SetGameRulesParam("difficulty", config.difficulty)

	local function UpdateUnitCount()
		local teamUnitCounts = GetTeamUnitsCounts(chickenTeamID)
		local total = 0

		for shortName in pairs(unitCounts) do
			unitCounts[shortName].count = 0
		end

		for unitDefID, number in pairs(teamUnitCounts) do
			if unitShortName[unitDefID] then
				local shortName = unitShortName[unitDefID]
				if unitCounts[shortName] then
					unitCounts[shortName].count = unitCounts[shortName].count + number
				end
			end
		end

		for shortName, counts in pairs(unitCounts) do
			if (counts.count ~= counts.lastCount) then
				SetGameRulesParam(shortName .. "Count", counts.count)
				counts.lastCount = counts.count
			end
			total = total + counts.count
		end

		return total
	end

	local SKIRMISH = {
		[UnitDefNames["chickens1"].id] = { distance = 270, chance = 0.33 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenelectricallterrainassault"].id] = { distance = 200, chance = 0.01 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidswarmer"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { distance = 200, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 0.25 },
	}
	local COWARD = {
		[UnitDefNames["chickenh1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh1b"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickens2"].id] = { distance = 250, chance = 0.5, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenh3"].id] = { distance = 500, chance = 0.25 },
	}
	local BERSERK = {
		[UnitDefNames["ve_chickenq"].id] = { chance = 0.01 },
		[UnitDefNames["e_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["n_chickenq"].id] = { chance = 0.1 },
		[UnitDefNames["h_chickenq"].id] = { chance = 0.2 },
		[UnitDefNames["vh_chickenq"].id] = { chance = 0.3 },
		[UnitDefNames["epic_chickenq"].id] = { chance = 0.5 },
		[UnitDefNames["chickens2"].id] = {chance = 0.2, distance = 750, teleport = true, teleportcooldown = 2,},
		[UnitDefNames["chickena1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena1b"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena1c"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1b"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickenallterraina1c"].id] = { chance = 0.2, distance = 1500 },
		[UnitDefNames["chickena2"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickena2b"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickenapexallterrainassault"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickenapexallterrainassaultb"].id] = { chance = 0.2, distance = 3000 },
		[UnitDefNames["chickene2"].id] = { chance = 0.05 },
		[UnitDefNames["chickenelectricallterrainassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidallterrainassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidswarmer"].id] = { chance = 0.01 },
		[UnitDefNames["chickenacidallterrain"].id] = { chance = 0.01 },
		[UnitDefNames["chickenp1"].id] = { chance = 0.2 },
		[UnitDefNames["chickenp2"].id] = { chance = 0.2 },
		[UnitDefNames["chickenpyroallterrain"].id] = { chance = 0.2 },
		[UnitDefNames["chickenh4"].id] = { chance = 1 },
		[UnitDefNames["chicken_miniqueen_electric"].id] = { chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_acid"].id] = { chance = 0.01 },
		[UnitDefNames["chicken_miniqueen_healer"].id] = { chance = 0.01 },
	}
	local HEALER = {
		[UnitDefNames["chickenh1"].id] = true,
		[UnitDefNames["chickenh1b"].id] = true,
	}
	local ARTILLERY = {
		[UnitDefNames["chickenr1"].id] = true,
		[UnitDefNames["chickenr2"].id] = true,
		[UnitDefNames["chickenearty1"].id] = true,
		[UnitDefNames["chickenacidarty"].id] = true,
	}
	local KAMIKAZE = {
		[UnitDefNames["chicken_dodo1"].id] = true,
		[UnitDefNames["chicken_dodo2"].id] = true,
	}

	local SMALL_UNIT = UnitDefNames["chicken1"].id
	-- local MEDIUM_UNIT = UnitDefNames["chicken1"].id
	-- local LARGE_UNIT = UnitDefNames["chicken1"].id

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Spawn Dynamics
	--

	local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
	local RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = Spring.GetAllyTeamStartBox(chickenAllyTeamID)

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
	local function squadManagerKillerLoop() -- Kills squads that have been alive for too long (most likely stuck somewhere on the map)
		--squadsTable
		for i = 1,#squadsTable do
			
			squadsTable[i].squadLife = squadsTable[i].squadLife - 1
			if squadsTable[i].squadLife < 3 and squadsTable[i].squadRegroup then
				squadsTable[i].squadRegroup = false
			end
			-- Spring.Echo("SquadLifeReport - SquadID: #".. i .. ", LifetimeRemaining: ".. squadsTable[i].squadLife)
			
			if squadsTable[i].squadLife <= 0 then
				-- Spring.Echo("Life is 0, time to do some killing")
				if SetCount(squadsTable[i].squadUnits) > 0 then
					if squadsTable[i].squadBurrow and (not queenID) then
						Spring.DestroyUnit(squadsTable[i].squadBurrow, true, false)
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
						Spring.DestroyUnit(destroyQueue[j], true, false)
					end
					destroyQueue = nil
					-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
				end
			end
		end
	end


	--or Spring.GetGameSeconds() <= config.gracePeriod
	local function squadCommanderGiveOrders(squadID, targetx, targety, targetz)
		local units = squadsTable[squadID].squadUnits
		local role = squadsTable[squadID].squadRole
		if SetCount(units) > 0 and squadsTable[squadID].target and squadsTable[squadID].target.x then
			if squadsTable[squadID].squadRegroup then
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
					if xmin < xaverage-384 or xmax > xaverage+384 or zmin < zaverage-384 or zmax > zaverage+384 then
						targetx = xaverage
						targetz = zaverage
						targety = Spring.GetGroundHeight(targetx, targetz)
						role = "raid"
					end
				end
			end

			for i, unitID in pairs(units) do
				if ValidUnitID(unitID) and not GetUnitIsDead(unitID) and not GetUnitNeutral(unitID) then
					-- Spring.Echo("GiveOrderToUnit #" .. i)
					if not unitCowardCooldown[unitID] then
						if role == "assault" or role == "healer" or role == "artillery" then
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
						elseif role == "raid" or role == "kamikaze" then
							Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
						elseif role == "aircraft" then
							local pos = getRandomEnemyPos()
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x, pos.y, pos.z} , {})
						end
					end
				end
			end
		end
	end

	-- local function refreshSquad(squadID) -- Get new target for a squad
	-- 	local targetCount = SetCount(squadPotentialTarget)
	-- 	local pos = false
	-- 	unitTargetPool[squadID] = nil
	-- 	local loops = 0
	-- 	repeat
	-- 		loops = loops + 1
	-- 		for target in pairs(squadPotentialTarget) do
	-- 			if mRandom(1,targetCount) == 1 then
	-- 				if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
	-- 					local x,y,z = Spring.GetUnitPosition(target)
	-- 					if y >= 0 then
	-- 						pos = {x = x, y = y, z = z}
	-- 						unitTargetPool[squadID] = target
	-- 						break
	-- 					end
	-- 				end
	-- 			end
	-- 		end

	-- 	until pos or loops >= 10
		
	-- 	if not pos then
	-- 		pos, target = getRandomEnemyPos()
	-- 	end

	-- 	squadsTable[squadID].target = pos
		
	-- 	-- Spring.MarkerAddPoint (squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z, "Squad #" .. squadID .. " target")
	-- 	local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
	-- 	squadCommanderGiveOrders(squadID, targetx, targety, targetz)
	-- end

	local function refreshSquad(squadID) -- Get new target for a squad
		local pos, pickedTarget = getRandomEnemyPos()
		--Spring.Echo(pos.x, pos.y, pos.z, pickedTarget)
		unitTargetPool[squadID] = pickedTarget
		squadsTable[squadID].target = pos
		-- Spring.MarkerAddPoint (squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z, "Squad #" .. squadID .. " target")
		local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
		squadCommanderGiveOrders(squadID, targetx, targety, targetz)
	end

	local function createSquad(newSquad)
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
				if mRandom(0,100) <= 40 then
					role = "raid"
				end
			else
				role = newSquad.role
			end
			if not newSquad.life then
				newSquad.life = 10
			end


			squadsTable[squadID] = {
				squadUnits = newSquad.units,
				squadLife = newSquad.life,
				squadRole = role,
				squadRegroup = newSquad.regroup,
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
		-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
	end

	local function manageAllSquads() -- Get new target for all squads that need it
		for i = 1,#squadsTable do
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


	local function getChickenSpawnLoc(burrowID, size)
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

	local function SpawnRandomOffWaveSquad(burrowID, chickenType, count)
		if gameOver then
			return
		end
		local squadCounter = 0
		if chickenType then
			if not count then count = 1 end
			squad = { count .. " " .. chickenType }
			for i, sString in pairs(squad) do
				local nEnd, _ = string.find(sString, " ")
				local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
				local chickenName = string.sub(sString, (nEnd + 1))
				for j = 1, unitNumber, 1 do
					squadCounter = squadCounter + 1
					table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
				end
			end
		else
			local techAngerPerTier = 100/config.wavesAmount
			if techAnger >= 100 then
				currentWave = config.wavesAmount
			else
				currentWave = math.ceil(techAnger/techAngerPerTier)
			end

			if currentWave > config.wavesAmount then
				currentWave = config.wavesAmount
			end

			local waveLevel = currentWave
			local squad = config.basicWaves[waveLevel][mRandom(1, #config.basicWaves[waveLevel])]
			if config.specialWaves[waveLevel] and math.random(1,100) <= 20 then
				squad = config.specialWaves[waveLevel][mRandom(1, #config.specialWaves[waveLevel])]
			elseif config.superWaves[waveLevel] and math.random(1,100) <= 1 then
				squad = config.superWaves[waveLevel][mRandom(1, #config.superWaves[waveLevel])]
			end
			for i, sString in pairs(squad) do
				local nEnd, _ = string.find(sString, " ")
				local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
				local chickenName = string.sub(sString, (nEnd + 1))
				for j = 1, unitNumber, 1 do
					squadCounter = squadCounter + 1
					table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
				end
			end
		end
		return squadCounter
	end

	local function SetupBurrow(unitID, x, y, z)
		burrows[unitID] = 0
		SetUnitBlocking(unitID, false, false)
		setChickenXP(unitID)
		-- spawn some turrets
		if mRandom(1,2) == 1 then
			local turretID = CreateUnit(lightTurret, x-32, y, z-32, mRandom(0,3), chickenTeamID)
			if turretID then
				SetUnitBlocking(turretID, false, false)
				setChickenXP(turretID)
				Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
			end
			local turretID = CreateUnit(lightTurret, x+32, y, z-32, mRandom(0,3), chickenTeamID)
			if turretID then
				SetUnitBlocking(turretID, false, false)
				setChickenXP(turretID)
				Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
			end
			local turretID = CreateUnit(lightTurret, x-32, y, z+32, mRandom(0,3), chickenTeamID)
			if turretID then
				SetUnitBlocking(turretID, false, false)
				setChickenXP(turretID)
				Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
			end
			local turretID = CreateUnit(lightTurret, x+32, y, z+32, mRandom(0,3), chickenTeamID)
			if turretID then
				SetUnitBlocking(turretID, false, false)
				setChickenXP(turretID)
				Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
			end
			-- spawn more turrets sometimes
			if mRandom(1,5) == 1 then
				local turretID = CreateUnit(lightTurret, x+48, y, z, mRandom(0,3), chickenTeamID)
				if turretID then
					SetUnitBlocking(turretID, false, false)
					setChickenXP(turretID)
					Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
				end
				local turretID = CreateUnit(lightTurret, x-48, y, z, mRandom(0,3), chickenTeamID)
				if turretID then
					SetUnitBlocking(turretID, false, false)
					setChickenXP(turretID)
					Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
				end
				local turretID = CreateUnit(lightTurret, x, y, z+48, mRandom(0,3), chickenTeamID)
				if turretID then
					SetUnitBlocking(turretID, false, false)
					setChickenXP(turretID)
					Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
				end
				local turretID = CreateUnit(lightTurret, x, y, z-48, mRandom(0,3), chickenTeamID)
				if turretID then
					SetUnitBlocking(turretID, false, false)
					setChickenXP(turretID)
					Spring.GiveOrderToUnit(turretID, CMD.PATROL, {x, y, z}, {"meta"})
				end
			end
		end
		-- spawn units together with burrow
		if Spring.GetGameSeconds() > config.gracePeriod then
			for i = 1,SetCount(humanTeams)*config.chickenSpawnMultiplier do
				if mRandom() <= config.spawnChance then
					SpawnRandomOffWaveSquad(unitID)
				end
			end
		end
	end

	local function SpawnBurrow(number)

		local unitDefID = UnitDefNames[config.burrowName].id

		for i = 1, (number or 1) do
			local x, z, y
			local tries = 0
			local canSpawnBurrow = false
			repeat
				if config.burrowSpawnType == "initialbox" then
					x = mRandom(lsx1, lsx2)
					z = mRandom(lsz1, lsz2)
				elseif config.burrowSpawnType == "alwaysbox" then
					x = mRandom(lsx1, lsx2)
					z = mRandom(lsz1, lsz2)
				elseif config.burrowSpawnType == "initialbox_post" then
					lsx1 = math.max(lsx1 * 0.99, config.spawnSquare)
					lsz1 = math.max(lsz1 * 0.99, config.spawnSquare)
					lsx2 = math.min(lsx2 * 1.01, MAPSIZEX - config.spawnSquare)
					lsz2 = math.min(lsz2 * 1.01, MAPSIZEZ - config.spawnSquare)
					x = mRandom(lsx1, lsx2)
					z = mRandom(lsz1, lsz2)
				else
					x = mRandom(config.spawnSquare, MAPSIZEX - config.spawnSquare)
					z = mRandom(config.spawnSquare, MAPSIZEZ - config.spawnSquare)
				end

				y = GetGroundHeight(x, z)
				tries = tries + 1

				canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, false)
				
				if canSpawnBurrow then
					if GG.IsPosInChickenScum(x, y, z) and mRandom(1,5) == 1 then
						canSpawnBurrow = true
					else
						if tries < maxTries*3 then
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, true)
						else
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, false)
						end
					end
				end

				if canSpawnBurrow then
					canSpawnBurrow = positionCheckLibrary.OccupancyCheck(x, y, z, config.minBaseDistance*0.25)
				end

				if canSpawnBurrow then
					canSpawnBurrow = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
				end

			until (canSpawnBurrow == true or tries >= maxTries * 4)

			if canSpawnBurrow then
				local unitID = CreateUnit(config.burrowName, x, y, z, mRandom(0,3), chickenTeamID)
				if unitID then
					SetupBurrow(unitID, x, y, z)
				end
			else
				for i = 1,100 do
					local x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
					local z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
					local y = GetGroundHeight(x, z)

					canSpawnBurrow = positionCheckLibrary.StartboxCheck(x, y, z, chickenAllyTeamID, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, false)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
					end
					if canSpawnBurrow then
						local unitID = CreateUnit(config.burrowName, x, y, z, mRandom(0,3), chickenTeamID)
						if unitID then
							SetupBurrow(unitID, x, y, z)
							break
						end
					elseif i == 100 then
						timeOfLastSpawn = 1
					end
				end
			end
		end
	end

	local function updateQueenLife()
		if not queenID then
			return
		end
		local curH, maxH = GetUnitHealth(queenID)
		local lifeCheck = math.ceil(((curH / maxH) * 100) - 0.5)
		if queenLifePercent ~= lifeCheck then
			-- health changed since last update, update it
			queenLifePercent = lifeCheck
			SetGameRulesParam("queenLife", queenLifePercent)
		end
	end

	local function SpawnQueen()
		local bestScore = 0
		local sx, sy, sz
		for burrowID, turretCount in pairs(burrows) do
			-- Try to spawn the queen at the 'best' burrow
			local x, y, z = GetUnitPosition(burrowID)
			if x and y and z then
				local score = 0
				score = score + (mRandom() * turretCount)
				if score > bestScore then
					bestScore = score
					sx = x
					sy = y
					sz = z
				end
			end
		end

		if sx and sy and sz then
			return CreateUnit(config.queenName, sx, sy, sz, mRandom(0,3), chickenTeamID)
		end

		local x, z, y
		local tries = 0
		local canSpawnQueen = false
		repeat
			if config.burrowSpawnType == "initialbox" then
				x = mRandom(lsx1, lsx2)
				z = mRandom(lsz1, lsz2)
			elseif config.burrowSpawnType == "alwaysbox" then
				x = mRandom(lsx1, lsx2)
				z = mRandom(lsz1, lsz2)
			elseif config.burrowSpawnType == "initialbox_post" then
				lsx1 = math.max(lsx1 * 0.99, config.spawnSquare)
				lsz1 = math.max(lsz1 * 0.99, config.spawnSquare)
				lsx2 = math.min(lsx2 * 1.01, MAPSIZEX - config.spawnSquare)
				lsz2 = math.min(lsz2 * 1.01, MAPSIZEZ - config.spawnSquare)
				x = mRandom(lsx1, lsx2)
				z = mRandom(lsz1, lsz2)
			else
				x = mRandom(config.spawnSquare, MAPSIZEX - config.spawnSquare)
				z = mRandom(config.spawnSquare, MAPSIZEZ - config.spawnSquare)
			end

			y = GetGroundHeight(x, z)
			tries = tries + 1

			canSpawnQueen = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, false)
			
			if canSpawnQueen then
				if tries < maxTries*3 then
					canSpawnQueen = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, true)
				else
					canSpawnQueen = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, false)
				end
			end

			if canSpawnQueen then
				canSpawnQueen = positionCheckLibrary.OccupancyCheck(x, y, z, config.minBaseDistance*0.25)
			end

			if canSpawnQueen then
				canSpawnQueen = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
			end

		until (canSpawnQueen == true or tries >= maxTries * 6)

		if canSpawnQueen then
			return CreateUnit(config.queenName, x, y, z, mRandom(0,3), chickenTeamID)
		else
			for i = 1,100 do
				local x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
				local z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
				local y = GetGroundHeight(x, z)

				canSpawnQueen = positionCheckLibrary.StartboxCheck(x, y, z, chickenAllyTeamID, true)
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, false)
				end
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
				end
				if canSpawnQueen then
					canSpawnQueen = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
				end
				if canSpawnQueen then
					return CreateUnit(config.queenName, x, y, z, mRandom(0,3), chickenTeamID)
				end
			end
		end
		return nil
	end

	local function Wave()
		if gameOver then
			return
		end

		currentMaxWaveSize = (config.minChickens + math.ceil((queenAnger*0.01)*(maxWaveSize - config.minChickens)))
		squadManagerKillerLoop()
		
		local techAngerPerTier = 100/config.wavesAmount
		if techAnger >= 100 then
			currentWave = config.wavesAmount
		else
			currentWave = math.ceil(techAnger/techAngerPerTier)
		end

		if currentWave > config.wavesAmount then
			currentWave = config.wavesAmount
		end

		local cCount = 0
		local loopCounter = 0
		local squadCounter = 0
		local cleanerSpawned = 0
		repeat
			loopCounter = loopCounter + 1
			for burrowID in pairs(burrows) do
				if cCount < currentMaxWaveSize then
					for mult = 1,config.chickenSpawnMultiplier do
						squadCounter = 0
						local waveLevel = currentWave
						local squad = config.basicWaves[waveLevel][mRandom(1, #config.basicWaves[waveLevel])]
						if config.specialWaves[waveLevel] and math.random(1,100) <= 20 then
							squad = config.specialWaves[waveLevel][mRandom(1, #config.specialWaves[waveLevel])]
						elseif config.superWaves[waveLevel] and math.random(1,100) <= 1 then
							squad = config.superWaves[waveLevel][mRandom(1, #config.superWaves[waveLevel])]
						end
						local skipSpawn = false
						if cCount > 1 and mRandom() > config.spawnChance then
							skipSpawn = true
						end
						if not skipSpawn then
							for i, sString in pairs(squad) do
								if cCount < currentMaxWaveSize then
									local nEnd, _ = string.find(sString, " ")
									local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
									local chickenName = string.sub(sString, (nEnd + 1))
									for j = 1, unitNumber, 1 do
										squadCounter = squadCounter + 1
										table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
									end
									cCount = cCount + unitNumber
								end
							end
						end
					end
				end
				
				local aliveCleaners = Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1"].id) + Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1b"].id)
				local targetCleaners = currentMaxWaveSize*0.1
				local cleanerSpawnCount = math.ceil((targetCleaners - aliveCleaners)*0.25)
				if targetCleaners - cleanerSpawned > 0 and cleanerSpawnCount > 0 then
					if mRandom(0,1) == 0 then
						for i = 1,math.ceil(cleanerSpawnCount) do
							table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenh1", team = chickenTeamID, squadID = i })
							cleanerSpawned = cleanerSpawned + 1
						end
					else
						for i = 1,math.ceil(cleanerSpawnCount) do
							table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenh1b", team = chickenTeamID, squadID = i })
							cleanerSpawned = cleanerSpawned + 1
						end
					end
				end
			end
		until (cCount > currentMaxWaveSize or loopCounter >= 100)

		return cCount
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------


	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == chickenTeamID or chickenDefTypes[unitDefID] then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{3},0)
			if UnitDefs[unitDefID].name == "chickenh2" then
				broodRaptors1[unitID] = true
			end
			if UnitDefs[unitDefID].name == "chickenh3" then
				broodRaptors2[unitID] = true
			end
			if UnitDefs[unitDefID].name == "chickenh4" then
				broodRaptors3[unitID] = true
			end
			return
		end
		if squadPotentialTarget[unitID] then
			squadPotentialTarget[unitID] = nil
		end
		if not UnitDefs[unitDefID].canMove then
			squadPotentialTarget[unitID] = true
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if unitTeam == chickenTeamID and attackerTeam == chickenTeamID and attackerDefID ~= UnitDefNames["chickenr2"].id then
			return 0
		end

		if attackerTeam == chickenTeamID then
			damage = damage * damageMod
		end

		if heroChicken[unitID] then
			damage = (damage * heroChicken[unitID])
		end

		if unitID == queenID then
			-- special case queen
			if weaponID == -1 and damage > 1 then
				damage = 1
			end
			if not queenResistance[weaponID] then
				queenResistance[weaponID] = {}
				queenResistance[weaponID].damage = (damage * 3 * config.queenResistanceMult)
				queenResistance[weaponID].notify = 0
			end
			local resistPercent = math.min((queenResistance[weaponID].damage) / queenMaxHP, 0.90)
			if resistPercent > 0.5 then
				if queenResistance[weaponID].notify == 0 then
					if attackerDefID then
						SendToUnsynced('QueenResistant', attackerDefID)
					end
					queenResistance[weaponID].notify = 1
					if mRandom() < config.spawnChance then
						SpawnRandomOffWaveSquad(queenID, "chickenw2", 4)
						SpawnRandomOffWaveSquad(queenID, "chickenh1", 5)
						SpawnRandomOffWaveSquad(queenID, "chickenh1b", 5)
						SpawnRandomOffWaveSquad(queenID)
					end
					for i = 1, SetCount(humanTeams)*2 do
						table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID, })
					end
				end
				damage = damage - (damage * resistPercent)
			end
			queenResistance[weaponID].damage = queenResistance[weaponID].damage + (damage * 3 * config.queenResistanceMult)
			return damage
		end

		return damage, 1
	end

	function SpawnMiniQueenMinions(unitID, unitDefID)
		local unitName = UnitDefs[unitDefID].name
		if miniQueenMinions[unitName] then
			if mRandom(1,100) == 1 and mRandom() < config.spawnChance then
				local minion = miniQueenMinions[unitName][math.random(1,#miniQueenMinions[unitName])]
				SpawnRandomOffWaveSquad(unitID, minion, 3)
			end
		end
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if not chickenteamhasplayers then
			if SKIRMISH[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < SKIRMISH[attackerDefID].chance) then
				local ux, uy, uz = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				if x and ux then
					local angle = math.atan2(ux - x, uz - z)
					local distance = mRandom(math.ceil(SKIRMISH[attackerDefID].distance*0.75), math.floor(SKIRMISH[attackerDefID].distance*1.25))
					if SKIRMISH[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						Spring.SetUnitPosition(attackerID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + SKIRMISH[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			elseif COWARD[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < COWARD[unitDefID].chance) then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH and curH < (maxH * 0.8) then
					local ax, ay, az = GetUnitPosition(attackerID)
					local x, y, z = GetUnitPosition(unitID)
					if x and ax then
						local angle = math.atan2(ax - x, az - z)
						local distance = mRandom(math.ceil(COWARD[unitDefID].distance*0.75), math.floor(COWARD[unitDefID].distance*1.25))
						if COWARD[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
							Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
							Spring.SetUnitPosition(unitID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
							Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
							Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
							unitTeleportCooldown[unitID] = Spring.GetGameFrame() + COWARD[unitDefID].teleportcooldown*30
						else
							Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
						end
						unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
					end
				end
			elseif BERSERK[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < BERSERK[unitDefID].chance) then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (BERSERK[unitDefID].distance or 10000) then
					if BERSERK[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-64,64)
						az = az + mRandom(-64,64)
						Spring.SetUnitPosition(unitID, ax, ay, az)
						Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[unitID] = Spring.GetGameFrame() + BERSERK[unitDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
				end
			elseif BERSERK[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < BERSERK[attackerDefID].chance) then
				local ax, ay, az = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (BERSERK[attackerDefID].distance or 10000) then
					if BERSERK[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-64,64)
						az = az + mRandom(-64,64)
						Spring.SetUnitPosition(attackerID, ax, ay, az)
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + BERSERK[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			end
			if queenID and unitID == queenID then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH then
					local spawnChance = math.ceil(curH/maxH*10000)
					if mRandom(0,spawnChance) == 1 then
						for i = 1,SetCount(humanTeams) do
							SpawnRandomOffWaveSquad(unitID, "chickenh1", 5)
							SpawnRandomOffWaveSquad(unitID, "chickenh1b", 5)
							SpawnRandomOffWaveSquad(unitID)
						end
					end
				end
			end
			SpawnMiniQueenMinions(unitID, unitDefID)
			if unitTeam == chickenTeamID or attackerTeam == chickenTeamID then
				if (unitID and unitSquadTable[unitID] and squadsTable[unitSquadTable[unitID]] and squadsTable[unitSquadTable[unitID]].life and squadsTable[unitSquadTable[unitID]].life < 5) then
					squadsTable[unitSquadTable[unitID]].life = 5
				end
				if (attackerID and unitSquadTable[attackerID] and squadsTable[unitSquadTable[attackerID]] and squadsTable[unitSquadTable[attackerID]].life and squadsTable[unitSquadTable[attackerID]].life < 5) then
					squadsTable[unitSquadTable[attackerID]].life = 5
				end
			end
		end
	end

	function gadget:GameStart()
		if config.burrowSpawnType == "initialbox" or config.burrowSpawnType == "alwaysbox" then
			local _, _, _, _, _, luaAllyID = Spring.GetTeamInfo(chickenTeamID, false)
			if luaAllyID then
				lsx1, lsz1, lsx2, lsz2 = Spring.GetAllyTeamStartBox(luaAllyID)
				if not lsx1 or not lsz1 or not lsx2 or not lsz2 then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Chicken start box available, Burrow Placement set to 'Avoid Players'")
					noChickenStartbox = true
				elseif lsx1 == 0 and lsz1 == 0 and lsx2 == Game.mapSizeX and lsz2 == Game.mapSizeX then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Chicken start box available, Burrow Placement set to 'Avoid Players'")
					noChickenStartbox = true
				end
			end
		end
		if not lsx1 then lsx1 = 0 end
		if not lsz1 then lsz1 = 0 end
		if not lsx2 then lsx2 = Game.mapSizeX end
		if not lsz2 then lsz2 = Game.mapSizeZ end
	end

	local function SpawnChickens()
		local i, defs = next(spawnQueue)
		if not i or not defs then
			if #squadCreationQueue.units > 0 then
				if mRandom(1,5) == 1 then
					squadCreationQueue.regroup = false
				end
				createSquad(squadCreationQueue)
				squadCreationQueue.units = {}
				manageAllSquads()
				-- Spring.Echo("[RAPTOR] Number of active Squads: ".. #squadsTable)
				-- Spring.Echo("[RAPTOR] Wave spawn complete.")
				-- Spring.Echo(" ")
			end
			return
		end
		local x, y, z = getChickenSpawnLoc(defs.burrow, SMALL_UNIT)
		if not x or not y or not z then
			spawnQueue[i] = nil
			return
		end
		local unitID = CreateUnit(defs.unitName, x, y, z, mRandom(0,3), defs.team)
		
		if unitID then
			if (not defs.squadID) or (defs.squadID and defs.squadID == 1) then
				if #squadCreationQueue.units > 0 then
					if mRandom(1,5) == 1 then
						squadCreationQueue.regroup = false
					end
					createSquad(squadCreationQueue)
				end
			end
			if defs.burrow and (not squadCreationQueue.burrow) then
				squadCreationQueue.burrow = defs.burrow
			end
			squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
			if HEALER[UnitDefNames[defs.unitName].id] or miniQueenMinions[defs.unitName] then
				squadCreationQueue.role = "healer"
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if ARTILLERY[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "artillery"
				squadCreationQueue.regroup = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if KAMIKAZE[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "kamikaze"
				squadCreationQueue.regroup = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if UnitDefNames[defs.unitName].canFly then
				squadCreationQueue.role = "aircraft"
				squadCreationQueue.regroup = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end

			GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })
			
			setChickenXP(unitID)
			if mRandom() < 0.1 then
				local mod = 0.75 - (mRandom() * 0.25)
				if mRandom() < 0.1 then
					mod = mod - (mRandom() * 0.2)
					if mRandom() < 0.1 then
						mod = mod - (mRandom() * 0.2)
					end
				end
				heroChicken[unitID] = mod
			end
		end
		spawnQueue[i] = nil
	end

	local function chickenEvent(type, num, tech)
		SendToUnsynced("ChickenEvent", type, num, tech)
	end

	local function updateSpawnQueen()
		if not queenID and not gameOver then
			-- spawn queen if not exists
			queenID = SpawnQueen()
			if queenID then
				queenSquad = table.copy(squadCreationQueueDefaults)
				queenSquad.life = 999999
				queenSquad.role = "raid"
				queenSquad.units = {queenID}
				createSquad(queenSquad)
				spawnQueue = {}
				chickenEvent("queen") -- notify unsynced about queen spawn
				_, queenMaxHP = GetUnitHealth(queenID)
				SetUnitExperience(queenID, config.maxXP)
				timeOfLastWave = t
				if mRandom() < config.spawnChance then
					SpawnRandomOffWaveSquad(queenID, "chickenh1", 20)
					SpawnRandomOffWaveSquad(queenID, "chickenh1b", 20)
				end
				Spring.SetGameRulesParam("BossFightStarted", 1)
			end
		else
			if mRandom() < config.spawnChance / 60 then
				for i = 1,SetCount(humanTeams) do
					SpawnRandomOffWaveSquad(queenID, "chickenh2", 1)
					SpawnRandomOffWaveSquad(queenID, "chickenh3", 2)
					SpawnRandomOffWaveSquad(queenID, "chickenh4", 5)
					SpawnRandomOffWaveSquad(queenID, "chickenw2", 4)
				end
				SpawnRandomOffWaveSquad(queenID)
			end
		end
	end

	local function spawnCreepStructure(unitDefName, spread)
		local structureDefID = UnitDefNames[unitDefName].id
		local canSpawnStructure = true
		local spread = spread or 128
		local spawnPosX = mRandom(lsx1,lsx2)
		local spawnPosZ = mRandom(lsz1,lsz2)

		if spawnPosX > MAPSIZEX - spread + 1 or spawnPosX < spread + 1 or spawnPosZ > MAPSIZEZ - spread + 1 or spawnPosZ < spread + 1 then
			canSpawnStructure = false
		end

		if canSpawnStructure then
			local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
			local canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
			if canSpawnStructure then
				canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
			end
			if canSpawnStructure then
				if GG.IsPosInChickenScum(spawnPosX, spawnPosY, spawnPosZ) then
					canSpawnStructure = true
				elseif playerAgressionLevel >= 5 and positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, true, true) then
					canSpawnStructure = true
				elseif playerAgressionLevel >= 10 and positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, true, false) then
					canSpawnStructure = true
				elseif playerAgressionLevel >= 15 and positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, false, false) then
					canSpawnStructure = true
				else
					canSpawnStructure = false
				end
			end
			if canSpawnStructure then
				local structureUnitID = Spring.CreateUnit(structureDefID, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), chickenTeamID)
				SetUnitBlocking(structureUnitID, false, false)
				return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
			end
		end
	end

	local function queueTurretSpawnIfNeeded()
		local burrowCount = SetCount(burrows)
		local heavyTurretCount = Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id)
		local lightTurretCount = Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id)
		if burrowCount*4*config.spawnChance > heavyTurretCount or mRandom(1,16) == 1 then
			local attempts = 0
			repeat
				attempts = attempts + 1
				local heavyTurretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(heavyTurret)
				if heavyTurretUnitID then
					setChickenXP(heavyTurretUnitID)
					Spring.GiveOrderToUnit(heavyTurretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
					if mRandom(1,4) == 1 then
						attempts = 0
						local specialHeavyTurret = specialHeavyTurrets[mRandom(1,#specialHeavyTurrets)]
						repeat 
							attempts = attempts + 1
							local specialHeavyTurretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(specialHeavyTurret)
							if specialHeavyTurretUnitID then
								setChickenXP(specialHeavyTurretUnitID)
								Spring.GiveOrderToUnit(specialHeavyTurretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
							end
						until specialHeavyTurretUnitID or attempts > 100
					end
				end
			until heavyTurretUnitID or attempts > 100
		end

		if burrowCount*20*config.spawnChance > lightTurretCount or heavyTurretCount*10*config.spawnChance > lightTurretCount or mRandom(1,16) == 1 then
			for i = 1,5 do
				local attempts = 0
				repeat
					attempts = attempts + 1
					local lightTurretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(lightTurret)
					if lightTurretUnitID then
						setChickenXP(lightTurretUnitID)
						Spring.GiveOrderToUnit(lightTurretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
						if mRandom(1,4) == 1 then
							attempts = 0
							local specialLightTurret = specialLightTurrets[mRandom(1,#specialLightTurrets)]
							repeat 
								attempts = attempts + 1
								local specialLightTurretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(specialLightTurret)
								if specialLightTurretUnitID then
									setChickenXP(specialLightTurretUnitID)
									Spring.GiveOrderToUnit(specialLightTurretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
								end
							until specialLightTurretUnitID or attempts > 100
						end
					end
				until lightTurretUnitID or attempts > 100
			end
		end
	end



	function gadget:GameFrame(n)

		-- remove initial commander (no longer required)
		if n == 1 then
			PutChickenAlliesInChickenTeam(n)
			local units = GetTeamUnits(chickenTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			chickenCount = UpdateUnitCount()
			return
		end

		if n % 90 == 0 then
			if (queenAnger >= 100) then
				damageMod = (damageMod + 0.001)
			end
		end

		local chickenTeamUnitCount = GetTeamUnitCount(chickenTeamID) or 0
		if chickenTeamUnitCount < chickenUnitCap then
			SpawnChickens()
		end

		for unitID, defs in pairs(deathQueue) do
			if ValidUnitID(unitID) and not GetUnitIsDead(unitID) then
				DestroyUnit(unitID, defs.selfd or false, defs.reclaimed or false)
			end
		end

		if n%30 == 16 then
			t = GetGameSeconds()
			playerAgression = playerAgression*0.998
			playerAgressionLevel = math.floor(playerAgression)
			SetGameRulesParam("chickenPlayerAgressionLevel", playerAgressionLevel)
			if t < config.gracePeriod then
				queenAnger = 0
				techAnger = 0
			else
				if not queenID then
					queenAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100) + queenAngerAgressionLevel, 100), 0)
				else
					queenAnger = 100
				end
				techAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100) - (playerAgressionLevel*5) + queenAngerAgressionLevel, 100), 0)
				queenAngerAgressionLevel = queenAngerAgressionLevel + ((playerAgressionLevel*0.01)/(config.queenTime/1200))
				if techAnger < 1 then techAnger = 1 end
				if playerAgressionLevel+1 <= maxBurrows then
					minBurrows = playerAgressionLevel+1
				else
					minBurrows = maxBurrows
				end
			end
			SetGameRulesParam("queenAnger", queenAnger)

			if queenAnger >= 100 then
				-- check if the queen should be alive
				updateSpawnQueen()
				updateQueenLife()
			end

			local burrowCount = SetCount(burrows)

			if config.burrowSpawnRate < (t - timeOfLastFakeSpawn) then
				-- This block is all about setting the correct burrow target
				if firstSpawn then
					minBurrows = 1
				end
				timeOfLastFakeSpawn = t
			end

			if t > config.burrowSpawnRate and burrowCount < minBurrows or (config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if (config.burrowSpawnType == "initialbox") and (GetGameSeconds() > config.gracePeriod) then
					config.burrowSpawnType = "initialbox_post"
				end
				if firstSpawn then
					SpawnBurrow()
					timeOfLastSpawn = t
					timeOfLastWave = (config.gracePeriod + 10) - config.chickenMaxSpawnRate
					firstSpawn = false
				else
					SpawnBurrow()
				end
				if burrowCount >= minBurrows then
					timeOfLastSpawn = t
				end
				chickenEvent("burrowSpawn")
				SetGameRulesParam("chicken_hiveCount", SetCount(burrows))
			elseif config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount >= maxBurrows then
				timeOfLastSpawn = t
			end

			if t > config.gracePeriod+5 then
				if burrowCount > 0 and (((config.chickenMaxSpawnRate) < (t - timeOfLastWave)) or (chickenCount < lastWaveUnitCount) and (t - timeOfLastWave) > (config.chickenMaxSpawnRate*0.25)) then
					local cCount = Wave()
					if cCount and cCount > 0 then
						chickenEvent("wave", cCount, currentWave)
					end
					lastWaveUnitCount = cCount
					timeOfLastWave = t
				end
			end
			chickenCount = UpdateUnitCount()
		end
		if playerAgressionLevel > 0 and n%((math.ceil(config.turretSpawnRate/playerAgressionLevel))*30) == 0 and chickenTeamUnitCount < chickenUnitCap then
			queueTurretSpawnIfNeeded()
		end
		local squadID = ((n % (#squadsTable*2))+1)/2 --*2 and /2 for lowering the rate of commands
		if not chickenteamhasplayers then
			if squadID and squadsTable[squadID] and squadsTable[squadID].squadRegroup then
				local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
				if targetx then
					squadCommanderGiveOrders(squadID, targetx, targety, targetz)
				else
					refreshSquad(squadID)
				end
			end
		end
		if n%100 == 50 and not chickenteamhasplayers then
			local chickens = GetTeamUnits(chickenTeamID)
			for i = 1,#chickens do 
				if unitCowardCooldown[chickens[i]] and (Spring.GetGameFrame() > unitCowardCooldown[chickens[i]]) then
					unitCowardCooldown[chickens[i]] = nil
					Spring.GiveOrderToUnit(chickens[i], CMD.STOP, 0, 0)
				end
				if Spring.GetCommandQueue(chickens[i], 0) <= 0 then
					if unitCowardCooldown[chickens[i]] then
						unitCowardCooldown[chickens[i]] = nil
					end
					local squadID = unitSquadTable[chickens[i]]
					if squadID then
						local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
						if targetx then
							squadCommanderGiveOrders(squadID, targetx, targety, targetz)
						else
							refreshSquad(squadID)
						end
					else
						local pos = getRandomEnemyPos()
						Spring.GiveOrderToUnit(chickens[i], CMD.FIGHT, {pos.x, pos.y, pos.z}, {})
					end
				end
			end
		end
		if n%30 == 20 then -- math.ceil((brood3count*4)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))
			local brood1count = SetCount(broodRaptors1)
			local brood2count = SetCount(broodRaptors2)
			local brood3count = SetCount(broodRaptors3)
			for unitID, _ in pairs(broodRaptors1) do
				if mRandom() < config.spawnChance then
					if mRandom(0,math.ceil((brood3count*4)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 0 then
						SpawnRandomOffWaveSquad(unitID, "chickenh4", 8)
						break
					end
					if mRandom(0,math.ceil((brood2count*8)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 0 then
						SpawnRandomOffWaveSquad(unitID, "chickenh3", 2)
						break
					end
					if mRandom(0,math.ceil((brood1count*16)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 1 then
						SpawnRandomOffWaveSquad(unitID, "chickenh2", 1)
						break
					end
				end
			end
			for unitID, _ in pairs(broodRaptors2) do
				if mRandom() < config.spawnChance then
					if mRandom(0,math.ceil((brood3count*8)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 0 then
						SpawnRandomOffWaveSquad(unitID, "chickenh4", 4)
						break
					end
					if mRandom(0,math.ceil((brood2count*16)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 0 then
						SpawnRandomOffWaveSquad(unitID, "chickenh3", 1)
						break
					end
				end
			end
			for unitID, _ in pairs(broodRaptors3) do
				if mRandom() < config.spawnChance then
					if mRandom(0,math.ceil((brood3count*16)/(SetCount(humanTeams)*config.chickenSpawnMultiplier))+1) == 0 then
						SpawnRandomOffWaveSquad(unitID, "chickenh4", 1)
						break
					end
				end
			end
		end
	end

	local chickenEggColors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}
	local function spawnRandomEgg(x,y,z,name)
		local r = mRandom(1,100)
		local size = "s"
		if r <= 5 then
			size = "l"
		elseif r <= 20 then
			size = "m"
		end
		if config.chickenEggs[name] and config.chickenEggs[name] ~= "" then
			color = config.chickenEggs[name]
		else
			color = chickenEggColors[mRandom(1,#chickenEggColors)]
		end
		
		
		
			local egg = Spring.CreateFeature("chicken_egg_"..size.."_"..color, x, y, z, mRandom(-999999,999999), chickenTeamID)
		if egg then
			Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
			Spring.SetFeatureVelocity(egg, mRandom(-195,195)*0.01, mRandom(130,335)*0.01, mRandom(-195,195)*0.01)
			--Spring.SetFeatureRotation(egg, mRandom(-175,175)*50000, mRandom(110,275)*50000, mRandom(-175,175)*50000)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)

		if unitTeam == chickenTeamID then
			local x,y,z = Spring.GetUnitPosition(unitID)
			if unitDefID == config.burrowDef or UnitDefs[unitDefID].name == "chicken_turretl" then
				for i = 1,mRandom(10,40) do
					local x = x + mRandom(-32,32)
					local z = z + mRandom(-32,32)
					local y = GetGroundHeight(x, z)
					spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
				end
			elseif UnitDefs[unitDefID].name == "chicken_turrets" then
				for i = 1,mRandom(3,10) do
					local x = x + mRandom(-16,16)
					local z = z + mRandom(-16,16)
					local y = GetGroundHeight(x, z)
					spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
				end
			elseif miniQueenMinions[UnitDefs[unitDefID].name] then
				for i = 1,mRandom(100,200) do
					local x = x + mRandom(-16,16)
					local z = z + mRandom(-16,16)
					local y = GetGroundHeight(x, z)
					spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
				end
			else
				spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
			end
		end
		
		if heroChicken[unitID] then
			heroChicken[unitID] = nil
		end

		if unitSquadTable[unitID] then
			for index, id in pairs(squadsTable[unitSquadTable[unitID]].squadUnits) do
				if id == unitID then
					table.remove(squadsTable[unitSquadTable[unitID]].squadUnits, index)
				end
			end
			unitSquadTable[unitID] = nil
		end

		squadPotentialTarget[unitID] = nil
		for squad in ipairs(unitTargetPool) do
			if unitTargetPool[squad] == unitID then
				refreshSquad(squad)
			end
		end

		if unitTeam == chickenTeamID and chickenDefTypes[unitDefID] then
			local name = unitName[unitDefID]
			if unitDefID ~= config.burrowDef then
				name = string.sub(name, 1, -2)
			end
			local kills = GetGameRulesParam("chicken" .. "Kills")
			SetGameRulesParam("chicken" .. "Kills", kills + 1)
			chickenCount = chickenCount - 1
		end

		if unitID == queenID then
			-- queen destroyed
			queenID = nil
			queenResistance = {}
			Spring.SetGameRulesParam("BossFightStarted", 0)

			if config.difficulty == config.difficulties.survival then
				updateDifficultyForSurvival()
			else
				gameOver = GetGameFrame() + 200
				spawnQueue = {}

				-- kill whole allyteam  (game_end gadget will destroy leftover units)
				if not killedChickensAllyTeam then
					killedChickensAllyTeam = true
					for _, teamID in ipairs(Spring.GetTeamList(chickenAllyTeamID)) do
						if not select(3, Spring.GetTeamInfo(teamID, false)) then
							Spring.KillTeam(teamID)
						end
					end
				end
			end
		end

		-- if config.addQueenAnger then
		-- 	if string.find(UnitDefs[unitDefID].name, "chicken_turret") then
		-- 		playerAgression = playerAgression + config.angerBonus*0.25
		-- 	end
		-- end

		if unitDefID == config.burrowDef and not gameOver then
			local kills = GetGameRulesParam(config.burrowName .. "Kills")
			SetGameRulesParam(config.burrowName .. "Kills", kills + 1)

			burrows[unitID] = nil
			if config.addQueenAnger then
				playerAgression = playerAgression + config.angerBonus
				config.maxXP = config.maxXP*1.01
			end

			for i, defs in pairs(spawnQueue) do
				if defs.burrow == unitID then
					spawnQueue[i] = nil
				end
			end

			for i = 1,#squadsTable do
				if squadsTable[i].squadBurrow == unitID then
					squadsTable[i].squadBurrow = nil
					break
				end
			end

			SetGameRulesParam("chicken_hiveCount", SetCount(burrows))
		end

		if UnitDefs[unitDefID].name == "chickenh2" then
			broodRaptors1[unitID] = nil
		end
		if UnitDefs[unitDefID].name == "chickenh3" then
			broodRaptors2[unitID] = nil
		end
		if UnitDefs[unitDefID].name == "chickenh4" then
			broodRaptors3[unitID] = nil
		end
		if unitTeleportCooldown[unitID] then
			unitTeleportCooldown[unitID] = nil
		end
	end

	function gadget:TeamDied(teamID)
		humanTeams[teamID] = nil
		--computerTeams[teamID] = nil
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		if oldTeam == chickenTeamID then
			DestroyUnit(unitID, true)
		end
	end

	function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
		if newTeam == chickenTeamID then
			return false
		else
			return true
		end
	end

	function gadget:GameOver()
		-- don't end game in survival mode
		if config.difficulty ~= config.difficulties.survival then
			gameOver = GetGameFrame()
		end
	end

else	-- UNSYNCED

	local hasChickenEvent = false
	local mRandom = math.random

	local function HasChickenEvent(ce)
		hasChickenEvent = (ce ~= "0")
	end

	local function WrapToLuaUI(_, type, num, tech)
		if hasChickenEvent then
			local chickenEventArgs = {}
			if type ~= nil then
				chickenEventArgs["type"] = type
			end
			if num ~= nil then
				chickenEventArgs["number"] = num
			end
			if tech ~= nil then
				chickenEventArgs["tech"] = tech
			end
			Script.LuaUI.ChickenEvent(chickenEventArgs)
		end
	end

	local function queenResistant(_, attackerDefId)
		if Script.LuaUI('GadgetMessageProxy') then
			local message = Script.LuaUI.GadgetMessageProxy( 'ui.chickens.queenResistant', { unitDefId = attackerDefId })
			Spring.Echo(message)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('ChickenEvent', WrapToLuaUI)
		gadgetHandler:AddSyncAction('QueenResistant', queenResistant)
		gadgetHandler:AddChatAction("HasChickenEvent", HasChickenEvent, "toggles hasChickenEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction('QueenResistant')
		gadgetHandler:RemoveChatAction("HasChickenEvent")
	end


	local nocolorshift = {0,0,0}
	local colorshiftcache = {0,0,0}
	if gl.SetUnitBufferUniforms then 
		function gadget:UnitCreated(unitID, unitDefID, unitTeam)
			if string.find(UnitDefs[unitDefID].name, "chicken") then
				gl.SetUnitBufferUniforms(unitID, nocolorshift, 8)
				if (not string.find(UnitDefs[unitDefID].name, "chicken_hive")) and (not string.find(UnitDefs[unitDefID].name, "chicken_turret")) then
					colorshiftcache[1] = mRandom(-500,500)*0.0001 -- hue (hue hue)
					colorshiftcache[2] = mRandom(-1000,1000)*0.0001 -- saturation         
					colorshiftcache[3] = mRandom(-1000,1000)*0.0001 -- brightness
					gl.SetUnitBufferUniforms(unitID, colorshiftcache, 8)
				end
			end
		end
	end

end
