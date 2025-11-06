-- The performance of travesabilty grids done in lua isn't great.
-- Try to keep resolution as low as you can get away with and for small zones.
-- Remember changes in terrain will invalidate the grid. Re-generations are expensive.

local spTestMoveOrder = Spring.TestMoveOrder
local spGetGroundHeight = Spring.GetGroundHeight
local floor = math.floor

local DEFAULT_GRID_SPACING = 32
local GRID_RESOLUTION_MULTIPLIER_DEFAULT = 2

local unitIDTraversabilityGrids = {}
local unitIDGridResolutions = {}

local function snapToGrid(value, gridSpacing)
	gridSpacing = gridSpacing or DEFAULT_GRID_SPACING
	return floor(value / gridSpacing) * gridSpacing
end

local function getGridKey(x, z)
	return string.format("%d,%d", x, z)
end

local function isInCircle(x, z, centerX, centerZ, radius)
	local dx = x - centerX
	local dz = z - centerZ
	return (dx * dx + dz * dz) <= (radius * radius)
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

	local snappedOriginX = snapToGrid(originX, gridResolution)
	local snappedOriginZ = snapToGrid(originZ, gridResolution)
	local originKey = getGridKey(snappedOriginX, snappedOriginZ)

	local originY = spGetGroundHeight(snappedOriginX, snappedOriginZ)
	local isTraversable = spTestMoveOrder(unitDefID, snappedOriginX, originY, snappedOriginZ, 0, 0, 0, true, true, false)

	if not isTraversable then
		unitIDTraversabilityGrids[gridKey] = grid
		return grid
	end

	grid[originKey] = true
	visited[originKey] = true
	queue[#queue + 1] = {x = snappedOriginX, z = snappedOriginZ}

	local neighbors = {
		{dx = gridResolution, dz = 0},
		{dx = -gridResolution, dz = 0},
		{dx = 0, dz = gridResolution},
		{dx = 0, dz = -gridResolution}
	}

	while #queue > 0 do
		local current = queue[1]
		table.remove(queue, 1)

		for i = 1, #neighbors do
			local neighbor = neighbors[i]
			local neighborX = current.x + neighbor.dx
			local neighborZ = current.z + neighbor.dz

			if isInCircle(neighborX, neighborZ, originX, originZ, range) then
				local neighborKey = getGridKey(neighborX, neighborZ)

				if not visited[neighborKey] then
					visited[neighborKey] = true

					local neighborY = spGetGroundHeight(neighborX, neighborZ)
					local isNeighborTraversable = spTestMoveOrder(unitDefID, neighborX, neighborY, neighborZ, 0, 0, 0, true, true, false)

					if isNeighborTraversable then
						grid[neighborKey] = true
						queue[#queue + 1] = {x = neighborX, z = neighborZ}
					else
						grid[neighborKey] = false
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

	local centerX = snapToGrid(x, storedGridResolution)
	local centerZ = snapToGrid(z, storedGridResolution)
	for dx = -gridResolutionMultiplier, gridResolutionMultiplier do
		for dz = -gridResolutionMultiplier, gridResolutionMultiplier do
			local testX = centerX + (dx * storedGridResolution)
			local testZ = centerZ + (dz * storedGridResolution)
			local testKey = getGridKey(testX, testZ)
			if grid[testKey] == true then
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

