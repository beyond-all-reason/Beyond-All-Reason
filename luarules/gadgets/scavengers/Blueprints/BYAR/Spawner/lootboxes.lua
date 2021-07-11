local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes
local UDN = UnitDefNames

local function lootboxGold()
	return {
		radius = 50,
		type = types.Land,
		tiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, },
		buildings = {
			{ unitDefID = UDN.lootboxgold.id, xOffset = 0, zOffset = 0, math.random(0, 3) }
		},
	}
end

return {
	lootboxGold,
}