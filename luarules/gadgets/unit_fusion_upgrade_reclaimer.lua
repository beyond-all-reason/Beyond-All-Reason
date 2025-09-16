local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Fusion Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds lower fusion",
		author    = "Floris (modified)",
		date      = "February 2022",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end


local transferInstantly = true


_G.transferredUnits = {}

local isFusion = {}

for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.evolvefusion then
        isFusion[unitDefID] = unitDef.metalCost
    end
end

local function hasFusionUnderneat(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 24)
	for k, uID in ipairs(units) do
		if isFusion[Spring.GetUnitDefID(uID)] then
			if unitID ~= uID then
				return uID
			end
		end
	end
	return false
end

-- make fusion below unselectable
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isFusion[unitDefID] then
		local fusion = hasFusionUnderneat(unitID)
		if fusion then
			Spring.SetUnitNoSelect(fusion, true)
			if transferInstantly then
				local mexTeamID = Spring.GetUnitTeam(fusion)
				if mexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(mexTeamID, false)) then
					_G.transferredUnits[unitID] = Spring.GetGameFrame()
					Spring.TransferUnit(unitID, mexTeamID)
				end
			end
		end
	end
end

-- make fusion below selectable again
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isFusion[unitDefID] then
		local fusion = hasFusionUnderneat(unitID)
		if fusion then
			Spring.SetUnitNoSelect(fusion, false)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isFusion[unitDefID] then
		Spring.SetUnitCOBValue(unitID, COB.YARD_OPEN, 1)
		local fusion = hasFusionUnderneat(unitID)
		if fusion then
			local fusionTeamID = Spring.GetUnitTeam(fusion)
			Spring.DestroyUnit(fusion, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isFusion[Spring.GetUnitDefID(fusion)])
			if not transferInstantly and fusionTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(fusionTeamID, false)) then
				_G.transferredUnits[unitID] = Spring.GetGameFrame()
				Spring.TransferUnit(unitID, fusionTeamID)
			end
		end
	end
end