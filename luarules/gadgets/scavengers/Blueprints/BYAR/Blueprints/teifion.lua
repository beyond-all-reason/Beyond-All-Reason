local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function t2Firebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   96,
		buildings = {
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  56,  zOffset = -96, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  -8,  zOffset =  96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =   8,  zOffset = -96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -56,  zOffset =  96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -24,  zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  24,  zOffset =   0, direction = 1 },
		},
	}
end

local function t2HeavyArtillery1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   64,
		buildings = {
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64,  zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64,  zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64,  zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0,  zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64,  zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64,  zOffset =  64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0,  zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0,  zOffset =  64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64,  zOffset =  64, direction = 1 },
		},
	}
end
    
local function t2HeavyFirebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  104,
		buildings = {
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -6,  zOffset = -104, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id, xOffset = -30,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42,  zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset =  -6,  zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42,  zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42,  zOffset = -104, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset = -54,  zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset = -54,  zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42,  zOffset =  104, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset =  -6,  zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -6,  zOffset =  104, direction = 1 },
		},
	}
end

local function t2Firebase2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =  112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =   16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset = -144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =  144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28,  zOffset = -144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =  -80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =   16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =   80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28,  zOffset = -112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,   xOffset = -44,  zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset = -112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =  -48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =  -16, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,   xOffset = -44,  zOffset =    0, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =  -16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4,  zOffset =   48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =   80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28,  zOffset =  144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =  -48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =   48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36,  zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,   xOffset = -44,  zOffset =   64, direction = 1 },
		},
	}
end

local function t2Firebase3()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   58,
		buildings = {
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -16,  zOffset =  18, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =   8,  zOffset =  58, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -8,  zOffset = -54, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  16,  zOffset =  18, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -16,  zOffset = -14, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  16,  zOffset = -14, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset = -56,  zOffset =  10, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  56,  zOffset = -22, direction = 1 },
		},
	}
end

local function t2HeavyFirebase2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  128,
		buildings = {
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  29,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -35,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -35,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  29,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -35,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset = -35,  zOffset = -128, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset = -35,  zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  93,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset =  29,  zOffset =    0, direction = 1 },
		},
	}
end

local function t3Firebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  163,
		buildings = {
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -109,  zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -125,  zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =   19,  zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -109,  zOffset =   31, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  163,  zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =  -45,  zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  179,  zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =   19,  zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =   19,  zOffset =   31, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  115,  zOffset =   15, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -109,  zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =   35,  zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =  -45,  zOffset =   31, direction = 1 },
		},
	}
end

local function t2Firebase4()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  288,
		buildings = {
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset =  288, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset = -288, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset = -240, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43,  zOffset =  240, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37,  zOffset =  -96, direction = 1 },
		},
	}
end

local function t2HeavyFirebase4()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  384,
		buildings = {
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -384, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  -32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  160, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -255,  zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  288, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -255,  zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  -96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -288, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =   32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =   96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -352, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  288, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  -96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =   96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  384, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47,  zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -288, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -255,  zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =    0, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset = -256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  -32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33,  zOffset =  384, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset =  320, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -384, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191,  zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset = -256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -255,  zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65,  zOffset =   32, direction = 1 },
		},
	}
end

local function t3HeavyArtillery1()
    return {
		type = types.Land,
		tiers = {tiers.T4 },
		radius =  162,
		buildings = {
        	{ unitDefID = UDN.armafus_scav.id, xOffset =  56,  zOffset =  -46, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset =  56,  zOffset =   50, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -56,  zOffset =  130, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset = -40,  zOffset =   50, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  40,  zOffset = -158, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -56,  zOffset = -142, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  40,  zOffset =  162, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset = -40,  zOffset =  -46, direction = 1 },
		},
	}
end

local function t2Firebase5()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   89,
		buildings = {
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  70,  zOffset =  -7, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  22,  zOffset =  89, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset = -50,  zOffset = -31, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset = -50,  zOffset =  33, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset =  14,  zOffset =  33, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset =  14,  zOffset = -31, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,  xOffset = -18,  zOffset = -79, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  22,  zOffset = -87, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,  xOffset = -18,  zOffset =  81, direction = 1 },
		},
	}
end

local function t3HeavyArtillery2()
    return {
		type = types.Land,
		tiers = {tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corbuzz_scav.id, xOffset =   96,  zOffset = -160, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corbuzz_scav.id, xOffset =   96,  zOffset =  160, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  -16,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -144,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  -16,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  128,  zOffset =    0, direction = 1 },
		},
	}
end
local function t2HeavyAntiAir1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  176,
		buildings = {
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0,  zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176,  zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176,  zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0,  zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176,  zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176,  zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =   32,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0,  zOffset =   32, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  -32,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0,  zOffset =  -32, direction = 1 },
		},
	}
end

local function nukeBase1()
    return {
		type = types.Land,
		tiers = { tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =   56,  zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =  -56,  zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =    0,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -144,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =   56,  zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =  -56,  zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =    0,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =  144,  zOffset =    0, direction = 1 },
		},
	}
end

local function t2HeavyFirebase5()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  327,
		buildings = {
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =    5,  zOffset =  -65, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   69,  zOffset =  319, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  189,  zOffset =  327, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -91,  zOffset = -193, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =   53,  zOffset =   63, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset = -123,  zOffset = -257, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  141,  zOffset =  199, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =   61,  zOffset =  -57, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  -27,  zOffset = -193, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  -75,  zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset = -203,  zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   53,  zOffset =  255, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset =  -91,  zOffset =   -1, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -75,  zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =   85,  zOffset =  191, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =    5,  zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =   29,  zOffset = -185, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  -19,  zOffset = -313, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   21,  zOffset =  191, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -59,  zOffset =  -65, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  109,  zOffset =   71, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset = -139,  zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset =    5,  zOffset =  319, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -11,  zOffset =   63, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -27,  zOffset =   -1, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  133,  zOffset =  319, direction = 1 },
		},
	}
end

local function t1Swarm1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  373,
		buildings = {
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -143,  zOffset =  156, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  359,  zOffset = -181, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -218,  zOffset =    2, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  117,  zOffset = -143, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -355,  zOffset =  151, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  285,  zOffset =   -5, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -97,  zOffset = -135, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -294,  zOffset =    6, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  372,  zOffset = -253, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   78,  zOffset =  291, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  338,  zOffset =  137, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  359,  zOffset =  299, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -145,  zOffset = -280, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -162,  zOffset = -141, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   72,  zOffset = -281, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  287,  zOffset =  159, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -209,  zOffset =  296, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -73,  zOffset = -281, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   73,  zOffset =  153, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -102,  zOffset =   21, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  352,  zOffset = -289, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -219,  zOffset = -287, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  133,  zOffset =  -14, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -281,  zOffset =  149, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -292,  zOffset = -286, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  141,  zOffset = -276, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -308,  zOffset = -145, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  217,  zOffset =  162, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -213,  zOffset =  149, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  216,  zOffset =  301, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -333,  zOffset =  286, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -345,  zOffset =  221, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -138,  zOffset =  293, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -280,  zOffset =  300, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -74,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -236,  zOffset = -147, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   51,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   -1,  zOffset = -282, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -367,  zOffset =  -63, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =    4,  zOffset =  285, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  149,  zOffset =  294, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  339,  zOffset = -142, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   64,  zOffset =   -6, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  273,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  335,  zOffset =   69, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  284,  zOffset =  300, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  286,  zOffset = -283, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -74,  zOffset =  151, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  340,  zOffset =    9, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -373,  zOffset = -138, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -66,  zOffset =  290, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  148,  zOffset =  155, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -26,  zOffset = -138, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  190,  zOffset = -139, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -362,  zOffset = -282, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =    5,  zOffset =  156, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  211,  zOffset = -277, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  244,  zOffset =  -29, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -143,  zOffset =   -4, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -363,  zOffset =    1, direction = 1 },
		},
	}
end

local function t2HeavyFirebase6()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  152,
		buildings = {
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61,  zOffset =  152, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91,  zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19,  zOffset =   72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61,  zOffset = -152, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61,  zOffset =   72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61,  zOffset =  -72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19,  zOffset =  -72, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91,  zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19,  zOffset = -152, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset = 101,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =  37,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset = -27,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19,  zOffset =  152, direction = 1 },
		},
	}
end

local function t2AntiAir1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  416,
		buildings = {
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260,  zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196,  zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220,  zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260,  zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196,  zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196,  zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260,  zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  204,  zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196,  zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  204,  zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220,  zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  236,  zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  236,  zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252,  zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252,  zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260,  zOffset =  208, direction = 1 },
		},
	}
end

local function t2AntiAir2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  192,
		buildings = {
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96,  zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0,  zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96,  zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192,  zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192,  zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96,  zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144,  zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192,  zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96,  zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192,  zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0,  zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48,  zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96,  zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192,  zOffset =   96, direction = 1 },
		},
	}
end

local function t2Airbase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  142,
		buildings = {
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =  -50,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =   14,  zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =  142,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset = -122,  zOffset = -136, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =  -34,  zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =   46,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   -2,  zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset =  118,  zOffset =  136, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   -2,  zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   30,  zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset = -146,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =   14,  zOffset = -128, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =  -34,  zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   30,  zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset =  118,  zOffset = -136, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset = -122,  zOffset =  136, direction = 1 },
		},
	}
end

local function t3FactoryBase1()
    return {
		type = types.Land,
		tiers = { tiers.T4 },
		radius =  240,
		buildings = {
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset = -96,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset = -24,  zOffset = -120, direction = 1 },
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32,  zOffset = -240, direction = 1 },
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32,  zOffset =  240, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  72,  zOffset =  120, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset = -96,  zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  72,  zOffset = -120, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset = -24,  zOffset =  120, direction = 1 },
		},
	}
end

local function t1HeavyFirebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  224,
		buildings = {
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0,  zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112,  zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224,  zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224,  zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0,  zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224,  zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224,  zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112,  zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224,  zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112,  zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112,  zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112,  zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112,  zOffset =  224, direction = 1 },
		},
	}
end

return {
	nukeBase1,
	t1HeavyFirebase1,
	t1Swarm1,
	t2Airbase1,
	t2AntiAir1,
	t2AntiAir2,
	t2Firebase1,
	t2Firebase2,
	t2Firebase3,
	t2Firebase4,
	t2Firebase5,
	t2HeavyAntiAir1,
	t2HeavyArtillery1,
	t2HeavyFirebase1,
	t2HeavyFirebase2,
	t2HeavyFirebase4,
	t2HeavyFirebase5,
	t2HeavyFirebase6,
	t3FactoryBase1,
	t3Firebase1,
	t3HeavyArtillery1,
	t3HeavyArtillery2,
}