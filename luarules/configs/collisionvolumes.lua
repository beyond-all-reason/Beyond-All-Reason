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
	dynamicPieceCollisionVolume["cor_viper"] = {	--same as with pieceCollisionVolume only uses "on" and "off" tables
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



unitCollisionVolume['armanni'] = {
	on={54,81,54,0,-2,0,2,1,0},
	off={54,56,54,0,-15,0,2,1,0},
}
unitCollisionVolume['armannit3'] = {
	on={81,121,81,0,-3,0,3,1,0},
	off={81,84,81,0,-22,0,3,1,0},
}
unitCollisionVolume['armlab'] = {
	on={95,28,95,0,2,0,2,1,0},
	off={95,22,95,0,-1,0,1,1,1},
}
unitCollisionVolume['armpb'] = {
	on={32,88,32,0,-8,0,1,1,1},
	off={40,40,40,0,-8,0,3,1,1},
}
unitCollisionVolume['armplat'] = {
	on={105,66,105,0,33,0,2,1,0},
	off={105,44,105,0,0,0,2,1,0},
}
unitCollisionVolume['armsolar'] = {
	on={73,76,73,0,-18,1,0,1,0},
	off={50,76,50,0,-18,1,0,1,0},
}
unitCollisionVolume['armvp'] = {
	on={120,34,92,0,0,0,2,1,0},
	off={90,34,92,0,0,0,2,1,0},
}
unitCollisionVolume['cordoom'] = {
	on={63,112,63,0,12,0,1,1,1},
	off={45,87,45,0,0,0,2,1,0},
}
unitCollisionVolume['cordoomt3'] = {
	on={95,168,95,0,18,0,2,1,1},
	off={68,131,68,0,0,0,3,1,0},
}
unitCollisionVolume['corplat'] = {
	on={112,60,112,0,28,0,1,1,1},
	off={112,35,112,0,0,0,1,1,1},
}
unitCollisionVolume['cormaw'] = {
	on={35,57,35,0,-5,-3,0,1,0},
	off={35,31,35,0,-5,-3,0,1,0},
}

for name, v in pairs(unitCollisionVolume) do
	for udid, ud in pairs(UnitDefs) do
		if string.find(ud.name, name) then
			unitCollisionVolume[ud.name] = v
		end
	end
end
pieceCollisionVolume['corhrk'] = {
	['2']={35,40,30,0,-8,0,2,1},

}
pieceCollisionVolume['legpede'] = {
	['0']={26,28,90,0,5,-23,2,1},
	['32']={26,28,86,0,0,7,2,1},
}
pieceCollisionVolume['legrail'] = {
	['0']={40,16,38,0,10,0,2,1},
	['2']={10,10,30,0,2,12,1,2},
}
pieceCollisionVolume['legsrail'] = {
	['0']={55,20,55,0,-2,0,1,1},
	['19']={15,15,60,0,5,12,1,2},
}
pieceCollisionVolume['armrad'] = {
	['1']={22,58,22,0,30,0,1,1},
	['3']={60,13,13,11,0,0,1,0},
}
pieceCollisionVolume['armamb'] = {
	['3']={22,22,22,0,0,-10,1,1},
	['0']={60,30,15,0,0,0,1,1,0},
}
pieceCollisionVolume['cortoast'] = {
	['3']={22,22,22,0,10,0,1,1},
	['0']={60,30,15,0,0,0,1,1,0},
}
pieceCollisionVolume['armveil'] = {
	['1']={25,75,25,0,-15,0,1,1},
	['3']={76,16,16,6,0,0,1,0},
}
pieceCollisionVolume['armbrtha'] = {
	['1']={32,84,32,0,-20,0,1,1},
	['3']={13,0,75,0,0,20,1,2},
	['4']={8,8,42,0,1,70,1,2},
}
pieceCollisionVolume['corint'] = {
	['1']={72,84,72,0,28,0,1,1},
	['3']={13,13,34,0,1,28,1,2},
}
pieceCollisionVolume['armvulc'] = {
	['0']={98,140,98,0,40,0,1,1},
	['5']={55,55,174,0,18,0,1,2},
}
pieceCollisionVolume['corgator'] = {
	['0']={23,14,33,0,0,0,2,1},
	['1']={15,5,25,0,0,2,2,1},
}
for name, v in pairs(pieceCollisionVolume) do
	for udid, ud in pairs(UnitDefs) do
		if string.find(ud.name, name) then
			pieceCollisionVolume[ud.name] = v
		end
	end
end

----dynamicPieceCollisionVolume['cortoast'] = {
----	on = {
----		['1']={40,40,40,-13,10,0,0,0},
----		['5']={8,8,21,0,1,-2,1,2},
----	},
----	off = {
----		['1']={12,58,58,-2,13,0,1,0},
----	}
----}
dynamicPieceCollisionVolume['corvipe'] = {
	on = {
		['0']={38,26,38,0,0,0,2,0},
		['5']={25,45,25,0,25,0,1,1}, -- changed to [1] so the cylinder collision is attached to the turret and not a door 
		['offsets']={0,23,0},
	},
	off = {
		['0']={38,26,38,0,0,0,2,0},
		['offsets']={0, 8, 0}, --['offsets']={0,10,0}, TODO: revert back when issue fixed: https://springrts.com/mantis/view.php?id=5144
	}
}
for name, v in pairs(dynamicPieceCollisionVolume) do
	for udid, ud in pairs(UnitDefs) do
		if string.find(ud.name, name) then
			dynamicPieceCollisionVolume[ud.name] = v
		end
	end
end

return unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume
