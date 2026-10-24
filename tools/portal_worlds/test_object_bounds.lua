-- SPDX-License-Identifier: GPL-2.0-or-later
-- Run from the game root with lua5.1 tools/portal_worlds/test_object_bounds.lua.
local function Load(rectangles, supported)
	local metadata = { schema = 1, size = { 10000, 10000 }, regions = {}, profiles = {}, connections = {} }
	for i, rect in ipairs(rectangles) do
		metadata.regions[i] = {
			id = tostring(i),
			x0 = rect[1],
			z0 = rect[2],
			x1 = rect[3],
			z1 = rect[4],
			width = rect[3] - rect[1],
			height = rect[4] - rect[2],
		}
		metadata.profiles[i] = {}
	end
	local env = {
		Engine = { FeatureSupport = { objectDrawBounds = supported } },
		VFS = {
			FileExists = function()
				return true
			end,
			Include = function()
				return metadata
			end,
		},
	}
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("luarules/Utilities/portal_worlds.lua"))
	setfenv(chunk, env)
	return chunk()
end
local layouts = {
	{ { 0, 0, 4096, 4096 }, { 4608, 0, 8704, 4096 }, { 0, 4608, 4096, 8704 }, { 4608, 4608, 8704, 8704 } },
	{ { 0, 0, 1000, 2000 }, { 1010, 0, 2010, 2000 } },
	{ { 0, 0, 1000, 1000 }, { 1030, 1040, 2030, 2040 } },
	{ { 0, 0, 1000, 3000 } },
}
for _, rectangles in ipairs(layouts) do
	for _, supported in ipairs({ true, false }) do
		local world = Load(rectangles, supported)
		for i, bounds in ipairs(world.objectBounds) do
			local r = world.regions[i]
			assert((bounds.margin > 0) == supported)
			assert(world.ContainsObject(i, r.x0, r.z0))
			assert(world.ObjectRegion(r.x0, r.z0) == i)
			assert(not world.ContainsObject(i, bounds.x1, r.z0))
			assert(not world.ContainsObject(i, nil, r.z0))
			assert(not world.ContainsObject(99, r.x0, r.z0))
			if supported then
				assert(world.ContainsObject(i, r.x0 - bounds.margin / 2, r.z0))
				assert(world.ObjectRegion(r.x0 - bounds.margin / 2, r.z0) == i)
				assert(not world.ContainsObject(i, bounds.x0 - 1, r.z0))
			end
			for j = 1, i - 1 do
				local other = world.objectBounds[j]
				assert(
					bounds.x0 >= other.x1 or bounds.x1 <= other.x0 or bounds.z0 >= other.z1 or bounds.z1 <= other.z0,
					"Flight margins overlap"
				)
			end
		end
	end
end
local world = Load(layouts[1], true)
assert(world.objectBounds[1].margin == 256 and world.objectBounds[1].x0 == -256)
print("Object bounds geometry and legacy fallback checks passed")
