function gadget:GetInfo()
    return {
        name      = 'Stockpile control',
        desc      = 'Limits Stockpile to set amount',
        author    = 'Bluestone, Damgam',
        version   = 'v1.0',
        date      = '23/04/2013',
        license   = 'WTFPL',
        layer     = 0,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then

	local isStockpilingUnit = { -- number represents maximum stockpile
		[UnitDefNames['armmercury'].id] = 5,
		[UnitDefNames['corscreamer'].id] = 5,

		[UnitDefNames['armthor'].id] = 2,

		[UnitDefNames['legmos'].id] = 3,
		[UnitDefNames['legmineb'].id] = 1,
	}
  
	local isStockpilingUnitScav = {}
	for defID, maxCount in pairs(isStockpilingUnit) do
		isStockpilingUnitScav[UnitDefNames[UnitDefs[defID].name .. "_scav"].id] = maxCount
	end

	table.mergeInPlace(isStockpilingUnit, isStockpilingUnitScav)

	local CMD_STOCKPILE = CMD.STOCKPILE
	local CMD_INSERT = CMD.INSERT
	local SpGiveOrderToUnit = Spring.GiveOrderToUnit

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua) -- Can't use StockPileChanged because that doesn't get called when the stockpile queue changes
		if unitID then
			if cmdID == CMD_STOCKPILE or (cmdID == CMD_INSERT and cmdParams[2]==CMD_STOCKPILE) then
				local pile,pileQ = Spring.GetUnitStockpile(unitID)
				local pilelimit = isStockpilingUnit[unitDefID] or 99
				local addQ = 1
				if cmdOptions.shift then
					if cmdOptions.ctrl then
						addQ = 100
					else
						addQ = 5
					end
				elseif cmdOptions.ctrl then
					addQ = 20
				end
				if cmdOptions.right then
					addQ = -addQ
				end
				if pile+pileQ == pilelimit and (not cmdOptions.right) then
					SendToUnsynced("PileLimit",teamID,pilelimit)
				end

				if pile+pileQ+addQ <= pilelimit then
					return true
				else
					if pile+pileQ <= pilelimit then
						local added = 0
						local needed = pilelimit - pile - pileQ
						while added < needed do
							SpGiveOrderToUnit(unitID, CMD_STOCKPILE, {}, 0) -- because SetUnitStockpile can't set the queue!
							added = added + 1
						end
						return false
					else
						return false
					end
				end
			end
		end
		return true
	end

-- UNSYNCED --
else

	local SpGetSpectatingState = Spring.GetSpectatingState
	local SpGetMyTeamID = Spring.GetMyTeamID
	local SpEcho = Spring.Echo

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("PileLimit",PileLimit)
	end

	function PileLimit(_,teamID,pilelimit)
		local myTeamID = SpGetMyTeamID()
		if myTeamID == teamID and not SpGetSpectatingState() then
			--SpEcho("Stockpile queue is already full (max " .. tostring(pilelimit) .. ").")
		end
	end

end

