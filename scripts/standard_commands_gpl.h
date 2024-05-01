// Argh's Standard Commands Script
// This script is released under the terms of the GNU license.
// It may be used by anyone, for any purpose, so long as you adhere to the GNU license.
// This script will not work with TAK compiling options, as I do not understand TAK scripts well enough to garantee that they will function as advertised.
#ifndef STANDARD_COMMANDS_GPL_H_
#define STANDARD_COMMANDS_GPL_H_
//
// Vector-based special effects
//
#define SFXTYPE_VTOL			1
#define SFXTYPE_THRUST			2
#define	SFXTYPE_WAKE1			3
#define	SFXTYPE_WAKE2			4
#define	SFXTYPE_REVERSEWAKE1		5
#define	SFXTYPE_REVERSEWAKE2		6
//
// Point-based (piece origin) special effects
//
#define SFXTYPE_POINTBASED	256
#define SFXTYPE_WHITESMOKE	(SFXTYPE_POINTBASED | 1)
#define SFXTYPE_BLACKSMOKE	(SFXTYPE_POINTBASED | 2)
#define SFXTYPE_SUBBUBBLES	256 | 3
//
#define SHATTER			1	// The piece will shatter instead of remaining whole
#define EXPLODE_ON_HIT		2	// The piece will explode when it hits the ground
#define FALL			4	// The piece will fall due to gravity instead of just flying off
#define SMOKE			8	// A smoke trail will follow the piece through the air
#define FIRE			16	// A fire trail will follow the piece through the air
#define BITMAPONLY		32	// The piece will just show the default explosion bitmap.
#define NOCEGTRAIL		64	// Disables the cegtrail for the specific piece (defined in the unit fbi)
//
// Bitmap Explosion Types
//
#define BITMAP_GPL			10000001
//
// Indices for set/get value
#define ACTIVATION		1	// set or get
#define STANDINGMOVEORDERS	2	// set or get
#define STANDINGFIREORDERS	3	// set or get
#define HEALTH			4	// get (0-100%)
#define INBUILDSTANCE		5	// set or get
#define BUSY			6	// set or get (used by misc. special case missions like transport ships)
#define PIECE_XZ			7	// get
#define PIECE_Y			8	// get
#define UNIT_XZ			9	// get
#define UNIT_Y			10	// get
#define UNIT_HEIGHT		11	// get
#define XZ_ATAN			12	// get atan of packed x,z coords
#define XZ_HYPOT			13	// get hypot of packed x,z coords
#define ATAN			14	// get ordinary two-parameter atan
#define HYPOT			15	// get ordinary two-parameter hypot
#define GROUND_HEIGHT		16	// get
#define BUILD_PERCENT_LEFT		17	// get 0 = unit is built and ready, 1-100 = How much is left to build
#define YARD_OPEN			18	// set or get (change which plots we occupy when building opens and closes)
#define BUGGER_OFF		19	// set or get (ask other units to clear the area)
#define ARMORED			20	// SET or GET.  Turns on the Armored state.
#define IN_WATER   			28	// GET only.  If unit position Y less than 0, then the unit must be in water (0 Y is the water level).
#define CURRENT_SPEED  		29	// SET only, if I'm reading the code right.  Gives us a new speed for the next frame ONLY.
#define VETERAN_LEVEL  		32	// SET or GET.  Can make units super-accurate, or keep them inaccurate.
#define MAX_ID			70	// GET only.  Returns maximum number of units - 1
#define MY_ID              		71	// GET only.  Returns ID of current unit
#define UNIT_TEAM	         		72	// GET only.  Returns team of unit given with parameter
#define UNIT_BUILD_PERCENT_LEFT	73	// GET only.  BUILD_PERCENT_LEFT, but comes with a unit parameter.
#define UNIT_ALLIED		74	// GET only.  Is this unit allied to the unit of the current COB script? 1=allied, 0=not allied
#define MAX_SPEED 			75	// SET only.  Alters MaxVelocity for the given unit.
#define POW			80
#define PRINT			81
#define HEADING			82
//
#endif // STANDARD_COMMANDS_GPL_H_