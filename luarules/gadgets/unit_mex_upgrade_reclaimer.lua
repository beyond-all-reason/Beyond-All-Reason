function gadget:GetInfo()
	return {
		name      = "Mex Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds t1 mex when t2 on top has finished",
		author    = "Floris",
		date      = "October 2021",
		license   = "",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isT1Mex = {}
local isT2Mex = {}
for unitDefID, unitDef in pairs(UnitDefs) do --almost all chickens have dying anims
	if unitDef.extractsMetal > 0 then
		if unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) > 1 then
			isT2Mex[unitDefID] = unitDef.metalCost
		else
			isT1Mex[unitDefID] = unitDef.metalCost
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isT2Mex[unitDefID] then
		-- search for t1 mex underneath
		local x, y, z = Spring.GetUnitPosition(unitID)
		local units = Spring.GetUnitsInCylinder(x, z, 10)
		for k, uID in ipairs(units) do
			if isT1Mex[Spring.GetUnitDefID(uID)] then
				Spring.DestroyUnit(uID, false, true)
				Spring.AddTeamResource(unitTeam, "metal", isT1Mex[Spring.GetUnitDefID(uID)])
			end
		end
	end
end
