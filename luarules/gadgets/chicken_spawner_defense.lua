function gadget:GetInfo()
	return {
		name = "Chicken Defense Spawner",
		desc = "Spawns burrows and chickens",
		author = "TheFatController/quantum",
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

	local GetUnitHeading = Spring.GetUnitHeading
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
	local GetUnitsInCylinder = Spring.GetUnitsInCylinder
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
	local GetUnitDirection = Spring.GetUnitDirection

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

	local survivalQueenMod = 0.8
	local queenLifePercent = 100
	local maxTries = 30
	local oldMaxChicken = 0
	local maxChicken = Game.maxUnits - 100
	local oldDamageMod = 1
	local damageMod = config.damageMod
	local currentWave = 1
	local lastWave = 1
	local lastWaveUnitCount = 0
	local targetCache = 1
	local minBurrows = 1
	local timeOfLastSpawn = 0
	local timeOfLastFakeSpawn = 0
	local timeOfLastWave = 0
	local expMod = 0
	local burrowTarget = 0
	local qDamage = 0
	local lastTeamID = 0
	local targetCacheCount = 0
	local nextSquadSize = 0
	local chickenCount = 0
	local t = 0 -- game time in seconds
	local timeCounter = 0
	local queenAnger = 0
	local queenMaxHP = 0
	local chickenDebtCount = 0
	local burrowAnger = 0
	local firstSpawn = true
	local gameOver = nil
	local qMove = false
	local computerTeams = {}
	local humanTeams = {}
	local disabledUnits = {}
	local spawnQueue = {}
	local deathQueue = {}
	local idleOrderQueue = {}
	local queenResistance = {}
	local stunList = {}
	local queenID
	local chickenTeamID, chickenAllyTeamID
	local lsx1, lsz1, lsx2, lsz2
	local turrets = {}
	local chickenBirths = {}
	local failChickens = {}
	local chickenTargets = {}
	local burrows = {}
	local failBurrows = {}
	local heroChicken = {}
	local defenseMap = {}
	local unitName = {}
	local unitShortName = {}
	local unitSpeed = {}
	local unitCanFly = {}

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
				for u = 1,#units do
					chickenteamhasplayers = true
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(teamID)
				end
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

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Difficulty
	--

	local expIncrement = ((SetCount(humanTeams) * config.expStep) / config.queenTime)
	local nextWave = ((config.queenTime / 10) / 60)
	local gracePenalty = math.max(math.floor(((config.gracePeriod - 270) / config.burrowSpawnRate) + 0.5), 0)
	local chickensPerPlayer = (config.chickensPerPlayer * SetCount(humanTeams))
	local maxBurrows = config.maxBurrows * SetCount(humanTeams)
	local queenTime = (config.queenTime + config.gracePeriod)
	chickenDebtCount = math.ceil((math.max((config.gracePeriod - 270), 0) / 3))
	-- eggChance scales - 20% at 0-300 grace, 10% at 400 grace, 0% at 500+ grace
	local eggChance = 0.20 * math.max(0, math.min(1, (500 - config.gracePeriod) / 200)) / config.chickenSpawnMultiplier
	local bonusEggs = math.ceil(24 * math.max(0, math.min(1, (500 - config.gracePeriod) / 200))) / config.chickenSpawnMultiplier

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
		[UnitDefNames["chickens2"].id] = { distance = 620, chance = 0.5 },
		[UnitDefNames["chickenf2"].id] = { distance = 2000, chance = 0.5 },
		[UnitDefNames["chickenw1b"].id] = { distance = 900, chance = 0.33 },
		[UnitDefNames["chickens3"].id] = { distance = 440, chance = 0.1 },
		[UnitDefNames["chickenh5"].id] = { distance = 300, chance = 0.5 },
		[UnitDefNames["chickenr1"].id] = { distance = 1000, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 1000, chance = 1 },
		[UnitDefNames["chickene1"].id] = { distance = 300, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 200, chance = 0.01 },	
		[UnitDefNames["chickenearty1"].id] = { distance = 1000, chance = 1 },
	}
	local COWARD = {
		[UnitDefNames["chickenh1"].id] = { distance = 300, chance = 0.5 },
		[UnitDefNames["chickenh1b"].id] = { distance = 15, chance = 0.1 },
		[UnitDefNames["chickenr1"].id] = { distance = 1000, chance = 1 },
		[UnitDefNames["chickenr2"].id] = { distance = 1000, chance = 0.1 },
		[UnitDefNames["chickenw1c"].id] = { distance = 900, chance = 0.33 },
		[UnitDefNames["chickenh5"].id] = { distance = 2000, chance = 0.5 },
		[UnitDefNames["chickene1"].id] = { distance = 2000, chance = 1 },
		[UnitDefNames["chickene2"].id] = { distance = 2000, chance = 1 },
		[UnitDefNames["chickenearty1"].id] = { distance = 2000, chance = 1 },
	}
	local BERSERK = {
		[UnitDefNames["chickenr2"].id] = { chance = 0.1 },
		[UnitDefNames["ve_chickenq"].id] = { chance = 0.01 },
		[UnitDefNames["e_chickenq"].id] = { chance = 0.05 },
		[UnitDefNames["n_chickenq"].id] = { chance = 0.1 },
		[UnitDefNames["h_chickenq"].id] = { chance = 0.2 },
		[UnitDefNames["vh_chickenq"].id] = { chance = 0.3 },
		[UnitDefNames["epic_chickenq"].id] = { chance = 0.5 },
	}
	-- local EGG_DROPPER = {
	-- 	[UnitDefNames["chicken1"].id] = "chicken_egg_s_pink",
	-- 	[UnitDefNames["chicken1b"].id] = "chicken_egg_s_white",
	-- 	[UnitDefNames["chicken1c"].id] = "chicken_egg_s_red",
	-- 	[UnitDefNames["chicken1d"].id] = "chicken_egg_s_pink",
	-- }
	local OVERSEER_ID = UnitDefNames["chickenh5"].id
	local SMALL_UNIT = UnitDefNames["chicken1"].id
	local MEDIUM_UNIT = UnitDefNames["chicken1"].id
	local LARGE_UNIT = UnitDefNames["chicken1"].id

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Clean up
	--

	local function KillOldChicken()
		for unitID, defs in pairs(chickenBirths) do
			if (t > defs.deathDate) then
				if (unitID ~= queenID) then
					deathQueue[unitID] = { selfd = false, reclaimed = false }
					chickenCount = chickenCount - 1
					chickenDebtCount = chickenDebtCount + 1
					local failCount = failBurrows[defs.burrowID]
					if (failBurrows[defs.burrowID] == nil) then
						failBurrows[defs.burrowID] = 5
					else
						failBurrows[defs.burrowID] = failCount + 5
					end
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game End Stuff
	--

	local function KillAllChicken()
		local chickenUnits = GetTeamUnits(chickenTeamID)
		for i = 1, #chickenUnits do
			local unitID = chickenUnits[i]
			if disabledUnits[unitID] then
				DestroyUnit(unitID, false, true)
			else
				DestroyUnit(unitID, true)
			end
		end
	end

	local function KillAllComputerUnits()
		for teamID in pairs(computerTeams) do
			local teamUnits = GetTeamUnits(teamID)
			for i = 1, #teamUnits do
				local unitID = teamUnits[i]
				if disabledUnits[unitID] then
					DestroyUnit(unitID, false, true)
				else
					DestroyUnit(unitID, true)
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Spawn Dynamics
	--

	local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
	local RaptorStartboxXMin, RaptorStartboxZMin, RaptorStartboxXMax, RaptorStartboxZMax = Spring.GetAllyTeamStartBox(chickenAllyTeamID)

	local function addChickenTarget(chickenID, targetID)
		if not targetID or GetUnitTeam(targetID) == chickenTeamID or GetUnitTeam(chickenID) ~= chickenTeamID then
			return
		end
		if chickenTargets[chickenID] and chickenTargets[chickenTargets[chickenID]] and type(chickenTargets[chickenTargets[chickenID]]) == 'table' then
			chickenTargets[chickenTargets[chickenID]][chickenID] = nil
		end
		if chickenTargets[targetID] == nil then
			chickenTargets[targetID] = { [chickenID] = targetID }
		elseif type(chickenTargets[targetID]) == 'table' then	-- without this an error happened to "index a number value" on unknown occasion (game-end), possible cause players own a chicken unit as well
			chickenTargets[targetID][chickenID] = targetID
		end
		chickenTargets[chickenID] = targetID
	end

	local function AttackNearestEnemy(unitID, unitDefID, unitTeam)
		local targetID = GetUnitNearestEnemy(unitID)
		if targetID and not GetUnitIsDead(targetID) and not GetUnitNeutral(targetID) then
			local defID = GetUnitDefID(targetID)
			local myDefID = GetUnitDefID(unitID)
			if unitSpeed[myDefID] and unitSpeed[myDefID] < (unitSpeed[defID] * 1.15) then
				return false
			end
			local x, y, z = GetUnitPosition(targetID)
			idleOrderQueue[unitID] = { cmd = CMD.FIGHT, params = { x, y, z }, opts = {} }
			addChickenTarget(unitID, targetID)
			return true
		else
			return false
		end
	end

	local function getRandomMapPos()
		local x = math.random(MAPSIZEX - 16)
		local z = math.random(MAPSIZEZ - 16)
		local y = GetGroundHeight(x, z)
		return { x, y, z }
	end

	-- selects a enemy target
	local function ChooseTarget()
		local humanTeamList = SetToList(humanTeams)
		if #humanTeamList == 0 or gameOver then
			return getRandomMapPos()
		end
		if targetCache and (targetCacheCount >= nextSquadSize or GetUnitIsDead(targetCache)) then
			local tries = 0
			repeat
				local teamID = humanTeamList[mRandom(#humanTeamList)]
				if teamID == lastTeamID then
					teamID = humanTeamList[mRandom(#humanTeamList)]
				end
				lastTeamID = teamID
				local units = GetTeamUnits(teamID)
				if units[2] then
					targetCache = units[mRandom(1, #units)]
				else
					targetCache = units[1]
				end
				local slowunit = true
				if targetCache and tries < 5 then
					local defID = GetUnitDefID(targetCache)
					if unitSpeed[defID] and unitSpeed[defID] > 75 then
						slowunit = false
					end
				end
				tries = (tries + 1)
			until (targetCache and not GetUnitIsDead(targetCache) and not GetUnitNeutral(targetCache) and slowunit) or (tries > maxTries)
			targetCacheCount = 0
			nextSquadSize = 6 + mRandom(0, 4)
		else
			targetCacheCount = targetCacheCount + 1
		end
		if not targetCache then
			-- no target could be found, use random map pos
			return getRandomMapPos()
		end
		if mRandom(100) < 50 then
			local angle = math.rad(mRandom(1, 360))
			local x, y, z = GetUnitPosition(targetCache)
			if not x or not y or not z then
				Spring.Log(gadget:GetInfo().name, LOG.ERROR,"Invalid pos in GetUnitPosition: " .. tostring(targetCache))
				return getRandomMapPos()
			end
			local distance = mRandom(50, 900)
			x = math.min(math.max(x - (math.sin(angle) * distance), 16), MAPSIZEX - 16)
			z = math.min(math.max(z - (math.cos(angle) * distance), 16), MAPSIZEZ - 16)
			return { x, y, z }
		else
			return { GetUnitPosition(targetCache) }
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
		-- if queenID then
		-- 	-- don't spawn new burrows when queen is there
		-- 	return
		-- end

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
					if tries < maxTries*3 then
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, true)
					else
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.minBaseDistance, chickenAllyTeamID, true, true, false)
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
					if math.random(1,3) == 1 and minBurrows < maxBurrows and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
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
							if math.random(1,3) == 1 and minBurrows < maxBurrows and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
								minBurrows = minBurrows + 1
							end
							burrows[unitID] = 0
							SetUnitBlocking(unitID, false, false)
							SetUnitExperience(unitID, mRandom() * expMod)
							break
						end
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
				if failBurrows[burrowID] then
					score = score - (failBurrows[burrowID] * 5)
				end
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

		-- Force Spawn if everything else failed
		local x = mRandom(RaptorStartboxXMin, RaptorStartboxXMax)
		local z = mRandom(RaptorStartboxZMin, RaptorStartboxZMax)
		local y = GetGroundHeight(x, z)
		return CreateUnit(config.queenName, x, y, z, math.random(0,3), chickenTeamID)
	end

	local function Wave()
		if gameOver then
			return
		end

		currentWave = math.min(math.ceil((((t - config.gracePeriod) / 60) / nextWave)), 10)

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
				for i = 1, config.queenSpawnMult*SetCount(humanTeams), 1 do
					local waveLevelPower = mRandom(1, currentWave*currentWave)
					local waveLevel = math.ceil(math.sqrt(waveLevelPower))
					local squad = config.waves[waveLevel][mRandom(1, #config.waves[waveLevel])]
					for i, sString in pairs(squad) do
						local nEnd, _ = string.find(sString, " ")
						local unitNumber = string.sub(sString, 1, (nEnd - 1)) * config.chickenSpawnMultiplier * 1+currentWave-waveLevel
						local chickenName = string.sub(sString, (nEnd + 1))
						for i = 1, unitNumber, 1 do
							table.insert(spawnQueue, { burrow = queenID, unitName = chickenName, team = chickenTeamID })
						end
						cCount = cCount + unitNumber
					end
				end
			end
			--return cCount
		end

		for burrowID in pairs(burrows) do
			local waveLevelPower = mRandom(1, currentWave*currentWave)
			local waveLevel = math.ceil(math.sqrt(waveLevelPower))
			local squad = config.waves[waveLevel][mRandom(1, #config.waves[waveLevel])]
			local newWaveSquadSpawn = false
			if lastWave ~= currentWave and config.newWaveSquad[currentWave] then
				squad = config.newWaveSquad[currentWave]
				lastWave = currentWave
				waveLevel = currentWave
				newWaveSquadSpawn = true
			end
			for i, sString in pairs(squad) do
				local skipSpawn = false
				if cCount > chickensPerPlayer and mRandom() > config.spawnChance*queenBurrowSpawnMultiplier then
					skipSpawn = true
				end
				-- if skipSpawn and chickenDebtCount > 0 and mRandom() > config.spawnChance*queenBurrowSpawnMultiplier then
				-- 	chickenDebtCount = (chickenDebtCount - 1)
				-- 	skipSpawn = false
				-- end
				if newWaveSquadSpawn then
					skipSpawn = false
				end
				if not skipSpawn then
					local nEnd, _ = string.find(sString, " ")
					local unitNumber = string.sub(sString, 1, (nEnd - 1)) * config.chickenSpawnMultiplier * 1+currentWave-waveLevel
					local chickenName = string.sub(sString, (nEnd + 1))
					for i = 1, unitNumber, 1 do
						table.insert(spawnQueue, { burrow = burrowID, unitName = chickenName, team = chickenTeamID })
					end
					cCount = cCount + unitNumber
				end
			end
		end
		return cCount
	end

	local function removeFailChickens()
		for unitID, failCount in pairs(failBurrows) do
			if failCount > 30 then
				deathQueue[unitID] = { selfd = false, reclaimed = false }
				burrows[unitID] = nil
				failBurrows[unitID] = nil
				for i, defs in pairs(spawnQueue) do
					if defs.burrow == unitID then
						spawnQueue[i] = nil
					end
				end
				SpawnBurrow()
			end
		end
		for unitID, failCount in pairs(failChickens) do
			local checkedForDT = false
			if unitID ~= queenID or GetUnitTeam(unitID) ~= chickenTeamID then
				if failCount > 5 then
					local x, y, z = GetUnitPosition(unitID)
					if x then
						local yh = GetGroundHeight(x, z)
						if y and yh and (y < (yh + 1)) then
							deathQueue[unitID] = { selfd = false, reclaimed = true }
							chickenCount = chickenCount - 1
							chickenDebtCount = chickenDebtCount + 1
							if chickenBirths[unitID] then
								local burrowFailCount = failBurrows[chickenBirths[unitID].burrowID]
								if (burrowFailCount == nil) then
									failBurrows[chickenBirths[unitID].burrowID] = 1
								else
									failBurrows[chickenBirths[unitID].burrowID] = burrowFailCount + 1
								end
							end
						end
					end
				elseif failCount > 2 then
					local x, y, z = GetUnitPosition(unitID)
					if x then
						local attackingFeature = false
						if not checkedForDT then
							checkedForDT = true
							local nearFeatures = Spring.GetFeaturesInSphere(x, y, z, 70)
							for i, featureID in ipairs(nearFeatures) do
								local featureDefID = Spring.GetFeatureDefID(featureID)
								if featureDefID and FeatureDefs[featureDefID].metal > 0 and not FeatureDefs[featureDefID].autoReclaimable then
									local fx, fy, fz = Spring.GetFeaturePosition(featureID)
									idleOrderQueue[unitID] = { cmd = CMD.ATTACK, params = { fx, fy, fz }, opts = {} }
									attackingFeature = true
									break
								end
							end
						end
						if not attackingFeature then
							local dx, _, dz = GetUnitDirection(unitID)
							local angle = math.atan2(dx, dz)
							Spring.SpawnCEG("blood_trail", x, y, z, 0, 0, 0)
							if y < -15 then
								deathQueue[unitID] = { selfd = false, reclaimed = false }
								chickenCount = chickenCount - 1
								chickenDebtCount = chickenDebtCount + 1
								if chickenBirths[unitID] then
									local burrowFailCount = failBurrows[chickenBirths[unitID].burrowID]
									if burrowFailCount == nil then
										failBurrows[chickenBirths[unitID].burrowID] = 3
									else
										failBurrows[chickenBirths[unitID].burrowID] = burrowFailCount + 3
									end
								end
							end
							Spring.AddUnitImpulse(unitID, math.sin(angle) * 2, 2.5, math.cos(angle) * 2, 100)
						end
					end
				end
			end
			failChickens = {}
		end
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

	function gadget:UnitIdle(unitID, unitDefID, unitTeam)
		if chickenteamhasplayers then return end
		if unitTeam ~= chickenTeamID or not chickenDefTypes[unitDefID] then
			-- filter out non chicken units
			return
		end
		local failCount = failChickens[unitID]
		if failCount == nil then
			if unitID ~= queenID then
				failChickens[unitID] = 1
			end
		else
			failChickens[unitID] = failCount + 1
		end

		if AttackNearestEnemy(unitID, unitDefID, unitTeam) then
			return
		end
		local chickenParams = ChooseTarget()
		if targetCache then
			idleOrderQueue[unitID] = { cmd = CMD.FIGHT, params = chickenParams, opts = {} }
			if GetUnitNeutral(targetCache) then
				idleOrderQueue[unitID] = { cmd = CMD.ATTACK, params = { targetCache }, opts = {} }
			end
			addChickenTarget(unitID, targetCache)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == chickenTeamID or chickenDefTypes[unitDefID] then
			-- filter out chicken units
			return
		end
		if chickenTargets[unitID] then
			chickenTargets[unitID] = nil
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if disabledUnits[unitID] then
			return 0, 0
		end

		if attackerTeam == chickenTeamID then
			return (damage * damageMod)
		end

		if heroChicken[unitID] then
			damage = (damage * heroChicken[unitID])
			local x, y, z = GetUnitPosition(unitID)
			Spring.SpawnCEG("CHICKENHERO", x, y, z, 0, 0, 0)
		end

		if unitID == queenID then
			-- special case queen
			if weaponID == -1 and damage > 25000 then
				return 25000
			end
			if attackerDefID then
				if not queenResistance[weaponID] then
					queenResistance[weaponID] = {}
					queenResistance[weaponID].damage = damage
					queenResistance[weaponID].notify = 0
				end
				local resistPercent = (math.min(queenResistance[weaponID].damage / queenMaxHP, 0.75) + 0.2)
				if resistPercent > 0.35 then
					if queenResistance[weaponID].notify == 0 then
						SendToUnsynced('QueenResistant', attackerDefID)
						queenResistance[weaponID].notify = 1
						for i = 1, 12, 1 do
							table.insert(spawnQueue, { burrow = queenID, unitName = "chickenw2", team = chickenTeamID })
						end
						for i = 1, 4, 1 do
							table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID })
							table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID })
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

		if chickenBirths[attackerID] then
			chickenBirths[attackerID].deathDate = (t + config.maxAge)
		end
		if failChickens[attackerID] then
			failChickens[attackerID] = nil
		end
		if failChickens[unitID] then
			failChickens[unitID] = nil
		end

		if SKIRMISH[attackerDefID] and (unitTeam ~= chickenTeamID) and attackerID and (mRandom() < SKIRMISH[attackerDefID].chance) then
			local ux, uy, uz = GetUnitPosition(unitID)
			local x, y, z = GetUnitPosition(attackerID)
			if x and ux then
				local angle = math.atan2(ux - x, uz - z)
				local distance = mRandom(math.ceil(SKIRMISH[attackerDefID].distance*0.75), math.floor(SKIRMISH[attackerDefID].distance*1.25))
				idleOrderQueue[attackerID] = { cmd = CMD.MOVE, params = { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, opts = {} }
			end
		elseif COWARD[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < COWARD[unitDefID].chance) then
			local curH, maxH = GetUnitHealth(unitID)
			if curH and maxH and curH < (maxH * 0.8) then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				if x and ax then
					local angle = math.atan2(ax - x, az - z)
					local distance = mRandom(math.ceil(COWARD[unitDefID].distance*0.75), math.floor(COWARD[unitDefID].distance*1.25))
					idleOrderQueue[unitID] = { cmd = CMD.MOVE, params = { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, opts = {} }
				end
			end
		elseif BERSERK[unitDefID] and (unitTeam == chickenTeamID) and attackerID and (mRandom() < BERSERK[unitDefID].chance) then
			local ax, ay, az = GetUnitPosition(attackerID)
			if ax then
				idleOrderQueue[unitID] = {cmd = CMD.MOVE, params = {ax, ay, az}, opts = {} }
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
			return
		end
		local x, y, z
		if queenID then
			x, y, z = getChickenSpawnLoc(defs.burrow, MEDIUM_UNIT)
		else
			x, y, z = getChickenSpawnLoc(defs.burrow, SMALL_UNIT)
		end
		if not x or not y or not z then
			spawnQueue[i] = nil
			return
		end
		local unitID = CreateUnit(defs.unitName, x, y, z, math.random(0,3), defs.team)
		
		if unitID then
			GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-64, 64), y, z + math.random(-64, 64) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-128, 128), y, z + math.random(-128, 128) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-256, 256), y, z + math.random(-256, 256) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + math.random(-512, 512), y, z + math.random(-512, 512) }, { "shift" })
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

			--if unitCanFly[GetUnitDefID(unitID)] then
				
			--end

			if queenID then
				idleOrderQueue[unitID] = { cmd = CMD.FIGHT, params = getRandomMapPos(), opts = {} }
			else
				local chickenParams = ChooseTarget()
				if targetCache and (unitID ~= queenID) and (mRandom(1, 15) == 5) then
					idleOrderQueue[unitID] = { cmd = CMD.ATTACK, params = { targetCache }, opts = {} }
				else
					if mRandom(100) > 50 or unitCanFly[GetUnitDefID(unitID)] then
						idleOrderQueue[unitID] = { cmd = CMD.FIGHT, params = chickenParams, opts = {} }
					else
						idleOrderQueue[unitID] = { cmd = CMD.MOVE, params = chickenParams, opts = {} }
					end
				end
				if targetCache then
					if GetUnitNeutral(targetCache) then
						idleOrderQueue[unitID] = { cmd = CMD.ATTACK, params = { targetCache }, opts = {} }
					end
					addChickenTarget(unitID, targetCache)
				end
				chickenBirths[unitID] = { deathDate = t + (config.maxAges[defs.unitName] or config.maxAge), burrowID = defs.burrow }
				chickenCount = chickenCount + 1
			end
		end
		spawnQueue[i] = nil
	end

	local function chickenEvent(type, num, tech)
		SendToUnsynced("ChickenEvent", type, num, tech)
	end

	local function getMostDefendedArea()
		table.sort(defenseMap, function(u1, u2)
			return u1 < u2;
		end)
		local k = next(defenseMap)
		if k then
			local x, z = string.match(k, "(%d+),(%d+)")
			if x ~= nil and z ~= nil then
				x = x * DMAREA
				z = z * DMAREA
				local y = GetGroundHeight(x, z)
				return x, y, z
			else
				return nil, nil, nil
			end
		else
			return nil, nil, nil
		end
	end

	local function updateSpawnQueen()
		if not queenID and not gameOver then
			-- spawn queen if not exists
			queenID = SpawnQueen()
			local x, y, z = getMostDefendedArea()
			if x and y and z then
				idleOrderQueue[queenID] = { cmd = CMD.MOVE, params = { x, y, z }, opts = {} }
			else
				idleOrderQueue[queenID] = { cmd = CMD.STOP, params = {}, opts = {} }
			end
			burrows[queenID] = 0
			spawnQueue = {}
			oldMaxChicken = maxChicken
			oldDamageMod = damageMod
			maxChicken = maxChicken
			chickenEvent("queen") -- notify unsynced about queen spawn
			_, queenMaxHP = GetUnitHealth(queenID)
			SetUnitExperience(queenID, expMod)
			timeOfLastWave = t
			SKIRMISH[UnitDefNames["chickenc1"].id] = { distance = 150, chance = 0.5 }
			SKIRMISH[UnitDefNames["chickenf1"].id] = { distance = 1200, chance = 0.25 }
			SKIRMISH[UnitDefNames["chickenw1"].id] = { distance = 1800, chance = 0.5 }
			COWARD[UnitDefNames["chicken_dodo1"].id] = { distance = 1100, chance = 0.33 }

			local chickenUnits = GetTeamUnits(chickenTeamID)
			for i = 1, #chickenUnits do
				local unitID = chickenUnits[i]
				if GetUnitDefID(unitID) == OVERSEER_ID then
					deathQueue[unitID] = { selfd = false, reclaimed = false }
				end
			end

			for i = 1, 150, 1 do
				if mRandom() < config.spawnChance then
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh4", team = chickenTeamID })
				end
			end

			for i = 1, 10, 1 do
				if mRandom() < config.spawnChance then
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1", team = chickenTeamID })
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh1b", team = chickenTeamID })
				end
			end
		else
			if mRandom() < config.spawnChance / 7.5 then
				for i = 1, mRandom(1, 3), 1 do
					table.insert(spawnQueue, { burrow = queenID, unitName = "chickenh4", team = chickenTeamID })
				end
			end
		end
	end


	local attemptingToSpawnHeavyTurret = 0
	local attemptingToSpawnLightTurret = 0
	local heavyTurret = "chickend2"
	local lightTurret = "chickend1"

	local function spawnStartBoxProtectionHeavy()
		local burrowCount = SetCount(burrows)
		if math.random(0,config.burrowSpawnRate*6) == 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
			if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < burrowCount*2 or Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < 2 then
				attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + 1
			end
		end
		if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[heavyTurret].id) < burrowCount*2 then
			if attemptingToSpawnHeavyTurret > 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
				canSpawnDefence = true
				-- lsx1 - xmin, lsz1 - zmin, lsx2 - xmax, lsz2 - zmax
				local spawnDirection = math.random(0,3)
				local spread = 200
				local spawnPosX = math.random(lsx1,lsx2)
				local spawnPosZ = math.random(lsz1,lsz2)

				if spawnPosX > MAPSIZEX - spread + 1 or spawnPosX < spread + 1 or spawnPosZ > MAPSIZEZ - spread + 1 or spawnPosZ < spread + 1 then
					canSpawnDefence = false
				end

				if canSpawnDefence then
					local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					local canSpawnDefence = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					if canSpawnDefence then
						canSpawnDefence = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnDefence then
						local StartBoxCheck = positionCheckLibrary.StartboxCheck(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID)
						if StartBoxCheck == false then
							canSpawnDefence = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, true, true)
						end
					end
					if canSpawnDefence then
						local heavyTurretUnitID = Spring.CreateUnit(heavyTurret, spawnPosX, spawnPosY, spawnPosZ, spawnDirection, chickenTeamID)
						if heavyTurretUnitID then
							attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret - 1
							SetUnitExperience(heavyTurretUnitID, mRandom() * expMod)
							for i = 1, math.random(1,attemptingToSpawnLightTurret+6) do
								local spawnPosX = spawnPosX + math.random(-spread, spread)
								local spawnPosZ = spawnPosZ + math.random(-spread, spread)
								local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
								canSpawnDefence = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread*0.2)
								if canSpawnDefence then
									canSpawnDefence = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY+50, spawnPosZ, spread*0.2)
								end
								if canSpawnDefence then
									local lightTurretUnitID = Spring.CreateUnit(lightTurret, spawnPosX, spawnPosY, spawnPosZ, spawnDirection, chickenTeamID)
									if lightTurretUnitID then
										Spring.GiveOrderToUnit(lightTurretUnitID, CMD.PATROL, {spawnPosX + math.random(-128,128), spawnPosY, spawnPosZ + math.random(-128,128)}, {"meta"})
										SetUnitBlocking(lightTurretUnitID, false, false)
										SetUnitExperience(lightTurretUnitID, mRandom() * expMod)
										if attemptingToSpawnLightTurret > 0 then
											attemptingToSpawnLightTurret = attemptingToSpawnLightTurret - 1
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local function spawnStartBoxProtectionLight()
		local burrowCount = SetCount(burrows)
		if math.random(0,config.burrowSpawnRate*6) == 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
			if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < burrowCount*5 or Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < 10 then
				attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + 10
			end
		end
		if Spring.GetTeamUnitDefCount(chickenTeamID, UnitDefNames[lightTurret].id) < burrowCount*5 then
			if attemptingToSpawnLightTurret > 0 and Spring.GetGameFrame() > (config.gracePeriod*30)+9000 then
				canSpawnDefence = true
				-- lsx1 - xmin, lsz1 - zmin, lsx2 - xmax, lsz2 - zmax
				local spawnDirection = math.random(0,3)
				local spread = 100
				local spawnPosX = math.random(lsx1,lsx2)
				local spawnPosZ = math.random(lsz1,lsz2)

				if spawnPosX > MAPSIZEX - spread + 1 or spawnPosX < spread + 1 or spawnPosZ > MAPSIZEZ - spread + 1 or spawnPosZ < spread + 1 then
					canSpawnDefence = false
				end

				if canSpawnDefence then
					local spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					local canSpawnDefence = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					if canSpawnDefence then
						canSpawnDefence = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnDefence then
						local StartBoxCheck = positionCheckLibrary.StartboxCheck(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID)
						if StartBoxCheck == false then
							canSpawnDefence = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, chickenAllyTeamID, true, true, true)
						end
					end
					if canSpawnDefence then
						local lightTurretUnitID = Spring.CreateUnit(lightTurret, spawnPosX, spawnPosY, spawnPosZ, spawnDirection, chickenTeamID)
						if lightTurretUnitID then
							Spring.GiveOrderToUnit(lightTurretUnitID, CMD.PATROL, {spawnPosX + math.random(-128,128), spawnPosY, spawnPosZ + math.random(-128,128)}, {"meta"})
							attemptingToSpawnLightTurret = attemptingToSpawnLightTurret - 1
							SetUnitExperience(lightTurretUnitID, mRandom() * expMod)
						end
					end
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
			--if n > gameOver then
			--	Spring.KillTeam(chickenTeamID)	-- already killed
			--end
			return
		end

		if n == 15 then
			DisableComputerUnits()
			config.burrowSpawnRate = config.burrowSpawnRate/SetCount(humanTeams)
			config.chickenSpawnRate = config.chickenSpawnRate/SetCount(humanTeams)
		end

		if n % 90 == 0 then
			if not chickenteamhasplayers then
				removeFailChickens()
			end
			if (queenAnger >= 100) then
				damageMod = (damageMod + 0.005)
			end
		end

		local chickenTeamUnitCount = Spring.GetTeamUnitCount(chickenTeamID) or 0
		if chickenTeamUnitCount < maxChicken then
			SpawnChickens()
		end

		for unitID in pairs(stunList) do
			if n > stunList[unitID] then
				SetUnitHealth(unitID, { paralyze = 0 })
				stunList[unitID] = nil
			end
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
					queenAnger = math.ceil(math.min((t - config.gracePeriod) / (queenTime - config.gracePeriod) * 100 % 100) + burrowAnger, 100)
				end
				SetGameRulesParam("queenAnger", queenAnger)
			end
			-- if not chickenteamhasplayers then
			-- 	KillOldChicken()
			-- end

			if t < config.gracePeriod then
				-- do nothing in the grace period
				return
			end

			expMod = (expMod + expIncrement) -- increment experience

			if next(idleOrderQueue) then
				local processOrderQueue = {}
				for unitID, order in pairs(idleOrderQueue) do
					if GetUnitDefID(unitID) then
						processOrderQueue[unitID] = order
					end
				end
				idleOrderQueue = {}
				for unitID, order in pairs(processOrderQueue) do
					if not chickenteamhasplayers then
						GiveOrderToUnit(unitID, order.cmd, order.params, order.opts)
						GiveOrderToUnit(unitID, CMD.MOVE_STATE, { mRandom(0, 2) }, { "shift" })
					end
					if unitCanFly[GetUnitDefID(unitID)] then
						GiveOrderToUnit(unitID, CMD.AUTOREPAIRLEVEL, { mRandom(0, 3) }, { "shift" })
					end
				end
			end

			if queenAnger >= 100 then
				-- check if the queen should be alive
				updateSpawnQueen()
				updateQueenLife()
			end

			local quicken = 0
			local burrowCount = SetCount(burrows)

			if config.burrowSpawnRate < (t - timeOfLastFakeSpawn) and burrowTarget < maxBurrows then
				-- This block is all about setting the correct burrow target
				if firstSpawn then
					minBurrows = math.ceil(SetCount(humanTeams)*0.5)
					local hteamID = next(humanTeams)
					local ranCount = GetTeamUnitCount(hteamID)
					for i = 1, ranCount, 1 do
						mRandom()
					end
					burrowTarget = math.max(math.min(math.ceil(minBurrows * 1.5) + gracePenalty, 40), 1)
				else
					burrowTarget = burrowTarget + 1
				end
				timeOfLastFakeSpawn = t
			end

			-- if burrowTarget > 0 and burrowTarget ~= burrowCount then
			-- 	quicken = (config.burrowSpawnRate * (1 - (burrowCount / burrowTarget)))
			-- end

			-- if burrowTarget > 0 and (burrowCount / burrowTarget) < 0.40 then
			-- 	-- less than 40% of desired burrows, spawn one right away
			-- 	quicken = config.burrowSpawnRate
			-- end

			local burrowSpawnTime = (config.burrowSpawnRate - quicken)

			if burrowCount < minBurrows or (burrowSpawnTime < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if firstSpawn then
					--for i = 1,math.ceil(minBurrows*1.2) do
						SpawnBurrow()
					--end
					timeOfLastWave = (t - (config.chickenSpawnRate - 6))
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
			end

			if burrowCount > 0 and ((config.chickenSpawnRate < (t - timeOfLastWave)) or (chickenCount < lastWaveUnitCount*(math.random(0,50)*0.01) and (t - timeOfLastWave) > 2)) then
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
			spawnStartBoxProtectionLight()
			spawnStartBoxProtectionHeavy()
		end
	end

	local chickenEggColors = {"pink","white","red", "blue", "darkgreen", "darkred", "green", "yellow"}
	local function spawnRandomEgg(x,y,z)
		local r = mRandom(1,100)
		local size = "s"
		if r <= 5 then
			size = "l"
		elseif r <= 20 then
			size = "m"
		end
		local egg = Spring.CreateFeature("chicken_egg_"..size.."_"..chickenEggColors[math.random(1,#chickenEggColors)], x, y, z, math.random(-999999,999999), chickenTeamID)
		if egg then
			Spring.SetFeatureVelocity(egg, mRandom(-2000,2000)*0.01, mRandom(300,600)*0.01, mRandom(-2000,2000)*0.01)
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
					spawnRandomEgg(x,y,z)
				end
			elseif UnitDefs[unitDefID].name == "chickend1" then
				for i = 1,math.random(3,10) do
					local x = x + math.random(-16,16)
					local z = z + math.random(-16,16)
					local y = GetGroundHeight(x, z)
					spawnRandomEgg(x,y,z)
				end
			else
				spawnRandomEgg(x,y,z)
			end
		end
		if heroChicken[unitID] then
			heroChicken[unitID] = nil
		end
		if stunList[unitID] then
			stunList[unitID] = nil
		end
		if chickenBirths[unitID] then
			chickenBirths[unitID] = nil
		end
		if turrets[unitID] then
			turrets[unitID] = nil
		end
		if idleOrderQueue[unitID] then
			idleOrderQueue[unitID] = nil
		end
		if failChickens[unitID] then
			failChickens[unitID] = nil
		end
		if failBurrows[unitID] then
			failBurrows[unitID] = nil
			return
		end

		if chickenTargets[unitID] then
			if unitTeam ~= chickenTeamID then
				for chickenID in pairs(chickenTargets[unitID]) do
					if GetUnitDefID(chickenID) then
						idleOrderQueue[chickenID] = { cmd = CMD.STOP, params = {}, opts = {} }
					end
				end
			elseif chickenTargets[chickenTargets[unitID]] and type(chickenTargets[chickenTargets[unitID]]) == 'table' then
				chickenTargets[chickenTargets[unitID]][unitID] = nil
			end
			chickenTargets[unitID] = nil
		end

		if unitID == targetCache then
			targetCache = 1
			targetCacheCount = math.huge
		end

		if unitTeam == chickenTeamID and chickenDefTypes[unitDefID] then
			local name = unitName[unitDefID]
			if unitDefID ~= config.burrowDef then
				name = string.sub(name, 1, -2)
			end
			local kills = GetGameRulesParam(name .. "Kills")
			SetGameRulesParam(name .. "Kills", kills + 1)
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
				queenTime = t + ((Spring.GetModOptions().chicken_queentime * 60) * survivalQueenMod)
				survivalQueenMod = survivalQueenMod * 0.8
				queenAnger = 0  -- reenable chicken spawning
				burrowAnger = 0
				SetGameRulesParam("queenAnger", queenAnger)
				SpawnBurrow()
				SpawnChickens() -- spawn new chickens (because queen could be the last one)
			else
				gameOver = GetGameFrame() + 200
				spawnQueue = {}
				KillAllComputerUnits()

				-- kill whole allyteam  (game_end gadget will destroy leftover units)
				if not killedChickensAllyTeam then
					killedChickensAllyTeam = true
					for _, teamID in ipairs(Spring.GetTeamList(chickenAllyTeamID)) do
						if not select(3, Spring.GetTeamInfo(teamID, false)) then
							Spring.KillTeam(teamID)
						end
					end
				end
				--KillAllChicken()
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

			for turretID, v in pairs(turrets) do
				if v[1] == unitID then
					local x, y, z = GetUnitPosition(turretID)
					if x and y and z then
						Spring.SpawnCEG("blood_explode", x, y, z, 0, 0, 0)
						local h = Spring.GetUnitHealth(turretID)
						if h then
							Spring.SetUnitHealth(turretID, h * 0.333)
						end
					end
					idleOrderQueue[turretID] = { cmd = CMD.STOP, params = {}, opts = {} }
					turrets[turretID] = nil
				end
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

			SetGameRulesParam("roostCount", SetCount(burrows))
		end

		if UnitDefs[unitDefID].name == "chickend1" then
			attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + math.random(0,1)
			if config.addQueenAnger then
				burrowAnger = (burrowAnger + (config.angerBonus*0.25))
				expMod = (expMod + config.angerBonus)
			end
		end
		if UnitDefs[unitDefID].name == "chickend2" then
			attemptingToSpawnLightTurret = attemptingToSpawnLightTurret + math.random(0,5)
			attemptingToSpawnHeavyTurret = attemptingToSpawnHeavyTurret + math.random(0,1)
			if config.addQueenAnger then
				burrowAnger = (burrowAnger + config.angerBonus)
				expMod = (expMod + config.angerBonus)
			end
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
