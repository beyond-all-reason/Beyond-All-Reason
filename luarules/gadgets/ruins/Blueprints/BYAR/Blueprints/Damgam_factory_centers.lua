local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes
local UDN = UnitDefNames

local math_random = math.random

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local function t1UnitSpammer()
	local buildings
	local r = math_random(0, 2)
	if r == 0 then
		buildings = {
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -24,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -24,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  24,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  24,  zOffset =  24, direction = 2 },

			{ unitDefID = UDN.corlab_scav.id, xOffset =  96,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.corlab_scav.id, xOffset =   0,  zOffset = -96, direction = 2 },
			{ unitDefID = UDN.corlab_scav.id, xOffset =   0,  zOffset =  96, direction = 0 },
			{ unitDefID = UDN.corlab_scav.id, xOffset = -96,  zOffset =   0, direction = 3 },

			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   72,  zOffset = -120, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -120,  zOffset =  -72, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -72,  zOffset =  120, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   72,  zOffset =  120, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   72,  zOffset =   72, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  120,  zOffset =  -72, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   72,  zOffset =  -72, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -72,  zOffset =   72, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -72,  zOffset = -120, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -120,  zOffset =   72, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  120,  zOffset =   72, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -72,  zOffset =  -72, direction = 1 },

			{ unitDefID = UDN.corpun_scav.id, xOffset = -128,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id, xOffset = -128,  zOffset =  128, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  128,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  128,  zOffset = -128, direction = 1 },
		}
	elseif r == 1 then
		buildings = {
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -32,  zOffset =  32, direction = 3 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -32,  zOffset = -32, direction = 3 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  32,  zOffset = -32, direction = 3 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  32,  zOffset =  32, direction = 3 },

			{ unitDefID = UDN.corvp_scav.id, xOffset =    0,  zOffset = -112, direction = 2 },
			{ unitDefID = UDN.corvp_scav.id, xOffset =    0,  zOffset =  112, direction = 0 },
			{ unitDefID = UDN.corvp_scav.id, xOffset =  112,  zOffset =    0, direction = 1 },
			{ unitDefID = UDN.corvp_scav.id, xOffset =  -96,  zOffset =    0, direction = 3 },

			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -128,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -128,  zOffset =  -80, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   80,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  128,  zOffset =   80, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -80,  zOffset =   80, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  128,  zOffset =  -80, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -80,  zOffset =  128, direction = 0 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -80,  zOffset = -128, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   80,  zOffset =  128, direction = 1 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   80,  zOffset =  -80, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -80,  zOffset =  -80, direction = 3 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   80,  zOffset = -128, direction = 2 },

			{ unitDefID = UDN.corpun_scav.id, xOffset = -136,  zOffset =  136, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id, xOffset = -136,  zOffset = -136, direction = 3 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  136,  zOffset =  136, direction = 1 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  136,  zOffset = -136, direction = 1 },
		}
	elseif r == 2 then
		buildings = {
			{ unitDefID = UDN.corhlt_scav.id, xOffset = 0,  zOffset =  32, direction = 0 },
			{ unitDefID = UDN.corhlt_scav.id, xOffset = 0,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.corhlt_scav.id, xOffset = 0,  zOffset = -32, direction = 2 },

			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  40,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -40,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset =  40,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.cormadsam_scav.id, xOffset = -40,  zOffset = -24, direction = 2 },

			{ unitDefID = UDN.corap_scav.id, xOffset =  128,  zOffset =   0, direction = 2 },
			{ unitDefID = UDN.corap_scav.id, xOffset = -128,  zOffset =   0, direction = 2 },
			{ unitDefID = UDN.corap_scav.id, xOffset =    0,  zOffset = -96, direction = 2 },
			{ unitDefID = UDN.corap_scav.id, xOffset =    0,  zOffset =  96, direction = 2 },

			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -136,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  184,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   88,  zOffset =  120, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -88,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   88,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  136,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -136,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -88,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -184,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  184,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   88,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -88,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  136,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =   88,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset =  -88,  zOffset =  120, direction = 2 },
			{ unitDefID = UDN.cornanotc_scav.id, xOffset = -184,  zOffset =   72, direction = 2 },

			{ unitDefID = UDN.corpun_scav.id, xOffset = -144,  zOffset =  128, direction = 0 },
			{ unitDefID = UDN.corpun_scav.id, xOffset = -208,  zOffset =  128, direction = 0 },
			{ unitDefID = UDN.corpun_scav.id, xOffset = -144,  zOffset = -128, direction = 2 },
			{ unitDefID = UDN.corpun_scav.id, xOffset = -208,  zOffset = -128, direction = 2 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  208,  zOffset = -128, direction = 2 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  144,  zOffset =  128, direction = 0 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  208,  zOffset =  128, direction = 0 },
			{ unitDefID = UDN.corpun_scav.id, xOffset =  144,  zOffset = -128, direction = 2 },
		}
	elseif r == 3 then
		buildings = {
			{ unitDefID = UDN.armferret_scav.id, xOffset =  24,  zOffset =  24, direction = 3 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  24,  zOffset = -24, direction = 3 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -24,  zOffset = -24, direction = 3 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -24,  zOffset =  24, direction = 3 },

			{ unitDefID = UDN.armlab_scav.id, xOffset =   0,  zOffset = -96, direction = 2 },
			{ unitDefID = UDN.armlab_scav.id, xOffset =  96,  zOffset =   0, direction = 1 },
			{ unitDefID = UDN.armlab_scav.id, xOffset =   0,  zOffset =  96, direction = 0 },
			{ unitDefID = UDN.armlab_scav.id, xOffset = -96,  zOffset =   0, direction = 3 },

			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -120,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset = -120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =  120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -120,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset = -120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  120,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =  120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  120,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =  -72, direction = 3 },

			{ unitDefID = UDN.armguard_scav.id, xOffset =  120,  zOffset = -120, direction = 1 },
			{ unitDefID = UDN.armguard_scav.id, xOffset =  120,  zOffset =  120, direction = 1 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -120,  zOffset =  120, direction = 3 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -120,  zOffset = -120, direction = 3 },
		}
	elseif r == 4 then
		buildings = {
			{ unitDefID = UDN.armferret_scav.id, xOffset =  24,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -24,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  24,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -24,  zOffset =  24, direction = 2 },

			{ unitDefID = UDN.armvp_scav.id, xOffset =    0,  zOffset = -104, direction = 2 },
			{ unitDefID = UDN.armvp_scav.id, xOffset = -104,  zOffset =    0, direction = 3 },
			{ unitDefID = UDN.armvp_scav.id, xOffset =    0,  zOffset =  104, direction = 0 },
			{ unitDefID = UDN.armvp_scav.id, xOffset =  104,  zOffset =    0, direction = 1 },

			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -120,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset = -120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  120,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset = -120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  120,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =  120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =  120, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   72,  zOffset =  -72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -120,  zOffset =   72, direction = 3 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -72,  zOffset =   72, direction = 3 },

			{ unitDefID = UDN.armguard_scav.id, xOffset =  120,  zOffset =  120, direction = 1 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -120,  zOffset = -120, direction = 3 },
			{ unitDefID = UDN.armguard_scav.id, xOffset =  120,  zOffset = -120, direction = 1 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -120,  zOffset =  120, direction = 3 },
		}
	elseif r == 5 then
		buildings = {
			{ unitDefID = UDN.armferret_scav.id, xOffset =   0,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  48,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -48,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =  48,  zOffset = -24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset = -48,  zOffset =  24, direction = 2 },
			{ unitDefID = UDN.armferret_scav.id, xOffset =   0,  zOffset = -24, direction = 2 },

			{ unitDefID = UDN.armap_scav.id, xOffset =    0,  zOffset = -96, direction = 2 },
			{ unitDefID = UDN.armap_scav.id, xOffset = -144,  zOffset =   0, direction = 2 },
			{ unitDefID = UDN.armap_scav.id, xOffset =  144,  zOffset =   0, direction = 2 },
			{ unitDefID = UDN.armap_scav.id, xOffset =    0,  zOffset =  96, direction = 2 },

			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   96,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  144,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -96,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -96,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -96,  zOffset =  120, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  192,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   96,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  -96,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -144,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   96,  zOffset =  120, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -192,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -192,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =   96,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  144,  zOffset =  -72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset =  192,  zOffset =   72, direction = 2 },
			{ unitDefID = UDN.armnanotc_scav.id, xOffset = -144,  zOffset =   72, direction = 2 },

			{ unitDefID = UDN.armguard_scav.id, xOffset =  144,  zOffset =  120, direction = 0 },
			{ unitDefID = UDN.armguard_scav.id, xOffset =  144,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -144,  zOffset =  120, direction = 0 },
			{ unitDefID = UDN.armguard_scav.id, xOffset =  192,  zOffset =  120, direction = 0 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -192,  zOffset =  120, direction = 0 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -144,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.armguard_scav.id, xOffset = -192,  zOffset = -120, direction = 2 },
			{ unitDefID = UDN.armguard_scav.id, xOffset =  192,  zOffset = -120, direction = 2 },
		}
	end

	return {
		type = types.Land,
		tiers = { tiers.T3, tiers.T4 },
		radius =  192,
		buildings = buildings,
	}
end

return {
	t1UnitSpammer,
}