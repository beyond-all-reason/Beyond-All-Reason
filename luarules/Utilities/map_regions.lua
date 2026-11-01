-- SPDX-License-Identifier: GPL-2.0-or-later
-- Shared geometry for multi-region maps.
local config = VFS.FileExists("mapconfig/map_regions.lua", VFS.MAP) and "mapconfig/map_regions.lua"
	or (VFS.FileExists("mapconfig/portal_worlds.lua", VFS.MAP) and "mapconfig/portal_worlds.lua")
if not config then
	return nil
end

local mapRegions = VFS.Include(config, nil, VFS.MAP)
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

-- Give flying objects room to turn or overshoot without exposing another region.
-- Half the separating distance on the widest axis keeps even diagonal envelopes
-- disjoint. Single-region maps use one sixteenth of their shorter side.
---@type table<integer, {x0:number, z0:number, x1:number, z1:number, margin:number}>
mapRegions.objectBounds = {}
for i, r in ipairs(mapRegions.regions) do
	local margin = math.min(r.width, r.height) / 16
	for j, other in ipairs(mapRegions.regions) do
		if i ~= j then
			local dx = math.max(0, r.x0 - other.x1, other.x0 - r.x1)
			local dz = math.max(0, r.z0 - other.z1, other.z0 - r.z1)
			margin = math.min(margin, math.max(dx, dz) / 2)
		end
	end
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

function mapRegions.TeamHome(teamID)
	for _, entry in ipairs(mapRegions.teams or {}) do
		if entry.team == teamID then
			return entry.region
		end
	end
end

return mapRegions
