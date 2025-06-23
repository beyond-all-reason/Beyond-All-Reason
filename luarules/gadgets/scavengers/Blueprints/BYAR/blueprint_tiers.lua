local UDN = UnitDefNames
local wallChance = 0
local gaiaTeamID = Spring.Utilities.GetScavTeamID() or Spring.GetGaiaTeamID()

function BPWallOrPopup(faction, tier)
	if gaiaTeamID then
		wallChance = Spring.GetTeamUnitCount(gaiaTeamID)
	end
	if math.random(1, Spring.GetTeamMaxUnits(gaiaTeamID)*0.9) > wallChance then
		local r = math.random(0,20)
		if tier == 1 then
			if faction == "arm" then
				if r == 15 then
					return UDN.armclaw_scav.id
				else
					return UDN.armdrag_scav.id
				end
			elseif faction == "cor" then
				if r == 15 then
					return UDN.cormaw_scav.id
				else
					return UDN.cordrag_scav.id
				end
			elseif faction == "scav" then
				if r == 15 then
					local r2 = math.random(1,3)
					if r2 == 1 then
						return UDN.corscavdtf_scav.id
					elseif r2 == 2 then
						return UDN.corscavdtl_scav.id
					elseif r2 == 3 then
						return UDN.corscavdtm_scav.id
					end
				else
					return UDN.corscavdrag_scav.id
				end
			end
		elseif tier == 2 then
			if faction == "arm" then
				if r == 15 then
					return UDN.armclaw_scav.id
				else
					return UDN.armfort_scav.id
				end
			elseif faction == "cor" then
				if r == 15 then
					return UDN.cormaw_scav.id
				else
					return UDN.corfort_scav.id
				end
			elseif faction == "scav" then
				if r == 15 then
					local r2 = math.random(1,3)
					if r2 == 1 then
						return UDN.corscavdtf_scav.id
					elseif r2 == 2 then
						return UDN.corscavdtl_scav.id
					elseif r2 == 3 then
						return UDN.corscavdtm_scav.id
					end
				else
					return UDN.corscavfort_scav.id
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
