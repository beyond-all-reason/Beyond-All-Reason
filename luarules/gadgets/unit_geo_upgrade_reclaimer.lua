function gadget:GetInfo()
	return {
		name      = "Geo Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds t1 geo when t2 on top has finished, also shares t2 geos build upon ally t1 geo owner",
		author    = "Floris",
		date      = "February 2022",
		license   = "",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isT1Geo = {}
local isT2Geo = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.geothermal then
		if unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) >= 2 then
			isT2Geo[unitDefID] = unitDef.metalCost
		else
			isT1Geo[unitDefID] = unitDef.metalCost
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isT2Geo[unitDefID] then
		-- search for t1 geo underneath
		local x, y, z = Spring.GetUnitPosition(unitID)
		local units = Spring.GetUnitsInCylinder(x, z, 10)
		for k, uID in ipairs(units) do
			if isT1Geo[Spring.GetUnitDefID(uID)] then
				local t1GeoTeamID = Spring.GetUnitTeam(uID)
				Spring.DestroyUnit(uID, false, true)
				Spring.AddTeamResource(unitTeam, "metal", isT1Geo[Spring.GetUnitDefID(uID)])
				if t1GeoTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(t1GeoTeamID, false)) then -- and Spring.AreTeamsAllied(t1GeoTeamID, unitTeam) then
					Spring.TransferUnit(unitID, t1GeoTeamID)
					break
				end
			end
		end
	end
end
