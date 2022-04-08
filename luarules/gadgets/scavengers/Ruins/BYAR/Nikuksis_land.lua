local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local types = blueprintConfig.BlueprintTypes



local function Nikuksis_ruin0()
	return {
		type = types.Land,
		radius = 248,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 24, zOffset = 248, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 24, zOffset = -232, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 168, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -168, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 168, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 136, zOffset = 120, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 72, zOffset = -216, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -72, zOffset = 216, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -48, zOffset = 80, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 0, zOffset = 160, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 104, zOffset = -168, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -104, zOffset = 168, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 136, zOffset = -120, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -168, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -168, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -72, zOffset = -216, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -24, zOffset = -232, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 48, zOffset = -80, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -96, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 72, zOffset = 216, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -104, zOffset = -168, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 48, zOffset = 80, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -136, zOffset = 120, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -48, zOffset = -80, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 168, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 0, zOffset = -160, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -136, zOffset = -120, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 104, zOffset = 168, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -168, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 168, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -24, zOffset = 248, direction = 1},
		},
	}
end


local function Nikuksis_ruin1()
	return {
		type = types.Land,
		radius = 190,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -5, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 27, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 59, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 91, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = 147, zOffset = -66, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -5, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 91, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -101, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = -37, zOffset = -82, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 27, zOffset = -82, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = -157, zOffset = 78, direction = 3},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 155, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -37, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -69, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -133, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = -157, zOffset = -66, direction = 3},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = -45, zOffset = 6, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 27, zOffset = 94, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 155, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 59, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -165, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -133, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 187, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -101, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 27, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 123, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -197, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -69, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -37, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -165, zOffset = 190, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = 147, zOffset = 78, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 187, zOffset = -178, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = -37, zOffset = 94, direction = 1},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 35, zOffset = 6, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 123, zOffset = -178, direction = 1},
		},
	}
end

local function Nikuksis_ruin2()
	return {
		type = types.Land,
		radius = 192,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 64, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 96, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = 152, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 96, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -96, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = -32, zOffset = -88, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 32, zOffset = -88, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = -152, zOffset = 72, direction = 3},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 160, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -64, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = -152, zOffset = -72, direction = 3},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -192, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = -40, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 32, zOffset = 88, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 160, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 64, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -160, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -128, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 192, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -96, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -192, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -64, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -160, zOffset = 184, direction = 1},
			{ unitDefID = UnitDefNames.armvp.id, xOffset = 152, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 192, zOffset = -184, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = -32, zOffset = 88, direction = 1},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 40, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 128, zOffset = -184, direction = 1},
		},
	}
end

local function Nikuksis_ruin3()
	return {
		type = types.Land,
		radius = 144,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 112, zOffset = -102, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -112, zOffset = -102, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -144, zOffset = 106, direction = 1},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = -104, zOffset = -46, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -112, zOffset = 106, direction = 1},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = 104, zOffset = -46, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 144, zOffset = 106, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 112, zOffset = 106, direction = 1},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = 104, zOffset = 34, direction = 1},
			{ unitDefID = UnitDefNames.armhp.id, xOffset = 0, zOffset = 2, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 144, zOffset = 74, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 144, zOffset = -70, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -144, zOffset = -102, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 144, zOffset = -102, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -144, zOffset = 74, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -144, zOffset = -70, direction = 1},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = -104, zOffset = 34, direction = 1},
		},
	}
end

local function Nikuksis_ruin4()
	return {
		type = types.Land,
		radius = 48,
		buildings = {
			{ unitDefID = UnitDefNames.armmakr.id, xOffset = -48, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmakr.id, xOffset = 48, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armmakr.id, xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armmakr.id, xOffset = 0, zOffset = -48, direction = 1},
		},
	}
end

local function Nikuksis_ruin5()
	return {
		type = types.Land,
		radius = 80,
		buildings = {
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 0, zOffset = -48, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -64, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -64, zOffset = -80, direction = 1},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 0, zOffset = 48, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 64, zOffset = -80, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 64, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = 64, zOffset = 80, direction = 1},
			{ unitDefID = UnitDefNames.armmakr.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armsolar.id, xOffset = -64, zOffset = 80, direction = 1},
		},
	}
end

local function Nikuksis_ruin6()
	return {
		type = types.Land,
		radius = 72,
		buildings = {
			{ unitDefID = UnitDefNames.armwin.id, xOffset = 72, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -24, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = 72, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = 24, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -72, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = 24, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -24, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = -72, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armwin.id, xOffset = 24, zOffset = 24, direction = 1},
		},
	}
end

local function Nikuksis_ruin7()
	return {
		type = types.Land,
		radius = 88,
		buildings = {
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -40, zOffset = -88, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 8, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -24, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -72, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -40, zOffset = -24, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 40, zOffset = 88, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 24, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -8, zOffset = -40, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 72, zOffset = 40, direction = 1},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = 0, zOffset = 0, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -8, zOffset = -72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 40, zOffset = 24, direction = 1},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = 40, zOffset = 56, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 72, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 40, zOffset = -8, direction = 1},
			{ unitDefID = UnitDefNames.armllt.id, xOffset = -40, zOffset = -56, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -40, zOffset = 8, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 8, zOffset = 72, direction = 1},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -72, zOffset = -40, direction = 1},
		},
	}
end

local function Nikuksis_ruin8()
	return {
		type = types.Land,
		radius = 96,
		buildings = {
			{ unitDefID = UnitDefNames.armrad.id, xOffset = -88, zOffset = 1, direction = 0},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = 48, zOffset = -39, direction = 0},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = -96, zOffset = 41, direction = 0},
			{ unitDefID = UnitDefNames.armestor.id, xOffset = 96, zOffset = 41, direction = 0},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = -48, zOffset = -39, direction = 0},
			{ unitDefID = UnitDefNames.armap.id, xOffset = 0, zOffset = 33, direction = 0},
			{ unitDefID = UnitDefNames.armrad.id, xOffset = 88, zOffset = 1, direction = 0},
			{ unitDefID = UnitDefNames.armrl.id, xOffset = 0, zOffset = -39, direction = 0},
		},
	}
end

local function Nikuksis_ruin9()
	return {
		type = types.Land,
		radius = 40,
		buildings = {
			{ unitDefID = UnitDefNames.armrad.id, xOffset = 0, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 32, zOffset = 0, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = 32, direction = 0},
			{ unitDefID = UnitDefNames.armeyes.id, xOffset = 40, zOffset = 40, direction = 0},
			{ unitDefID = UnitDefNames.armeyes.id, xOffset = -40, zOffset = -40, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = 0, zOffset = -32, direction = 0},
			{ unitDefID = UnitDefNames.armdrag.id, xOffset = -32, zOffset = 0, direction = 0},
		},
	}
end

local function Nikuksis_ruin10()
	return {
		type = types.Land,
		radius = 68,
		buildings = {
			{ unitDefID = UnitDefNames.armnanotc.id, xOffset = 56, zOffset = -4, direction = 1},
			{ unitDefID = UnitDefNames.armnanotc.id, xOffset = -56, zOffset = -4, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 0, zOffset = 68, direction = 1},
			{ unitDefID = UnitDefNames.armmoho.id, xOffset = 0, zOffset = 4, direction = 1},
			{ unitDefID = UnitDefNames.armmstor.id, xOffset = 0, zOffset = -60, direction = 1},
		},
	}
end

return {
    Nikuksis_ruin0,
    Nikuksis_ruin1,
    Nikuksis_ruin2,
    Nikuksis_ruin3,
    Nikuksis_ruin4,
    Nikuksis_ruin5,
    Nikuksis_ruin6,
    Nikuksis_ruin7,
    Nikuksis_ruin8,
    Nikuksis_ruin9,
	Nikuksis_ruin10,
}