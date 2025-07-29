local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
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
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences1()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = UnitDefNames.corllt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences2()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armbeamer_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences3()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.corhllt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences4()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = UnitDefNames.armhlt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences5()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.corhlt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences6()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.armguard_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences7()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.corpun_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences8()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences9()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.corrl_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences10()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.armferret_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences11()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.cormadsam_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences12()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.armcir_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences13()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.corerad_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences14()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
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
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.corrad_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences16()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armrad_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences17()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.corjamt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences18()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 16,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -16, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -16, direction = 3},
			{ unitDefID = UnitDefNames.armjamt_scav.id, xOffset = 16, zOffset = 16, direction = 3},
		},
	}
end

local function tinyDefences19()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = UnitDefNames.corjuno_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences20()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 28,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = -20, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -20, zOffset = 12, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 12, zOffset = -20, direction = 3},
			{ unitDefID = UnitDefNames.armjuno_scav.id, xOffset = 28, zOffset = 28, direction = 3},
		},
	}
end

local function tinyDefences21()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = UnitDefNames.cornanotc_scav.id, xOffset = 22, zOffset = 22, direction = 3},
		},
	}
end

local function tinyDefences22()
	return {
		type = types.Land,
		tiers = { tiers.T0},
		radius = 22,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 14, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = -18, direction = 3},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -18, zOffset = 14, direction = 3},
			{ unitDefID = UnitDefNames.armnanotc_scav.id, xOffset = 22, zOffset = 22, direction = 3},
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