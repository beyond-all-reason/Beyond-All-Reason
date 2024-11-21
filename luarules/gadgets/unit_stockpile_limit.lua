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


if gadgetHandler:IsSyncedCode() then

	local CMD_STOCKPILE = CMD.STOCKPILE
	local CMD_INSERT = CMD.INSERT
	local StockpileDesiredTarget = {}

	local defaultStockpileLimit = 99
	local isStockpilingUnitNames = { -- number represents maximum stockpile. You can also use stockpileLimit customParam which overwrites whatever is set in this table
		['armmercury'] = 5,
		['corscreamer'] = 5,

		['armthor'] = 2,

		['legmos'] = 8,
		['legmost3'] = 8,
		['legmineb'] = 1,
		['legsrailt4'] = 3,

		['armsilo'] = 10,
		['corsilo'] = 10,
		['legsilo'] = 10,
		['cordesolator'] = 10,
		['armseadragon'] = 10,


		['armamd'] = 20,
		['legabm'] = 20,
		['corfmd'] = 20,
		['raptor_turret_antinuke_t2_v1'] = 5,
		['raptor_turret_antinuke_t3_v1'] = 10,

		['armjuno'] = 20,
		['corjuno'] = 20,

		['armcarry'] = 20,
		['corcarry'] = 20,

		['armantiship'] = 20,
		['corantiship'] = 20,

		['armscab'] = 20,
		['cormabm'] = 20,

		['armemp'] = 10,
		['cortron'] = 10,
		['legperdition'] = 10,

		['armbotrail'] = 50,
		['armcomlvl2'] = 3,
		['armcomlvl3'] = 3,
		['armdecomlvl3'] = 1,
		['armcomlvl4'] = 3,
		['armcomlvl5'] = 4,
		['armcomlvl6'] = 4,
		['armdecomlvl6'] = 2,
		['armcomlvl7'] = 4,
		['armcomlvl8'] = 5,
		['armcomlvl9'] = 5,
		['armcomlvl10'] = 5,
		['armdecomlvl10'] = 2,
		['legcom'] = 2,
		['legcomlvl2'] = 3,
		['legcomlvl3'] = 3,
		['legdecomlvl3'] = 1,
		['legcomlvl4'] = 3,
		['legcomlvl5'] = 4,
		['legcomlvl6'] = 4,
		['legdecomlvl6'] = 2,
		['legcomlvl7'] = 4,
		['legcomlvl8'] = 5,
		['legcomlvl9'] = 5,
		['legcomlvl10'] = 5,
		['legdecomlvl10'] = 3,

		['legstarfall'] = 1,
		['legrampart'] = 20,
	}
	-- convert unitname -> unitDefID + add scavengers
	local isStockpilingUnit = {}
	for name, params in pairs(isStockpilingUnitNames) do
		if UnitDefNames[name] then
			isStockpilingUnit[UnitDefNames[name].id] = params
			if UnitDefNames[name..'_scav'] then
				isStockpilingUnit[UnitDefNames[name..'_scav'].id] = params
			end
		end
	end
	isStockpilingUnitNames = nil

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
		local MaxStockpile = math.max(math.min(isStockpilingUnit[unitDefID] or defaultStockpileLimit, StockpileDesiredTarget[unitID]), 0)

		local stock,queued = GetUnitStockpile(unitID)
		if queued and stock then
			local count = stock + queued - MaxStockpile
			while count < 0 do
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
				local stock, _ = Spring.GetUnitStockpile(unitID)
				if stock == nil then
					return true
				end
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
				if fromLua == true and fromSynced == true then 	-- fromLua is *true* if command is sent from a gadget and *false* if it's sent by a player.
					return true
				else
					StockpileDesiredTarget[unitID] = math.max(math.min(StockpileDesiredTarget[unitID] + addQ, isStockpilingUnit[unitDefID] or defaultStockpileLimit), 0) -- let's make sure desired target doesn't go above maximum of this unit, and doesn't go below 0
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

	function gadget:StockpileChanged(unitID, unitDefID, unitTeam)
		UpdateStockpile(unitID, unitDefID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		StockpileDesiredTarget[unitID] = nil
	end

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_STOCKPILE)
		gadgetHandler:RegisterAllowCommand(CMD_INSERT)
		local units = Spring.GetAllUnits()
		for i = 1, #units do
			local unitDefID = Spring.GetUnitDefID(units[i])
			gadget:UnitCreated(units[i], unitDefID)
		end
	end
end

