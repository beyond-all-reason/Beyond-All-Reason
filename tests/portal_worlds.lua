-- This file is part of Zero-K (GPL v2 or later), see LICENSE.
-- Run from the game checkout with: lua5.1 tests/portal_worlds.lua
local checks = 0
local function Check(value)
	checks = checks + 1
	assert(value, "portal geometry regression " .. checks)
end
local function World(gap)
	local w = {
		schema = 1,
		size = { 400, 200 },
		gap = 2048,
		profiles = { {}, {}, {} },
		regions = {},
		connections = { { 1, 2 }, { 2, 3 } },
		teams = {},
	}
	for i = 1, 3 do
		local x = (i - 1) * (100 + gap)
		w.regions[i] = { id = tostring(i), x0 = x, z0 = 0, x1 = x + 100, z1 = 100, width = 100, height = 100 }
	end
	return w
end
local function Load(w)
	local chunk = assert(loadfile("luarules/Utilities/portal_worlds.lua"))
	local env = { VFS = {
		MAP = "map",
		FileExists = function()
			return true
		end,
		Include = function()
			return w
		end,
	} }
	setmetatable(env, { __index = _G })
	return setfenv(chunk, env)()
end
local w = Load(World(10))
Check(w.minimumGap == 10) -- Nominal metadata says 2048; physical geometry wins.
Check(w.Region(20, 20) == 1)
Check(w.Region(0, 0) == 1)
Check(w.Region(100, 20) == nil)
Check(w.Region(20, 100) == nil)
Check(w.Region(105, 20) == nil)
local edge, nextRegion = w.Route(1, 3, function()
	return true
end)
Check(edge == 1 and nextRegion == 2)
Check(w.Route(1, 3, function(i)
	return i ~= 2
end) == nil)
Check(not pcall(Load, World(0)))
Check(not pcall(Load, World(-10)))
local bad = World(10)
bad.regions[2].id = bad.regions[1].id
Check(not pcall(Load, bad))
bad = World(10)
bad.regions[2].x1 = bad.regions[2].x1 + 1
Check(not pcall(Load, bad))
print("PORTAL_GEOMETRY_PASS " .. checks)
