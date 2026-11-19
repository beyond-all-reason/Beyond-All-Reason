-- split_targets.lua -----------------------------------------------------------
-- Divides targets and assigns them to units according to the caller's strategy.

local minimumLaneLength = 100

local table_new = table.new
local table_sort = table.sort
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_tau = math.tau ---@type number

local spGetUnitPosition = Spring.GetUnitPosition

local objectPosition = BAR.Utilities.GetObjectPosition
local getCentroid = BAR.Utilities.GetObjectCentroid

---@return integer[] index
---@return number[] value
---@return number depthSq
local function measureAlongAxis(objects, getPosition, originX, originZ, axisX, axisZ)
	local count = #objects
	local index, value = table_new(count, 0), table_new(count, 0)
	local depthSq = 0.0
	for i = 1, count do
		local x, _, z = getPosition(objects[i])
		local rx, rz = x - originX, z - originZ
		local depth = rx * axisZ - rz * axisX
		index[i] = i
		value[i] = rx * axisX + rz * axisZ
		depthSq = depthSq + depth * depth
	end
	return index, value, depthSq / count
end

---@return integer[] index
---@return number[] value
local function measureAroundOrigin(objects, getPosition, originX, originZ, startAngle)
	local count = #objects
	local index, value = table_new(count, 0), table_new(count, 0)
	for i = 1, count do
		local x, _, z = getPosition(objects[i])
		index[i] = i
		value[i] = (math_atan2(z - originZ, x - originX) - startAngle) % math_tau
	end
	return index, value
end

---Pie slices start after the widest empty arc so no slices wrap back around behind the units.
local function getStartAngle(targets, count, originX, originZ)
	local angles = table_new(count, 0)
	for i = 1, count do
		local x, _, z = objectPosition(targets[i])
		angles[i] = math_atan2(z - originZ, x - originX)
	end
	table_sort(angles)
	local startAngle, widestGap = angles[1], angles[1] + math_tau - angles[count]
	for i = 2, count do
		local gap = angles[i] - angles[i - 1]
		if gap > widestGap then
			startAngle, widestGap = angles[i], gap
		end
	end
	return startAngle
end

local function sortIndexByValue(index, value)
	table_sort(index, function(a, b)
		return value[a] < value[b]
	end)
	return index
end

local function getValueSpan(value, count)
	local low, high = value[1], value[1]
	for i = 2, count do
		low, high = math_min(low, value[i]), math_max(high, value[i])
	end
	return high - low
end

---Units that share a lane form a "squad" and attack the lane's targets together.
local function getLaneCount(countUnits, countTargets, span, lanes, maxOrders, laneWidth)
	local limit = math_min(countUnits, countTargets)
	if lanes then
		return math_max(1, math_min(limit, lanes))
	end
	lanes = limit
	if maxOrders or laneWidth then
		local lanesForBudget = maxOrders and maxOrders > 0 and countUnits * countTargets / maxOrders or 1
		local lanesForWidth = laneWidth and laneWidth > 0 and span / laneWidth or 1
		lanes = math_max(1, math_min(limit, math_floor(math_sqrt(lanesForBudget * lanesForWidth) + 0.5)))
	end
	return lanes
end

local function assignLanes(units, unitIndex, targets, targetIndex, lanes, sortTargets)
	local countUnits, countTargets = #units, #targets
	local laneUnits, laneTargets = table_new(lanes, 0), table_new(lanes, 0)
	for lane = 1, lanes do
		laneUnits[lane], laneTargets[lane] = {}, {}
	end
	for i = 1, countUnits do
		local squad = laneUnits[math_ceil(i * lanes / countUnits)]
		squad[#squad + 1] = units[unitIndex[i]]
	end
	local finish = 0
	for lane = 1, lanes do
		local band = laneTargets[lane]
		local start = finish + 1
		finish = math_floor(lane * countTargets / lanes)
		for j = start, finish do
			band[j - start + 1] = targets[targetIndex[j]]
		end
	end

	if lanes > 1 then
		for lane = 1, lanes do
			local squad, band = laneUnits[lane], laneTargets[lane]
			if #squad == 1 then
				for j = 1, #band do
					if band[j] == squad[1] then
						local neighbor = laneTargets[lane < lanes and lane + 1 or lane - 1]
						band[j], neighbor[1] = neighbor[1], band[j] -- swap self-targets with neighbor lanes
						break
					end
				end
			end
		end
	end

	if sortTargets then
		for lane = 1, lanes do
			sortTargets(laneUnits[lane], laneTargets[lane])
		end
	end

	local result = table_new(0, countUnits)
	for lane = 1, lanes do
		local squad = laneUnits[lane]
		for s = 1, #squad do
			local unitID = squad[s]
			local list, band = {}, laneTargets[lane]
			for j = 1, #band do
				if band[j] ~= unitID then
					list[#list + 1] = band[j]
				end
			end
			if not list[1] and lanes > 1 then
				band = laneTargets[lane < lanes and lane + 1 or lane - 1]
				for j = 1, #band do
					if band[j] ~= unitID then
						list[#list + 1] = band[j]
					end
				end
			end
			result[unitID] = list
		end
	end
	return result, laneUnits
end

---The lists are disjoint, so swapping the first target between neighbors cannot cause self-targeting.
local function repairSelfTargets(orderedUnits, result)
	local countUnits = #orderedUnits
	for i = 1, countUnits do
		local unitID = orderedUnits[i]
		local list = result[unitID]
		for j = 1, #list do
			if list[j] == unitID then
				if countUnits > 1 then
					local neighbor = result[orderedUnits[i < countUnits and i + 1 or i - 1]]
					list[j], neighbor[1] = neighbor[1], unitID
				else
					list[j] = list[#list]
					list[#list] = nil
				end
				break
			end
		end
	end
end

---Ignores relative positions and assigns targets to units efficiently. Takes one unit per group.
---@param units UnitID[]
---@param targets ObjectID[]
---@param sortTargets? fun(units: UnitID[], targets: ObjectID[])
---@return table<UnitID, ObjectID[]?> unitTargets
---@return UnitID[][] squads
local function splitRoundRobin(units, targets, _, sortTargets)
	local countUnits = #units
	local countTargets = #targets
	local result, squads = table_new(0, countUnits), table_new(countUnits, 0)
	for index = 1, countUnits do
		result[units[index]] = {}
		squads[index] = { units[index] }
	end
	if countUnits == 0 or countTargets == 0 then
		return result, squads
	end

	if countTargets < countUnits then
		for index = 1, countUnits do
			local unitID = units[index]
			local targetIndex = (index - 1) % countTargets + 1
			local targetID = targets[targetIndex]
			if targetID == unitID then
				-- The next target is the nearest substitute (when there is one).
				targetID = countTargets > 1 and targets[targetIndex % countTargets + 1] or nil
			end
			result[unitID][1] = targetID
		end
		return result, squads
	end

	-- We save microseconds by diagonalizing on the index.
	for index = 1, countUnits do
		result[units[index]][1] = targets[index]
	end

	-- So the more expensive loop runs on a smaller range.
	local unitIndex = 0
	for index = countUnits + 1, countTargets do
		unitIndex = unitIndex % countUnits + 1
		local list = result[units[unitIndex]]
		list[#list + 1] = targets[index]
	end

	repairSelfTargets(units, result)
	if sortTargets then
		for index = 1, countUnits do
			local unitID = units[index]
			sortTargets({ unitID }, result[unitID])
		end
	end
	return result, squads
end

---Groups targets into "lanes" or "slices" from the unit-group center and outward.
---Units take neighboring paths so travel distances are short (without pathing checks).
---When the groups mostly overlap, the lanes become slices around the unit-group center.
---@param units UnitID[]
---@param targets ObjectID[] Unit IDs, feature IDs, or both; features carry the Game.maxUnits offset when the engine expects it.
---@param unitPosition? fun(unitID: UnitID): number, number, number # Where each unit starts from; queued orders use the last order position
---@param sortTargets? fun(units: UnitID[], targets: ObjectID[])
---@param lanes? integer else calculate the lane count from maxOrders and laneWidth
---@param maxOrders? integer
---@param laneWidth? number
---@return table<UnitID, ObjectID[]?> unitTargets
---@return UnitID[][] squads
local function splitRivers(units, targets, unitPosition, sortTargets, lanes, maxOrders, laneWidth)
	local countUnits = #units
	local countTargets = #targets
	if countUnits == 0 or countTargets == 0 then
		return splitRoundRobin(units, targets, unitPosition, sortTargets)
	end
	if unitPosition == nil then
		unitPosition = spGetUnitPosition
	end

	local unitsX, unitsZ = getCentroid(units, unitPosition)
	local targetsX, targetsZ = getCentroid(targets, objectPosition)
	local dx, dz = targetsX - unitsX, targetsZ - unitsZ
	local length = math_sqrt(dx * dx + dz * dz)

	if length >= minimumLaneLength then
		-- Lanes run along an axis from the unit-group center to the target-group center.
		local axisX, axisZ = -dz / length, dx / length
		local targetIndex, targetValue, targetDepthSq =
			measureAlongAxis(targets, objectPosition, unitsX, unitsZ, axisX, axisZ)
		-- Slice instead when the unit-group starts inside the target-group.
		if 2 * length * length >= targetDepthSq then
			local unitIndex, unitValue = measureAlongAxis(units, unitPosition, unitsX, unitsZ, axisX, axisZ)
			local count = getLaneCount(
				countUnits,
				countTargets,
				getValueSpan(targetValue, countTargets),
				lanes,
				maxOrders,
				laneWidth
			)
			sortIndexByValue(unitIndex, unitValue)
			sortIndexByValue(targetIndex, targetValue)
			return assignLanes(units, unitIndex, targets, targetIndex, count, sortTargets)
		end
	end

	local startAngle = getStartAngle(targets, countTargets, unitsX, unitsZ)
	local targetIndex, targetValue = measureAroundOrigin(targets, objectPosition, unitsX, unitsZ, startAngle)
	local unitIndex, unitValue = measureAroundOrigin(units, unitPosition, unitsX, unitsZ, startAngle)
	local count = getLaneCount(countUnits, countTargets, 0, lanes, maxOrders, nil)
	sortIndexByValue(unitIndex, unitValue)
	sortIndexByValue(targetIndex, targetValue)
	return assignLanes(units, unitIndex, targets, targetIndex, count, sortTargets)
end

return {
	RoundRobin = splitRoundRobin,
	Rivers = splitRivers,
}
