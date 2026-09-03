local DEFAULT_GENERIC_SCRIPT = "modules/transport/scripts/generic_air_transport_lus.lua"
local DEFAULT_WEAPONIZED_SCRIPT = "modules/transport/scripts/weaponized_air_transport_lus.lua"

return {
	ALLOW_ENEMY_LOAD_MODE = 2,
	LOAD_RADIUS = 128,
	UNLOAD_RADIUS = 32,

	labBuildoptions = {
		armap = { "armatlas", "armhvytrans" },
		armaap = { "armdfly" },
		armplat = {},
		corap = { "corvalk", "corhvytrans" },
		coraap = { "corseah" },
		corplat = {},
		legap = { "leglts", "legatrans" },
		legaap = { "legstronghold" },
	},

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

	transporters = {
		armdfly = {
			script = DEFAULT_WEAPONIZED_SCRIPT,
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
			script = DEFAULT_WEAPONIZED_SCRIPT,
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

	passengerSizes = {},
}
