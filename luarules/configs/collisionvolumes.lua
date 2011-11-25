--[[  from Spring Wiki and source code, info about CollisionVolumeData
Spring.GetUnitCollisionVolumeData ( number unitID ) -> 
	number scaleX, number scaleY, number scaleZ, number offsetX, number offsetY, number offsetZ,
	number volumeType, number testType, number primaryAxis, boolean disabled

Spring.SetUnitCollisionVolumeData ( number unitID, number scaleX, number scaleY, number scaleZ,
					number offsetX, number offsetY, number offsetX,
					number vType, number tType, number Axis ) -> nil

Spring.SetUnitPieceCollisionVolumeData ( number unitID, number pieceIndex, boolean enabled, number scaleX, number scaleY, number scaleZ,
					number offsetX, number offsetY, number offsetZ, number vType, number Axis) -> nil
	per piece collision volumes always use COLVOL_TEST_CONT as tType
	above syntax is for 0.83, for 0.82 compatibility repeat enabled 3 more times
	
   possible vType constants
     DISABLED = -1  disables collision volume and collision detection for that unit, do not use
     ELLIPSOID = 0
     CYLINDER =  1
     BOX =       2
     SPHERE =    3
     FOOTPRINT = 4  intersection of sphere and footprint-prism, makes a sphere collision volume, default
	 
   possible tType constants, for non-sphere collision volumes use 1
     COLVOL_TEST_DISC = 0
     COLVOL_TEST_CONT = 1

   possible Axis constants, use non-zero only for Cylinder test
     COLVOL_AXIS_X = 0
     COLVOL_AXIS_Y = 1
     COLVOL_AXIS_Z = 2

   sample collision volume with detailed descriptions
	unitCollisionVolume["arm_advanced_radar_tower"] = {
		on=            -- Unit is active/open/poped-up 
		   {60,80,60,  -- Volume X scale, Volume Y scale, Volume Z scale,
		    0,15,0,    -- Volume X offset, Volume Y offset, Volume Z offset,
		    0,1,0},    -- vType, tType, axis}
		off={32,48,32,0,-10,0,0,1,0},
	}
	pieceCollisionVolume["arm_big_bertha"] = {
		["1"]={true,       -- [pieceIndexNumber]={enabled,
			   48,74,48,   --              Volume X scale, Volume Y scale, Volume Z scale,
		       0,0,0,      --              Volume X offset, Volume Y offset, Volume Z offset,
			   1,1}        --              vType, axis},
		["2"]={false},
		....
	}

]]--


--Collision volume definitions, ones entered here are for TA, for other mods modify apropriatly
local unitCollisionVolume = {}			--dynamic collision volume definitions
local pieceCollisionVolume = {}			--per piece collision volume definitions
local dynamicPieceCollisionVolume = {}	--dynamic per piece collision volume definitions

	unitCollisionVolume["armason"] = {
		on={57,60,57,0,-7,0,0,1,0},    --{Xscale,Yscale,Zscale, Xoffset,Yoffset,Zoffset, vType,tType,axis}
		off={24,34,24,0,10,0,0,1,0},
	}
	unitCollisionVolume["armamb"] = {
		on={49,45,49,-0.5,-14,0,0,1,0},
		off={49,26,49,-0.5,-14,0,0,1,0},
	}
	unitCollisionVolume["armanni"] = {
		on={54,81,54,0,-2,0,2,1,0},
		off={54,56,54,0,-15,0,2,1,0},
	}
	unitCollisionVolume["armlab"] = {
		on={95,28,95,0,2,0,2,1,0},
		off={95,22,95,0,-1,0,1,1,1},
	}
	unitCollisionVolume["armmmkr"] = {
		on={60,72,60,0,7,0,1,1,1},
		off={60,50,60,0,-4,0,1,1,1},
	}
	unitCollisionVolume["armpb"] = {
		on={39,88,39,0,-11,0,0,1,0},
		off={39,55,39,0,-27,0,0,1,0},
	}
	unitCollisionVolume["armplat"] = {
		on={105,66,105,0,33,0,2,1,0},
		off={105,44,105,0,0,0,2,1,0},
	}
	unitCollisionVolume["armsolar"] = {
		on={83,76,83,0,-18,1,0,1,0},
		off={50,76,50,0,-18,1,0,1,0},
	}
	unitCollisionVolume["armtarg"] = {
		on={62,34,62,0,0,0,2,1,0},
		off={55,78,55,0,-19.5,0,0,1,0},
	}
	unitCollisionVolume["armvp"] = {
		on={120,34,92,0,0,0,2,1,0},
		off={90,34,92,0,0,0,2,1,0},
	}
	unitCollisionVolume["cordoom"] = {
		on={63,112,63,0,12,0,1,1,1},
		off={45,87,45,0,0,0,2,1,0},
	}
	unitCollisionVolume["corfmkr"] = {
		on={48,46,48,0,0,0,0,1,0},
		off={48,43,48,0,-16,0,0,1,0},
	}
	unitCollisionVolume["cormexp"] = {
		on={83,77,78,0,-27,0,0,1,0},
		off={90,135,84,0,-27,0,0,1,0},
	}
	unitCollisionVolume["cormmkr"] = {
		on={60,60,60,0,0,0,1,1,1},
		off={50,92,50,0,-22.5,0,0,1,0},
	}
	unitCollisionVolume["corplat"] = {
		on={112,60,112,0,28,0,1,1,1},
		off={112,35,112,0,0,0,1,1,1},
	}
	unitCollisionVolume["corsolar"] = {
		on={86,78,86,0,-25,0,0,1,0},
		off={77,78,77,0,-35,0,0,1,0},
	}
	unitCollisionVolume["cortarg"] = {
		on={64,20,64,0,0,0,1,1,1},
		off={38,20,38,0,0,0,1,1,1},
	}
	unitCollisionVolume["cortoast"] = {
		on={44,23,44,0,4,0,2,1,0},
		off={44,7,44,0,-3.3,0,2,1,0},
	}
	unitCollisionVolume["corvipe"] = {
		on={39,86,39,0,-10,0,0,1,0},
		off={39,55,39,0,-27,0,0,1,0},
	}
	unitCollisionVolume["packo"] = {
		on={49,51,49,-0.5,-10,0,0,1,0},
		off={49,23,49,-0.5,-10,0,0,1,0},
	}
	unitCollisionVolume["shiva"] = {
		on={54,50,50,0,2,-1,0,1,0},
		off={54,45,50,0,-4,-1,0,1,0},
	}
	pieceCollisionVolume["armbrtha"] = {
			["0"]={true,32,80,32,0,20,0,1,1},
			["2"]={true,26,30,70,0,0,14,1,2},
			["1"]={false},
			["3"]={true,8,8,42,0,1,94,1,2},
			["4"]={false},	
	}
	pieceCollisionVolume["corint"] = {
			["0"]={true,73,103,73,0,50,0,1,1},
			["2"]={true,13,13,48,0,1,55,1,2},
			["1"]={false},
			["3"]={false},
			["4"]={false},	
	}		
	dynamicPieceCollisionVolume["corgant"] = {
		on = {
			["0"]={true,118,96,130,0,0,0,1,2},
			["1"]={false},
			["2"]={false},
			["3"]={false},
			["4"]={false},
			["5"]={false},
			["6"]={false},
			["7"]={false},
			["8"]={false},
			["9"]={false},
			["10"]={false},
			["11"]={false},
			["12"]={false},
			["13"]={false},
			["14"]={false},
			["15"]={false},
			["16"]={false},
			["17"]={true,105,55,105,0,7,30,1,2},
			["18"]={false},
			["19"]={false},
			["20"]={false},
			["21"]={false},
			["22"]={false},
			["23"]={false},
			["24"]={false},
			["25"]={false},
			["26"]={false},
			["27"]={false},
			["28"]={false},
			["29"]={false},
			["30"]={false},
			["31"]={false},
			["33"]={false},
			["32"]={false},
			["33"]={false},
			["34"]={false},
			["35"]={false},
			["36"]={false},
			["37"]={false},
			["38"]={false},
			["39"]={false},
			
			
		},
		off = {
			["0"]={true,110,66,130,0,0,0,1,2},
			["1"]={false},
			["2"]={false},
			["3"]={false},
			["4"]={false},
			["5"]={false},
			["6"]={false},
			["7"]={false},
			["8"]={false},
			["9"]={false},
			["10"]={false},
			["11"]={false},
			["12"]={false},
			["13"]={false},
			["14"]={false},
			["15"]={false},
			["16"]={false},
			["17"]={false},
			["18"]={false},
			["19"]={false},
			["20"]={false},
			["21"]={false},
			["22"]={false},
			["23"]={false},
			["24"]={false},
			["25"]={false},
			["26"]={false},
			["27"]={false},
			["28"]={false},
			["29"]={false},
			["30"]={false},
			["31"]={false},
			["33"]={false},
			["32"]={false},
			["33"]={false},
			["34"]={false},
			["35"]={false},
			["36"]={false},
			["37"]={false},
			["38"]={false},
			["39"]={false},
		}
	}	
	dynamicPieceCollisionVolume["armarad"] = {
		on = {
			["0"]={true,25,45,25,0,22,0,1,1},
			["1"]={false},
			["2"]={true,76,29,29,0,3,0,1,0},
			["3"]={false},
			["4"]={false},
			["5"]={false},
			["6"]={false},
		
			
			
		},
		off = {
			["0"]={true,32,51,32,0,8,1,0,0},
			["1"]={false},
			["2"]={false},
			["3"]={false},
			["4"]={false},
			["5"]={false},
			["6"]={false},
		
			
		}
	}
	
return unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume