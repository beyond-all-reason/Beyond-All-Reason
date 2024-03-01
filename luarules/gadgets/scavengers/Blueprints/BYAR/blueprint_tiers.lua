local UDN = UnitDefNames
local wallChance = 0
local scavMaxUnits = Spring.GetModOptions().maxunits

function BPWallOrPopup(faction, tier)
	if ScavengerTeamID then
		wallChance = Spring.GetTeamUnitCount(ScavengerTeamID)
	end
	if math.random(1, scavMaxUnits*0.9) > wallChance then
		local r = math.random(0,20)
		if tier == 1 then
			if faction == "arm" then
				if r == 15 then
					return UDN.armada_dragonsclaw_scav.id
				else
					return UDN.armada_dragonsteeth_scav.id
				end
			elseif faction == "cor" then
				if r == 15 then
					return UDN.cortex_dragonsmaw_scav.id
				else
					return UDN.cortex_dragonsteeth_scav.id
				end
			elseif faction == "scav" then
				if r == 15 then
					local r2 = math.random(1,3)
					if r2 == 1 then
						return UDN.cortex_scavdragonsmaw_scav.id
					elseif r2 == 2 then
						return UDN.cortex_scavdragonsclaw_scav.id
					elseif r2 == 3 then
						return UDN.cortex_scavmissilewall_scav.id
					end
				else
					return UDN.cortex_scavdragonsteeth_scav.id
				end
			end
		elseif tier == 2 then
			if faction == "arm" then
				if r == 15 then
					return UDN.armada_dragonsclaw_scav.id
				else
					return UDN.armada_fortificationwall_scav.id
				end
			elseif faction == "cor" then
				if r == 15 then
					return UDN.cortex_dragonsmaw_scav.id
				else
					return UDN.cortex_fortificationwall_scav.id
				end
			elseif faction == "scav" then
				if r == 15 then
					local r2 = math.random(1,3)
					if r2 == 1 then
						return UDN.cortex_scavdragonsmaw_scav.id
					elseif r2 == 2 then
						return UDN.cortex_scavdragonsclaw_scav.id
					elseif r2 == 3 then
						return UDN.cortex_scavmissilewall_scav.id
					end
				else
					return UDN.cortex_scavfortificationwall_scav.id
				end
			end
		end
	end
end

local tiers = {
	T0 = 0,
	T1 = 1,
	T2 = 2,
	T3 = 3,
	T4 = 4,
}

local blueprintTypes = {
	Land = 1,
	Sea = 2,
}

return {
	Tiers = tiers,
	BlueprintTypes = blueprintTypes,
}