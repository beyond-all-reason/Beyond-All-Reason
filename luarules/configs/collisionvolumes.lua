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
	
	Warning 
	Ensure that buildings/units do not have a unitdeff hitbox defined
	It will break certain units being able to damage the relevant building/unit
	this is possibly a bug but not sure

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

-- number of times this table had to be touched since 2022 ~45
-- increase this number eachtime this table gets touched

dynamicPieceCollisionVolume['cormaw'] = {
    on={
        ['0']={32,70,32,0,5,0,1,1,1},
        ['offsets']={0,27,0},
    },
    off={
        ['0']={32,22,32,0,10,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['armclaw'] = {
    on={
        ['0']={32,85,32,0,5,0,1,1,1},
        ['offsets']={0,30,0},
    },
    off={
        ['0']={32,22,32,0,10,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['legdtr'] = {
    on={
        ['0']={32,90,32,0,5,0,1,1,1},
        ['offsets']={0,45,0},
    },
    off={
        ['0']={32,22,32,0,11,0,1,1,1},
        ['offsets']={0,0,0},
    }
}
dynamicPieceCollisionVolume['armannit3'] = {
    on={
        ['1']={96,140,96,0,5,0,2,1,0},
    },
    off={
        ['0']={96,80,96,0,10,0,2,1,0},
    }
}
dynamicPieceCollisionVolume['cordoomt3'] = {
    on={
        ['1']={112,180,112,0,5,0,1,1,0},
    },
    off={
        ['0']={96,80,96,0,10,0,2,1,0},
    }
}

unitCollisionVolume['armanni'] = {
	on={54,81,54,0,-2,0,2,1,0},
	off={54,56,54,0,-15,0,2,1,0},
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
	on={96,66,96,0,33,0,1,1,1},
	off={96,44,96,0,0,0,1,1,1},
}
unitCollisionVolume['armsolar'] = {
	on={73,76,73,0,-18,1,0,1,0},
	off={50,76,50,0,-18,1,0,1,0},
}
unitCollisionVolume['armvp'] = {
	on={96,34,96,0,0,0,2,1,0},
	off={96,34,96,0,0,0,2,1,0},
}
unitCollisionVolume['cordoom'] = {
	on={63,112,63,0,0,0,1,1,1},
	off={45,87,45,0,-12,0,2,1,0},
}

unitCollisionVolume['corplat'] = {
	on={96,60,96,0,28,0,1,1,1},
	off={96,42,96,0,-20,0,1,1,1},
}
unitCollisionVolume['legsolar'] = {

	on={70,70,70,0,-12,1,0,1,0},

	off={40,76,40,0,-10,1,0,1,0},

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
--pieceCollisionVolume['legrail'] = {
--	['0']={40,16,38,0,10,0,2,1},
--	['2']={10,10,30,0,2,12,1,2},
--}
pieceCollisionVolume['legsrail'] = {
	['0']={55,24,55,0,12,0,1,1},
	['7']={12,12,60,0,3,9,1,2},
}
pieceCollisionVolume['legerailtank'] = {
	['0']={65,20,75, 0,-4,0, 2,1}, 
	['4']={31,21,36, 0,0,0, 2,1},
	--['10']={50,50,50,0,0,0,2,1},
}
pieceCollisionVolume['leginf'] = {
	['1']={38,49,88, 0,22.8,14.3, 2,1},
	['0']={35,37,88, 0,21,11, 2,1},
}
---pieceCollisionVolume['legsrailt4'] = {
---	['0']={121,53,121,0,26,0,2,2},
---	['7']={26,26,132,0,7,20,2,4},
---}
pieceCollisionVolume['armrad'] = {
	['1']={22,58,22,0,0,0,1,1},
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
pieceCollisionVolume['armbrtha'] = {
	['1']={32,84,32,0,-20,0,1,1},
	['3']={13,0,75,0,0,20,1,2},
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
	['3']={15,5,25,0,0,2,2,1},
}
pieceCollisionVolume['corsala'] = {
	['0']={34,20,34,0,3.5,0,2,1},
	['1']={13.5,6.2,17,0,1.875,1.5,2,1},
}
pieceCollisionVolume['cortermite'] = {
	['3']={22,10,22,0,2,0,1,1},
	['1']={48,25,48,0,0,0,1,1,0},
}


pieceCollisionVolume['correap'] = {
	['0']={36,20,46,0,3.5,0,2,1},
	['3']={24,14,24,0,1.875,1.5,2,1},
}
pieceCollisionVolume['corlevlr'] = {
	['0']={31,17,31,0,3.5,0,2,1},
	['1']={16,10,15,0,1.875,1.5,2,1},
}
pieceCollisionVolume['corraid'] = {
	['0']={33,18,39,0,3.5,0,2,1},
	['4']={16,7,15,0,0,1,2,1},
}
pieceCollisionVolume['cormist'] = {
	['0']={34,18,43,0,3.5,0,2,1},
	['1']={20,28,24,0,0,1.5,2,1},
}
pieceCollisionVolume['corgarp'] = {
	['0']={30,21,42,0,0,6,2,1},
	['6']={16,7,15,0,-2,1.5,2,1},
}
pieceCollisionVolume['armstump'] = {
	['0']={34,18,40,0,-5,0,2,1},
	['18']={17,16,16,1,0,0,2,1},
}
pieceCollisionVolume['armsam'] = {
	['0']={26,26,43,0,0,-2,2,1},
	['8']={16,16,20,0,0,0,2,1},
}
pieceCollisionVolume['armpincer'] = {
	['0']={31,13,31,0,5,0,2,1},
	['1']={16,12,20,0,0,0,2,1},
}
pieceCollisionVolume['armjanus'] = {
	['0']={26,12,35,0,0,0,2,1},
	['1']={20,10,20,0,0,0,2,1},
}
pieceCollisionVolume['armanac'] = {
	['0']={40,19,40,0,4,0,1,1},
	['3']={16,10,16,0,5,0,2,1},
}
pieceCollisionVolume['corah'] = {
	['0']={28,16,35,0,5,0,2,1},
	['2']={10,20,10,0,0,0,2,1},
}
pieceCollisionVolume['corhal'] = {
	['0']={42,12,42,0,0,0,2,1},
	['1']={14,10,14,0,0,0,2,1},
}
pieceCollisionVolume['corsnap'] = {
	['0']={32,16,38,0,4,0,2,1},
	['3']={12,10,12,0,0,0,2,1},
}
pieceCollisionVolume['corsumo'] = {
	['0']={42,32,45,0,0,0,2,1},
	['2']={22,10,22,0,0,0,1,1},
}
pieceCollisionVolume['armfboy'] = {
	['0']={34,40,42,0,-5,0,2,1},
	['8']={16,16,16,0,0,0,2,1},
}
pieceCollisionVolume['armfido'] = {
	['1']={26,32,34,0,-10,10,2,1},
	['15']={12,30,12,0,0,0,2,1},
}
pieceCollisionVolume['corgol'] = {
	['0']={48,44,56,0,0,0,2,1},
	['3']={24,24,24,0,0,0,2,1},
}
pieceCollisionVolume['cortrem'] = {
	['0']={40,32,44,0,0,0,2,1},
	['1']={24,64,24,0,0,0,2,1},
}
pieceCollisionVolume['seal'] = {
	['0']={28,25,34,0,0,0,2,1},
	['1']={12,16,12,0,0,0,2,1},
}
pieceCollisionVolume['corban'] = {
	['0']={44,32,44,0,0,0,2,1},
	['3']={24,16,24,0,8,0,2,1},
}
pieceCollisionVolume['cormart'] = {
	['0']={30,28,34,0,0,0,2,1},
	['5']={12,25,12,0,2,0,2,1},
}
pieceCollisionVolume['armmart'] = {
	['0']={44,24,50,0,0,0,2,1},
	['1']={16,32,16,0,0,0,2,1},
}
pieceCollisionVolume['armbull'] = {
	['0']={44,23,52,0,5,0,2,1},
	['4']={24,18,24,0,0,0,2,1},
}
pieceCollisionVolume['armlatnk'] = {
	['0']={30,26,34,0,0,0,2,1},
	['5']={16,16,16,0,0,0,2,1},
}
pieceCollisionVolume['armmanni'] = {
	['0']={48,34,38,0,10,0,2,1},
	['1']={24,52,24,0,0,0,2,1},
}
pieceCollisionVolume['armthor'] = {
	['0']={80,25,80,0,10,0,2,1},
	['15']={55,25,40,0,0,0,2,1},
}
pieceCollisionVolume['legfloat'] = {
	['0']={40,18,50,0,-1.5,0,2,1},
	['8']={18,9,30,0,1,-5,2,1},
}
pieceCollisionVolume['legnavyfrigate'] = {
	['0']={30,18,52,-1,-4,1,2,1},
	['3']={11,13,20,0,5,0,2,1},
}
pieceCollisionVolume['legcar'] = {
	['0']={34,16,46,0,-2.5,1,2,1},
	['4']={14,12,20,0,-2,-6,2,1},
}

pieceCollisionVolume['legmed'] = {
	['0']={48,31,69,0,0,0,2,1},
	['1']={7,25,15,0,35,-5,2,1},
}

pieceCollisionVolume['legehovertank'] = {
	['0']={63,32,63,0,-15,0,1,1},
	['20']={25,12,37,0,0,-6,2,1},
}

pieceCollisionVolume['corsiegebreaker'] = {
	['0']={36,18,64,0,4,8,2,2},
	['1']={19,12,24,0,-2.5,-2.5,2,1},
}

pieceCollisionVolume['armshockwave'] = {
    ['2']={22,22,22,0,10,0,1,1},
    ['0']={60,65,60,0,20,0,1,1,0},
}
pieceCollisionVolume['legmohoconct'] = {
	['0']={70,30,70,0,-3,0,1,1},
	['1']={21,16,30,0,-3,-1,2,1},
}

for name, v in pairs(pieceCollisionVolume) do
	for udid, ud in pairs(UnitDefs) do
		if string.find(ud.name, name) then
			pieceCollisionVolume[ud.name] = v
		end
	end
end

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
