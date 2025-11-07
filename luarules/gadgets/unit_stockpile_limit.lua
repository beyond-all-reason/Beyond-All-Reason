local gadget = gadget ---@type Gadget

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

	local defaultStockpileLimit = 99

	local CMD_STOCKPILE = CMD.STOCKPILE
	local CMD_INSERT = CMD.INSERT
	local StockpileDesiredTarget = {}

	local unitStockpileLimit = {}

	local GetUnitStockpile	= Spring.GetUnitStockpile
	local GiveOrderToUnit	= Spring.GiveOrderToUnit
	local mathClamp = math.clamp

	for udid, ud in pairs(UnitDefs) do
		if ud.canStockpile then
			unitStockpileLimit[udid] = defaultStockpileLimit
			if ud.weapons then
				for i = 1, #ud.weapons do
					local weaponDef = WeaponDefs[ud.weapons[i].weaponDef]
					if weaponDef.stockpile and weaponDef.customParams and weaponDef.customParams.stockpilelimit then
						unitStockpileLimit[udid] = tonumber(weaponDef.customParams.stockpilelimit)
					end
				end
			end
		end
	end

	function UpdateStockpile(unitID, unitDefID)
		if not unitID then
			return
		end
		local MaxStockpile = mathClamp(unitStockpileLimit[unitDefID], 0, StockpileDesiredTarget[unitID])

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
			if cmdID == CMD_STOCKPILE or (cmdID == CMD_INSERT and cmdParams[2] == CMD_STOCKPILE) then
				local stock, _ = GetUnitStockpile(unitID)
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
					if StockpileDesiredTarget[unitID] then
						StockpileDesiredTarget[unitID] = mathClamp(StockpileDesiredTarget[unitID] + addQ, 0, unitStockpileLimit[unitDefID])
						UpdateStockpile(unitID, unitDefID)
					end
					return false
				end
			end
		end
		return true
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitStockpileLimit[unitDefID] then
			StockpileDesiredTarget[unitID] = unitStockpileLimit[unitDefID]
			UpdateStockpile(unitID, unitDefID)
		end
	end
	gadget.UnitGiven = gadget.UnitCreated

	function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
		UpdateStockpile(unitID, unitDefID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
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

