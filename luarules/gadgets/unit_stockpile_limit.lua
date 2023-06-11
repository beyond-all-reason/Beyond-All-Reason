function gadget:GetInfo()
    return {
        name      = 'Stockpile control',
        desc      = 'Limits Stockpile to set amount',
        author    = 'Bluestone, Damgam',
        version   = 'v1.0',
        date      = '23/04/2013',
		license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end



if gadgetHandler:IsSyncedCode() then -- SYNCED --

	local CMD_STOCKPILE = CMD.STOCKPILE
	local CMD_INSERT = CMD.INSERT
	local StockpileDesiredTarget = {}

	----------------------------------------------------------------------------
	-- Config
	----------------------------------------------------------------------------
	local defaultStockpileLimit = 99
	local isStockpilingUnit = { -- number represents maximum stockpile. You can also use stockpileLimit customParam which overwrites whatever is set in this table
		[UnitDefNames['armmercury'].id] = 5,
		[UnitDefNames['corscreamer'].id] = 5,

		[UnitDefNames['armthor'].id] = 2,

		[UnitDefNames['legmos'].id] = 8,
		[UnitDefNames['legmineb'].id] = 1,

		[UnitDefNames['armsilo'].id] = 10,
		[UnitDefNames['corsilo'].id] = 10,

		[UnitDefNames['armamd'].id] = 20,
		[UnitDefNames['corfmd'].id] = 20,
		[UnitDefNames['chicken_antinuke'].id] = 3,

		[UnitDefNames['armcarry'].id] = 20,
		[UnitDefNames['corcarry'].id] = 20,

		[UnitDefNames['armscab'].id] = 20,
		[UnitDefNames['cormabm'].id] = 20,

		[UnitDefNames['armemp'].id] = 10,
		[UnitDefNames['cortron'].id] = 10,

		[UnitDefNames['armbotrail'].id] = 50,
		
		[UnitDefNames['legcom'].id] = 2,
		[UnitDefNames['legcomlvl2'].id] = 2,
		[UnitDefNames['legcomlvl3'].id] = 3,
		[UnitDefNames['legcomlvl4'].id] = 4,
		
	}
	----------------------------------------------------------------------------
	-- Scav copies
	----------------------------------------------------------------------------

	local isStockpilingUnitScav = {}
	for defID, maxCount in pairs(isStockpilingUnit) do
		if UnitDefNames[UnitDefs[defID].name .. "_scav"] then
			isStockpilingUnitScav[UnitDefNames[UnitDefs[defID].name .. "_scav"].id] = maxCount
		end
	end
	table.mergeInPlace(isStockpilingUnit, isStockpilingUnitScav)

	----------------------------------------------------------------------------
	----------------------------------------------------------------------------

	local GetUnitStockpile	= Spring.GetUnitStockpile
	local GiveOrderToUnit	= Spring.GiveOrderToUnit

	local canStockpile = {}
	for udid, ud in pairs(UnitDefs) do
		if ud.canStockpile then
			canStockpile[udid] = true
		end
		if ud.customParams and ud.customParams.stockpileLimit then
			isStockpilingUnit[udid] = tonumber(ud.customParams.stockpileLimit)
		elseif ud.customParams and ud.customParams.stockpilelimit then
			isStockpilingUnit[udid] = tonumber(ud.customParams.stockpilelimit)
		end
	end

	function UpdateStockpile(unitID, unitDefID)
		local MaxStockpile = math.min(isStockpilingUnit[unitDefID] or defaultStockpileLimit, StockpileDesiredTarget[unitID])

		local stock,queued = GetUnitStockpile(unitID)
		if queued and stock then
			local count = stock + queued - MaxStockpile
			while count < 0  do
				if count <= -100 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "ctrl", "shift" })
					count = count + 100
				elseif count <= -20 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "ctrl" })
					count = count + 20
				elseif count <= -5 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "shift" })
					count = count + 5
				else
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, 0)
					count = count + 1
				end
			end
			while count > 0 do
				if count >= 100 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "ctrl", "shift", "right" })
					count = count - 100
				elseif count >= 20 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "ctrl", "right" })
					count = count - 20
				elseif count >= 5 then
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "shift", "right" })
					count = count - 5
				else
					GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "right" })
					count = count - 1
				end
			end
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua) -- Can't use StockPileChanged because that doesn't get called when the stockpile queue changes
		if unitID then
			if cmdID == CMD_STOCKPILE or (cmdID == CMD_INSERT and cmdParams[2]==CMD_STOCKPILE) then
				local pile,pileQ = Spring.GetUnitStockpile(unitID)
				if pile == nil then
					return true
				end
				local pilelimit = math.min(isStockpilingUnit[unitDefID] or defaultStockpileLimit, StockpileDesiredTarget[unitID])
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
				if fromLua == true then 	-- fromLua is *true* if command is sent from a gadget and *false* if it's sent by a player
					if pile+pileQ+addQ <= pilelimit then
						return true
					else
						return false
					end
				else
					StockpileDesiredTarget[unitID] = math.max(math.min(StockpileDesiredTarget[unitID] + addQ, isStockpilingUnit[unitDefID] or defaultStockpileLimit),0) -- let's make sure desired target doesn't go above maximum of this unit
					UpdateStockpile(unitID, unitDefID)
					return false
				end
			end
		end
		return true
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if canStockpile[unitDefID] then
			StockpileDesiredTarget[unitID] = isStockpilingUnit[unitDefID] or defaultStockpileLimit
			UpdateStockpile(unitID, unitDefID)
		end
	end
	
	function gadget:UnitGiven(unitID, unitDefID, unitTeam)
		if canStockpile[unitDefID] then
			StockpileDesiredTarget[unitID] = isStockpilingUnit[unitDefID] or defaultStockpileLimit
			UpdateStockpile(unitID, unitDefID)
		end
	end
	
	function gadget:UnitCaptured(unitID, unitDefID, unitTeam)
		if canStockpile[unitDefID] then
			StockpileDesiredTarget[unitID] = isStockpilingUnit[unitDefID] or defaultStockpileLimit
			UpdateStockpile(unitID, unitDefID)
		end
	end

	function gadget:StockpileChanged(unitID, unitDefID, unitTeam)
		UpdateStockpile(unitID, unitDefID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		StockpileDesiredTarget[unitID] = nil
	end
	
	function gadget:Initialize()
		local units = Spring.GetAllUnits()
		for i = 1, #units do
			local unitDefID = Spring.GetUnitDefID(units[i])
			gadget:UnitCreated(units[i], unitDefID)
		end
	end
end

