// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// tilt_bank_mobileunit.h
// This header defines wether a unit shoud tilt forward and backward when accelerating
// And wether it should lean bank left and right when turning
// NOTE: 
//1.  Needs the following, with the defaults shown below. Redefine them if you want to change defaults
/*
#define TB_BASE base 
#define TB_TURNRATE <30.0> 
#define TB_TILT_X <0.1>
#define TB_BANK_Z <0.03> // Do not define this if you dont want banking
#define TB_FRAMES 3 // how frequently you want updates
#include "../tilt_bank_mobileunit.h"

2. In Create() You must add before SLEEP_UNTIL_UNITFINISHED;
call-script TB_Init(); 

3. To the end of StartMoving you must add START_TILTBANK
StartMoving(reversing)
{
	signal SIGNAL_MOVE;
	set-signal-mask SIGNAL_MOVE;

	START_TILTBANK;
}


4. To the end of StopMoving You must add STOP_TILTBANK 
StopMoving()
{
	signal SIGNAL_MOVE;

	STOP_TILTBANK;
}


Perf Note:
About 80% of turns and moves executed here are actually non-empty turns. So if-gating them might not even be worth it.
*/

#ifndef WRAPDELTA
	#define WRAPDELTA(angle) (((angle + 98280) % 65520) - 32760)
#endif

// Which piece to tilt and bank
#ifndef TB_BASE
    #define TB_BASE base
#endif

// How quickly to tilt and bank
#ifndef TB_TURNRATE
    #define TB_TURNRATE <30>
#endif

// How much effect acceleration has on forward-backward tilting
#ifndef TB_TILT_X
    #define TB_TILT_X <0.1>
#endif

#ifndef TB_CANREVERSE
    #define TB_CANREVERSE 0
#endif


#ifndef TB_FRAMES
    #define TB_FRAMES 3
#endif

#define TB_ACCURACY 1000

#ifdef TB_BANK_Z
	
	static-var TB_prevHeading, TB_prevSpeed, TB_maxSpeed;

	TB_Init(){
		TB_maxSpeed = get MAX(10000, get MAX_SPEED); // Make sure it is not zero in case we are stunned on create
		TB_prevHeading = get HEADING;
		TB_prevSpeed = 0;
	}

	#define START_TILTBANK 	TB_prevHeading = get HEADING; \
	TB_prevSpeed = 0; \
	start-script TiltBank(reversing);

	#define STOP_TILTBANK 		TB_prevHeading = get HEADING;  \
		TB_prevSpeed = 0; \
		turn TB_BASE to z-axis <0> speed TB_TURNRATE; \
		turn TB_BASE to x-axis <0> speed TB_TURNRATE; 


#else
	static-var TB_prevSpeed, TB_maxSpeed;

	TB_Init(){
		TB_maxSpeed = get MAX(10000, get MAX_SPEED); // Make sure it is not zero in case we are stunned on create
		TB_prevSpeed = 0;
	}

	#define START_TILTBANK 	TB_prevSpeed = 0; \
		start-script TiltBank(reversing);

	#define STOP_TILTBANK	TB_prevSpeed = 0; \
		turn TB_BASE to x-axis <0> speed TB_TURNRATE; 
#endif



TiltBank(reversing)
{
	// Could probably get away with half as many local vars...
	var TB_currSpeed;
	var deltaSpeed;

	#ifdef TB_BANK_Z
		var TB_currHeading;
		var deltaHeading;
	#endif
	#ifdef PROFILE
		var nt;
		nt = 0;
		var nn;
		nn = 0;
	#endif
	while(1)
	{
		// get current
		TB_currSpeed   = (get CURRENT_SPEED) * TB_ACCURACY / (TB_maxSpeed);
		
		#ifdef TB_BANK_Z
			TB_currHeading = get HEADING;
		#endif

		// calc deltas
		deltaSpeed   = (TB_currSpeed - TB_prevSpeed) / TB_FRAMES;
		
		// Less braking effect:
		if (deltaSpeed < 0) deltaSpeed = deltaSpeed/2;

		#ifdef TB_BANK_Z
			// adjust heading with speed
			deltaHeading = (WRAPDELTA(TB_currHeading - TB_prevHeading) ) / TB_FRAMES;
			deltaHeading = deltaHeading * TB_currSpeed / (TB_ACCURACY * 10);
        #endif
		
		#if TB_CANREVERSE == 1 
			// Reversing isnt very reliable, but can be used here to flip directions
			if (reversing){
				deltaHeading = -1 * deltaHeading;
				deltaSpeed   = -1 * deltaSpeed;
			}
		#endif
		//dbg(deltaSpeed, deltaHeading, reversing);
		if (TB_prevSpeed != TB_currSpeed){
			turn TB_BASE to x-axis deltaSpeed   * (-1 * TB_TILT_X) speed TB_TURNRATE;
			TB_prevSpeed = TB_currSpeed;
			
		#ifdef PROFILE
			nt = nt + 1;
		#endif
		}
		
		#ifdef TB_BANK_Z
			if (TB_prevHeading != TB_currHeading){
				turn TB_BASE to z-axis deltaHeading * (-1 * TB_BANK_Z) speed TB_TURNRATE;
				TB_prevHeading = TB_currHeading;
			
			#ifdef PROFILE
				nt = nt + 1;
			#endif
			}
		#endif
		
		#ifdef PROFILE
		nn = nn + 2;
		if (nn % 100 == 0){
			get PRINT((nt*100)/nn);
		}
		#endif
		//move TB_BASE to y-axis ((tilt* tilt) * [0.005]) now;
		 
		
		sleep (32 * TB_FRAMES);
	}
}