local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local function getRandomNanoTowerID()
	return math.random(0, 1) == 0 and UDN.armnanotc_scav.id or UDN.cornanotc_scav.id
end

local function t1Firebase1()
	local buildings
	local r = math.random(0,3)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.armguard_scav.id,  xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =   40, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =    8,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =  -40, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -40,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   -8,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   40,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =   -8, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =  -72, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armguard_scav.id,  xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =    8,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   40,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -40,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -72,  zOffset =   40, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =   -8, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   -8,  zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =  -40, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.corpun_scav.id,    xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -16,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   16,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =   80, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corpun_scav.id,    xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   48,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -16,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -48,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   80,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -80,  zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   16,  zOffset =  -80, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T1 },
		radius = 72,
		buildings = buildings,
	}
end

local function windFarm1()
	local buildings
	local r = math.random(0,3)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48,  zOffset =  -80, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80,  zOffset =  -96, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96,  zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96,  zOffset =  -80, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80,  zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =   96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80,  zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80,  zOffset =   96, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1 },
		radius = 96,
		buildings = buildings,
	}
end

local function minefield1()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3 },
		radius = 192,
		buildings = {
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-192,192),  zOffset = math.random(-192,192), direction = 0 },
		},
	}
end

local function minefield2()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3 },
		radius = 96,
		buildings = {
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-96,96),  zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-96,96),  zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-96,96),  zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-96,96),  zOffset = math.random(-96,96), direction = 0 },
		},
	}
end

local function minefield3()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3 },
		radius = 384,
		buildings = {
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384),  zOffset = math.random(-384,384), direction = 0 },
		},
	}
end
		
local function randomNanoTowerDuo()
	local unitID = getRandomNanoTowerID()

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2 },
		radius = 48,
		buildings = {
			{ unitDefID = unitID, xOffset =   24,  zOffset =    0, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24,  zOffset =    0, direction = 0 },
		},
	}
end
		
local function randomNanoTowerQuad()
	local unitID = getRandomNanoTowerID()

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 56,
		buildings = {
			{ unitDefID = unitID, xOffset =   24,  zOffset =   24, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24,  zOffset =   24, direction = 0 },
			{ unitDefID = unitID, xOffset =   24,  zOffset =  -24, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24,  zOffset =  -24, direction = 0 },
		},
	}
end
		
local function t3Gantry1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -112,  zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  112,  zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -112,  zOffset =   16, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  112,  zOffset =   16, direction = 0 },
			{ unitDefID = UDN.armgate_scav.id,   xOffset =   40,  zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.armamd_scav.id,    xOffset =  -40,  zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.armshltx_scav.id,  xOffset =    0,  zOffset =   80, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -112,  zOffset =   16, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  112,  zOffset =   16, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -112,  zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  112,  zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.corgant_scav.id,   xOffset =    0,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corgate_scav.id,   xOffset =   40,  zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.corfmd_scav.id,    xOffset =  -40,  zOffset =  -24, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius = 112,
		buildings = buildings,
	}
end

local function t3Gantry2()
	local buildings	
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.armapt3_scav.id,    xOffset =    0,  zOffset =   20, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset = -116,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset = -196,  zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset =  188,  zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset =  124,  zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset = -204,  zOffset =   -8, direction = 3 },
			{ unitDefID = UDN.armbrtha_scav.id,   xOffset =    4,  zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armgate_scav.id,    xOffset =    4,  zOffset = -136, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset =  196,  zOffset =   88, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset =  196,  zOffset =   -8, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = -188,  zOffset =   40, direction = 3 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =  180,  zOffset =   40, direction = 1 },
			{ unitDefID = UDN.armamb_scav.id,     xOffset =   60,  zOffset = -144, direction = 2 },
			{ unitDefID = UDN.armamb_scav.id,     xOffset =  -52,  zOffset = -144, direction = 2 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset = -108,  zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset =  116,  zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset = -204,  zOffset =   88, direction = 3 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corapt3_scav.id,     xOffset =    1,  zOffset =   11, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -96,  zOffset = -140, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  192,  zOffset =  -60, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -192,  zOffset =  -60, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   96,  zOffset = -140, direction = 0 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset =  104,  zOffset =  172, direction = 0 },
			{ unitDefID = UDN.corint_scav.id,      xOffset =    0,  zOffset =  180, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset = -200,  zOffset =   76, direction = 3 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset = -184,  zOffset =   28, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset = -104,  zOffset =  172, direction = 0 },
			{ unitDefID = UDN.cortoast_scav.id,    xOffset =   32,  zOffset = -140, direction = 2 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset =  200,  zOffset =  -20, direction = 1 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset =  200,  zOffset =   76, direction = 1 },
			{ unitDefID = UDN.corgate_scav.id,     xOffset =  -24,  zOffset = -148, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset = -200,  zOffset =  -20, direction = 3 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =  184,  zOffset =   28, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius = 204,
		buildings = buildings,
	}
end

local function t2HeavyFirebase1()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 134,
		buildings = {
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -14,  zOffset =   13, direction = 0 },		
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   26,  zOffset =  -91, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   90,  zOffset =  -59, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   26,  zOffset =  101, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -134,  zOffset =   53, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -86,  zOffset =  -43, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   58,  zOffset =  -75, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   58,  zOffset =   85, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  122,  zOffset =   53, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   90,  zOffset =   69, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -118,  zOffset =   21, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -102,  zOffset =  -11, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   -6,  zOffset = -107, direction = 2 },
		},
	}
end

local function t2HeavyFirebase2()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 172,
		buildings = {
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -14,  zOffset =   20, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  138,  zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  138,  zOffset =   12, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  138,  zOffset =   76, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -102,  zOffset =  156, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   10,  zOffset = -100, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -150,  zOffset =  -52, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -70,  zOffset =  156, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   -6,  zOffset =  172, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -134,  zOffset =  -84, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -38,  zOffset =  172, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   74,  zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  138,  zOffset =   44, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  122,  zOffset =  108, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -118,  zOffset = -116, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  122,  zOffset =  -20, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -134,  zOffset =  140, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   42,  zOffset = -116, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -166,  zOffset =  -20, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -86,  zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  106,  zOffset = -148, direction = 2 },
		},
	}
end

local function t2HeavyFirebase3()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 196,
		buildings = {
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =   -4,  zOffset =  -11, direction = 3 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  148,  zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  100,  zOffset = -131, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  212,  zOffset =   13, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -12,  zOffset = -163, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  132,  zOffset = -131, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  180,  zOffset =   93, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -172,  zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -140,  zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -172,  zOffset =  -35, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -124,  zOffset =   93, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,      xOffset =  180,  zOffset = -115, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id,   xOffset = -132,  zOffset = -107, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  180,  zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  132,  zOffset =  -99, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,     xOffset =  -92,  zOffset =   93, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,      xOffset = -172,  zOffset =  109, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -44,  zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -156,  zOffset =   29, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -108,  zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -124,  zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  180,  zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   20,  zOffset =  173, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -12,  zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -172,  zOffset =   -3, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id,   xOffset =  140,  zOffset =  117, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   20,  zOffset = -179, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -172,  zOffset = -115, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,     xOffset =  100,  zOffset =  -99, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -172,  zOffset =  -83, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  196,  zOffset =  -19, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   52,  zOffset =  173, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -92,  zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  116,  zOffset =  157, direction = 2 },
		},
	}
end

local function t2HeavyFirebase4()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 328,
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -208,  zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  160,  zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -160,  zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -208,  zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  160,  zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  208,  zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -160,  zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  208,  zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -16,  zOffset =   -7, direction = 2 },

			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  312,  zOffset =   49, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  312,  zOffset =   17, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =    8,  zOffset =  177, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -328,  zOffset =  -15, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  312,  zOffset =   81, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   48,  zOffset =  105, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -312,  zOffset =  -47, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  232,  zOffset = -111, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  168,  zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset =  145, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152,  zOffset =   97, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,    xOffset =  152,  zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -56,  zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  136,  zOffset = -159, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -248,  zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  296,  zOffset =  -15, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  168,  zOffset =  129, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset =  161, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  104,  zOffset =  145, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -216,  zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -360,  zOffset =    1, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  200,  zOffset =  113, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  112,  zOffset = -103, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   40,  zOffset =  177, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -120,  zOffset =  113, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -272,  zOffset =   25, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,   xOffset =  232,  zOffset =   65, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset =  113, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  232,  zOffset =   97, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -280,  zOffset = -111, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -24,  zOffset = -159, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  296,  zOffset =  -47, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,   xOffset = -168,  zOffset =   49, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -296,  zOffset =  -79, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -152,  zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  104,  zOffset = -175, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -280,  zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -88,  zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   72,  zOffset = -191, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -184,  zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -184,  zOffset =   97, direction = 2 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  200,  zOffset = -127, direction = 2 },
		},
	}
end


local function t2HeavyFirebase5()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 110,
		buildings = {
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =    3,  zOffset =  -10, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   11,  zOffset =  110, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -53,  zOffset =  -98, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -53,  zOffset =   62, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -21,  zOffset =   94, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   91,  zOffset =  -18, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   91,  zOffset =   14, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -85,  zOffset =  -34, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -69,  zOffset =  -66, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   91,  zOffset =  -50, direction = 1 },
		},
	}
end

local function t2HeavyFirebase6()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 245,
		buildings = {
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =   19,  zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  123,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -245,  zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   -5,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -181,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  187,  zOffset =  -32, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -165,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  139,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   59,  zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -101,  zOffset = -176, direction = 1 },
			{ unitDefID = UDN.corerad_scav.id,     xOffset =  -85,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  203,  zOffset =   32, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -213,  zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,      xOffset =  -69,  zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -197,  zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  203,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  187,  zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -149,  zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  -85,  zOffset =  144, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,     xOffset =  139,  zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  219,  zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  107,  zOffset =  144, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   11,  zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -133,  zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   91,  zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -229,  zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   43,  zOffset =  176, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   27,  zOffset = -144, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset = -117,  zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =   75,  zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"),   xOffset =  171,  zOffset =  112, direction = 1 },
		}
	}
end

local function t2HeavyFirebase7()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 325,
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   -3,  zOffset =  140, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -131,  zOffset =   12, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   -3,  zOffset = -116, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  125,  zOffset =   12, direction = 1 },
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =   -3,  zOffset =   12, direction = 1 },

			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  277,  zOffset =  100, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  149,  zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  133,  zOffset =  260, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  117,  zOffset = -252, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -107,  zOffset =  292, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -235,  zOffset = -124, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  213,  zOffset =  164, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -123,  zOffset =  260, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -75,  zOffset = -268, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =   85,  zOffset =  116, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -331,  zOffset =   52, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -155,  zOffset =  228, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -139,  zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  309,  zOffset =  -76, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -219,  zOffset =  180, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  245,  zOffset = -108, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -283,  zOffset =  116, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  149,  zOffset =  196, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -107,  zOffset = -252, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  325,  zOffset =   36, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  245,  zOffset =  132, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  213,  zOffset = -172, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =  -75,  zOffset =  100, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -251,  zOffset =  148, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -283,  zOffset =   84, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  277,  zOffset =   68, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =   85,  zOffset =  -76, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  149,  zOffset =  228, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -187,  zOffset =  196, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  -91,  zOffset =  -60, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -299,  zOffset =  -92, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -315,  zOffset =   84, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  149,  zOffset = -220, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -171,  zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   85,  zOffset = -268, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  277,  zOffset = -108, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -203,  zOffset = -124, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -139,  zOffset = -220, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -203,  zOffset = -156, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  245,  zOffset = -140, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  309,  zOffset =   68, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  181,  zOffset =  196, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  181,  zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -267,  zOffset =  -92, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -123,  zOffset =  228, direction = 1 },
		}
	}
end

local function t2HeavyFirebase8()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 333,
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -75,  zOffset =  131, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -123,  zOffset =   83, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -75,  zOffset =   83, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   85,  zOffset =  -61, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  133,  zOffset =  -61, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -123,  zOffset =  131, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  133,  zOffset = -109, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   85,  zOffset = -109, direction = 1 },
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =    5,  zOffset =    3, direction = 1 },

			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   93,  zOffset = -325, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -163,  zOffset =  -53, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =  189,  zOffset =  -69, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -83,  zOffset =  299, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   61,  zOffset =  139, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -99,  zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  221,  zOffset =  -21, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -19,  zOffset = -213, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -123,  zOffset =  211, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  189,  zOffset =   11, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  269,  zOffset =  -85, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  133,  zOffset = -189, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -179,  zOffset =  -21, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -67,  zOffset = -149, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -243,  zOffset =   43, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -19,  zOffset =  235, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -259,  zOffset =   75, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  237,  zOffset =  -53, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  157,  zOffset =   43, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -211,  zOffset =   11, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -323,  zOffset =  123, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   13,  zOffset = -245, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   29,  zOffset = -277, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =   85,  zOffset = -189, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -115,  zOffset =  315, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   93,  zOffset =  107, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   29,  zOffset =  171, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -51,  zOffset =  267, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset = -179,  zOffset =  139, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset = -179,  zOffset =   91, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  189,  zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -131,  zOffset =  -85, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  -75,  zOffset =  211, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   61,  zOffset = -309, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =   13,  zOffset =  203, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -291,  zOffset =  107, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  -51,  zOffset = -181, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  125,  zOffset =   75, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  301,  zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset =  333,  zOffset = -133, direction = 1 },
		}
	}
end

return {
	t1Firebase1,
	windFarm1,
	minefield1,
	minefield2,
	minefield3,
	randomNanoTowerDuo,
	randomNanoTowerQuad,
	t3Gantry1,
	t3Gantry2,
	t2HeavyFirebase1,
	t2HeavyFirebase2,
	t2HeavyFirebase3,
	t2HeavyFirebase4,
	t2HeavyFirebase5,
	t2HeavyFirebase6,
	t2HeavyFirebase7,
	t2HeavyFirebase8,
}