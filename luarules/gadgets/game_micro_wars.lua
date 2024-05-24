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
local battlefieldMode = modOptions.micro_wars_battlefield_mode or true
local endRoundEarlyPercentage = modOptions.end_round_early_percentage or 50

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
local unitSpawnConfigs = {
    ["Basic T1 - T3"] = {  -- Already provided in your original script
        [1] = {
			{unitName = "armpw", count = 20},    -- Pawns
			{unitName = "armpwt4", count = 10},  -- Rocket Bots
			{unitName = "corcrash", count = 2},  -- Trashers
			{unitName = "legmos", count = 2},   -- Whirlwinds
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
	
    ["Raining Hell"] = {
		[1] = {
			{unitName = "armrock", count = 15},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 10},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 10},  -- Janus (Arm Janus)
		},
		[2] = {
			{unitName = "armrock", count = 15},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 10},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 10},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 15},  -- Trashers (Cor Crash)
		},
		[3] = {
			{unitName = "armrock", count = 25},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 15},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 15},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 15},  -- Trashers (Cor Crash)
		},
		[4] = {
			{unitName = "armrock", count = 25},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 15},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 15},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 15},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 15},    -- Arbiters (Cor Hrk)
		},
		[5] = {
			{unitName = "armrock", count = 25},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 15},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 15},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 20},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 15},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
		},
		[6] = {
			{unitName = "armrock", count = 25},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 15},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 15},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 20},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 15},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
			{unitName = "corban", count = 7},     -- Banishers (Cor Ban)
		},
		[7] = {
			{unitName = "armrock", count = 25},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 25},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 10},    -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 5},   -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 20},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 10},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
			{unitName = "corban", count = 10},    -- Banishers (Cor Ban)
			{unitName = "legmed", count = 3},     -- Medusa (Leg Med)
		},
		[8] = {
			{unitName = "armrock", count = 15},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 15},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 5},     -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 5},   -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 10},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 10},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
			{unitName = "corban", count = 10},    -- Banishers (Cor Ban)
			{unitName = "legmed", count = 5},     -- Medusa (Leg Med)
			{unitName = "corvroc", count = 5},    -- Rocket Trucks (Cor Vroc)
		},
		[9] = {
			{unitName = "armrock", count = 15},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 25},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 5},     -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 10},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 10},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 15},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
			{unitName = "corban", count = 10},    -- Banishers (Cor Ban)
			{unitName = "legmed", count = 5},     -- Medusa (Leg Med)
			{unitName = "corvroc", count = 5},    -- Rocket Trucks (Cor Vroc)
			{unitName = "corcat", count = 2},     -- Catapults (Cor Cat)
		},
		[10] = {
			{unitName = "armrock", count = 15},   -- Rocket Bots (Arm Rock)
			{unitName = "corstorm", count = 25},  -- Rocket Bots (Cor Storm)
			{unitName = "armsam", count = 5},     -- Missile Trucks (Arm Sam)
			{unitName = "armjanus", count = 10},  -- Janus (Arm Janus)
			{unitName = "legmos", count = 10},    -- Mosquito (Leg Mos)
			{unitName = "corcrash", count = 10},  -- Trashers (Cor Crash)
			{unitName = "corhrk", count = 15},    -- Arbiters (Cor Hrk)
			{unitName = "corape", count = 5},     -- Wasps (Cor Ape)
			{unitName = "corban", count = 10},    -- Banishers (Cor Ban)
			{unitName = "legmed", count = 5},     -- Medusa (Leg Med)
			{unitName = "corvroc", count = 5},    -- Rocket Trucks (Cor Vroc)
			{unitName = "corcat", count = 2},     -- Catapults (Cor Cat)
			{unitName = "corkarg", count = 5},    -- Karganeth (Cor Karg)
		},
	},

	["Royalty"] = {
        [1] = {
			{unitName = "armpw", count = 50},      -- Pawns
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armwar", count = 10},     -- Centurion
		},
		[2] = {
			{unitName = "corthud", count = 50},    -- Thugs
			{unitName = "cormando", count = 1},    -- Commando
			{unitName = "corhrk", count = 10},     -- Arbiter
		},
		[3] = {
			{unitName = "legshot", count = 50},    -- Legion Shield Bot
			{unitName = "corgol", count = 1},      -- Tzar
			{unitName = "corhrk", count = 10},     -- Arbiter
		},
		[4] = {
			{unitName = "armpw", count = 100},     -- Pawns
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armwar", count = 15},     -- Centurion
		},
		[5] = {
			{unitName = "corthud", count = 50},    -- Thugs
			{unitName = "cormando", count = 5},    -- Commando
			{unitName = "corhrk", count = 10},     -- Arbiter
			{unitName = "legshot", count = 25},    -- Legion Shield Bot
			{unitName = "corgol", count = 1},      -- Tzar
		},
		[6] = {
			{unitName = "corthud", count = 20},    -- Thugs
			{unitName = "cormando", count = 5},    -- Commando
			{unitName = "corhrk", count = 10},     -- Arbiter
			{unitName = "legshot", count = 25},    -- Legion Shield Bot
			{unitName = "corgol", count = 3},      -- Tzar
			{unitName = "armpw", count = 20},      -- Pawns
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armwar", count = 10},     -- Centurion
		},
		[7] = {
			{unitName = "corthud", count = 50},    -- Thugs
			{unitName = "cormando", count = 5},    -- Commando
			{unitName = "corhrk", count = 10},     -- Arbiter
			{unitName = "legshot", count = 25},    -- Legion Shield Bot
			{unitName = "corgol", count = 3},      -- Tzar
			{unitName = "armpw", count = 50},      -- Pawns
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armwar", count = 10},     -- Centurion
			{unitName = "armmerl", count = 10},    -- Ambassador
		},
		[8] = {
			{unitName = "corthud", count = 50},    -- Thugs
			{unitName = "cormando", count = 5},    -- Commando
			{unitName = "corhrk", count = 10},     -- Arbiter
			{unitName = "legshot", count = 25},    -- Legion Shield Bot
			{unitName = "corgol", count = 3},      -- Tzar
			{unitName = "armpw", count = 50},      -- Pawns
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armwar", count = 10},     -- Centurion
			{unitName = "armmerl", count = 10},    -- Ambassador
			{unitName = "corgolt4", count = 1},    -- Epic Tzar
		},
		[9] = {
			{unitName = "corthud", count = 20},    -- Thugs
			{unitName = "cormando", count = 5},    -- Commando
			{unitName = "corhrk", count = 5},      -- Arbiter
			{unitName = "legshot", count = 25},    -- Legion Shield Bot
			{unitName = "corgol", count = 10},     -- Tzar
			{unitName = "armpw", count = 70},      -- Pawns
			{unitName = "armpwt4", count = 3},     -- Epic Pawn
			{unitName = "armwar", count = 10},     -- Centurion
			{unitName = "armmerl", count = 10},    -- Ambassador
			{unitName = "corgolt4", count = 1},    -- Epic Tzar
		},
		[10] = {
			{unitName = "legshot", count = 35},    -- Legion Shield Bot
			{unitName = "corgol", count = 10},     -- Tzar
			{unitName = "armpw", count = 80},      -- Pawns
			{unitName = "armpwt4", count = 10},    -- Epic Pawn
			{unitName = "corgolt4", count = 1},    -- Epic Tzar
		}
    },

	["Inferno"] = {
        [1] = {
			{unitName = "cortorch", count = 15},  -- Torch
			{unitName = "corsala", count = 10},   -- Salamander
			{unitName = "corcan", count = 15}     -- Fiends
		},
		[2] = {
			{unitName = "legkark", count = 10},   -- Karkinos
			{unitName = "leghelios", count = 30}, -- Helios
			{unitName = "corhal", count = 5},     -- Laser Tigers
			{unitName = "legbar", count = 5}      -- Barrage
		},
		[3] = {
			{unitName = "leginf", count = 1},     -- Inferno
			{unitName = "leghelios", count = 20}, -- Helios
			{unitName = "legbar", count = 5},     -- Barrage
			{unitName = "corcan", count = 15},    -- Fiends
			{unitName = "corsala", count = 10},   -- Salamanders
			{unitName = "cortermite", count = 10} -- Thermites
		},
		[4] = {
			{unitName = "corvipe", count = 1},    -- Scorpion Tank
			{unitName = "corftiger", count = 10}, -- Heat Tigers
			{unitName = "corsala", count = 20},   -- Salamanders
			{unitName = "leginf", count = 2}      -- Infernos
		},
		[5] = {
			{unitName = "legbart", count = 10},   -- Belcher
			{unitName = "leginf", count = 5},     -- Inferno
			{unitName = "legbar", count = 20},    -- Barrage
			{unitName = "corcan", count = 30},    -- Fiends
			{unitName = "corsala", count = 20}    -- Salamanders
		},
		[6] = {
			{unitName = "cortermite", count = 50},  -- Termites
			{unitName = "corthert4", count = 1}     -- Epic Termite
		},
		[7] = {
			{unitName = "corvipe", count = 5},     -- Scorpion Tanks
			{unitName = "corsala", count = 20},    -- Salamanders
			{unitName = "corftiger", count = 30},  -- Heat Tigers
			{unitName = "corcan", count = 20},     -- Fiends
			{unitName = "cortorch", count = 20},   -- Torch
			{unitName = "cordemon", count = 1},    -- Demon
			{unitName = "corforge", count = 5}     -- Forge
		},
		[8] = {
			{unitName = "cordemon", count = 3},    -- Demons
			{unitName = "corvipe", count = 10},    -- Scorpion Tanks
			{unitName = "corftiger", count = 30},  -- Heat Tigers
			{unitName = "leginf", count = 10},     -- Infernos
			{unitName = "cortorch", count = 30}    -- Torch
		},
		[9] = {
			{unitName = "corjugg", count = 1},     -- Juggernaut
			{unitName = "cordemon", count = 2},    -- Demons
			{unitName = "leghelios", count = 50},  -- Helios
			{unitName = "corsala", count = 50}     -- Salamanders
		},
		[10] = {
			{unitName = "corjugg", count = 1},     -- Juggernaut
			{unitName = "cordemon", count = 4},    -- Demons
			{unitName = "corthert4", count = 2},   -- Epic Termites
			{unitName = "corvipe", count = 15},    -- Scorpion Tanks
			{unitName = "corftiger", count = 10},  -- Heat Tigers
			{unitName = "corsala", count = 20},    -- Salamanders
			{unitName = "cortermite", count = 10}, -- Termites
			{unitName = "leginf", count = 10},     -- Infernos
			{unitName = "legbart", count = 10},    -- Belchers
			{unitName = "leghelios", count = 30},  -- Helios
			{unitName = "legkark", count = 10},    -- Karkinos
			{unitName = "corcan", count = 30}      -- Fiends
		},
    },

	["World of Tanks"] = {
        [1] = {
			{unitName = "leghades", count = 10},  -- Helios
			{unitName = "corraid", count = 10},   -- Brutes
			{unitName = "armstump", count = 10},  -- Stouts
			{unitName = "leghades", count = 10},  -- Hades
			{unitName = "corlevlr", count = 10},  -- Pounders
			{unitName = "corgarp", count = 10},   -- Garpikes
			{unitName = "armpincer", count = 10}, -- Pincers
			{unitName = "armflash", count = 10},  -- Blitz
			{unitName = "corgator", count = 10}   -- Incisors
		},
		[2] = {
			{unitName = "corgator", count = 20},  -- Incisors
			{unitName = "corsala", count = 20},   -- Salamanders
			{unitName = "armlatnk", count = 20},  -- Jaguars
			{unitName = "armflash", count = 20},  -- Blitz
			{unitName = "armstump", count = 20},  -- Stouts
			{unitName = "corraid", count = 20}    -- Brutes
		},
		[3] = {
			{unitName = "corban", count = 10},    -- Banishers
			{unitName = "corsala", count = 40},   -- Salamanders
			{unitName = "leghades", count = 30},  -- Hades
			{unitName = "legkark", count = 1}     -- Scorpion
		},
		[4] = {
			{unitName = "armcroc", count = 5},    -- Turtles
			{unitName = "corgarp", count = 10},   -- Garpikes
			{unitName = "armpincer", count = 10}, -- Pincers
			{unitName = "corsala", count = 5},    -- Salamanders
			{unitName = "corparrow", count = 1}   -- Poison Arrow
		},
		[5] = {
			{unitName = "legmed", count = 1},     -- Medusa
			{unitName = "corgator", count = 10},  -- Incisors
			{unitName = "corsala", count = 10},   -- Salamanders
			{unitName = "corparrow", count = 3},  -- Poison Arrows
			{unitName = "corgol", count = 2}      -- Tzars
		},
		[6] = {
			{unitName = "corftiger", count = 15}, -- Heat Tigers
			{unitName = "corraid", count = 15},   -- Tigers
			{unitName = "corgatreap", count = 15} -- Laser Tigers
		},
		[7] = {
			{unitName = "legmed", count = 5},     -- Medusa
			{unitName = "legkeres", count = 1},   -- Keres
			{unitName = "corlevlr", count = 30},  -- Pounders
			{unitName = "armstump", count = 20},  -- Stouts
			{unitName = "corraid", count = 20},   -- Brutes
			{unitName = "corban", count = 5}      -- Banishers
		},
		[8] = {
			{unitName = "armbull", count = 5},     -- Bulls
			{unitName = "corraid", count = 5},     -- Tigers
			{unitName = "corban", count = 5},      -- Banishers
			{unitName = "corparrow", count = 5},   -- Poison Arrows
			{unitName = "legmed", count = 5},      -- Medusa
			{unitName = "corgol", count = 5},      -- Tzars
			{unitName = "corgatreap", count = 5},  -- Laser Tigers
			{unitName = "corftiger", count = 5},   -- Heat Tigers
			{unitName = "corsala", count = 5},     -- Salamanders
			{unitName = "corraid", count = 5},     -- Brutes
			{unitName = "armstump", count = 5},    -- Stouts
			{unitName = "armtorch", count = 5},    -- Torch
			{unitName = "armcroc", count = 5},     -- Turtles
			{unitName = "armflash", count = 5},    -- Blitz
			{unitName = "corgator", count = 5},    -- Incisors
			{unitName = "armgremlin", count = 5},  -- Gremlin
			{unitName = "legkark", count = 5},     -- Scorpion
			{unitName = "armpincer", count = 5},   -- Pincers
			{unitName = "corgarp", count = 5},     -- Garpikes
			{unitName = "leghades", count = 5},    -- Hades
			{unitName = "leghades", count = 5}     -- Helios
		},
		[9] = {
			{unitName = "armbull", count = 5},     -- Bulls
			{unitName = "corraid", count = 5},     -- Tigers
			{unitName = "corban", count = 5},      -- Banishers
			{unitName = "corparrow", count = 5},   -- Poison Arrows
			{unitName = "legmed", count = 5},      -- Medusa
			{unitName = "corgol", count = 5},      -- Tzars
			{unitName = "corgatreap", count = 5},  -- Laser Tigers
			{unitName = "corftiger", count = 5},   -- Heat Tigers
			{unitName = "corsala", count = 5},     -- Salamanders
			{unitName = "corraid", count = 5},     -- Brutes
			{unitName = "armstump", count = 5},    -- Stouts
			{unitName = "armtorch", count = 5},    -- Torch
			{unitName = "armcroc", count = 5},     -- Turtles
			{unitName = "armflash", count = 5},    -- Blitz
			{unitName = "corgator", count = 5},    -- Incisors
			{unitName = "armgremlin", count = 5},  -- Gremlin
			{unitName = "legkark", count = 5},     -- Scorpion
			{unitName = "armpincer", count = 5},   -- Pincers
			{unitName = "corgarp", count = 5},     -- Garpikes
			{unitName = "leghades", count = 5},    -- Hades
			{unitName = "leghades", count = 5},    -- Helios
			{unitName = "armthor", count = 1},     -- Thor
			{unitName = "corgolt4", count = 1},    -- Epic Tzar
			{unitName = "legkeres", count = 1}     -- Keres
		},
		[10] = {
			{unitName = "armgremlin", count = 75},  -- Gremlins
			{unitName = "armlatnk", count = 25},    -- Jaguars
			{unitName = "armthor", count = 1}       -- Thor
		},
    },

	["Arachnophobia"] = {
        [1] = {
			{unitName = "armsptk", count = 20},    -- Recluse
			{unitName = "armspid", count = 10},    -- Webber
			{unitName = "leginfestor", count = 30} -- Infestors
		},
		[2] = {
			{unitName = "armsptk", count = 20},    -- Recluse
			{unitName = "armspid", count = 10},    -- Webber
			{unitName = "leginfestor", count = 30},-- Infestors
			{unitName = "cortermite", count = 20}, -- Termites
			{unitName = "legsrail", count = 20}    -- Railgun Spiders
		},
		[3] = {
			{unitName = "armspid", count = 20},    -- Webbers
			{unitName = "armvang", count = 10},    -- Vanguards
			{unitName = "armsptk", count = 20}     -- Recluse
		},
		[4] = {
			{unitName = "corthermite", count = 1}, -- Epic Termite
			{unitName = "cortermite", count = 60}  -- Termites
		},
		[5] = {
			{unitName = "corkarg", count = 1},     -- Karganeth
			{unitName = "leginfestor", count = 15} -- Infestors
		},
		[6] = {
			{unitName = "legpede", count = 2},     -- Mukade
			{unitName = "legsrail", count = 50},   -- Railgun Spiders
			{unitName = "armspid", count = 10},    -- Webbers
			{unitName = "armsptk", count = 10}     -- Recluse
		},
		[7] = {
			{unitName = "armsptk", count = 40},    -- Recluse
			{unitName = "cortermite", count = 40}, -- Termites
			{unitName = "armspid", count = 20},    -- Webbers
			{unitName = "legsrail", count = 40},   -- Railgun Spiders
			{unitName = "legpede", count = 1},     -- Mukade
			{unitName = "armsptkt4", count = 1},   -- Epic Recluse
			{unitName = "corthermite", count = 1}  -- Epic Termite
		},
		[8] = {
			{unitName = "armvang", count = 15},    -- Vanguards
			{unitName = "legsrail", count = 20},   -- Railgun Spiders
			{unitName = "armsptkt4", count = 1},   -- Epic Recluse
			{unitName = "corkarg", count = 10},    -- Karganeth
			{unitName = "armsptk", count = 30}     -- Recluse
		},
		[9] = {
			{unitName = "cortermite", count = 30},     -- Termites
			{unitName = "armsptk", count = 30},        -- Recluse
			{unitName = "armsptkt4", count = 5},       -- Epic Recluse
			{unitName = "corthermite", count = 5},     -- Epic Termite
			{unitName = "corkarganetht4", count = 5},  -- Epic Karganeth
			{unitName = "armvang", count = 10},        -- Vanguards
			{unitName = "corkarg", count = 10},        -- Karganeth
			{unitName = "leginfestor", count = 30},    -- Infestors
			{unitName = "legsrail", count = 30},       -- Railgun Spiders
			{unitName = "legkark", count = 30},        -- Karkinos
			{unitName = "armspid", count = 30}         -- Webber
		},
		[10] = {
			{unitName = "armsptkt4", count = 1},      -- Epic Recluse
			{unitName = "corthermite", count = 1},    -- Epic Termite
			{unitName = "corkarganetht4", count = 1}  -- Epic Karganeth
		},
    },

	["Can't Touch This"] = {
        [1] = {
			{unitName = "armfav", count = 30},    -- Rovers
			{unitName = "corfav", count = 30},    -- Rascals
			{unitName = "legcen", count = 1},     -- Centaur
			{unitName = "legstr", count = 1},     -- Strider
			{unitName = "armflea", count = 30},   -- Ticks
			{unitName = "armpw", count = 30},     -- Pawns
			{unitName = "corak", count = 20},     -- Grunts
			{unitName = "armflash", count = 10}   -- Blitz
		},
		[2] = {
			{unitName = "armflea", count = 100},  -- Ticks
			{unitName = "corak", count = 1},      -- Grunt
			{unitName = "armfast", count = 1},    -- Sprinter
			{unitName = "armamph", count = 1},    -- Platypus
			{unitName = "corpyro", count = 1},    -- Fiend
			{unitName = "armpw", count = 1},      -- Pawn
			{unitName = "legcen", count = 1},     -- Centaur
			{unitName = "legstr", count = 1},     -- Strider
			{unitName = "armlatnk", count = 1},   -- Jaguar
			{unitName = "armfav", count = 1},     -- Rover
			{unitName = "leghades", count = 1},   -- Hades
			{unitName = "armflash", count = 1},   -- Blitz
			{unitName = "corgator", count = 1},   -- Incisor
			{unitName = "cortorch", count = 1},   -- Torch
			{unitName = "legmrv", count = 1}      -- Quickshot
		},
		[3] = {
			{unitName = "legcen", count = 5},     -- Centaurs
			{unitName = "armpw", count = 20},     -- Pawns
			{unitName = "corak", count = 20},     -- Grunts
			{unitName = "armflea", count = 30}    -- Ticks
		},
		[4] = {
			{unitName = "corpyro", count = 5},    -- Fiends
			{unitName = "corfav", count = 50},    -- Rascals
			{unitName = "armfast", count = 20},   -- Sprinters
			{unitName = "armlatnk", count = 10}   -- Jaguars
		},
		[5] = {
			{unitName = "legstr", count = 10},    -- Striders
			{unitName = "armfast", count = 10},   -- Sprinters
			{unitName = "corpyro", count = 10},   -- Fiends
			{unitName = "corak", count = 10},     -- Grunts
			{unitName = "armpw", count = 10},     -- Pawns
			{unitName = "armmar", count = 1}      -- Marauder
		},
		[6] = {
			{unitName = "armamph", count = 20},   -- Platypus
			{unitName = "armfast", count = 20},   -- Sprinters
			{unitName = "legcen", count = 20},    -- Centaurs
			{unitName = "corakt4", count = 1}     -- Epic Grunt
		},
		[7] = {
			{unitName = "corakt4", count = 1},    -- Epic Grunt
			{unitName = "armpwt4", count = 1},    -- Epic Pawn
			{unitName = "armflea", count = 100}   -- Ticks
		},
		[8] = {
			{unitName = "armmar", count = 5},     -- Marauders
			{unitName = "legmrv", count = 5},     -- Quickshots
			{unitName = "armpwt4", count = 5},    -- Epic Pawns
			{unitName = "corpyro", count = 50},   -- Fiends
			{unitName = "cortorch", count = 5}    -- Torches
		},
		[9] = {
			{unitName = "armpwt4", count = 1},    -- Epic Pawn
			{unitName = "corakt4", count = 1},    -- Epic Grunt
			{unitName = "armmar", count = 10},    -- Marauders
			{unitName = "corfav", count = 50},    -- Rascals
			{unitName = "armflea", count = 50}    -- Ticks
		},
		[10] = {
			{unitName = "armfav", count = 7},     -- Rovers
			{unitName = "corfav", count = 7},     -- Rascals
			{unitName = "legcen", count = 7},     -- Centaurs
			{unitName = "legstr", count = 7},     -- Striders
			{unitName = "armflea", count = 7},    -- Ticks
			{unitName = "armpw", count = 7},      -- Pawns
			{unitName = "corak", count = 7},      -- Grunts
			{unitName = "armflash", count = 7},   -- Blitz
			{unitName = "armfast", count = 7},    -- Sprinters
			{unitName = "armamph", count = 7},    -- Platypus
			{unitName = "corpyro", count = 7},    -- Fiends
			{unitName = "armlatnk", count = 7},   -- Jaguars
			{unitName = "leghades", count = 7},   -- Hades
			{unitName = "corgator", count = 7},   -- Incisors
			{unitName = "cortorch", count = 7},   -- Torches
			{unitName = "legmrv", count = 7},     -- Quickshots
			{unitName = "armmar", count = 7},     -- Marauders
			{unitName = "corakt4", count = 7},    -- Epic Grunts
			{unitName = "armpwt4", count = 7}     -- Epic Pawns
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
            {unitName = "corshad", count = 15}, --Bombers
			{unitName = "armrock", count = 30}, --Rocketeers
			{unitName = "armsam", count = 5},     -- Missile Trucks (Arm Sam)
            -- More units
        },
        -- Other rounds
    },

	["Glass the Runners"] = {
        [1] = {
			{unitName = "legphoenix", count = 5},  -- Phoenixes
			{unitName = "armpw", count = 30},      -- Pawns
			{unitName = "armfast", count = 10},    -- Sprinters
			{unitName = "corcrash", count = 5},    -- Trashers
		},
		[2] = {
			{unitName = "legphoenix", count = 10}, -- Phoenixes
			{unitName = "armpwt4", count = 1},     -- Epic Pawn
			{unitName = "armpw", count = 30},      -- Pawns
			{unitName = "armwar", count = 10},     -- Centurions
			{unitName = "corcrash", count = 5},    -- Trashers
			{unitName = "armaak", count = 1},      -- Archangel
			{unitName = "armfast", count = 10},    -- Sprinters
		},
		[3] = {
			{unitName = "legphoenix", count = 20}, -- Phoenixes
			{unitName = "armpwt4", count = 5},     -- Epic Pawns
			{unitName = "corsumo", count = 10},    -- Mammoths
		},
		[4] = {
			{unitName = "legphoenix", count = 20}, -- Phoenixes
			{unitName = "armaak", count = 2},      -- Archangels
			{unitName = "armwar", count = 20},     -- Centurions
		},
		[5] = {
			{unitName = "armfast", count = 100},   -- Sprinters
			{unitName = "armaak", count = 5},      -- Archangels
			{unitName = "legphoenix", count = 20}, -- Phoenixes
		},
		[6] = {
			{unitName = "legphoenix", count = 25}, -- Phoenixes
			{unitName = "armpwt4", count = 10},    -- Epic Pawns
			{unitName = "corban", count = 20},     -- Banishers
			{unitName = "armfast", count = 30},    -- Sprinters
		}
    },

	["Long Range Standoff"] = {
        [1] = {
			{unitName = "armrock", count = 20},    -- Rocket Bots
			{unitName = "cormist", count = 10},    -- Lashers
			{unitName = "armsnipe", count = 1},    -- Sniper
		},
		[2] = {
			{unitName = "armsnipe", count = 5},    -- Snipers
			{unitName = "cormort", count = 10},    -- Sheldons
			{unitName = "corvoyr", count = 1},     -- Radar Bot (Augur)
			{unitName = "armfido", count = 10},    -- Hounds
		},
		[3] = {
			{unitName = "armvang", count = 1},     -- Vanguard
			{unitName = "armsnipe", count = 10},   -- Snipers
			{unitName = "cormort", count = 10},    -- Sheldons
			{unitName = "corvoyr", count = 2},     -- Radar Bots (Augur)
			{unitName = "corspec", count = 1},     -- Deceiver
			{unitName = "corban", count = 2},      -- Banishers
		},
		[4] = {
			{unitName = "armvang", count = 1},     -- Vanguard
			{unitName = "legsrail", count = 20},   -- Railgun Spiders
		},
		[5] = {
			{unitName = "corcat", count = 2},      -- Catapults
			{unitName = "corban", count = 10},     -- Banishers
			{unitName = "armsnipe", count = 20},   -- Snipers
			{unitName = "legsrail", count = 30},   -- Railgun Spiders
			{unitName = "corawac", count = 3},     -- Radar/Sonar Planes (Condor)
		}
    },
    
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

local firstRoundDelay = 80  -- Corresponds to a 2.7-second delay at 30 fps, right as the commander lands for spawn
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
    StartNewRound()
    Spring.Echo("Micro Wars Started -- Building Disabled")
end

local function CalculateTeamStrength(teamID)
    local unitList = Spring.GetTeamUnits(teamID)
    local totalHealth = 0
    local totalUnits = #unitList
    for _, unitID in ipairs(unitList) do
        if not Spring.GetUnitIsDead(unitID) then
            totalHealth = totalHealth + Spring.GetUnitHealth(unitID)
        end
    end
    return totalUnits, totalHealth
end

local function CheckForEarlyEnd()
    local maxUnits = 0
    local maxHealth = 0
    local maxTeam = nil
    -- Find the team with the maximum units and HP
    for _, teamID in ipairs(teams) do
        if teamID ~= gaiaTeamID then
            local unitCount, totalHealth = CalculateTeamStrength(teamID)
            if unitCount > maxUnits or (unitCount == maxUnits and totalHealth > maxHealth) then
                maxUnits = unitCount
                maxHealth = totalHealth
                maxTeam = teamID
            end
        end
    end
    -- Check conditions independently for units and HP against other teams
    for _, teamID in ipairs(teams) do
        if teamID ~= gaiaTeamID and teamID ~= maxTeam then
            local unitCount, totalHealth = CalculateTeamStrength(teamID)
            if maxUnits >= unitCount * (endRoundEarlyPercentage / 100) and
               maxHealth >= totalHealth * (endRoundEarlyPercentage / 100) then
                return maxTeam
            end
        end
    end
    return nil
end

local checkForEarlyEndDelay = 300 -- Delay of 10 seconds (10 * 30 fps)
-- Commonly used helper function to calculate game frames
local function CalculateFrame(seconds)
    return seconds * 30  -- 30 frames per second
end
function gadget:GameFrame(n)
    -- Delay check until 10 seconds into the game and also delay after each round start
    if not battlefieldMode then
        if n == currentRoundFrameStart + roundTime then
            currentRoundFrameStart = n + checkForEarlyEndDelay  -- Update and apply delay for new round start
            StartNewRound()
        end
    else
        local checkStartFrame = currentRoundFrameStart + checkForEarlyEndDelay
        local earlyRoundCheckEndFrame = n - checkForEarlyEndDelay
        -- Check only during allowed periods
        if n > checkStartFrame and (currentRoundFrameStart == 0 or n > currentRoundFrameStart + checkForEarlyEndDelay) then
            local winningTeam = CheckForEarlyEnd()
            if winningTeam then
                currentRoundFrameStart = n + checkForEarlyEndDelay  -- Prepare delay for next round
                Spring.Echo("Team " .. winningTeam .. " has conclusively won the round early based on both unit count and total HP.")
                StartNewRound()
                return
            end
        end
    end
    -- Handling for first-round delayed spawn
    if firstRoundDelayed and (n == currentRoundFrameStart + firstRoundDelay) then
        -- Execute delayed spawn
        local spawnConfiguration = unitSpawnConfig[1] or {}
        for _, teamID in ipairs(teams) do
            if teamID ~= gaiaTeamID then
                for _, config in ipairs(spawnConfiguration) do
                    SpawnUnitsForTeam(teamID, config.unitName, config.count)
                end
            end
        end
        firstRoundDelayed = false -- Reset flag
    end
end


--dynamically prevent building
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
       if cmdID < 0 then  -- build commands are negative numbers corresponding to the unitDefID to be built
           return false  -- disallow all build commands
       end
       return true  -- allow all other commands
   end

function gadget:Initialize()
    for _, teamID in ipairs(teams) do
        unitSpawns[teamID] = {}
    end
end

function gadget:Shutdown()
    ResetUnitSpawns()
end
