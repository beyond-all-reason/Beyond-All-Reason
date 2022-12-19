--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function gadget:GetInfo()
	return {
		name = "Galaxy Campaign Battle Handler",
		desc = "Implements unit locks and structure placement.",
		author = "GoogleFrog",
		date = "6 February 2017",
		license = "GNU GPL, v2 or later",
		layer = 0, -- Before game_over.lua for the purpose of setting vitalUnit
		enabled = true
	}
end

local campaignBattleID = Spring.GetModOptions().singleplayercampaignbattleid
local missionDifficulty = tonumber(Spring.GetModOptions().planetmissiondifficulty) or 2
if not campaignBattleID then
	return
end

local doNotDisableAnyUnits = (Spring.GetModOptions().campaign_debug_units == "1")
local SPAWN_GAME_PRELOAD = true

local CAMPAIGN_SPAWN_DEBUG = (Spring.GetModOptions().campaign_spawn_debug == "1")

local COMPARE = {
	AT_LEAST = 1,
	AT_MOST = 2
}

local alliedTrueTable = {allied = true}
local publicTrueTable = {public = true}

local CMD_INSERT = CMD.INSERT
local PLAYER_ALLY_TEAM_ID = 0
local PLAYER_TEAM_ID = 0

local SAVE_FILE = "Gadgets/mission_galaxy_campaign_battle.lua"
local loadGameFrame = 0

local FACING_TO_HEADING = 2^14

local mapCenterX = Game.mapSizeX / 2
local mapCenterZ = Game.mapSizeZ / 2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then --SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("LuaRules/Configs/customcmds.h.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Variables

-- Variables that require saving for save/load
local unitLineage = {}
local initialUnitData = {}
local bonusObjectiveList = {}

local commandsToGive = nil -- Give commands just after game start
local wantLevelGround = nil -- Positions to level

-- Regeneratable from other information
local vitalUnits = {}
local defeatConditionConfig
local victoryAtLocation = {}
local typeVictoryLocations = {}
local finishedUnits = {} -- Units that have been non-nanoframes at some point.

local midgamePlacement = {}

local unlockedUnitsByTeam = {}
local teamCommParameters = {}

local enemyUnitDefBonusObj = {}
local myUnitDefBonusObj = {}
local checkForLoseAfterSeconds = false
local completeAllBonusObjectiveID
local timeLossObjectiveID

-- Small speedup things.
local firstGameFrame = true
local gameIsOver = false
local allyTeamList = Spring.GetAllyTeamList()

local initialUnitDataTable = {}

local removedCmdDesc = {} -- Remember commands so they can be readded.
local disableAiUnitControl

GG.terraformRequiresUnlock = true
GG.terraformUnlocked = {}

loaded = true
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- For gadget:Save
local function UpdateSaveReferences()
	_G.missionGalaxySaveTable = {
		unitLineage        = unitLineage,
		initialUnitData    = initialUnitData,
		bonusObjectiveList = bonusObjectiveList,
	}
end
UpdateSaveReferences()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utility

local BUILD_RESOLUTION = 16

local CustomKeyToUsefulTable = Spring.Utilities.CustomKeyToUsefulTable

local function SumUnits(units, limit)
	if not units then
		return 0
	end
	local count = 0
	for unitID, wantedAllyTeamID in pairs(units) do
		local inbuild = select(3, Spring.GetUnitIsStunned(unitID))
		if not inbuild then
			local allyTeamID = Spring.GetUnitAllyTeam(unitID)
			if allyTeamID == wantedAllyTeamID then
				count = count + 1
				if count >= limit then
					return count
				end
			end
		end
	end
	return count
end

local function ComparisionSatisfied(compareType, targetNumber, number)
	if compareType == COMPARE.AT_LEAST then
		return number >= targetNumber
	elseif compareType == COMPARE.AT_MOST then
		return number <= targetNumber
	end
	return false
end

local function SanitizeBuildPositon(x, z, ud, facing)
	local xSize, zSize = ud.xsize, ud.zsize
	if facing % 2 == 1 then
		xSize, zSize = zSize, xSize
	end
	local oddX = (xSize % 4 == 2)
	local oddZ = (zSize % 4 == 2)
	
	if oddX then
		x = math.floor((x + 8)/BUILD_RESOLUTION)*BUILD_RESOLUTION - 8
	else
		x = math.floor(x/BUILD_RESOLUTION)*BUILD_RESOLUTION
	end
	if oddZ then
		z = math.floor((z + 8)/BUILD_RESOLUTION)*BUILD_RESOLUTION - 8
	else
		z = math.floor(z/BUILD_RESOLUTION)*BUILD_RESOLUTION
	end
	return x, z, xSize, zSize
end

local function GetExtraStartUnits(teamID, customKeys)
	if initialUnitDataTable[teamID] then
		return initialUnitDataTable[teamID]
	end
	
	local prefix
	if Spring.GetGaiaTeamID() == teamID then
		prefix = "neutralstartunits_"
	else
		prefix =  "extrastartunits_"
	end
	
	if not (customKeys and customKeys[prefix .. "1"]) then
		return
	end
	local startUnits = {}
	
	local block = 1
	while customKeys[prefix .. block] do
		local blockUnits = CustomKeyToUsefulTable(customKeys[prefix .. block])
		for i = 1, #blockUnits do
			startUnits[#startUnits + 1] = blockUnits[i]
		end
		block = block + 1
	end
	initialUnitDataTable[teamID] = startUnits
	return startUnits
end

local function SetGameRulesParamHax(key, value)
	--Spring.SetGameRulesParam(key, value)
	Spring.SetTeamRulesParam(0, key, value, publicTrueTable)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Victory and Defeat functions

local function IsVitalUnitType(unitID, unitDefID)
	-- Commanders are handled seperately
	local allyTeamID = Spring.GetUnitAllyTeam(unitID)
	if not allyTeamID then
		Spring.Echo("IsVitalUnitType missing allyTeamID")
		return
	end
	local defeatConfig = defeatConditionConfig[allyTeamID]
	return defeatConfig.vitalUnitTypes and defeatConfig.vitalUnitTypes[unitDefID]
end

local function InitializeVictoryConditions()
	defeatConditionConfig = CustomKeyToUsefulTable(Spring.GetModOptions().defeatconditionconfig) or {}
	for i = 1, #allyTeamList do
		local allyTeamID = allyTeamList[i]
		local defeatConfig = defeatConditionConfig[allyTeamID] or {}
		if defeatConfig.vitalUnitTypes then
			local unitDefMap = {}
			for j = 1, #defeatConfig.vitalUnitTypes do
				local ud = UnitDefNames[defeatConfig.vitalUnitTypes[j]]
				if ud then
					unitDefMap[ud.id] = true
				end
			end
			defeatConfig.vitalUnitTypes = unitDefMap
		end
		if defeatConfig.loseAfterSeconds then
			checkForLoseAfterSeconds = true
		end
		defeatConditionConfig[allyTeamID] = defeatConfig
	end
end

local function AddDefeatIfUnitDestroyed(unitID, allyTeamID, objectiveID)
	local defeatConfig = defeatConditionConfig[allyTeamID]
	defeatConfig.defeatIfUnitDestroyed = defeatConfig.defeatIfUnitDestroyed or {}
	defeatConfig.defeatIfUnitDestroyed[unitID] = (objectiveID or true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Victory at location units

local function AddVictoryAtLocationUnit(unitID, location, allyTeamID)
	Spring.Echo("Adding victory at location unit", unitID)
	victoryAtLocation = victoryAtLocation or {}
	victoryAtLocation[unitID] = victoryAtLocation[unitID] or {}
	local locations = victoryAtLocation[unitID]
	locations[#locations + 1] = {
		x = location.x,
		z = location.z,
		radiusSq = location.radius*location.radius,
		allyTeamID = allyTeamID
	}
	
	if location.mapMarker then
		SendToUnsynced("AddMarker", math.floor(location.x) .. math.floor(location.z), location.x, location.z, location.mapMarker.text, location.mapMarker.color)
	end
end

local function DoVictoryAtLocationCheck(unitID, location)
	if not Spring.ValidUnitID(unitID) then
		return false
	end
	if Spring.GetUnitAllyTeam(unitID) ~= location.allyTeamID then
		return false
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	if (x - location.x)^2 + (z - location.z)^2 <= location.radiusSq then
		return true
	end
	return false
end

local function VictoryAtLocationUpdate()
	if not victoryAtLocation then
		return
	end
	for unitID, data in pairs(victoryAtLocation) do
		for i = 1, #data do
			if DoVictoryAtLocationCheck(unitID, data[i]) then
				if data[i].objectiveID then
					local objParameter = "objectiveSuccess_" .. data[i].objectiveID
					SetGameRulesParamHax(objParameter, (Spring.GetGameRulesParam(objParameter) or 0) + ((Spring.GetUnitAllyTeam(unitID) == PLAYER_ALLY_TEAM_ID and 1) or 0))
				end
				GG.CauseVictory(data[i].allyTeamID)
				return
			end
		end
	end
end

local function MaybeAddTypeVictoryLocation(unitID, unitDefID, teamID)
	if not typeVictoryLocations[teamID] then
		return
	end
	local name = unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].name
	local locations = name and typeVictoryLocations[teamID][name]
	if not locations then
		return
	end
	local allyTeamID = Spring.GetUnitAllyTeam(unitID)
	for i = 1, #locations do
		AddVictoryAtLocationUnit(unitID, locations[i], allyTeamID)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Bonus Objectives

local function AllOtherObjectivesSucceeded(ignoreObjectiveID)
	for i = 1, #bonusObjectiveList do
		if i ~= ignoreObjectiveID then
			if not bonusObjectiveList[i].success then
				return false
			end
		end
	end
	return true
end

local function CompleteBonusObjective(bonusObjectiveID, success)
	local objectiveData = bonusObjectiveList[bonusObjectiveID]
	SetGameRulesParamHax("bonusObjectiveSuccess_" .. bonusObjectiveID, (success and 1) or 0)
	
	objectiveData.success = success
	objectiveData.terminated = true
	
	if completeAllBonusObjectiveID and bonusObjectiveID ~= completeAllBonusObjectiveID then
		if success then
			if AllOtherObjectivesSucceeded(completeAllBonusObjectiveID) then
				CompleteBonusObjective(completeAllBonusObjectiveID, true)
			end
		else
			CompleteBonusObjective(completeAllBonusObjectiveID, false)
		end
	end
end

local function CheckBonusObjective(bonusObjectiveID, gameSeconds, victory)
	local objectiveData = bonusObjectiveList[bonusObjectiveID]
	gameSeconds = gameSeconds or math.floor(Spring.GetGameFrame()/30)
	
	-- Cbeck whether the objective is open
	if objectiveData.terminated then
		return
	end
	
	if objectiveData.completeAllBonusObjectives then
		return -- Not handled here
	end
	
	-- Check for victory timer
	if objectiveData.victoryByTime then
		if victory then
			CompleteBonusObjective(bonusObjectiveID, true)
		elseif gameSeconds > objectiveData.victoryByTime then
			CompleteBonusObjective(bonusObjectiveID, false)
		end
		return
	end
	
	-- Check whether the objective is in the right timeframe and whether it passes/fails
	-- Times: satisfyAtTime, satisfyByTime, satisfyUntilTime, satisfyAfterTime, satisfyForeverAfterFirstSatisfied, satisfyOnce or satisfyForever
	if objectiveData.satisfyByTime and (objectiveData.satisfyByTime < gameSeconds) then
		CompleteBonusObjective(bonusObjectiveID, false)
		return
	end
	if objectiveData.satisfyUntilTime and (objectiveData.satisfyUntilTime < gameSeconds) then
		CompleteBonusObjective(bonusObjectiveID, true)
		return
	end
	if objectiveData.satisfyAfterTime and (objectiveData.satisfyAfterTime >= gameSeconds) then
		return
	end
	if objectiveData.satisfyAtTime and (objectiveData.satisfyAtTime ~= gameSeconds) then
		return
	end
	
	-- Objective may have succeeded if the game ends.
	if gameIsOver and (objectiveData.satisfyForever or objectiveData.satisfyUntilTime or objectiveData.satisfyAfterTime or objectiveData.satisfyForever) then
		CompleteBonusObjective(bonusObjectiveID, true)
		return
	end
	
	-- Check satisfaction
	local unitCount = SumUnits(objectiveData.units, objectiveData.targetNumber + 1) + (objectiveData.removedUnits or 0)
	if objectiveData.onlyCountRemovedUnits then
		unitCount = objectiveData.removedUnits or 0
	end
	local satisfied = ComparisionSatisfied(objectiveData.comparisionType, objectiveData.targetNumber, unitCount)
	if satisfied then
		if objectiveData.satisfyAtTime or objectiveData.satisfyByTime or objectiveData.satisfyOnce then
			CompleteBonusObjective(bonusObjectiveID, true)
		end
		if objectiveData.satisfyForeverAfterFirstSatisfied then
			objectiveData.satisfyForeverAfterFirstSatisfied = nil
			objectiveData.satisfyForever = true
		end
		if objectiveData.lockUnitsOnSatisfy then
			objectiveData.lockUnitsOnSatisfy = nil
			objectiveData.unitsLocked = true
		end
	else
		if objectiveData.satisfyAtTime or objectiveData.satisfyUntilTime or objectiveData.satisfyAfterTime or objectiveData.satisfyForever then
			CompleteBonusObjective(bonusObjectiveID, false)
		end
	end
end

local function DebugPrintBonusObjective()
	Spring.Echo(" ====== Bonus Objectives ====== ")
	for i = 1, #bonusObjectiveList do
		local objectiveData = bonusObjectiveList[i]
		Spring.Echo("Objective", i, "Succeed", objectiveData.success, "Terminated", objectiveData.terminated)
	end
end

local function DoPeriodicBonusObjectiveUpdate(gameSeconds)
	for i = 1, #bonusObjectiveList do
		CheckBonusObjective(i, gameSeconds)
	end
	--DebugPrintBonusObjective()
end

local function AddBonusObjectiveUnit(unitID, bonusObjectiveID, allyTeamID, isCapture)
	if gameIsOver then
		return
	end
	local objectiveData = bonusObjectiveList[bonusObjectiveID]
	if objectiveData.unitsLocked or objectiveData.terminated then
		return
	end
	if isCapture and not objectiveData.capturedUnitsSatisfy then
		return
	end
	objectiveData.units = objectiveData.units or {}
	objectiveData.units[unitID] = allyTeamID or Spring.GetUnitAllyTeam(unitID)
	if objectiveData.lockUnitsOnSatisfy then
		CheckBonusObjective(bonusObjectiveID)
	end
end

local function RemoveBonusObjectiveUnit(unitID, bonusObjectiveID)
	if gameIsOver then
		return
	end
	local objectiveData = bonusObjectiveList[bonusObjectiveID]
	if not objectiveData.units then
		return
	end
	if objectiveData.units[unitID] then
		if objectiveData.countRemovedUnits or objectiveData.onlyCountRemovedUnits then
			if finishedUnits[unitID] then
				objectiveData.removedUnits = (objectiveData.removedUnits or 0) + 1
			end
		end
		if objectiveData.failOnUnitLoss then
			if finishedUnits[unitID] then
				CompleteBonusObjective(bonusObjectiveID, false)
			end
		end
		objectiveData.units[unitID] = nil
	end
end

local function SetWinBeforeBonusObjective(victory)
	local gameSeconds = math.floor(Spring.GetGameFrame()/30)
	for i = 1, #bonusObjectiveList do
		CheckBonusObjective(i, gameSeconds, victory)
	end
	DebugPrintBonusObjective()
end

local function InitializeBonusObjectives()
	local bonusObjectiveConfig = CustomKeyToUsefulTable(Spring.GetModOptions().bonusobjectiveconfig) or {}
	for objectiveID = 1, #bonusObjectiveConfig do
		local bonusObjective = bonusObjectiveConfig[objectiveID] or {}
		if bonusObjective.unitTypes then
			local unitDefMap = {}
			for i = 1, #bonusObjective.unitTypes do
				local ud = UnitDefNames[bonusObjective.unitTypes[i]]
				if ud then
					unitDefMap[ud.id] = true
					myUnitDefBonusObj[ud.id] = myUnitDefBonusObj[ud.id] or {}
					myUnitDefBonusObj[ud.id][#myUnitDefBonusObj[ud.id] + 1] = objectiveID
				end
			end
			bonusObjective.unitTypes = unitDefMap
		end
		if bonusObjective.enemyUnitTypes then
			local unitDefMap = {}
			for i = 1, #bonusObjective.enemyUnitTypes do
				local ud = UnitDefNames[bonusObjective.enemyUnitTypes[i]]
				if ud then
					unitDefMap[ud.id] = true
					enemyUnitDefBonusObj[ud.id] = enemyUnitDefBonusObj[ud.id] or {}
					enemyUnitDefBonusObj[ud.id][#enemyUnitDefBonusObj[ud.id] + 1] = objectiveID
				end
			end
			bonusObjective.enemyUnitTypes = unitDefMap
		end
		if bonusObjective.completeAllBonusObjectives then
			completeAllBonusObjectiveID = objectiveID
		end
		bonusObjectiveList[objectiveID] = bonusObjective
	end
end

local function AddUnitToBonusObjectiveList(unitID, objectiveList, isCapture)
	if not objectiveList then
		return
	end
	for i = 1, #objectiveList do
		AddBonusObjectiveUnit(unitID, objectiveList[i], nil, isCapture)
	end
end

local function RemoveUnitFromBonusObjectiveList(unitID, objectiveList)
	if not objectiveList then
		return
	end
	for i = 1, #objectiveList do
		RemoveBonusObjectiveUnit(unitID, objectiveList[i])
	end
end

local function BonusObjectiveUnitCreated(unitID, unitDefID, teamID, isCapture)
	if teamID == PLAYER_TEAM_ID then
		AddUnitToBonusObjectiveList(unitID, myUnitDefBonusObj[unitDefID], isCapture)
	elseif Spring.GetUnitAllyTeam(unitID) ~= PLAYER_ALLY_TEAM_ID then
		AddUnitToBonusObjectiveList(unitID, enemyUnitDefBonusObj[unitDefID], isCapture)
	end
end

local function CheckInitialUnitDestroyed(unitID)
	if not initialUnitData[unitID] then
		return
	end
	
	if initialUnitData[unitID].mapMarker then
		SendToUnsynced("RemoveMarker", unitID)
	end
	
	victoryAtLocation[unitID] = nil
	initialUnitData[unitID] = nil
end

local function BonusObjectiveUnitDestroyed(unitID, unitDefID, teamID)
	RemoveUnitFromBonusObjectiveList(unitID, myUnitDefBonusObj[unitDefID])
	RemoveUnitFromBonusObjectiveList(unitID, enemyUnitDefBonusObj[unitDefID])
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unit Placement

local function AddInitialUnitObjectiveParameters(unitID, parameters)
	initialUnitData[unitID] = parameters
	initialUnitData[unitID].allyTeamID = initialUnitData[unitID].allyTeamID or Spring.GetUnitAllyTeam(unitID)
	if parameters.defeatIfDestroyedObjectiveID or parameters.defeatIfDestroyed then
		AddDefeatIfUnitDestroyed(unitID, initialUnitData[unitID].allyTeamID, parameters.defeatIfDestroyedObjectiveID)
	end
	if parameters.victoryAtLocation then
		AddVictoryAtLocationUnit(unitID, parameters.victoryAtLocation, initialUnitData[unitID].allyTeamID)
	end
	if parameters.bonusObjectiveID then
		AddBonusObjectiveUnit(unitID, parameters.bonusObjectiveID, initialUnitData[unitID].allyTeamID)
	end
end

local function SetupInitialUnitParameters(unitID, unitData)
	AddInitialUnitObjectiveParameters(unitID, unitData)
	
	if unitData.invincible then
		GG.SetUnitInvincible(unitID, true)
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitRulesParam(unitID, "ignoredByAI", 1, publicTrueTable)
		Spring.SetUnitRulesParam(unitID, "avoidAttackingNeutral", 1)
	elseif unitData.notAutoAttacked then
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitRulesParam(unitID, "ignoredByAI", 1, publicTrueTable)
		Spring.SetUnitRulesParam(unitID, "avoidAttackingNeutral", 1)
	end
	
	if unitData.noControl then
		local teamID = Spring.GetUnitTeam(unitID)
		if teamID then
			disableAiUnitControl = disableAiUnitControl or {}
			local unitList = disableAiUnitControl[teamID] or {}
			unitList[#unitList + 1] = unitID
			disableAiUnitControl[teamID] = unitList
		end
	end
	
	if unitData.mapMarker then
		local ux, _, uz = Spring.GetUnitPosition(unitID)
		if ux then
			SendToUnsynced("AddMarker", unitID, ux, uz, unitData.mapMarker.text, unitData.mapMarker.color)
		end
	end
end

local function GetClearPlacement(unitDefID, centerX, centerZ, spawnRadius, depth)
	local x, z = centerX, centerZ
	if spawnRadius then
		x = centerX + 2*math.random()*spawnRadius - spawnRadius
		z = centerZ + 2*math.random()*spawnRadius - spawnRadius
	end
	local y = Spring.GetGroundHeight(x,z)
	
	spawnRadius = spawnRadius or 100
	local tries = 1
	while not (y > depth and Spring.TestMoveOrder(unitDefID, x, y, z, 0, 0, 0, true, true, false)) do
		if tries > 30 then
			spawnRadius = spawnRadius + 15
		end
		if tries > 50 then
			break
		end
		x = centerX + 2*math.random()*spawnRadius - spawnRadius
		z = centerZ + 2*math.random()*spawnRadius - spawnRadius
		y = Spring.GetGroundHeight(x,z)
		tries = tries + 1
	end
	
	return x, z
end

local function PlaceUnit(unitData, teamID, doLevelGround, findClearPlacement)
	if not CAMPAIGN_SPAWN_DEBUG then
		if unitData.difficultyAtLeast and (unitData.difficultyAtLeast > missionDifficulty) then
			return
		end
		if unitData.difficultyAtMost and (unitData.difficultyAtMost < missionDifficulty) then
			return
		end
	end
	local name = unitData.name
	local ud = UnitDefNames[name]
	if not (ud and ud.id) then
		Spring.Echo("Missing unit placement", name)
		return
	end
	
	local x, z, facing, xSize, zSize = unitData.x, unitData.z, unitData.facing
	
	if findClearPlacement then
		x, z = GetClearPlacement(ud.id, x, z, unitData.spawnRadius, -ud.maxWaterDepth)
	end
	
	if ud.isImmobile then
		x, z, xSize, zSize = SanitizeBuildPositon(x, z, ud, facing)
	end
	
	local build = (unitData.buildProgress and unitData.buildProgress < 1) or false
	local wantLevel = ud.isImmobile and ud.levelGround
	local unitID
	if unitData.orbitalDrop then
		unitID = GG.DropUnit(ud.name, x, Spring.GetGroundHeight(x,z), z, facing, teamID, true)
	else
		unitID = Spring.CreateUnit(ud.id, x, Spring.GetGroundHeight(x,z), z, facing, teamID, build, doLevelGround and wantLevel)
	end
	
	if unitData.stunTime then
		local _, maxHealth = Spring.GetUnitHealth(unitID)
		local paraFactor = 1 + unitData.stunTime/40
		Spring.SetUnitHealth(unitID, {paralyze = maxHealth * paraFactor})
	end
	
	if CAMPAIGN_SPAWN_DEBUG then
		if unitData.difficultyAtLeast then
			if unitData.difficultyAtMost then
				Spring.Utilities.UnitEcho(unitID, "At least " .. unitData.difficultyAtLeast .. ". At most " .. unitData.difficultyAtMost)
			else
				Spring.Utilities.UnitEcho(unitID, "At least " .. unitData.difficultyAtLeast)
			end
		elseif unitData.difficultyAtMost then
			Spring.Utilities.UnitEcho(unitID, "At most " .. unitData.difficultyAtMost)
		end
		
		Spring.SetUnitRulesParam(unitID, "fulldisable", 1)
		GG.UpdateUnitAttributes(unitID)
	end
	
	if (not doLevelGround) and wantLevel then
		wantLevelGround = wantLevelGround or {}
		wantLevelGround[#wantLevelGround + 1] = {
			pos = {x, Spring.GetGroundHeight(x,z), z},
			xSize = xSize,
			zSize = zSize,
		}
	end
	
	if not unitID then
		Spring.MarkerAddPoint(x, 0, z, "Error creating unit " .. (((ud or {}).humanName) or "???"))
		return
	end
	
	if unitData.shieldFactor and ud.customParams.shield_power then
		Spring.SetUnitShieldState(unitID, -1, true, unitData.shieldFactor*tonumber(ud.customParams.shield_power))
	end
	
	if unitData.commands then
		local commands = unitData.commands
		commandsToGive = commandsToGive or {}
		commandsToGive[#commandsToGive + 1] = {
			unitID = unitID,
			commands = commands,
		}
	elseif unitData.patrolRoute then
		local patrolRoute = unitData.patrolRoute
		local patrolCommands = {
			[1] = {
				cmdID = CMD_RAW_MOVE,
				pos = patrolRoute[1]
			}
		}
		
		for i = 2, #patrolRoute do
			patrolCommands[#patrolCommands + 1] = {
				cmdID = CMD.PATROL,
				pos = patrolRoute[i],
				options = {"shift"}
			}
		end
		
		commandsToGive = commandsToGive or {}
		commandsToGive[#commandsToGive + 1] = {
			unitID = unitID,
			commands = patrolCommands,
		}
	elseif unitData.selfPatrol then
		local vx = mapCenterX - x
		local vz = mapCenterZ - z
		local cx = x + vx*25/math.abs(vx)
		local cz = z + vz*25/math.abs(vz)
		
		local patrolCommands = {
			[1] = {
				cmdID = CMD.PATROL,
				pos = {cx, cz}
			}
		}
		
		commandsToGive = commandsToGive or {}
		commandsToGive[#commandsToGive + 1] = {
			unitID = unitID,
			commands = patrolCommands,
		}
	end
	
	if unitData.movestate then
		commandsToGive = commandsToGive or {}
		if commandsToGive[#commandsToGive] and commandsToGive[#commandsToGive].unitID == unitID then
			local cmd = commandsToGive[#commandsToGive].commands
			cmd[#cmd + 1] = {cmdID = CMD.MOVE_STATE, params = {unitData.movestate}, options = {"shift"}}
		else
			commandsToGive[#commandsToGive + 1] = {
				unitID = unitID,
				commands = {cmdID = CMD.MOVE_STATE, params = {unitData.movestate}, options = {"shift"}}
			}
		end
	end
	
	SetupInitialUnitParameters(unitID, unitData, x, z)
	
	if build then
		local _, maxHealth = Spring.GetUnitHealth(unitID)
		Spring.SetUnitHealth(unitID, {build = unitData.buildProgress, health = maxHealth*unitData.buildProgress})
	end
end

local function AddMidgameUnit(unitData, teamID, gameFrame, spawnFrameOverride)
	local n = spawnFrameOverride or unitData.delay
	if gameFrame > n then
		return -- Loaded game.
	end
	if CAMPAIGN_SPAWN_DEBUG then
		return -- Do not spawn any midgame units in spawn debug.
	end
	if unitData.difficultyAtLeast and (unitData.difficultyAtLeast > missionDifficulty) then
		return
	end
	if unitData.difficultyAtMost and (unitData.difficultyAtMost < missionDifficulty) then
		return
	end
	
	local unitList = midgamePlacement[n] or {}
	unitList[#unitList + 1] = {
		unitData = unitData,
		teamID = teamID,
	}
	midgamePlacement[n] = unitList
end

local function DoStructureLevelGround()
	if not wantLevelGround then
		return
	end
	for i = 1, #wantLevelGround do
		local x, y, z = wantLevelGround[i].pos[1], wantLevelGround[i].pos[2], wantLevelGround[i].pos[3]
		local xSize, zSize = wantLevelGround[i].xSize, wantLevelGround[i].zSize
		Spring.LevelHeightMap(x - xSize*4, z - zSize*4, x + xSize*4, z + zSize*4, y)
	end
	wantLevelGround = nil
end

local function AddUnitTerraform(unitData)
	if not unitData.terraformHeight then
		return
	end
	
	local ud = UnitDefNames[unitData.name]
	if not (ud and ud.id) then
		return
	end
	
	local x, z, facing = unitData.x, unitData.z, unitData.facing
	
	if ud.isImmobile then
		x, z = SanitizeBuildPositon(x, z, ud, facing)
	end
	
	local xsize, zsize
	if (facing == 0) or (facing == 2) then
		xsize = ud.xsize*4
		zsize = (ud.zsize or ud.ysize)*4
	else
		xsize = (ud.zsize or ud.ysize)*4
		zsize = ud.xsize*4
	end
	
	local unitTerra = {
		terraformShape = 1, -- Rectangle
		terraformType = 1, -- Level
		position = {
			x - xsize,
			z - zsize,
			x + xsize,
			z + zsize
		},
		height = unitData.terraformHeight,
	}
	
	return unitTerra
end

local function PlaceFeature(featureData, teamID)
	if featureData.difficultyAtLeast and (featureData.difficultyAtLeast > missionDifficulty) then
		return
	end
	if featureData.difficultyAtMost and (featureData.difficultyAtMost < missionDifficulty) then
		return
	end
	
	local name = featureData.name
	local fd = FeatureDefNames[name]
	if not (fd and fd.id) then
		Spring.Echo("Missing feature placement", name)
		return
	end
	
	local x, z, facing = featureData.x, featureData.z, featureData.facing
	if not facing then
		facing = math.random()*4
	end
	
	local unitDefName
	if string.find(name, "_dead") then
		unitDefName = string.gsub(name, "_dead", "")
		local ud = UnitDefNames[unitDefName]
		if ud.isImmobile then
			x, z = SanitizeBuildPositon(x, z, ud, facing)
		end
	end
	
	local featureID = Spring.CreateFeature(fd.id, x, Spring.GetGroundHeight(x,z), z, facing*FACING_TO_HEADING, teamID)
	if unitDefName then
		Spring.SetFeatureResurrect(featureID, unitDefName, math.floor(facing + 0.5)%4)
	end
end

local function PlaceRetinueUnit(retinueID, range, unitDefName, spawnX, spawnZ, facing, teamID, experience)
	local unitDefID = UnitDefNames[unitDefName]
	unitDefID = unitDefID and unitDefID.id
	if not unitDefID then
		return
	end
	
	local validPlacement = false
	local x, z
	local tries = 0
	while not validPlacement do
		x, z = spawnX + math.random()*range*2 - range, spawnZ + math.random()*range*2 - range
		if tries < 10 then
			validPlacement = Spring.TestBuildOrder(unitDefID, x, 0, z, facing)
		elseif tries < 20 then
			validPlacement = Spring.TestMoveOrder(unitDefID, x, 0, z)
		else
			x, z =  spawnX + math.random()*2 - 1, spawnZ + math.random()*2 - 1
		end
	end
	
	local retinueUnitID = Spring.CreateUnit(unitDefID, x, Spring.GetGroundHeight(x,z), z, facing, teamID)
	Spring.SetUnitRulesParam(retinueUnitID, "retinueID", retinueID, {ally = true})
	Spring.SetUnitExperience(retinueUnitID, experience)
end

local function HandleCommanderCreation(unitID, teamID)
	if Spring.GetGameFrame() >= 10 then
		return
	end
	local commParameters = teamCommParameters[teamID]
	if not commParameters then
		return
	end
	AddInitialUnitObjectiveParameters(unitID, commParameters)
end

local function ProcessUnitCommand(unitID, command)
	if command.unitName then
		local ud = UnitDefNames[command.unitName]
		command.cmdID = ud and ud.id and -ud.id
		if not command.cmdID then
			return
		end
		if command.pos then
			command.pos[1], command.pos[2] = SanitizeBuildPositon(command.pos[1], command.pos[2], ud, command.facing or 0)
		else -- Must be a factory production command
			Spring.GiveOrderToUnit(unitID, command.cmdID, 0, command.options or 0)
			return
		end
	end
	
	local team = Spring.GetUnitTeam(unitID)
	
	if command.pos then
		local x, z = command.pos[1], command.pos[2]
		local y = CallAsTeam(team,
			function ()
				return Spring.GetGroundHeight(x, z)
			end
		)
		
		Spring.GiveOrderToUnit(unitID, command.cmdID, {x, y, z, command.facing or command.radius}, command.options or 0)
		return
	end
	
	if command.atPosition then
		local p = command.atPosition
		local units = Spring.GetUnitsInRectangle(p[1] - BUILD_RESOLUTION, p[2] - BUILD_RESOLUTION, p[1] + BUILD_RESOLUTION, p[2] + BUILD_RESOLUTION)
		if units and units[1] then
			Spring.GiveOrderToUnit(unitID, command.cmdID, units[1], command.options or 0)
		end
		return
	end
	
	local params = {}
	if command.params then
		for i = 1, #command.params do -- Somehow tables lose their order
			params[i] = command.params[i]
		end
	end
	Spring.GiveOrderToUnit(unitID, command.cmdID, params, command.options or 0)
end

local function GiveCommandsToUnit(unitID, commands)
	for i = 1, #commands do
		ProcessUnitCommand(unitID, commands[i])
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unit Locking System

local function RemoveUnit(unitID, lockDefID)
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, -lockDefID)
	if (cmdDescID) then
		if not removedCmdDesc[lockDefID] then
			local toRemove = Spring.GetUnitCmdDescs(unitID, cmdDescID, cmdDescID)
			removedCmdDesc[lockDefID] = toRemove[1]
		end
		Spring.RemoveUnitCmdDesc(unitID, cmdDescID)
	end
end

local function AddUnit(unitID, lockDefID)
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, -lockDefID)
	if (not cmdDescID) and removedCmdDesc[lockDefID] then
		Spring.InsertUnitCmdDesc(unitID, removedCmdDesc[lockDefID])
	end
end

local function LockUnit(unitID, lockDefID)
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, -lockDefID)
	if (cmdDescID) then
		local cmdArray = {disabled = true}
		Spring.EditUnitCmdDesc(unitID, cmdDescID, cmdArray)
	end
end

local function SetBuildOptions(unitID, unitDefID, teamID)
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if ud and ud.isBuilder then
		local origUnlocks
		if unitLineage[unitID] and (unitLineage[unitID] ~= teamID) then
			origUnlocks = unlockedUnitsByTeam[unitLineage[unitID]]
		end
		local unlockedUnits = unlockedUnitsByTeam[teamID]
		if unlockedUnits or origUnlocks then
			local buildoptions = ud.buildOptions
			for i = 1, #buildoptions do
				local opt = buildoptions[i]
				if not ((unlockedUnits and unlockedUnits[opt]) or (origUnlocks and origUnlocks[opt]))then
					RemoveUnit(unitID, opt)
				else
					AddUnit(unitID, opt)
				end
			end
		end
	end
end

local function IsUnlockedForUnit(unitID, teamID, buildUnitDefID)
	-- Unlock if either my current or original team could build the unit.
	if not (unlockedUnitsByTeam[teamID] and unlockedUnitsByTeam[teamID][buildUnitDefID]) then
		local origTeamID = (unitID and unitLineage[unitID])
		if origTeamID and unlockedUnitsByTeam[origTeamID] and unlockedUnitsByTeam[origTeamID][buildUnitDefID] then
			return true
		end
		return false
	end
	return true
end

function gadget:AllowCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOpts)
	if CAMPAIGN_SPAWN_DEBUG then
		return false
	end
	if cmdID == CMD_INSERT and cmdParams and cmdParams[2] then
		cmdID = cmdParams[2]
	end
	if cmdID < 0 and not IsUnlockedForUnit(unitID, unitTeamID, -cmdID) then
		return false
	end
	return true
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeamID, x, y, z)
	return IsUnlockedForUnit(builderID, builderTeamID, unitDefID)
end

local function LineageUnitCreated(unitID, unitDefID, teamID, builderID)
	local ud = UnitDefs[unitDefID]
	if ud.customParams.dynamic_comm then
		HandleCommanderCreation(unitID, teamID)
	end
	
	if builderID and unitLineage[builderID] then
		unitLineage[unitID] = unitLineage[builderID]
	else
		unitLineage[unitID] = teamID
	end
	SetBuildOptions(unitID, unitDefID, teamID)
	
	if CAMPAIGN_SPAWN_DEBUG then
		Spring.SetUnitRulesParam(unitID, "fulldisable", 1)
		GG.UpdateUnitAttributes(unitID)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Initialization

local function SetTeamUnlocks(teamID, customKeys)
	if doNotDisableAnyUnits then
		return
	end
	local unlockData = CustomKeyToUsefulTable(customKeys and customKeys.campaignunlocks)
	if not unlockData then
		return
	end
	local unlockedUnits = {}
	local unlockCount = 0
	for i = 1, #unlockData do
		local ud = UnitDefNames[unlockData[i]]
		if ud and ud.id then
			unlockCount = unlockCount + 1
			Spring.SetTeamRulesParam(teamID, "unlockedUnit" .. unlockCount, ud.name, alliedTrueTable)
			unlockedUnits[ud.id] = true
			if ud.customParams.parent_of_plate then
				local pud = UnitDefNames[ud.customParams.parent_of_plate]
				if pud and not unlockedUnits[pud.id] then
					unlockCount = unlockCount + 1
					Spring.SetTeamRulesParam(teamID, "unlockedUnit" .. unlockCount, pud.name, alliedTrueTable)
					unlockedUnits[pud.id] = true
				end
			end
		end
	end
	Spring.SetTeamRulesParam(teamID, "unlockedUnitCount", unlockCount, alliedTrueTable)
	unlockedUnitsByTeam[teamID] = unlockedUnits
end

local function SetTeamAbilities(teamID, customKeys)
	local abilityData = CustomKeyToUsefulTable(customKeys and customKeys.campaignabilities)
	if not abilityData then
		return
	end
	for i = 1, #abilityData do
		-- TODO, move to a defs file
		if abilityData[i] == "terraform" then
			Spring.SetTeamRulesParam(teamID, "terraformUnlocked", 1)
			GG.terraformUnlocked[teamID] = true
		end
	end
end

local function InitializeTeamTypeVictoryLocations(teamID, customKeys)
	local locations = CustomKeyToUsefulTable(customKeys and customKeys.typevictorylocation)
	if not locations then
		return
	end
	typeVictoryLocations[teamID] = locations
end

local function PlaceTeamUnits(teamID, customKeys, alliedToPlayer)
	local initialUnits = GetExtraStartUnits(teamID, customKeys)
	if not initialUnits then
		return
	end
	
	for i = 1, #initialUnits do
		PlaceUnit(initialUnits[i], teamID, alliedToPlayer)
	end
end

local function PlaceFeatures(featureData)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for i = 1, #featureData do
		PlaceFeature(featureData[i], gaiaTeamID)
	end
end

local function InitializeCommanderParameters(teamID, customKeys)
	local commParameters = CustomKeyToUsefulTable(customKeys and customKeys.commanderparameters)
	if not commParameters then
		return
	end
	teamCommParameters[teamID] = commParameters
end

local function InitializeUnlocks()
	if doNotDisableAnyUnits then
		GG.terraformRequiresUnlock = false
	else
		SetGameRulesParamHax("terraformRequiresUnlock", 1)
	end
	
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		local customKeys = select(7, Spring.GetTeamInfo(teamID, true))
		SetTeamAbilities(teamID, customKeys)
		SetTeamUnlocks(teamID, customKeys)
		InitializeCommanderParameters(teamID, customKeys)
	end
end

local function InitializeTypeVictoryLocation()
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _,_,_,_,_,allyTeamID, customKeys = Spring.GetTeamInfo(teamID, true)
		InitializeTeamTypeVictoryLocations(teamID, customKeys)
	end
end

local function InitializeMapMarkers()
	local mapMarkers = CustomKeyToUsefulTable(Spring.GetModOptions().planetmissionmapmarkers)
	if not mapMarkers then
		return
	end
	for i = 1, #mapMarkers do
		local marker = mapMarkers[i]
		SendToUnsynced("AddMarker", math.floor(marker.x) .. math.floor(marker.z), marker.x, marker.z, marker.text, marker.color)
	end
end

local function CheckDisableControlAiMessage()
	if not disableAiUnitControl then
		return
	end
	
	for teamID, data in pairs(disableAiUnitControl) do
		local dis_msg = "DISABLE_CONTROL:"
		for i = 1, #data do
			dis_msg = dis_msg .. data[i] .. "+"
			Spring.SetUnitRulesParam(unitID, "disableAiControl", 1, publicTrueTable)
		end
		SendToUnsynced("SendAIEvent", teamID, dis_msg)
	end
	
	disableAiUnitControl = nil
end

local function PlaceMidgameUnits(unitList, gameFrame)
	for i = 1, #unitList do
		local data = unitList[i]
		PlaceUnit(data.unitData, data.teamID, true, true)
		if data.unitData.repeatDelay then
			AddMidgameUnit(data.unitData, data.teamID, gameFrame, gameFrame + data.unitData.repeatDelay)
		end
	end
	
	if commandsToGive then
		for i = 1, #commandsToGive do
			GiveCommandsToUnit(commandsToGive[i].unitID, commandsToGive[i].commands)
		end
		commandsToGive = nil
	end
	
	CheckDisableControlAiMessage()
end

local function InitializeMidgameUnits(gameFrame)
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _,_,_,_,_,allyTeamID, customKeys = Spring.GetTeamInfo(teamID, true)
		
		local midgameUnits = CustomKeyToUsefulTable(customKeys and customKeys.midgameunits)
		if midgameUnits then
			for j = 1, #midgameUnits do
				AddMidgameUnit(midgameUnits[j], teamID, gameFrame)
			end
		end
	end
end

local function DoInitialUnitPlacement()
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		local _,_,_,_,_,allyTeamID, customKeys = Spring.GetTeamInfo(teamID, true)
		PlaceTeamUnits(teamID, customKeys, allyTeamID == PLAYER_ALLY_TEAM_ID)
	end
	
	local featuresToSpawn = CustomKeyToUsefulTable(Spring.GetModOptions().featurestospawn) or false
	if featuresToSpawn then
		PlaceFeatures(featuresToSpawn)
	end
	
	if commandsToGive then
		for i = 1, #commandsToGive do
			GiveCommandsToUnit(commandsToGive[i].unitID, commandsToGive[i].commands)
		end
		commandsToGive = nil
	end
	
	CheckDisableControlAiMessage()
end

local function DoInitialTerraform(noBuildings)
	local terraformList = CustomKeyToUsefulTable(Spring.GetModOptions().initalterraform) or {}
	local gaiaTeamID = Spring.GetGaiaTeamID()
	
	if not noBuildings then
		-- Add terraform for structures
		local teamList = Spring.GetTeamList()
		for i = 1, #teamList do
			local teamID = teamList[i]
			local customKeys = select(7, Spring.GetTeamInfo(teamID, true))
			local initialUnits = GetExtraStartUnits(teamID, customKeys)
			initialUnitDataTable[teamID] = initialUnitDataTable[teamID] or CustomKeyToUsefulTable(customKeys and customKeys.extrastartunits)
			if initialUnits then
				for j = 1, #initialUnits do
					local unitTerra = AddUnitTerraform(initialUnits[j])
					if unitTerra then
						terraformList[#terraformList + 1] = unitTerra
					end
				end
			end
		end

		local neutralUnits = GetExtraStartUnits(gaiaTeamID, Spring.GetModOptions())
		if neutralUnits then
			for i = 1, #neutralUnits do
				local unitTerra = AddUnitTerraform(neutralUnits[i])
				if unitTerra then
					terraformList[#terraformList + 1] = unitTerra
				end
			end
		end
	end
	
	if #terraformList == 0 then
		return
	end
	
	-- Create terraforms
	for i = 1, #terraformList do
		local terraform = terraformList[i]
		local pos = terraform.position
		if terraform.terraformShape == 1 then
			-- Rectangle
			local points = {
				{x = pos[1], z = pos[2]},
				{x = pos[3] - 8, z = pos[2]},
				{x = pos[3] - 8, z = pos[4] - 8},
				{x = pos[1], z = pos[4] - 8},
				{x = pos[1], z = pos[2]},
			}
			GG.Terraform.TerraformArea(terraform.terraformType, points, 5, terraform.height or 0, nil, nil, terraform.teamID or gaiaTeamID,
				terraform.volumeSelection or 0, true, pos[1], pos[2], i, terraform.needConstruction, terraform.enableDecay)
		elseif terraform.terraformShape == 2 then
			-- Line
			local points = {
				{x = pos[1], z = pos[2]},
				{x = pos[3], z = pos[4]},
			}
			GG.Terraform.TerraformWall(terraform.terraformType, points, 2, terraform.height or 0, nil, nil, terraform.teamID or gaiaTeamID,
				terraform.volumeSelection or 0, true, pos[1], pos[2], i, terraform.needConstruction, terraform.enableDecay)
		elseif terraform.terraformShape == 3 then
			-- Ramp
			GG.Terraform.TerraformRamp(pos[1], pos[2], pos[3], pos[4], pos[5], pos[6], terraform.width, nil, nil, terraform.teamID or gaiaTeamID,
				terraform.volumeSelection or 0, true, pos[1], pos[3], i, terraform.needConstruction, terraform.enableDecay)
		end
	end
	local fixSaves = Spring.GetModOptions().init_terra_save_fix
	GG.Terraform.ForceTerraformCompletion(true, fixSaves == 1 or fixSaves == "1")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Gadget Interface

local Unlocks = {}
local GalaxyCampaignHandler = {}

function Unlocks.GetIsUnitUnlocked(teamID, unitDefID)
	if unlockedUnitsByTeam[teamID] then
		if not (unlockedUnitsByTeam[teamID][unitDefID]) then
			return false
		end
	end
	return true
end

function GalaxyCampaignHandler.VitalUnit(unitID)
	return vitalUnits[unitID]
end

function GalaxyCampaignHandler.GetDefeatConfig(allyTeamID)
	return defeatConditionConfig[allyTeamID]
end

function GalaxyCampaignHandler.DeployRetinue(unitID, x, z, facing, teamID)
	local customKeys = select(7, Spring.GetTeamInfo(teamID, true))
	local retinueData = CustomKeyToUsefulTable(customKeys and customKeys.retinuestartunits)
	if retinueData then
		local range = 70 + #retinueData*20
		for i = 1, #retinueData do
			local unitData = retinueData[i]
			PlaceRetinueUnit(unitData.retinueID, range, unitData.unitDefName, x, z, facing, teamID, unitData.experience)
		end
	end
end

function GalaxyCampaignHandler.HasFactoryPlop(teamID)
	return teamCommParameters[teamID] and teamCommParameters[teamID].facplop
end

function GalaxyCampaignHandler.OverrideCommFacing(teamID)
	return teamCommParameters[teamID] and teamCommParameters[teamID].facing
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Victory/Defeat

local function IsWinner(winners)
	for i = 1, #winners do
		if winners[i] == PLAYER_ALLY_TEAM_ID then
			return true
		end
	end
	return false
end

local function MissionGameOver(missionWon)
	gameIsOver = true
	SetWinBeforeBonusObjective(missionWon)
	SendToUnsynced("MissionGameOver", missionWon)
	SetGameRulesParamHax("MissionGameOver", (missionWon and 1) or 0)
	local frame = Spring.GetGameFrame()
	Spring.Echo("set MissionGameOver_frames", frame)
	SetGameRulesParamHax("MissionGameOver_frames", frame)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- (Most) callins

function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
	if IsVitalUnitType(unitID, unitDefID) then
		vitalUnits[unitID] = true
	end
	MaybeAddTypeVictoryLocation(unitID, unitDefID, teamID)
	finishedUnits[unitID] = true
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	LineageUnitCreated(unitID, unitDefID, teamID, builderID)
	BonusObjectiveUnitCreated(unitID, unitDefID, teamID)
end

-- note: Taken comes before Given
function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	SetBuildOptions(unitID, unitDefID, newTeamID)
	BonusObjectiveUnitCreated(unitID, unitDefID, newTeamID, true)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if vitalUnits[unitID] then
		vitalUnits[unitID] = false
	end
	BonusObjectiveUnitDestroyed(unitID, unitDefID, teamID)
	CheckInitialUnitDestroyed(unitID)
	if unitLineage[unitID] then
		unitLineage[unitID] = nil
	end
	if finishedUnits[unitID] then
		finishedUnits[unitID] = false
	end
end

function gadget:Initialize()
	InitializeUnlocks()
	InitializeVictoryConditions()
	InitializeBonusObjectives()
	InitializeTypeVictoryLocation()
	
	GG.MissionGameOver = MissionGameOver
	
	local allUnits = Spring.GetAllUnits()
	for _, unitID in pairs(allUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitDefID then
			local teamID = Spring.GetUnitTeam(unitID)
			gadget:UnitCreated(unitID, unitDefID, teamID)
			if not select(3, Spring.GetUnitIsStunned(unitID)) then
				gadget:UnitFinished(unitID, unitDefID, teamID)
			end
		end
	end
	
	GG.Unlocks = Unlocks
	GG.GalaxyCampaignHandler = GalaxyCampaignHandler
end


function gadget:GamePreload()
	if Spring.GetGameRulesParam("loadedGame") then
		return
	end
	DoInitialTerraform()
	if SPAWN_GAME_PRELOAD then
		DoInitialUnitPlacement()
	end
end

function gadget:GameFrame(n)
	n = n + loadGameFrame
	if firstGameFrame then
		InitializeMapMarkers()
		InitializeMidgameUnits(n)
		firstGameFrame = false
		if not SPAWN_GAME_PRELOAD then
			if not Spring.GetGameRulesParam("loadedGame") then
				DoInitialUnitPlacement()
			end
		end
		DoStructureLevelGround()
		if Spring.GetGameRulesParam("loadedGame") then
			DoInitialTerraform(true)
		end
	end
	
	if midgamePlacement[n] then
		PlaceMidgameUnits(midgamePlacement[n], n)
		midgamePlacement[n] = nil
	end
	
	-- Check objectives
	if n%30 == 0 and not gameIsOver then
		VictoryAtLocationUpdate()
		local gameSeconds = n/30
		if checkForLoseAfterSeconds then
			for i = 1, #allyTeamList do
				local lostAfterSeconds = defeatConditionConfig[allyTeamList[i]].loseAfterSeconds
				if lostAfterSeconds and lostAfterSeconds <= gameSeconds and GG.IsAllyTeamAlive(allyTeamList[i]) then
					local defeatConfig = defeatConditionConfig[allyTeamList[i]]
					if defeatConfig.timeLossObjectiveID then
						local objParameter = "objectiveSuccess_" .. defeatConfig.timeLossObjectiveID
						SetGameRulesParamHax(objParameter, (Spring.GetGameRulesParam(objParameter) or 0) + ((allyTeamList[i] == PLAYER_ALLY_TEAM_ID and 0) or 1))
					end
					GG.DestroyAlliance(allyTeamList[i])
				end
			end
		end
		DoPeriodicBonusObjectiveUpdate(gameSeconds)
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:find("galaxyMissionResign", 1, true) then
		GG.DestroyAlliance(PLAYER_ALLY_TEAM_ID)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Load

function gadget:Load(zip)
	if not (GG.SaveLoad and GG.SaveLoad.ReadFile) then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Galaxy campaign mission failed to access save/load API")
		return
	end
	
	local loadData = GG.SaveLoad.ReadFile(zip, "Galaxy Campaign Battle Handler", SAVE_FILE) or {}
	loadGameFrame = Spring.GetGameRulesParam("lastSaveGameFrame") or 0

	if not loadData.unitLineage
	or not loadData.bonusObjectiveList
	or not loadData.initialUnitData
	then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Galaxy campaign mission load file corrupted")
		return
	end
	
	loaded = true

	-- Unit Lineage. Reset because nonsense would be in it from UnitCreated.
	unitLineage = {}
	for oldUnitID, teamID in pairs(loadData.unitLineage) do
		local unitID = GG.SaveLoad.GetNewUnitID(oldUnitID)
		if unitID then
			unitLineage[unitID] = teamID
			SetBuildOptions(unitID, unitDefID, Spring.GetUnitTeam(unitID))
		end
	end
	
	for i = 1, #loadData.bonusObjectiveList do
		bonusObjectiveList[i] = loadData.bonusObjectiveList[i]
		local oldUnits = loadData.bonusObjectiveList[i].units
		if oldUnits then
			bonusObjectiveList[i].units = {}
			for oldUnitID, allyTeamID in pairs(oldUnits) do
				local unitID = GG.SaveLoad.GetNewUnitID(oldUnitID)
				if unitID then
					bonusObjectiveList[i].units[unitID] = allyTeamID
				end
			end
		end
	end
	
	-- Clear the commanders out of victoryAtLocation
	victoryAtLocation = {}
	initialUnitData = {}
	
	-- Put the units back in the objectives
	for oldUnitID, data in pairs(loadData.initialUnitData) do
		local unitID = GG.SaveLoad.GetNewUnitID(oldUnitID)
		if unitID then
			SetupInitialUnitParameters(unitID, data)
		end
	end
	
	-- restore victoryAtLocation units
	-- needed for any units that weren't created at start; e.g. Dantes on planet 21 (Vis Ragstrom)
	local units = Spring.GetAllUnits()
	for i=1,#units do
		local unitID = units[i]
		local finished = select(5, Spring.GetUnitHealth(unitID)) == 1
		if finished and not victoryAtLocation[unitID] then
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitTeam = Spring.GetUnitTeam(unitID)
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
	
	UpdateSaveReferences()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else --UNSYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MakeRealTable = Spring.Utilities.MakeRealTable

function gadget:Save(zip)
	if not GG.SaveLoad then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Galaxy campaign mission failed to access save/load API")
		return
	end
	GG.SaveLoad.WriteSaveData(zip, SAVE_FILE, MakeRealTable(SYNCED.missionGalaxySaveTable, "Campaign"))
end

local function MissionGameOver(cmd, missionWon)
	if (Script.LuaUI('MissionGameOver')) then
		Script.LuaUI.MissionGameOver(missionWon)
	end
end

local function AddMarker(cmd, markerID, x, z, text, color)
	if (Script.LuaUI('AddCustomMapMarker')) then
		Script.LuaUI.AddCustomMapMarker(markerID, x, z, text, color)
	end
end

local function RemoveMarker(cmd, markerID)
	if (Script.LuaUI('RemoveCustomMapMarker')) then
		Script.LuaUI.RemoveCustomMapMarker(markerID)
	end
end

function SendAIEvent(_, teamID, msg)
	local localPlayer = Spring.GetLocalPlayerID();
	-- Send message only to hosted native AI
	local aiid, ainame, aihost = Spring.GetAIInfo(teamID);
	if (aihost == localPlayer) then
		--Spring.Echo("Team:" .. tostring(teamID) .. " | SendAIEvent0 | " .. msg)
		Spring.SendSkirmishAIMessage(teamID, msg)
		--Spring.Echo("Team:" .. tostring(teamID) .. " | SendAIEvent1 | END")
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction("SendAIEvent", SendAIEvent)
	gadgetHandler:AddSyncAction("MissionGameOver", MissionGameOver)
	gadgetHandler:AddSyncAction("AddMarker", AddMarker)
	gadgetHandler:AddSyncAction("RemoveMarker", RemoveMarker)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("SendAIEvent")
	gadgetHandler:RemoveSyncAction("MissionGameOver")
	gadgetHandler:RemoveSyncAction("AddMarker")
	gadgetHandler:RemoveSyncAction("RemoveMarker")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end -- END UNSYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------