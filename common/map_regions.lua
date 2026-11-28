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

local DEFAULT_OBJECT_MARGIN = 1024

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
for i, a in ipairs(mapRegions.regions) do
	for j = 1, i - 1 do
		local b = mapRegions.regions[j]
		local dx = math.max(0, a.x0 - b.x1, b.x0 - a.x1)
		local dz = math.max(0, a.z0 - b.z1, b.z0 - a.z1)
		assert(dx > 0 or dz > 0, "Map regions must have a separating strip")
	end
end

-- Extend the bounds, splitting gaps on facing sides.
local hasObjectBounds = Engine and Engine.FeatureSupport and Engine.FeatureSupport.objectDrawBounds
---@type table<integer, {x0:number, z0:number, x1:number, z1:number}>
mapRegions.objectBounds = {}
for i, r in ipairs(mapRegions.regions) do
	local margin = r.margin or mapRegions.margin or DEFAULT_OBJECT_MARGIN
	assert(type(margin) == "number" and margin >= 0 and margin < math.huge, "Invalid map region object margin")
	if not hasObjectBounds then
		margin = 0
	end
	local bounds = {
		x0 = r.x0 - margin,
		z0 = r.z0 - margin,
		x1 = r.x1 + margin,
		z1 = r.z1 + margin,
	}
	if margin > 0 then
		for j, other in ipairs(mapRegions.regions) do
			if i ~= j then
				local dx = math.max(0, r.x0 - other.x1, other.x0 - r.x1)
				local dz = math.max(0, r.z0 - other.z1, other.z0 - r.z1)
				if dx >= dz then
					if r.x1 < other.x0 then
						bounds.x1 = math.min(bounds.x1, (r.x1 + other.x0) / 2)
					else
						bounds.x0 = math.max(bounds.x0, (r.x0 + other.x1) / 2)
					end
				elseif r.z1 < other.z0 then
					bounds.z1 = math.min(bounds.z1, (r.z1 + other.z0) / 2)
				else
					bounds.z0 = math.max(bounds.z0, (r.z0 + other.z1) / 2)
				end
			end
		end
	end
	mapRegions.objectBounds[i] = bounds
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

-- Permit an area centered in a region unless it can reach another region.
---@param x number
---@param z number
---@param radius number
---@return integer?
function mapRegions.AreaRegion(x, z, radius)
	local regionID = mapRegions.Region(x, z)
	if not regionID or not (radius >= 0 and radius < math.huge) then
		return
	end
	local radiusSquared = radius * radius
	for i, r in ipairs(mapRegions.regions) do
		if i ~= regionID then
			local dx = math.max(0, r.x0 - x, x - r.x1)
			local dz = math.max(0, r.z0 - z, z - r.z1)
			if dx * dx + dz * dz <= radiusSquared then
				return
			end
		end
	end
	return regionID
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
