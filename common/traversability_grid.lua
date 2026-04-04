-- The performance of travesabilty grids done in lua isn't great.
-- Try to keep resolution as low as you can get away with and for small zones.
-- Remember changes in terrain will invalidate the grid. Re-generations are expensive.

local spGetGroundNormal = SpringShared.GetGroundNormal
local floor = math.floor
local distance2dSquared = math.distance2dSquared

local DEFAULT_GRID_SPACING = 32 -- the interval at which terrain is tested using the unitDefID. A decent compromise between performance and accuracy. Emperically chosen.
local GRID_RESOLUTION_MULTIPLIER_DEFAULT = 2 -- how many GRID_SPACINGs step to check in each direction to determine if a spot is reachable or not.
local DEFAULT_MAX_SLOPE = 0.36 -- calibrated using quickstart on ascendency

local BFS_NDX = { 1, -1, 0, 0 }
local BFS_NDZ = { 0, 0, 1, -1 }

local unitIDTraversabilityGrids = {}
local unitIDGridResolutions = {}

local function snapToGrid(value, gridSpacing)
	gridSpacing = gridSpacing or DEFAULT_GRID_SPACING
	return floor(value / gridSpacing) * gridSpacing
end

local function isPositionTraversable(x, z, maxSlope)
	local nx, ny, nz, slope = spGetGroundNormal(x, z)
	return slope <= maxSlope
end

local function generateTraversableGrid(originX, originZ, range, gridResolution, gridKey, maxSlope)
	if not originX or not originZ or not range then
		return
	end

	gridResolution = gridResolution or DEFAULT_GRID_SPACING
	gridKey = gridKey or "defaultKey"
	maxSlope = maxSlope or DEFAULT_MAX_SLOPE

	local grid = {}
	local visited = {}

	local snappedOriginX = snapToGrid(originX, gridResolution)
	local snappedOriginZ = snapToGrid(originZ, gridResolution)

	local isTraversable = isPositionTraversable(snappedOriginX, snappedOriginZ, maxSlope)

	if not isTraversable then
		unitIDTraversabilityGrids[gridKey] = grid
		return grid
	end

	grid[snappedOriginX] = grid[snappedOriginX] or {}
	grid[snappedOriginX][snappedOriginZ] = true
	visited[snappedOriginX] = visited[snappedOriginX] or {}
	visited[snappedOriginX][snappedOriginZ] = true

	local queueX = { snappedOriginX }
	local queueZ = { snappedOriginZ }
	local queueLen = 1
	local rangeSq = range * range

	local i = 1
	while i <= queueLen do
		local currentX = queueX[i]
		local currentZ = queueZ[i]
		i = i + 1

		for j = 1, 4 do
			local neighborX = currentX + BFS_NDX[j] * gridResolution
			local neighborZ = currentZ + BFS_NDZ[j] * gridResolution

			if distance2dSquared(neighborX, neighborZ, snappedOriginX, snappedOriginZ) <= rangeSq then
				local visitedX = visited[neighborX]
				if not visitedX or not visitedX[neighborZ] then
					visited[neighborX] = visited[neighborX] or {}
					visited[neighborX][neighborZ] = true

					local isNeighborTraversable = isPositionTraversable(neighborX, neighborZ, maxSlope)

					grid[neighborX] = grid[neighborX] or {}
					if isNeighborTraversable then
						grid[neighborX][neighborZ] = true
						queueLen = queueLen + 1
						queueX[queueLen] = neighborX
						queueZ[queueLen] = neighborZ
					else
						grid[neighborX][neighborZ] = false
					end
				end
			end
		end
	end

	unitIDTraversabilityGrids[gridKey] = grid
	unitIDGridResolutions[gridKey] = gridResolution
	return grid
end

local function canMoveToPosition(gridKey, x, z, gridResolutionMultiplier)
	if not gridKey then
		gridKey = "defaultKey"
	end

	if not unitIDTraversabilityGrids[gridKey] then
		return false
	end

	gridResolutionMultiplier = gridResolutionMultiplier or GRID_RESOLUTION_MULTIPLIER_DEFAULT

	local grid = unitIDTraversabilityGrids[gridKey]
	local storedGridResolution = unitIDGridResolutions[gridKey] or DEFAULT_GRID_SPACING

	-- we check in all directions because snapping to a single coordinate can give a false negative for reachability
	local centerX = snapToGrid(x, storedGridResolution)
	local centerZ = snapToGrid(z, storedGridResolution)
	for dx = -gridResolutionMultiplier, gridResolutionMultiplier do
		for dz = -gridResolutionMultiplier, gridResolutionMultiplier do
			local testX = centerX + (dx * storedGridResolution)
			local testZ = centerZ + (dz * storedGridResolution)
			if grid[testX] and grid[testX][testZ] == true then
				return true
			end
		end
	end

	return false
end

return {
	generateTraversableGrid = generateTraversableGrid,
	canMoveToPosition = canMoveToPosition,
	unitIDTraversabilityGrids = unitIDTraversabilityGrids,
}
