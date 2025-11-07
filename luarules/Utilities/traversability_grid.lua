-- The performance of travesabilty grids done in lua isn't great.
-- Try to keep resolution as low as you can get away with and for small zones.
-- Remember changes in terrain will invalidate the grid. Re-generations are expensive.

local spTestMoveOrder = Spring.TestMoveOrder
local spGetGroundHeight = Spring.GetGroundHeight
local floor = math.floor
local distance2dSquared = math.distance2dSquared

local DEFAULT_GRID_SPACING = 32 -- the interval at which terrain is tested using the unitDefID. A decent compromise between performance and accuracy. Emperically chosen.
local GRID_RESOLUTION_MULTIPLIER_DEFAULT = 2 -- how many GRID_SPACINGs step to check in each direction to determine if a spot is reachable or not.

local unitIDTraversabilityGrids = {}
local unitIDGridResolutions = {}

local function snapToGrid(value, gridSpacing)
	gridSpacing = gridSpacing or DEFAULT_GRID_SPACING
	return floor(value / gridSpacing) * gridSpacing
end



local function generateTraversableGrid(unitDefID, originX, originZ, range, gridResolution, gridKey)
	if not unitDefID or not originX or not originZ or not range then
		return
	end

	gridResolution = gridResolution or DEFAULT_GRID_SPACING
	gridKey = gridKey or "defaultKey"

	local grid = {}
	local visited = {}
	local queue = {}
	local queueStart = 1
	local queueEnd = 0

	local snappedOriginX = snapToGrid(originX, gridResolution)
	local snappedOriginZ = snapToGrid(originZ, gridResolution)

	local originY = spGetGroundHeight(snappedOriginX, snappedOriginZ)
	local isTraversable = spTestMoveOrder(unitDefID, snappedOriginX, originY, snappedOriginZ, 0, 0, 0, true, true, false)

	if not isTraversable then
		unitIDTraversabilityGrids[gridKey] = grid
		return grid
	end

	grid[snappedOriginX] = grid[snappedOriginX] or {}
	grid[snappedOriginX][snappedOriginZ] = true
	visited[snappedOriginX] = visited[snappedOriginX] or {}
	visited[snappedOriginX][snappedOriginZ] = true
	queueEnd = queueEnd + 1
	queue[queueEnd] = {x = snappedOriginX, z = snappedOriginZ}

	local neighbors = {
		{dx = gridResolution, dz = 0},
		{dx = -gridResolution, dz = 0},
		{dx = 0, dz = gridResolution},
		{dx = 0, dz = -gridResolution}
	}

	while queueStart <= queueEnd do
		local current = queue[queueStart]
		queueStart = queueStart + 1

		for i = 1, #neighbors do
			local neighbor = neighbors[i]
			local neighborX = current.x + neighbor.dx
			local neighborZ = current.z + neighbor.dz

			if distance2dSquared(neighborX, neighborZ, snappedOriginX, snappedOriginZ) <= (range * range) then
				local visitedX = visited[neighborX]
				if not visitedX or not visitedX[neighborZ] then
					visited[neighborX] = visited[neighborX] or {}
					visited[neighborX][neighborZ] = true

					local neighborY = spGetGroundHeight(neighborX, neighborZ)
					local isNeighborTraversable = spTestMoveOrder(unitDefID, neighborX, neighborY, neighborZ, 0, 0, 0, true, true, false)

					grid[neighborX] = grid[neighborX] or {}
					if isNeighborTraversable then
						grid[neighborX][neighborZ] = true
						queueEnd = queueEnd + 1
						queue[queueEnd] = {x = neighborX, z = neighborZ}
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
	unitIDTraversabilityGrids = unitIDTraversabilityGrids
}
