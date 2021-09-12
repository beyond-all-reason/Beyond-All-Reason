Spring.Echo("[Scavengers] API initialized")

math_random = math.random
-- variables
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
GaiaTeamID = Spring.GetGaiaTeamID()
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
	GaiaTeamID = scavengerAITeamID
	_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
	ScavengerStartboxXMin, ScavengerStartboxZMin, ScavengerStartboxXMax, ScavengerStartboxZMax = Spring.GetAllyTeamStartBox(GaiaAllyTeamID)
	if ScavengerStartboxXMin == 0 and ScavengerStartboxZMin == 0 and ScavengerStartboxXMax == mapsizeX and ScavengerStartboxZMax == mapsizeZ then
		ScavengerStartboxExists = false
	else
		--ScavengerStartboxExists = true
	end
else
	_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
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
ConstructorNumberOfRetries = {}
CaptureProgressForBeacons = {}
AliveEnemyCommanders = {}
AliveEnemyCommandersCount = 0
FinalBossKilled = false
bosshealthmultiplier = 5--teamcount*spawnmultiplier
ActiveReinforcementUnits = {}
scavteamhasplayers = false
BaseCleanupQueue = {}

spawningStartFrame = (math.ceil( math.ceil(mapsizeX + mapsizeZ) / 750 ) + 30) * 10
scavMaxUnits = Spring.GetModOptions().MaxUnits

if GaiaTeamID == Spring.GetGaiaTeamID() then
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


function teamsCheck()
	bestTeamScore = 0
	bestTeam = 0
	globalScore = 0
	local previousGlobalScore = globalScore
	local nonFinalGlobalScore = 0
	local scoreTeamCount = 0
	scorePerTeam = {}
	for _,teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= GaiaTeamID and teamID ~= Spring.GetGaiaTeamID() then
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
	globalScore = math.ceil((nonFinalGlobalScore/scoreTeamCount) + killedscavengers + timeScore)
	if globalScore < previousGlobalScore then
		globalScore = previousGlobalScore
	end
	nonFinalGlobalScore = nil
	scoreTeamCount = nil
end

function buffConstructorBuildSpeed(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if UnitDefs[unitDefID].buildSpeed then
		local a = UnitDefs[unitDefID].buildSpeed*TierSpawnChances.BPMult
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
scavStatsDifficulty = "Null"

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
	spSetGameRulesParam("scavStatsScavUnits", scavStatsScavUnits)

	-- scavStatsScavUnitsKilled			done
	spSetGameRulesParam("scavStatsScavUnitsKilled", scavStatsScavUnitsKilled)

	-- scavStatsGlobalScore				done
	local scavStatsGlobalScore = globalScore
	spSetGameRulesParam("scavStatsGlobalScore", scavStatsGlobalScore)

	-- scavStatsTechLevel				done
	local scavStatsTechLevel = TierSpawnChances.Message
	spSetGameRulesParam("scavStatsTechLevel", scavStatsTechLevel)

	-- scavStatsTechPercentage 			done
	local techPercentage = math.ceil((globalScore/scavconfig.timers.Endless)*100)
	if techPercentage > 100 then
		scavStatsTechPercentage = 100
	else
		scavStatsTechPercentage = techPercentage
	end
	spSetGameRulesParam("scavStatsTechPercentage", scavStatsTechPercentage)


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
		local scavStatsBossMaxHealth = unitSpawnerModuleConfig.FinalBossHealth*teamcount*spawnmultiplier
		local scavStatsBossHealth = Spring.GetUnitHealth(FinalBossUnitID)
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
