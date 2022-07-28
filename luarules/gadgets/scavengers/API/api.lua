Spring.Echo("[Scavengers] API initialized")

math_random = math.random
-- variables
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
ScavengerTeamID = Spring.GetGaiaTeamID()
ScavengerStartboxXMin = mapsizeX + 1
ScavengerStartboxZMin = mapsizeZ + 1
ScavengerStartboxXMax = mapsizeX + 1
ScavengerStartboxZMax = mapsizeZ + 1
ScavengerStartboxExists = false

-- local scavTechDifficulty = Spring.GetModOptions().scavengerstech
if scavengersAIEnabled then
	if spawnmultiplier == 0 then
		spawnmultiplier = 0.5
	end
	ScavengerTeamID = scavengerAITeamID
	_,_,_,_,_,ScavengerAllyTeamID = Spring.GetTeamInfo(ScavengerTeamID)
	ScavengerStartboxXMin, ScavengerStartboxZMin, ScavengerStartboxXMax, ScavengerStartboxZMax = Spring.GetAllyTeamStartBox(ScavengerAllyTeamID)
	if ScavengerStartboxXMin == 0 and ScavengerStartboxZMin == 0 and ScavengerStartboxXMax == mapsizeX and ScavengerStartboxZMax == mapsizeZ then
		ScavengerStartboxExists = false
	else
		ScavengerStartboxExists = true
		ScavSafeAreaMinX = ScavengerStartboxXMin
		ScavSafeAreaMaxX = ScavengerStartboxXMax
		ScavSafeAreaMinZ = ScavengerStartboxZMin
		ScavSafeAreaMaxZ = ScavengerStartboxZMax
		ScavSafeAreaSize = math.ceil(((ScavengerStartboxXMax - ScavengerStartboxXMin) + (ScavengerStartboxZMax - ScavengerStartboxZMin))*0.175)
		ScavSafeAreaDamage = 5
	end
else
	_,_,_,_,_,ScavengerAllyTeamID = Spring.GetTeamInfo(ScavengerTeamID)
	ScavengerStartboxExists = false
end

BossWaveStarted = false
selfdx = {}
selfdy = {}
selfdz = {}
oldselfdx = {}
oldselfdy = {}
oldselfdz = {}
scavNoSelfD = {}
UDC = Spring.GetTeamUnitDefCount
UDN = UnitDefNames
scavStructure = {}
scavConstructor = {}
scavAssistant = {}
scavResurrector = {}
scavFactory = {}
scavCollector = {}
scavCapturer = {}
scavReclaimer = {}
scavSpawnBeacon = {}
scavStockpiler = {}
scavNuke = {}
scavConverted = {}
UnitSuffixLenght = {}
numOfSpawnBeacons = 0
numOfSpawnBeaconsTeams = {}
scavMaxUnits = 2000
scavengerSoundPath = "Sounds/voice/scavengers/"
killedscavengers = 0
QueuedSpawns = {}
QueuedSpawnsFrames = {}
QueuedDestroys = {}
QueuedDestroysFrames = {}
ConstructorNumberOfRetries = {}
CaptureProgressForBeacons = {}
AliveEnemyCommanders = {}
AliveEnemyCommandersCount = 0
FinalBossKilled = false
bosshealthmultiplier = 5--teamcount*spawnmultiplier
ActiveReinforcementUnits = {}
scavteamhasplayers = false
BaseCleanupQueue = {}
endOfGracePeriodScore = 0

--spawningStartFrame = (math.ceil( math.ceil(mapsizeX + mapsizeZ) / 750 ) + 30) * 5
spawningStartFrame = (math.ceil( math.ceil(mapsizeX*mapsizeZ) / 1000000 )) * 10
scavMaxUnits = Spring.GetModOptions().maxunits

if ScavengerTeamID == Spring.GetGaiaTeamID() then
	scavMaxUnits = 10000
end
TierSpawnChances = {
	T0 = 100,
	T1 = 0,
	T2 = 0,
	T3 = 0,
	T4 = 0,
	BPMult = 1,
}

-- check for solo play
if teamcount <= 0 then
		teamcount = 1
end
	if allyteamcount <= 0 then
		allyteamcount = 1
end

function UpdateTierChances(n)
	-- Must be 100 in total
	if globalScore > scavconfig.timers.Endless9 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 100
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 100
	elseif globalScore > scavconfig.timers.Endless8 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 5
		TierSpawnChances.T4 = 95
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 50
	elseif globalScore > scavconfig.timers.Endless7 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 10
		TierSpawnChances.T4 = 90
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 30
	elseif globalScore > scavconfig.timers.Endless6 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 20
		TierSpawnChances.T4 = 80
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 20
	elseif globalScore > scavconfig.timers.Endless5 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 30
		TierSpawnChances.T4 = 70
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 18
	elseif globalScore > scavconfig.timers.Endless4 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 35
		TierSpawnChances.T4 = 65
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 16
	elseif globalScore > scavconfig.timers.Endless3 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 60
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 14
	elseif globalScore > scavconfig.timers.Endless2 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 45
		TierSpawnChances.T4 = 55
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 12
	elseif globalScore > scavconfig.timers.Endless1 then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 50
		TierSpawnChances.Message = "Current tier: Endless"
		TierSpawnChances.BPMult = 10
	elseif globalScore > scavconfig.timers.T4top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 50
		TierSpawnChances.Message = "Current tier: T4 Top"
		TierSpawnChances.BPMult = 8
	elseif globalScore > scavconfig.timers.T4high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 40
		TierSpawnChances.Message = "Current tier: T4 High"
		TierSpawnChances.BPMult = 6
	elseif globalScore > scavconfig.timers.T4med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 30
		TierSpawnChances.Message = "Current tier: T4 Medium"
		TierSpawnChances.BPMult = 5
	elseif globalScore > scavconfig.timers.T4low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 30
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 20
		TierSpawnChances.Message = "Current tier: T4 Low"
		TierSpawnChances.BPMult = 4.5
	elseif globalScore > scavconfig.timers.T4start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 10
		TierSpawnChances.Message = "Current tier: T4 Start"
		TierSpawnChances.BPMult = 4
	elseif globalScore > scavconfig.timers.T3top then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 50
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Top"
		TierSpawnChances.BPMult = 3.4
	elseif globalScore > scavconfig.timers.T3high then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 40
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 High"
		TierSpawnChances.BPMult = 3.2
	elseif globalScore > scavconfig.timers.T3med then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 20
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 30
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Medium"
		TierSpawnChances.BPMult = 2.8
	elseif globalScore > scavconfig.timers.T3low then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 30
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 20
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Low"
		TierSpawnChances.BPMult = 2.4
	elseif globalScore > scavconfig.timers.T3start then
		TierSpawnChances.T0 = 0
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 10
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T3 Start"
		TierSpawnChances.BPMult = 2
	elseif globalScore > scavconfig.timers.T2top then
		TierSpawnChances.T0 = 10
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 50
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Top"
		TierSpawnChances.BPMult = 1.8
	elseif globalScore > scavconfig.timers.T2high then
		TierSpawnChances.T0 = 10
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 40
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 High"
		TierSpawnChances.BPMult = 1.6
	elseif globalScore > scavconfig.timers.T2med then
		TierSpawnChances.T0 = 20
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 30
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Medium"
		TierSpawnChances.BPMult = 1.4
	elseif globalScore > scavconfig.timers.T2low then
		TierSpawnChances.T0 = 30
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 20
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Low"
		TierSpawnChances.BPMult = 1.2
	elseif globalScore > scavconfig.timers.T2start then
		TierSpawnChances.T0 = 40
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 10
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T2 Start"
		TierSpawnChances.BPMult = 1.1
	elseif globalScore > scavconfig.timers.T1top then
		TierSpawnChances.T0 = 50
		TierSpawnChances.T1 = 50
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Top"
		TierSpawnChances.BPMult = 1
	elseif globalScore > scavconfig.timers.T1high then
		TierSpawnChances.T0 = 60
		TierSpawnChances.T1 = 40
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 High"
		TierSpawnChances.BPMult = 1
	elseif globalScore > scavconfig.timers.T1med then
		TierSpawnChances.T0 = 70
		TierSpawnChances.T1 = 30
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Medium"
		TierSpawnChances.BPMult = 1
	elseif globalScore > scavconfig.timers.T1low then
		TierSpawnChances.T0 = 80
		TierSpawnChances.T1 = 20
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Low"
		TierSpawnChances.BPMult = 1
	elseif globalScore > scavconfig.timers.T1start then
		TierSpawnChances.T0 = 90
		TierSpawnChances.T1 = 10
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T1 Start"
		TierSpawnChances.BPMult = 1
	else
		TierSpawnChances.T0 = 100
		TierSpawnChances.T1 = 0
		TierSpawnChances.T2 = 0
		TierSpawnChances.T3 = 0
		TierSpawnChances.T4 = 0
		TierSpawnChances.Message = "Current tier: T0"
		TierSpawnChances.BPMult = 0.5
	end

	if scavconfig.maxTechLevel < 4 then
		TierSpawnChances.T3 = TierSpawnChances.T3 + TierSpawnChances.T4
		TierSpawnChances.T4 = 0
		if globalScore > scavconfig.timers.T3top then
			TierSpawnChances.Message = "Current tier: T3 Top (Capped)"
		end
	end
	if scavconfig.maxTechLevel < 3 then
		TierSpawnChances.T2 = TierSpawnChances.T2 + TierSpawnChances.T3
		TierSpawnChances.T3 = 0
		if globalScore > scavconfig.timers.T2top then
			TierSpawnChances.Message = "Current tier: T2 Top (Capped)"
		end
	end
	if scavconfig.maxTechLevel < 2 then
		TierSpawnChances.T1 = TierSpawnChances.T1 + TierSpawnChances.T2
		TierSpawnChances.T2 = 0
		if globalScore > scavconfig.timers.T1top then
			TierSpawnChances.Message = "Current tier: T1 Top (Capped)"
		end
	end

end

function teamsCheck()
	bestTeamScore = 0
	bestTeam = 0
	globalScore = 0
	local nonFinalGlobalScore = 0
	local scoreTeamCount = 0
	scorePerTeam = {}
	for _,teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= ScavengerTeamID and teamID ~= Spring.GetGaiaTeamID() then
			if not numOfSpawnBeaconsTeams[teamID] then
				numOfSpawnBeaconsTeams[teamID] = 0
			end
			local i = teamID
			local _,_,teamisDead = Spring.GetTeamInfo(i)
			local unitCount = Spring.GetTeamUnitCount(i)
			if (not teamisDead) or unitCount > 0 then
				scoreTeamCount = scoreTeamCount + 1
				local _,_,_,mi = Spring.GetTeamResources(i, "metal")
				local _,_,_,ei = Spring.GetTeamResources(i, "energy")
				local resourceScoreM = mi*scavconfig.scoreConfig.scorePerMetal
				local resourceScoreE = ei*scavconfig.scoreConfig.scorePerEnergy
				local unitScore = unitCount*scavconfig.scoreConfig.scorePerOwnedUnit
				local finalScore = resourceScoreM + resourceScoreE + unitScore
				nonFinalGlobalScore = nonFinalGlobalScore + finalScore

				scorePerTeam[teamID] = finalScore

				if finalScore > bestTeamScore then
					bestTeamScore = finalScore
					bestTeam = i
				end
			end
		end
	end
	if not killedscavengers then
		killedscavengers = 0
	end
	if scoreTeamCount == 1 then
		scoreTeamCount = 2
	end
	local timeScore = Spring.GetGameSeconds()*scavconfig.scoreConfig.scorePerSecond
	globalScore = math.max(math.ceil(((nonFinalGlobalScore/scoreTeamCount) + killedscavengers + timeScore) - endOfGracePeriodScore), 0)
	nonFinalGlobalScore = nil
	scoreTeamCount = nil
end

function buffConstructorBuildSpeed(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if UnitDefs[unitDefID].buildSpeed then
		local a = (UnitDefs[unitDefID].buildSpeed*TierSpawnChances.BPMult)*spawnmultiplier
		--Spring.Echo(a)
		Spring.SetUnitBuildSpeed(unitID, a, a, a, a, a, a)
	end
end

local spSetGameRulesParam = Spring.SetGameRulesParam
scavStatsAvailable = 0
scavStatsScavCommanders = 0
scavStatsScavSpawners = 0
scavStatsScavUnits = 0
scavStatsScavUnitsKilled = 0
scavStatsGlobalScore = 0
scavStatsTechLevel = "Null"
scavStatsTechPercentage = 0
scavStatsDifficulty = scavconfig.difficultyName
scavStatsGracePeriod = 999
scavStatsGracePeriodLeft = 999

spSetGameRulesParam("scavStatsAvailable", scavStatsAvailable)

function collectScavStats()
	if scavStatsAvailable == 0 then
		scavStatsAvailable = 1
		spSetGameRulesParam("scavStatsAvailable", scavStatsAvailable)
	end

	-- scavStatsScavCommanders			done
	spSetGameRulesParam("scavStatsScavCommanders", scavStatsScavCommanders)

	-- scavStatsScavSpawners			done
	spSetGameRulesParam("scavStatsScavSpawners", scavStatsScavSpawners)

	-- scavStatsScavUnits				done
	scavStatsScavUnits = Spring.GetTeamUnitCount(ScavengerTeamID)
	spSetGameRulesParam("scavStatsScavUnits", scavStatsScavUnits)

	-- scavStatsScavUnitsKilled			deprecated
	spSetGameRulesParam("scavStatsScavUnitsKilled", scavStatsScavUnitsKilled)

	-- scavStatsGlobalScore				done
	local scavStatsGlobalScore = globalScore
	spSetGameRulesParam("scavStatsGlobalScore", scavStatsGlobalScore)

	-- scavStatsTechLevel				done
	local scavStatsTechLevel = string.gsub(TierSpawnChances.Message, "Current tier: ","")
	spSetGameRulesParam("scavStatsTechLevel", scavStatsTechLevel)

	-- scavStatsTechPercentage 			done
	local techPercentage = math.ceil((globalScore/scavconfig.timers.BossFight)*100)
	if techPercentage > 100 then
		scavStatsTechPercentage = 100
	else
		scavStatsTechPercentage = techPercentage
	end
	spSetGameRulesParam("scavStatsTechPercentage", scavStatsTechPercentage)

	-- scavGracePeriod
	local scavStatsGracePeriod = math.floor(scavconfig.gracePeriod/30)
	local scavStatsGracePeriodLeft = math.floor((scavconfig.gracePeriod/30) - Spring.GetGameSeconds())
	spSetGameRulesParam("scavStatsGracePeriod", scavStatsGracePeriod)
	spSetGameRulesParam("scavStatsGracePeriodLeft", scavStatsGracePeriodLeft)


	-- done
	if BossWaveTimeLeft then
		spSetGameRulesParam("scavStatsBossFightCountdownStarted", 1)
		spSetGameRulesParam("scavStatsBossFightCountdown", BossWaveTimeLeft)
	else
		spSetGameRulesParam("scavStatsBossFightCountdownStarted", 0)
		spSetGameRulesParam("scavStatsBossFightCountdown", 0)
	end

	-- done
	if FinalBossUnitID then
		local scavStatsBossHealth, scavStatsBossMaxHealth = Spring.GetUnitHealth(FinalBossUnitID)
		spSetGameRulesParam("scavStatsBossSpawned", 1)
		spSetGameRulesParam("scavStatsBossMaxHealth", scavStatsBossMaxHealth)
		spSetGameRulesParam("scavStatsBossHealth", scavStatsBossHealth)
	else
		spSetGameRulesParam("scavStatsBossSpawned", 0)
		spSetGameRulesParam("scavStatsBossMaxHealth", 0)
		spSetGameRulesParam("scavStatsBossHealth", 0)
	end

	spSetGameRulesParam("scavStatsDifficulty", scavStatsDifficulty)
end

