---
--- The campaign AI's regions, by the name a mission gives them. A team's AI knows a region by its ID only,
--- and watches its squads on a grid in which each cell belongs to one region at most.
---

---@class MissionAiRegion
---@field regionName string
---@field regionID integer
---@field teamID integer
---@field cells integer[]

local CELL_SIZE = 64 -- the AI's GRID_TRIGGER_STEP
local CELL_ROW_STRIDE = 65536

local regionsByName = {} ---@type table<string, MissionAiRegion?>
local regionsByID = {} ---@type table<integer, table<integer, MissionAiRegion?>> by teamID, then regionID
local regionCounts = {} ---@type table<integer, integer?> by teamID
local cellRegions = {} ---@type table<integer, table<integer, MissionAiRegion?>> by teamID, then cell

--- The cells whose centre the polygon contains, found the way the AI's CGridRegion::Rasterize finds them.
---@param polygon table x1, z1, x2, z2, ...
---@return integer[] cells
local function getCells(polygon)
	local cells = {}
	local vertexCount = #polygon / 2

	local minZ, maxZ = math.huge, -math.huge
	for i = 2, #polygon, 2 do
		minZ = math.min(minZ, polygon[i])
		maxZ = math.max(maxZ, polygon[i])
	end

	for row = math.floor(minZ / CELL_SIZE), math.floor(maxZ / CELL_SIZE) do
		local scanZ = (row + 0.5) * CELL_SIZE

		local crossings = {}
		for i = 1, vertexCount do
			local next = i % vertexCount + 1
			local x1, z1 = polygon[2 * i - 1], polygon[2 * i]
			local x2, z2 = polygon[2 * next - 1], polygon[2 * next]
			if (z1 <= scanZ and z2 > scanZ) or (z2 <= scanZ and z1 > scanZ) then
				crossings[#crossings + 1] = x1 + (scanZ - z1) / (z2 - z1) * (x2 - x1)
			end
		end
		table.sort(crossings)

		for i = 1, #crossings - 1, 2 do
			local firstColumn = math.ceil(crossings[i] / CELL_SIZE - 0.5)
			local lastColumn = math.floor(crossings[i + 1] / CELL_SIZE - 0.5)
			for column = firstColumn, lastColumn do
				cells[#cells + 1] = row * CELL_ROW_STRIDE + column
			end
		end
	end

	return cells
end

local function warn(message, regionName)
	Spring.Log("ai_regions.lua", LOG.WARNING, "[Mission API] " .. message .. ": " .. regionName)
end

---@param polygon number[] x1, z1, x2, z2, ...
---@return integer? regionID nil for a region the AI could not watch
local function defineRegion(regionName, teamID, polygon)
	if regionsByName[regionName] then
		warn("Region is already defined", regionName)
		return nil
	end

	local cells = getCells(polygon)
	if #cells == 0 then
		warn("Region is too small for the AI to watch", regionName)
		return nil
	end

	local teamCells = table.ensureTable(cellRegions, teamID)
	for _, cell in ipairs(cells) do
		if teamCells[cell] then
			warn("Region overlaps region " .. teamCells[cell].regionName, regionName)
			return nil
		end
	end

	-- 0 is the AI's ID for every region, and an ID is never used twice.
	local regionID = (regionCounts[teamID] or 0) + 1
	regionCounts[teamID] = regionID

	local region = { regionName = regionName, regionID = regionID, teamID = teamID, cells = cells }
	regionsByName[regionName] = region
	table.ensureTable(regionsByID, teamID)[regionID] = region
	for _, cell in ipairs(cells) do
		teamCells[cell] = region
	end

	return regionID
end

---@return string? regionName nil for a region that is not live
local function getRegionName(teamID, regionID)
	local region = regionsByID[teamID] and regionsByID[teamID][regionID]
	return region and region.regionName
end

---@return integer? regionID nil for a region that is not live
---@return integer? teamID
local function clearRegion(regionName)
	local region = regionsByName[regionName]
	if not region then
		return
	end

	regionsByName[regionName] = nil
	regionsByID[region.teamID][region.regionID] = nil
	for _, cell in ipairs(region.cells) do
		cellRegions[region.teamID][cell] = nil
	end

	return region.regionID, region.teamID
end

return {
	Define = defineRegion,
	Clear = clearRegion,
	GetName = getRegionName,
}
