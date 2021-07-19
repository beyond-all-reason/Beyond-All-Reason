if not gadgetHandler:IsSyncedCode() then
    return
end

local gadgetEnabled

if Spring.GetModOptions and (Spring.GetModOptions().scoremode or "disabled") ~= "disabled" and (Spring.GetModOptions().scoremode_chess or "enabled") ~= "disabled" then
    gadgetEnabled = true
else
    gadgetEnabled = false
end

ChessModeUnbalancedModoption = Spring.GetModOptions().scoremode_chess_unbalanced or "enabled"
ChessModePhaseTimeModoption = tonumber(Spring.GetModOptions().scoremode_chess_adduptime) or 4
ChessModeSpawnPerPhaseModoption = tonumber(Spring.GetModOptions().scoremode_chess_spawnsperphase) or 1

local pveEnabled = Spring.Utilities.Gametype.IsPvE()

if pveEnabled then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
	gadgetEnabled = false
end

function gadget:GetInfo()
    return {
      name      = "Control Victory Chess Mode",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
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

local function pickRandomUnit(list, quantity)
    if #list > 1 then
        r = math.random(1,#list)
    else
        r = 1
    end
    pickedTable = {}
    for i = 1,quantity do
        table.insert(pickedTable, list[r])
    end
    r = nil
    return pickedTable
end


local starterLandUnitsList = {
    [1] = {
        [1] = { 
            table = {
                "armflea", 
                "armfav", 
                "corfav",
            },              
            quantity = 5,
        },
        [2] = { 
            table = {
                "armjeth", 
                "corcrash", 
                "armsam", 
                "cormist", 
                "armah", 
                "corah",
            },              
            quantity = 2,
        },
        [3] = { 
            table = {
                "armpeep", 
                "corfink",
            },                      
            quantity = 1,
        },
    },
}
    
local landUnitsList = {
    -- PHASE 1 -- Early T1
    [1] = {
        [1] = {    
            table = {
                "armpw", 
                "corak", 
                "armflash", 
                "corgator", 
                "armsh", 
                "corsh",
            },                           
            quantity = 5,
        },
    },

    -- PHASE 2 -- Late T1
    [2] = {
        [1] = {    
            table = {
                "armrock", 
                "corstorm", 
                "armham", 
                "corthud", 
                "armwar", 
                "corkark", 
                "corwolv", 
                "armart", 
                "corgarp", 
                "armpincer", 
                "corlevlr", 
                "armjanus", 
                "corraid", 
                "armstump", 
                "armmh", 
                "cormh", 
                "armanac", 
                "corsnap",
            },                           
            quantity = 5,
        },
        [2] = { 
            table = {
                "armjeth", 
                "corcrash", 
                "armsam", 
                "cormist", 
                "armah", 
                "corah",
            },              
            quantity = 2,
        },
    },

    -- PHASE 3 -- Air T1
    [3] = {
        [1] = { 
            table = {
                "armjeth", 
                "corcrash", 
                "armsam", 
                "cormist", 
                "armah", 
                "corah",
            },              
            quantity = 2,
        },
        [2] = { 
            table = {
                "armfig", 
                "corveng",
            }, 
            quantity = 2,
        },
        [3] = { 
            table = {
                "armthund", 
                "corshad", 
                "armkam", 
                "corbw",
            }, 
            quantity = 5,
        },
    },

    -- PHASE 4 -- Early T2
    [4] = {
        [1] = {    
            table = {
                "armfast", 
                "corpyro", 
                "armfido", 
                "cormort", 
                "armlatnk", 
            },                           
            quantity = 5,
        },
    },

    -- PHASE 5 -- Late T2
    [5] = {
        [1] = {    
            table = {
                "cortermite", 
                "armamph", 
                "coramph", 
                "armzeus", 
                "corcan", 
                "armsptk", 
                "armsnipe", 
                "corhrk", 
                "armmav", 
                "armfboy", 
                "corsumo",
                "armmart", 
                "cormart", 
                "armcroc", 
                "corseal", 
                "armmerl", 
                "corvroc", 
                "armbull",
                "correap",
                "armmanni",
                "cortrem",
                "corban",
                "corgatreap",
            },                           
            quantity = 5,
        },
        [2] = { 
            table = {
                "armaak", 
                "coraak", 
                "armyork", 
                "corsent", 
            },              
            quantity = 2,
        },
        [3] = { 
            table = {
                "armvader", 
                "corroach", 
                "armmark", 
                "corvoyr",
                "armspy", 
                "corspy",
                "armspid",
                "armseer",
                "corvrad",      
            },              
            quantity = 3,
        },
    },

    -- PHASE 6 -- Air T2
    [6] = {
        [1] = { 
            table = {
                "armaak", 
                "coraak", 
                "armyork", 
                "corsent", 
            },              
            quantity = 2,
        },
        [2] = { 
            table = {
                "armhawk", 
                "corvamp",
            }, 
            quantity = 2,
        },
        [3] = { 
            table = {
                "armpnix", 
                "corhurc", 
                "armstil",
                "armbrawl", 
                "corape", 
            }, 
            quantity = 5,
        },
    },

    -- PHASE 7 -- Endgame
    [7] = {
        [1] = {
            table = {
                "corkorg",
                "corjugg",
                "armbanth",
                "armthor",
                "armpwt4",
                "armrattet4",
                "armvadert4",
                "cordemont4",
                "corkarganetht4",
                "armrectrt4",
                "corgolt4",
                "corcrwt4",
                "armfepocht4",
                "corfblackhyt4",
                "armthundt4",
            },
            quantity = 1,
        },
        [2] = {
            table = {
                "armmar",
                "armvang",
                "armraz",
                "corshiva",
                "corkarg",
                "corcat",
                "armlunchbox",
                "armmeatball",
                "armassimilator",
                "armrectrt4",
                "armsptkt4",
                "armlun",
                "corsok",
                "corcrw",
                "armliche",
            },
            quantity = 3,
        },
    },
}

local starterSeaUnitsList = {
    [1] = {
        [1] = { 
            table = {
                "armpt", 
                "corpt",
            },                          
            quantity = 5,
        },
        [2] = { 
            table = {
                "armpeep", 
                "corfink",
            },                       
            quantity = 1,
        },
    },
}

local seaUnitsList = {
    -- PHASE 1 -- Early T1
    [1] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 1 -- Late T1
    [2] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 3 -- Air T1
    [3] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 4 -- Early T2
    [4] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 5 -- Late T2
    [5] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 6 -- Air T2
    [6] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },

    -- PHASE 6 -- Endgame
    [7] = {
        [1] = {
            table = {"armpt", "corpt",},                          
            quantity = 10,
        },
        [2] = {
            table = {"armfig", "corveng", "armthund", "corshad"},                       
            quantity = 5,
        },
    },
}



local maxPhases = #landUnitsList
local phaseSpawns = 0
local spawnsPerPhase = ChessModeSpawnPerPhaseModoption
local addUpFrequency = ChessModePhaseTimeModoption*1800
local spawnTimer = 2
local respawnTimer = 300
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
                teamSpawnPositions[teamID] = { x = x, y = y, z = z}
                if teamSpawnPositions[teamID].y > 0 then
                    teamIsLandPlayer[teamID] = true
                else
                    teamIsLandPlayer[teamID] = false
                end
				teamSpawnQueue[teamID] = {}
				teamRespawnQueue[teamID] = {}
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
            if teamSpawnQueue[teamID][1] then
                local x = teamSpawnPositions[teamID].x + math.random(-64,64)
                local z = teamSpawnPositions[teamID].z + math.random(-64,64)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(teamSpawnQueue[teamID], 1)
            end
        end
    end
end

local function respawnUnitsFromQueue()
    local teams = spGetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if teamRespawnQueue[teamID] then
            if teamRespawnQueue[teamID][1] then
                local x = teamSpawnPositions[teamID].x + math.random(-64,64)
                local z = teamSpawnPositions[teamID].z + math.random(-64,64)
                local y = Spring.GetGroundHeight(x,z)
                Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
                Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
                table.remove(teamRespawnQueue[teamID], 1)
            end
        end
    end
end

local function chooseNewUnits(starter)
    if starter then
        landPhase = starterLandUnitsList[1]
        landPhaseQuantity = #starterLandUnitsList[1]

        seaPhase = starterSeaUnitsList[1]
        seaPhaseQuantity = #starterSeaUnitsList[1]
    else
        landPhase = landUnitsList[phase]
        landPhaseQuantity = #landUnitsList[phase]

        seaPhase = seaUnitsList[phase]
        seaPhaseQuantity = #seaUnitsList[phase]
    end

    landUnit = {}
    seaUnit = {}
    for j = 1,landPhaseQuantity do
        landUnit[j] = pickRandomUnit(landPhase[j].table, landPhase[j].quantity)
    end
    for j = 1,seaPhaseQuantity do
        seaUnit[j] = pickRandomUnit(seaPhase[j].table, seaPhase[j].quantity)
    end

end

local function addNewUnitsToQueue(starter)
	--local landRandom, landUnit, landUnitCount
	--local seaRandom, seaUnit, seaUnitCount
    chooseNewUnits(starter)
    
	local teams = Spring.GetTeamList()
    for i = 1,#teams do
        local teamID = teams[i]
        if ChessModeUnbalancedModoption == "enabled" then
            chooseNewUnits(starter)
        end
        if teamIsLandPlayer[teamID] then
            for j = 1,landPhaseQuantity do
                for k = 1, #landUnit[j] do
                    if teamSpawnQueue[teamID] then
                        if teamSpawnQueue[teamID][1] then
                            teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = landUnit[j][k]
                        else
                            teamSpawnQueue[teamID][1] = landUnit[j][k]
                        end
                    end
                end
            end
        else
            for j = 1,seaPhaseQuantity do
                for k = 1, #seaUnit[j] do
                    if teamSpawnQueue[teamID] then
                        if teamSpawnQueue[teamID][1] then
                            teamSpawnQueue[teamID][#teamSpawnQueue[teamID]+1] = seaUnit[j][k]
                        else
                            teamSpawnQueue[teamID][1] = seaUnit[j][k]
                        end
                    end
                end
            end
        end
    end
    
    if not starter then
        phaseSpawns = phaseSpawns + 1
        if phaseSpawns == spawnsPerPhase then
            phaseSpawns = 0
            phase = phase + 1
        end
        if phase > maxPhases then
            phase = 1
        end
    end

    landUnit = nil
    landUnitCount = nil
    seaUnit = nil
    seaUnitCount = nil
end

local function respawnDeadUnit(unitName, unitTeam)
    if teamSpawnQueue[unitTeam] then
        if teamRespawnQueue[unitTeam][1] then
            teamRespawnQueue[unitTeam][#teamRespawnQueue[unitTeam]+1] = unitName
        else
            teamRespawnQueue[unitTeam][1] = unitName
        end
    end
end

function gadget:GameFrame(n)
    if n == 20 then
        introSetUp()
    end
    if n == 25 then
        addNewUnitsToQueue(true)
    end
    if n%900 == 1 then
        addInfiniteResources()
    end
    if n > 25 and n%spawnTimer == 1 then
        spawnUnitsFromQueue()
    end
    if n > 25 and n%1800 < 10 then
        respawnUnitsFromQueue()
    end
    if n > 25 and n%addUpFrequency == 1 then
        addNewUnitsToQueue(false)
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID then-- and canResurrect[Spring.GetUnitDefID(builderID)] then
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
