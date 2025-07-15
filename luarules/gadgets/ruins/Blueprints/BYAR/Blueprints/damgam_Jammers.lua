local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west


local function Jammer0()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 32,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer1()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = -48, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer2()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armrad_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer3()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 72,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 8, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -40, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -8, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 40, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armeyes_scav.id, xOffset = -32, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.armeyes_scav.id, xOffset = 32, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.armrad_scav.id, xOffset = -24, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 24, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer4()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 97,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 9, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -55, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 33, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 1, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -23, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -87, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 41, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 65, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -55, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -63, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 9, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -87, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -31, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -23, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 41, zOffset = 97, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = -111, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = -111, zOffset = 41, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 17, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = -47, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 25, zOffset = 33, direction = 1},
			{ unitDefID = UnitDefNames.armjuno_scav.id, xOffset = -39, zOffset = 33, direction = 1},
		},
	}
end

local function Jammer5()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 32,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer6()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corllt_scav.id, xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corllt_scav.id, xOffset = -48, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer7()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corrad_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer8()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 72,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 8, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 40, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -72, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 72, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -8, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -40, zOffset = -64, direction = 1},
			{ unitDefID = UnitDefNames.coreyes_scav.id, xOffset = 32, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.coreyes_scav.id, xOffset = -32, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.corrad_scav.id, xOffset = -24, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 24, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer9()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 97,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -23, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 65, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -31, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -55, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -55, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 9, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -87, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 41, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 9, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 33, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -23, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -87, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = -63, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 1, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 41, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 73, zOffset = 97, direction = 1},
			{ unitDefID = UnitDefNames.corrl_scav.id, xOffset = -111, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.corrl_scav.id, xOffset = -111, zOffset = 41, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = -47, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 17, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 25, zOffset = 33, direction = 1},
			{ unitDefID = UnitDefNames.corjuno_scav.id, xOffset = -39, zOffset = 33, direction = 1},
		},
	}
end

local function Jammer10()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 32,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armveil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer11()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armveil_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armarad_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer12()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 64,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 3},
			{ unitDefID = UnitDefNames.armveil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 32, zOffset = 0, direction = 3},
		},
	}
end

local function Jammer13()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 96,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -64, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 64, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armtarg_scav.id, xOffset = -56, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.armtarg_scav.id, xOffset = 56, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.armveil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 64, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -64, zOffset = -48, direction = 3},
		},
	}
end

local function Jammer14()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 128,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 64, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -128, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 128, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 128, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 128, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -128, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = 64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 64, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -128, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -64, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 128, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -64, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -128, zOffset = 16, direction = 1},
			{ unitDefID = UnitDefNames.armveil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armsd_scav.id, xOffset = 64, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armgate_scav.id, xOffset = -64, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer15()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 32,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corshroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer16()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.corshroud_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corarad_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer17()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 64,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.corshroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -32, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 32, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer18()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 112,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 112, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -112, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 112, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -80, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = 64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = -64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 80, zOffset = -80, direction = 3},
			{ unitDefID = UnitDefNames.corshroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortarg_scav.id, xOffset = -64, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.cortarg_scav.id, xOffset = 64, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = -80, zOffset = -48, direction = 3},
			{ unitDefID = UnitDefNames.corflak_scav.id, xOffset = 80, zOffset = 48, direction = 1},
		},
	}
end

local function Jammer19()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 112,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 80, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 80, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = -64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = -64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 64, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -80, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 112, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -80, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -112, zOffset = -32, direction = 3},
			{ unitDefID = UnitDefNames.corshroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.corsd_scav.id, xOffset = 64, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.corgate_scav.id, xOffset = -64, zOffset = 0, direction = 3},
		},
	}
end

return {
    Jammer0,
    Jammer1,
    Jammer2,
    Jammer3,
    Jammer4,
    Jammer5,
    Jammer6,
    Jammer7,
    Jammer8,
    Jammer9,
    Jammer10,
    Jammer11,
    Jammer12,
    Jammer13,
    Jammer14,
    Jammer15,
    Jammer16,
    Jammer17,
    Jammer18,
    Jammer19,
}
