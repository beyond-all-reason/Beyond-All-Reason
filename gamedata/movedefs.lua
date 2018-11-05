-- the commented out slopemod were there to compensate for modoption betterunitmovement

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
	
	COMMANDERKBOT = {
		crushstrength = 50,
		depthModParams = {
			minHeight = 0,
			maxScale = 1.5,
			quadraticCoeff = (9.9/22090)/2,
			linearCoeff = (0.1/470)/2,
			constantCoeff = 1,
			},
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
	},
	
	AKBOTBOMB2 = {
		crushstrength = 50,
		depthmod = 0,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5000,
		maxwaterslope = 50,
		depthModParams = {
			constantCoeff = 1.5,
		},
		
	},
	ANT = {
		footprintX = 1,
		footprintZ = 1,
		maxWaterDepth = 2,
		crushStrength = 0,
		speedModClass = 1, -- 0 = tank, 1 = kbot, 2 = hover, 3 = ship 
	},
	ATANK3 = {
		crushstrength = 30,
		depthmod = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 36,
		--slopeMod = 32,
		maxwaterdepth = 5000,
		maxwaterslope = 80,
	},
	BOAT4 = {
		crushstrength = 9,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 8,
	},
	
	BOAT42X2 = {
		crushstrength = 9,
		footprintx = 2,
		footprintz = 2,
		minwaterdepth = 8,
	},
	BOAT43X3 = {
		crushstrength = 9,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 8,
	},
	
	BOAT44X4 = {
		crushstrength = 9,
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 8,
	},
	BOAT45X5 = {
		crushstrength = 9,
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 8,
	},
	
	BOAT46X6 = {
		crushstrength = 9,
		footprintx = 6,
		footprintz = 6,
		minwaterdepth = 8,
	},
	
	BOAT47X7 = {
		crushstrength = 9,
		footprintx = 7,
		footprintz = 7,
		minwaterdepth = 8,
	},
	
	BOAT5 = {
		crushstrength = 16,
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 10,
	},
	
	BOAT53X3 = {
		crushstrength = 16,
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 10,
	},
	BOAT54X4 = {
		crushstrength = 16,
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 10,
	},
	BOAT55X5 = {
		crushstrength = 16,
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 10,
	},
	
	BOAT56X6 = {
		crushstrength = 16,
		footprintx = 6,
		footprintz = 6,
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
	CRITTERH = {
		crushstrength = 0,
		footprintx = 1,
		footprintz = 1,
		maxslope = 50,
		maxwaterslope = 255,
		maxWaterDepth = 255,
		minwaterdepth = 15,
		speedModClass = 2, -- 0 = tank, 1 = kbot, 2 = hover, 3 = ship 
	},
	DBOAT6 = {
		crushstrength = 252,
		footprintx = 6,
		footprintz = 6,
		minwaterdepth = 15,
	},
	
	DBOAT65X5 = {
		crushstrength = 252,
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 15,
	},
	DBOAT66X6 = {
		crushstrength = 252,
		footprintx = 6,
		footprintz = 6,
		minwaterdepth = 15,
	},
	DBOAT67X7 = {
		crushstrength = 252,
		footprintx = 7,
		footprintz = 7,
		minwaterdepth = 15,
	},
	
	DBOAT68X8 = {
		crushstrength = 252,
		footprintx = 8,
		footprintz = 8,
		minwaterdepth = 15,
	},

	DBOAT69X9 = {
		crushstrength = 252,
		footprintx = 9,
		footprintz = 9,
		minwaterdepth = 15,
	},
	
	DBOAT610X10 = {
		crushstrength = 252,
		footprintx = 10,
		footprintz = 10,
		minwaterdepth = 15,
	},
	
	
	HAKBOT4 = {
		crushstrength = 252,
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
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	HKBOT4 = {
		crushstrength = 1400,
		footprintx = 4,
		footprintz = 4,
		maxslope = 36,
		maxwaterdepth = 26,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	HKBOT5 = {
		crushstrength = 1400,
		footprintx = 5,
		footprintz = 5,
		maxslope = 36,
		maxwaterdepth = 30,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	HOVER3 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 3,
		footprintz = 3,
		maxslope = 22,
		--slopeMod = 32,
		maxwaterslope = 255,
	},
	HHOVER3 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 252,
		footprintx = 3,
		footprintz = 3,
		maxslope = 22,
		--slopeMod = 32,
		maxwaterslope = 255,
	},
	HOVER4 = {
		badslope = 22,
		badwaterslope = 255,
		crushstrength = 25,
		footprintx = 4,
		footprintz = 4,
		maxslope = 22,
		--slopeMod = 32,
		maxwaterslope = 255,
	},
	HTANK3 = {
		crushstrength = 250,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		--slopeMod = 32,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	HTANK4 = {
		crushstrength = 250,
		footprintx = 4,
		footprintz = 4,
		maxslope = 18,
		--slopeMod = 32,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	HTKBOT4 = {
		crushstrength = 252,
		footprintx = 4,
		footprintz = 4,
		maxslope = 80,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	KBOT1 = {
		crushstrength = 5,
		footprintx = 1,
		footprintz = 1,
		maxslope = 36,
		maxwaterdepth = 5,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}	
	},
	KBOT12X2 = {
		crushstrength = 5,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 5,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}	
	},
	KBOT2 = {
		crushstrength = 10,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	KBOT3 = {
		crushstrength = 15,
		footprintx = 2,
		footprintz = 2,
		maxslope = 36,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	TANK1 = {	-- armfav/corfav
		crushstrength = 10,
		footprintx = 2,
		footprintz = 2,
		maxslope = 18,
		--slopeMod = 32,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	TANK2 = {
		crushstrength = 18,
		footprintx = 2,
		footprintz = 2,
		maxslope = 18,
		--slopeMod = 32,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	TANK3 = {
		crushstrength = 30,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		--slopeMod = 32,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	TKBOT2 = {
		crushstrength = 15,
		footprintx = 2,
		footprintz = 2,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
	},
	TKBOT3 = {
		crushstrength = 15,
		footprintx = 3,
		footprintz = 3,
		maxwaterdepth = 22,
		depthModParams = {
			minHeight = 4,
			linearCoeff = 0.03,
			maxValue = 0.7,
		}
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
		footprintx = 2,
		footprintz = 2,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	UBOAT32X2 = {
		footprintx = 2,
		footprintz = 2,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	
	UBOAT33X3 = {
		footprintx = 3,
		footprintz = 3,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	
	UBOAT34X4 = {
		footprintx = 4,
		footprintz = 4,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	
	UBOAT35X5 = {
		footprintx = 5,
		footprintz = 5,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	UBOAT36X6 = {
		footprintx = 6,
		footprintz = 6,
		minwaterdepth = 15,
		crushstrength = 5,
		subMarine = 1,
	},
	UBOAT37X7 = {
		footprintx = 7,
		footprintz = 7,
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
	NANO = {
		crushstrength = 0,
		footprintx = 3,
		footprintz = 3,
		maxslope = 18,
		maxwaterdepth = 0,
	},
	--Chicken Movedefs
	CHICKENNANO = {
	crushstrength = 0,
	footprintx = 3,
	footprintz = 3,
	maxslope = 18,
	maxwaterdepth = 0,
	},
	CHICKQUEEN = {
		footprintx=3,
		footprintz=3,
		maxwaterdepth=72,
		maxslope=40,
		crushstrength=15000,
		avoidMobilesOnPath=false,
	},
	CHICKENHKBOT1 = {
		footprintx=1,
		footprintz=1,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=100,
	},
	CHICKENHKBOT2 = {
		footprintx=2,
		footprintz=2,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=200,
	},
	CHICKENHKBOT3 = {
		footprintx=3,
		footprintz=3,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=500,
	},
	CHICKENHKBOT4 = {
		footprintx=4,
		footprintz=4,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=900,
	},
	CHICKENHKBOT5 = {
		footprintx=5,
		footprintz=5,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=2000,
	},
	CHICKENHKBOT6 = {
		footprintx=6,
		footprintz=6,
		maxwaterdepth=22,
		maxslope=36,
		crushstrength=6000,
	},
	CHICKENHOVERDODO = {
		footprintx = 1,
		footprintz = 1,
		maxslope = 30,
		maxwaterslope = 255,
	},
}

--------------------------------------------------------------------------------
-- Final processing / array format
--------------------------------------------------------------------------------
local defs = {}

for moveName, moveData in pairs(moveDatas) do
	moveData.heatmapping = true
	moveData.name = moveName
	moveData.allowRawMovement = true
	if moveName and string.find(moveName, "KBOT") and moveData.maxslope then
		moveData.slopemod = 4
	end
	defs[#defs + 1] = moveData
end

return defs

