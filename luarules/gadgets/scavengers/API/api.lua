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
spawnmultiplier = tonumber(Spring.GetModOptions().scavengers) or 1
scavTechDifficulty = Spring.GetModOptions().scavengerstech or "adaptive"
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
		ScavengerStartboxExists = true
	end
else
	_,_,_,_,_,GaiaAllyTeamID = Spring.GetTeamInfo(GaiaTeamID)
	ScavengerStartboxExists = false
end
teamcount = #Spring.GetTeamList() - 1
allyteamcount = #Spring.GetAllyTeamList() - 1

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
scavSpawnBeacon = {}
scavStockpiler = {}
scavNuke = {}
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

if Spring.GetModOptions() and Spring.GetModOptions().maxunits then
	scavMaxUnits = tonumber(Spring.GetModOptions().maxunits)
end
if GaiaTeamID == Spring.GetGaiaTeamID() then
	scavMaxUnits = 10000
end
TierSpawnChances = {
	T0 = 100,
	T1 = 0,
	T2 = 0,
	T3 = 0,
	T4 = 0,
}

-- check for solo play
if teamcount <= 0 then
		teamcount = 1
end
	if allyteamcount <= 0 then
		allyteamcount = 1
end

-- Check height diffrences
function posCheck(posx, posy, posz, posradius)
	-- if true then can spawn
	local testpos1 = Spring.GetGroundHeight((posx + posradius), (posz + posradius) )
	local testpos2 = Spring.GetGroundHeight((posx + posradius), (posz - posradius) )
	local testpos3 = Spring.GetGroundHeight((posx - posradius), (posz + posradius) )
	local testpos4 = Spring.GetGroundHeight((posx - posradius), (posz - posradius) )
	local testpos5 = Spring.GetGroundHeight((posx + posradius), posz )
	local testpos6 = Spring.GetGroundHeight(posx, (posz + posradius) )
	local testpos7 = Spring.GetGroundHeight((posx - posradius), posz )
	local testpos8 = Spring.GetGroundHeight(posx, (posz - posradius) )
	local deathwater = Game.waterDamage
	local heighttollerance = scavconfig.other.heighttolerance
	if scavconfig.other.noheightchecksforwater and (not deathwater or deathwater == 0) and posy <= 0 then
		return true
	elseif deathwater > 0 and posy <= 0 then
		return false
	elseif testpos1 < posy - heighttollerance or testpos1 > posy + heighttollerance then
		return false
	elseif testpos2 < posy - heighttollerance or testpos2 > posy + heighttollerance then
		return false
	elseif testpos3 < posy - heighttollerance or testpos3 > posy + heighttollerance then
		return false
	elseif testpos4 < posy - heighttollerance or testpos4 > posy + heighttollerance then
		return false
	elseif testpos5 < posy - heighttollerance or testpos5 > posy + heighttollerance then
		return false
	elseif testpos6 < posy - heighttollerance or testpos6 > posy + heighttollerance then
		return false
	elseif testpos7 < posy - heighttollerance or testpos7 > posy + heighttollerance then
		return false
	elseif testpos8 < posy - heighttollerance or testpos8 > posy + heighttollerance then
		return false
	else
		return true
	end
end

-- Check if area is occupied
function posOccupied(posx, posy, posz, posradius)
	-- if true then can spawn
	local unitcount = #Spring.GetUnitsInRectangle(posx-posradius, posz-posradius, posx+posradius, posz+posradius)
	if unitcount > 0 then
		return false
	else
		return true
	end
end

-- Check if area is visible for any player
function posLosCheck(posx, posy, posz, posradius)
	-- if true then can spawn
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInRadar(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return false
			end
		end
	end
	return true
end

function posFriendlyCheckOnlyLos(posx, posy, posz, allyTeamID)
	return Spring.IsPosInLos(posx, posy, posz, allyTeamID)
end

function posLosCheckNoRadar(posx, posy, posz, posradius)
	-- if true then can spawn
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInAirLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
				return false
			end
		end
	end
	return true
end

function posLosCheckOnlyLOS(posx, posy, posz, posradius)
	-- if true then can spawn
	for _,allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= GaiaAllyTeamID then
			if Spring.IsPosInLos(posx, posy, posz, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx + posradius, posy, posz - posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz + posradius, allyTeamID) == true or
			Spring.IsPosInLos(posx - posradius, posy, posz - posradius, allyTeamID) == true then
			return false
			end
		end
	end
	return true
end

function posStartboxCheck(posx, posy, posz, posradius)
	if ScavengerStartboxExists and posx <= ScavengerStartboxXMax and posx >= ScavengerStartboxXMin and posz >= ScavengerStartboxZMin and posz <= ScavengerStartboxZMax then
		return false
	else
		return true
	end
end

function posMapsizeCheck(posx, posy, posz, posradius)
	if posx + posradius >= mapsizeX or posx - posradius <= 0 or posz - posradius <= 0 or posz + posradius >= mapsizeZ then
		return false
	else
		return true
	end
end


function teamsCheck()

	bestTeamScore = 0
	bestTeam = 0
	if scavTechDifficulty == "adaptive" or globalScore == nil then
		globalScore = 0
	end
	nonFinalGlobalScore = 0
	scoreTeamCount = 0
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
	local timeScore = Spring.GetGameSeconds()*scavconfig.scoreConfig.scorePerSecond
	if scavTechDifficulty == "adaptive" then
		globalScore = math.ceil((nonFinalGlobalScore/scoreTeamCount) + killedscavengers + timeScore)
	elseif scavTechDifficulty == "easy" then
		globalScore = math.ceil(globalScore + 10*scavconfig.difficulty.easy*(Spring.GetGameSeconds()/60))
	elseif scavTechDifficulty == "medium" then
		globalScore = math.ceil(globalScore + 10*scavconfig.difficulty.medium*(Spring.GetGameSeconds()/60))
	elseif scavTechDifficulty == "hard" then
		globalScore = math.ceil(globalScore + 10*scavconfig.difficulty.hard*(Spring.GetGameSeconds()/60))
	elseif scavTechDifficulty == "brutal" then
		globalScore = math.ceil(globalScore + 10*scavconfig.difficulty.brutal*(Spring.GetGameSeconds()/60))
	end
	nonFinalGlobalScore = nil
	scoreTeamCount = nil
end