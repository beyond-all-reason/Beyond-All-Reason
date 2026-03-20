local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

local function Nikuksis_land0()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1 },
		radius = 168,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -40, zOffset = -136, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 136, zOffset = 40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 40, zOffset = 136, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 8, zOffset = -168, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 168, zOffset = -8, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 24, zOffset = 168, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -168, zOffset = 8, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136, zOffset = -40, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 136, zOffset = -24, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 168, zOffset = 24, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -24, zOffset = 136, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 24, zOffset = -136, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -8, zOffset = 168, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -168, zOffset = -24, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -24, zOffset = -168, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -136, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = -48, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = 48, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = 48, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = -48, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 8, zOffset = 136, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = -136, zOffset = -8, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 136, zOffset = 8, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = -8, zOffset = -136, direction = 1},
		},
	}
end

local function Nikuksis_land1()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1 },
		radius = 72,
		buildings = {
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = 72, zOffset = 27, direction = 1},
			{ unitDefID = UnitDefNames.armrl_scav.id, xOffset = -72, zOffset = -37, direction = 1},
			{ unitDefID = UnitDefNames.armestor_scav.id, xOffset = -8, zOffset = 59, direction = 1},
			{ unitDefID = UnitDefNames.armestor_scav.id, xOffset = 8, zOffset = -53, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = -64, zOffset = 67, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = 0, zOffset = 3, direction = 1},
			{ unitDefID = UnitDefNames.armadvsol_scav.id, xOffset = 64, zOffset = -61, direction = 1},
		},
	}
end

local function Nikuksis_land2()
	return {
		type = types.Land,
		tiers = { tiers.T0, tiers.T1 },
		radius = 64,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -64, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = 0, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 64, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 32, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -32, zOffset = -64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 64, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 32, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = 32, zOffset = 32, direction = 1},
			{ unitDefID = UnitDefNames.armllt_scav.id, xOffset = -32, zOffset = -32, direction = 1},
		},
	}
end

local function Nikuksis_land3()
	return {
		type = types.Land,
		tiers = { tiers.T1, tiers.T2 },
		radius = 96,
		buildings = {
			{ unitDefID = UnitDefNames.armmine3_scav.id, xOffset = 0, zOffset = -92, direction = 1},
			{ unitDefID = UnitDefNames.armmine3_scav.id, xOffset = 96, zOffset = 4, direction = 1},
			{ unitDefID = UnitDefNames.armmine3_scav.id, xOffset = 0, zOffset = 4, direction = 1},
			{ unitDefID = UnitDefNames.armmine3_scav.id, xOffset = -96, zOffset = 4, direction = 1},
			{ unitDefID = UnitDefNames.armmine3_scav.id, xOffset = 0, zOffset = 84, direction = 1},
		},
	}
end



local function Nikuksis_land5()
	return {
		type = types.Land,
		tiers = { tiers.T2 },
		radius = 32,
		buildings = {
			{ unitDefID = UnitDefNames.armarad_scav.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = 32, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -32, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armflak_scav.id, xOffset = -32, zOffset = -32, direction = 0},
		},
	}
end

local function Nikuksis_land6()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3 },
		radius = 48,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armamd_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Nikuksis_land7()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3 },
		radius = 96,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = -96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 16, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = 16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = 48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 80, zOffset = -16, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -16, zOffset = 96, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = -16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 48, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -48, zOffset = -48, direction = 1},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -80, zOffset = 16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = 64, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = -16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 16, zOffset = -64, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = -16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 16, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = 64, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -16, zOffset = -64, direction = 0},
			{ unitDefID = UnitDefNames.armmercury_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

local function Nikuksis_land8()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 192,
		buildings = {
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -96, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 192, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = -192, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 0, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 1, "land"), xOffset = 96, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -144, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 192, zOffset = 0, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 48, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 144, zOffset = -48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -192, zOffset = 0, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -96, zOffset = 0, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -48, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 96, zOffset = 0, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = -144, zOffset = 48, direction = 0},
			{ unitDefID = BPWallOrPopup('scav', 2), xOffset = 144, zOffset = 48, direction = 0},
			{ unitDefID = UnitDefNames.armmercury_scav.id, xOffset = -144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmercury_scav.id, xOffset = -48, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmercury_scav.id, xOffset = 144, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmercury_scav.id, xOffset = 48, zOffset = 0, direction = 0},
		},
	}
end

local function Nikuksis_land9()
	return {
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, tiers.T4 },
		radius = 80,
		buildings = {
			{ unitDefID = UnitDefNames.armmmkr_scav.id, xOffset = 0, zOffset = 80, direction = 1},
			{ unitDefID = UnitDefNames.armmmkr_scav.id, xOffset = 80, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmmkr_scav.id, xOffset = -80, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmmkr_scav.id, xOffset = 0, zOffset = -80, direction = 1},
			{ unitDefID = UnitDefNames.armafus_scav.id, xOffset = 0, zOffset = 0, direction = 1},
		},
	}
end

return {
    Nikuksis_land0,
    Nikuksis_land1,
    Nikuksis_land2,
    Nikuksis_land3,
    Nikuksis_land5,
    Nikuksis_land6,
    Nikuksis_land7,
    Nikuksis_land8,
    Nikuksis_land9,
}