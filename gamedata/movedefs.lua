
local moveDatas = {
	AKBOT2 = {
		crushstrength = 50,
		depthmod = 0,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
	},
	ATANK3 = {
		crushstrength = 30,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 80,
	},
	BOAT4 = {
		crushstrength = 40,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 8,
	},
	BOAT5 = {
		crushstrength = 50,
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 10,
	},
	--[[
	DBOAT3 = {
		crushstrength = 30,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 15,
	},
	]]--
	DBOAT6 = {
		crushstrength = 70,
		footprintx = 6,
		footprintz = 6,
		minwaterdepth = 15,
	},
	HAKBOT4 = {
		crushstrength = 250,
		depthmod = 0,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 80,
	},
	--[[
	HDBOAT8 = {
		crushstrength = 1400,
		footprintx = 8,
		footprintz = 8,
		minwaterdepth = 15,
	},
	]]--
	HKBOT3 = {
		crushstrength = 1400,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		maxwaterdepth = 22,
	},
	HKBOT4 = {
		crushstrength = 1400,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 26,
	},
	HKBOT5 = {
		crushstrength = 1400,
		footprintx = 5,
		footprintz = 5,
		maxslope = 36,
		maxwaterdepth = 30,
	},
	HOVER3 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 3,
		footprintz = 3,
		maxslope = 22,
		maxwaterslope = 255,
	},
	HOVER4 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 4,
		footprintz = 4,
		maxslope = 22,
		maxwaterslope = 255,
	},
	HTANK3 = {
		crushstrength = 250,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		maxwaterdepth = 22,
	},
	HTANK4 = {
		crushstrength = 250,
		footprintx = 4,
		footprintz = 4,
		maxslope = 18,
		maxwaterdepth = 22,
	},
	HTKBOT4 = {
		crushstrength = 250,
		footprintx = 4,
		footprintz = 4,
		maxslope = 80,
		maxwaterdepth = 22,
	},
	KBOT1 = {
		crushstrength = 5,
		footprintx = 1,
		footprintz = 1,
		maxslope = 36,
		maxwaterdepth = 5,
	},
	KBOT2 = {
		crushstrength = 10,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 22,
	},
	TANK2 = {
		crushstrength = 15,
		footprintx = 2,
		footprintz = 2,
		maxslope = 18,
		maxwaterdepth = 22,
	},
	TANK3 = {
		crushstrength = 30,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		maxwaterdepth = 22,
	},
	TKBOT3 = {
		crushstrength = 15,
		footprintx = 3,
		footprintz = 3,
		maxwaterdepth = 22,
	},
	VKBOT3 = {
		crushstrength = 1400,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 24,
		maxwaterdepth = 5000,
		maxwaterslope = 30,
	},
	VKBOT5 = {
		crushstrength = 1400,
		depthmod = 0,
		footprintx = 5,
		footprintz = 5,
		maxslope = 24,
		maxwaterdepth = 5000,
		maxwaterslope = 30,
	},
	
	-- Subs
	UBOAT3 = {
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	--[[
	UBOAT4 = {
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 40,
		crushstrength = 5,
		subMarine = 1,
	},
	]]--
}

--------------------------------------------------------------------------------
-- Final processing / array format
--------------------------------------------------------------------------------
local defs = {}

for moveName, moveData in pairs(moveDatas) do
	
	moveData.heatmapping = false
	moveData.name = moveName
	
	defs[#defs + 1] = moveData
end

return defs

