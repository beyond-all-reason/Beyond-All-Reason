local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

-- ARM T1
local function t1Energy1()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 160,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -48,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -48,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset = -160, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   48,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  160, direction = 1 },
		}
	}
end

local function t1Energy2()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 168,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset =  136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset = -136, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =  -48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset = -168, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =  -48,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset =  168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset =  168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset =  136, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset =  168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset = -136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset =  168, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =   48,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armsolar_scav.id,  xOffset =   48,  zOffset =   96, direction = 1 },
		}
	}
end

local function t1Energy3()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 121,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -103,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   57,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  121,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   89,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  121,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   41,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  121,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -71,  zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -103,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   57,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   89,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   25,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -103,  zOffset = -112, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -39,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -39,  zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   25,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -71,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -103,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -103,  zOffset =    0, direction = 1 },
		}
	}
end

-- COR T1
local function t1Energy4()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 160,
		buildings = {
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =  -48,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =  -48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -160, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset = -160, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =   48,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =   48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  160, direction = 1 },
		}
	}
end

local function t1Energy5()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 168,
		buildings = {
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset = -136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset =  136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset =  168, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =   48,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset =  136, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =  -48,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =  -48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset = -136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset =  168, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id,  xOffset =   48,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  120,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset =  168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset = -168, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset =  168, direction = 1 },
		}
	}
end

local function t1Energy6()
	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 112,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   56,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -40,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.cormaw_scav.id,    xOffset = -104,  zOffset =    0, direction = 3 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =   24,  zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.cormaw_scav.id,    xOffset =   88,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =   24,  zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -40,  zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.coradvsol_scav.id, xOffset =  -56,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -104,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -104,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   56,  zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   88,  zOffset =  -80, direction = 1 },
		}
	}
end

-- ARM T2
local function t2Energy1()
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius = 128,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  -48, direction = 3 },
			{ unitDefID = UDN.armfus_scav.id,    xOffset =  -56,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =   80, direction = 3 },
			{ unitDefID = UDN.armfus_scav.id,    xOffset =   56,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  -48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =   80, direction = 3 },
		}
	}
end

local function t2Energy2()
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius =  80,
		buildings = {
			{ unitDefID = UDN.armafus_scav.id,   xOffset =    0,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =   80, direction = 3 },
		}
	}
end

-- COR T2
local function t2Energy3()
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius = 128,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =   72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  -40, direction = 3 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =   56,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =   72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =  -72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -96,  zOffset =  -72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  -40, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =  -72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =  -72, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  128,  zOffset =   40, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =   40, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =  -56,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   96,  zOffset =   72, direction = 3 },
		}
	}
end

local function t2Energy4()
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius =  80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -48, direction = 3 },
			{ unitDefID = UDN.corafus_scav.id,   xOffset =    0,  zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =  -80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   48, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =  -80, direction = 3 },
		}
	}
end

-- ARM T3
local function t2ResourcesBase1()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 208,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -48, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -48, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -176,  zOffset = -144, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset = -128,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset = -112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  176,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   48, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset = -128,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  128,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   48, direction = 0 },
			{ unitDefID = UDN.armflak_scav.id,   xOffset =  -64,  zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.armafus_scav.id,   xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,   xOffset =   64,  zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  144,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -176,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  128,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -144,  zOffset = -144, direction = 0 },
			{ unitDefID = UDN.armflak_scav.id,   xOffset =   64,  zOffset =  -96, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   16, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  128,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,   xOffset =  -64,  zOffset =  -96, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  144,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  176,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -144,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset = -128,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset = -112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  144, direction = 0 },
		}
	}
end

local function t2ResourcesBase2()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 270,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  174,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -98,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   62,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  126,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -130,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -34,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -194,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -66,  zOffset =  192, direction = 1 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  206,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  126,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -194,  zOffset = -192, direction = 1 },
			{ unitDefID = UDN.armbrtha_scav.id,  xOffset = -146,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -162,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  126,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   94,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =   64, direction = 1 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  206,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armfus_scav.id,    xOffset = -114,  zOffset =  104, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   30,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  206,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   -2,  zOffset = -192, direction = 1 },
			{ unitDefID = UDN.armveil_scav.id,   xOffset = -146,  zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,   xOffset =  142,  zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -98,  zOffset = -192, direction = 1 },
			{ unitDefID = UDN.armfus_scav.id,    xOffset =  -42,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,     xOffset =  166,  zOffset = -136, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -162,  zOffset = -192, direction = 1 },
			{ unitDefID = UDN.armmmkr_scav.id,   xOffset =  142,  zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -130,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  238,  zOffset =  192, direction = 1 },
			{ unitDefID = UDN.armfus_scav.id,    xOffset =   54,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -66,  zOffset = -192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =   32, direction = 1 },
			{ unitDefID = UDN.armpb_scav.id,     xOffset =  -26,  zOffset =  184, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  270,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -226,  zOffset = -192, direction = 1 },
		}
	}
end

local function t2EnergyBase1()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 214,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset = -122, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  166, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  214,  zOffset =  -58, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =   54,  zOffset =  166, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  -42,  zOffset = -154, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -106,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  -10,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  -58, direction = 1 },
			{ unitDefID = UDN.armtarg_scav.id,    xOffset =   62,  zOffset =   94, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  102, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  -26, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -106,  zOffset = -154, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  182,  zOffset = -154, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  214,  zOffset = -154, direction = 2 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset =  134,  zOffset =  102, direction = 1 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =  -58,  zOffset =  -58, direction = 0 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =   70,  zOffset =  -58, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  134, direction = 1 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset =   22,  zOffset = -138, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =   86,  zOffset = -154, direction = 2 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =  134,  zOffset =  -58, direction = 0 },
			{ unitDefID = UDN.armuwadves_scav.id, xOffset =    6,  zOffset =  -58, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  118,  zOffset = -154, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =   54,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  -90, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  150,  zOffset = -154, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  -42,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  214,  zOffset =  -90, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset = -154, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =   22,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  -74,  zOffset = -154, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =   70, direction = 1 },
			{ unitDefID = UDN.armafus_scav.id,    xOffset =  -42,  zOffset =  102, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  214,  zOffset = -122, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset = -138,  zOffset =  198, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),  xOffset =  -74,  zOffset =  198, direction = 2 },
		}
	}
end

-- COR T3
local function t2MetalBase1()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 208,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -144,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  144,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  176,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =  -64,  zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -48, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =   64,  zOffset =  -96, direction = 2 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  128,  zOffset =   64, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =  -64,  zOffset =  -96, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset = -112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   48, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset = -112, direction = 0 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset = -128,  zOffset =    0, direction = 0 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset = -128,  zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =  -80, direction = 0 },
			{ unitDefID = UDN.corafus_scav.id,   xOffset =    0,  zOffset =    0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  128,  zOffset =    0, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -176,  zOffset =  144, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =   64,  zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset = -128,  zOffset =   64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -144,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  144,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  -48, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   16, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  176,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset =   48, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  208,  zOffset = -144, direction = 0 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  128,  zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  112,  zOffset = -144, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -208,  zOffset =  112, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -176,  zOffset = -144, direction = 0 },
		}
	}
end

local function t2ResourceBase3()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 170,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  110,  zOffset = -141, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset =  -45, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   78,  zOffset = -141, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -114,  zOffset =  179, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset =  -77, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   46,  zOffset = -141, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset =  -13, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -178,  zOffset =  115, direction = 1 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =   54,  zOffset =  -53, direction = 1 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  -50,  zOffset =  115, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset = -170,  zOffset = -133, direction = 1 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  -50,  zOffset =   51, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset = -109, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -114,  zOffset =  147, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   14,  zOffset = -141, direction = 1 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =  -42,  zOffset =  -53, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset =  134,  zOffset =  171, direction = 1 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset =   30,  zOffset =  131, direction = 1 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =   54,  zOffset =   43, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -114,  zOffset =  115, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  142,  zOffset = -141, direction = 1 },
			{ unitDefID = UDN.cormmkr_scav.id,   xOffset = -114,  zOffset =   51, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -146,  zOffset =  115, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = -130,  zOffset =  -29, direction = 1 },
		}
	}
end

local function t2EnergyBase2()
	return {
		type = types.Land,
		tiers = { tiers.T3 },
		radius = 181,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -149,  zOffset = -153, direction = 2 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =  -93,  zOffset =  159, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  107,  zOffset =  151, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -117,  zOffset = -153, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset = -153, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset =   55, direction = 1 },
			{ unitDefID = UDN.coruwadves_scav.id,  xOffset = -109,  zOffset =   79, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset =   87, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  123,  zOffset = -153, direction = 2 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =   75,  zOffset =  -57, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  155,  zOffset =  -89, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  155,  zOffset = -121, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   59,  zOffset = -153, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -149,  zOffset =  151, direction = 1 },
			{ unitDefID = UDN.cortarg_scav.id,     xOffset =   -5,  zOffset =  -65, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset =  151, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  139,  zOffset =  119, direction = 1 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =   19,  zOffset =  159, direction = 0 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  155,  zOffset =  -57, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  139,  zOffset =   55, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   91,  zOffset = -153, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  139,  zOffset =  151, direction = 1 },
			{ unitDefID = UDN.corafus_scav.id,     xOffset = -101,  zOffset =  -73, direction = 2 },
			{ unitDefID = UDN.coruwadves_scav.id,  xOffset =   51,  zOffset =   79, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset =  119, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   75,  zOffset =  151, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  139,  zOffset =   87, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  155,  zOffset = -153, direction = 2 },
			{ unitDefID = UDN.coruwadves_scav.id,  xOffset =  -29,  zOffset =   79, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -85,  zOffset = -153, direction = 2 },
			{ unitDefID = UDN.corvipe_scav.id,     xOffset =  -13,  zOffset = -145, direction = 2 },
		}
	}
end

local function t2Wind1()
	local r = math.random(0,1)
	local unitDefID
	if r == 0 then
		unitDefID = UDN.armwint2_scav.id
	else
		unitDefID = UDN.corwint2_scav.id
	end

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, tiers.T3 },
		radius =  48,
		buildings = {
			{ unitDefID = unitDefID, xOffset = 0,  zOffset = 0, direction = 1 },
		}
	}
end


local function t1Eco1()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 48,
		buildings = {
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 48, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 48, zOffset = 16, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -48, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -48, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 0, zOffset = -48, direction = 1},
		},
	}
end

local function t1Eco2()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 48,
		buildings = {
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 48, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 0, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -48, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -48, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 48, zOffset = 16, direction = 1},
		},
	}
end

local function t1Eco3()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 88,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 8, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -24, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 24, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -8, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = 72, zOffset = 8, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = -72, zOffset = -8, direction = 1},
		},
	}
end

local function t1Eco4()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 88,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -8, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 8, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 24, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -24, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = -72, zOffset = -8, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = 72, zOffset = 8, direction = 1},
		},
	}
end

local function t1Eco5()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 128,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.corestor_scav.id, xOffset = 96, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.corestor_scav.id, xOffset = -96, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -24, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 24, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = 96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = -96, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = 96, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.coradvsol_scav.id, xOffset = -96, zOffset = 96, direction = 1},
		},
	}
end

local function t1Eco6()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 128,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armestor_scav.id, xOffset = -88, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armestor_scav.id, xOffset = 88, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 24, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -24, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = 96, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = -96, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = -96, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = 96, zOffset = -96, direction = 1},
		},
	}
end

local function t1Eco7()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 104,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 102, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 102, zOffset = -72, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 54, zOffset = 104, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 102, zOffset = 24, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -10, zOffset = 104, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 22, zOffset = 104, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -42, zOffset = 104, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -74, zOffset = 104, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 102, zOffset = -8, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 102, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = -66, zOffset = -128, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = -66, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = 46, zOffset = -64, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = -18, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = -18, zOffset = -128, direction = 1},
			{ unitDefID = UnitDefNames.cormakr_scav.id, xOffset = 46, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.cormstor_scav.id, xOffset = -146, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.cormstor_scav.id, xOffset = -146, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 38, zOffset = -120, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -66, zOffset = -64, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -66, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -18, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -18, zOffset = -64, direction = 1},
			{ unitDefID = UnitDefNames.corhlt_scav.id, xOffset = 54, zOffset = 56, direction = 1},
		},
	}
end

local function t1Eco8()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 107,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 101, zOffset = -69, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -11, zOffset = 107, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 101, zOffset = 27, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 101, zOffset = -37, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -43, zOffset = 107, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -75, zOffset = 107, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 21, zOffset = 107, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 101, zOffset = -5, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 53, zOffset = 107, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 101, zOffset = 59, direction = 3},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = -19, zOffset = 51, direction = 0},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = -67, zOffset = 51, direction = 0},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = -19, zOffset = -125, direction = 0},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = 45, zOffset = -13, direction = 3},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = -67, zOffset = -125, direction = 0},
			{ unitDefID = UnitDefNames.armmakr_scav.id, xOffset = 45, zOffset = -61, direction = 3},
			{ unitDefID = UnitDefNames.armmstor_scav.id, xOffset = -139, zOffset = -5, direction = 1},
			{ unitDefID = UnitDefNames.armmstor_scav.id, xOffset = -139, zOffset = -69, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -67, zOffset = -61, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -19, zOffset = -13, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -19, zOffset = -61, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -67, zOffset = -13, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 37, zOffset = -117, direction = 1},
			{ unitDefID = UnitDefNames.armhlt_scav.id, xOffset = 53, zOffset = 59, direction = 1},
		},
	}
end

local function t1Eco9()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armsolar_scav.id, xOffset = -56, zOffset = -56, direction = 1},
			{ unitDefID = UnitDefNames.armsolar_scav.id, xOffset = -56, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.armsolar_scav.id, xOffset = 56, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.armsolar_scav.id, xOffset = 56, zOffset = -56, direction = 1},
		},
	}
end

local function t1Eco10()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corsolar_scav.id, xOffset = 56, zOffset = -56, direction = 1},
			{ unitDefID = UnitDefNames.corsolar_scav.id, xOffset = -56, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.corsolar_scav.id, xOffset = -56, zOffset = -56, direction = 1},
			{ unitDefID = UnitDefNames.corsolar_scav.id, xOffset = 56, zOffset = 56, direction = 1},
		},
	}
end

local function t1Eco11()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 152,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 120, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 120, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = 152, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -48, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -48, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 0, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -96, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 0, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 96, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 48, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = -96, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 48, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.corwin_scav.id, xOffset = 96, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 96, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -96, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.corasp_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function t1Eco12()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1},
		radius = 152,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 120, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -56, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 88, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 56, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 88, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -56, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 152, zOffset = -120, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -88, zOffset = 152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 120, zOffset = -152, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 96, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 48, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 48, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 0, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -96, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 96, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = 0, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -96, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -48, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armwin_scav.id, xOffset = -48, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -96, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 96, zOffset = 96, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -96, zOffset = -96, direction = 1},
			{ unitDefID = UnitDefNames.armasp_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end


return {
	t1Energy1,
	t1Energy2,
	t1Energy3,
	t1Energy4,
	t1Energy5,
	t1Energy6,
	t2Energy1,
	t2Energy2,
	t2Energy3,
	t2Energy4,
	t2ResourcesBase1,
	t2ResourcesBase2,
	t2EnergyBase1,
	t2MetalBase1,
	t2ResourceBase3,
	t2EnergyBase2,
	t2Wind1,
	t1Eco1,
	t1Eco2,
	t1Eco3,
	t1Eco4,
	t1Eco5,
	t1Eco6,
	t1Eco7,
	t1Eco8,
	t1Eco9,
	t1Eco10,
	t1Eco11,
	t1Eco12,
}