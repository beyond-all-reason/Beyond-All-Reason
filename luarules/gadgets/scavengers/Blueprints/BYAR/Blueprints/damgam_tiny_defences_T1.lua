local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west


local function tinyDefences0()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.armada_sentry_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences1()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = UnitDefNames.cortex_guard_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences2()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armada_beamer_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences3()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.cortex_twinguard_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences4()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = UnitDefNames.armada_overwatch_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences5()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.cortex_warden_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences6()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.armada_gauntlet_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences7()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.cortex_agitator_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences8()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = UnitDefNames.armada_nettle_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences9()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.cortex_thistle_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences10()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.armada_ferret_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences11()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.cortex_sam_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences12()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.armada_chainsaw_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences13()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.cortex_eradicator_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences14()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.legmg_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences15()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.cortex_radartower_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences16()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armada_radartower_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences17()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.cortex_castro_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences18()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armada_sneakypete_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences19()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.cortex_juno_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences20()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.armada_juno_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences21()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = UnitDefNames.cortex_constructionturret_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences22()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.armada_constructionturret_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

return {
    tinyDefences0,
	tinyDefences1,
    tinyDefences2,
    tinyDefences3,
    tinyDefences4,
    tinyDefences5,
    tinyDefences6,
    tinyDefences7,
    tinyDefences8,
    tinyDefences9,
    tinyDefences10,
    tinyDefences11,
    tinyDefences12,
    tinyDefences13,
    tinyDefences14,
    tinyDefences15,
    tinyDefences16,
    tinyDefences17,
    tinyDefences18,
    --tinyDefences19,
    --tinyDefences20,
    tinyDefences21,
    tinyDefences22,
}