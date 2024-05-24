-- game_micro_wars

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Load mod options
local modOptions = Spring.GetModOptions() or {}

local microWarsEnabled = modOptions.micro_wars_enabled or false
if not microWarsEnabled then
    return false -- Disable this gadget if Micro Wars is not enabled
end

local roundTime = (modOptions.round_time or 5) * 60 * 30 -- Convert minutes to game frames (30 frames per second)
local numberOfControlPoints = modOptions.number_of_control_points or 10
local productionMode = modOptions.production_mode or false
local maxRoundsMode = modOptions.max_rounds_mode or false
local maxNumberOfRounds = modOptions.max_number_of_rounds or 10
local controlPointUnitConversion = modOptions.control_point_unit_conversion or 1
local allowRoundResign = modOptions.allow_round_resign or false

-- Correct initialization for despawnUnits
local despawnUnits = true -- Default value
if modOptions.micro_wars_despawn == nil then
    despawnUnits = true
else
    despawnUnits = modOptions.micro_wars_despawn
end

local teams = Spring.GetTeamList()
local gaiaTeamID = Spring.GetGaiaTeamID()

-- Custom unit spawn configuration per round
--[[
local unitSpawnConfig = {
    [1] = {{unitName = "armpw", count = 100}},
    [2] = {{unitName = "corak", count = 100}},
    [3] = {{unitName = "armpw", count = 50}, {unitName = "corak", count = 50}},
}
]]

--name = "Basic T1 to T3"

-- Define multiple unit spawn configurations based on presets
local unitSpawnConfigs = {
    ["Basic T1 - T3"] = {  -- Already provided in your original script
        [1] = {
        {unitName = "armpw", count = 20},    -- Pawns
        {unitName = "armrock", count = 10},  -- Rocket Bots
        {unitName = "corcrash", count = 2},  -- Trashers
        {unitName = "corshad", count = 2},   -- Whirlwinds
    },
    [2] = {
        {unitName = "armpw", count = 30},    -- Pawns
        {unitName = "armrock", count = 15},  -- Rocket Bots
        {unitName = "corcrash", count = 3},  -- Trashers
        {unitName = "corshad", count = 3},   -- Whirlwinds
        {unitName = "armsam", count = 2},    -- Missile Trucks
    },
    [3] = {
        {unitName = "armpw", count = 40},    -- Pawns
        {unitName = "armrock", count = 20},  -- Rocket Bots
        {unitName = "corcrash", count = 4},  -- Trashers
        {unitName = "corshad", count = 4},   -- Whirlwinds
        {unitName = "armsam", count = 4},    -- Missile Trucks
    },
    [4] = {
        {unitName = "armpw", count = 50},    -- Pawns
        {unitName = "armrock", count = 25},  -- Rocket Bots
        {unitName = "corcrash", count = 5},  -- Trashers
        {unitName = "corshad", count = 5},   -- Whirlwinds
        {unitName = "armsam", count = 6},    -- Missile Trucks
        {unitName = "corraid", count = 2},   -- Brutes
    },
    [5] = {
        {unitName = "armpw", count = 60},    -- Pawns
        {unitName = "armrock", count = 30},  -- Rocket Bots
        {unitName = "corcrash", count = 6},  -- Trashers
        {unitName = "corshad", count = 6},   -- Whirlwinds
        {unitName = "armsam", count = 8},    -- Missile Trucks
        {unitName = "corspec", count = 4},   -- Deceivers
    },
    [6] = {
        {unitName = "armpw", count = 70},    -- Pawns
        {unitName = "armrock", count = 35},  -- Rocket Bots
        {unitName = "corcrash", count = 7},  -- Trashers
        {unitName = "corshad", count = 7},   -- Whirlwinds
        {unitName = "armsam", count = 10},   -- Missile Trucks
        {unitName = "corraid", count = 4},   -- Brutes
        {unitName = "corspec", count = 4},   -- Deceivers
    },
    [7] = {
        {unitName = "armpw", count = 80},    -- Pawns
        {unitName = "armrock", count = 40},  -- Rocket Bots
        {unitName = "corcrash", count = 8},  -- Trashers
        {unitName = "corshad", count = 8},   -- Whirlwinds
        {unitName = "armsam", count = 12},   -- Missile Trucks
        {unitName = "corraid", count = 6},   -- Brutes
        {unitName = "corcat", count = 2},    -- Heavy Rocket Bot
    },
    [8] = {
        {unitName = "armpw", count = 90},    -- Pawns
        {unitName = "armrock", count = 45},  -- Rocket Bots
        {unitName = "corcrash", count = 9},  -- Trashers
        {unitName = "corshad", count = 9},   -- Whirlwinds
        {unitName = "armsam", count = 14},   -- Missile Trucks
        {unitName = "corraid", count = 8},   -- Brutes
        {unitName = "corspec", count = 8},   -- Deceivers
        {unitName = "corcat", count = 4},    -- Heavy Rocket Bot
    },
    [9] = {
        {unitName = "armpw", count = 100},   -- Pawns
        {unitName = "armrock", count = 50},  -- Rocket Bots
        {unitName = "corcrash", count = 10}, -- Trashers
        {unitName = "corshad", count = 10},  -- Whirlwinds
        {unitName = "armsam", count = 16},   -- Missile Trucks
        {unitName = "corraid", count = 10},  -- Brutes
        {unitName = "corspec", count = 10},  -- Deceivers
        {unitName = "corcat", count = 6},    -- Heavy Rocket Bot
    },
    [10] = {
        {unitName = "armpw", count = 120},   -- Pawns
        {unitName = "armrock", count = 60},  -- Rocket Bots
        {unitName = "corcrash", count = 12}, -- Trashers
        {unitName = "corshad", count = 12},  -- Whirlwinds
        {unitName = "armsam", count = 20},   -- Missile Trucks
        {unitName = "corraid", count = 12},  -- Brutes
        {unitName = "corspec", count = 12},  -- Deceivers
        {unitName = "corcat", count = 8},    -- Heavy Rocket Bot
        {unitName = "corkarg", count = 1},   -- Karganeth (All-Terrain Assault Mech)
    }
    },
    ["T1 Variety"] = {
        [1] = {
            {unitName = "armpw", count = 30},
            -- More units
        },
        -- Other rounds
    },
    ["Death from Above"] = {
        [1] = {
            {unitName = "corshad", count = 15},
            -- More units
        },
        -- Other rounds
    },
	["Raining Hell"] = {
		[1] = {

			{unitName = "armrock", count = 15},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 10},    -- Missile Trucks
			{unitName = "armsam", count = 10},    -- Janus
		},
		[2] = {
			{unitName = "armrock", count = 15},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 10},    -- Missile Trucks
			{unitName = "armsam", count = 10},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 15},  -- Trashers
		},
		[3] = {
			{unitName = "armrock", count = 25},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 15},    -- Missile Trucks
			{unitName = "armsam", count = 15},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 15},  -- Trashers
		},
		[4] = {
			{unitName = "armrock", count = 25},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 15},    -- Missile Trucks
			{unitName = "armsam", count = 15},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 15},  -- Trashers
			{unitName = "corhrk", count = 15},  -- Arbiters
		},
		[5] = {
			{unitName = "armrock", count = 25},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 15},    -- Missile Trucks
			{unitName = "armsam", count = 15},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 20},  -- Trashers
			{unitName = "corhrk", count = 15},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps


		},
		[6] = {
			{unitName = "armrock", count = 25},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 15},    -- Missile Trucks
			{unitName = "armsam", count = 15},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 20},  -- Trashers
			{unitName = "corhrk", count = 15},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps
			{unitName = "corban", count = 7},  --Banishers
		},
		[7] = {
			{unitName = "armrock", count = 25},  -- Rocket Bots
			{unitName = "corestorm", count = 25},  -- Rocket Bots
			{unitName = "armsam", count = 10},    -- Missile Trucks
			{unitName = "armsam", count = 5},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 20},  -- Trashers
			{unitName = "corhrk", count = 10},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps
			{unitName = "corban", count = 10},  --Banishers
			{unitName = "legmed", count = 3},  --Medusa
		},
		[8] = {
			{unitName = "armrock", count = 15},  -- Rocket Bots
			{unitName = "corestorm", count = 15},  -- Rocket Bots
			{unitName = "armsam", count = 5},    -- Missile Trucks
			{unitName = "armsam", count = 5},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 10},  -- Trashers
			{unitName = "corhrk", count = 10},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps
			{unitName = "corban", count = 10},  --Banishers
			{unitName = "legmed", count = 5},  --Medusa
			{unitName = "corvroc", count = 5},  --Rocket truck
		},
		[9] = {
			{unitName = "armrock", count = 15},  -- Rocket Bots
			{unitName = "corestorm", count = 25},  -- Rocket Bots
			{unitName = "armsam", count = 5},    -- Missile Trucks
			{unitName = "armsam", count = 10},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 10},  -- Trashers
			{unitName = "corhrk", count = 15},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps
			{unitName = "corban", count = 10},  --Banishers
			{unitName = "legmed", count = 5},  --Medusa
			{unitName = "corvroc", count = 5},  --Rocket truck
			{unitName = "corcat", count = 2},  --catapult
		},
		[10] = {
			{unitName = "armrock", count = 15},  -- Rocket Bots
			{unitName = "corestorm", count = 25},  -- Rocket Bots
			{unitName = "armsam", count = 5},    -- Missile Trucks
			{unitName = "armsam", count = 10},    -- Janus
			{unitName = "legmos", count = 10},    -- mosquito
			{unitName = "corcrash", count = 10},  -- Trashers
			{unitName = "corhrk", count = 15},  -- Arbiters
			{unitName = "corape", count = 5},  --Wasps
			{unitName = "corban", count = 10},  --Banishers
			{unitName = "legmed", count = 5},  --Medusa
			{unitName = "corvroc", count = 5},  --Rocket truck
			{unitName = "corcat", count = 2},  --catapult
			{unitName = "corkarg", count = 5},   -- Karganeth (All-Terrain Assault Mech)
		}
	}
    -- Define other presets like "Glass the Runners" and "Long Range Standoff"
}

-- Check which preset is selected in the game options and set the unitSpawnConfig accordingly
local selectedComposition = modOptions.preset_army_compositions or "Basic T1 - T3"
local unitSpawnConfig = unitSpawnConfigs[selectedComposition]



local currentRound = 1
local currentRoundFrameStart = 0
local unitSpawns = {}

function gadget:GetInfo()
    return {
        name      = "Micro Wars",
        desc      = "Implements the Micro Wars game mode with timed rounds and unit spawns",
        author    = "Soareverix",
        date      = "2024",
        layer     = 0,
        enabled   = microWarsEnabled,
    }
end


local function ResetUnitSpawns()
    if not despawnUnits then
        return -- Do not despawn units if despawnUnits is set to false
    end

    for teamID, units in pairs(unitSpawns) do
        for _, unitID in ipairs(units) do
            if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
                Spring.DestroyUnit(unitID, false, true) -- destroy unit without explosion
            end
        end
    end
    unitSpawns = {}
end

local function GetCommanderPosition(teamID)
    local teamUnits = Spring.GetTeamUnits(teamID)
    for _, unitID in ipairs(teamUnits) do
        if UnitDefs[Spring.GetUnitDefID(unitID)].customParams.iscommander then
            local x, y, z = Spring.GetUnitPosition(unitID)
            return x, y, z
        end
    end
    -- Fallback to team start position if no commander is found
    local x, z = Spring.GetTeamStartPosition(teamID)
    local y = Spring.GetGroundHeight(x, z)
    return x, y, z
end

-- Load the units_per_round multiplier
local unitsPerRoundMultiplier = modOptions.units_per_round or 1

local function SpawnUnitsForTeam(teamID, unitName, unitCount)
    local teamUnits = unitSpawns[teamID] or {}
    local x, y, z = GetCommanderPosition(teamID)

    -- Apply unitsPerRoundMultiplier to unitCount
    unitCount = math.floor(unitCount * unitsPerRoundMultiplier)

    for i = 1, unitCount do
        local ux = x + math.random(-100, 100)
        local uz = z + math.random(-100, 100)
        local uy = Spring.GetGroundHeight(ux, uz)
        local unitID = Spring.CreateUnit(unitName, ux, uy,uz, 0, teamID)
        table.insert(teamUnits, unitID)
        
        -- Trigger explosion effect for each spawned unit
        Spring.SpawnCEG("botrailspawn", ux, uy, uz, 0, 0, 0)
    end

    unitSpawns[teamID] = teamUnits
end

local function SpawnUnitsForTeam(teamID, unitName, unitCount)
    local teamUnits = unitSpawns[teamID] or {}
    local x, y, z = GetCommanderPosition(teamID)

    for i = 1, unitCount do
        local ux = x + math.random(-100, 100)
        local uz = z + math.random(-100, 100)
        local uy = Spring.GetGroundHeight(ux, uz)
        local unitID = Spring.CreateUnit(unitName, ux, uy, uz, 0, teamID)
        table.insert(teamUnits, unitID)
        
        -- Trigger explosion effect for each spawned unit
        Spring.SpawnCEG("botrailspawn", ux, uy, uz, 0, 0, 0)
    end

    unitSpawns[teamID] = teamUnits
end

local firstRoundDelay = 80  -- Corresponds to a 3-second delay at 30 fps
local firstRoundDelayed = (currentRound == 1)  -- Only delay the first round

local function StartNewRound()
    currentRoundFrameStart = Spring.GetGameFrame()
    ResetUnitSpawns()

    local spawnConfiguration = unitSpawnConfig[currentRound] or {}

    for _, teamID in ipairs(teams) do
        if teamID ~= gaiaTeamID then
            if not firstRoundDelayed then  -- Spawn units immediately if not first round or delay elapsed
                for _, config in ipairs(spawnConfiguration) do
                    SpawnUnitsForTeam(teamID, config.unitName, config.count)
                end
            end
        end
    end

    currentRound = currentRound + 1
    if maxRoundsMode and currentRound > maxNumberOfRounds then
        Spring.Echo("Ending game after max number of rounds reached")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:GameStart()
    Spring.Echo("Micro Wars Started") -- Debugging output
    StartNewRound()
    Spring.Echo("Micro Wars Started -- Building Disabled")
end

local function HandleMaxRounds()
    if maxRoundsMode and currentRound > maxNumberOfRounds then
        Spring.Echo("Ending game after max number of rounds reached")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:GameFrame(n)
    if n == currentRoundFrameStart + roundTime then
        StartNewRound()
    end
    
    if firstRoundDelayed and (n == currentRoundFrameStart + firstRoundDelay) then
        -- Perform the delayed first round spawn
        local spawnConfiguration = unitSpawnConfig[1] or {}  -- Ensure it targets the first round config

        for _, teamID in ipairs(teams) do
            if teamID ~= gaiaTeamID then
                for _, config in ipairs(spawnConfiguration) do
                    SpawnUnitsForTeam(teamID, config.unitName, config.count)
                end
            end
        end
        firstRoundDelayed = false  -- Reset the delay flag to prevent re-spawning
    end
end

function gadget:Initialize()
    for _, teamID in ipairs(teams) do
        unitSpawns[teamID] = {}
    end
end

function gadget:Shutdown()
    ResetUnitSpawns()
end
