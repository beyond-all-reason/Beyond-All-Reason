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

	--local GetUnitHeading = Spring.GetUnitHeading
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
	--local GetUnitsInCylinder = Spring.GetUnitsInCylinder
	local GetUnitNearestEnemy = Spring.GetUnitNearestEnemy
	local GetUnitPosition = Spring.GetUnitPosition
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local TestBuildOrder = Spring.TestBuildOrder
	local GetGroundBlocked = Spring.GetGroundBlocked
	local CreateUnit = Spring.CreateUnit
	local SetUnitBlocking = Spring.SetUnitBlocking
	local GetGroundHeight = Spring.GetGroundHeight
	local GetUnitTeam = Spring.GetUnitTeam
	local GetUnitHealth = Spring.GetUnitHealth
	local SetUnitExperience = Spring.SetUnitExperience
	local GetUnitDefID = Spring.GetUnitDefID
	local SetUnitHealth = Spring.SetUnitHealth
	local GetUnitIsDead = Spring.GetUnitIsDead
	-- local GetUnitDirection = Spring.GetUnitDirection

	local mRandom = math.random
	local math = math
	local Game = Game
	local table = table
	local ipairs = ipairs
	local pairs = pairs

	local MAPSIZEX = Game.mapSizeX
	local MAPSIZEZ = Game.mapSizeZ
	local DMAREA = 160

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	local queenLifePercent = 100
	local maxTries = 30
	local oldMaxChicken = 0
	local maxChicken = Game.maxUnits - 100
	local oldDamageMod = 1
	local damageMod = config.damageMod
	local currentWave = 1
	local lastWave = 1
	local lastWaveUnitCount = 0
	local minBurrows = 1
	local timeOfLastSpawn = 0
	local timeOfLastFakeSpawn = 0
	local timeOfLastWave = 0
	local expMod = 0
	local lastTeamID = 0
	local nextSquadSize = 0
	local chickenCount = 0
	local t = 0 -- game time in seconds
	local timeCounter = 0
	local queenAnger = 0
	local queenMaxHP = 0
	local burrowAnger = 0
	local firstSpawn = true
	local gameOver = nil
	local computerTeams = {}
	local humanTeams = {}
	local disabledUnits = {}
	local spawnQueue = {}
	local deathQueue = {}
	local queenResistance = {}
	local queenID
	local chickenTeamID, chickenAllyTeamID
	local lsx1, lsz1, lsx2, lsz2
	local burrows = {}
	local overseers = {}
	local heroChicken = {}
	local defenseMap = {}
	local unitName = {}
	local unitShortName = {}
	local unitSpeed = {}
	local unitCanFly = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadPotentialTarget = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = 5,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = 5,
	}

	local attemptingToSpawnHeavyTurret = 0
	local attemptingToSpawnLightTurret = 0
	local heavyTurret = "chickend2"
	local lightTurret = "chickend1"

	for unitDefID, unitDef in pairs(UnitDefs) do
		unitName[unitDefID] = unitDef.name
		unitShortName[unitDefID] = string.match(unitDef.name, "%D*")
		unitSpeed[unitDefID] = unitDef.speed
		if unitDef.canFly then
			unitCanFly[unitDefID] = unitDef.canFly
		end
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
			computerTeams[teamID] = true
		else
			humanTeams[teamID] = true
		end
	end

	local gaiaTeamID = GetGaiaTeamID()
	if not chickenTeamID then
		chickenTeamID = gaiaTeamID
		chickenAllyTeamID = select(6, Spring.GetTeamInfo(chickenTeamID))
	else
		computerTeams[gaiaTeamID] = nil
	end

	humanTeams[gaiaTeamID] = nil

	function PutChickenAlliesInChickenTeam(n)
		local players = Spring.GetPlayerList()
		for i = 1,#players do
			local player = players[i]
			local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
			if allyTeamID == chickenAllyTeamID and (not spectator) then
				Spring.AssignPlayerToTeam(player, chickenTeamID)
				local units = Spring.GetTeamUnits(teamID)
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
				local units = Spring.GetTeamUnits(chickenAllies[i])
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(chickenAllies[i])
				end
			end
		end

		if chickenteamhasplayers then
			config.gracePeriod = math.ceil(config.gracePeriod*0.25)
			SetGameRulesParam("gracePeriod", config.gracePeriod)
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
		local x = math.random(MAPSIZEX - 16)
		local z = math.random(MAPSIZEZ - 16)
		local y = GetGroundHeight(x, z)
		return { x, y, z }
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Difficulty
    --

	if config.difficulty == config.difficulties.survival then
		config.queenTime = config.queenTime*0.5
	end
	local expIncrement = ((SetCount(humanTeams) * config.expStep) / config.queenTime)
	local maxBurrows = config.maxBurrows
	local queenTime = (config.queenTime + config.gracePeriod)
	local maxWaveSize = ((config.maxBurrows*0.5)+(config.maxBurrows*0.5)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	
	local function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		queenTime = (config.queenTime + config.gracePeriod)
		queenAnger = 0  -- reenable chicken spawning
		burrowAnger = 0
		SetGameRulesParam("queenAnger", queenAnger)
		local nextDifficulty
		if config.queenName == "ve_chickenq" then -- Enter Easy Phase
			nextDifficulty = config.difficultyParameters[1]
		elseif config.queenName == "e_chickenq" then -- Enter Normal Phase
			nextDifficulty = config.difficultyParameters[2]
		elseif config.queenName == "n_chickenq" then -- Enter Hard Phase
			nextDifficulty = config.difficultyParameters[3]
		elseif config.queenName == "h_chickenq" then -- Enter Very Hard Phase
			nextDifficulty = config.difficultyParameters[4]
		elseif config.queenName == "vh_chickenq" then -- Enter Epic Phase
			nextDifficulty = config.difficultyParameters[5]
		elseif config.queenName == "epic_chickenq" then -- We're already at Epic, just multiply some numbers to make it even harder
			nextDifficulty = config.difficultyParameters[5]
			config.chickenSpawnMultiplier = config.chickenSpawnMultiplier*2
		end
		config.queenName = nextDifficulty.queenName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.queenSpawnMult = nextDifficulty.queenSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxBurrows = nextDifficulty.maxBurrows
		expIncrement = ((SetCount(humanTeams) * config.expStep) / config.queenTime)
		maxBurrows = config.maxBurrows
		maxWaveSize = ((config.maxBurrows*0.5)+(config.maxBurrows*0.5)*SetCount(humanTeams))*config.chickenSpawnMultiplier
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
		[UnitDefNames["chickens2"].id] = { distance = 500, chance = 0.5 },
		[UnitDefNames["chickens3"].id] = { distance = 440, chance = 0.1 },
		[UnitDefNames["chickenh5"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidswarmer"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickenacidassault"].id] = { distance = 200, chance = 1 },	
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidallterrain"].id] = { distance = 300, chance = 1 },
	}
	local COWARD = {
		[UnitDefNames["chickenh1"].id] = { distance = 300, chance = 0.5 },
		[UnitDefNames["chickenh1b"].id] = { distance = 15, chance = 0.1 },
		[UnitDefNames["chickenr1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 500, chance = 0.1 },
		[UnitDefNames["chickenh5"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenearty1"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenelectricallterrain"].id] = { distance = 500, chance = 1 },
		[UnitDefNames["chickenacidarty"].id] = { distance = 500, chance = 1 },
	}
	local BERSERK = {
		[UnitDefNames["ve_chickenq"].id] = { chance = 0.01 },
		[UnitDefNames["e_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["n_chickenq"].id] = { chance = 0.1 },
		[UnitDefNames["h_chickenq"].id] = { chance = 0.2 },
		[UnitDefNames["vh_chickenq"].id] = { chance = 0.3 },
		[UnitDefNames["epic_chickenq"].id] = { chance = 0.5 },
		[UnitDefNames["chickena1"].id] = { chance = 0.2 },
		[UnitDefNames["chickena1b"].id] = { chance = 0.2 },
		[UnitDefNames["chickena1c"].id] = { chance = 0.2 },
		[UnitDefNames["chickena2"].id] = { chance = 0.2 },
		[UnitDefNames["chickena2b"].id] = { chance = 0.2 },
		[UnitDefNames["chickene2"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidassault"].id] = { chance = 0.05 },
		[UnitDefNames["chickenacidswarmer"].id] = { chance = 0.01 },
		[UnitDefNames["chickenacidallterrain"].id] = { chance = 0.01 },
		[UnitDefNames["chickenp1"].id] = { chance = 0.2 },
		[UnitDefNames["chickenp2"].id] = { chance = 0.2 },
		[UnitDefNames["chickenpyroallterrain"].id] = { chance = 0.2 },
	}
	local HEALER = {
		[UnitDefNames["chickenh1"].id] = true,
		[UnitDefNames["chickenh1b"].id] = true,
		[UnitDefNames["chickenh5"].id] = true,
	}
	local ARTILLERY = {
		[UnitDefNames["chickenr1"].id] = true,
		[UnitDefNames["chickenr2"].id] = true,
		[UnitDefNames["chickenearty1"].id] = true,
		[UnitDefNames["chickenacidarty"].id] = true,
	}
	
	local OVERSEER_ID = UnitDefNames["chickenh5"].id
	local SMALL_UNIT = UnitDefNames["chicken1"].id
	local MEDIUM_UNIT = UnitDefNames["chicken1"].id
	local LARGE_UNIT = UnitDefNames["chicken1"].id

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
			-- Spring.Echo("SquadLifeReport - SquadID: #".. i .. ", LifetimeRemaining: ".. squadsTable[i].squadLife)
			
			if squadsTable[i].squadLife <= 0 then
				-- Spring.Echo("Life is 0, time to do some killing")
				if SetCount(squadsTable[i].squadUnits) > 0 then
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

	local function squadCommanderGiveOrders(squadID, targetx, targety, targetz)
		local units = squadsTable[squadID].squadUnits
		local role = squadsTable[squadID].squadRole
		if SetCount(units) > 0 and squadsTable[squadID].target and squadsTable[squadID].target.x then
			
			if role ~= "aircraft" then
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
					if xmin < xaverage-256 or xmax > xaverage+256 or zmin < zaverage-256 or zmax > zaverage+256 then
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
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+math.random(-128, 128), targety, targetz+math.random(-128, 128)} , {})
						elseif role == "raid" then
							Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+math.random(-128, 128), targety, targetz+math.random(-128, 128)} , {})
						elseif role == "aircraft" then
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+math.random(-128, 128), targety, targetz+math.random(-128, 128)} , {})
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, getRandomMapPos() , {"shift"})
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, getRandomMapPos() , {"shift"})
							Spring.GiveOrderToUnit(unitID, CMD.FIGHT, getRandomMapPos() , {"shift"})
						end
					end
				end
			end
		end
	end

	local function refreshSquad(squadID) -- Get new target for a squad
		local role = squadsTable[squadID].squadRole
		local targetCount = SetCount(squadPotentialTarget)
		local pos = false
		
		for target in pairs(unitTargetPool) do
			if unitTargetPool[target] == squadID then
				local x,y,z = Spring.GetUnitPosition(target)
				--Spring.MarkerErasePosition (x, y, z)
				unitTargetPool[target] = nil
				break
			end
		end
		local loops = 0
		repeat
			loops = loops + 1
			for target in pairs(squadPotentialTarget) do
				if math.random(1,targetCount) == 1 then
					if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
						local x,y,z = Spring.GetUnitPosition(target)
						if y >= 0 then
							pos = {x = x, y = y, z = z}
							unitTargetPool[target] = squadID
							break
						end
					end
				end
			end

		until pos or loops >= 10
		
		if not pos then
			pos = getRandomMapPos()
		end

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
				if math.random(0,100) <= 40 then
					role = "raid"
				end
			else
				role = newSquad.role
			end
			if not newSquad.life then
				newSquad.life = 5
			end


			squadsTable[squadID] = {
				squadUnits = newSquad.units,
				squadLife = newSquad.life,
				squadRole = role,
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
			for target, squad in pairs(unitTargetPool) do
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
					if GG.IsPosInChickenScum(x, y, z) and math.random(1,5) == 1 then
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
				local unitID = CreateUnit(config.burrowName, x, y, z, math.random(0,3), chickenTeamID)
				if unitID then
					if math.random(1,4) == 1 and minBurrows < maxBurrows and Spring.GetGameFrame() > (config.gracePeriod*30)+150 then
						minBurrows = minBurrows + 1
					end
					burrows[unitID] = 0
					SetUnitBlocking(unitID, false, false)
					SetUnitExperience(unitID, mRandom() * expMod)
				end
			else
				for i = 1,100 do
					local x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
					local z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
					local y = GetGroundHeight(x, z)

					canSpawnBurrow = positionCheckLibrary.StartboxCheck(x, y, z, 64, chickenAllyTeamID, true)
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
						local unitID = CreateUnit(config.burrowName, x, y, z, math.random(0,3), chickenTeamID)
						if unitID then
							if math.random(1,4) == 1 and minBurrows < maxBurrows and Spring.GetGameFrame() > (config.gracePeriod*30)+150 then
								minBurrows = minBurrows + 1
							end
							burrows[unitID] = 0
							SetUnitBlocking(unitID, false, false)
							SetUnitExperience(unitID, mRandom() * expMod)
							attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + 1
							break
						end
					elseif i == 100 then
						burrowAnger = (burrowAnger + config.angerBonus)
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
			return CreateUnit(config.queenName, sx, sy, sz, math.random(0,3), chickenTeamID)
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
			return CreateUnit(config.queenName, x, y, z, math.random(0,3), chickenTeamID)
		else
			for i = 1,100 do
				local x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
				local z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
				local y = GetGroundHeight(x, z)

				canSpawnQueen = positionCheckLibrary.StartboxCheck(x, y, z, 64, chickenAllyTeamID, true)
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
					return CreateUnit(config.queenName, x, y, z, math.random(0,3), chickenTeamID)
				end
			end
		end
		return nil
	end

	local function Wave()
		if gameOver then
			return
		end
		squadManagerKillerLoop()
		currentWave = math.ceil(queenAnger/#config.waves)

		if currentWave > #config.waves then
			currentWave = #config.waves
		end

		if currentWave == 10 then
			COWARD[UnitDefNames["chickenc1"].id] = { distance = 700, chance = 0.1 }
		end

		local cCount = 0
		local queenBurrowSpawnMultiplier = 1
		if queenID then
			queenBurrowSpawnMultiplier = 0.2
			-- spawn units from queen
			if config.queenSpawnMult > 0 then
				for mult = 1,config.chickenSpawnMultiplier do
					for i = 1, config.queenSpawnMult*SetCount(humanTeams), 1 do
						squadCounter = 0
						local waveLevelPower = mRandom(1, currentWave*currentWave)
						local waveLevel = math.ceil(math.sqrt(waveLevelPower))
						local squad = config.waves[waveLevel][mRandom(1, #config.waves[waveLevel])]
						for i, sString in pairs(squad) do
							local nEnd, _ = string.find(sString, " ")
							local unitNumber = math.random(1, string.sub(sString, 1, (nEnd - 1)))
							local chickenName = string.sub(sString, (nEnd + 1))
							for i = 1, unitNumber, 1 do
								squadCounter = squadCounter + 1
								table.insert(spawnQueue, { burrow = queenID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
							end
							cCount = cCount + unitNumber
							for j = 1, math.floor(1+((currentWave-waveLevel)*0.25)) do
								if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1"].id) + Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1b"].id) < waveLevel*3 then
									if math.random(0,1) == 0 then
										table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID, squadID = j })
									else
										table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID, squadID = j })
									end
									cCount = cCount + 1
								end
							end
						end
					end
				end
			end
		end
		local overseerSpawned = false
		local cleanersSpawned = false
		local scoutSpawned = false
		local loopCounter = 0
		local squadCounter = 0
		repeat
			loopCounter = loopCounter + 1
			for overseerID in pairs(overseers) do
				if cCount < maxWaveSize then
					for mult = 1,config.chickenSpawnMultiplier do
						squadCounter = 0
						local waveLevelPower = mRandom(1, currentWave^2)
						local waveLevel = math.ceil(math.sqrt(waveLevelPower))
						local squad = config.waves[waveLevel][mRandom(1, #config.waves[waveLevel])]
						local skipSpawn = false
						if cCount > 1 and mRandom() > config.spawnChance*queenBurrowSpawnMultiplier then
							skipSpawn = true
						end
						if not skipSpawn then
							for i, sString in pairs(squad) do
								if cCount < maxWaveSize then
									local nEnd, _ = string.find(sString, " ")
									local unitNumber = math.random(1, string.sub(sString, 1, (nEnd - 1)))
									local chickenName = string.sub(sString, (nEnd + 1))
									for j = 1, unitNumber, 1 do
										squadCounter = squadCounter + 1
										table.insert(spawnQueue, { burrow = overseerID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
									end
									cCount = cCount + unitNumber
								end
							end
						end
					end
				end
			end
			for burrowID in pairs(burrows) do
				if cCount < maxWaveSize then
					for mult = 1,config.chickenSpawnMultiplier do
						squadCounter = 0
						local waveLevelPower = mRandom(1, currentWave^2)
						local waveLevel = math.ceil(math.sqrt(waveLevelPower))
						local squad = config.waves[waveLevel][mRandom(1, #config.waves[waveLevel])]
						local skipSpawn = false
						if cCount > 1 and mRandom() > config.spawnChance*queenBurrowSpawnMultiplier then
							skipSpawn = true
						end
						if not skipSpawn then
							for i, sString in pairs(squad) do
								if cCount < maxWaveSize then
									local nEnd, _ = string.find(sString, " ")
									local unitNumber = math.random(1, string.sub(sString, 1, (nEnd - 1)))
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
				if cleanersSpawned == false and mRandom() > config.spawnChance then
					if queenAnger > 10 then
						local aliveCleaners = Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1"].id) + Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh1b"].id)
						local targetCleaners = currentWave*SetCount(humanTeams)
						local cleanerSpawnCount = targetCleaners - aliveCleaners
						if cleanerSpawnCount > 0 then
							for i = 1,math.ceil(cleanerSpawnCount) do
								if math.random(0,1) == 0 then
									table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenh1", team = chickenTeamID, squadID = i })
								else
									table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenh1b", team = chickenTeamID, squadID = i })
								end
								cCount = cCount + 1
							end
						end
					end
					cleanersSpawned = true
				elseif overseerSpawned == false and mRandom() > config.spawnChance then
					if queenAnger > 50 and Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenh5"].id) < SetCount(humanTeams) then
						table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenh5", team = chickenTeamID, })
						cCount = cCount + 1
					end
					overseerSpawned = true
				elseif scoutSpawned == false and mRandom() > config.spawnChance then
					if queenAnger > 40 and Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames["chickenf2"].id) < SetCount(humanTeams) then
						table.insert(spawnQueue, { burrow = burrowID, unitName = "chickenf2", team = chickenTeamID, })
						cCount = cCount + 1
					end
					scoutSpawned = true
				end
			end
		until (cCount > maxWaveSize or loopCounter >= currentWave)
		return cCount
	end

	--------------------------------------------------------------------------------
	-- Get rid of the AI
	--------------------------------------------------------------------------------

	local function DisableUnit(unitID)
		Spring.MoveCtrl.Enable(unitID)
		Spring.MoveCtrl.SetNoBlocking(unitID, true)
		Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX + 1900, 2000, Game.mapSizeZ + 1900) --don't move too far out or prevent_aicraft_hax will explode it!
		--Spring.SetUnitCloak(unitID, true)
		Spring.SetUnitHealth(unitID, { paralyze = 99999999 })
		Spring.SetUnitNoDraw(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitNoSelect(unitID, true)
		Spring.SetUnitNoMinimap(unitID, true)
		Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
		Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
		disabledUnits[unitID] = true
	end

	local function DisableComputerUnits()
		for teamID in pairs(computerTeams) do
			local teamUnits = GetTeamUnits(teamID)
			for _, unitID in ipairs(teamUnits) do
				DisableUnit(unitID)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------



	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == chickenTeamID or chickenDefTypes[unitDefID] then
			if unitDefID == OVERSEER_ID then
				overseers[unitID] = true
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

		if unitTeam == chickenTeamID and attackerTeam == chickenTeamID then
			return 0
		end

		if disabledUnits[unitID] then
			return 0, 0
		end

		if attackerTeam == chickenTeamID then
			return (damage * damageMod)
		end

		if heroChicken[unitID] then
			damage = (damage * heroChicken[unitID])
		end

		if unitID == queenID then
			-- special case queen
			if weaponID == -1 and damage > 25000 then
				damage = 25000
			end
			damage = damage/(1+(SetCount(humanTeams)*0.2))
			if attackerDefID then
				if not queenResistance[weaponID] then
					queenResistance[weaponID] = {}
					queenResistance[weaponID].damage = damage
					queenResistance[weaponID].notify = 0
				end
				local resistPercent = math.min((queenResistance[weaponID].damage * 2 * config.chickenSpawnMultiplier) / queenMaxHP, 0.999)
				if resistPercent > 0.35 then
					if queenResistance[weaponID].notify == 0 then
						SendToUnsynced('QueenResistant', attackerDefID)
						queenResistance[weaponID].notify = 1
						for i = 1, 10, 1 do
							table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID, })
							table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID, })
						end
					end
					damage = damage - (damage * resistPercent)
				end
				queenResistance[weaponID].damage = queenResistance[weaponID].damage + damage
				return damage
			end
		end
		return damage, 1
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if not chickenteamhasplayers then
			if SKIRMISH[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < SKIRMISH[attackerDefID].chance) then
				local ux, uy, uz = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				if x and ux then
					local angle = math.atan2(ux - x, uz - z)
					local distance = mRandom(math.ceil(SKIRMISH[attackerDefID].distance*0.75), math.floor(SKIRMISH[attackerDefID].distance*1.25))
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					unitCowardCooldown[unitID] = true
				end
			elseif COWARD[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < COWARD[unitDefID].chance) then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH and curH < (maxH * 0.8) then
					local ax, ay, az = GetUnitPosition(attackerID)
					local x, y, z = GetUnitPosition(unitID)
					if x and ax then
						local angle = math.atan2(ax - x, az - z)
						local distance = mRandom(math.ceil(COWARD[unitDefID].distance*0.75), math.floor(COWARD[unitDefID].distance*1.25))
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
						unitCowardCooldown[unitID] = true
					end
				end
			elseif BERSERK[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < BERSERK[unitDefID].chance) then
				local ax, ay, az = GetUnitPosition(attackerID)
				if ax then
					Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+math.random(-64,64), ay, az+math.random(-64,64)}, {})
					unitCowardCooldown[unitID] = true
				end
			elseif BERSERK[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < BERSERK[attackerDefID].chance) then
				local ax, ay, az = GetUnitPosition(unitID)
				if ax then
					Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+math.random(-64,64), ay, az+math.random(-64,64)}, {})
					unitCowardCooldown[unitID] = true
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
		local unitID = CreateUnit(defs.unitName, x, y, z, math.random(0,3), defs.team)
		
		if unitID then
			if (not defs.squadID) or (defs.squadID and defs.squadID == 1) then
				if #squadCreationQueue.units > 0 then
					createSquad(squadCreationQueue)
				end
			end
			squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
			squadCreationQueue.life = 5
			if HEALER[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "healer"
				squadCreationQueue.life = 20
			end
			if ARTILLERY[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "artillery"
				squadCreationQueue.life = 50
			end
			if UnitDefNames[defs.unitName].canFly then
				squadCreationQueue.role = "aircraft"
				squadCreationQueue.life = 10
			end

			GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-128, 128), y, z + math.random(-128, 128) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-128, 128), y, z + math.random(-128, 128) }, { "shift" })
			
			SetUnitExperience(unitID, mRandom() * expMod)
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
				burrows[queenID] = 0
				spawnQueue = {}
				oldMaxChicken = maxChicken
				oldDamageMod = damageMod
				maxChicken = maxChicken
				chickenEvent("queen") -- notify unsynced about queen spawn
				_, queenMaxHP = GetUnitHealth(queenID)
				SetUnitExperience(queenID, expMod)
				timeOfLastWave = t
				for i = 1, 10, 1 do
					if mRandom() < config.spawnChance then
						table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID, })
						table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID, })
					end
				end
			end
		else
			if mRandom() < config.spawnChance / 20 then
				table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh2", team = chickenTeamID, })
				for i = 1, mRandom(1, 2), 1 do
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh3", team = chickenTeamID, })
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID, })
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID, })
				end
				for i = 1, mRandom(1, 5), 1 do
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh4", team = chickenTeamID })
				end
			end
		end
	end

	local function spawnCreepStructure(unitDefName, spread)
		local structureDefID = UnitDefNames[unitDefName].id
		local canSpawnStructure = true
		local spread = 128
		local spawnPosX = math.random(lsx1,lsx2)
		local spawnPosZ = math.random(lsz1,lsz2)

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
				else
					canSpawnStructure = false
				end
			end
			if canSpawnStructure then
				local structureUnitID = Spring.CreateUnit(structureDefID, spawnPosX, spawnPosY, spawnPosZ, math.random(0,3), chickenTeamID)
				return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
			end
		end
	end

	local function queueTurretSpawnIfNeeded()
		local burrowCount = SetCount(burrows)
		if math.random(0,config.burrowSpawnRate*6) == 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
			if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < burrowCount or Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < 2 then
				attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + 1
			end
		end
		if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < burrowCount*2 then
			if attemptingToSpawnHeavyTurret > 0 then
				local heavyTurretUnitID = spawnCreepStructure(heavyTurret, spread)
				if heavyTurretUnitID then
					attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret - 1
					SetUnitExperience(heavyTurretUnitID, mRandom() * expMod)
					attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + 5
				end
			end
		end

		if math.random(0,config.burrowSpawnRate*6) == 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
			if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < burrowCount*5 or Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < 10 then
				attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + 10
			end
		end
		if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < burrowCount*10 then
			if attemptingToSpawnLightTurret > 0 then
				local lightTurretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(lightTurret, spread)
				if lightTurretUnitID then
					attemptingToSpawnLightTurret = attemptingToSpawnLightTurret - 1
					SetUnitExperience(lightTurretUnitID, mRandom() * expMod)
					Spring.GiveOrderToUnit(lightTurretUnitID, CMD.PATROL, {spawnPosX + math.random(-128,128), spawnPosY, spawnPosZ + math.random(-128,128)}, {"meta"})
				end
			end
		end
	end

	function gadget:GameFrame(n)

		-- remove initial commander (no longer required)
		if n == 1 then
			PutChickenAlliesInChickenTeam(n)
			local units = Spring.GetTeamUnits(chickenTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			chickenCount = UpdateUnitCount()
			return
		end

		if n == 15 then
			DisableComputerUnits()
			config.burrowSpawnRate = config.burrowSpawnRate/SetCount(humanTeams)
			--config.chickenMaxSpawnRate = config.chickenMaxSpawnRate/SetCount(humanTeams)
		end

		if n % 90 == 0 then
			if (queenAnger >= 100) then
				damageMod = (damageMod + 0.005)
			end
		end

		local chickenTeamUnitCount = Spring.GetTeamUnitCount(chickenTeamID) or 0
		if chickenTeamUnitCount < maxChicken then
			SpawnChickens()
		end

		for unitID, defs in pairs(deathQueue) do
			if ValidUnitID(unitID) and not GetUnitIsDead(unitID) then
				DestroyUnit(unitID, defs.selfd or false, defs.reclaimed or false)
			end
		end

		if n >= timeCounter then
			timeCounter = (n + UPDATE)
			t = GetGameSeconds()
			if not queenID then
				if t < config.gracePeriod then
					queenAnger = 0
				else
					queenAnger = math.ceil(math.min((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100) + burrowAnger, 100)
				end
				SetGameRulesParam("queenAnger", queenAnger)
			end

			if t < config.gracePeriod then
				-- do nothing in the grace period
				return
			end

			expMod = (expMod + expIncrement) -- increment experience

			if queenAnger >= 100 then
				-- check if the queen should be alive
				updateSpawnQueen()
				updateQueenLife()
			end

			local quicken = 0
			local burrowCount = SetCount(burrows)

			if config.burrowSpawnRate < (t - timeOfLastFakeSpawn) then
				-- This block is all about setting the correct burrow target
				if firstSpawn then
					minBurrows = 1
				end
				timeOfLastFakeSpawn = t
			end

			local burrowSpawnTime = (config.burrowSpawnRate - quicken)

			if burrowCount < minBurrows or (burrowSpawnTime < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if firstSpawn then
					SpawnBurrow()
					timeOfLastSpawn = t
					timeOfLastWave = (config.gracePeriod + 10) - config.chickenMaxSpawnRate
					firstSpawn = false
					if (config.burrowSpawnType == "initialbox") then
						config.burrowSpawnType = "initialbox_post"
					end
				else
					SpawnBurrow()
				end
				if burrowCount >= minBurrows then
					timeOfLastSpawn = t
				end
				chickenEvent("burrowSpawn")
				SetGameRulesParam("roostCount", SetCount(burrows))
			elseif burrowSpawnTime < t - timeOfLastSpawn and burrowCount >= maxBurrows then
				if math.random(0,3) == 1 then
					attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + 1
				end
				attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + 2
				timeOfLastSpawn = t
			end

			if burrowCount > 0 and ((config.chickenMaxSpawnRate < (t - timeOfLastWave)) or (chickenCount < lastWaveUnitCount) and (t - timeOfLastWave) > config.chickenMaxSpawnRate*0.5) then
				local cCount = Wave()
				if cCount and cCount > 0 then
					chickenEvent("wave", cCount, currentWave)
				end
				lastWaveUnitCount = cCount
				timeOfLastWave = t
			end
			chickenCount = UpdateUnitCount()
		end
		if n%30 == 10 and n > 300 and chickenTeamUnitCount < maxChicken then
			queueTurretSpawnIfNeeded()
		end
		local squadID = (n % #squadsTable)+1
		if not chickenteamhasplayers then
			if squadID and squadsTable[squadID] and squadsTable[squadID].squadRole ~= "aircraft" and squadsTable[squadID].squadRole ~= "artillery" then
				local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
				if targetx then
					squadCommanderGiveOrders(squadID, targetx, targety, targetz)
				else
					refreshSquad(squadID)
				end
			end
		end
		if n%300 == 100 and not chickenteamhasplayers then
			local chickens = Spring.GetTeamUnits(chickenTeamID)
			for i = 1,#chickens do 
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
						Spring.GiveOrderToUnit(chickens[i], CMD.FIGHT, getRandomMapPos(), {})
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
			color = chickenEggColors[math.random(1,#chickenEggColors)]
		end
		
		
		
			local egg = Spring.CreateFeature("chicken_egg_"..size.."_"..color, x, y, z, math.random(-999999,999999), chickenTeamID)
		if egg then
			Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
			Spring.SetFeatureVelocity(egg, mRandom(-195,195)*0.01, mRandom(130,335)*0.01, mRandom(-195,195)*0.01)
			--Spring.SetFeatureRotation(egg, mRandom(-175,175)*50000, mRandom(110,275)*50000, mRandom(-175,175)*50000)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)

		if unitTeam == chickenTeamID then
			local x,y,z = Spring.GetUnitPosition(unitID)
			if unitDefID == config.burrowDef or UnitDefs[unitDefID].name == "chickend2" then
				for i = 1,math.random(10,40) do
					local x = x + math.random(-32,32)
					local z = z + math.random(-32,32)
					local y = GetGroundHeight(x, z)
					spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name)
				end
			elseif UnitDefs[unitDefID].name == "chickend1" then
				for i = 1,math.random(3,10) do
					local x = x + math.random(-16,16)
					local z = z + math.random(-16,16)
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
		if unitTargetPool[unitID] then
			refreshSquad(unitTargetPool[unitID])
			unitTargetPool[unitID] = nil
		end
		

		if unitTeam == chickenTeamID and chickenDefTypes[unitDefID] then
			local name = unitName[unitDefID]
			if unitDefID ~= config.burrowDef then
				name = string.sub(name, 1, -2)
			end
			local kills = GetGameRulesParam("chicken" .. "Kills")
			SetGameRulesParam("chicken" .. "Kills", kills + 1)
			chickenCount = chickenCount - 1
			if attackerID then
				local x, _, z = GetUnitPosition(attackerID)
				if x and z then
					local area = math.floor(x / DMAREA) .. "," .. math.floor(z / DMAREA)
					if defenseMap[area] == nil then
						defenseMap[area] = 1
					else
						defenseMap[area] = defenseMap[area] + 1
					end
				end
			end
		end

		if unitID == queenID then
			-- queen destroyed
			queenID = nil
			maxChicken = oldMaxChicken
			damageMod = oldDamageMod
			queenResistance = {}

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

		if unitDefID == config.burrowDef and not gameOver then
			local kills = GetGameRulesParam(config.burrowName .. "Kills")
			SetGameRulesParam(config.burrowName .. "Kills", kills + 1)

			burrows[unitID] = nil
			if config.addQueenAnger then
				burrowAnger = (burrowAnger + config.angerBonus)
				expMod = (expMod + config.angerBonus)
			end

			for i, defs in pairs(spawnQueue) do
				if defs.burrow == unitID then
					spawnQueue[i] = nil
				end
			end

			if math.random(1,4) == 1 then
				attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + 1
			end
			attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + math.random(1,5)
			maxWaveSize = maxWaveSize+(SetCount(humanTeams) * config.chickenSpawnMultiplier )

			SetGameRulesParam("roostCount", SetCount(burrows))
		end

		if UnitDefs[unitDefID].name == "chickend1" then
			attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + math.random(0,1)
			if config.addQueenAnger then
				burrowAnger = (burrowAnger + (config.angerBonus*0.25))
			end
		end
		if UnitDefs[unitDefID].name == "chickend2" then
			attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + math.random(0,5)
			attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + math.random(0,1)
			if config.addQueenAnger then
				burrowAnger = (burrowAnger + config.angerBonus)
			end
		end

		if unitDefID == OVERSEER_ID then
			overseers[unitID] = nil
		end
	end

	function gadget:TeamDied(teamID)
		if humanTeams[teamID] then
			if minBurrows > 1 then
				minBurrows = (minBurrows - 1)
			end
		end
		humanTeams[teamID] = nil
		computerTeams[teamID] = nil
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

end
