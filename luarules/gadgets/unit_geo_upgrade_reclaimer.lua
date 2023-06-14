function gadget:GetInfo()
	return {
		name      = "Geo Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds t1 geo when t2 on top has finished, also shares t2 geos build upon ally t1 geo owner",
		author    = "Floris",
		date      = "February 2022",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

_G.transferredUnits = {}

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


local function hasGeoUnderneat(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 10)
	for k, uID in ipairs(units) do
		if isT1Geo[Spring.GetUnitDefID(uID)] then
			return uID
		end
	end
	return false
end

-- make t1 geo below unselectable
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isT2Geo[unitDefID] then
		local t1Geo = hasGeoUnderneat(unitID)
		if t1Geo then
			Spring.SetUnitNoSelect(t1Geo, true)
		end
	end
end

-- make t1 geo below selectable again
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isT2Geo[unitDefID] then
		local t1Geo = hasGeoUnderneat(unitID)
		if t1Geo then
			Spring.SetUnitNoSelect(t1Geo, false)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isT2Geo[unitDefID] then
		local t1Geo = hasGeoUnderneat(unitID)
		if t1Geo then
			local t1GeoTeamID = Spring.GetUnitTeam(t1Geo)
			Spring.DestroyUnit(t1Geo, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isT1Geo[Spring.GetUnitDefID(t1Geo)])
			if t1GeoTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(t1GeoTeamID, false)) then -- and Spring.AreTeamsAllied(t1GeoTeamID, unitTeam) then
				_G.transferredUnits[unitID] = Spring.GetGameFrame()
				Spring.TransferUnit(unitID, t1GeoTeamID)
			end
		end
	end
end


-- the mex upgrade reclaimer gadget already does this
--function gadget:GameFrame(gf)
--	if gf % 99 then
--		local newTransferredUnits = {}
--		for unitID, frame in pairs(_G.transferredUnits) do
--			if frame+30 > gf then
--				newTransferredUnits[newTransferredUnits] = frame
--			end
--		end
--		_G.transferredUnits = newTransferredUnits
--	end
--end
