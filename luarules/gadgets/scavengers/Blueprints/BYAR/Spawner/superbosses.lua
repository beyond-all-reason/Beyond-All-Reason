local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function epicInfantry()
	return {
		radius = 200,
		type = types.Land,
		tiers = { tiers.T3 },
		buildings = {
			{ unitDefID = UDN.armpwt4_scav.id, xOffset = 0, zOffset = 0, direction = math.random(0, 3) },
		},
	}
end

return {
	epicInfantry,
}