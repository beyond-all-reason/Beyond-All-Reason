local gadget = gadget ---@type Gadget

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

local GG = gadgetHandler.GG
local transferInstantly = true	-- false = transfer geo on completion


_G.transferredUnits = {}

local isGeo = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.geothermal then
		isGeo[unitDefID] = unitDef.metalCost
	end
end


local function hasGeoUnderneat(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 10)
	for k, uID in ipairs(units) do
		if isGeo[Spring.GetUnitDefID(uID)] then
			if unitID ~= uID then
				return uID
			end
		end
	end
	return false
end

-- make t1 geo below unselectable
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isGeo[unitDefID] then
		local geo = hasGeoUnderneat(unitID)
		if geo then
			Spring.SetUnitNoSelect(geo, true)
			if transferInstantly then
				local mexTeamID = Spring.GetUnitTeam(geo)
				if mexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(mexTeamID, false)) then
					_G.transferredUnits[unitID] = Spring.GetGameFrame()
					Spring.TransferUnit(unitID, mexTeamID, GG.CHANGETEAM_REASON.UPGRADED)
				end
			end
		end
	end
end

-- make t1 geo below selectable again
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isGeo[unitDefID] then
		local geo = hasGeoUnderneat(unitID)
		if geo then
			Spring.SetUnitNoSelect(geo, false)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isGeo[unitDefID] then
		Spring.SetUnitCOBValue(unitID, COB.YARD_OPEN, 1)
		local geo = hasGeoUnderneat(unitID)
		if geo then
			local geoTeamID = Spring.GetUnitTeam(geo)
			Spring.DestroyUnit(geo, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isGeo[Spring.GetUnitDefID(geo)])
			if not transferInstantly and geoTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(geoTeamID, false)) then
				_G.transferredUnits[unitID] = Spring.GetGameFrame()
				Spring.TransferUnit(unitID, geoTeamID, GG.CHANGETEAM_REASON.UPGRADED)
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
