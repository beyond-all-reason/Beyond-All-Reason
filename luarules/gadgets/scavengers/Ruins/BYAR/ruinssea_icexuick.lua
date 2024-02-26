local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local types = blueprintConfig.BlueprintTypes

local function ixatol0()
	return {
		radius = 96,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   19, zOffset =   90, direction = 0 },
			{ unitDefID = UnitDefNames.armada_harpoon.id,    xOffset =   43, zOffset = -110, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -45, zOffset =   90, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -77, zOffset =   90, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -13, zOffset =   90, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -45, zOffset =  -54, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergystorage.id,  xOffset =    3, zOffset =  -54, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -77, zOffset =  -54, direction = 0 },
			{ unitDefID = UnitDefNames.armada_eel.id,   xOffset =  127, zOffset =  -27, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergystorage.id,  xOffset =   67, zOffset =  -54, direction = 0 },
		},
	}
end

local function ixwaterwallh()
	return {
		radius = 112,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   80, zOffset =  -32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   48, zOffset =  -32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -80, zOffset =   32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -112, zOffset =   32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -32, zOffset =    0, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =    0, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  112, zOffset =  -32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   32, zOffset =    0, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -48, zOffset =   32, direction = 2 },
		},
	}
end

local function ixwaterwallv()
	return {
		radius = 128,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   40, zOffset =  128, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -40, zOffset = -128, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   -8, zOffset =  -32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -24, zOffset =  -64, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   24, zOffset =   64, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    8, zOffset =    0, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   24, zOffset =   96, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    8, zOffset =   32, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -24, zOffset =  -96, direction = 2 },
		},
	}
end

local function ixwaterwallhxl()
	return {
		radius = 112,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -144, zOffset = -112, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -176, zOffset = -128, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -48, zOffset =  -32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -16, zOffset =  -16, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -112, zOffset =  -80, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -208, zOffset = -160, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  112, zOffset =   80, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   48, zOffset =   32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  208, zOffset =  160, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  144, zOffset =  112, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  176, zOffset =  128, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -80, zOffset =  -64, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   80, zOffset =   64, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   16, zOffset =   16, direction = 3 },
		},
	}
end

local function ixwaterwallvxl()
	return {
		radius = 128,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =  -32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  192, zOffset = -160, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   64, zOffset =  -48, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =   32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -128, zOffset =  112, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -160, zOffset =  128, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   32, zOffset =  -32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  128, zOffset = -112, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   32, zOffset =    0, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -32, zOffset =   32, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  160, zOffset = -128, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -96, zOffset =   80, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   96, zOffset =  -80, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =    0, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -32, zOffset =    0, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -192, zOffset =  160, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -64, zOffset =   48, direction = 3 },
		},
	}
end

local function ixatolmmkr()
	return {
		radius = 100,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id,  xOffset =  -24, zOffset =  -25, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =  -97, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -32, zOffset =   95, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id,  xOffset =   24, zOffset =  -25, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   32, zOffset =  -97, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -32, zOffset =  -97, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -64, zOffset =   79, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   32, zOffset =   95, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =    0, zOffset =   95, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id,  xOffset =   24, zOffset =   23, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id,  xOffset =  -24, zOffset =   23, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   64, zOffset =  -65, direction = 0 },
		},
	}
end

local function ixatol1nano()
	return {
		radius = 76,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -12, zOffset =   43, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -76, zOffset =   11, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   20, zOffset =   43, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   52, zOffset =  -21, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -44, zOffset =   43, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   52, zOffset =  -53, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   52, zOffset =   11, direction = 0 },
			{ unitDefID = UnitDefNames.armada_tidalgenerator.id,  xOffset =   -4, zOffset =  -13, direction = 0 },
		},
	}
end

local function ixatolseaplane()
	return {
		radius = 105,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_navalmetalstorage.id,  xOffset =  -15, zOffset =  -45, direction = 3 },
			{ unitDefID = UnitDefNames.armada_navalmetalstorage.id,  xOffset =  -15, zOffset =   19, direction = 3 },
			{ unitDefID = UnitDefNames.armada_navalradarsonar.id,  xOffset =   57, zOffset =   -5, direction = 3 },
			{ unitDefID = UnitDefNames.armada_horizon.id, xOffset =   60, zOffset =   -3, direction = 0,},
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -63, zOffset =  -45, direction = 0 },
			{ unitDefID = UnitDefNames.armada_seaplaneplatform.id,  xOffset =  105, zOffset =   75, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -63, zOffset =  -13, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -63, zOffset =   19, direction = 3 },
		},
	}
end

local function ixatolmmkrtide()
	return {
		radius = 54,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_tidalgenerator.id,  xOffset =   54, zOffset =   27, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -18, zOffset =  -29, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   14, zOffset =  -29, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -50, zOffset =   35, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -50, zOffset =    3, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =   46, zOffset =  -29, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id,  xOffset =    6, zOffset =   27, direction = 0 },
		},
	}
end

local function ixatolmmkrsubs()
	return {
		radius = 54,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id, xOffset =   17, zOffset =   -4, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalradarsonar.id, xOffset =   65, zOffset =  -68, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id, xOffset =   17, zOffset =   44, direction = 1 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id, xOffset =  -31, zOffset =   44, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalenergyconverter.id, xOffset =  -31, zOffset =   -4, direction = 1 },
			{ unitDefID = UnitDefNames.armada_eel.id,  xOffset =   76, zOffset =   21, direction = 0 },
			{ unitDefID = UnitDefNames.armada_eel.id,  xOffset = -108, zOffset =  -29, direction = 0,},
		},
	}
end

local function ixuwnrg()
	return {
		radius = 56,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -40, zOffset =   37, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =    8, zOffset =    5, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,  xOffset =   -8, zOffset =  -43, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -24, zOffset =    5, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_urchin.id,    xOffset =   64, zOffset =   -3, direction = 0 },
		},
	}
end

local function ixatolmmkrwalled()
	return {
		radius = 96,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_navalenergyconverter.id,  xOffset =   24, zOffset =    8, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =   64, zOffset =  -48, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =   96, zOffset =  -16, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -64, zOffset =  -48, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalenergyconverter.id,  xOffset =  -24, zOffset =   -8, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =   64, zOffset =   48, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -96, zOffset =   16, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =   96, zOffset =   16, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -96, zOffset =  -16, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sharksteeth.id, xOffset =  -64, zOffset =   48, direction = 0 },
		},
	}
end

local function ixuwamsub()
	return {
		radius = 170,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,    xOffset =  170, zOffset =  -35, direction = 2 },
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,    xOffset =   42, zOffset =  -51, direction = 2 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,    xOffset = -118, zOffset = -131, direction = 2 },
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,    xOffset =  -22, zOffset =  -51, direction = 2 },
			{ unitDefID = UnitDefNames.cortex_amphibiouscomplex.id,   xOffset =   10, zOffset =   77, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,    xOffset =  170, zOffset =   45, direction = 2 },
			{ unitDefID = UnitDefNames.cormuskrat.id, xOffset = -126, zOffset =  139, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sonarstation.id,   xOffset = -123, zOffset =   13, direction = 0 },
		},
	}
end

local function ixuwstor()
	return {
		radius = 82,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,  xOffset =   61, zOffset =  -21, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,  xOffset =  -19, zOffset =  -21, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,  xOffset =  -19, zOffset =   59, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,  xOffset =   61, zOffset =   59, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sonarstation.id, xOffset =  -82, zOffset =  -76, direction = 0 },
		},
	}
end

local function ixuwstoradv()
	return {
		radius = 82,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,  xOffset =   61, zOffset =  -21, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,  xOffset =  -19, zOffset =  -21, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalenergystorage.id,  xOffset =  -19, zOffset =   59, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_navalmetalstorage.id,  xOffset =   61, zOffset =   59, direction = 0 },
			{ unitDefID = UnitDefNames.cortex_sonarstation.id, xOffset =  -82, zOffset =  -76, direction = 0 },
		},
	}
end

local function ixadvatol0()
	return {
		radius = 128,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  109, zOffset =  -57, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -147, zOffset =  -25, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  125, zOffset =   39, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalarbalest.id, xOffset =  -91, zOffset =  -33, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -115, zOffset =  -89, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset = -147, zOffset =  -57, direction = 0 },
			{ unitDefID = UnitDefNames.armada_harpoon.id,    xOffset =   85, zOffset =  127, direction = 0 },
			{ unitDefID = UnitDefNames.armada_advancedsonarstation.id,  xOffset =  -35, zOffset =   71, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  109, zOffset =   71, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalpinpointer.id,  xOffset =   -3, zOffset =    7, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navaladvancedenergyconverter.id, xOffset = -107, zOffset =   55, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  125, zOffset =  -25, direction = 0 },
			{ unitDefID = UnitDefNames.armada_navalpinpointer.id,  xOffset =   61, zOffset =    7, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  -83, zOffset =  -89, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id, xOffset =  125, zOffset =    7, direction = 0 },
		},
	}
end

local function ixatolaa2()
	return {
		radius = 48,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_navalarbalest.id, xOffset =    4, zOffset =   28, direction = 2 },
			{ unitDefID = UnitDefNames.armada_advancedsonarstation.id,  xOffset =   -4, zOffset =  -28, direction = 2 },
		},
	}
end

local function ixadvatolfus()
	return {
		radius = 282,
		type = types.Sea,
		buildings = {
			{ unitDefID = UnitDefNames.armada_navaladvancedenergyconverter.id,   xOffset = -130, zOffset =   -2, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   -2, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_navalarbalest.id,   xOffset =  134, zOffset =   78, direction = 1 },
			{ unitDefID = UnitDefNames.armada_navaladvancedenergyconverter.id,   xOffset = -194, zOffset =   -2, direction = 3 },
			{ unitDefID = UnitDefNames.armada_hardenedmetalstorage.id, xOffset =  190, zOffset = -170, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -258, zOffset =  -10, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -162, zOffset =  -74, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  -66, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   94, zOffset =  134, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   78, zOffset = -170, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  190, zOffset =  102, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   46, zOffset = -170, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  222, zOffset =  102, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  110, zOffset = -106, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  -98, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_hardenedenergystorage.id, xOffset =  -66, zOffset = -170, direction = 2 },
			{ unitDefID = UnitDefNames.armada_navaladvancedenergyconverter.id,   xOffset =   38, zOffset = -106, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  -34, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_harpoon.id,      xOffset =  134, zOffset = -194, direction = 3 },
			{ unitDefID = UnitDefNames.armada_hardenedmetalstorage.id, xOffset =  190, zOffset = -250, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -258, zOffset =  -42, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -226, zOffset =  -74, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  126, zOffset =  134, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -194, zOffset =  -74, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   30, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_navalradarsonar.id,    xOffset =  118, zOffset =  190, direction = 2 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   62, zOffset =  166, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  254, zOffset =   70, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  110, zOffset =  -74, direction = 3 },
			{ unitDefID = UnitDefNames.armada_harpoon.id,      xOffset = -154, zOffset =  190, direction = 3 },
			{ unitDefID = UnitDefNames.armada_navalfusionreactor.id,   xOffset =  -18, zOffset =  -26, direction = 0 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  158, zOffset =  134, direction = 3 },
			{ unitDefID = UnitDefNames.armada_harpoon.id,      xOffset = -282, zOffset =  -98, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =  110, zOffset = -138, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset =   14, zOffset = -170, direction = 3 },
			{ unitDefID = UnitDefNames.armada_sharksteeth.id,   xOffset = -258, zOffset =   22, direction = 3 },
		},
	}
end

return {
	ixatol0,
	ixwaterwallh,
	ixwaterwallv,
	ixwaterwallhxl,
	ixwaterwallvxl,
	ixatolmmkr,
	ixatol1nano,
	ixatolseaplane,
	ixatolmmkrtide,
	ixatolmmkrsubs,
	ixuwnrg,
	ixatolmmkrwalled,
	ixuwamsub,
	ixuwstor,
	ixuwstoradv,
	ixadvatol0,
	ixatolaa2,
	ixadvatolfus,
}