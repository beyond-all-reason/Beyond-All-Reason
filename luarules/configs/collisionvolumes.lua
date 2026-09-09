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
     ELLIPSOID = 0
     CYLINDER =  1
     BOX =       2
     SPHERE =    3  default
   Values outside 0..3 are clamped by InitShape to an ellipsoid. Disabling a volume, defaulting
   it to the footprint, and defaulting it to a model-radius sphere are all real, but they are
   flags rather than vType values, and they are set from the unit def rather than from here:
   see UnitDefCollisionVolume below.

   possible tType constants, for non-sphere collision volumes use 1
     COLVOL_TEST_DISC = 0
     COLVOL_TEST_CONT = 1

   possible Axis constants, use non-zero only for Cylinder test
     COLVOL_AXIS_X = 0
     COLVOL_AXIS_Y = 1
     COLVOL_AXIS_Z = 2

   sample collision volume with detailed descriptions
	dynamicUnitCollisionVolume["arm_advanced_radar_tower"] = {
		on=            -- Unit is active/open/poped-up
		   {60,80,60,  -- Volume X scale, Volume Y scale, Volume Z scale,
		    0,15,0,    -- Volume X offset, Volume Y offset, Volume Z offset,
		    0,1,0[,    -- vType, tType, axis [,  -- Optional
			0,0,0]}    -- Aimpoint X offset, Aimpoint Y offset, Aimpoint Z offset]},
		off={32,48,32,0,-10,0,0,1,0},
	}                  -- Aimpoint offsets are relative to unit's base position (aka unit coordinate space)
	staticPieceCollisionVolume["arm_big_bertha"] = {
		["0"]={true,       -- [pieceIndexNumber]={enabled,
			   48,74,48,   --            Volume X scale, Volume Y scale, Volume Z scale,
		       0,0,0,      --            Volume X offset, Volume Y offset, Volume Z offset,
			   1,1},       --            vType, axis},
		....               -- All undefined pieces will be treated as disabled for collision detection
	}
	dynamicPieceCollisionVolume["cor_viper"] = { -- Same as with staticPieceCollisionVolume only uses "on" and "off" tables.

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
]]
--

-- Engine types ----------------------------------------------------------------

---Values outside the range become an ellipsoid.
---@alias VolumeShapeIndex
---|0 ELLIPSOID
---|1 CYLINDER
---|2 BOX
---|3 SPHERE

---@alias VolumeHitTestType
---|0 DISCRETE
---|1 CONTINUOUS

---@alias VolumeAxisIndex
---|0 X
---|1 Y
---|2 Z

---See `LuaUtils::ParseColVolData`.
---@class UnitCollisionVolumeData
---@field [1] number scaleX
---@field [2] number scaleY
---@field [3] number scaleZ
---@field [4] number offsetX
---@field [5] number offsetY
---@field [6] number offsetZ
---@field [7] VolumeShapeIndex volumeType (default := `3`, SPHERE)
---@field [8] VolumeHitTestType useContinuousHitTest (default := `1`, CONTINUOUS)
---@field [9] VolumeAxisIndex primaryAxis (default := `2`, Z)
---@field [10]? boolean ignoreHits Returned by the getter, ignored by the setter, which reads nine.
---@field radius number?
---@field height number?

---See `LuaUtils::PushColVolTable`.
---@class UnitDefCollisionVolume
---@field type "ellipsoid"|"cylinder"|"box"|"sphere"
---@field scaleX number
---@field scaleY number
---@field scaleZ number
---@field offsetX number
---@field offsetY number
---@field offsetZ number
---@field boundingRadius number
---@field defaultToSphere boolean Every scale was at most 1, so the volume becomes a model-radius sphere.
---@field defaultToFootPrint boolean From `useFootPrintCollisionVolume`. The volume becomes a footprint box.
---@field defaultToPieceTree boolean From `usePieceCollisionVolumes`. Hit tests go to the pieces and skip this volume.

---See `SetSolidObjectPieceCollisionVolumeData`.
---Piece volumes are always continuous so they lack a hit test field.
---@class PieceCollisionVolumeData
---@field [1] number scaleX (default := `1`)
---@field [2] number scaleY
---@field [3] number scaleZ
---@field [4] number offsetX (default := `0`)
---@field [5] number offsetY
---@field [6] number offsetZ
---@field [7] VolumeShapeIndex volumeType (default := `3`, SPHERE)
---@field [8] VolumeAxisIndex primaryAxis (default := `2`, Z)
---@field [9]? boolean enabled (default := `true`)

-- Collision volume definitions --------------------------------------------------

---Summary type for all unitDef collision volume configuration types. Unwieldy.
---@alias UnitColVolConfig ColVolUnitDef|ColVolUnitOnOff|ColVolPieceMap|ColVolPieceMapOnOff

---@alias ColVolUnitDef UnitCollisionVolumeData

---@class ColVolUnitOnOff
---@field on UnitCollisionVolumeData
---@field off UnitCollisionVolumeData

---@class ColVolPieceMap
---@field [string] PieceCollisionVolumeData Numeric string keys "0"..."65535" -- TODO: Plainly should be an integer. Fix is planned.
---@field offsets? number[] unit-space aimpoint offsets, `{ x, y, z }`

---@class ColVolPieceMapOnOff
---@field on ColVolPieceMap
---@field off ColVolPieceMap

-- A unit draws its collision volumes from exactly one of these four tables:

local staticUnitCollisionVolume = {} ---@type table<string, ColVolUnitDef> whole-unit volume definitions
local dynamicUnitCollisionVolume = {} ---@type table<string, ColVolUnitOnOff> whole-unit volume definitions, by armored state
local staticPieceCollisionVolume = {} ---@type table<string, ColVolPieceMap> per-piece volume definitions
local dynamicPieceCollisionVolume = {} ---@type table<string, ColVolPieceMapOnOff> per-piece volume definitions, by armored state

-- Lookup table to avoid probing for the base table type.
---@alias ColVolConfigType 1|2|3|4 UNIT_STATIC|UNIT_DYNAMIC|PIECE_STATIC|PIECE_DYNAMIC
local COLVOL_CONFIG = {
	UNIT_STATIC = 1,
	UNIT_DYNAMIC = 2,
	PIECE_STATIC = 3,
	PIECE_DYNAMIC = 4,
}

---Maps units to their collision volume data, organized by colvol types.
---@class CollisionVolumeConfigs
---@field [1] table<string, ColVolUnitDef> unitStaticColliders
---@field [2] table<string, ColVolUnitOnOff> unitDynamicColliders
---@field [3] table<string, ColVolPieceMap> pieceStaticColliders
---@field [4] table<string, ColVolPieceMapOnOff> pieceDynamicColliders
local colVolConfigs = {
	[COLVOL_CONFIG.UNIT_STATIC] = staticUnitCollisionVolume,
	[COLVOL_CONFIG.UNIT_DYNAMIC] = dynamicUnitCollisionVolume,
	[COLVOL_CONFIG.PIECE_STATIC] = staticPieceCollisionVolume,
	[COLVOL_CONFIG.PIECE_DYNAMIC] = dynamicPieceCollisionVolume,
}

-- Dynamic collision volumes ---------------------------------------------------

dynamicPieceCollisionVolume.cormaw = {
	on = {
		["0"] = { 32, 70, 32, 0, 5, 0, 1, 1 },
		offsets = { 0, 27, 0 },
	},
	off = {
		["0"] = { 32, 22, 32, 0, 10, 0, 1, 1 },
		offsets = { 0, 0, 0 },
	},
}
dynamicPieceCollisionVolume.armclaw = {
	on = {
		["0"] = { 32, 85, 32, 0, 5, 0, 1, 1 },
		offsets = { 0, 30, 0 },
	},
	off = {
		["0"] = { 32, 22, 32, 0, 10, 0, 1, 1 },
		offsets = { 0, 0, 0 },
	},
}
dynamicPieceCollisionVolume.legdtr = {
	on = {
		["0"] = { 32, 90, 32, 0, 5, 0, 1, 1 },
		offsets = { 0, 45, 0 },
	},
	off = {
		["0"] = { 32, 22, 32, 0, 11, 0, 1, 1 },
		offsets = { 0, 0, 0 },
	},
}
dynamicPieceCollisionVolume.armannit3 = {
	on = {
		["1"] = { 96, 140, 96, 0, 5, 0, 2, 1 },
	},
	off = {
		["0"] = { 96, 80, 96, 0, 10, 0, 2, 1 },
	},
}
dynamicPieceCollisionVolume.cordoomt3 = {
	on = {
		["1"] = { 112, 180, 112, 0, 5, 0, 1, 1 },
	},
	off = {
		["0"] = { 96, 80, 96, 0, 10, 0, 2, 1 },
	},
}
dynamicPieceCollisionVolume.leganavybattleship = {
	on = {
		["1"] = { 48, 48, 120, 0, 8, -58, 1, 2 },
		offsets = { 0, 30, 0 },
	},
	off = {
		["1"] = { 48, 48, 120, 0, 8, -58, 1, 2 },
		offsets = { 0, 0, 0 },
	},
}
dynamicPieceCollisionVolume.legacluster = {
	on = {
		["0"] = { 47, 56, 47, 0, 0, 0, 1, 1 },
		offsets = { 0, 18, 0 },
	},
	off = {
		["0"] = { 47, 20, 47, 0, 0, 0, 1, 1 },
		offsets = { 0, 0, 0 },
	},
}
dynamicPieceCollisionVolume.legapopupdef = {
	on = {
		["0"] = { 35, 68, 35, 0, 0, 0, 1, 1 },
		offsets = { 0, 18, 0 },
	},
	off = {
		["0"] = { 42, 42, 42, 0, 0, 0, 3, 1 },
		offsets = { 0, 10, 0 },
	},
}
dynamicPieceCollisionVolume.corvipe = {
	on = {
		["0"] = { 38, 26, 38, 0, 0, 0, 2, 0 },
		["5"] = { 25, 45, 25, 0, 25, 0, 1, 1 }, -- changed to [1] so the cylinder collision is attached to the turret and not a door
		offsets = { 0, 23, 0 },
	},
	off = {
		["0"] = { 38, 26, 38, 0, 0, 0, 2, 0 },
		offsets = { 0, 8, 0 }, --['offsets']={0,10,0}, TODO: revert back when issue fixed: https://springrts.com/mantis/view.php?id=5144
	},
}

dynamicUnitCollisionVolume.armanni = {
	on = { 54, 81, 54, 0, -2, 0, 2, 1, 0 },
	off = { 54, 56, 54, 0, -15, 0, 2, 1, 0 },
}
dynamicUnitCollisionVolume.armlab = {
	on = { 95, 28, 95, 0, 2, 0, 2, 1, 0 },
	off = { 95, 22, 95, 0, -1, 0, 1, 1, 1 },
}
dynamicUnitCollisionVolume.armpb = {
	on = { 32, 88, 32, 0, -8, 0, 1, 1, 1 },
	off = { 40, 40, 40, 0, -8, 0, 3, 1, 1 },
}
dynamicUnitCollisionVolume.armplat = {
	on = { 96, 66, 96, 0, 33, 0, 1, 1, 1 },
	off = { 96, 44, 96, 0, 0, 0, 1, 1, 1 },
}
dynamicUnitCollisionVolume.armsolar = {
	on = { 73, 76, 73, 0, -18, 1, 0, 1, 0 },
	off = { 50, 76, 50, 0, -18, 1, 0, 1, 0 },
}
dynamicUnitCollisionVolume.armvp = {
	on = { 96, 34, 96, 0, 0, 0, 2, 1, 0 },
	off = { 96, 34, 96, 0, 0, 0, 2, 1, 0 },
}
dynamicUnitCollisionVolume.cordoom = {
	on = { 63, 112, 63, 0, 0, 0, 1, 1, 1 },
	off = { 45, 87, 45, 0, -12, 0, 2, 1, 0 },
}

dynamicUnitCollisionVolume.corplat = {
	on = { 96, 60, 96, 0, 28, 0, 1, 1, 1 },
	off = { 96, 42, 96, 0, -20, 0, 1, 1, 1 },
}
dynamicUnitCollisionVolume.legsplab = {
	on = { 96, 76, 96, 0, 24, 0, 1, 1, 1 },
	off = { 96, 46, 96, 0, -12, 0, 1, 1, 1 },
}
dynamicUnitCollisionVolume.legsolar = {

	on = { 70, 70, 70, 0, -12, 1, 0, 1, 0 },

	off = { 40, 76, 40, 0, -10, 1, 0, 1, 0 },
}

-- Static collision volumes ----------------------------------------------------

staticPieceCollisionVolume.corhrk = {
	["2"] = { 35, 40, 30, 0, -8, 0, 2, 1 },
}
staticPieceCollisionVolume.legpede = {
	["0"] = { 26, 28, 90, 0, 5, -23, 2, 1 },
	["32"] = { 26, 28, 86, 0, 0, 7, 2, 1 },
}
staticPieceCollisionVolume.legelrpcmech = {
	["0"] = { 48, 48, 80, 0, -10, 0, 2, 0 },
	["10"] = { 24, 36, 24, -4, -6, 1, 1, 1 },
	["22"] = { 24, 36, 24, -2, 2, 1, 1, 1 },
	["15"] = { 28, 36, 28, -8, -6, 2, 1, 1 },
	["28"] = { 28, 36, 28, 6, -6, 2, 1, 1 },
	["29"] = { 28, 20, 40, 0, 2, 0, 2, 0 },
}
staticPieceCollisionVolume.legrail = {
	["2"] = { 29, 20, 34, -0.5, -4, -4, 2, 1 },
	["5"] = { 10, 10, 36, 0, 0, 9, 1, 2 },
}
staticPieceCollisionVolume.legsrail = {
	["0"] = { 55, 24, 55, 0, 12, 0, 1, 1 },
	["7"] = { 12, 12, 60, 0, 3, 9, 1, 2 },
}
staticPieceCollisionVolume.leghelios = {
	["0"] = { 30, 11, 25, 0, -4, 1, 2, 0 },
	["2"] = { 16, 10, 18, 0, 3.5, 2, 2, 0 },
}
staticPieceCollisionVolume.leggat = {
	["0"] = { 33, 12, 43, 0, 0, 2, 2, 1 },
	["5"] = { 20, 20, 20, 0, 2, 0, 3, 0 },
}
staticPieceCollisionVolume.legaskirmtank = {
	["0"] = { 40, 20, 42, 0, -2, -1, 0, 2 },
	["1"] = { 37, 8, 31, 0, 0, 6, 2, 1 },
	["2"] = { 24, 24, 24, 0, 0, 0, 3, 1 },
}
staticPieceCollisionVolume.legamcluster = {
	["0"] = { 37, 16, 50, 0, 0, 0, 2, 1 },
	["2"] = { 16, 12, 24, 0, 7.5, -2, 2, 1 },
}
staticPieceCollisionVolume.legaheattank = {
	["0"] = { 46, 17, 56, 0, 0, 0, 2, 1 },
	["2"] = { 20, 20, 27, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.legerailtank = {
	["0"] = { 65, 20, 75, 0, -4, 0, 2, 1 },
	["4"] = { 31, 21, 36, 0, 0, 0, 2, 1 },
	--['10']={50,50,50,0,0,0,2,1},
}
staticPieceCollisionVolume.leginf = {
	["1"] = { 28, 20, 76, 0, 24, 14, 2, 1 },
	["0"] = { 35, 20, 80, 0, 8, 16, 2, 1 },
}
staticPieceCollisionVolume.legbastion = {
	["0"] = { 80, 32, 80, 0, 15, 0, 2, 0 },
	["2"] = { 48, 90, 48, 0, 30, 0, 2, 0 },
	["10"] = { 36, 45, 36, 0, -8, 0, 1, 1 },
}

staticPieceCollisionVolume.armrad = {
	["1"] = { 22, 58, 22, 0, 0, 0, 1, 1 },
	["3"] = { 60, 13, 13, 11, 0, 0, 1, 0 },
}
staticPieceCollisionVolume.armamb = {
	["3"] = { 22, 22, 22, 0, 0, -10, 1, 1 },
	["0"] = { 60, 30, 15, 0, 0, 0, 1, 1 },
}
staticPieceCollisionVolume.cortoast = {
	["3"] = { 22, 22, 22, 0, 10, 0, 1, 1 },
	["0"] = { 60, 30, 15, 0, 0, 0, 1, 1 },
}
staticPieceCollisionVolume.armbrtha = {
	["1"] = { 32, 84, 32, 0, -20, 0, 1, 1 },
	["3"] = { 13, 0, 75, 0, 0, 20, 1, 2 },
}
staticPieceCollisionVolume.corint = {
	["1"] = { 72, 84, 72, 0, 28, 0, 1, 1 },
	["3"] = { 13, 13, 34, 0, 1, 28, 1, 2 },
}
staticPieceCollisionVolume.armvulc = {
	["0"] = { 98, 140, 98, 0, 40, 0, 1, 1 },
	["5"] = { 55, 55, 174, 0, 18, 0, 1, 2 },
}
staticPieceCollisionVolume.corgator = {
	["0"] = { 23, 14, 33, 0, 0, 0, 2, 1 },
	["3"] = { 15, 5, 25, 0, 0, 2, 2, 1 },
}
staticPieceCollisionVolume.corsala = {
	["0"] = { 34, 20, 34, 0, 3.5, 0, 2, 1 },
	["1"] = { 13.5, 6.2, 17, 0, 1.875, 1.5, 2, 1 },
}
staticPieceCollisionVolume.cortermite = {
	["3"] = { 22, 10, 22, 0, 2, 0, 1, 1 },
	["1"] = { 48, 25, 48, 0, 0, 0, 1, 1 },
}

staticPieceCollisionVolume.correap = {
	["1"] = { 35, 20, 46, 0, 1, 0, 2, 1 },
	["9"] = { 19, 14, 20, 0, 2, 0, 2, 1 },
}
staticPieceCollisionVolume.corlevlr = {
	["0"] = { 31, 17, 31, 0, 3.5, 0, 2, 1 },
	["1"] = { 16, 10, 15, 0, 1.875, 1.5, 2, 1 },
}
staticPieceCollisionVolume.corraid = {
	["0"] = { 33, 18, 39, 0, 3.5, 0, 2, 1 },
	["4"] = { 16, 7, 15, 0, 0, 1, 2, 1 },
}
staticPieceCollisionVolume.cormist = {
	["0"] = { 34, 18, 43, 0, 3.5, 0, 2, 1 },
	["1"] = { 20, 28, 24, 0, 0, 1.5, 2, 1 },
}
staticPieceCollisionVolume.corgarp = {
	["0"] = { 30, 21, 42, 0, 0, 6, 2, 1 },
	["6"] = { 16, 7, 15, 0, -2, 1.5, 2, 1 },
}
staticPieceCollisionVolume.armstump = {
	["0"] = { 34, 18, 40, 0, -5, 0, 2, 1 },
	["18"] = { 17, 16, 16, 1, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armsam = {
	["0"] = { 26, 26, 43, 0, 0, -2, 2, 1 },
	["8"] = { 16, 16, 20, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armpincer = {
	["0"] = { 31, 13, 31, 0, 5, 0, 2, 1 },
	["1"] = { 16, 12, 20, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armjanus = {
	["0"] = { 26, 12, 35, 0, 0, 0, 2, 1 },
	["1"] = { 20, 10, 20, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armanac = {
	["0"] = { 40, 19, 40, 0, 4, 0, 1, 1 },
	["3"] = { 16, 10, 16, 0, 5, 0, 2, 1 },
}
staticPieceCollisionVolume.corah = {
	["0"] = { 28, 16, 35, 0, 5, 0, 2, 1 },
	["2"] = { 10, 20, 10, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corhal = {
	["0"] = { 42, 12, 42, 0, 0, 0, 2, 1 },
	["1"] = { 14, 10, 14, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corsnap = {
	["0"] = { 32, 16, 38, 0, 4, 0, 2, 1 },
	["3"] = { 12, 10, 12, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corsumo = {
	["0"] = { 42, 32, 45, 0, 0, 0, 2, 1 },
	["2"] = { 22, 10, 22, 0, 0, 0, 1, 1 },
}
staticPieceCollisionVolume.armfboy = {
	["0"] = { 34, 40, 42, 0, -5, 0, 2, 1 },
	["8"] = { 16, 16, 16, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armfido = {
	["1"] = { 26, 32, 34, 0, -10, 10, 2, 1 },
	["15"] = { 12, 30, 12, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corgol = {
	["0"] = { 48, 44, 56, 0, 0, 0, 2, 1 },
	["3"] = { 24, 24, 24, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.cortrem = {
	["0"] = { 40, 32, 44, 0, 0, 0, 2, 1 },
	["1"] = { 24, 64, 24, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corseal = {
	["0"] = { 28, 25, 34, 0, 0, 0, 2, 1 },
	["1"] = { 12, 16, 12, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.corban = {
	["0"] = { 44, 32, 44, 0, 0, 0, 2, 1 },
	["3"] = { 24, 16, 24, 0, 8, 0, 2, 1 },
}
staticPieceCollisionVolume.cormart = {
	["0"] = { 30, 28, 34, 0, 0, 0, 2, 1 },
	["5"] = { 12, 25, 12, 0, 2, 0, 2, 1 },
}
staticPieceCollisionVolume.armmart = {
	["0"] = { 44, 24, 50, 0, 0, 0, 2, 1 },
	["1"] = { 16, 32, 16, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armbull = {
	["0"] = { 44, 23, 52, 0, 5, 0, 2, 1 },
	["4"] = { 24, 18, 24, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armlatnk = {
	["0"] = { 30, 26, 34, 0, 0, 0, 2, 1 },
	["5"] = { 16, 16, 16, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armmanni = {
	["0"] = { 48, 34, 38, 0, 10, 0, 2, 1 },
	["1"] = { 24, 52, 24, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.armthor = {
	["0"] = { 80, 25, 80, 0, 10, 0, 2, 1 },
	["15"] = { 55, 25, 40, 0, 0, 0, 2, 1 },
}
staticPieceCollisionVolume.legfloat = {
	["0"] = { 40, 18, 50, 0, -1.5, 0, 2, 1 },
	["8"] = { 18, 9, 30, 0, 1, -5, 2, 1 },
}
staticPieceCollisionVolume.legnavyfrigate = {
	["0"] = { 30, 18, 52, -1, -4, 1, 1, 1 },
	["3"] = { 11, 13, 20, 0, 5, 0, 2, 1 },
}
staticPieceCollisionVolume.legcar = {
	["0"] = { 34, 16, 46, 0, -2.5, 1, 2, 1 },
	["4"] = { 14, 12, 20, 0, -2, -6, 2, 1 },
}

staticPieceCollisionVolume.legmed = {
	["0"] = { 48, 31, 69, 0, 0, 0, 2, 1 },
	["1"] = { 7, 35, 15, 0, 40, -5, 2, 1 },
}

staticPieceCollisionVolume.legehovertank = {
	["0"] = { 63, 32, 63, 0, -15, 0, 1, 1 },
	["20"] = { 25, 12, 37, 0, 0, -6, 2, 1 },
}

staticPieceCollisionVolume.corsiegebreaker = {
	["0"] = { 36, 18, 64, 0, 4, 8, 2, 2 },
	["1"] = { 19, 12, 24, 0, -2.5, -2.5, 2, 1 },
}

staticPieceCollisionVolume.armshockwave = {
	["2"] = { 22, 22, 22, 0, 10, 0, 1, 1 },
	["0"] = { 60, 65, 60, 0, 20, 0, 1, 1 },
}
staticPieceCollisionVolume.legmohoconct = {
	["0"] = { 70, 30, 70, 0, -3, 0, 1, 1 },
	["1"] = { 21, 16, 30, 0, -3, -1, 2, 1 },
}
staticPieceCollisionVolume.legkeres = {
	["0"] = { 58, 22, 68, 0, -6, 1, 2, 0 },
	["2"] = { 44, 19, 48, 0, 9.5, 2, 2, 0 },
}

-- TODO: copied collision volumes should be declarative

staticPieceCollisionVolume.corgolt4 = staticPieceCollisionVolume.corgol
staticPieceCollisionVolume.corhalab = staticPieceCollisionVolume.corhal
staticPieceCollisionVolume.leggatet3 = staticPieceCollisionVolume.leggat
staticPieceCollisionVolume.leginfestor = staticPieceCollisionVolume.leginf
staticPieceCollisionVolume.legsrailt4 = staticPieceCollisionVolume.legsrail

-- Processing collision volumes ------------------------------------------------

-- copy each entry to its scavenger variants, matched via the customparams that scav def
-- generation stamps (isscavenger + fromunit backlink). The old substring propagation
-- corrupted units whose name merely contained another entry's name (armannit3/cordoomt3
-- got armanni/cordoom's whole-unit volumes, clobbering their per-piece definitions)
local function propagateToScavCopies(tbl)
	local scavCopies = {}
	for _, unitDef in pairs(UnitDefs) do
		local baseName = unitDef.customParams.isscavenger and unitDef.customParams.fromunit
		if baseName and tbl[baseName] then
			scavCopies[unitDef.name] = tbl[baseName]
		end
	end
	for name, v in pairs(scavCopies) do
		tbl[name] = v
	end
end
propagateToScavCopies(staticUnitCollisionVolume)
propagateToScavCopies(dynamicUnitCollisionVolume)
propagateToScavCopies(staticPieceCollisionVolume)
propagateToScavCopies(dynamicPieceCollisionVolume)

local unitColVolTypeIndex = {} ---@type table<string, ColVolConfigType>
for configType = 1, #colVolConfigs do
	for unitName in pairs(colVolConfigs[configType]) do
		unitColVolTypeIndex[unitName] = configType
	end
end

-- TODO: For now, we reunify the config tables into the consumer's tables. Later these should not merge.
local unitCollisionVolume = {}
local pieceCollisionVolume = {}

for unitName, configType in pairs(unitColVolTypeIndex) do
	if configType == COLVOL_CONFIG.UNIT_STATIC or configType == COLVOL_CONFIG.UNIT_DYNAMIC then
		unitCollisionVolume[unitName] = colVolConfigs[configType][unitName]
	elseif configType == COLVOL_CONFIG.PIECE_STATIC then
		pieceCollisionVolume[unitName] = colVolConfigs[configType][unitName]
	end
end

-- Lacks an explicit unit + dynamic table:
return unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume
