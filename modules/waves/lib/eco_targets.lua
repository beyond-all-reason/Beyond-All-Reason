--- Targets by economic value: a wave prefers what feeds the enemy.
--- The value is the legacy formula; the draw is weighted by it.

local EcoTargets = {}

---@param unitDef table
---@return number|nil value, nil when the unit is not a target at all
function EcoTargets.ValueOf(unitDef)
	local params = unitDef.customParams or {}
	if unitDef.canMove and not params.iscommander then
		return nil
	end
	if params.objectify then
		return nil
	end
	local value = 1
	if unitDef.energyMake then
		value = value + unitDef.energyMake
	end
	if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
		value = value - unitDef.energyUpkeep
	end
	if unitDef.windGenerator then
		value = value + unitDef.windGenerator * 0.75
	end
	if unitDef.tidalGenerator then
		value = value + unitDef.tidalGenerator * 15
	end
	if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
		value = value + 200
	end
	if params.energyconv_capacity then
		value = value + tonumber(params.energyconv_capacity) / 2
	end
	if params.decoyfor == "armfus" then
		value = value + 1000
	end
	if params.techlevel and tonumber(params.techlevel) > 1 then
		value = value * tonumber(params.techlevel) * 2
	end
	if params.unitgroup == "antinuke" or params.unitgroup == "nuke" then
		value = 1000
	end
	return value
end

---@return table tracker
function EcoTargets.New()
	local tracker = { byUnit = {}, byValue = {}, values = {} }

	---@param unitID integer
	---@param unitDef table
	tracker.Add = function(unitID, unitDef)
		local value = EcoTargets.ValueOf(unitDef)
		if value == nil then
			return
		end
		tracker.byUnit[unitID] = value
		local bucket = tracker.byValue[value]
		if bucket == nil then
			bucket = {}
			tracker.byValue[value] = bucket
			tracker.values[#tracker.values + 1] = value
		end
		bucket[unitID] = true
	end

	---@param unitID integer
	tracker.Remove = function(unitID)
		local value = tracker.byUnit[unitID]
		if value == nil then
			return
		end
		tracker.byUnit[unitID] = nil
		tracker.byValue[value][unitID] = nil
	end

	---The director's targetsOf contract: plain targets and high-value ones.
	---Every eco structure is a plain target; the richest value bracket with
	---anything in it is the high-value list.
	---@return integer[] targets
	---@return integer[] highValue
	tracker.Targets = function()
		local targets = {}
		local best, bestValue = {}, -1
		for value, bucket in pairs(tracker.byValue) do
			local any = false
			for unitID in pairs(bucket) do
				targets[#targets + 1] = unitID
				any = true
			end
			if any and value > bestValue then
				bestValue = value
				best = bucket
			end
		end
		local highValue = {}
		for unitID in pairs(best) do
			highValue[#highValue + 1] = unitID
		end
		table.sort(targets)
		table.sort(highValue)
		return targets, highValue
	end

	return tracker
end

return EcoTargets
