if not gadgetHandler:IsSyncedCode() then
    return
end

local gadgetEnabled = false
if Spring.Utilities.Gametype.IsPvE() then
	Spring.Echo("[ControlVictory] Deactivated because Chickens or Scavengers are present!")
elseif Spring.GetModOptions().scoremode ~= "disabled" and Spring.GetModOptions().scoremode_chess then
    gadgetEnabled = true
end

function gadget:GetInfo()
	return {
		name      = "Control Victory Chess Mode",
		desc      = "123",
		author    = "Damgam",
		date      = "2021",
		license   = "GNU GPL, v2 or later",
		layer     = -100,
		enabled   = gadgetEnabled,
	}
end

local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")

local ChessModeUnbalancedModoption = Spring.GetModOptions().scoremode_chess_unbalanced
local ChessModePhaseTimeModoption = Spring.GetModOptions().scoremode_chess_adduptime
local ChessModeSpawnPerPhaseModoption = Spring.GetModOptions().scoremode_chess_spawnsperphase

local capturePointRadius = math.floor(Spring.GetModOptions().captureradius)

local gaiaTeamID = Spring.GetGaiaTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
local teams = Spring.GetTeamList()

local teamSpawnPositions = {}
local teamSpawnQueue = {}
local teamRespawnQueue = {}
local teamIsLandPlayer = {}
local resurrectedUnits = {}


local function distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	local dist = math.sqrt(xd*xd + yd*yd)
	return dist
end

function GetControlPoints()
	--if controlPoints then return controlPoints end
	controlPoints = {}
	if Script.LuaRules('ControlPoints') then
		local rawPoints = Script.LuaRules.ControlPoints() or {}
		for id = 1, #rawPoints do
			local rawPoint = rawPoints[id]
			local rawPoint = rawPoint
			local pointID = id
			local pointOwner = rawPoint.owner
			local pointPosition = {x=rawPoint.x, y=rawPoint.y, z=rawPoint.z}
			local point = {pointID=pointID, pointPosition=pointPosition, pointOwner=pointOwner}
			controlPoints[id] = point
		end
	end
	return controlPoints
end

-- function GetRandomAllyPoint(teamID, unitName)
--     local _,_,_,_,_,allyTeamID = Spring.GetTeamInfo(teamID)
--     local unitDefID = UnitDefNames[unitName].id
-- 	for i = 1,1000 do
-- 		local r = math.random(1,#controlPoints)
-- 		local point = controlPoints[r]
-- 		local pointAlly = controlPoints[r].pointOwner
-- 		local pointPos = controlPoints[r].pointPosition
-- 		local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
--         local unreachable = true
--         if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
--             unreachable = false
--         end
--         if unreachable == false and pointAlly == allyTeamID then
-- 			pos = pointPos
-- 			break
-- 		end
-- 	end
-- 	return pos
-- end

-- function GetClosestEnemyPoint(unitID)
-- 	local pos
-- 	local bestDistance
-- 	local controlPoints = controlPointsList
-- 	local unitAllyTeam = Spring.GetUnitAllyTeam(unitID)
-- 	local unitDefID = Spring.GetUnitDefID(unitID)
-- 	local unitPositionX, unitPositionY, unitPositionZ = Spring.GetUnitPosition(unitID)
-- 	local position = {x=unitPositionX, y=unitPositionY, z=unitPositionZ}
-- 	for i = 1, #controlPoints do
-- 		local point = controlPoints[i]
-- 		local pointAlly = controlPoints[i].pointOwner
-- 		if pointAlly ~= unitAllyTeam then
-- 			local pointPos = controlPoints[i].pointPosition
-- 			local dist = distance(position, pointPos)
-- 			local y = Spring.GetGroundHeight(pointPos.x, pointPos.z)
-- 			local unreachable = true
-- 			if (-(UnitDefs[unitDefID].minWaterDepth) > y) and (-(UnitDefs[unitDefID].maxWaterDepth) < y) or UnitDefs[unitDefID].canFly then
-- 				unreachable = false
-- 			end
-- 			if unreachable == false and (not bestDistance or dist < bestDistance) then
-- 				bestDistance = dist
-- 				pos = pointPos
-- 			end
-- 		end
-- 	end
-- 	return pos
-- end


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
        table = {
            --bots
            "armpw",
            "corak",
            --vehicles
            "armflash",
            "corgator",
        },
        quantity = 10,
    },
    [2] = {
        table = {
            "armflea",
            "armfav",
            "corfav" ,
        },
        quantity = 5,
    },
    -- [3] = {
    --     table = {
    --         "armassistdrone",
    --         "corassistdrone",
    --     },
    --     quantity = 1,
    -- },
    [3] = {
        table = {
            "armrectr",
            "cornecro",
        },
        quantity = 4,
    },
    [4] = {
        table = {
            "armmlv",
            "cormlv",
        },
        quantity = 2,
    },
    [5] = {
        table = {
            -- "armjeth",
            -- "corcrash",
            -- "armah",
            -- "corah",
            "armsam",
            "cormist",
        },
        quantity = 4,
    },
}

local landUnitsList = {

    -- Tier 1
    [1] = {
        [1] = {
            table = {
                -- Bots
                "armpw",
                "armrock",
                "armham",
                --"armjeth",
                "armwar",
                "corak",
                "corthud",
                "corstorm",
                --"corcrash",
                "legkark",
                "leggob",
                "legcen",
                "legbal",

                -- Vehicles
                "armflash",
                "armstump",
                "armart",
                "armsam",
                "armpincer",
                "armjanus",
                "corgator",
                "cormist",
                "corwolv",
                "corlevlr",
                "corraid",
                "leggat",
                "legrail",

                -- Hovercraft
                "armsh",
                "armmh",
                --"armah",
                "armanac",
                "corsh",
                "cormh",
                --"corah",
                "corsnap",
            },
            quantity = 10,
        },
        [2] = {
            table = {
                "armrectr",
                "cornecro",
            },
            quantity = 4,
        },
        -- [2] = {
        --     table = {
        --         "armck",
        --         "armcv",
        --         "armbeaver",
        --         "armch",
        --         "corck",
        --         "corcv",
        --         "cormuskrat",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 2
    [2] = {
        [1] = {
            table = {
                -- Bots
                "armvader",
                "armspid",
                "armsptk",
                "armfast",
                "armamph",
                "armfido",
                "armzeus",
                "armspy",
                --"armaak",
                "armsnipe",
                "armmav",
                "corroach",
                "corpyro",
                --"corfast",
                "cormort",
                "coramph",
                "corsktl",
                "corspy",
                "corcan",
                --"coraak",
                "cortermite",
                "cormando",

                -- Vehicles
                "armgremlin",
                "armmart",
                "armlatnk",
                --"armyork",
                "armcroc",
                "armmerl",
                "armbull",
				--"corforge",
                "cormart",
                --"corsent",
                "corseal",
                "correap",
                "corgatreap",
                "corvroc",
                "corban",
                "corparrow",

                -- Hovercraft
                "corhal",
            },
            quantity = 5,
        },
        [2] = {
            table = {
                "armrectr",
                "cornecro",
            },
            quantity = 3,
        },
        -- [2] = {
        --     table = {
        --         "armack",
        --         "armdecom",
        --         "armacv",
        --         --"armconsul",
        --         "corack",
        --         "cordecom",
        --         "coracv",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 3
    [3] = {
        [1] = {
            table = {
                -- Heavy T2s
                "corgol",
                "corsumo",
                "armfboy",
                "armmanni",
                "cortrem",
                "corhrk",

                -- Bots
                "armmar",
                "armvang",
                "armraz",
                "corshiva",
                "corkarg",
                "corcat",
                "armlunchbox",
                "armmeatball",
                "armassimilator",

                -- Vehicles
                "armthor",

                -- Hovercraft
                "armlun",
                "corsok",
                "armsptkt4",
            },
            quantity = 3,
        },
        [2] = {
            table = {
                "armrectr",
                "cornecro",
            },
            quantity = 2,
        },
        -- [2] = {
        --     table = {
        --         "armack",
        --         "armdecom",
        --         "armacv",
        --         --"armconsul",
        --         "corack",
        --         "cordecom",
        --         "coracv",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 4
    [4] = {
        [1] = {
            table = {
                "corkorg",
                "corjugg",
                "armbanth",
                "armthor",

                -- Superboss
                "armpwt4",
                "armrattet4",
                "armvadert4",
                "corakt4",
                "cordemont4",
                "corkarganetht4",
                "corgolt4",
            },
            quantity = 1,
        },
        [2] = {
            table = {
                "armrectr",
                "cornecro",
            },
            quantity = 1,
        },
        -- [2] = {
        --     table = {
        --         "armack",
        --         "armdecom",
        --         "armacv",
        --         --"armconsul",
        --         "corack",
        --         "cordecom",
        --         "coracv",
        --     },
        --     quantity = 1,
        -- },
    },
}

local starterSeaUnitsList = {
    [1] = {
        table = {
            "armpt",
            "corpt",
        },
        quantity = 10,
    },
    [2] = {
        table = {
            "armrecl",
            "correcl",
        },
        quantity = 4,
    },
    -- [2] = {
    --     table = {
    --         "armassistdrone",
    --         "corassistdrone",
    --     },
    --     quantity = 1,
    -- },
}

local seaUnitsList = {
    -- Tier 1
    [1] = {
        [1] = {
            table = {
                "armpt",
                "armdecade",
                "armpship",
                "armsub",
                "armpincer",
                "corpt",
                "coresupp",
                "corpship",
                "corsub",
                "corgarp",

                -- Hovercraft
                "armsh",
                "armmh",
                --"armah",
                "armanac",
                "corsh",
                "cormh",
                --"corah",
                "corsnap",
            },
            quantity = 10,
        },
        [2] = {
            table = {
                "armrecl",
                "correcl",
            },
            quantity = 4,
        },
        -- [2] = {
        --     table = {
        --         "armbeaver",
        --         "armch",
        --         "armcs",
        --         "cormuskrat",
        --         "corcs",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 2
    [2] = {
        [1] = {
            table = {
                "armroy",
                "armmls",
                "armsubk",
                "armaas",
                "armcrus",
                "armmship",
                "armcroc",
                "corroy",
                "cormls",
                "corshark",
                "corarch",
                "corcrus",
                "corssub",
                "cormship",
                "corseal",

                -- Hovercraft
                "corhal",
            },
            quantity = 5,
        },
        [2] = {
            table = {
                "armrecl",
                "correcl",
            },
            quantity = 3,
        },
        -- [2] = {
        --     table = {
        --         "armmls",
        --         "armacsub",
        --         "cormls",
        --         "coracsub",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 3
    [3] = {
        [1] = {
            table = {
                "armbats",
                "armepoch",
                "armserp",
                "corbats",
                "corblackhy",
                "corslrpc",
                "armdecadet3",
                "armpshipt3",
                "armptt2",

                -- Hovercraft
                "armlun",
                "corsok",
            },
            quantity = 3,
        },
        [2] = {
            table = {
                "armrecl",
                "correcl",
            },
            quantity = 2,
        },
        -- [2] = {
        --     table = {
        --         "armmls",
        --         "armacsub",
        --         "cormls",
        --         "coracsub",
        --     },
        --     quantity = 1,
        -- },
    },

    -- Tier 4
    [4] = {
        [1] = {
            table = {
                "armserpt3",
                "armepoch",
                "corblackhy",
                "armvadert4",
                "corkorg",
                "armbanth",
                "coresuppt3",
            },
            quantity = 1,
        },
        [2] = {
            table = {
                "armrecl",
                "correcl",
            },
            quantity = 1,
        },
        -- [2] = {
        --     table = {
        --         "armmls",
        --         "armacsub",
        --         "cormls",
        --         "coracsub",
        --     },
        --     quantity = 1,
        -- },
    },
}



--local spawnsPerPhase = ChessModeSpawnPerPhaseModoption
local addUpFrequency = ChessModePhaseTimeModoption*1800
--local spawnTimer = 9000
local respawnTimer = 2500
--local phase
--local canResurrect = {}

-- Functions to hide commanders
-- for unitDefID, unitDef in pairs(UnitDefs) do
--     if unitDef.canResurrect then
--         canResurrect[unitDefID] = true
--     end
-- end

local function disableUnit(unitID)
	Spring.MoveCtrl.Enable(unitID)
	Spring.MoveCtrl.SetNoBlocking(unitID, true)
    local r = math.random(0,3)
    local x = 0
    local z = 0
    if r == 0 then
        x = 0 - math.random(0,1900)
        z = 0 - math.random(0,1900)
    elseif r == 1 then
        x = Game.mapSizeX + math.random(0,1900)
        z = 0 - math.random(0,1900)
    elseif r == 2 then
        x = 0 - math.random(0,1900)
        z = Game.mapSizeZ + math.random(0,1900)
    elseif r == 3 then
        x = Game.mapSizeX + math.random(0,1900)
        z = Game.mapSizeZ + math.random(0,1900)
    end
    Spring.MoveCtrl.SetPosition(unitID, x, 2000, z)
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

local initialCommanders = {}
local function introSetUp()
    for i = 1,#teams do
        local teamID = teams[i]
        local teamUnits = Spring.GetTeamUnits(teamID)
        if teamID ~= gaiaTeamID then
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
				initialCommanders[unitID] = true
            end
        end
    end
    phase = 1
end


local function destroyCommanders()
	for unitID, _ in pairs(initialCommanders) do
		if Spring.ValidUnitID(unitID) then
			Spring.DestroyUnit(unitID, false, true)
		end
	end
	initialCommanders = nil
end

local function addInfiniteResources()
    for i = 1,#teams do
        local teamID = teams[i]
        Spring.SetTeamResource(teamID, "ms", 1000000)
        Spring.SetTeamResource(teamID, "es", 1000000)
        Spring.SetTeamResource(teamID, "m", 500000)
        Spring.SetTeamResource(teamID, "e", 500000)
    end
end

-- local function spawnUnitsFromQueue(teamID)
--     if teamSpawnQueue[teamID] then
--         if teamSpawnQueue[teamID][1] then
--             local pos = GetRandomAllyPoint(teamID, teamSpawnQueue[teamID][1])
--             local spawnedUnit
--             if pos and pos.x then
--                 local x = pos.x+math.random(-50,50)
--                 local z = pos.z+math.random(-50,50)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamSpawnQueue[teamID], 1)
--             else
--                 local x = teamSpawnPositions[teamID].x + math.random(-64,64)
--                 local z = teamSpawnPositions[teamID].z + math.random(-64,64)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamSpawnQueue[teamID], 1)
--             end
--             local rawPos = GetClosestEnemyPoint(spawnedUnit)
--             if rawPos then
--                 local posx = rawPos.x
--                 local posz = rawPos.z
--                 local posy = Spring.GetGroundHeight(posx, posz)
--                 if posx then
--                     Spring.GiveOrderToUnit(spawnedUnit, CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
--                 end
--             end
--         end
--     end
-- end

-- local function respawnUnitsFromQueue(teamID)
--     if teamRespawnQueue[teamID] then
--         if teamRespawnQueue[teamID][1] then
--             local pos = GetRandomAllyPoint(teamID, teamRespawnQueue[teamID][1])
--             local spawnedUnit
--             if pos and pos.x then
--                 local x = pos.x+math.random(-50,50)
--                 local z = pos.z+math.random(-50,50)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamRespawnQueue[teamID], 1)
--             else
--                 local x = teamSpawnPositions[teamID].x + math.random(-64,64)
--                 local z = teamSpawnPositions[teamID].z + math.random(-64,64)
--                 local y = Spring.GetGroundHeight(x,z)
--                 spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
--                 Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
--                 table.remove(teamRespawnQueue[teamID], 1)
--             end
--             local rawPos = GetClosestEnemyPoint(spawnedUnit)
--             if rawPos then
--                 local posx = rawPos.x
--                 local posz = rawPos.z
--                 local posy = Spring.GetGroundHeight(posx, posz)
--                 if posx then
--                     Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
--                     Spring.GiveOrderToUnit(spawnedUnit, CMD.FIGHT,  {posx+math.random(-capturePointRadius,capturePointRadius), posy, posz+math.random(-capturePointRadius,capturePointRadius)}, {"alt", "ctrl"})
--                 end
--             end
--         end
--     end
-- end

local function spawnUnitsFromQueue(teamID)
    if teamSpawnQueue[teamID] then
        if teamSpawnQueue[teamID][1] then
            local x = teamSpawnPositions[teamID].x + math.random(-64,64)
            local z = teamSpawnPositions[teamID].z + math.random(-64,64)
            local y = Spring.GetGroundHeight(x,z)
			local spawnedUnit = Spring.CreateUnit(teamSpawnQueue[teamID][1], x, y, z, 0, teamID)
			if spawnedUnit then
				Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
				Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
			end
            table.remove(teamSpawnQueue[teamID], 1)
        end
    end
end

local function respawnUnitsFromQueue(teamID)
    if teamRespawnQueue[teamID] then
        if teamRespawnQueue[teamID][1] then
            local x = teamSpawnPositions[teamID].x + math.random(-64,64)
            local z = teamSpawnPositions[teamID].z + math.random(-64,64)
            local y = Spring.GetGroundHeight(x,z)
            local spawnedUnit = Spring.CreateUnit(teamRespawnQueue[teamID][1], x, y, z, 0, teamID)
			if spawnedUnit then
				Spring.GiveOrderToUnit(spawnedUnit,CMD.MOVE_STATE,{0},0)
				Spring.SpawnCEG("scav-spawnexplo",x,y,z,0,0,0)
			end
            table.remove(teamRespawnQueue[teamID], 1)
        end
    end
end

local function chooseNewUnits(starter, tier)
    if starter then
        landWave = starterLandUnitsList
        landWaveQuantity = #starterLandUnitsList

        seaWave = starterSeaUnitsList
        seaWaveQuantity = #starterSeaUnitsList
    else
        if (Spring.GetGameSeconds() > 450 and tier > 80) or (Spring.GetGameSeconds() > 750) then -- Tier 4 -- Big Tech 3 units
            landWave = landUnitsList[4]
            landWaveQuantity = #landUnitsList[4]
            seaWave = seaUnitsList[4]
            seaWaveQuantity = #seaUnitsList[4]
        elseif (Spring.GetGameSeconds() > 300 and tier > 60) or (Spring.GetGameSeconds() > 600) then -- Tier 3 -- Expensive Tech 2 units and small Tech 3 units
            landWave = landUnitsList[3]
            landWaveQuantity = #landUnitsList[3]
            seaWave = seaUnitsList[3]
            seaWaveQuantity = #seaUnitsList[3]
        elseif (Spring.GetGameSeconds() > 150 and tier > 40) or (Spring.GetGameSeconds() > 450) then -- Tier 2 -- Less Expensive Tech 2 units
            landWave = landUnitsList[2]
            landWaveQuantity = #landUnitsList[2]
            seaWave = seaUnitsList[2]
            seaWaveQuantity = #seaUnitsList[2]
        else  -- Tier 1
            landWave = landUnitsList[1]
            landWaveQuantity = #landUnitsList[1]
            seaWave = seaUnitsList[1]
            seaWaveQuantity = #seaUnitsList[1]
        end
    end

    landUnit = {}
    seaUnit = {}
    for j = 1,landWaveQuantity do
        landUnit[j] = pickRandomUnit(landWave[j].table, landWave[j].quantity)
    end
    for j = 1,seaWaveQuantity do
        seaUnit[j] = pickRandomUnit(seaWave[j].table, seaWave[j].quantity)
    end
end

local function addNewUnitsToQueue(starter)
	--local landRandom, landUnit, landUnitCount
	--local seaRandom, seaUnit, seaUnitCount
    local tier = math.random(1,100)
    chooseNewUnits(starter, tier)
    for i = 1,#teams do
        local teamID = teams[i]
        if ChessModeUnbalancedModoption then
            chooseNewUnits(starter, tier)
        end
        if teamIsLandPlayer[teamID] then
            for j = 1,landWaveQuantity do
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
            for j = 1,seaWaveQuantity do
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

    landUnit = nil
    landUnitCount = nil
    seaUnit = nil
    seaUnitCount = nil
end

local function respawnDeadUnit(unitName, unitTeam)
    if teamRespawnQueue[unitTeam] then
        if teamRespawnQueue[unitTeam][1] then
            teamRespawnQueue[unitTeam][#teamRespawnQueue[unitTeam]+1] = unitName
        else
            teamRespawnQueue[unitTeam][1] = unitName
        end
    end
end

function gadget:GameFrame(n)
    if n%30 == 0 then
		controlPointsList = GetControlPoints()
	end
    if n == 31 then
        local capturePointPatrolRadius = capturePointRadius*1.5
        for i = 1,#controlPointsList do
            local x = controlPointsList[i].pointPosition.x
            local z = controlPointsList[i].pointPosition.z
            local y = Spring.GetGroundHeight(x, z)
            local landRandomUnit = starterLandUnitsList[1].table[math.random(1,#starterLandUnitsList[1].table)]
            local seaRandomUnit = starterSeaUnitsList[1].table[math.random(1,#starterSeaUnitsList[1].table)]
            local losCheck = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, 1, gaiaAllyTeamID, true, true, true)
            if losCheck == true then
                for j = 1,5 do
                    local unitID
                    if y > -10 then
                        unitID = Spring.CreateUnit(landRandomUnit, x+math.random(-32,32), y, z+math.random(-32,32), 0, gaiaTeamID)
                    else
                        unitID = Spring.CreateUnit(seaRandomUnit, x+math.random(-32,32), y, z+math.random(-32,32), 0, gaiaTeamID)
                    end
                    if unitID then
                        Spring.GiveOrderToUnit(unitID,CMD.MOVE_STATE,{1},0)
                        Spring.GiveOrderToUnit(unitID, CMD.FIGHT,  {x+math.random(-capturePointPatrolRadius, capturePointPatrolRadius), y, z+math.random(-capturePointPatrolRadius, capturePointPatrolRadius)}, {"alt", "ctrl"})
                        for k = 1,10 do
                            Spring.GiveOrderToUnit(unitID, CMD.PATROL,  {x+math.random(-capturePointPatrolRadius, capturePointPatrolRadius), y, z+math.random(-capturePointPatrolRadius, capturePointPatrolRadius)}, {"shift", "alt", "ctrl"})
                        end
                    end
                end
            end
        end
    end
    if n == 20 then
        introSetUp()
    end
	if n == 110 then	-- killing it too early doesnt work somehow (probably due to spawn animation)
		-- com-ends/game_end ignores this scoremode so we can delete the initial commanders
		destroyCommanders()
	end
    if n == 25 then
        addNewUnitsToQueue(true)
    end
    if n%900 == 1 then
        addInfiniteResources()
    end
    if n > 25 and n%addUpFrequency == 1 then
        Spring.PlaySoundFile("sounds/voice/allison/ReinforcementsHaveArrived.wav", 0.75, nil, "ui")
        addNewUnitsToQueue(false)
    end
    for i = 1,#teams do
        local teamID = teams[i]
        if n == 30 then
            for i = 1,100 do
                spawnUnitsFromQueue(teamID)
                respawnUnitsFromQueue(teamID)
            end
        end

        if teamSpawnQueue[teamID] and #teamSpawnQueue[teamID] > 0 then
            -- if teamRespawnQueue[teamID] and #teamRespawnQueue[teamID] > 0 then
            --     if n > 25 and n%math.ceil(spawnTimer/(#teamRespawnQueue[teamID]+#teamSpawnQueue[teamID])) == 1 then
            --         spawnUnitsFromQueue(teamID)
            --     end
            -- else
                -- if n > 25 and n%spawnTimer == 1 then
                    spawnUnitsFromQueue(teamID)
                -- end
            -- end
        else
            if teamRespawnQueue[teamID] and #teamRespawnQueue[teamID] > 0 then
                if n > 25 and n%math.ceil(respawnTimer/(#teamRespawnQueue[teamID])) == 1 then
                    respawnUnitsFromQueue(teamID)
                end
            end
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if builderID then-- and canResurrect[Spring.GetUnitDefID(builderID)] then
        resurrectedUnits[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    local unitName = UnitDefs[unitDefID].name
    if resurrectedUnits[unitID] then
        resurrectedUnits[unitID] = nil
    elseif unitTeam ~= gaiaTeamID and unitName ~= "armcom" and unitName ~= "corcom" and unitName ~= "legcom" then
        local UnitName = UnitDefs[unitDefID].name
        respawnDeadUnit(UnitName, unitTeam)
    end
end
