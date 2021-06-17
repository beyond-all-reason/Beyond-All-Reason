if not gadgetHandler:IsSyncedCode() then
    return
end

if Spring.GetModOptions and (Spring.GetModOptions().scoremode or "disabled") ~= "disabled" then
    gadgetEnabled = true
else
    gadgetEnabled = false
end

local chickensEnabled = false
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "Chicken: Very Easy" or
			luaAI == "Chicken: Easy" or
			luaAI == "Chicken: Normal" or
			luaAI == "Chicken: Hard" or
			luaAI == "Chicken: Very Hard" or
			luaAI == "Chicken: Epic!" or
			luaAI == "Chicken: Custom" or
			luaAI == "Chicken: Survival" or
			luaAI == "ScavengersAI" then
			chickensEnabled = true
		end
	end
end

if chickensEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	gadgetEnabled = false
end

function gadget:GetInfo()
    return {
      name      = "Control Victory Chess Mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = gadgetEnabled,
    }
end


local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetAllyTeamList= Spring.GetAllyTeamList
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID

TeamSpawnPositions = {}
TeamSpawnQueue = {}
TeamRespawnQueue = {}
TeamIsLandPlayer = {}
ResurrectedUnits = {}

-- {unitName, amount}

StarterLandUnitsList = {
    [1] = {"armflea", 5},
    [2] = {"armfav", 5},
    [3] = {"corfav", 5},
}

StarterSeaUnitsList = {
    [1] = {"armpt", 5},
    [2] = {"corpt", 5},
}

LandUnitsList = {
    [1] = {
        [1] = {"armpw", 2},
        [2] = {"corak", 2},
        [3] = {"armrectr", 1}
        [4] = {"cornecro", 1}
    },
}

SeaUnitsList = {
    [1] = {
        [1] = {"armdecade", 2},
        [2] = {"coresupp", 2},
        [3] = {"armrecl", 1},
        [4] = {"correcl", 1},
    },
}

local maxPhases = #LandUnitsList
local phaseTime = 9000 -- frames
local addUpFrequency = 1800
local spawnTimer = 5
local respawnTimer = 150











-- Functions to hide commanders

local canResurrect = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.canResurrect then
        canResurrect[unitDefID] = true
    end
end

local function DisableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
    Spring.MoveCtrl.SetPosition(unitID, Game.mapSizeX+1900, 2000, Game.mapSizeZ+1900)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitCloak(unitID, true)
	--Spring.SetUnitHealth(unitID, {paralyze=99999999})
	Spring.SetUnitMaxHealth(unitID, 10000000)
	Spring.SetUnitHealth(unitID, 10000000)
	Spring.SetUnitNoDraw(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
end

local function IntroSetUp()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        local teamUnits = Spring.GetTeamUnits(teamID)
        --if (not spGetGaiaTeamID() == teamID) then
            for _, unitID in ipairs(teamUnits) do
                local x,y,z = Spring.GetUnitPosition(unitID)
                TeamSpawnPositions[teamID] = {x, y, z}
                if TeamSpawnPositions[teamID][2] > 0 then
                    TeamIsLandPlayer[teamID] = true
                else
                    TeamIsLandPlayer[teamID] = false
                end
                TeamSpawnQueue[teamID] = {[1] = "dummyentry",}
                TeamRespawnQueue[teamID] = {[1] = "dummyentry",}
                DisableUnit(unitID)
            end
        --end
    end
    phase = 1
end

local function SpawnUnitsFromQueue()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if TeamSpawnQueue[teamID] then
            if TeamSpawnQueue[teamID][2] then
                local x = TeamSpawnPositions[teamID][1]+math.random(-32,32)
                local z = TeamSpawnPositions[teamID][3]+math.random(-32,32)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(TeamSpawnQueue[teamID][2], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(TeamSpawnQueue[teamID], 2)
            end
        end
    end
end

local function RespawnUnitsFromQueue()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if TeamRespawnQueue[teamID] then
            if TeamRespawnQueue[teamID][2] then
                local x = TeamSpawnPositions[teamID][1]+math.random(-32,32)
                local z = TeamSpawnPositions[teamID][3]+math.random(-32,32)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(TeamRespawnQueue[teamID][2], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(TeamRespawnQueue[teamID], 2)
            end
        end
    end
end

local function AddNewUnitsToQueue(starter)
    if starter then
        landUnit = StarterLandUnitsList[math.random(1,#StarterLandUnitsList)][1]
        landUnitCount = StarterLandUnitsList[math.random(1,#StarterLandUnitsList)][2]
        seaUnit = StarterSeaUnitsList[math.random(1,#StarterSeaUnitsList)][1]
        seaUnitCount = StarterSeaUnitsList[math.random(1,#StarterSeaUnitsList)][2]
    else
        landUnit = LandUnitsList[phase][math.random(1,#LandUnitsList[phase])][1]
        landUnitCount = LandUnitsList[phase][math.random(1,#LandUnitsList[phase])][2]
        seaUnit = SeaUnitsList[phase][math.random(1,#SeaUnitsList[phase])][1]
        seaUnitCount = SeaUnitsList[phase][math.random(1,#SeaUnitsList[phase])][2]
    end
    
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if TeamIsLandPlayer[teamID] then
            for j = 1,landUnitCount do
                if TeamSpawnQueue[teamID] then
                    if TeamSpawnQueue[teamID][2] then
                        TeamSpawnQueue[teamID][#TeamSpawnQueue[teamID]+1] = landUnit
                    else
                        TeamSpawnQueue[teamID][2] = landUnit
                    end
                end
            end
        else
            for j = 1,seaUnitCount do
                if TeamSpawnQueue[teamID] then
                    if TeamSpawnQueue[teamID][2] then
                        TeamSpawnQueue[teamID][#TeamSpawnQueue[teamID]+1] = seaUnit
                    else
                        TeamSpawnQueue[teamID][2] = seaUnit
                    end
                end
            end
        end
    end
    landUnit = nil
    landUnitCount = nil
    seaUnit = nil
    seaUnitCount = nil
end

local function RespawnDeadUnit(unitName, unitTeam)
    if TeamSpawnQueue[unitTeam] then
        if TeamRespawnQueue[unitTeam][2] then
            TeamRespawnQueue[unitTeam][#TeamRespawnQueue[unitTeam]+1] = unitName
        else
            TeamRespawnQueue[unitTeam][2] = unitName
        end
    end
end

function gadget:GameFrame(n)
    if n == 20 then
        IntroSetUp()
    end
    if n == 25 then
        AddNewUnitsToQueue(true)
    end
    if n > 25 and n%phaseTime == 1 then
        phase = phase + 1
        if phase > maxPhases then
            phase = maxPhases
        end
    end
    if n > 25 and n%spawnTimer == 1 then
        SpawnUnitsFromQueue()
    end
    if n > 25 and n%respawnTimer == 1 then
        RespawnUnitsFromQueue()
    end
    if n > 25 and n%addUpFrequency == 1 then
        AddNewUnitsToQueue(false)
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID and canResurrect[Spring.GetUnitDefID(builderID)] then
        ResurrectedUnits[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if not ResurrectedUnits[unitID] then
        local UnitName = UnitDefs[unitDefID].name
        RespawnDeadUnit(UnitName, unitTeam)
    else
        ResurrectedUnits[unitID] = nil
    end
end
