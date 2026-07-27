local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west


local function tinyDefenses0()
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

local function tinyDefenses1()
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

local function tinyDefenses2()
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

local function tinyDefenses3()
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

local function tinyDefenses4()
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

local function tinyDefenses5()
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

local function tinyDefenses6()
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

local function tinyDefenses7()
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

local function tinyDefenses8()
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

local function tinyDefenses9()
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

local function tinyDefenses10()
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

local function tinyDefenses11()
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

local function tinyDefenses12()
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

local function tinyDefenses13()
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

local function tinyDefenses14()
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

local function tinyDefenses15()
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

local function tinyDefenses16()
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

local function tinyDefenses17()
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

local function tinyDefenses18()
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

local function tinyDefenses19()
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

local function tinyDefenses20()
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

local function tinyDefenses21()
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

local function tinyDefenses22()
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
    tinyDefenses0,
	tinyDefenses1,
    tinyDefenses2,
    tinyDefenses3,
    tinyDefenses4,
    tinyDefenses5,
    tinyDefenses6,
    tinyDefenses7,
    tinyDefenses8,
    tinyDefenses9,
    tinyDefenses10,
    tinyDefenses11,
    tinyDefenses12,
    tinyDefenses13,
    tinyDefenses14,
    tinyDefenses15,
    tinyDefenses16,
    tinyDefenses17,
    tinyDefenses18,
    --tinyDefenses19,
    --tinyDefenses20,
    tinyDefenses21,
    tinyDefenses22,
}