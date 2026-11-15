-- SPDX-License-Identifier: GPL-2.0-or-later
-- Shared geometry for multi-region maps, read by LuaRules and LuaUI. Returns nil on maps without regions.
local CONFIG_FILE = "mapconfig/map_regions.lua"

if not VFS.FileExists(CONFIG_FILE, VFS.MAP) then
	return nil
end

local mapRegions = VFS.Include(CONFIG_FILE, nil, VFS.MAP)
assert(mapRegions.schema == 1, "Unsupported map region metadata schema")
assert(
	#mapRegions.regions > 0 and (not mapRegions.profiles or #mapRegions.profiles == #mapRegions.regions),
	"Invalid map region definitions"
)

local identifiers = {}
for _, r in ipairs(mapRegions.regions) do
	assert(type(r.id) == "string" and not identifiers[r.id], "Map region identifiers must be unique")
	identifiers[r.id] = true
	assert(
		r.x0 >= 0
			and r.z0 >= 0
			and r.x1 <= mapRegions.size[1]
			and r.z1 <= mapRegions.size[2]
			and r.width == r.x1 - r.x0
			and r.height == r.z1 - r.z0
			and r.width > 0
			and r.height > 0,
		"Invalid map region rectangle"
	)
end

-- Verify physical separation between regions.
mapRegions.minimumGap = math.huge
for i, a in ipairs(mapRegions.regions) do
	for j = 1, i - 1 do
		local b = mapRegions.regions[j]
		local dx = math.max(0, a.x0 - b.x1, b.x0 - a.x1)
		local dz = math.max(0, a.z0 - b.z1, b.z0 - a.z1)
		local gap = math.sqrt(dx * dx + dz * dz)
		assert(gap > 0, "Map regions must have a separating strip")
		mapRegions.minimumGap = math.min(mapRegions.minimumGap, gap)
	end
end

-- Object bounds extend each region by a margin so flying objects can turn or overshoot without vanishing.
-- The margin is the region's `margin`, else the manifest's `margin`, else 1/16 of the region's shorter side,
-- and never more than half the larger axis gap to another region, so two extended regions never overlap.
---@type table<integer, {x0:number, z0:number, x1:number, z1:number, margin:number}>
mapRegions.objectBounds = {}
for i, r in ipairs(mapRegions.regions) do
	local margin = r.margin or mapRegions.margin or math.min(r.width, r.height) / 16
	for j, other in ipairs(mapRegions.regions) do
		if i ~= j then
			local dx = math.max(0, r.x0 - other.x1, other.x0 - r.x1)
			local dz = math.max(0, r.z0 - other.z1, other.z0 - r.z1)
			margin = math.min(margin, math.max(dx, dz) / 2)
		end
	end
	-- Without independent object bounds the engine clips objects to the terrain bounds.
	if not (Engine and Engine.FeatureSupport and Engine.FeatureSupport.objectDrawBounds) then
		margin = 0
	end
	mapRegions.objectBounds[i] = {
		x0 = r.x0 - margin,
		z0 = r.z0 - margin,
		x1 = r.x1 + margin,
		z1 = r.z1 + margin,
		margin = margin,
	}
end

---@param regionID integer?
---@param x number?
---@param z number?
---@return boolean
function mapRegions.ContainsObject(regionID, x, z)
	if not regionID or not x or not z then
		return false
	end
	local r = mapRegions.objectBounds[regionID]
	return r ~= nil and x >= r.x0 and x < r.x1 and z >= r.z0 and z < r.z1
end

---@param x number?
---@param z number?
---@return integer?
function mapRegions.ObjectRegion(x, z)
	for regionID in ipairs(mapRegions.regions) do
		if mapRegions.ContainsObject(regionID, x, z) then
			return regionID
		end
	end
end

---@param x number?
---@param z number?
---@return integer?
function mapRegions.Region(x, z)
	if not x or not z then
		return
	end
	for regionID, r in ipairs(mapRegions.regions) do
		if x >= r.x0 and x < r.x1 and z >= r.z0 and z < r.z1 then
			return regionID
		end
	end
end

---@param teamID integer
---@return integer?
function mapRegions.TeamHome(teamID)
	for _, entry in ipairs(mapRegions.teams or {}) do
		if entry.team == teamID then
			return entry.region
		end
	end
end

return mapRegions
