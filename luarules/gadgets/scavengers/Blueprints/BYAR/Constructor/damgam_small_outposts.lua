local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
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
			{ unitDefID = UDN.armguard_scav.id,  xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    8, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =  -40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -40, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   -8, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   -8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =  -72, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armguard_scav.id,  xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    8, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -40, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  -72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   -8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   -8, yOffset = 0, zOffset =   72, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  -40, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.corpun_scav.id,    xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =   80, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corpun_scav.id,    xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =  -80, direction = 1 },
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
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   48, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   96, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =  -80, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =   80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.armwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -96, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   48, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -96, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -48, yOffset = 0, zOffset =   80, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   96, yOffset = 0, zOffset =  -80, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =   80, yOffset = 0, zOffset =   96, direction = 1 },
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
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-192,192), yOffset = 0, zOffset = math.random(-192,192), direction = 0 },
		},
	}
end

local function minefield2()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3 },
		radius = 96,
		buildings = {
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
		},
	}
end

local function minefield3()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3 },
		radius = 384,
		buildings = {
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine1_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.armmine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id, xOffset = math.random(-384,384), yOffset = 0, zOffset = math.random(-384,384), direction = 0 },
		},
	}
end

local function t1Firebase2()
	local randomTurrets = {UDN.armllt_scav.id, BPWallOrPopup("scav"), UDN.armbeamer_scav.id, UDN.armhlt_scav.id, UDN.armguard_scav.id, UDN.armrl_scav.id, UDN.armferret_scav.id, UDN.armcir_scav.id, UDN.armnanotc_scav.id, BPWallOrPopup("scav"), UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corpun_scav.id, UDN.corrl_scav.id, UDN.cormadsam_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1 },
		radius = 96,
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
		},
	}
end
		
local function t2Firebase1()
	local randomTurrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, UDN.armminivulc_scav.id, UDN.corminibuzz_scav.id, }
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius = 96,
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
		},
	}
end
		
local function t2Firebase2()
	local randomTurrets = {UDN.armamb_scav.id, UDN.armpb_scav.id, UDN.armanni_scav.id, UDN.armflak_scav.id, UDN.armmercury_scav.id, UDN.armbrtha_scav.id, UDN.armvulc_scav.id, UDN.armtarg_scav.id, UDN.armveil_scav.id, UDN.armgate_scav.id, UDN.cortoast_scav.id, UDN.corvipe_scav.id, UDN.cordoom_scav.id, UDN.corflak_scav.id, UDN.corscreamer_scav.id, UDN.corint_scav.id, UDN.corbuzz_scav.id, UDN.cortarg_scav.id, UDN.corshroud_scav.id, UDN.corgate_scav.id, UDN.corsilo_scav.id, UDN.armsilo_scav.id, UDN.cortron_scav.id, UDN.armemp_scav.id, UDN.corjuno_scav.id, UDN.armjuno_scav.id, UDN.corminibuzz_scav.id }
	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius = 96,
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
		},
	}
end
		
local function randomNanoTowerSingle()
	local unitID = getRandomNanoTowerID()

	return {
		type = types.Land,
		tiers = { tiers.T0 },
		radius = 24,
		buildings = {
			{ unitDefID = unitID, xOffset = math.random(-96,96), yOffset = 0, zOffset = math.random(-96,96), direction = 0 },
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
			{ unitDefID = unitID, xOffset =   24, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24, yOffset = 0, zOffset =    0, direction = 0 },
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
			{ unitDefID = unitID, xOffset =   24, yOffset = 0, zOffset =   24, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24, yOffset = 0, zOffset =   24, direction = 0 },
			{ unitDefID = unitID, xOffset =   24, yOffset = 0, zOffset =  -24, direction = 0 },
			{ unitDefID = unitID, xOffset =  -24, yOffset = 0, zOffset =  -24, direction = 0 },
		},
	}
end
		
local function t3Gantry1()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -112, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  112, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -112, yOffset = 0, zOffset =   16, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  112, yOffset = 0, zOffset =   16, direction = 0 },
			{ unitDefID = UDN.armgate_scav.id,   xOffset =   40, yOffset = 0, zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.armamd_scav.id,    xOffset =  -40, yOffset = 0, zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.armshltx_scav.id,  xOffset =    0, yOffset = 0, zOffset =   80, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -112, yOffset = 0, zOffset =   16, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  112, yOffset = 0, zOffset =   16, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -112, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  112, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.corgant_scav.id,   xOffset =    0, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = UDN.corgate_scav.id,   xOffset =   40, yOffset = 0, zOffset =  -24, direction = 0 },
			{ unitDefID = UDN.corfmd_scav.id,    xOffset =  -40, yOffset = 0, zOffset =  -24, direction = 0 },
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
			{ unitDefID = UDN.armapt3_scav.id,    xOffset =    0, yOffset = 0, zOffset =   20, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset = -116, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset = -196, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset =  188, yOffset = 0, zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id,  xOffset =  124, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset = -204, yOffset = 0, zOffset =   -8, direction = 3 },
			{ unitDefID = UDN.armbrtha_scav.id,   xOffset =    4, yOffset = 0, zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armgate_scav.id,    xOffset =    4, yOffset = 0, zOffset = -136, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset =  196, yOffset = 0, zOffset =   88, direction = 1 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset =  196, yOffset = 0, zOffset =   -8, direction = 1 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset = -188, yOffset = 0, zOffset =   40, direction = 3 },
			{ unitDefID = UDN.armmercury_scav.id, xOffset =  180, yOffset = 0, zOffset =   40, direction = 1 },
			{ unitDefID = UDN.armamb_scav.id,     xOffset =   60, yOffset = 0, zOffset = -144, direction = 2 },
			{ unitDefID = UDN.armamb_scav.id,     xOffset =  -52, yOffset = 0, zOffset = -144, direction = 2 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset = -108, yOffset = 0, zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armanni_scav.id,    xOffset =  116, yOffset = 0, zOffset =  184, direction = 0 },
			{ unitDefID = UDN.armflak_scav.id,    xOffset = -204, yOffset = 0, zOffset =   88, direction = 3 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corapt3_scav.id,     xOffset =    1, yOffset = 0, zOffset =   11, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -96, yOffset = 0, zOffset = -140, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  192, yOffset = 0, zOffset =  -60, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -192, yOffset = 0, zOffset =  -60, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   96, yOffset = 0, zOffset = -140, direction = 0 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset =  104, yOffset = 0, zOffset =  172, direction = 0 },
			{ unitDefID = UDN.corint_scav.id,      xOffset =    0, yOffset = 0, zOffset =  180, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset = -200, yOffset = 0, zOffset =   76, direction = 3 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset = -184, yOffset = 0, zOffset =   28, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id,     xOffset = -104, yOffset = 0, zOffset =  172, direction = 0 },
			{ unitDefID = UDN.cortoast_scav.id,    xOffset =   32, yOffset = 0, zOffset = -140, direction = 2 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset =  200, yOffset = 0, zOffset =  -20, direction = 1 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset =  200, yOffset = 0, zOffset =   76, direction = 1 },
			{ unitDefID = UDN.corgate_scav.id,     xOffset =  -24, yOffset = 0, zOffset = -148, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,     xOffset = -200, yOffset = 0, zOffset =  -20, direction = 3 },
			{ unitDefID = UDN.corscreamer_scav.id, xOffset =  184, yOffset = 0, zOffset =   28, direction = 1 },
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
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -14, yOffset = 0, zOffset =   13, direction = 0 },		
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   26, yOffset = 0, zOffset =  -91, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   90, yOffset = 0, zOffset =  -59, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   26, yOffset = 0, zOffset =  101, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -134, yOffset = 0, zOffset =   53, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -86, yOffset = 0, zOffset =  -43, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   58, yOffset = 0, zOffset =  -75, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   58, yOffset = 0, zOffset =   85, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  122, yOffset = 0, zOffset =   53, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   90, yOffset = 0, zOffset =   69, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -118, yOffset = 0, zOffset =   21, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -102, yOffset = 0, zOffset =  -11, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   -6, yOffset = 0, zOffset = -107, direction = 2 },
		},
	}
end

local function t2HeavyFirebase2()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 172,
		buildings = {
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -14, yOffset = 0, zOffset =   20, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  138, yOffset = 0, zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  138, yOffset = 0, zOffset =   12, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  138, yOffset = 0, zOffset =   76, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -102, yOffset = 0, zOffset =  156, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   10, yOffset = 0, zOffset = -100, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -150, yOffset = 0, zOffset =  -52, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -70, yOffset = 0, zOffset =  156, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   -6, yOffset = 0, zOffset =  172, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -134, yOffset = 0, zOffset =  -84, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -38, yOffset = 0, zOffset =  172, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   74, yOffset = 0, zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  138, yOffset = 0, zOffset =   44, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  122, yOffset = 0, zOffset =  108, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -118, yOffset = 0, zOffset = -116, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  122, yOffset = 0, zOffset =  -20, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -134, yOffset = 0, zOffset =  140, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   42, yOffset = 0, zOffset = -116, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -166, yOffset = 0, zOffset =  -20, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -86, yOffset = 0, zOffset = -132, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  106, yOffset = 0, zOffset = -148, direction = 2 },
		},
	}
end

local function t2HeavyFirebase3()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 196,
		buildings = {
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =   -4, yOffset = 0, zOffset =  -11, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  148, yOffset = 0, zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  100, yOffset = 0, zOffset = -131, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  212, yOffset = 0, zOffset =   13, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -12, yOffset = 0, zOffset = -163, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  132, yOffset = 0, zOffset = -131, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  180, yOffset = 0, zOffset =   93, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -172, yOffset = 0, zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -140, yOffset = 0, zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -172, yOffset = 0, zOffset =  -35, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -124, yOffset = 0, zOffset =   93, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,      xOffset =  180, yOffset = 0, zOffset = -115, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id,   xOffset = -132, yOffset = 0, zOffset = -107, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  180, yOffset = 0, zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  132, yOffset = 0, zOffset =  -99, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,     xOffset =  -92, yOffset = 0, zOffset =   93, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,      xOffset = -172, yOffset = 0, zOffset =  109, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -44, yOffset = 0, zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -156, yOffset = 0, zOffset =   29, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -108, yOffset = 0, zOffset = -147, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -124, yOffset = 0, zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  180, yOffset = 0, zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   20, yOffset = 0, zOffset =  173, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -12, yOffset = 0, zOffset =  157, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -172, yOffset = 0, zOffset =   -3, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id,   xOffset =  140, yOffset = 0, zOffset =  117, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   20, yOffset = 0, zOffset = -179, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -172, yOffset = 0, zOffset = -115, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,     xOffset =  100, yOffset = 0, zOffset =  -99, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -172, yOffset = 0, zOffset =  -83, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  196, yOffset = 0, zOffset =  -19, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   52, yOffset = 0, zOffset =  173, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -92, yOffset = 0, zOffset =  125, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  116, yOffset = 0, zOffset =  157, direction = 2 },
		},
	}
end

local function t2HeavyFirebase4()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 328,
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -208, yOffset = 0, zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  160, yOffset = 0, zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -160, yOffset = 0, zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -208, yOffset = 0, zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  160, yOffset = 0, zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  208, yOffset = 0, zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset = -160, yOffset = 0, zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id,   xOffset =  208, yOffset = 0, zOffset =    9, direction = 2 },
			{ unitDefID = UDN.armminivulc_scav.id, xOffset =  -16, yOffset = 0, zOffset =   -7, direction = 2 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset =  312, yOffset = 0, zOffset =   49, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  312, yOffset = 0, zOffset =   17, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    8, yOffset = 0, zOffset =  177, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -328, yOffset = 0, zOffset =  -15, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  312, yOffset = 0, zOffset =   81, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   48, yOffset = 0, zOffset =  105, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -312, yOffset = 0, zOffset =  -47, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  232, yOffset = 0, zOffset = -111, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  168, yOffset = 0, zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  145, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -152, yOffset = 0, zOffset =   97, direction = 2 },
			{ unitDefID = UDN.armrad_scav.id,    xOffset =  152, yOffset = 0, zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -56, yOffset = 0, zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -159, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -248, yOffset = 0, zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  296, yOffset = 0, zOffset =  -15, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  168, yOffset = 0, zOffset =  129, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  161, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  145, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -216, yOffset = 0, zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -120, yOffset = 0, zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -360, yOffset = 0, zOffset =    1, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  200, yOffset = 0, zOffset =  113, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  112, yOffset = 0, zOffset = -103, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =  177, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -120, yOffset = 0, zOffset =  113, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -272, yOffset = 0, zOffset =   25, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,   xOffset =  232, yOffset = 0, zOffset =   65, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -88, yOffset = 0, zOffset =  113, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  232, yOffset = 0, zOffset =   97, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -280, yOffset = 0, zOffset = -111, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -24, yOffset = 0, zOffset = -159, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  296, yOffset = 0, zOffset =  -47, direction = 2 },
			{ unitDefID = UDN.armjamt_scav.id,   xOffset = -168, yOffset = 0, zOffset =   49, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -296, yOffset = 0, zOffset =  -79, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -152, yOffset = 0, zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset = -175, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -280, yOffset = 0, zOffset =   81, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -88, yOffset = 0, zOffset = -143, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset = -191, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -184, yOffset = 0, zOffset = -127, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -184, yOffset = 0, zOffset =   97, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  200, yOffset = 0, zOffset = -127, direction = 2 },
		},
	}
end


local function t2HeavyFirebase5()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 110,
		buildings = {
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =    3, yOffset = 0, zOffset =  -10, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   11, yOffset = 0, zOffset =  110, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -53, yOffset = 0, zOffset =  -98, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -53, yOffset = 0, zOffset =   62, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -21, yOffset = 0, zOffset =   94, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   91, yOffset = 0, zOffset =  -18, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   91, yOffset = 0, zOffset =   14, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -85, yOffset = 0, zOffset =  -34, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -69, yOffset = 0, zOffset =  -66, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   91, yOffset = 0, zOffset =  -50, direction = 1 },
		},
	}
end

local function t2HeavyFirebase6()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 245,
		buildings = {
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =   19, yOffset = 0, zOffset =    8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  123, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -245, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   -5, yOffset = 0, zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -181, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  187, yOffset = 0, zOffset =  -32, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -165, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  139, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   59, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -101, yOffset = 0, zOffset = -176, direction = 1 },
			{ unitDefID = UDN.corerad_scav.id,     xOffset =  -85, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  203, yOffset = 0, zOffset =   32, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -213, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,      xOffset =  -69, yOffset = 0, zOffset =  -96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -197, yOffset = 0, zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  203, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  187, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -149, yOffset = 0, zOffset =   96, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  -85, yOffset = 0, zOffset =  144, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,     xOffset =  139, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  219, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  107, yOffset = 0, zOffset =  144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   11, yOffset = 0, zOffset =  192, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -133, yOffset = 0, zOffset = -160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   91, yOffset = 0, zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -229, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   43, yOffset = 0, zOffset =  176, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   27, yOffset = 0, zOffset = -144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset = -117, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =   75, yOffset = 0, zOffset =  160, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),   xOffset =  171, yOffset = 0, zOffset =  112, direction = 1 },
		}
	}
end

local function t2HeavyFirebase7()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 325,
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   -3, yOffset = 0, zOffset =  140, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -131, yOffset = 0, zOffset =   12, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   -3, yOffset = 0, zOffset = -116, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  125, yOffset = 0, zOffset =   12, direction = 1 },
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =   -3, yOffset = 0, zOffset =   12, direction = 1 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset =  277, yOffset = 0, zOffset =  100, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  149, yOffset = 0, zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  133, yOffset = 0, zOffset =  260, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  117, yOffset = 0, zOffset = -252, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -107, yOffset = 0, zOffset =  292, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -235, yOffset = 0, zOffset = -124, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  213, yOffset = 0, zOffset =  164, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -123, yOffset = 0, zOffset =  260, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -75, yOffset = 0, zOffset = -268, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =   85, yOffset = 0, zOffset =  116, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -331, yOffset = 0, zOffset =   52, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -155, yOffset = 0, zOffset =  228, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -139, yOffset = 0, zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  309, yOffset = 0, zOffset =  -76, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -219, yOffset = 0, zOffset =  180, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  245, yOffset = 0, zOffset = -108, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -283, yOffset = 0, zOffset =  116, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  149, yOffset = 0, zOffset =  196, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -107, yOffset = 0, zOffset = -252, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  325, yOffset = 0, zOffset =   36, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  245, yOffset = 0, zOffset =  132, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  213, yOffset = 0, zOffset = -172, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =  -75, yOffset = 0, zOffset =  100, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -251, yOffset = 0, zOffset =  148, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -283, yOffset = 0, zOffset =   84, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  277, yOffset = 0, zOffset =   68, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =   85, yOffset = 0, zOffset =  -76, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  149, yOffset = 0, zOffset =  228, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -187, yOffset = 0, zOffset =  196, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  -91, yOffset = 0, zOffset =  -60, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -299, yOffset = 0, zOffset =  -92, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -315, yOffset = 0, zOffset =   84, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  149, yOffset = 0, zOffset = -220, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -171, yOffset = 0, zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   85, yOffset = 0, zOffset = -268, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  277, yOffset = 0, zOffset = -108, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -203, yOffset = 0, zOffset = -124, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -139, yOffset = 0, zOffset = -220, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -203, yOffset = 0, zOffset = -156, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  245, yOffset = 0, zOffset = -140, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  309, yOffset = 0, zOffset =   68, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  181, yOffset = 0, zOffset =  196, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  181, yOffset = 0, zOffset = -188, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -267, yOffset = 0, zOffset =  -92, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -123, yOffset = 0, zOffset =  228, direction = 1 },
		}
	}
end

local function t2HeavyFirebase8()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 333,
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -75, yOffset = 0, zOffset =  131, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -123, yOffset = 0, zOffset =   83, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  -75, yOffset = 0, zOffset =   83, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   85, yOffset = 0, zOffset =  -61, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  133, yOffset = 0, zOffset =  -61, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset = -123, yOffset = 0, zOffset =  131, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =  133, yOffset = 0, zOffset = -109, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id,   xOffset =   85, yOffset = 0, zOffset = -109, direction = 1 },
			{ unitDefID = UDN.corminibuzz_scav.id, xOffset =    5, yOffset = 0, zOffset =    3, direction = 1 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset =   93, yOffset = 0, zOffset = -325, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -163, yOffset = 0, zOffset =  -53, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =  189, yOffset = 0, zOffset =  -69, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -83, yOffset = 0, zOffset =  299, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   61, yOffset = 0, zOffset =  139, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -99, yOffset = 0, zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  221, yOffset = 0, zOffset =  -21, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -19, yOffset = 0, zOffset = -213, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -123, yOffset = 0, zOffset =  211, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  189, yOffset = 0, zOffset =   11, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  269, yOffset = 0, zOffset =  -85, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  133, yOffset = 0, zOffset = -189, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -179, yOffset = 0, zOffset =  -21, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -67, yOffset = 0, zOffset = -149, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -243, yOffset = 0, zOffset =   43, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -19, yOffset = 0, zOffset =  235, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -259, yOffset = 0, zOffset =   75, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  237, yOffset = 0, zOffset =  -53, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  157, yOffset = 0, zOffset =   43, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -211, yOffset = 0, zOffset =   11, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -323, yOffset = 0, zOffset =  123, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   13, yOffset = 0, zOffset = -245, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   29, yOffset = 0, zOffset = -277, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =   85, yOffset = 0, zOffset = -189, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -115, yOffset = 0, zOffset =  315, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   93, yOffset = 0, zOffset =  107, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   29, yOffset = 0, zOffset =  171, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -51, yOffset = 0, zOffset =  267, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset = -179, yOffset = 0, zOffset =  139, direction = 1 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset = -179, yOffset = 0, zOffset =   91, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  189, yOffset = 0, zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -131, yOffset = 0, zOffset =  -85, direction = 1 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  -75, yOffset = 0, zOffset =  211, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   61, yOffset = 0, zOffset = -309, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   13, yOffset = 0, zOffset =  203, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -291, yOffset = 0, zOffset =  107, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -51, yOffset = 0, zOffset = -181, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  125, yOffset = 0, zOffset =   75, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  301, yOffset = 0, zOffset = -117, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  333, yOffset = 0, zOffset = -133, direction = 1 },
		}
	}
end

return {
	t1Firebase1,
	windFarm1,
	minefield1,
	minefield2,
	minefield3,
	t1Firebase2,
	t2Firebase1,
	t2Firebase2,
	randomNanoTowerSingle,
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