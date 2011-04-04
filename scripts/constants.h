#ifndef CONSTANTS_H_
#define CONSTANTS_H_
#endif

#define SFXTYPE_VTOL			1
#define SFXTYPE_THRUST			2
#define	SFXTYPE_WAKE1			3
#define	SFXTYPE_WAKE2			4
#define	SFXTYPE_REVERSEWAKE1	5
#define	SFXTYPE_REVERSEWAKE2	6

#define SFXTYPE_POINTBASED		256
#define SFXTYPE_WHITESMOKE		256|1
#define SFXTYPE_BLACKSMOKE		256|2
#define SFXTYPE_SUBBUBBLES		256|3

#define SHATTER					1
#define EXPLODE_ON_HIT			2
#define FALL					4
#define SMOKE					8
#define FIRE					16
#define BITMAPONLY				32
#define BITMAP					10000001

// Explosion generators
#define UNIT_SFX1				1024
#define UNIT_SFX2				1025
#define UNIT_SFX3				1026
#define UNIT_SFX4				1027
#define UNIT_SFX5				1028
#define UNIT_SFX6				1029
#define UNIT_SFX7				1030
#define UNIT_SFX8				1031

// Weapons
#define FIRE_W1					2048
#define FIRE_W2					2049
#define FIRE_W3					2050
#define FIRE_W4					2051
#define FIRE_W5					2052
#define FIRE_W6					2053
#define FIRE_W7					2054
#define FIRE_W8					2055

#define DETO_W1					4096
#define DETO_W2					4097
#define DETO_W3					4098
#define DETO_W4					4099
#define DETO_W5					4100
#define DETO_W6					4101
#define DETO_W7					4102
#define DETO_W8					4103


// COB constants
#define ACTIVATION					1	// set or get
#define STANDINGMOVEORDERS			2	// set or get
#define STANDINGFIREORDERS			3	// set or get
	#define HEALTH					4	// get (0-100%)
	#define INBUILDSTANCE			5	// set or get
#define BUSY						6	// set or get (used by misc. special case missions like transport ships)
#define PIECE_XZ					7	// get
#define PIECE_Y						8	// get
#define UNIT_XZ						9	// get
#define UNIT_Y						10	// get
#define UNIT_HEIGHT					11	// get
#define XZ_ATAN						12	// get atan of packed x,z coords
#define XZ_HYPOT					13	// get hypot of packed x,z coords
#define ATAN						14	// get ordinary two-parameter atan
#define HYPOT						15	// get ordinary two-parameter hypot
#define GROUND_HEIGHT				16	// get land height, 0 if below water
#define BUILD_PERCENT_LEFT			17	// get 0 = unit is built and ready, 1-100 = How much is left to build
#define YARD_OPEN					18	// set or get (change which plots we occupy when building opens and closes)
#define BUGGER_OFF					19	// set or get (ask other units to clear the area)
#define ARMORED						20	// set or get
#define IN_WATER					28
#define CURRENT_SPEED				29
#define VETERAN_LEVEL				32
#define ON_ROAD						34
#define MAX_ID						70
#define MY_ID						71
#define UNIT_TEAM					72
#define UNIT_BUILD_PERCENT_LEFT		73
#define UNIT_ALLIED					74
#define MAX_SPEED					75
#define CLOAKED						76
#define WANT_CLOAK					77
#define GROUND_WATER_HEIGHT			78	// get land height, negative if below water
#define UPRIGHT						79	// set or get
#define	POW							80	// get
#define PRINT						81	// get, so multiple args can be passed
#define HEADING						82	// get
#define TARGET_ID					83	// get
#define LAST_ATTACKER_ID			84	// get
#define LOS_RADIUS					85	// set or get
#define AIR_LOS_RADIUS				86	// set or get
#define RADAR_RADIUS				87	// set or get
#define JAMMER_RADIUS				88	// set or get
#define SONAR_RADIUS				89	// set or get
#define SONAR_JAM_RADIUS			90	// set or get
#define SEISMIC_RADIUS				91	// set or get
#define DO_SEISMIC_PING				92	// get
#define CURRENT_FUEL				93	// set or get
#define TRANSPORT_ID				94	// get
#define SHIELD_POWER				95	// set or get
#define STEALTH						96	// set or get
#define CRASHING					97	// set or get, returns whether aircraft isCrashing state
#define COB_ID						100	// get
#define ALPHA_THRESHOLD				103	// set or get
#define SET_WEAPON_UNIT_TARGET		106 // get (fake set)
#define SET_WEAPON_GROUND_TARGET	107 // get (fake set)

#define LUA0						110
#define LUA1						111
#define LUA2						112
#define LUA3						113
#define LUA4						114
#define LUA5						115
#define LUA6						116
#define LUA7						117
#define LUA8						118
#define LUA9						119
#define FLANK_B_MODE				120 // set or get
#define FLANK_B_DIR					121 // set or get, set is through get for multiple args
#define FLANK_B_MOBILITY_ADD		122 // set or get
#define FLANK_B_MAX_DAMAGE			123 // set or get
#define FLANK_B_MIN_DAMAGE			124 // set or get
#define KILL_UNIT					125 // get KILL_UNIT(unitId, SelfDestruct=true, Reclaimed=false)
// NOTE: shared variables use codes [1024 - 5119]

