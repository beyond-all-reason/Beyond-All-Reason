/* SmokeUnit.h -- Process unit smoke when damaged */

#ifndef SMOKE_H_
#define SMOKE_H_

#include "SFXtype.h"
#include "EXPtype.h"

// Figure out how many smoking pieces are defined

#ifdef SMOKEPIECE4
 #define NUM_SMOKE_PIECES 4
#else
 #ifdef SMOKEPIECE3
  #define NUM_SMOKE_PIECES 3
 #else
  #ifdef SMOKEPIECE2
   #define NUM_SMOKE_PIECES 2
  #else
   #define NUM_SMOKE_PIECES 1
   #ifndef SMOKEPIECE1
    #define SMOKEPIECE1 SMOKEPIECE
   #endif
  #endif
 #endif
#endif


SmokeUnit()
{
	var healthpercent;
	var sleeptime;
	var smoketype;

#if NUM_SMOKE_PIECES > 1
	var choice;
#endif

	// Wait until the unit is actually built
	while (get BUILD_PERCENT_LEFT)
	{
		sleep 400;
	}

	// Smoke loop
	while (TRUE)
	{
		// How is the unit doing?
		healthpercent = get HEALTH;

		if (healthpercent < 66)
		{
			// Emit a puff of smoke

			smoketype = SFXTYPE_BLACKSMOKE;

			if (rand( 1, 66 ) < healthpercent)
			{
				smoketype = SFXTYPE_WHITESMOKE;
			}

		 	// Figure out which piece the smoke will emit from, and spit it out

#if NUM_SMOKE_PIECES == 1
			emit-sfx smoketype from SMOKEPIECE1;
#else
			choice = rand( 1, NUM_SMOKE_PIECES );

			if (choice == 1)
			{	emit-sfx smoketype from SMOKEPIECE1; }
			if (choice == 2)
			{	emit-sfx smoketype from SMOKEPIECE2; }
 #if NUM_SMOKE_PIECES >= 3
			if (choice == 3)
			{	emit-sfx smoketype from SMOKEPIECE3; }
  #if NUM_SMOKE_PIECES >= 4
			if (choice == 4)
			{	emit-sfx smoketype from SMOKEPIECE4; }
  #endif
 #endif
#endif
		}

		// Delay between puffs

		sleeptime = healthpercent * 50;
		if (sleeptime < 200)
		{
			sleeptime = 200;	// Fastest rate is five times per second
		}

		sleep sleeptime;
	}
}


// Clean up pre-processor
#undef NUM_SMOKE_PIECES

#endif