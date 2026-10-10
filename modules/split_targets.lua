-- split_targets.lua
-- Divides the targets of an area command between the units that received it, so each unit gets
-- its own share of the targets instead of every unit getting every target.
-- Every unit receives at least one target when any exist, and never receives itself.

local minimumRiverLength = 100

local table_new = table.new
local table_sort = table.sort
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local math_atan2 = math.atan2
local math_pi = math.pi

local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition

local UNIT_ID_MAX = Game.maxUnits
local offsetFeatureID = not Engine.FeatureSupport.noOffsetForFeatureID ---@as boolean

local getFeaturePosition = spGetFeaturePosition
if offsetFeatureID then
	getFeaturePosition = function(targetID)
		return spGetFeaturePosition(targetID - UNIT_ID_MAX)
	end
end

local function objectPosition(objectID)
	if objectID <= UNIT_ID_MAX then
		return spGetUnitPosition(objectID)
	end
	return getFeaturePosition(objectID)
end

local function getObjectCentroid(objects, getPosition)
	local sumX, sumZ = 0.0, 0.0
	local count = #objects
	for i = 1, count do
		local x, _, z = getPosition(objects[i])
		sumX, sumZ = sumX + x, sumZ + z ---@diagnostic disable-line -- OK
	end
	return sumX / count, sumZ / count
end

---@return integer[] index
---@return number[] value projection(s) across the lanes
---@return number depthSq the spread of the objects in total, as average squared projection
local function getFromProjection(objects, count, getPosition, originX, originZ, axisX, axisZ)
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
---@return number[] value bearing(s) around the origin, measured from `startAngle`
---@return number radius average distance from the origin
local function getFromBearing(objects, count, getPosition, originX, originZ, startAngle)
	local index, value = table_new(count, 0), table_new(count, 0)
	local radius = 0.0
	for i = 1, count do
		local x, _, z = getPosition(objects[i])
		local rx, rz = x - originX, z - originZ
		index[i] = i
		value[i] = (math_atan2(rz, rx) - startAngle) % (2 * math_pi)
		radius = radius + math_sqrt(rx * rx + rz * rz)
	end
	return index, value, radius / count
end

---Pie slices start after the widest empty arc so no slices wrap back around behind the units.
local function getStartAngle(targets, count, originX, originZ)
	local angles = table_new(count, 0)
	for i = 1, count do
		local x, _, z = objectPosition(targets[i])
		angles[i] = math_atan2(z - originZ, x - originX)
	end
	table_sort(angles)
	local startAngle, widestGap = angles[1], angles[1] + 2 * math_pi - angles[count]
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
local function getLaneCount(countUnits, countTargets, span, maxOrders, laneWidth)
	local lanes = math_min(countUnits, countTargets)
	if maxOrders or laneWidth then
		local lanesForBudget = maxOrders and math_ceil(countUnits * countTargets / maxOrders) or 1
		local lanesForWidth = laneWidth and math_ceil(span / laneWidth) or 1
		lanes = math_max(1, math_min(lanes, math_max(lanesForBudget, lanesForWidth)))
	end
	return lanes
end

local function assignLanes(units, unitIndex, targets, targetIndex, lanes)
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
						band[j], neighbor[1] = neighbor[1], band[j]
						break
					end
				end
			end
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
	return result
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

---Ignores relative positions and assigns targets to units efficiently.
---@param units UnitID[]
---@param targets ObjectID[]
---@return table<UnitID, ObjectID[]?> unitTargets
local function splitRoundRobin(units, targets)
	local countUnits = #units
	local countTargets = #targets
	local result = table_new(0, countUnits)
	for index = 1, countUnits do
		result[units[index]] = {}
	end
	if countUnits == 0 or countTargets == 0 then
		return result
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
		return result
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
	return result
end

---Groups targets into "lanes" or "slices" from the unit-group center and outward.
---Units take neighboring paths so travel distances are short (without pathing checks).
---When the groups mostly overlap, the lanes become slices around the unit-group center.
---@param units UnitID[]
---@param targets ObjectID[] Unit IDs, feature IDs, or both; features carry the Game.maxUnits offset when the engine expects it.
---@param unitPosition? fun(unitID: UnitID): number, number, number # Where each unit starts from; queued orders use the last order position
---@param maxOrders? integer Squads share their lane's targets so that units x targets per lane totals about this many.
---@param laneWidth? number Squads are formed so no lane is much wider than this, in elmos or arc length.
---@return table<UnitID, ObjectID[]?> unitTargets
local function splitRivers(units, targets, unitPosition, maxOrders, laneWidth)
	local countUnits = #units
	local countTargets = #targets
	if countUnits == 0 or countTargets == 0 then
		return splitRoundRobin(units, targets)
	end
	if unitPosition == nil then
		unitPosition = spGetUnitPosition
	end

	local unitsX, unitsZ = getObjectCentroid(units, unitPosition)
	local targetsX, targetsZ = getObjectCentroid(targets, objectPosition)
	local dx, dz = targetsX - unitsX, targetsZ - unitsZ
	local length = math_sqrt(dx * dx + dz * dz)

	if length >= minimumRiverLength then
		-- Lanes run along an axis from the unit-group center to the target-group center.
		local axisX, axisZ = -dz / length, dx / length
		local targetIndex, targetValue, targetDepthSq =
			getFromProjection(targets, countTargets, objectPosition, unitsX, unitsZ, axisX, axisZ)
		-- Slice instead when the unit-group starts inside the target-group.
		if 2 * length * length >= targetDepthSq then
			local unitIndex, unitValue =
				getFromProjection(units, countUnits, unitPosition, unitsX, unitsZ, axisX, axisZ)
			local lanes =
				getLaneCount(countUnits, countTargets, getValueSpan(targetValue, countTargets), maxOrders, laneWidth)
			sortIndexByValue(unitIndex, unitValue)
			sortIndexByValue(targetIndex, targetValue)
			return assignLanes(units, unitIndex, targets, targetIndex, lanes)
		end
	end

	local startAngle = getStartAngle(targets, countTargets, unitsX, unitsZ)
	local targetIndex, targetValue, radius =
		getFromBearing(targets, countTargets, objectPosition, unitsX, unitsZ, startAngle)
	local unitIndex, unitValue = getFromBearing(units, countUnits, unitPosition, unitsX, unitsZ, startAngle)
	local lanes =
		getLaneCount(countUnits, countTargets, getValueSpan(targetValue, countTargets) * radius, maxOrders, laneWidth)
	sortIndexByValue(unitIndex, unitValue)
	sortIndexByValue(targetIndex, targetValue)
	return assignLanes(units, unitIndex, targets, targetIndex, lanes)
end

return {
	RoundRobin = splitRoundRobin,
	Rivers = splitRivers,
}
