--[[  from Spring Wiki, info about CollisionVolumeData
Spring.GetUnitCollisionVolumeData ( number unitID ) -> 
	number scaleX, number scaleY, number scaleZ, number offsetX, number offsetY, number offsetZ,
	number volumeType, number testType, number primaryAxis, boolean disabled

Spring.SetUnitCollisionVolumeData ( number unitID, number scaleX, number scaleY, number scaleZ,
					number offsetX, number offsetY, number offsetX,
					number vType, number tType, number Axis ) -> nil

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
]]--

--Collision volume definitions, ones entered here are for BA, for other mods modify apropriatly

local unitCollisionVolume = {}

	unitCollisionVolume["armarad"] = {
		on={66,80,66,0,15,0,0,1,0},    --{Xscale,Yscale,Zscale, Xoffset,Yoffset,Zoffset, vType,tType,axis}
		off={32,51,32,0,-9,0,0,1,0},
	}
	unitCollisionVolume["armason"] = {
		on={57,60,57,0,-7,0,0,1,0},
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
	unitCollisionVolume["armmmkr"] = {
		on={60,72,60,0,7,0,1,1,1},
		off={60,50,60,0,-4,0,1,1,1},
	}
	unitCollisionVolume["armpb"] = {
		on={39,88,39,0,-14,0,0,1,0},
		off={39,53,39,0,-20,0,0,1,0},
	}
	unitCollisionVolume["armplat"] = {
		on={105,66,105,0,33,0,2,1,0},
		off={105,44,105,0,0,0,2,1,0},
	}
	unitCollisionVolume["armsolar"] = {
		on={83,100,83,0,-12,1,0,1,0},
		off={50,95,50,0,-12,1,0,1,0},
	}
	unitCollisionVolume["armtarg"] = {
		on={62,34,62,0,0,0,2,1,0},
		off={55,78,55,0,-5.5,0,0,1,0},
	}
	unitCollisionVolume["cordoom"] = {
		on={55,105,55,0,-3,0,2,1,0},
		off={48,86,48,0,-15,0,2,1,0},
	}
	unitCollisionVolume["cormmkr"] = {
		on={60,60,60,0,0,0,1,1,1},
		off={50,92,50,0,-17.5,0,0,1,0},
	}
	unitCollisionVolume["corplat"] = {
		on={112,60,112,0,30,0,1,1,1},
		off={112,37,112,0,0,0,1,1,1},
	}
	unitCollisionVolume["corsolar"] = {
		on={86,43,86,0,-10,0,0,1,0},
		off={57,32,57,0,-10,0,0,1,0},
	}
	unitCollisionVolume["cortarg"] = {
		on={64,20,64,0,0,0,1,1,1},
		off={38,20,38,0,0,0,1,1,1},
	}
	unitCollisionVolume["cortoast"] = {
		on={44,23,44,0,0,0,2,1,0},
		off={44,10,44,0,-7,0,2,1,0},
	}
	unitCollisionVolume["corvipe"] = {
		on={39,86,39,0,-13,0,0,1,0},
		off={39,35,39,0,-17,0,0,1,0},
	}
	unitCollisionVolume["packo"] = {
		on={49,45,49,-0.5,-14,0,0,1,0},
		off={49,26,49,-0.5,0,0,0,1,0},
	}

return unitCollisionVolume