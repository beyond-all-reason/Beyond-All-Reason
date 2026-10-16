local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local ensureTable = table.ensureTable

local POLL_FRAMES = 0.5 * Game.gameSpeed

local hasStockpile = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef] ---@as table
		if weaponDef.stockpile then
			hasStockpile[unitDefID] = true
			-- break -- Match `GetUnitStockpile` and keep the last match.
		end
	end
end

local function getTriggerState(context, triggerID)
	local stockpileState = context.StockpileState
	return ensureTable(stockpileState, triggerID)
end

---@return integer
local function countActivations(threshold, lastProgress, progress, completed)
	if not completed then
		return (lastProgress < threshold and threshold <= progress) and 1 or 0
	end
	return (lastProgress < threshold and 1 or 0) + (threshold <= progress and 1 or 0)
end

return {
	type = 'StockpileProgress',
	parameters = {
		{ name = 'progress',    required = true,  type = ParameterTypes.Fraction },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if frameNumber % POLL_FRAMES ~= 0 then
				return
			end
			local unitStates = context.StockpileState[triggerID]
			if not unitStates then
				return
			end

			local parameters = trigger.parameters
			for unitID, state in pairs(unitStates) do
				local _, _, progress = Spring.GetUnitStockpile(unitID)
				progress = progress or 0
				local crossings = countActivations(parameters.progress, state.progress, progress, state.completed)
				state.progress = progress
				state.completed = false

				if crossings > 0 and (not parameters.unitName or context.DoesUnitHaveName(unitID, parameters.unitName)) then
					for _ = 1, crossings do
						context.ActivateTrigger(trigger)
					end
				end
			end
		end,

		StockpileChanged = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
			if newCount <= oldCount then
				return
			end
			local unitStates = context.StockpileState[triggerID]
			if not unitStates then
				return
			end
			local state = unitStates[unitID]
			if state then
				state.completed = true
			end
		end,

		MetaUnitAdded = function(trigger, triggerID, context, unitID, unitDefID)
			if not hasStockpile[unitDefID] then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end

			local _, _, progress = Spring.GetUnitStockpile(unitID) -- TODO: evolution applies stockpile progress late
			getTriggerState(context, triggerID)[unitID] = { progress = progress or 0, completed = false }
		end,

		MetaUnitRemoved = function(trigger, triggerID, context, unitID)
			local unitStates = context.StockpileState[triggerID]
			if unitStates then
				unitStates[unitID] = nil
				if next(unitStates) == nil then
					context.StockpileState[triggerID] = nil
				end
			end
		end,
	},
}
