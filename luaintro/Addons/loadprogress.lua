
if addon.InGetInfo then
	return {
		name    = "LoadProgress",
		desc    = "",
		author  = "jK",
		date    = "2012",
		license = "GPL2",
		layer   = 0,
		enabled = true,
	}
end

local tips = require "savetable.lua"

local startTime = -1
local cachedLoadTimes = VFS.FileExists("loadprogress_cached.lua") and VFS.Include("loadprogress_cached.lua") or { }
local cachedTotalTime = (cachedLoadTimes[Game.mapName] or -1) * 0.97 --*0.97 cause else last rendered frame would show 99%

local function mix(x,y,a)
	return x * (1-a) + y * a
end

function SG.GetLoadProgress()
	if startTime < 0 then startTime = os.clock() end

	if cachedTotalTime > 0 then
		return math.clamp((os.clock() - startTime) / cachedTotalTime, 0, 1)
	else
		return -1
	end
end

function addon.Shutdown()
	cachedLoadTimes[Game.mapName] = os.clock() - startTime
	table.save(cachedLoadTimes, "loadprogress_cached.lua")
end

