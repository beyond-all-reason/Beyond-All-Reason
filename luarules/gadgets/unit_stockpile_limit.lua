local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Stockpile control",
		desc = "Limits Stockpile to set amount",
		author = "Bluestone, Damgam",
		version = "v1.0",
		date = "23/04/2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local defaultStockpileLimit = 99

	local CMD_STOCKPILE = CMD.STOCKPILE

	---@type table<number, integer?>
	local stockpileTarget = {}
	---@type table<number, integer?>
	local unitStockpileLimit = {}

	local GetUnitDefID = Spring.GetUnitDefID
	local GetUnitStockpile = Spring.GetUnitStockpile
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local SetUnitStockpile = Spring.SetUnitStockpile
	local mathClamp = math.clamp
	local mathFloor = math.floor

	local stockpileStep = {
		single = { amount = 1, add = 0, remove = { "right" } },
		small = { amount = 5, add = { "shift" }, remove = { "shift", "right" } },
		medium = { amount = 20, add = { "ctrl" }, remove = { "ctrl", "right" } },
		large = { amount = 100, add = { "ctrl", "shift" }, remove = { "ctrl", "shift", "right" } },
	}

	local stockpileStepsDescending = {
		stockpileStep.large,
		stockpileStep.medium,
		stockpileStep.small,
		stockpileStep.single,
	}

	local function parsedStockpileLimit(weaponDef)
		local configured = weaponDef.customParams.stockpilelimit
		local limit = tonumber(configured)

		if not limit or limit < 0 then
			Spring.Log(
				gadget:GetInfo().name,
				LOG.WARNING,
				weaponDef.name .. ": ignoring stockpilelimit of " .. tostring(configured)
			)

			return nil
		end

		return mathFloor(limit)
	end

	for udid, ud in pairs(UnitDefs) do
		if ud.canStockpile then
			unitStockpileLimit[udid] = defaultStockpileLimit
			if ud.weapons then
				for i = 1, #ud.weapons do
					local weaponDef = WeaponDefs[ud.weapons[i].weaponDef]
					if weaponDef.stockpile and weaponDef.customParams and weaponDef.customParams.stockpilelimit then
						unitStockpileLimit[udid] = parsedStockpileLimit(weaponDef) or unitStockpileLimit[udid]
					end
				end
			end
		end
	end

	local function commandStockpileDelta(cmdOptions)
		local step
		if cmdOptions.shift then
			step = cmdOptions.ctrl and stockpileStep.large or stockpileStep.small
		elseif cmdOptions.ctrl then
			step = stockpileStep.medium
		else
			step = stockpileStep.single
		end

		return cmdOptions.right and -step.amount or step.amount
	end

	local function giveStockpileOrders(unitID, delta)
		for i = 1, #stockpileStepsDescending do
			local step = stockpileStepsDescending[i]
			while delta >= step.amount do
				GiveOrderToUnit(unitID, CMD_STOCKPILE, {}, step.add)
				delta = delta - step.amount
			end
			while delta <= -step.amount do
				GiveOrderToUnit(unitID, CMD_STOCKPILE, {}, step.remove)
				delta = delta + step.amount
			end
		end
	end

	local function convergeStockpile(unitID)
		local target = stockpileTarget[unitID]
		if not target then
			return
		end

		local stock, queued = GetUnitStockpile(unitID)
		if not (stock and queued) then
			return
		end

		giveStockpileOrders(unitID, target - stock - queued)
	end

	local function isRealNumber(value)
		return type(value) == "number" and value == value
	end

	local function setStockpileTarget(unitID, unitDefID, target)
		local limit = unitStockpileLimit[unitDefID]
		if not limit or not isRealNumber(target) then
			return false
		end

		stockpileTarget[unitID] = mathClamp(mathFloor(target), 0, limit)
		convergeStockpile(unitID)

		return true
	end

	local function addStockpileTarget(unitID, unitDefID, delta)
		local target = stockpileTarget[unitID]
		if not target then
			return false
		end

		return setStockpileTarget(unitID, unitDefID, target + delta)
	end

	local function trimStockpileToTarget(unitID, unitDefID, target)
		if not setStockpileTarget(unitID, unitDefID, target) then
			return false
		end

		local clampedTarget = stockpileTarget[unitID]
		local stock, _, buildPercent = GetUnitStockpile(unitID)
		if stock and stock > clampedTarget then
			SetUnitStockpile(unitID, clampedTarget, buildPercent)
		end

		return true
	end

	GG.StockpileLimit = {
		---Stockpile limit of the unit's def.
		---@param unitID integer
		---@return integer? limit `nil` when the unit cannot stockpile.
		GetLimit = function(unitID)
			local unitDefID = GetUnitDefID(unitID)

			return unitDefID and unitStockpileLimit[unitDefID]
		end,
		---@param unitDefID integer
		---@return integer? limit `nil` when the def cannot stockpile.
		GetDefLimit = function(unitDefID)
			return unitStockpileLimit[unitDefID]
		end,
		---Stockpiled plus queued rounds the unit is working towards.
		---@param unitID integer
		---@return integer? target `nil` when the unit is not tracked.
		GetTarget = function(unitID)
			return stockpileTarget[unitID]
		end,
		---Sets the target, clamped to the unit's limit. Only the queue moves.
		---@param unitID integer
		---@param target number Floored, then clamped to `0`..limit.
		---@return boolean applied `false` when the unit cannot stockpile.
		SetTarget = function(unitID, target)
			return setStockpileTarget(unitID, GetUnitDefID(unitID), target)
		end,
		---@param unitID integer
		---@param delta number Added to the current target.
		---@return boolean applied `false` when the unit is not tracked.
		AddTarget = function(unitID, delta)
			return addStockpileTarget(unitID, GetUnitDefID(unitID), delta)
		end,
		---Sets the target and discards built rounds above it.
		---@param unitID integer
		---@param target number Floored, then clamped to `0`..limit.
		---@return boolean applied `false` when the unit cannot stockpile.
		TrimToTarget = function(unitID, target)
			return trimStockpileToTarget(unitID, GetUnitDefID(unitID), target)
		end,
	}

	-- StockpileChanged doesn't fire on queue-only changes, so player commands have to be caught here
	function gadget:AllowCommand(
		unitID,
		unitDefID,
		teamID,
		cmdID,
		cmdParams,
		cmdOptions,
		cmdTag,
		playerID,
		fromSynced,
		fromLua
	)
		if not unitID then
			return true
		end

		-- fromLua is true for gadget-issued commands, false for player ones
		if fromLua == true and fromSynced == true then
			return true
		end

		if GetUnitStockpile(unitID) == nil then
			return true
		end

		addStockpileTarget(unitID, unitDefID, commandStockpileDelta(cmdOptions))

		return false
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if stockpileTarget[unitID] then
			return
		end

		local limit = unitStockpileLimit[unitDefID]
		if limit then
			setStockpileTarget(unitID, unitDefID, limit)
		end
	end
	gadget.UnitGiven = gadget.UnitCreated

	function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
		convergeStockpile(unitID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		stockpileTarget[unitID] = nil
	end

	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD_STOCKPILE)
		local units = Spring.GetAllUnits()
		for i = 1, #units do
			gadget:UnitCreated(units[i], GetUnitDefID(units[i]))
		end
	end

	function gadget:Shutdown()
		GG.StockpileLimit = nil
	end
end
