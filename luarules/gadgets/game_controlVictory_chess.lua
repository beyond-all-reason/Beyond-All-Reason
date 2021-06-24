if not gadgetHandler:IsSyncedCode() then
    return
end

local gadgetEnabled

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

local teamSpawnPositions = {}
local teamSpawnQueue = {}
local teamRespawnQueue = {}
local teamIsLandPlayer = {}
local resurrectedUnits = {}

-- {unitName, amount}

local starterLandUnitsList = {
    [1] = {"armflea", 5},
    [2] = {"armfav", 5},
    [3] = {"corfav", 5},
}

local starterSeaUnitsList = {
    [1] = {"armpt", 5},
    [2] = {"corpt", 5},
}

local landUnitsList = {
    [1] = { -- Early T1
        -- Bots
            -- Raider
        [1] = {"armpw", 5},
        [2] = {"corak", 5},
            -- Rezzers
        [3] = {"armrectr", 2},
        [4] = {"cornecro", 2},
    },
    [2] = { -- Late T1
        -- Bots
        [1] = {"armrock", 5},
        [2] = {"armham", 5},
        [3] = {"armwar", 5},
        [4] = {"corstorm", 5},
        [5] = {"corthud", 5},
    },
    [3] = { -- Early T2
        -- Bots
            -- Raider
        [1] = {"corpyro", 5},
        [2] = {"armfast", 5},
        [3] = {"armfido", 5},
        [4] = {"cormort", 5},
            -- Crawling Bombs
        [5] = {"armvader", 3},
        [6] = {"corroach", 3},

            -- Radar/Stealth Bots
        [7] = {"armaser", 1},
        [8] = {"armmark", 1},
        [9] = {"corspec", 1},
        [10] = {"corvoyr", 1},
    },
}

local seaUnitsList = {
    [1] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [2] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [3] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [4] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [5] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [6] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [7] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [8] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [9] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
    [10] = { -- placeholder
        [1] = {"armdecade", 4},
        [2] = {"coresupp", 4},
        [3] = {"armrecl", 2},
        [4] = {"correcl", 2},
    },
}

local maxPhases = #landUnitsList
local phaseTime = 9000 -- frames
local addUpFrequency = 1800
local spawnTimer = 5
local respawnTimer = 90
local phase
local canResurrect = {}

-- Functions to hide commanders
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.canResurrect then
        canResurrect[unitDefID] = true
    end
end

local function disableUnit(unitID)
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

local function introSetUp()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        local teamUnits = Spring.GetTeamUnits(teamID)
        --if (not spGetGaiaTeamID() == teamID) then
            for _, unitID in ipairs(teamUnits) do
                local x,y,z = Spring.GetUnitPosition(unitID)
                teamSpawnPositions[teamID] = {x, y, z}
                if teamSpawnPositions[teamID][2] > 0 then
                    teamIsLandPlayer[teamID] = true
                else
                    teamIsLandPlayer[teamID] = false
                end
                teamSpawnQueue[teamID] = {[1] = "dummyentry",}
                teamRespawnQueue[teamID] = {[1] = "dummyentry",}
                disableUnit(unitID)
            end
        --end
    end
    phase = 1
end

local function addInfiniteResources()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        Spring.SetTeamResource(teamID, "ms", 1000000)
        Spring.SetTeamResource(teamID, "es", 1000000)
        Spring.SetTeamResource(teamID, "m", 500000)
        Spring.SetTeamResource(teamID, "e", 500000)
    end
end

local function spawnUnitsFromQueue()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if teamSpawnQueue[teamID] then
            if teamSpawnQueue[teamID][2] then
                local x = teamSpawnPositions[teamID][1]+math.random(-32,32)
                local z = teamSpawnPositions[teamID][3]+math.random(-32,32)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(teamSpawnQueue[teamID][2], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(teamSpawnQueue[teamID], 2)
            end
        end
    end
end

local function respawnUnitsFromQueue()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if teamRespawnQueue[teamID] then
            if teamRespawnQueue[teamID][2] then
                local x = teamSpawnPositions[teamID][1]+math.random(-32,32)
                local z = teamSpawnPositions[teamID][3]+math.random(-32,32)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(teamRespawnQueue[teamID][2], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(teamRespawnQueue[teamID], 2)
            end
        end
    end
end

local function AddNewUnitsToQueue(starter)
	local landRandom, landUnit, landUnitCount
	local seaRandom, seaUnit, seaUnitCount

    if starter then
        landRandom = math.random(1,#starterLandUnitsList)
        landUnit = starterLandUnitsList[landRandom][1]
        landUnitCount = starterLandUnitsList[landRandom][2]

        seaRandom = math.random(1,#starterSeaUnitsList)
        seaUnit = starterSeaUnitsList[seaRandom][1]
        seaUnitCount = starterSeaUnitsList[seaRandom][2]
    else
        landRandom = math.random(1,#landUnitsList[phase])
        landUnit = landUnitsList[phase][landRandom][1]
        landUnitCount = landUnitsList[phase][landRandom][2]

        seaRandom = math.random(1,#seaUnitsList[phase])
        seaUnit = seaUnitsList[phase][seaRandom][1]
        seaUnitCount = seaUnitsList[phase][seaRandom][2]
    end
    
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if teamIsLandPlayer[teamID] then
            for j = 1,landUnitCount do
                if teamSpawnQueue[teamID] then
                    if teamSpawnQueue[teamID][2] then
                        teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = landUnit
                    else
                        teamSpawnQueue[teamID][2] = landUnit
                    end
                end
            end
        else
            for j = 1,seaUnitCount do
                if teamSpawnQueue[teamID] then
                    if teamSpawnQueue[teamID][2] then
                        teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = seaUnit
                    else
                        teamSpawnQueue[teamID][2] = seaUnit
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

local function respawnDeadUnit(unitName, unitTeam)
    if teamSpawnQueue[unitTeam] then
        if teamRespawnQueue[unitTeam][2] then
            teamRespawnQueue[unitTeam][#teamRespawnQueue[unitTeam]+1] = unitName
        else
            teamRespawnQueue[unitTeam][2] = unitName
        end
    end
end

function gadget:GameFrame(n)
    if n == 20 then
        introSetUp()
    end
    if n == 25 then
        AddNewUnitsToQueue(true)
    end
    if n%900 == 1 then
        addInfiniteResources()
    end
    if n > 25 and n%phaseTime == 1 then
        phase = phase + 1
        if phase > maxPhases then
            phase = maxPhases
        end
    end
    if n > 25 and n%spawnTimer == 1 then
        spawnUnitsFromQueue()
    end
    if n > 25 and n%respawnTimer == 1 then
        respawnUnitsFromQueue()
    end
    if n > 25 and n%addUpFrequency == 1 then
        AddNewUnitsToQueue(false)
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID and canResurrect[Spring.GetUnitDefID(builderID)] then
        resurrectedUnits[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if resurrectedUnits[unitID] then
        resurrectedUnits[unitID] = nil
    else
        local UnitName = UnitDefs[unitDefID].name
        respawnDeadUnit(UnitName, unitTeam)
    end
end
