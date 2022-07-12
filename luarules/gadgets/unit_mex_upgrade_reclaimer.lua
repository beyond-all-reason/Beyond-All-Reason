function gadget:GetInfo()
	return {
		name      = "Mex Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds t1 mex when t2 on top has finished, also shares t2 mexes build upon ally t1 mex owner",
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
local isT15Mex = {}
local isT2Mex = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		if unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) >= 2 then
			isT2Mex[unitDefID] = unitDef.metalCost
		elseif unitDef.extractsMetal > 0.0015 and unitDef.extractsMetal < 0.004 then
			isT15Mex[unitDefID] = unitDef.metalCost
		else
			isT1Mex[unitDefID] = unitDef.metalCost
		end
	end
end

-- [UNFINISHED] possible alternative method
-- transform t1 mex assist to t2 mex assist
--function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
--	if isT1Mex[unitDefID] then
--		-- search for t2 mex on top
--		local x, y, z = Spring.GetUnitPosition(unitID)
--		local units = Spring.GetUnitsInCylinder(x, z, 10)
--		for k, uID in ipairs(units) do
--			if isT2Mex[Spring.GetUnitDefID(uID)] then
--				--Spring.GiveOrderToUnit(unitID, CMD.INSERT, cmdParams, cmdOptions.coded)
--				return false
--			end
--		end
--	end
--	return true
--end

local function hasMexUnderneat(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 10)
	for k, uID in ipairs(units) do
		if isT1Mex[Spring.GetUnitDefID(uID)] then
			return uID
		end
	end
	return false
end

local function hasT15MexUnderneat(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 10)
	for k, uID in ipairs(units) do
		if isT15Mex[Spring.GetUnitDefID(uID)] then
			return uID
		end
	end
	return false
end

-- make t1 mex below unselectable
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isT2Mex[unitDefID] then
		local t1Mex = hasMexUnderneat(unitID)
		local t15Mex = hasT15MexUnderneat(unitID)
		if t1Mex then
			Spring.SetUnitNoSelect(t1Mex, true)
		elseif t15Mex then
			Spring.SetUnitNoSelect(t15Mex, true)
		end
	end
end

-- make t1 mex below selectable again
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if isT2Mex[unitDefID] then
		local t1Mex = hasMexUnderneat(unitID)
		local t15Mex = hasT15MexUnderneat(unitID)
		if t1Mex then
			Spring.SetUnitNoSelect(t1Mex, false)
		elseif t15Mex then
			Spring.SetUnitNoSelect(t15Mex, false)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isT2Mex[unitDefID] then
		local t1Mex = hasMexUnderneat(unitID)
		local t15Mex = hasT15MexUnderneat(unitID)
		if t1Mex then
			local t1MexTeamID = Spring.GetUnitTeam(t1Mex)
			Spring.DestroyUnit(t1Mex, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isT1Mex[Spring.GetUnitDefID(t1Mex)])
			if t1MexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(t1MexTeamID, false)) then -- and Spring.AreTeamsAllied(t1MexTeamID, unitTeam) then
				Spring.TransferUnit(unitID, t1MexTeamID)
			end
		elseif t15Mex then
			local t15MexTeamID = Spring.GetUnitTeam(t15Mex)
			Spring.DestroyUnit(t15Mex, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isT15Mex[Spring.GetUnitDefID(t15Mex)])
			if t15MexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(t15MexTeamID, false)) then -- and Spring.AreTeamsAllied(t1MexTeamID, unitTeam) then
				Spring.TransferUnit(unitID, t15MexTeamID)
			end
		end
	elseif isT15Mex[unitDefID] then
		local t1Mex = hasMexUnderneat(unitID)
		if t1Mex then
			local t1MexTeamID = Spring.GetUnitTeam(t1Mex)
			Spring.DestroyUnit(t1Mex, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isT1Mex[Spring.GetUnitDefID(t1Mex)])
			if t1MexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(t1MexTeamID, false)) then -- and Spring.AreTeamsAllied(t1MexTeamID, unitTeam) then
				Spring.TransferUnit(unitID, t1MexTeamID)
			end
		end
	end
end
