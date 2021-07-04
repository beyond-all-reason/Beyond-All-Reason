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
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  56, yOffset = 0, zOffset = -96, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  -8, yOffset = 0, zOffset =  96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =   8, yOffset = 0, zOffset = -96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -56, yOffset = 0, zOffset =  96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -24, yOffset = 0, zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,  xOffset =  24, yOffset = 0, zOffset =   0, direction = 1 },
		},
	}
end

local function t2HeavyArtillery1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   64,
		buildings = {
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64, yOffset = 0, zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64, yOffset = 0, zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64, yOffset = 0, zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0, yOffset = 0, zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64, yOffset = 0, zOffset = -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =  64, yOffset = 0, zOffset =  64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0, yOffset = 0, zOffset =   0, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset =   0, yOffset = 0, zOffset =  64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id, xOffset = -64, yOffset = 0, zOffset =  64, direction = 1 },
		},
	}
end
    
local function t2HeavyFirebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  104,
		buildings = {
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -6, yOffset = 0, zOffset = -104, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id, xOffset = -30, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42, yOffset = 0, zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset =  -6, yOffset = 0, zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42, yOffset = 0, zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42, yOffset = 0, zOffset = -104, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset = -54, yOffset = 0, zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset = -54, yOffset = 0, zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  42, yOffset = 0, zOffset =  104, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id,  xOffset =  -6, yOffset = 0, zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -6, yOffset = 0, zOffset =  104, direction = 1 },
		},
	}
end

local function t2Firebase2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =   16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =  -80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =   16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =   80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,   xOffset = -44, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =  -16, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,   xOffset = -44, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =  -16, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =   4, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =   80, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset = -28, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"), xOffset =  36, yOffset = 0, zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,   xOffset = -44, yOffset = 0, zOffset =   64, direction = 1 },
		},
	}
end

local function t2Firebase3()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   58,
		buildings = {
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -16, yOffset = 0, zOffset =  18, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =   8, yOffset = 0, zOffset =  58, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  -8, yOffset = 0, zOffset = -54, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  16, yOffset = 0, zOffset =  18, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -16, yOffset = 0, zOffset = -14, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  16, yOffset = 0, zOffset = -14, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset = -56, yOffset = 0, zOffset =  10, direction = 1 },
        	{ unitDefID = UDN.armpb_scav.id,   xOffset =  56, yOffset = 0, zOffset = -22, direction = 1 },
		},
	}
end

local function t2HeavyFirebase2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  128,
		buildings = {
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  29, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -35, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -35, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  29, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -35, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset = -35, yOffset = 0, zOffset = -128, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset = -35, yOffset = 0, zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  93, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset =  29, yOffset = 0, zOffset =    0, direction = 1 },
		},
	}
end

local function t3Firebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  163,
		buildings = {
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -109, yOffset = 0, zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -125, yOffset = 0, zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =   19, yOffset = 0, zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -109, yOffset = 0, zOffset =   31, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  163, yOffset = 0, zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =  -45, yOffset = 0, zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =  179, yOffset = 0, zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =   19, yOffset = 0, zOffset =  -33, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =   19, yOffset = 0, zOffset =   31, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  115, yOffset = 0, zOffset =   15, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset = -109, yOffset = 0, zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armflak_scav.id, xOffset =   35, yOffset = 0, zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id, xOffset =  -45, yOffset = 0, zOffset =   31, direction = 1 },
		},
	}
end

local function t2Firebase4()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  288,
		buildings = {
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset =  288, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset = -288, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset = -240, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset = -43, yOffset = 0, zOffset =  240, direction = 1 },
        	{ unitDefID = UDN.armamb_scav.id, xOffset =  37, yOffset = 0, zOffset =  -96, direction = 1 },
		},
	}
end

local function t2HeavyFirebase4()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  384,
		buildings = {
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -384, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  -32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  160, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -255, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  288, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -255, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -288, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =   32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -128, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -352, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  288, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -160, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  384, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armanni_scav.id,    xOffset =  -47, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -352, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -288, direction = 1 },
        	{ unitDefID = UDN.armmercury_scav.id, xOffset = -255, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset = -256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  -32, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  320, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   33, yOffset = 0, zOffset =  384, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset =  320, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -384, direction = 1 },
        	{ unitDefID = UDN.armbrtha_scav.id,   xOffset = -191, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset = -256, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.armgate_scav.id,    xOffset = -255, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = BPWallOrPopup("scav"),  xOffset =   65, yOffset = 0, zOffset =   32, direction = 1 },
		},
	}
end

local function t3HeavyArtillery1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  162,
		buildings = {
        	{ unitDefID = UDN.armafus_scav.id, xOffset =  56, yOffset = 0, zOffset =  -46, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset =  56, yOffset = 0, zOffset =   50, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -56, yOffset = 0, zOffset =  130, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset = -40, yOffset = 0, zOffset =   50, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  40, yOffset = 0, zOffset = -158, direction = 1 },
        	{ unitDefID = UDN.armamd_scav.id,  xOffset = -56, yOffset = 0, zOffset = -142, direction = 1 },
        	{ unitDefID = UDN.armvulc_scav.id, xOffset =  40, yOffset = 0, zOffset =  162, direction = 1 },
        	{ unitDefID = UDN.armafus_scav.id, xOffset = -40, yOffset = 0, zOffset =  -46, direction = 1 },
		},
	}
end

local function t2Firebase5()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =   89,
		buildings = {
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  70, yOffset = 0, zOffset =  -7, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  22, yOffset = 0, zOffset =  89, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset = -50, yOffset = 0, zOffset = -31, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset = -50, yOffset = 0, zOffset =  33, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset =  14, yOffset = 0, zOffset =  33, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id,  xOffset =  14, yOffset = 0, zOffset = -31, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,  xOffset = -18, yOffset = 0, zOffset = -79, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  22, yOffset = 0, zOffset = -87, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,  xOffset = -18, yOffset = 0, zOffset =  81, direction = 1 },
		},
	}
end

local function t3HeavyArtillery2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corbuzz_scav.id, xOffset =   96, yOffset = 0, zOffset = -160, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corbuzz_scav.id, xOffset =   96, yOffset = 0, zOffset =  160, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  -16, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -144, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  -16, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =   48, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id, xOffset =  -16, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  128, yOffset = 0, zOffset =    0, direction = 1 },
		},
	}
end
local function t2HeavyAntiAir1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  176,
		buildings = {
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0, yOffset = 0, zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176, yOffset = 0, zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176, yOffset = 0, zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0, yOffset = 0, zOffset = -176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176, yOffset = 0, zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  176, yOffset = 0, zOffset =  176, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset = -176, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =   32, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0, yOffset = 0, zOffset =   32, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =  -32, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,     xOffset =    0, yOffset = 0, zOffset =  -32, direction = 1 },
		},
	}
end

local function nukeBase1()
    return {
		type = types.Land,
		tiers = { tiers.T4 },
		radius =  144,
		buildings = {
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =   56, yOffset = 0, zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =  -56, yOffset = 0, zOffset =  -56, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =    0, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -144, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =   56, yOffset = 0, zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset =  -56, yOffset = 0, zOffset =   56, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =    0, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =  144, yOffset = 0, zOffset =    0, direction = 1 },
		},
	}
end

local function t2HeavyFirebase5()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  327,
		buildings = {
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =    5, yOffset = 0, zOffset =  -65, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   69, yOffset = 0, zOffset =  319, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  189, yOffset = 0, zOffset =  327, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -91, yOffset = 0, zOffset = -193, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =   53, yOffset = 0, zOffset =   63, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset = -123, yOffset = 0, zOffset = -257, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  141, yOffset = 0, zOffset =  199, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =   61, yOffset = 0, zOffset =  -57, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  -27, yOffset = 0, zOffset = -193, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  -75, yOffset = 0, zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset = -203, yOffset = 0, zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   53, yOffset = 0, zOffset =  255, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset =  -91, yOffset = 0, zOffset =   -1, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -75, yOffset = 0, zOffset = -129, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =   85, yOffset = 0, zOffset =  191, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =    5, yOffset = 0, zOffset =  127, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =   29, yOffset = 0, zOffset = -185, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  -19, yOffset = 0, zOffset = -313, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =   21, yOffset = 0, zOffset =  191, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -59, yOffset = 0, zOffset =  -65, direction = 1 },
        	{ unitDefID = UDN.cortoast_scav.id, xOffset =  109, yOffset = 0, zOffset =   71, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset = -139, yOffset = 0, zOffset = -321, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id,  xOffset =    5, yOffset = 0, zOffset =  319, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -11, yOffset = 0, zOffset =   63, direction = 1 },
        	{ unitDefID = UDN.cormmkr_scav.id,  xOffset =  -27, yOffset = 0, zOffset =   -1, direction = 1 },
        	{ unitDefID = UDN.cordoom_scav.id,  xOffset =  133, yOffset = 0, zOffset =  319, direction = 1 },
		},
	}
end

local function t1Swarm1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  373,
		buildings = {
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -143, yOffset = 0, zOffset =  156, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  359, yOffset = 0, zOffset = -181, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -218, yOffset = 0, zOffset =    2, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  117, yOffset = 0, zOffset = -143, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -355, yOffset = 0, zOffset =  151, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  285, yOffset = 0, zOffset =   -5, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -97, yOffset = 0, zOffset = -135, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -294, yOffset = 0, zOffset =    6, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  372, yOffset = 0, zOffset = -253, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   78, yOffset = 0, zOffset =  291, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  338, yOffset = 0, zOffset =  137, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  359, yOffset = 0, zOffset =  299, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -145, yOffset = 0, zOffset = -280, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -162, yOffset = 0, zOffset = -141, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   72, yOffset = 0, zOffset = -281, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  287, yOffset = 0, zOffset =  159, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -209, yOffset = 0, zOffset =  296, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -73, yOffset = 0, zOffset = -281, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   73, yOffset = 0, zOffset =  153, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -102, yOffset = 0, zOffset =   21, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  352, yOffset = 0, zOffset = -289, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -219, yOffset = 0, zOffset = -287, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  133, yOffset = 0, zOffset =  -14, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -281, yOffset = 0, zOffset =  149, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -292, yOffset = 0, zOffset = -286, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  141, yOffset = 0, zOffset = -276, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -308, yOffset = 0, zOffset = -145, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  217, yOffset = 0, zOffset =  162, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -213, yOffset = 0, zOffset =  149, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  216, yOffset = 0, zOffset =  301, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -333, yOffset = 0, zOffset =  286, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -345, yOffset = 0, zOffset =  221, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -138, yOffset = 0, zOffset =  293, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -280, yOffset = 0, zOffset =  300, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -74, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -236, yOffset = 0, zOffset = -147, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   51, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   -1, yOffset = 0, zOffset = -282, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -367, yOffset = 0, zOffset =  -63, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =    4, yOffset = 0, zOffset =  285, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  149, yOffset = 0, zOffset =  294, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  339, yOffset = 0, zOffset = -142, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =   64, yOffset = 0, zOffset =   -6, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  273, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  335, yOffset = 0, zOffset =   69, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  284, yOffset = 0, zOffset =  300, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  286, yOffset = 0, zOffset = -283, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -74, yOffset = 0, zOffset =  151, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  340, yOffset = 0, zOffset =    9, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -373, yOffset = 0, zOffset = -138, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -66, yOffset = 0, zOffset =  290, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  148, yOffset = 0, zOffset =  155, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  -26, yOffset = 0, zOffset = -138, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  190, yOffset = 0, zOffset = -139, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -362, yOffset = 0, zOffset = -282, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =    5, yOffset = 0, zOffset =  156, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  211, yOffset = 0, zOffset = -277, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset =  244, yOffset = 0, zOffset =  -29, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -143, yOffset = 0, zOffset =   -4, direction = 1 },
        	{ unitDefID = UDN.armflea_scav.id, xOffset = -363, yOffset = 0, zOffset =    1, direction = 1 },
		},
	}
end

local function t2HeavyFirebase6()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  152,
		buildings = {
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61, yOffset = 0, zOffset =  152, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91, yOffset = 0, zOffset =   64, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19, yOffset = 0, zOffset =   72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61, yOffset = 0, zOffset = -152, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61, yOffset = 0, zOffset =   72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset =  61, yOffset = 0, zOffset =  -72, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19, yOffset = 0, zOffset =  -72, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset = -91, yOffset = 0, zOffset =  -64, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19, yOffset = 0, zOffset = -152, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset = 101, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset =  37, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.cortron_scav.id, xOffset = -27, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corint_scav.id,  xOffset = -19, yOffset = 0, zOffset =  152, direction = 1 },
		},
	}
end

local function t2AntiAir1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  416,
		buildings = {
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260, yOffset = 0, zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196, yOffset = 0, zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220, yOffset = 0, zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260, yOffset = 0, zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196, yOffset = 0, zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196, yOffset = 0, zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260, yOffset = 0, zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  204, yOffset = 0, zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196, yOffset = 0, zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  204, yOffset = 0, zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset =  220, yOffset = 0, zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  236, yOffset = 0, zOffset =  416, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  236, yOffset = 0, zOffset =  208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset = -196, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252, yOffset = 0, zOffset = -208, direction = 1 },
        	{ unitDefID = UDN.corshroud_scav.id, xOffset =  252, yOffset = 0, zOffset = -416, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id,   xOffset = -260, yOffset = 0, zOffset =  208, direction = 1 },
		},
	}
end

local function t2AntiAir2()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  192,
		buildings = {
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset = -144, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96, yOffset = 0, zOffset =  192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  144, yOffset = 0, zOffset =  -48, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset =  144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =   48, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192, yOffset = 0, zOffset = -192, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  -96, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset =   48, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =  192, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =    0, yOffset = 0, zOffset =   96, direction = 1 },
        	{ unitDefID = UDN.corscreamer_scav.id, xOffset =  -48, yOffset = 0, zOffset = -144, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset =   96, yOffset = 0, zOffset =  -96, direction = 1 },
        	{ unitDefID = UDN.corarad_scav.id,     xOffset = -192, yOffset = 0, zOffset =   96, direction = 1 },
		},
	}
end

local function t2Airbase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  142,
		buildings = {
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =  -50, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =   14, yOffset = 0, zOffset =  128, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =  142, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset = -122, yOffset = 0, zOffset = -136, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =  -34, yOffset = 0, zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset =   46, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   -2, yOffset = 0, zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset =  118, yOffset = 0, zOffset =  136, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   -2, yOffset = 0, zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   30, yOffset = 0, zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.coraap_scav.id,  xOffset = -146, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corgate_scav.id, xOffset =   14, yOffset = 0, zOffset = -128, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =  -34, yOffset = 0, zOffset =   80, direction = 1 },
        	{ unitDefID = UDN.corflak_scav.id, xOffset =   30, yOffset = 0, zOffset =  -80, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset =  118, yOffset = 0, zOffset = -136, direction = 1 },
        	{ unitDefID = UDN.corasp_scav.id,  xOffset = -122, yOffset = 0, zOffset =  136, direction = 1 },
		},
	}
end

local function t3FactoryBase1()
    return {
		type = types.Land,
		tiers = { tiers.T4 },
		radius =  240,
		buildings = {
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset = -96, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset = -24, yOffset = 0, zOffset = -120, direction = 1 },
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32, yOffset = 0, zOffset = -240, direction = 1 },
        	{ unitDefID = UDN.corgant_scav.id, xOffset =  32, yOffset = 0, zOffset =  240, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  72, yOffset = 0, zOffset =  120, direction = 1 },
        	{ unitDefID = UDN.corsilo_scav.id, xOffset = -96, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset =  72, yOffset = 0, zOffset = -120, direction = 1 },
        	{ unitDefID = UDN.corafus_scav.id, xOffset = -24, yOffset = 0, zOffset =  120, direction = 1 },
		},
	}
end

local function t1HeavyFirebase1()
    return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  224,
		buildings = {
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224, yOffset = 0, zOffset = -224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  224, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112, yOffset = 0, zOffset =  112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -224, yOffset = 0, zOffset =  224, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset =  112, yOffset = 0, zOffset =    0, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112, yOffset = 0, zOffset = -112, direction = 1 },
        	{ unitDefID = UDN.armbeamer_scav.id, xOffset = -112, yOffset = 0, zOffset =  224, direction = 1 },
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