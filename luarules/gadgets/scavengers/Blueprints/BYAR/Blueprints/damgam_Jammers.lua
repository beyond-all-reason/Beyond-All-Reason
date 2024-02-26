local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
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
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer1()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armada_sentry_scav.id, xOffset = -48, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.armada_sentry_scav.id, xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer2()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_radartower_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer3()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 72,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 8, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -40, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -8, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 40, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armada_beholder_scav.id, xOffset = -32, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.armada_beholder_scav.id, xOffset = 32, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.armada_radartower_scav.id, xOffset = -24, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = 24, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer4()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 97,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 9, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -55, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 33, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 1, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -23, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -87, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 41, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 65, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -55, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -63, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 9, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -87, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -31, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -23, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 41, zOffset = 97, direction = 1},
			{ unitDefID = UnitDefNames.armada_nettle_scav.id, xOffset = -111, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armada_nettle_scav.id, xOffset = -111, zOffset = 41, direction = 1},
			{ unitDefID = UnitDefNames.armada_constructionturret_scav.id, xOffset = 17, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armada_constructionturret_scav.id, xOffset = -47, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = 25, zOffset = 33, direction = 1},
			{ unitDefID = UnitDefNames.armada_juno_scav.id, xOffset = -39, zOffset = 33, direction = 1},
		},
	}
end

local function Jammer5()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 32,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer6()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 80,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 80, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -80, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_guard_scav.id, xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_guard_scav.id, xOffset = -48, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer7()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_radartower_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer8()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 72,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 8, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 40, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -72, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 72, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -8, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -40, zOffset = -64, direction = 1},
			{ unitDefID = UnitDefNames.cortex_beholder_scav.id, xOffset = 32, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.cortex_beholder_scav.id, xOffset = -32, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.cortex_radartower_scav.id, xOffset = -24, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = 24, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer9()
	return {
		type = types.Land,
		tiers = {tiers.T1, tiers.T2},
		radius = 97,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -23, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 65, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -31, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -55, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -55, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 9, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -87, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 41, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 9, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 33, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -23, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -87, zOffset = -95, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = -63, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 1, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 41, zOffset = 97, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 73, zOffset = 97, direction = 1},
			{ unitDefID = UnitDefNames.cortex_thistle_scav.id, xOffset = -111, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.cortex_thistle_scav.id, xOffset = -111, zOffset = 41, direction = 1},
			{ unitDefID = UnitDefNames.cortex_constructionturret_scav.id, xOffset = -47, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.cortex_constructionturret_scav.id, xOffset = 17, zOffset = -39, direction = 1},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = 25, zOffset = 33, direction = 1},
			{ unitDefID = UnitDefNames.cortex_juno_scav.id, xOffset = -39, zOffset = 33, direction = 1},
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
			{ unitDefID = UnitDefNames.armada_veil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
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
			{ unitDefID = UnitDefNames.armada_veil_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_advancedradartower_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer12()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 64,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = 0, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 3},
			{ unitDefID = UnitDefNames.armada_veil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_arbalest_scav.id, xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_arbalest_scav.id, xOffset = 32, zOffset = 0, direction = 3},
		},
	}
end

local function Jammer13()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 96,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 96, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -32, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -96, zOffset = -80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 32, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 96, zOffset = 80, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -96, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 32, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -32, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -64, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 64, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_pinpointer_scav.id, xOffset = -56, zOffset = 8, direction = 3},
			{ unitDefID = UnitDefNames.armada_pinpointer_scav.id, xOffset = 56, zOffset = -8, direction = 3},
			{ unitDefID = UnitDefNames.armada_veil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_arbalest_scav.id, xOffset = 64, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armada_arbalest_scav.id, xOffset = -64, zOffset = -48, direction = 3},
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
			{ unitDefID = UnitDefNames.armada_veil_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_tracer_scav.id, xOffset = 64, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armada_keeper_scav.id, xOffset = -64, zOffset = 0, direction = 1},
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
			{ unitDefID = UnitDefNames.cortex_shroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
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
			{ unitDefID = UnitDefNames.cortex_shroud_scav.id, xOffset = 16, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_advancedradartower_scav.id, xOffset = -16, zOffset = 0, direction = 1},
		},
	}
end

local function Jammer17()
	return {
		type = types.Land,
		tiers = {tiers.T2, tiers.T3, tiers.T4 },
		radius = 64,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -64, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 64, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -32, direction = 1},
			{ unitDefID = UnitDefNames.cortex_shroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
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
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -80, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -112, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 112, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 80, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -48, zOffset = -48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -112, zOffset = -80, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 48, zOffset = 48, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 112, zOffset = 48, direction = 3},
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
			{ unitDefID = UnitDefNames.cortex_shroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_pinpointer_scav.id, xOffset = -64, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.cortex_pinpointer_scav.id, xOffset = 64, zOffset = -24, direction = 1},
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
			{ unitDefID = UnitDefNames.cortex_shroud_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.cortex_nemesis_scav.id, xOffset = 64, zOffset = 0, direction = 3},
			{ unitDefID = UnitDefNames.cortex_overseer_scav.id, xOffset = -64, zOffset = 0, direction = 3},
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
