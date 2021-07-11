local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function cloakedFusion()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armckfus_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) }
		}
	}
end

local function underwaterFusion()
	return {
		radius = 50,
		type = types.Sea,
		tiers = { tiers.T3, tiers.T2, },
		buildings = {
			{ unitDefID = UDN.coruwfus_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) }
		}
	}
end

local function fakeFusionBlue()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T2, },
		buildings = {
			{ unitDefID = UDN.armdf_scav.id, xOffset = 0, zOffset = 0, direction = 2 }
		}
	}
end

local function targetingFacilityBlue()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T3, },
		buildings = {
			{ unitDefID = UDN.armtarg_scav.id, xOffset = 0, zOffset = 0, direction = 2 }
		}
	}
end

return {
	cloakedFusion,
	underwaterFusion,
	fakeFusionBlue,
	targetingFacilityBlue,
}