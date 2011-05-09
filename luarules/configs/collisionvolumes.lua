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
		on={55,112,55,0,-3,0,2,1,0},
		off={48,86,48,0,-15,0,2,1,0},
	}
	unitCollisionVolume["corfmkr"] = {
		on={48,46,48,0,0,0,0,1,0},
		off={48,43,48,0,-16,0,0,1,0},
	}
	unitCollisionVolume["corgant"] = {
		on={118,96,130,0,-21,0,1,1,2},
		off={110,66,130,0,-21,0,1,1,2},
	}
	unitCollisionVolume["cormexp"] = {
		on={83,77,78,0,-32,0,0,1,0},
		off={90,135,84,0,-32,0,0,1,0},
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
		on={49,45,49,-0.5,-14,0,0,1,0},
		off={49,26,49,-0.5,-13,0,0,1,0},
	}
	unitCollisionVolume["shiva"] = {
		on={54,50,50,0,2,-1,0,1,0},
		off={54,45,50,0,-4,-1,0,1,0},
	}

return unitCollisionVolume