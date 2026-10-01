-- split_targets.lua
-- Divides the targets of an area command between the units that received it, so each unit gets
-- its own share of the targets instead of every unit getting every target.
-- Every unit receives at least one target when any exist, and never receives itself.

local minimumRiverLength = 24

local table_new = table.new
local table_sort = table.sort
local math_ceil = math.ceil
local math_floor = math.floor
local math_sqrt = math.sqrt

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

local function sortIndexByProjection(objects, count, getPosition, originX, originZ, axisX, axisZ)
	local index, value = table_new(count, 0), table_new(count, 0)
	for i = 1, count do
		local x, _, z = getPosition(objects[i])
		index[i] = i
		value[i] = (x - originX) * axisX + (z - originZ) * axisZ
	end
	table_sort(index, function(a, b)
		return value[a] < value[b]
	end)
	return index
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

---Groups targets into "rivers" that run from the unit-group to target-group center.
---Nearby units take neighboring lanes so travel distances are short (without pathing checks).
---Resorts to the round-robin split when the groups do not have clear separation. -- Can improve
---@param units UnitID[]
---@param targets ObjectID[] Unit IDs, feature IDs, or both; features carry the Game.maxUnits offset when the engine expects it.
---@param unitPosition? fun(unitID: UnitID): number, number, number # Where each unit starts from; queued orders use the last order position
---@return table<UnitID, ObjectID[]?> unitTargets
local function splitRivers(units, targets, unitPosition)
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
	if length < minimumRiverLength then
		return splitRoundRobin(units, targets)
	end

	-- Lanes run along an axis from the unit-group center to the target-group center.
	local axisX, axisZ = -dz / length, dx / length
	local unitIndex = sortIndexByProjection(units, countUnits, unitPosition, unitsX, unitsZ, axisX, axisZ)
	local targetIndex = sortIndexByProjection(targets, countTargets, objectPosition, unitsX, unitsZ, axisX, axisZ)

	local orderedUnits = table_new(countUnits, 0)
	for i = 1, countUnits do
		orderedUnits[i] = units[unitIndex[i]]
	end

	local result = table_new(0, countUnits)

	if countTargets < countUnits then
		for i = 1, countUnits do
			local unitID = orderedUnits[i]
			local lane = math_ceil(i * countTargets / countUnits)
			local targetID = targets[targetIndex[lane]]
			if targetID == unitID then
				-- The neighboring lane is the nearest substitute (when there is one).
				lane = lane < countTargets and lane + 1 or lane - 1
				targetID = targets[targetIndex[lane]]
			end
			result[unitID] = { targetID }
		end
		return result
	end

	local finish = 0
	for i = 1, countUnits do
		local start = finish + 1
		finish = math_floor(i * countTargets / countUnits)
		local list = table_new(finish - start + 1, 0)
		for j = start, finish do
			list[j - start + 1] = targets[targetIndex[j]]
		end
		result[orderedUnits[i]] = list
	end

	repairSelfTargets(orderedUnits, result)
	return result
end

return {
	RoundRobin = splitRoundRobin,
	Rivers = splitRivers,
}
