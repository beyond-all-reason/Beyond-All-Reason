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
		    0,1,0[,    -- vType, tType, axis [,  -- Optional
			0,0,0]}    -- Aimpoint X offset, Aimpoint Y offset, Aimpoint Z offset]},
		off={32,48,32,0,-10,0,0,1,0},
	}                  -- Aimpoint offsets are relative to unit's base position (aka unit coordiante space)
	pieceCollisionVolume["arm_big_bertha"] = {
		["0"]={true,       -- [pieceIndexNumber]={enabled,
			   48,74,48,   --            Volume X scale, Volume Y scale, Volume Z scale,
		       0,0,0,      --            Volume X offset, Volume Y offset, Volume Z offset,
			   1,1},       --            vType, axis},   
		....               -- All undefined pieces will be treated as disabled for collision detection
	}
	dynamicPieceCollisionVolume["core_viper"] = {	--same as with pieceCollisionVolume only uses "on" and "off" tables
		on = {
			["0"]={true,51,12,53,0,4,0,2,0},
			["5"]={true,25,66,25,0,-14,0,1,1},
			offsets={0,35,0}   -- Aimpoint X offset, Aimpoint Y offset, Aimpoint Z offset
		},                     -- offsets entry is optional 
		off = {
			["0"]={true,51,12,53,0,4,0,2,0},
			offsets={0,8,0}
		}
	}
	
	Q: How am I supposed to guess the piece index number?
	A: Open the model in UpSpring and locate your piece. Count all pieces above it in the piece tree.
	   Piece index number is equal to number of pieces above it in tree. Root piece has index 0.
	   Or start counting from tree top till your piece starting from 0. Count lines in Upspring
	   not along the tree hierarchy.
	Q: I defined all per piece volumes in here but unit still uses only one collision volume!
	A: Edit unit's definition file and add:
		usePieceCollisionVolumes=1;    (FBI)
		usePieceCollisionVolumes=true, (LUA)
	Q: The unit always has on/off volume and it never changes
	A: You need to edit the unit script and set ARMORED status to on or off depending on the
	   unit's on/off status, unarmored for on and armored for off
]]--

--Collision volume definitions, ones entered here are for TA, for other mods modify apropriatly
local unitCollisionVolume = {}			--dynamic collision volume definitions
local pieceCollisionVolume = {}			--per piece collision volume definitions
local dynamicPieceCollisionVolume = {}	--dynamic per piece collision volume definitions


	unitCollisionVolume["armason"] = {
		on={57,60,57,0,-7,0,1,1,1},    --{Xscale,Yscale,Zscale, Xoffset,Yoffset,Zoffset, vType,tType,axis}
		off={24,34,24,0,10,0,1,1,1},
	}
	unitCollisionVolume["armamb"] = {
		on={49,45,49,-0.5,-14,0,1,1,1},
		off={49,26,49,-0.5,-14,0,1,1,1},
	}
	unitCollisionVolume["armanni"] = {
		on={54,81,54,0,-2,0,2,1,0},
		off={54,56,54,0,-15,0,2,1,0},
	}
	unitCollisionVolume["armlab"] = {
		on={95,22,95,0,-1,0,1,1,1},
		off={95,22,95,0,-1,0,1,1,1},
	}
	unitCollisionVolume["armclaw"] = {
		on={32,39,32,0,-6,0,1,1,1},
		off={32,22,32,0,-16.5,0,1,1,1},
	}	
	unitCollisionVolume["armmmkr"] = {
		on={60,70,60,0,7,0,1,1,1},
		off={60,50,60,0,-4,0,1,1,1},
	}
	unitCollisionVolume["armpb"] = {
		on={39,78,39,0,-11,0,1,1,1},
		off={39,40,39,0,-27,0,1,1,1},
	}
	unitCollisionVolume["armplat"] = {
		on={105,66,105,0,33,0,2,1,0},
		off={105,44,105,0,0,0,2,1,0},
	}
	unitCollisionVolume["armsolar"] = {
		on={83,76,83,0,-18,1,1,1,1},
		off={50,76,50,0,-18,1,1,1,1},
	}
	unitCollisionVolume["armtarg"] = {
		on={62,34,62,0,0,0,2,1,0},
		off={55,78,55,0,-19.5,0,1,1,1},
	}
	unitCollisionVolume["armvp"] = {
		on={90,34,92,0,0,0,2,1,0},
		off={90,34,92,0,0,0,2,1,0},
	}
	unitCollisionVolume["cordoom"] = {
		on={63,112,63,0,12,0,1,1,1},
		off={45,87,45,0,0,0,2,1,0},
	}
	unitCollisionVolume["corfmkr"] = {
		on={48,46,48,0,0,0,1,1,1},
		off={48,43,48,0,-16,0,1,1,1},
	}
	unitCollisionVolume["cormaw"] = {
		on={32,39,32,0,-6,0,1,1,1},
		off={32,22,32,0,-16,0,1,1,1},
	}
	unitCollisionVolume["cormexp"] = {
		on={83,77,83,0,-27,0,1,1,1},
		off={90,135,90,0,-27,0,1,1,1},
	}
	unitCollisionVolume["cormmkr"] = {
		on={60,60,60,0,0,0,1,1,1},
		off={55,92,55,0,-22.5,0,1,1,1},
	}
	unitCollisionVolume["corplat"] = {
		on={112,60,112,0,28,0,1,1,1},
		off={112,35,112,0,0,0,1,1,1},
	}
	unitCollisionVolume["corsolar"] = {
		on={86,78,86,0,-25,0,1,1,1},
		off={60,78,60,0,-35,0,1,1,1},
	}
	unitCollisionVolume["cortarg"] = {
		on={64,20,64,0,0,0,1,1,1},
		off={38,20,38,0,0,0,1,1,1},
	}
	unitCollisionVolume["packo"] = {
		on={49,51,49,-0.5,-10,0,1,1,1},
		off={49,23,49,-0.5,-10,0,1,1,1},
	}
	unitCollisionVolume["shiva"] = {
		on={50,50,50,0,2,-1,1,1,1},
		off={54,45,54,0,-4,-1,1,1,1},
	}
	pieceCollisionVolume["armbrtha"] = {
			["0"]={32,80,32,0,20,0,1,1},
			["2"]={30,30,71,0,24,0,1,2},
			["3"]={8,8,42,0,1,70,1,2},
	}
	pieceCollisionVolume["corint"] = {
			["0"]={73,103,73,0,50,0,1,1},
			["2"]={13,13,48,0,1,55,1,2},
	}		
	pieceCollisionVolume["armveil"] = {
			["0"]={25,58,25,0,30,0,1,1},
			["2"]={76,16,16,6,0,0,1,0},
	}
	pieceCollisionVolume["armrad"] = {
			["0"]={22,58,22,0,30,0,1,1},
			["2"]={60,13,13,11,0,0,1,0},
	}
	dynamicPieceCollisionVolume["corgant"] = {
		on = {
			["0"]={130,96,130,0,0,0,1,2},
			["17"]={105,35,105,0,13,30,2,2},
		},
		off = {
			["0"]={130,66,130,0,0,0,1,2},
		}
	}
	dynamicPieceCollisionVolume["armarad"] = {
		on = {
			["0"]={25,45,25,0,22,0,1,1},
			["2"]={76,29,29,0,3,0,1,0},
		},
		off = {
			["0"]={32,51,32,0,8,1,1,1},
		}
	}
		dynamicPieceCollisionVolume["cortoast"] = {
		on = {
			["1"]={44,23,44,0,0,0,2,0},
			["7"]={10,10,60,0,3,13,1,2},
		},
		off = {
			["1"]={44,7,44,0,0,0,2,0},
		}
	}
	dynamicPieceCollisionVolume["corvipe"] = {
		on = {
			["0"]={40,12,30,0,0,0,2,0},
			["5"]={25,46,25,0,25,0,1,1},
		},
		off = {
			["0"]={39,55,39,0,0,0,0,1},
		}
	}

return unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume