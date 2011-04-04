/*
** SFXtype.h -- Special Effects Type information for scripts
**
** Copyright 1997 Cavedog Entertainment
*/

#ifndef __SFXTYPE_H_
#define __SFXTYPE_H_

/*
Special Effect Particles referenced in the scripting language
with the command "emit-sfx".  This file is included by any
scripts that use the command, as well as TAObjScr.cpp in the game,
so it can start the proper effect.
*/

// IMPORTANT:	If you change these defines, copy the file to
//				v:\totala\cdimage\scripts so the scripts have
//				access to the proper data, and recompile them.


// Vector-based special effects

#define SFXTYPE_VTOL			0
#define SFXTYPE_THRUST			1
#define	SFXTYPE_WAKE1			2
#define	SFXTYPE_WAKE2			3
#define	SFXTYPE_REVERSEWAKE1	4
#define	SFXTYPE_REVERSEWAKE2	5



// Point-based (piece origin) special effects

#define SFXTYPE_POINTBASED	256

#define SFXTYPE_WHITESMOKE	(SFXTYPE_POINTBASED | 1)
#define SFXTYPE_BLACKSMOKE	(SFXTYPE_POINTBASED | 2)
#define SFXTYPE_SUBBUBBLES	(SFXTYPE_POINTBASED | 3)

#endif