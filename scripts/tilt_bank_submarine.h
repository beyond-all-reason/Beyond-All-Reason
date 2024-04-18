// Author Beherith (mysterme@gmail.com)
// tilt_bank_submarine.h
// This header defines wether a submarine should tilt up and down on terrian height changes
// And wether it should lean bank left and right when turning
// NOTE: 
//1.  Needs the following, with the defaults shown below. Redefine them if you want to change defaults
/*
#define TB_BASE base 
#define TB_TURNRATE <30.0> 
#define TB_TILT_X <0.1>
#define TB_BANK_Z <0.03> // Do not define this if you dont want banking
#define TB_FRAMES 3 // how frequently you want updates
#include "../tilt_bank_submarine.h"

2. In Create() You must add
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
    #define TB_FRAMES 2
#endif

#define TB_ACCURACY 1000

// Prev and Delta share a variable
static-var TB_prevHeadingDelta, TB_maxSpeed, TB_prevHeightDelta;

TB_Init(){
	TB_maxSpeed = get MAX_SPEED;
	TB_prevHeadingDelta = get HEADING;
	TB_prevHeightDelta = get UNIT_Y;
}

#define START_TILTBANK 	TB_prevHeadingDelta = get HEADING; \
	TB_prevHeightDelta = get UNIT_Y; \
	start-script TiltBank(reversing);

#define STOP_TILTBANK 		TB_prevHeadingDelta = get HEADING;  \
	TB_prevHeightDelta = get UNIT_Y; \
	turn TB_BASE to z-axis <0> speed TB_TURNRATE; \
	turn TB_BASE to x-axis <0> speed TB_TURNRATE; 

TiltBank(reversing)
{
	// Could probably get away with half as many local vars...

	var TB_currHeading;
	var TB_currHeight;

	while(1)
	{
		// get current
		TB_currHeading = get HEADING;
		TB_currHeight = get UNIT_Y;


		// calc deltas
		TB_prevHeightDelta  = (TB_currHeight - TB_prevHeightDelta) / (TB_FRAMES * 256); 
		
		#if TB_CANREVERSE == 1 
			// Reversing isnt very reliable, but can be used here to flip directions
			if (reversing){	TB_prevHeightDelta = -1 * TB_prevHeightDelta;}
		#endif
		turn TB_BASE to x-axis (TB_prevHeightDelta  * TB_TILT_X) speed TB_TURNRATE;
		TB_prevHeightDelta = TB_currHeight;

		// adjust heading with speed
		TB_prevHeadingDelta = (WRAPDELTA(TB_currHeading - TB_prevHeadingDelta) ) / TB_FRAMES;
		TB_prevHeadingDelta = TB_prevHeadingDelta * ((get CURRENT_SPEED) * TB_ACCURACY / (TB_maxSpeed)) / (TB_ACCURACY * 10);
  
		#if TB_CANREVERSE == 1 
			// Reversing isnt very reliable, but can be used here to flip directions
			if (reversing){	TB_prevHeadingDelta = -1 * TB_prevHeadingDelta;	}
		#endif
		
		//dbg(TB_prevHeightDelta, TB_prevHeadingDelta * ( TB_BANK_Z) / <1>, (TB_prevHeightDelta  * TB_TILT_X) / <1>);
		if (TB_prevHeadingDelta != TB_currHeading){
			turn TB_BASE to z-axis TB_prevHeadingDelta * ( TB_BANK_Z) speed TB_TURNRATE;
		}

		TB_prevHeadingDelta = TB_currHeading;
		sleep (32 * TB_FRAMES);
	}
}