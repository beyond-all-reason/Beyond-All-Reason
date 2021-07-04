local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

-- FACTORIES
local function t1FactoryBase1()
	local buildings
	local r = math.random(0,5)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =   64, yOffset = 0, zOffset =    3, direction = 1 },
			{ unitDefID = UDN.cormstor_scav.id,  xOffset =  120, yOffset = 0, zOffset =   75, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -104, yOffset = 0, zOffset =   11, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  144, yOffset = 0, zOffset =  -29, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -80, yOffset = 0, zOffset =  131, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  -64, yOffset = 0, zOffset =    3, direction = 1 },
			{ unitDefID = UDN.corerad_scav.id,   xOffset =    0, yOffset = 0, zOffset =  -93, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   80, yOffset = 0, zOffset =  131, direction = 1 },
			{ unitDefID = UDN.cormstor_scav.id,  xOffset = -120, yOffset = 0, zOffset =   75, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,    xOffset =    0, yOffset = 0, zOffset = -173, direction = 2 },
			{ unitDefID = UDN.corlab_scav.id,    xOffset =    0, yOffset = 0, zOffset =   67, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  104, yOffset = 0, zOffset =   11, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -144, yOffset = 0, zOffset =  -29, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset = -125, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset =   99, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset =   67, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset =   35, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   64, yOffset = 0, zOffset =   35, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset = -141, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =    3, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset =   67, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset =   99, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  112, yOffset = 0, zOffset =  -29, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -112, yOffset = 0, zOffset =  -29, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset = -125, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset = -141, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =    3, direction = 0 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armlab_scav.id, xOffset = 0, yOffset = 0, zOffset = 0, direction = math.random(0,3) },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -80, yOffset = 0, zOffset =  -90, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   62, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   94, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  144, yOffset = 0, zOffset =   86, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   62, direction = 0 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -144, yOffset = 0, zOffset =   86, direction = 0 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset =  104, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   80, yOffset = 0, zOffset =  -90, direction = 0 },
			{ unitDefID = UDN.corvp_scav.id,     xOffset =    0, yOffset = 0, zOffset =   54, direction = 0 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = -104, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   94, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -40, yOffset = 0, zOffset =  -82, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =  -82, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -40, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  -50, direction = 0 },
		}
	elseif r == 3 then
		buildings = {
			{ unitDefID = UDN.armvp_scav.id, xOffset = 0, yOffset = 0, zOffset = 0, direction = math.random(0,3) },
		}
	elseif r == 4 then
		buildings = {
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =   25, yOffset = 0, zOffset = -159, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   81, yOffset = 0, zOffset =   25, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   65, yOffset = 0, zOffset = -183, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   65, yOffset = 0, zOffset =  185, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id,    xOffset =  113, yOffset = 0, zOffset =    9, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -63, yOffset = 0, zOffset =  -87, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   81, yOffset = 0, zOffset =   -7, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   33, yOffset = 0, zOffset = -199, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   81, yOffset = 0, zOffset =  -39, direction = 2 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -127, yOffset = 0, zOffset =  -23, direction = 3 },
			{ unitDefID = UDN.corap_scav.id,     xOffset =  -31, yOffset = 0, zOffset =    9, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   33, yOffset = 0, zOffset =  201, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -23, yOffset = 0, zOffset =  -63, direction = 0 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =  -63, yOffset = 0, zOffset =  -55, direction = 0 },
			{ unitDefID = UDN.corjamt_scav.id,   xOffset =  -63, yOffset = 0, zOffset =   73, direction = 0 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =   25, yOffset = 0, zOffset =  161, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   81, yOffset = 0, zOffset =   57, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -95, yOffset = 0, zOffset =  -55, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -127, yOffset = 0, zOffset =  -55, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   65, yOffset = 0, zOffset = -151, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -63, yOffset = 0, zOffset =  105, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -31, yOffset = 0, zOffset =   89, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   65, yOffset = 0, zOffset =  153, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -159, yOffset = 0, zOffset =  -55, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  113, yOffset = 0, zOffset =  -23, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  113, yOffset = 0, zOffset =   41, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -175, yOffset = 0, zOffset =  -23, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -111, yOffset = 0, zOffset =   57, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -95, yOffset = 0, zOffset =   89, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  145, yOffset = 0, zOffset =   -7, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -95, yOffset = 0, zOffset =  -87, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    1, yOffset = 0, zOffset = -199, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  145, yOffset = 0, zOffset =   25, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    1, yOffset = 0, zOffset =  201, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armap_scav.id, xOffset = 0, yOffset = 0, zOffset = 0, direction = math.random(0,3) },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, },
		radius = 120,
		buildings = buildings,
	}
end

local function t2Factory()
	local randomFactoryID = {
		UDN.coralab_scav.id,
		UDN.armalab_scav.id,
		UDN.coravp_scav.id,
		UDN.armavp_scav.id,
		UDN.coraap_scav.id,
		UDN.armaap_scav.id,
	}

	local r = math.random(1, #randomFactoryID)

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 70,
		buildings = {
			{ unitDefID = randomFactoryID[r], xOffset = 0, yOffset = 0, zOffset = 0, direction = math.random(0,3) },
		},
	}
end

-- ECO BUILDINGS

local function t1Metal1()
return {
	type = types.Land,
	tiers = { tiers.T0, tiers.T1, },
	radius = 88,
	buildings = {
		{ unitDefID = UDN.cormakr_scav.id, xOffset = -32, yOffset = 0, zOffset = -32, direction = 0 },
		{ unitDefID = UDN.cormakr_scav.id, xOffset =  32, yOffset = 0, zOffset = -32, direction = 0 },
		{ unitDefID = UDN.cormakr_scav.id, xOffset = -32, yOffset = 0, zOffset =  32, direction = 0 },
		{ unitDefID = UDN.cormakr_scav.id, xOffset =  32, yOffset = 0, zOffset =  32, direction = 0 },

		{ unitDefID = BPWallOrPopup("scav"), xOffset = -72, yOffset = 0, zOffset = -72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset = -40, yOffset = 0, zOffset = -72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  -8, yOffset = 0, zOffset = -72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset = -72, yOffset = 0, zOffset = -40, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset = -72, yOffset = 0, zOffset =  -8, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  72, yOffset = 0, zOffset =  72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  72, yOffset = 0, zOffset =  40, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  72, yOffset = 0, zOffset =   8, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  40, yOffset = 0, zOffset =  72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =   8, yOffset = 0, zOffset =  72, direction = 0 },
	},
}
end

local function t1Resources1()
return {
	type = types.Land,
	tiers = { tiers.T2, tiers.T3, },
	radius = 120,
	buildings = {
		{ unitDefID = UDN.cormmkr_scav.id,   xOffset =  -40, yOffset = 0, zOffset =  -40, direction = 0 },
		{ unitDefID = UDN.cormmkr_scav.id,   xOffset =   40, yOffset = 0, zOffset =   40, direction = 0 },
		{ unitDefID = UDN.coradvsol_scav.id, xOffset =  -40, yOffset = 0, zOffset =   40, direction = 0 },
		{ unitDefID = UDN.coradvsol_scav.id, xOffset =   40, yOffset = 0, zOffset =  -40, direction = 0 },

		{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset = -104, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset = -104, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  -40, yOffset = 0, zOffset = -104, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset =  -72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset =  -40, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  104, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =   72, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =   40, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  104, direction = 0 },
		{ unitDefID = BPWallOrPopup("scav"), xOffset =   40, yOffset = 0, zOffset =  104, direction = 0 },
		},
	}
end

local function t1Resources2()
	local buildings
	local r = math.random(0,2)

	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corsolar_scav.id, xOffset =   0, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id, xOffset =  80, yOffset = 0, zOffset = -80, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id, xOffset = -80, yOffset = 0, zOffset =  80, direction = 1 },

			{ unitDefID = UDN.cormakr_scav.id, xOffset =  -16, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset =   64, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset =   16, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset =  -64, yOffset = 0, zOffset =   16, direction = 1 },

			{ unitDefID = UDN.corwin_scav.id, xOffset = -80, yOffset = 0, zOffset = -96, direction = 1 },
			{ unitDefID = UDN.corwin_scav.id, xOffset =  80, yOffset = 0, zOffset =  96, direction = 1 },

			{ unitDefID = UDN.corrl_scav.id, xOffset = -144, yOffset = 0, zOffset =  144, direction = 3 },
			{ unitDefID = UDN.corrl_scav.id, xOffset =  144, yOffset = 0, zOffset = -144, direction = 1 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  -8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   72, yOffset = 0, zOffset =  24, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset = -24, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset =   8, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -72, yOffset = 0, zOffset = -24, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.corsolar_scav.id, xOffset = -40, yOffset = 0, zOffset = -40, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id, xOffset =  40, yOffset = 0, zOffset =  40, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id, xOffset =  40, yOffset = 0, zOffset = -40, direction = 1 },
			{ unitDefID = UDN.corsolar_scav.id, xOffset = -40, yOffset = 0, zOffset =  40, direction = 1 },

			{ unitDefID = UDN.cormakr_scav.id, xOffset =  104, yOffset = 0, zOffset =   -8, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset =   -8, yOffset = 0, zOffset = -104, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset =    8, yOffset = 0, zOffset =  104, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id, xOffset = -104, yOffset = 0, zOffset =    8, direction = 1 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  112, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =  -48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset = -144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset = -112, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset = -144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset = -144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -112, yOffset = 0, zOffset =   48, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =  112, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =  144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =  144, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =  144, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset = -40, yOffset = 0, zOffset =   40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  64, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -64, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset =  40, yOffset = 0, zOffset =  -40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =  -64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =   32, direction = 1 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset =  40, yOffset = 0, zOffset =   40, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,    xOffset =   0, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset = -40, yOffset = 0, zOffset =  -40, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corllt_scav.id,    xOffset =   0, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =  -32, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		radius = 96,
		buildings = buildings,
	}
end

local function t1MetalStore1()
	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, tiers.T3, },
		radius = 96,
		buildings = {
			{ unitDefID = UDN.cormstor_scav.id, xOffset = -40, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = UDN.cormstor_scav.id, xOffset =  40, yOffset = 0, zOffset = 0, direction = 0 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset = -96, yOffset = 0, zOffset = -80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -96, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -64, yOffset = 0, zOffset = -80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  96, yOffset = 0, zOffset =  80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  96, yOffset = 0, zOffset =  48, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  64, yOffset = 0, zOffset =  80, direction = 0 },
		},
	}
end

-- SMALL RADAR OUTPOSTS

local function t1RadarBase1()
	local randomTurrets = { UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.cornanotc_scav.id, }
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corrad_scav.id, xOffset = 0, yOffset = 0, zOffset = 0, direction = 0 },

			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -88, yOffset = 0, zOffset =   0, direction = 3 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  88, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset = -88, direction = 2 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset =  88, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = UDN.corrad_scav.id,    xOffset =   0, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset =   0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -16, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  16, yOffset = 0, zOffset = -32, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  16, yOffset = 0, zOffset =  32, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -16, yOffset = 0, zOffset = -32, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		radius = 88,
		buildings = buildings,
	}
end

local function t1IntelBase1()
	local randomIntel = { UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corwin_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id, }
	local randomTurrets = { UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corrl_scav.id, }

	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		radius = 70,
		buildings = {
			{ unitDefID = UDN.corjamt_scav.id, xOffset = 40, yOffset = 0, zOffset =  0, direction = 1 },

			{ unitDefID = randomIntel[math.random(1, #randomIntel)],     xOffset = -40, yOffset = 0, zOffset =  0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset = 60, direction = 3 },
		},
	}
end

-- ROADBLOCKS

local function t1Barriers()
	local buildings
	local r = math.random(0,3)
	if r == 0 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -64, yOffset = 0, zOffset = -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  64, yOffset = 0, zOffset =  64, direction = 0 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -64, yOffset = 0, zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  64, yOffset = 0, zOffset = -64, direction = 0 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -64, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  64, yOffset = 0, zOffset = 0, direction = 0 },
		}
	elseif r == 3 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset = 0, yOffset = 0, zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = 0, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = 0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = 0, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = 0, yOffset = 0, zOffset = -64, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		radius = 80,
		buildings = buildings,
	}
end

-- WALL OF TURRETS (lines)

local function t1Firebase1()
	local randomTurrets = { UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, }
	local buildings
	local r = math.random(0,3)
	if r == 0 then
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -64, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  64, yOffset = 0, zOffset = -32, direction = 0 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -32, yOffset = 0, zOffset =  64, direction = 1 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset =   0, direction = 3 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  32, yOffset = 0, zOffset = -64, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -96, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -32, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  32, yOffset = 0, zOffset = 0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  96, yOffset = 0, zOffset = 0, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = 0, yOffset = 0, zOffset = -96, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = 0, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = 0, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = 0, yOffset = 0, zOffset =  96, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, },
		radius = 112,
		buildings = buildings,
	}
end

local function t2Firebase1()
	local unitoptions = { UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, }
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset =  100, yOffset = 0, zOffset = -60, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id,                        xOffset =   50, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset =    0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id,                        xOffset =  -50, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset = -100, yOffset = 0, zOffset =  60, direction = 0 },
		}		
	else
		buildings = {
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset =  60, yOffset = 0, zOffset = -100, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id,                        xOffset =  32, yOffset = 0, zOffset =  -50, direction = 0 },
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset =   0, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id,                        xOffset = -32, yOffset = 0, zOffset =   50, direction = 0 },
			{ unitDefID = unitoptions[math.random(1, #unitoptions)], xOffset = -60, yOffset = 0, zOffset =  100, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 100,
		buildings = buildings,
	}
end

local function t1Energy1()
	local randomTurretsCor = {UDN.corllt_scav.id, UDN.corrad_scav.id, UDN.corjamt_scav.id,}
	local randomTurretsArm = {UDN.armllt_scav.id, UDN.armrad_scav.id, UDN.armjamt_scav.id,}
	local buildings
	local r = math.random(0,1)
	local x1 = math.random(-48,48)
	local x2 = math.random(-48,48)

	if r == 0 then
		buildings = {
			{ unitDefID = randomTurretsCor[math.random(1, #randomTurretsCor)], xOffset =   x1, yOffset = 0, zOffset = -120, direction = 0 },
			{ unitDefID = UDN.coradvsol_scav.id,                               xOffset =  -40, yOffset = 0, zOffset =  -40, direction = 0 },
			{ unitDefID = UDN.coradvsol_scav.id,                               xOffset =   40, yOffset = 0, zOffset =  -40, direction = 0 },
			{ unitDefID = UDN.coradvsol_scav.id,                               xOffset =  -40, yOffset = 0, zOffset =   40, direction = 0 },
			{ unitDefID = UDN.coradvsol_scav.id,                               xOffset =   40, yOffset = 0, zOffset =   40, direction = 0 },
			{ unitDefID = randomTurretsCor[math.random(1, #randomTurretsCor)], xOffset =   x2, yOffset = 0, zOffset =  120, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = randomTurretsArm[math.random(1, #randomTurretsArm)], xOffset =   x1, yOffset = 0, zOffset = -112, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id,                               xOffset =  -32, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id,                               xOffset =   32, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id,                               xOffset =  -32, yOffset = 0, zOffset =   32, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id,                               xOffset =   32, yOffset = 0, zOffset =   32, direction = 0 },
			{ unitDefID = randomTurretsArm[math.random(1, #randomTurretsArm)], xOffset =   x2, yOffset = 0, zOffset =  112, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		radius = 112,
		buildings = buildings,
	}
end

-- MEDIUM RADAR OUTPOSTS

local function t1IntelBase2()
	local randomTurrets = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		radius = 128,
		buildings = {
			{ unitDefID = UDN.corjamt_scav.id, xOffset = 96, yOffset = 0, zOffset = 0, direction = 3 },
			{ unitDefID = UDN.corrad_scav.id,  xOffset =  0, yOffset = 0, zOffset = 0, direction = 0 },

			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -96, yOffset = 0, zOffset =   0, direction = 3 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset = -96, direction = 2 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   0, yOffset = 0, zOffset =  96, direction = 0 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset =  32, direction = 0 },			
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset = -32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   96, yOffset = 0, zOffset =  32, direction = 0 },
		},
	}
end

local function t1Firebase2()
	local randomTurrets = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2, },
		radius = 100,
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  100, yOffset = 0, zOffset =  25, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id,                            xOffset =    0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -100, yOffset = 0, zOffset = -25, direction = 0 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset =  112, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -32, yOffset = 0, zOffset = -112, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   0, yOffset = 0, zOffset =  -96, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  32, yOffset = 0, zOffset =  -80, direction = 0 },
		},
	}
end

-- MEDIUM ARTILLERY BASES

local function t2Firebase2()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 128,
		buildings = {
			{ unitDefID = UDN.corvipe_scav.id,  xOffset =  25, yOffset = 0, zOffset =  100, direction = 3 },
			{ unitDefID = UDN.cortoast_scav.id, xOffset =   0, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corarad_scav.id,  xOffset = -25, yOffset = 0, zOffset = -128, direction = 0 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset = -128, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -96, yOffset = 0, zOffset =  32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -64, yOffset = 0, zOffset =  64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  192, yOffset = 0, zOffset = 128, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  160, yOffset = 0, zOffset =  96, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  128, yOffset = 0, zOffset =  64, direction = 0 },
		},
	}
end

-- JAMMED AA BASES

local function t2Firebase3()
	local randomTurrets = {UDN.corarad_scav.id, UDN.corvipe_scav.id, UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.cormadsam_scav.id,}
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corflak_scav.id,   xOffset = -48, yOffset = 0, zOffset = -48, direction = 3 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =  48, yOffset = 0, zOffset =  48, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset = -48, yOffset = 0, zOffset =  48, direction = 0 },

			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   48, yOffset = 0, zOffset =  -48, direction = 2 },

			{ unitDefID = BPWallOrPopup("scav"), xOffset = -80, yOffset = 0, zOffset =  48, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -80, yOffset = 0, zOffset =  80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -48, yOffset = 0, zOffset =  80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  80, yOffset = 0, zOffset = -48, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  80, yOffset = 0, zOffset = -80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  48, yOffset = 0, zOffset = -80, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corfmd_scav.id,     xOffset =  -93, yOffset = 0, zOffset =   -1, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   35, yOffset = 0, zOffset =   15, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -77, yOffset = 0, zOffset =  -49, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   35, yOffset = 0, zOffset =  111, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -109, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = UDN.coruwadvms_scav.id, xOffset =   83, yOffset = 0, zOffset =   63, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -141, yOffset = 0, zOffset =   15, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -45, yOffset = 0, zOffset =   15, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   19, yOffset = 0, zOffset =  -81, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -45, yOffset = 0, zOffset =  -17, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   19, yOffset = 0, zOffset = -145, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  131, yOffset = 0, zOffset =  111, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  131, yOffset = 0, zOffset =   15, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -141, yOffset = 0, zOffset =  -17, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -77, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -109, yOffset = 0, zOffset =  -49, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id,  xOffset =   19, yOffset = 0, zOffset = -113, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   99, yOffset = 0, zOffset =   15, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -13, yOffset = 0, zOffset =  -97, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -141, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   35, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  131, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -45, yOffset = 0, zOffset =  -49, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  131, yOffset = 0, zOffset =   79, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   35, yOffset = 0, zOffset =   79, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   51, yOffset = 0, zOffset = -129, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -45, yOffset = 0, zOffset =   47, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   99, yOffset = 0, zOffset =  111, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   67, yOffset = 0, zOffset =  111, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   51, yOffset = 0, zOffset =  -97, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset = -141, yOffset = 0, zOffset =  -49, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =  -13, yOffset = 0, zOffset = -129, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),  xOffset =   67, yOffset = 0, zOffset =   15, direction = 1 },
		}
	end
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 120,
		buildings = buildings,
	}
end

-- CLOAKED BASES

local function t2Firebase4()
	local randomTurrets = {UDN.corvipe_scav.id, UDN.armferret_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 64,
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -48, yOffset = 0, zOffset =  16, direction = 3 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  48, yOffset = 0, zOffset = -16, direction = 1 },
		},
	}
end

-- BIG BASES

local function t2HeavyFirebase1()
	local randomIntel = {UDN.corrad_scav.id, UDN.corarad_scav.id, UDN.corshroud_scav.id, UDN.cornanotc_scav.id, UDN.armtarg_scav.id,}
	local randomTurrets = {UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	local buildings
	local r = math.random(0,2)
	if r == 0 then
		buildings = {
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  -56, yOffset = 0, zOffset =   56, direction = 0 },
			{ unitDefID = UDN.cordoom_scav.id,                           xOffset =   40, yOffset = 0, zOffset =  -16, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = -100, yOffset = 0, zOffset = -140, direction = 2 },
			{ unitDefID = randomIntel[math.random(1, #randomIntel)],     xOffset =  -20, yOffset = 0, zOffset = -100, direction = 2 },
			{ unitDefID = randomIntel[math.random(1, #randomIntel)],     xOffset =   60, yOffset = 0, zOffset = -100, direction = 2 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  240, yOffset = 0, zOffset = -260, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  140, yOffset = 0, zOffset =   56, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -128, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -128, yOffset = 0, zOffset =   96, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -128, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -96, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -64, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  160, yOffset = 0, zOffset = -192, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  128, yOffset = 0, zOffset = -192, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   96, yOffset = 0, zOffset = -192, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  160, yOffset = 0, zOffset = -160, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  160, yOffset = 0, zOffset = -128, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  240, yOffset = 0, zOffset = -260, direction = 0 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   32, yOffset = 0, zOffset =  -45, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -32, yOffset = 0, zOffset =   51, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =  -13, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =  -13, direction = 0 },
			{ unitDefID = UDN.cordoom_scav.id,   xOffset =    0, yOffset = 0, zOffset =    3, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset = -104, yOffset = 0, zOffset =   91, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  104, yOffset = 0, zOffset = -101, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =   19, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    0, yOffset = 0, zOffset =   51, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -32, yOffset = 0, zOffset =  -45, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  104, yOffset = 0, zOffset =   91, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    0, yOffset = 0, zOffset =  -45, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   32, yOffset = 0, zOffset =   51, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =   19, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.corerad_scav.id,   xOffset =  128, yOffset = 0, zOffset = -128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  176, yOffset = 0, zOffset =  208, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   56, yOffset = 0, zOffset =   56, direction = 2 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset =  -48, yOffset = 0, zOffset =   48, direction = 2 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset = -128, yOffset = 0, zOffset = -192, direction = 2 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset =   48, yOffset = 0, zOffset =  -48, direction = 2 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset = -184, yOffset = 0, zOffset =  184, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  176, yOffset = 0, zOffset = -144, direction = 2 },
			{ unitDefID = UDN.corerad_scav.id,   xOffset = -128, yOffset = 0, zOffset =  128, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  208, yOffset = 0, zOffset =  176, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -112, yOffset = 0, zOffset =  176, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =   48, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -176, yOffset = 0, zOffset =  144, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  208, yOffset = 0, zOffset =   16, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset =  192, yOffset = 0, zOffset =  128, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =  -48, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =  176, direction = 2 },
			{ unitDefID = UDN.cordoom_scav.id,   xOffset =  128, yOffset = 0, zOffset =  128, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  -16, yOffset = 0, zOffset =  176, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -56, yOffset = 0, zOffset =  -56, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -208, yOffset = 0, zOffset = -176, direction = 2 },
			{ unitDefID = UDN.corhlt_scav.id,    xOffset =  176, yOffset = 0, zOffset =   16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset = -144, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset =  128, yOffset = 0, zOffset =  192, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =  -48, direction = 2 },
			{ unitDefID = UDN.corhlt_scav.id,    xOffset = -176, yOffset = 0, zOffset =  -16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -176, yOffset = 0, zOffset = -176, direction = 2 },
			{ unitDefID = UDN.corgate_scav.id,   xOffset =    0, yOffset = 0, zOffset =    0, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =   16, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =  -16, direction = 3 },
			{ unitDefID = UDN.corhlt_scav.id,    xOffset = -176, yOffset = 0, zOffset =   16, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset = -192, yOffset = 0, zOffset = -128, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  -16, yOffset = 0, zOffset = -176, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset =   16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   48, yOffset = 0, zOffset =  -16, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =  144, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -16, yOffset = 0, zOffset =  144, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -176, yOffset = 0, zOffset =  112, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -176, yOffset = 0, zOffset = -208, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  208, yOffset = 0, zOffset =  -16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =   16, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  112, yOffset = 0, zOffset = -176, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset = -144, direction = 3 },
			{ unitDefID = UDN.corvipe_scav.id,   xOffset =  184, yOffset = 0, zOffset = -184, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  176, yOffset = 0, zOffset = -112, direction = 2 },
			{ unitDefID = UDN.corhlt_scav.id,    xOffset =  176, yOffset = 0, zOffset =  -16, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -208, yOffset = 0, zOffset =  -16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =  -16, direction = 3 },
			{ unitDefID = UDN.cordoom_scav.id,   xOffset = -128, yOffset = 0, zOffset = -128, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -208, yOffset = 0, zOffset =   16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   16, yOffset = 0, zOffset =   48, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  176, yOffset = 0, zOffset =  176, direction = 2 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =   16, yOffset = 0, zOffset =  176, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -48, yOffset = 0, zOffset =  -16, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  240, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -144, yOffset = 0, zOffset =   16, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -240, yOffset = 0, zOffset =    0, direction = 3 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =   16, yOffset = 0, zOffset = -176, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  144, yOffset = 0, zOffset = -176, direction = 2 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 176,
		buildings = buildings,
}
end

-- LONG RANGE PLASMA CANNON BASES

local function t2HeavyFirebase2()
	local buildings
	local r = math.random(0,1)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.corint_scav.id,    xOffset =    0, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset = -120, yOffset = 0, zOffset =   32, direction = 3 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset =  120, yOffset = 0, zOffset =  -32, direction = 1 },
		}
	else
		buildings = {
			{ unitDefID = UDN.cortoast_scav.id,  xOffset =  106, yOffset = 0, zOffset =  -80, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -46, yOffset = 0, zOffset = -136, direction = 1 },
			{ unitDefID = UDN.corarad_scav.id,   xOffset =  -62, yOffset = 0, zOffset =   40, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   34, yOffset = 0, zOffset =    8, direction = 0 },
			{ unitDefID = UDN.cortoast_scav.id,  xOffset = -102, yOffset = 0, zOffset =   80, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -46, yOffset = 0, zOffset =   -8, direction = 0 },
			{ unitDefID = UDN.corint_scav.id,    xOffset =  -22, yOffset = 0, zOffset =  -64, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   -6, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   98, yOffset = 0, zOffset =   56, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -78, yOffset = 0, zOffset = -120, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   50, yOffset = 0, zOffset =  136, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -94, yOffset = 0, zOffset =  -88, direction = 1 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =   66, yOffset = 0, zOffset =  -24, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -94, yOffset = 0, zOffset =  -56, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   18, yOffset = 0, zOffset =  136, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   82, yOffset = 0, zOffset =  120, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   98, yOffset = 0, zOffset =   88, direction = 1 },
			{ unitDefID = UDN.corint_scav.id,    xOffset =   26, yOffset = 0, zOffset =   64, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -14, yOffset = 0, zOffset = -136, direction = 1 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T3, },
		radius = 136,
		buildings = buildings,
	}
end

-- COUNTER INTRUSION BASES

local function t2Base1()
	local randomTurrets = {UDN.corarad_scav.id, UDN.corshroud_scav.id, UDN.corhlt_scav.id, UDN.cornanotc_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 144,
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =    0, yOffset = 0, zOffset = -122, direction = 0 },
			{ unitDefID = UDN.cormakr_scav.id,                           xOffset =  -72, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = UDN.coruwadvms_scav.id,                        xOffset =  -32, yOffset = 0, zOffset =  -74, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -48, yOffset = 0, zOffset =   70, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -64, yOffset = 0, zOffset = -122, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -16, yOffset = 0, zOffset =   86, direction = 0 },
			{ unitDefID = UDN.coruwadvms_scav.id,                        xOffset =   32, yOffset = 0, zOffset =  -74, direction = 0 },
			{ unitDefID = UDN.coreyes_scav.id,                           xOffset =  -72, yOffset = 0, zOffset =   62, direction = 0 },
			{ unitDefID = UDN.cormakr_scav.id,                           xOffset =   72, yOffset = 0, zOffset =   30, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  144, yOffset = 0, zOffset =   70, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -128, yOffset = 0, zOffset =  102, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   16, yOffset = 0, zOffset =   86, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   48, yOffset = 0, zOffset =   70, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =    0, yOffset = 0, zOffset =  134, direction = 0 },
			{ unitDefID = UDN.coreyes_scav.id,                           xOffset =   72, yOffset = 0, zOffset =   62, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -32, yOffset = 0, zOffset = -122, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   96, yOffset = 0, zOffset =  -58, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  128, yOffset = 0, zOffset =  102, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -80, yOffset = 0, zOffset =  -90, direction = 0 },
			{ unitDefID = UDN.corsd_scav.id,                             xOffset =    0, yOffset = 0, zOffset =   22, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   80, yOffset = 0, zOffset =  -90, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -144, yOffset = 0, zOffset =   70, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset = -144, yOffset = 0, zOffset =   38, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  144, yOffset = 0, zOffset =   38, direction = 0 },
			{ unitDefID = UDN.corshroud_scav.id,                         xOffset =  -96, yOffset = 0, zOffset =  -58, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   64, yOffset = 0, zOffset = -122, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   32, yOffset = 0, zOffset = -122, direction = 0 },
		},
	}
end



-- HEAVY DEFENSIVE BASES

local function t2HeavyFirebase5()
	local randomTurrets = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T3, },
		radius = 120,
		buildings = {
			{ unitDefID = UDN.cordoom_scav.id, xOffset =    0, yOffset = 0, zOffset =   0, direction = 0 },
			{ unitDefID = UDN.corarad_scav.id, xOffset = -120, yOffset = 0, zOffset = -32, direction = 3 },
			
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset = 120, yOffset = 0, zOffset = 32, direction = 1 },
		},
	}
end

-- HEAVY DEFENSIVE AIRREPAIR BASES

local function t2Firebase5()
	local randomTurrets = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 170,
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  135, yOffset = 0, zOffset =   74, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =  -22, direction = 0 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset = -137, yOffset = 0, zOffset =  138, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -57, yOffset = 0, zOffset = -166, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  135, yOffset = 0, zOffset =  138, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =  -54, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =  138, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =   10, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset = -166, direction = 1 },
			{ unitDefID = UDN.corasp_scav.id,    xOffset =   -1, yOffset = 0, zOffset =   34, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =  106, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =   74, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -137, yOffset = 0, zOffset =   10, direction = 1 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset =  151, yOffset = 0, zOffset =  -70, direction = 1 },
			{ unitDefID = UDN.corhllt_scav.id,   xOffset =  119, yOffset = 0, zOffset = -182, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   47, yOffset = 0, zOffset =  130, direction = 1 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset =  -41, yOffset = 0, zOffset =  -86, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =    7, yOffset = 0, zOffset = -182, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =  -54, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =   42, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset = -137, yOffset = 0, zOffset =   42, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -169, yOffset = 0, zOffset =   58, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -137, yOffset = 0, zOffset =   74, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =   10, direction = 0 },
			{ unitDefID = UDN.corflak_scav.id,   xOffset =  135, yOffset = 0, zOffset =   42, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -49, yOffset = 0, zOffset =  130, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   71, yOffset = 0, zOffset = -182, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =   74, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =  106, direction = 0 },
			{ unitDefID = UDN.corgate_scav.id,   xOffset =   23, yOffset = 0, zOffset = -102, direction = 1 },
			{ unitDefID = UDN.corpun_scav.id,    xOffset = -169, yOffset = 0, zOffset =  -70, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -89, yOffset = 0, zOffset =  -22, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  167, yOffset = 0, zOffset =   26, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =   42, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  167, yOffset = 0, zOffset =   58, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   87, yOffset = 0, zOffset =  138, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -169, yOffset = 0, zOffset =   26, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   39, yOffset = 0, zOffset = -182, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -25, yOffset = 0, zOffset = -182, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  135, yOffset = 0, zOffset =   10, direction = 1 },
		},
	}
end

-- HEAVY POWERPLANT BASES

local function t2Energy1()
	local randomTurrets = {UDN.corhlt_scav.id, UDN.corflak_scav.id, UDN.corshroud_scav.id, UDN.cortarg_scav.id, BPWallOrPopup("scav"), BPWallOrPopup("scav"),}
	local buildings
	local r = math.random(0,4)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cornanotc_scav.id,                         xOffset = -192, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id,                         xOffset =  192, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corfus_scav.id,                            xOffset =  -96, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corfus_scav.id,                            xOffset =    0, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.corfus_scav.id,                            xOffset =   96, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -96, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -64, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -32, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =    0, yOffset = 0, zOffset =  -64, direction = 2 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   32, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   64, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   96, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -96, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -64, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -32, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =    0, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   32, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   64, yOffset = 0, zOffset =   80, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   96, yOffset = 0, zOffset =   80, direction = 0 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id,                         xOffset = -160, yOffset = 0, zOffset = -160, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id,                         xOffset =  160, yOffset = 0, zOffset = -160, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id,                         xOffset = -160, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id,                         xOffset =  160, yOffset = 0, zOffset =  160, direction = 0 },
			{ unitDefID = UDN.armafus_scav.id,                           xOffset =    0, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -80, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -96, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =  -96, yOffset = 0, zOffset =    0, direction = 3 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -96, yOffset = 0, zOffset =   32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =  -80, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   80, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   96, yOffset = 0, zOffset =  -32, direction = 0 },
			{ unitDefID = randomTurrets[math.random(1, #randomTurrets)], xOffset =   96, yOffset = 0, zOffset =    0, direction = 1 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   96, yOffset = 0, zOffset =   32, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"),                         xOffset =   80, yOffset = 0, zOffset =   64, direction = 0 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -24, yOffset = 0, zOffset =  -65, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   24, yOffset = 0, zOffset =  -65, direction = 0 },
			{ unitDefID = UDN.coreyes_scav.id,   xOffset =    0, yOffset = 0, zOffset =   39, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   56, yOffset = 0, zOffset =  -33, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =    0, yOffset = 0, zOffset =  -73, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset = -145, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -56, yOffset = 0, zOffset =  -33, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =  -88, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   56, yOffset = 0, zOffset =   -1, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  143, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   56, yOffset = 0, zOffset =   31, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =   16, yOffset = 0, zOffset =   39, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -113, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  111, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =   32, yOffset = 0, zOffset =   39, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset =  143, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset =  111, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  144, yOffset = 0, zOffset =  -89, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -104, yOffset = 0, zOffset = -145, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  144, yOffset = 0, zOffset =   87, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -56, yOffset = 0, zOffset =   31, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -24, yOffset = 0, zOffset =   63, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  -32, yOffset = 0, zOffset =   39, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset = -144, yOffset = 0, zOffset =  -89, direction = 0 },
			{ unitDefID = UDN.corfus_scav.id,    xOffset =    0, yOffset = 0, zOffset =   -9, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =    0, yOffset = 0, zOffset =  -57, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -56, yOffset = 0, zOffset =   -1, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset =  143, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset =  -16, yOffset = 0, zOffset =   39, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   24, yOffset = 0, zOffset =   63, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  136, yOffset = 0, zOffset = -145, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =   88, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =  -88, yOffset = 0, zOffset =  -97, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =   88, yOffset = 0, zOffset =  -97, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -145, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -136, yOffset = 0, zOffset = -113, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  104, yOffset = 0, zOffset =  143, direction = 0 },
			{ unitDefID = UDN.cormine3_scav.id,  xOffset = -144, yOffset = 0, zOffset =   87, direction = 0 },
		}
	elseif r == 3 then
		buildings = {
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -44, yOffset = 0, zOffset =   63, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  148, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -44, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  116, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = UDN.corafus_scav.id,   xOffset =   20, yOffset = 0, zOffset =   -1, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  180, yOffset = 0, zOffset =   63, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   84, yOffset = 0, zOffset =  -33, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,    xOffset =  180, yOffset = 0, zOffset =   95, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  180, yOffset = 0, zOffset =   31, direction = 0 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset = -132, yOffset = 0, zOffset =   23, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =  132, yOffset = 0, zOffset =   47, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -60, yOffset = 0, zOffset = -129, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -92, yOffset = 0, zOffset = -129, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -124, yOffset = 0, zOffset =  -65, direction = 0 },
			{ unitDefID = UDN.corshroud_scav.id, xOffset =   84, yOffset = 0, zOffset =  -65, direction = 0 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset =  -84, yOffset = 0, zOffset =   71, direction = 0 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset = -132, yOffset = 0, zOffset =   71, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =  -44, yOffset = 0, zOffset =   31, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset =   52, yOffset = 0, zOffset =  -65, direction = 0 },
			{ unitDefID = UDN.corestor_scav.id,  xOffset =  -76, yOffset = 0, zOffset =  -81, direction = 0 },
			{ unitDefID = BPWallOrPopup("scav"), xOffset = -124, yOffset = 0, zOffset =  -97, direction = 0 },
			{ unitDefID = UDN.corllt_scav.id,    xOffset = -124, yOffset = 0, zOffset = -129, direction = 2 },
			{ unitDefID = UDN.cormakr_scav.id,   xOffset =  -84, yOffset = 0, zOffset =   23, direction = 0 },
		}
	else
		buildings = {
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -160, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  160, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -64, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =    0, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   64, yOffset = 0, zOffset =  -64, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -64, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =    0, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   64, yOffset = 0, zOffset =    0, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =  -64, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =    0, yOffset = 0, zOffset =   64, direction = 0 },
			{ unitDefID = UDN.armadvsol_scav.id, xOffset =   64, yOffset = 0, zOffset =   64, direction = 0 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		radius = 160,
		buildings = buildings,
	}
end

return {
	t1Barriers,
	t1Energy1,
	t1FactoryBase1,
	t1Firebase1,
	t1Firebase2,
	t1IntelBase1,
	t1IntelBase2,
	t1Metal1,
	t1MetalStore1,
	t1RadarBase1,
	t1Resources1,
	t1Resources2,
	t2Base1,
	t2Energy1,
	t2Factory,
	t2Firebase1,
	t2Firebase2,
	t2Firebase3,
	t2Firebase4,
	t2Firebase5,
	t2HeavyFirebase1,
	t2HeavyFirebase2,
	t2HeavyFirebase5,
}
