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
	local minBurrows = 1
	local timeOfLastSpawn = -999999
	local timeOfLastFakeSpawn = 0
	local timeOfLastWave = 0
	local t = 0 -- game time in secondstarget
	local queenAnger = 0
	local techAnger = 0
	local queenMaxHP = 0
	local playerAgression = 0
	local playerAgressionLevel = 0
	local playerAgressionEcoValue = 0
	local queenAngerAgressionLevel = 0
	local difficultyCounter = config.difficulty
	local waveParameters = {
		baseCooldown = mRandom(3,5),
		airWave = {
			cooldown = mRandom(1,2),
		},
	}
	local squadSpawnOptions = config.squadSpawnOptionsTable
	--local miniBossCooldown = 0
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
	local burrowTurrets = {}
	local heroChicken = {}
	local aliveEggsTable = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadPotentialTarget = {}
	local squadPotentialHighValueTarget = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local unitTeleportCooldown = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = 10,
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = 10,
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}

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
		local loops = 0
		local targetCount = SetCount(squadPotentialTarget)
		local highValueTargetCount = SetCount(squadPotentialHighValueTarget)
		local pos = {}
		local pickedTarget = nil
		repeat
			loops = loops + 1
			if highValueTargetCount > 0 and mRandom() <= 0.75 then
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

	function setChickenXP(unitID)
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

	local maxBurrows = ((config.maxBurrows*(1-config.chickenPerPlayerMultiplier))+(config.maxBurrows*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	local queenTime = (config.queenTime + config.gracePeriod)
	if config.difficulty == config.difficulties.survival then
		queenTime = math.ceil(queenTime*0.5)
	end
	local maxWaveSize = ((config.maxChickens*(1-config.chickenPerPlayerMultiplier))+(config.maxChickens*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	local minWaveSize = ((config.minChickens*(1-config.chickenPerPlayerMultiplier))+(config.minChickens*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
	config.chickenSpawnRate = config.chickenSpawnRate*Spring.GetModOptions().chicken_spawntimemult
	local currentMaxWaveSize = minWaveSize
	function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		queenAnger = 0  -- reenable chicken spawning
		techAnger = 0
		playerAgression = 0
		queenAngerAgressionLevel = 0
		pastFirstQueen = true
		SetGameRulesParam("queenAnger", queenAnger)
		local nextDifficulty
		difficultyCounter = difficultyCounter + 1
		if config.difficultyParameters[difficultyCounter] then
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.queenResistanceMult = nextDifficulty.queenResistanceMult
		else
			difficultyCounter = difficultyCounter - 1
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.chickenSpawnMultiplier = config.chickenSpawnMultiplier+1
			config.queenResistanceMult = config.queenResistanceMult+0.5
		end
		config.queenName = nextDifficulty.queenName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.turretSpawnRate = nextDifficulty.turretSpawnRate
		config.queenSpawnMult = nextDifficulty.queenSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxChickens = nextDifficulty.maxChickens
		config.minChickens = nextDifficulty.minChickens
		config.maxBurrows = nextDifficulty.maxBurrows
		config.maxXP = nextDifficulty.maxXP
		config.angerBonus = nextDifficulty.angerBonus
		config.queenTime = math.ceil(nextDifficulty.queenTime*0.5)
		queenTime = (config.queenTime + config.gracePeriod)
		maxBurrows = ((config.maxBurrows*(1-config.chickenPerPlayerMultiplier))+(config.maxBurrows*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
		maxWaveSize = ((config.maxChickens*(1-config.chickenPerPlayerMultiplier))+(config.maxChickens*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
		minWaveSize = ((config.minChickens*(1-config.chickenPerPlayerMultiplier))+(config.minChickens*config.chickenPerPlayerMultiplier)*SetCount(humanTeams))*config.chickenSpawnMultiplier
		config.chickenSpawnRate = nextDifficulty.chickenSpawnRate*Spring.GetModOptions().chicken_spawntimemult
		currentMaxWaveSize = minWaveSize
		SetGameRulesParam("ChickenQueenAngerGain_Base", 100/config.queenTime) 
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game Rules
	--

	SetGameRulesParam("queenTime", queenTime)
	SetGameRulesParam("queenLife", queenLifePercent)
	SetGameRulesParam("queenAnger", queenAnger)
	SetGameRulesParam("gracePeriod", config.gracePeriod)
	SetGameRulesParam("difficulty", config.difficulty)
	SetGameRulesParam("ChickenQueenAngerGain_Base", 100/config.queenTime) 
	SetGameRulesParam("ChickenQueenAngerGain_Aggression", 0)
	SetGameRulesParam("ChickenQueenAngerGain_Eco", 0)


	function chickenEvent(type, num, tech)
		SendToUnsynced("ChickenEvent", type, num, tech)
	end

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
		local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
		squadsTable[squadID].squadNeedsRefresh = true
		--squadCommanderGiveOrders(squadID, targetx, targety, targetz)
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
				newSquad.life = 10
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


	function getChickenSpawnLoc(burrowID, size)
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

	function SpawnRandomOffWaveSquad(burrowID, chickenType, count)
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
			squadCounter = 0
			local squad
			local specialRandom = mRandom(1,100)
			for _ = 1,1000 do
				if specialRandom <= 33 then
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
				for i, sString in pairs(squad.units) do
					local nEnd, _ = string.find(sString, " ")
					local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
					local chickenName = string.sub(sString, (nEnd + 1))
					for j = 1, unitNumber, 1 do
						squadCounter = squadCounter + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
					end
				end
			end
		end
		return squadCounter
	end
	
	function SpawnBurrowTurret(burrowID, burrowX, burrowY, burrowZ, turretX, turretZ)
		if mRandom() < config.spawnChance then
			local turretOptions = {}
			for uName, uSettings in pairs(config.chickenTurrets) do
				if not uSettings.maxQueenAnger then uSettings.maxQueenAnger = uSettings.minQueenAnger + 50 end
				if uSettings.minQueenAnger <= techAnger and uSettings.maxQueenAnger >= techAnger and uSettings.spawnOnBurrows then
					for i = 1,uSettings.spawnedPerWave do
						table.insert(turretOptions, uName)
					end
				end
			end
			if #turretOptions > 0 then
				local turretID = CreateUnit(turretOptions[mRandom(1,#turretOptions)], turretX, burrowY, turretZ, mRandom(0,3), chickenTeamID)
				if turretID then
					SetUnitBlocking(turretID, false, false)
					setChickenXP(turretID)
					Spring.GiveOrderToUnit(turretID, CMD.PATROL, {burrowX, burrowY, burrowZ}, {"meta"})
					burrowTurrets[turretID] = burrowID
				end
			end
		end
	end

	function SetupBurrow(unitID, x, y, z)
		burrows[unitID] = 0
		SetUnitBlocking(unitID, false, false)
		setChickenXP(unitID)
		if SetCount(config.chickenTurrets) > 0 then
			local r = math.random(1,100)
			-- spawn some turrets
			SpawnBurrowTurret(unitID, x, y, z, x-config.burrowTurretSpawnRadius, z-config.burrowTurretSpawnRadius)
			SpawnBurrowTurret(unitID, x, y, z, x+config.burrowTurretSpawnRadius, z-config.burrowTurretSpawnRadius)
			SpawnBurrowTurret(unitID, x, y, z, x-config.burrowTurretSpawnRadius, z+config.burrowTurretSpawnRadius)
			SpawnBurrowTurret(unitID, x, y, z, x+config.burrowTurretSpawnRadius, z+config.burrowTurretSpawnRadius)
			SpawnBurrowTurret(unitID, x, y, z, x+(config.burrowTurretSpawnRadius*1.5), z)
			SpawnBurrowTurret(unitID, x, y, z, x-(config.burrowTurretSpawnRadius*1.5), z)
			SpawnBurrowTurret(unitID, x, y, z, x, z+(config.burrowTurretSpawnRadius*1.5))
			SpawnBurrowTurret(unitID, x, y, z, x, z-(config.burrowTurretSpawnRadius*1.5))

			SpawnBurrowTurret(unitID, x, y, z, x-config.burrowTurretSpawnRadius*0.5, z-config.burrowTurretSpawnRadius*1.25)
			SpawnBurrowTurret(unitID, x, y, z, x+config.burrowTurretSpawnRadius*1.25, z-config.burrowTurretSpawnRadius*0.5)
			SpawnBurrowTurret(unitID, x, y, z, x-config.burrowTurretSpawnRadius*1.25, z+config.burrowTurretSpawnRadius*0.5)
			SpawnBurrowTurret(unitID, x, y, z, x+config.burrowTurretSpawnRadius*0.5, z+config.burrowTurretSpawnRadius*1.25)
			SpawnBurrowTurret(unitID, x, y, z, x+(config.burrowTurretSpawnRadius*1.25), z+config.burrowTurretSpawnRadius*0.5)
			SpawnBurrowTurret(unitID, x, y, z, x-(config.burrowTurretSpawnRadius*1.25), z-config.burrowTurretSpawnRadius*0.5)
			SpawnBurrowTurret(unitID, x, y, z, x-config.burrowTurretSpawnRadius*0.5, z+(config.burrowTurretSpawnRadius*1.25))
			SpawnBurrowTurret(unitID, x, y, z, x+config.burrowTurretSpawnRadius*0.5, z-(config.burrowTurretSpawnRadius*1.25))
		end
	end

	function SpawnBurrow(number)

		--local unitDefID = UnitDefNames[config.burrowName].id

		for i = 1, (number or 1) do
			local x, z, y
			local tries = 0
			local canSpawnBurrow = false
			repeat
				if config.burrowSpawnType == "initialbox" or config.burrowSpawnType == "initialbox_post" or config.burrowSpawnType == "alwaysbox" then
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
					if config.useScum and GG.IsPosInChickenScum(x, y, z) and mRandom(1,5) == 1 then
						canSpawnBurrow = true
					else
						if tries < maxTries*3 then
							canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, true)
						else
							canSpawnBurrow = false
						end
					end
				end

				if canSpawnBurrow then
					canSpawnBurrow = positionCheckLibrary.OccupancyCheck(x, y, z, config.minBaseDistance)
				end

				if canSpawnBurrow then
					canSpawnBurrow = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
				end

				if canSpawnBurrow then
					for burrowID, _ in pairs(burrows) do
						local bx, _, bz = Spring.GetUnitPosition(burrowID)
						local spread = config.minBaseDistance
						if x > bx-spread and x < bx+spread and z > bz-spread and z < bz+spread then
							canSpawnBurrow = false
							break
						end
					end
				end

			until (canSpawnBurrow == true or tries >= maxTries * 4)

			if canSpawnBurrow then
				local unitID = CreateUnit(config.burrowName, x, y, z, mRandom(0,3), chickenTeamID)
				if unitID then
					SetupBurrow(unitID, x, y, z)
				end
			else
				for j = 1,100 do
					x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
					z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
					y = GetGroundHeight(x, z)

					canSpawnBurrow = positionCheckLibrary.StartboxCheck(x, y, z, chickenAllyTeamID)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, false)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
					end
					if canSpawnBurrow and playerAgression > config.angerBonus*10 then
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, false)
					end
					if canSpawnBurrow then
						for burrowID, _ in pairs(burrows) do
							local bx, _, bz = Spring.GetUnitPosition(burrowID)
							local spread = 100*SetCount(burrows)
							if x > bx-spread and x < bx+spread and z > bz-spread and z < bz+spread then
								canSpawnBurrow = false
								break
							end
						end
					end
					if canSpawnBurrow then
						local unitID = CreateUnit(config.burrowName, x, y, z, mRandom(0,3), chickenTeamID)
						if unitID then
							SetupBurrow(unitID, x, y, z)
							break
						end
					elseif j == 100 then
						timeOfLastSpawn = GetGameSeconds()
						playerAgression = playerAgression + (config.angerBonus*(queenAnger*0.01))
					end
				end
			end
		end
	end

	function updateQueenLife()
		if not queenID then
			SetGameRulesParam("queenLife", 0)
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

	function SpawnQueen()
		local bestScore = 0
		local bestBurrowID
		local sx, sy, sz
		for burrowID, _ in pairs(burrows) do
			-- Try to spawn the queen at the 'best' burrow
			local x, y, z = GetUnitPosition(burrowID)
			if x and y and z then
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
			return CreateUnit(config.queenName, sx, sy, sz, mRandom(0,3), chickenTeamID), burrowID
		end

		local x, z, y
		local tries = 0
		local canSpawnQueen = false
		repeat
			x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
			z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
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
				x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
				z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
				y = GetGroundHeight(x, z)

				canSpawnQueen = positionCheckLibrary.StartboxCheck(x, y, z, chickenAllyTeamID)
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

	function Wave()
		if gameOver then
			return
		end
		squadManagerKillerLoop()
		
		local waveType = "normal"
		waveParameters.baseCooldown = waveParameters.baseCooldown - 1
		waveParameters.airWave.cooldown = waveParameters.airWave.cooldown - 1
		
		if waveParameters.baseCooldown <= 0 then
			-- special waves
			if techAnger > config.airStartAnger and waveParameters.airWave.cooldown <= 0 then
				waveParameters.airWave.cooldown = mRandom(5,10)
				waveParameters.baseCooldown = mRandom(2,4)
				waveType = "air"
			end
		end

		local cCount = 0
		local loopCounter = 0
		local squadCounter = 0
		repeat
			loopCounter = loopCounter + 1
			for burrowID in pairs(burrows) do
				if mRandom() <= config.spawnChance then
					squadCounter = 0
					local squad
					if (waveType == "air" or (queenID and mRandom() <= 0.25)) and mRandom() <= 0.5 then
						for _ = 1,1000 do
							local potentialSquad = squadSpawnOptions.air[mRandom(1, #squadSpawnOptions.air)]
							if potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger then
								squad = potentialSquad
								break
							end
						end
					else
						local specialRandom = mRandom(1,100)
						for _ = 1,1000 do
							if specialRandom <= 33 then
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
						for i, sString in pairs(squad.units) do
							local nEnd, _ = string.find(sString, " ")
							local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
							local chickenName = string.sub(sString, (nEnd + 1))
							for j = 1, unitNumber, 1 do
								squadCounter = squadCounter + 1
								table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID, squadID = squadCounter })
							end
							cCount = cCount + unitNumber
						end
						if waveType ~= "air" then
							table.insert(spawnQueue, { burrow = burrowID, unitName = config.chickenHealers[mRandom(1,#config.chickenHealers)], team = chickenTeamID, squadID = 1 })
							cCount = cCount + 1
						end
					end
				end
			end
		until (cCount > currentMaxWaveSize or loopCounter >= 200*config.chickenSpawnMultiplier)

		if waveType == "air" and cCount > 0 then
			chickenEvent("airWave", cCount)
		elseif config.useWaveMsg then
			chickenEvent("wave", cCount)
		end
		return cCount
	end

	function spawnCreepStructure(unitDefName, spread)
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
				if config.useScum and GG.IsPosInChickenScum(spawnPosX, spawnPosY, spawnPosZ) then
					canSpawnStructure = true
				elseif (not config.useScum) and positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, true, true) then
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
				if structureUnitID then
					SetUnitBlocking(structureUnitID, false, false)
					return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
				end
			end
		end
	end

	function spawnCreepStructuresWave()
		for uName, uSettings in pairs(config.chickenTurrets) do
			--Spring.Echo(uName)
			--Spring.Debug.TableEcho(uSettings)
			if not uSettings.maxQueenAnger then uSettings.maxQueenAnger = uSettings.minQueenAnger + 100 end
			if uSettings.minQueenAnger <= techAnger and uSettings.maxQueenAnger >= techAnger then
				for i = 1,math.floor((uSettings.spawnedPerWave*(1-config.chickenPerPlayerMultiplier))+(uSettings.spawnedPerWave*config.chickenPerPlayerMultiplier)*SetCount(humanTeams)) do
					if mRandom() < config.spawnChance then
						local attempts = 0
						repeat
							attempts = attempts + 1
							local turretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(uName)
							if turretUnitID then
								setChickenXP(turretUnitID)
								Spring.GiveOrderToUnit(turretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
							end
						until turretUnitID or attempts > 100
					end
				end
			end
		end
	end

	function SpawnMinions(unitID, unitDefID)
		local unitName = UnitDefs[unitDefID].name
		if config.chickenMinions[unitName] then
			local minion = config.chickenMinions[unitName][mRandom(1,#config.chickenMinions[unitName])]
			SpawnRandomOffWaveSquad(unitID, minion, 4)
		end
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------


	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == chickenTeamID then
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{3},0)
			if UnitDefs[unitDefID].canCloak then
				Spring.GiveOrderToUnit(unitID,37382,{1},0)
			end
			return
		end
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
			playerAgressionEcoValue = playerAgressionEcoValue + (config.ecoBuildingsPenalty[unitDefID]/(config.queenTime/3600)) -- scale to 60minutes = 3600seconds queen time
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if unitTeam == chickenTeamID and attackerTeam == chickenTeamID and (not (attackerDefID and config.chickenBehaviours.ARTILLERY[attackerDefID])) then
			return 0
		end

		if attackerTeam == chickenTeamID then
			damage = damage * damageMod
		end

		if heroChicken[unitID] then
			damage = (damage * heroChicken[unitID])
		end

		if unitID == queenID then -- Queen Resistance
			if attackerDefID then
				if weaponID == -1 and damage > 1 then
					damage = 1
				end
				if not queenResistance[attackerDefID] then
					queenResistance[attackerDefID] = {}
					queenResistance[attackerDefID].damage = (damage * 4 * config.queenResistanceMult)
					queenResistance[attackerDefID].notify = 0
				end
				local resistPercent = math.min((queenResistance[attackerDefID].damage) / queenMaxHP, 0.95)
				if resistPercent > 0.5 then
					if queenResistance[attackerDefID].notify == 0 then
						chickenEvent("queenResistance", attackerDefID)
						queenResistance[attackerDefID].notify = 1
						if mRandom() < config.spawnChance then
							SpawnRandomOffWaveSquad(queenID, config.chickenHealers[mRandom(1,#config.chickenHealers)], SetCount(humanTeams)*10)
						end
						for _ = 1,SetCount(humanTeams) do
							if mRandom() < config.spawnChance then
								SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
							end
						end
						spawnCreepStructuresWave()
					end
					damage = damage - (damage * resistPercent)
					
				end
				queenResistance[attackerDefID].damage = queenResistance[attackerDefID].damage + (damage * 4 * config.queenResistanceMult)
			else
				damage = 1
			end
			return damage
		end

		if burrowTurrets[unitID] and (not paralyzer) then
			local health, maxHealth = Spring.GetUnitHealth(burrowTurrets[unitID])
			if health and maxHealth then
				Spring.SetUnitHealth(burrowTurrets[unitID], health-damage)
				--Spring.AddUnitDamage(burrowTurrets[unitID], damage)
			end
			damage = 0
		end
		return damage, 1
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		if not chickenteamhasplayers then
			if config.chickenBehaviours.SKIRMISH[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < config.chickenBehaviours.SKIRMISH[attackerDefID].chance) and unitTeam ~= attackerTeam then
				local ux, uy, uz = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				if x and ux then
					local angle = math.atan2(ux - x, uz - z)
					local distance = mRandom(math.ceil(config.chickenBehaviours.SKIRMISH[attackerDefID].distance*0.75), math.floor(config.chickenBehaviours.SKIRMISH[attackerDefID].distance*1.25))
					if config.chickenBehaviours.SKIRMISH[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						Spring.SetUnitPosition(attackerID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.chickenBehaviours.SKIRMISH[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			elseif config.chickenBehaviours.COWARD[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < config.chickenBehaviours.COWARD[unitDefID].chance) and unitTeam ~= attackerTeam then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH and curH < (maxH * 0.8) then
					local ax, ay, az = GetUnitPosition(attackerID)
					local x, y, z = GetUnitPosition(unitID)
					if x and ax then
						local angle = math.atan2(ax - x, az - z)
						local distance = mRandom(math.ceil(config.chickenBehaviours.COWARD[unitDefID].distance*0.75), math.floor(config.chickenBehaviours.COWARD[unitDefID].distance*1.25))
						if config.chickenBehaviours.COWARD[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
							Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
							Spring.SetUnitPosition(unitID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
							Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
							Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
							unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.chickenBehaviours.COWARD[unitDefID].teleportcooldown*30
						else
							Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
						end
						unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
					end
				end
			elseif config.chickenBehaviours.BERSERK[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < config.chickenBehaviours.BERSERK[unitDefID].chance) and unitTeam ~= attackerTeam then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (config.chickenBehaviours.BERSERK[unitDefID].distance or 10000) then
					if config.chickenBehaviours.BERSERK[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-64,64)
						az = az + mRandom(-64,64)
						Spring.SetUnitPosition(unitID, ax, ay, az)
						Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.chickenBehaviours.BERSERK[unitDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
				end
			elseif config.chickenBehaviours.BERSERK[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < config.chickenBehaviours.BERSERK[attackerDefID].chance) and unitTeam ~= attackerTeam then
				local ax, ay, az = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (config.chickenBehaviours.BERSERK[attackerDefID].distance or 10000) then
					if config.chickenBehaviours.BERSERK[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-64,64)
						az = az + mRandom(-64,64)
						Spring.SetUnitPosition(attackerID, ax, ay, az)
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.chickenBehaviours.BERSERK[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			end
			if queenID and unitID == queenID then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH then
					curH = math.max(curH, maxH*0.05)
					local spawnChance = math.max(0, math.ceil(curH/maxH*10000))
					if mRandom(0,spawnChance) == 1 then
						SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
						SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
					end
				end
			end
			if unitTeam == chickenTeamID or attackerTeam == chickenTeamID then
				if (unitID and unitSquadTable[unitID] and squadsTable[unitSquadTable[unitID]] and squadsTable[unitSquadTable[unitID]].squadLife and squadsTable[unitSquadTable[unitID]].squadLife < 10) then
					squadsTable[unitSquadTable[unitID]].squadLife = 10
				end
				if (attackerID and unitSquadTable[attackerID] and squadsTable[unitSquadTable[attackerID]] and squadsTable[unitSquadTable[attackerID]].squadLife and squadsTable[unitSquadTable[attackerID]].squadLife < 10) then
					squadsTable[unitSquadTable[attackerID]].squadLife = 10
				end
			end
		end
	end

	function gadget:GameStart()
		if config.burrowSpawnType == "initialbox" or config.burrowSpawnType == "alwaysbox" or config.burrowSpawnType == "initialbox_post" then
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

	function SpawnChickens()
		local i, defs = next(spawnQueue)
		if not i or not defs then
			if #squadCreationQueue.units > 0 then
				if mRandom(1,5) == 1 then
					squadCreationQueue.regroupenabled = false
				end
				local squadID = createSquad(squadCreationQueue)
				squadCreationQueue.units = {}
				refreshSquad(squadID)
				-- Spring.Echo("[RAPTOR] Number of active Squads: ".. #squadsTable)
				-- Spring.Echo("[RAPTOR] Wave spawn complete.")
				-- Spring.Echo(" ")
			end
			return
		end
		local x, y, z = getChickenSpawnLoc(defs.burrow, config.chickenBehaviours.PROBE_UNIT)
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
				end
			end
			if defs.burrow and (not squadCreationQueue.burrow) then
				squadCreationQueue.burrow = defs.burrow
			end
			squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
			if config.chickenBehaviours.HEALER[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "healer"
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if config.chickenBehaviours.ARTILLERY[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "artillery"
				squadCreationQueue.regroupenabled = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if config.chickenBehaviours.KAMIKAZE[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "kamikaze"
				squadCreationQueue.regroupenabled = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if UnitDefNames[defs.unitName].canFly then
				squadCreationQueue.role = "aircraft"
				squadCreationQueue.regroupenabled = false
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

	function updateSpawnQueen()
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
		else
			if mRandom() < config.spawnChance / 15 then
				SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
				SpawnMinions(queenID, Spring.GetUnitDefID(queenID))
				--SpawnRandomOffWaveSquad(queenID)
			end
		end
	end

	function updateRaptorSpawnBox()
		if config.burrowSpawnType == "initialbox_post" then
			lsx1 = math.max(RaptorStartboxXMin - ((MAPSIZEX*0.01) * queenAnger), 0)
			lsz1 = math.max(RaptorStartboxZMin - ((MAPSIZEZ*0.01) * queenAnger), 0)
			lsx2 = math.min(RaptorStartboxXMax + ((MAPSIZEX*0.01) * queenAnger), MAPSIZEX)
			lsz2 = math.min(RaptorStartboxZMax + ((MAPSIZEZ*0.01) * queenAnger), MAPSIZEZ)
		end
	end

	local chickenEggColors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}
	function spawnRandomEgg(x,y,z,name,spread)
		if name then
			local totalEggValue = 0
			local targetEggValue = UnitDefNames[name].metalCost*0.5
			repeat
				-- local rSize = mRandom(1,100)
				-- local eggValue = 100
				-- local size = "s"
				-- if rSize <= 5 then
				-- 	size = "l"
				-- 	eggValue = 500
				-- elseif rSize <= 20 then
				-- 	size = "m"
				-- 	eggValue = 200
				-- end
				local eggValue = 200
				local size = "s"
				if targetEggValue - totalEggValue > 8000 then
					size = "l"
					eggValue = 2000
				elseif targetEggValue - totalEggValue > 2000 then
					size = "m"
					eggValue = 500
				end
				totalEggValue = totalEggValue + eggValue
				if config.chickenEggs[name] and config.chickenEggs[name] ~= "" then
					color = config.chickenEggs[name]
				else
					color = chickenEggColors[mRandom(1,#chickenEggColors)]
				end
				local egg = Spring.CreateFeature("chicken_egg_"..size.."_"..color, x + mRandom(-spread,spread), y + 20, z + mRandom(-spread,spread), mRandom(-999999,999999), chickenTeamID)
				if egg then
					Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
					Spring.SetFeatureVelocity(egg, mRandom(-195,195)*0.01, mRandom(130,335)*0.01, mRandom(-195,195)*0.01)
					--Spring.SetFeatureRotation(egg, mRandom(-175,175)*50000, mRandom(110,275)*50000, mRandom(-175,175)*50000)
				end
			until totalEggValue >= targetEggValue
		else
			local rSize = mRandom(1,100)
			local size = "s"
			if rSize <= 5 then
				size = "l"
			elseif rSize <= 20 then
				size = "m"
			end
			local color = chickenEggColors[mRandom(1,#chickenEggColors)]
			local egg = Spring.CreateFeature("chicken_egg_"..size.."_"..color, x + mRandom(-spread,spread), y + 20, z + mRandom(-spread,spread), mRandom(-999999,999999), chickenTeamID)
			if egg then
				Spring.SetFeatureMoveCtrl(egg, false,1,1,1,1,1,1,1,1,1)
				Spring.SetFeatureVelocity(egg, mRandom(-195,195)*0.01, mRandom(130,335)*0.01, mRandom(-195,195)*0.01)
				--Spring.SetFeatureRotation(egg, mRandom(-175,175)*50000, mRandom(110,275)*50000, mRandom(-175,175)*50000)
			end
		end
	end

	function decayRandomEggs()
		for eggID, _ in pairs(aliveEggsTable) do
			if mRandom(1,18) == 1 then -- scaled to decay 1000hp egg in about 3 minutes +/- RNG
				local fx, fy, fz = Spring.GetFeaturePosition(eggID)
				Spring.SetFeatureHealth(eggID, Spring.GetFeatureHealth(eggID) - 20)
				if Spring.GetFeatureHealth(eggID) <= 0 then
					Spring.DestroyFeature(eggID)
				end
			end
		end
	end

	local announcedFirstWave = false
	function gadget:GameFrame(n)

		if announcedFirstWave == false and GetGameSeconds() > config.gracePeriod then
			chickenEvent("firstWave")
			announcedFirstWave = true
		end
		-- remove initial commander (no longer required)
		if n == 1 then
			PutChickenAlliesInChickenTeam(n)
			local units = GetTeamUnits(chickenTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			return
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
			playerAgression = playerAgression*0.995
			playerAgressionLevel = math.floor(playerAgression)
			SetGameRulesParam("chickenPlayerAgressionLevel", playerAgressionLevel)
			currentMaxWaveSize = (minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))
			if t < config.gracePeriod then
				queenAnger = 0
				techAnger = 0
				minBurrows = SetCount(humanTeams)
			else
				if pastFirstQueen then
					techAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / ((queenTime/Spring.GetModOptions().chicken_queentimemult) - config.gracePeriod) * 100) - (playerAgressionLevel*1) + queenAngerAgressionLevel, 999), 0)
				else
					techAnger = math.max(math.ceil(math.min((t - (config.gracePeriod/Spring.GetModOptions().chicken_graceperiodmult)) / ((queenTime/Spring.GetModOptions().chicken_queentimemult) - (config.gracePeriod/Spring.GetModOptions().chicken_graceperiodmult)) * 100) - (playerAgressionLevel*1) + queenAngerAgressionLevel, 999), 0)
				end
				if not queenID then
					queenAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100) + queenAngerAgressionLevel, 100), 0)
					minBurrows = SetCount(humanTeams)
				else
					queenAnger = 100
					minBurrows = 1
				end
				queenAngerAgressionLevel = queenAngerAgressionLevel + ((playerAgression*0.01)/(config.queenTime/3600)) + playerAgressionEcoValue
				SetGameRulesParam("ChickenQueenAngerGain_Aggression", (playerAgression*0.01)/(config.queenTime/3600))
				SetGameRulesParam("ChickenQueenAngerGain_Eco", playerAgressionEcoValue)
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
				timeOfLastFakeSpawn = t
			end

			if t > config.burrowSpawnRate and burrowCount < minBurrows or (config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if (config.burrowSpawnType == "initialbox") and (t > config.gracePeriod) then
					config.burrowSpawnType = "initialbox_post"
				end
				if firstSpawn then
					SpawnBurrow()
					timeOfLastWave = (config.gracePeriod + 10) - config.chickenSpawnRate
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
				if burrowCount > 0
				and SetCount(spawnQueue) == 0
				and ((config.chickenSpawnRate) < (t - timeOfLastWave)) then
					Wave()
					timeOfLastWave = t
				end
			end

			for turret,burrow in pairs(burrowTurrets) do
				local h,mh = Spring.GetUnitHealth(burrow)
				if h and mh then
					Spring.SetUnitMaxHealth(turret, mh)
					Spring.SetUnitHealth(turret, h)
				end
			end

			updateRaptorSpawnBox()
		end
		if n%((math.ceil(config.turretSpawnRate))*30) == 0 and n > 900 and chickenTeamUnitCount < chickenUnitCap then
			spawnCreepStructuresWave()
		end
		local squadID = ((n % (#squadsTable*2))+1)/2 --*2 and /2 for lowering the rate of commands
		if not chickenteamhasplayers then
			if squadID and squadsTable[squadID] and squadsTable[squadID].squadRegroupEnabled then
				local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
				if targetx then
					squadCommanderGiveOrders(squadID, targetx, targety, targetz)
				else
					refreshSquad(squadID)
				end
			end
		end
		if n%7 == 3 and not chickenteamhasplayers then
			local chickens = GetTeamUnits(chickenTeamID)
			for i = 1,#chickens do
				if mRandom(1,math.ceil((33*math.max(1, Spring.GetTeamUnitDefCount(chickenTeamID, Spring.GetUnitDefID(chickens[i])))))) == 1 and mRandom() < config.spawnChance then
					SpawnMinions(chickens[i], Spring.GetUnitDefID(chickens[i]))
				end
				if mRandom(1,60) == 1 then 
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
								squadsTable[squadID].squadNeedsRefresh = true
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
		end
		if n%6 == 2 then
			decayRandomEggs()
		end
		manageAllSquads()
	end

	local deleteBurrowTurrets = {}
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)

		if unitTeam == chickenTeamID then
			if config.useEggs and (not (gameIsOver or queenID)) then
				local x,y,z = Spring.GetUnitPosition(unitID)
				spawnRandomEgg(x,y,z, UnitDefs[unitDefID].name, 1)
			end
			if unitDefID == config.burrowDef then
				if mRandom() <= config.spawnChance then
					spawnCreepStructuresWave()
				end
				for turret, burrow in pairs(burrowTurrets) do
					if burrowTurrets[turret] == unitID then
						table.insert(deleteBurrowTurrets, turret)
					end
				end
				if #deleteBurrowTurrets > 0 then
					for i = 1,#deleteBurrowTurrets do
						Spring.DestroyUnit(deleteBurrowTurrets[i], false, false)
					end
					deleteBurrowTurrets = {}
				end
			elseif config.chickenTurrets[UnitDefs[unitDefID].name] then
				burrowTurrets[unitID] = nil
			end
		end
		
		if heroChicken[unitID] then
			heroChicken[unitID] = nil
		end

		if unitSquadTable[unitID] then
			for index, id in ipairs(squadsTable[unitSquadTable[unitID]].squadUnits) do
				if id == unitID then
					table.remove(squadsTable[unitSquadTable[unitID]].squadUnits, index)
				end
			end
			unitSquadTable[unitID] = nil
		end

		squadPotentialTarget[unitID] = nil
		squadPotentialHighValueTarget[unitID] = nil
		for squad in ipairs(unitTargetPool) do
			if unitTargetPool[squad] == unitID then
				refreshSquad(squad)
			end
		end

		if unitTeam == chickenTeamID then
			local kills = GetGameRulesParam("chicken" .. "Kills") or 0
			SetGameRulesParam("chicken" .. "Kills", kills + 1)
		end

		if unitID == queenID then
			-- queen destroyed
			queenID = nil
			queenResistance = {}
			Spring.SetGameRulesParam("BossFightStarted", 0)

			if Spring.GetModOptions().chicken_endless then
				updateDifficultyForSurvival()
			else
				gameOver = GetGameFrame() + 200
				spawnQueue = {}
				gameIsOver = true
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
			local kills = GetGameRulesParam(config.burrowName .. "Kills") or 0
			SetGameRulesParam(config.burrowName .. "Kills", kills + 1)

			burrows[unitID] = nil
			playerAgression = playerAgression + (config.angerBonus/config.chickenSpawnMultiplier)
			config.maxXP = config.maxXP*1.01

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
		if unitTeleportCooldown[unitID] then
			unitTeleportCooldown[unitID] = nil
		end
		if unitTeam ~= chickenTeamID and config.ecoBuildingsPenalty[unitDefID] then
			playerAgressionEcoValue = playerAgressionEcoValue - (config.ecoBuildingsPenalty[unitDefID]/(config.queenTime/3600)) -- scale to 60minutes = 3600seconds queen time
		end
	end

	function gadget:TeamDied(teamID)
		humanTeams[teamID] = nil
		--computerTeams[teamID] = nil
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		if oldTeam == chickenTeamID and not string.find(UnitDefs[unitDefID].name, "lootbox") then
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

	function gadget:FeatureCreated(featureID, featureAllyTeamID)
		if featureAllyTeamID == chickenAllyTeamID then
			local egg = string.find(FeatureDefs[Spring.GetFeatureDefID(featureID)].name, "chicken_egg")
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

else	-- UNSYNCED

	local hasChickenEvent = false
	local mRandom = math.random

	function HasChickenEvent(ce)
		hasChickenEvent = (ce ~= "0")
	end

	function WrapToLuaUI(_, type, num, tech)
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

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('ChickenEvent', WrapToLuaUI)
		gadgetHandler:AddChatAction("HasChickenEvent", HasChickenEvent, "toggles hasChickenEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasChickenEvent")
	end


	local nocolorshift = {0,0,0}
	local colorshiftcache = {0,0,0}
	if gl.SetUnitBufferUniforms then 
		function gadget:UnitCreated(unitID, unitDefID, unitTeam)
			if string.find(UnitDefs[unitDefID].name, "chicken") then
				gl.SetUnitBufferUniforms(unitID, nocolorshift, 8)
				colorshiftcache[1] = mRandom(-100,100)*0.0001 -- hue (hue hue)
				colorshiftcache[2] = mRandom(-200,200)*0.0001 -- saturation         
				colorshiftcache[3] = mRandom(-200,200)*0.0001 -- brightness
				gl.SetUnitBufferUniforms(unitID, colorshiftcache, 8)
			end
		end
	end

end
