local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Mex Upgrade Reclaimer",
		desc      = "Insta reclaims/refunds a mex when another mex on top has finished, also shares mexes build upon ally mex owner",
		author    = "Floris",
		date      = "October 2021",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GG = gadgetHandler.GG

local transferInstantly = true	-- false = transfer mex on completion


_G.transferredUnits = {}
-- table of all mex unitDefIDs
local isMex = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = unitDef.metalCost
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

-- get the first mex bellow that isn't itself, stacking more than one should be prevented by yardmaps
local function hasMexBeneath(unitID)
	local x, _, z = Spring.GetUnitPosition(unitID)
	local units = Spring.GetUnitsInCylinder(x, z, 10)
	for k, uID in ipairs(units) do
		if isMex[Spring.GetUnitDefID(uID)] then
			if unitID ~= uID then
				return uID
			end
		end
	end
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	-- make mex below unselectable
	if isMex[unitDefID] then
		local mex = hasMexBeneath(unitID)
		if mex then
			Spring.SetUnitNoSelect(mex, true)
			if transferInstantly then
				local mexTeamID = Spring.GetUnitTeam(mex)
				if mexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(mexTeamID, false)) then
					_G.transferredUnits[unitID] = Spring.GetGameFrame()
					Spring.TransferUnit(unitID, mexTeamID, false, GG.CHANGETEAM_REASON.UPGRADED)
				end
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- make mex below selectable again
	if isMex[unitDefID] then
		local mex = hasMexBeneath(unitID)
		if mex then
			Spring.SetUnitNoSelect(mex, false)
		end
    end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	-- on completion open up yardmap to allow for another mex to built ontop
	if isMex[unitDefID] then
        Spring.SetUnitCOBValue(unitID, COB.YARD_OPEN, 1)
		-- if theres a mex below this one reclaim it, and donate this one to the owner of the previous mex
		local mex = hasMexBeneath(unitID)
		if mex then
			local mexTeamID = Spring.GetUnitTeam(mex)
			Spring.DestroyUnit(mex, false, true)
			Spring.AddTeamResource(unitTeam, "metal", isMex[Spring.GetUnitDefID(mex)])
			if not transferInstantly and mexTeamID ~= unitTeam and not select(3, Spring.GetTeamInfo(mexTeamID, false)) then
				_G.transferredUnits[unitID] = Spring.GetGameFrame()
				Spring.TransferUnit(unitID, mexTeamID, false, GG.CHANGETEAM_REASON.UPGRADED)
			end
		end
	end
end


function gadget:GameFrame(gf)
	if gf % 99 then
		local newTransferredUnits = {}
		for unitID, frame in pairs(_G.transferredUnits) do
			if frame+30 > gf then
				newTransferredUnits[unitID] = frame
			end
		end
		_G.transferredUnits = newTransferredUnits
	end
end
