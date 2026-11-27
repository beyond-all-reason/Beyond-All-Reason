-- Tractor beam transport defs, applied by alldefs_post when beta_tractorbeam is on.
-- A passenger takes customparams.nseats seats, else 1 up to 750 mass and 4 above;
-- customparams.oversized "1" or "-1" weighs it x1.5 or x0.5 for speed mode 2.

-- Speed tags per transport: transporterspeedmodmode 0 off, 1 slows by seats used, 2 by weight over seats;
-- transporterspeedmodstrength scales it, transportercomspeedmodstrength is the least slowdown with a commander aboard.

local DEFAULT_GENERIC_SCRIPT = "units/generic_air_transport_lus.lua"
local DEFAULT_WEAPONIZED_SCRIPT = "units/weaponized_air_transport_lus.lua"

return {
	-- Gadget settings
	ALLOW_ENEMY_LOAD_MODE = 2, -- Stunned only
	LOAD_RADIUS = 128, -- elmos XZ; transporter must be within this range to fire PerformLoad
	UNLOAD_RADIUS = 32, -- elmos XZ; transporter must be within this range to fire PerformUnload

	-- the transports each factory builds: known transports are stripped first, {} leaves none,
	-- and a factory not listed keeps its own
	labBuildoptions = {
		armap = { "armatlas", "armhvytrans" }, -- Aircraft Plant
		armaap = { "armdfly" }, -- Advanced Aircraft Plant
		armplat = {}, -- Seaplane Platform
		corap = { "corvalk", "corhvytrans" }, -- Aircraft Plant
		coraap = { "corseah" }, -- Advanced Aircraft Plant
		corplat = {}, -- Seaplane Platform
		legap = { "leglts", "legatrans" }, -- Legion Drone Plant
		legaap = { "legstronghold" }, -- Legion Advanced Aircraft Plant
	},

	-- applied to every transport below before its own fields; alldefs_post sets objectname
	transporterDefaults = {
		transportcapacity = 1000,
		transportsize = 1000,
		transportunloadmethod = 0,
		transportmass = 100000,
		holdsteady = true,
		releaseheld = true,
		loadingRadius = 512,
		unloadSpread = 0,
		script = DEFAULT_GENERIC_SCRIPT,
	},

	-- per transport: unitDef fields, and customparams merged into the unitDef's
	transporters = {
		armdfly = {
			script = DEFAULT_WEAPONIZED_SCRIPT, -- has a weapon
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "armada_ion",
				transportercomspeedmodstrength = 0.33,
			},
		},
		armatlas = {
			customparams = {
				loadtime = 30,
				transporterseats = 1,
				transportcegname = "armada_ion",
				transportercomspeedmodstrength = 0,
			},
		},
		armhvytrans = {
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "armada_ion",
				transportercomspeedmodstrength = 0,
			},
		},
		corseah = {
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "cortex_grapple",
				transportercomspeedmodstrength = 0.33,
			},
		},
		corhvytrans = {
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "cortex_grapple",
				transportercomspeedmodstrength = 0,
			},
		},
		corvalk = {
			customparams = {
				loadtime = 30,
				transporterseats = 1,
				transportcegname = "cortex_grapple",
				transportercomspeedmodstrength = 0,
			},
		},
		legstronghold = {
			script = DEFAULT_WEAPONIZED_SCRIPT, -- has a weapon
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "legion_grav_distort",
				transportercomspeedmodstrength = 0.33,
			},
		},
		legatrans = {
			customparams = {
				loadtime = 60,
				transporterseats = 4,
				transportcegname = "legion_grav_distort",
				transportercomspeedmodstrength = 0,
			},
		},
		leglts = {
			customparams = {
				loadtime = 30,
				transporterseats = 1,
				transportcegname = "legion_grav_distort",
				transportercomspeedmodstrength = 0,
			},
		},
	},
}
