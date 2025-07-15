local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west


local function tacnukes0()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 232,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -24, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -136, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -232, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 136, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 160, zOffset = -232, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160, zOffset = -88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160, zOffset = 232, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = 232, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 56, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = 88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 24, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -168, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = -232, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -200, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = -184, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 160, zOffset = 88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 168, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 184, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = -88, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 200, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -56, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 232, direction = 3},
			{ unitDefID = UnitDefNames.corwint2_scav.id, xOffset = 48, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.corwint2_scav.id, xOffset = -48, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.corwint2_scav.id, xOffset = -144, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.corwint2_scav.id, xOffset = 144, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -48, zOffset = -104, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 48, zOffset = -152, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 48, zOffset = 104, direction = 1},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -48, zOffset = 152, direction = 1},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 144, zOffset = 40, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 144, zOffset = -184, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -144, zOffset = 184, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -144, zOffset = -40, direction = 3},
		},
	}
end

local function tacnukes1()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 219,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 27, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 59, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 160, zOffset = -229, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -85, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160, zOffset = 219, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -53, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 91, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = -85, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -133, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -21, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 155, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 219, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -160, zOffset = -85, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -128, zOffset = 219, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = 91, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 187, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 139, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -197, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 160, zOffset = 91, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 128, zOffset = -229, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 187, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = -181, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -229, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -165, direction = 3},
			{ unitDefID = UnitDefNames.armwint2_scav.id, xOffset = -144, zOffset = 75, direction = 1},
			{ unitDefID = UnitDefNames.armwint2_scav.id, xOffset = 48, zOffset = -21, direction = 1},
			{ unitDefID = UnitDefNames.armwint2_scav.id, xOffset = 144, zOffset = -69, direction = 1},
			{ unitDefID = UnitDefNames.armwint2_scav.id, xOffset = -48, zOffset = 27, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 48, zOffset = 107, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -48, zOffset = 155, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -48, zOffset = -101, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 48, zOffset = -149, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -144, zOffset = 171, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 144, zOffset = -181, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 144, zOffset = 43, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -144, zOffset = -37, direction = 3},
		},
	}
end

local function tacnukes2()
	return {
		type = types.Land,
		tiers = {tiers.T3, tiers.T4 },
		radius = 104,
		buildings = {
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -96, zOffset = -96, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -48, zOffset = -48, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 48, zOffset = -48, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -48, zOffset = 48, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 48, zOffset = 48, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 96, zOffset = -96, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 96, zOffset = 96, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 0, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -96, zOffset = 96, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 8, zOffset = 88, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 88, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -8, zOffset = -88, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 88, zOffset = -56, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -56, zOffset = -88, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -88, zOffset = 56, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -88, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 56, zOffset = 88, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -40, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 8, zOffset = -40, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -8, zOffset = 40, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 40, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 104, zOffset = 40, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 40, zOffset = -104, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -104, zOffset = -40, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -40, zOffset = 104, direction = 3},
		},
	}
end

local function tacnukes3()
	return {
		type = types.Land,
		tiers = {tiers.T3, tiers.T4 },
		radius = 116,
		buildings = {
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 108, zOffset = 68, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -36, zOffset = 20, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -84, zOffset = -124, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -84, zOffset = 68, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 12, zOffset = -28, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -36, zOffset = -76, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 60, zOffset = 20, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 100, zOffset = -36, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -76, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 68, zOffset = 60, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 20, zOffset = 60, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -76, zOffset = 28, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 52, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -28, zOffset = -36, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 4, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -28, zOffset = 76, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -92, zOffset = -68, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 116, zOffset = 12, direction = 3},
		},
	}
end

local function tacnukes4()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 84,
		buildings = {
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -20, zOffset = -54, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 76, zOffset = 42, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -68, zOffset = -6, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -116, zOffset = 42, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 28, zOffset = -6, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = -12, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 68, zOffset = -62, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 36, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -28, zOffset = -14, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 20, zOffset = -46, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -60, zOffset = 50, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = 84, zOffset = -14, direction = 3},
		},
	}
end

local function tacnukes5()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 42,
		buildings = {
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -17, zOffset = -14, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -65, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 31, zOffset = -62, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 39, zOffset = 26, direction = 3},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 23, zOffset = -22, direction = 3},
			{ unitDefID = UnitDefNames.armemp_scav.id, xOffset = -9, zOffset = 42, direction = 3},
		},
	}
end

local function tacnukes6()
	return {
		type = types.Land,
		tiers = {tiers.T3, tiers.T4 },
		radius = 104,
		buildings = {
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 48, zOffset = -48, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 96, zOffset = 96, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -96, zOffset = -96, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 48, zOffset = 48, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -48, zOffset = -48, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 96, zOffset = -96, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -96, zOffset = 96, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 0, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -48, zOffset = 48, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 56, zOffset = 88, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 8, zOffset = 88, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -56, zOffset = -88, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -88, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 88, zOffset = -56, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 88, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -88, zOffset = 56, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -8, zOffset = -88, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 40, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -40, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 8, zOffset = -40, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -8, zOffset = 40, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -40, zOffset = 104, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 40, zOffset = -104, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -104, zOffset = -40, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 104, zOffset = 40, direction = 3},
		},
	}
end

local function tacnukes7()
	return {
		type = types.Land,
		tiers = {tiers.T3, tiers.T4 },
		radius = 116,
		buildings = {
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -84, zOffset = 68, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 60, zOffset = 20, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -36, zOffset = -76, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 12, zOffset = -28, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -84, zOffset = -124, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -36, zOffset = 20, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 108, zOffset = 68, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 68, zOffset = 60, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 20, zOffset = 60, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -76, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -76, zOffset = 28, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 100, zOffset = -36, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -28, zOffset = -36, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 52, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 4, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -92, zOffset = -68, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -28, zOffset = 76, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 116, zOffset = 12, direction = 3},
		},
	}
end

local function tacnukes8()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 84,
		buildings = {
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 28, zOffset = -6, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 76, zOffset = 42, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -20, zOffset = -54, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -116, zOffset = 42, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -68, zOffset = -6, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 68, zOffset = -62, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = -12, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 36, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 20, zOffset = -46, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -28, zOffset = -14, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = 84, zOffset = -14, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -60, zOffset = 50, direction = 3},
		},
	}
end

local function tacnukes9()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 42,
		buildings = {
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 31, zOffset = -62, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -17, zOffset = -14, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -65, zOffset = 34, direction = 3},
			{ unitDefID = UnitDefNames.corhllllt_scav.id, xOffset = 39, zOffset = 26, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 23, zOffset = -22, direction = 3},
			{ unitDefID = UnitDefNames.cortron_scav.id, xOffset = -9, zOffset = 42, direction = 3},
		},
	}
end

return {
    tacnukes0,
    tacnukes1,
    tacnukes2,
    tacnukes3,
    tacnukes4,
    tacnukes5,
    tacnukes6,
    tacnukes7,
    tacnukes8,
    tacnukes9,
}
