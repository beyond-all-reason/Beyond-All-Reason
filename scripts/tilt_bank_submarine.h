// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
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

Additional TODO:
- [ ] It would be very nice if the turn speed was abs-maxed to ensure smoothness
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

// If the unit can reverse
#ifndef TB_CANREVERSE
    #define TB_CANREVERSE 0
#endif

// How often to update
#ifndef TB_FRAMES
    #define TB_FRAMES 2
#endif

#ifdef TB_WAKE_PIECE
	// Period of updates 
	#ifndef TB_WAKE_PERIOD
		#define TB_WAKE_PERIOD 8
	#endif

	#ifndef TB_WAKE_BUBBLES 
		#define TB_WAKE_BUBBLES 259
	#endif
#endif

#define TB_ACCURACY 1000

// Prev and Delta share a variable
static-var TB_prevHeadingDelta, TB_maxSpeed, TB_prevHeightDelta, TB_currHeadingORHeight;

TB_Init(){
	TB_maxSpeed = get MAX(20000, get MAX_SPEED); // Make sure it is not zero in case we are stunned on create
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
	#ifdef TB_WAKE_PIECE
		var tb_frame;
		tb_frame = 0;
	#endif
	while(1)
	{
		// Get unit hieght
		TB_currHeadingORHeight = get UNIT_Y;

		// calc deltas
		TB_prevHeightDelta  = (TB_currHeadingORHeight - TB_prevHeightDelta) / (TB_FRAMES * 1024); 
		
		#if TB_CANREVERSE == 1 
			// Reversing isnt very reliable, but can be used here to flip directions
			if (reversing){	TB_prevHeightDelta = -1 * TB_prevHeightDelta;}
		#endif
		// Tilt the unit if new target differs from old
		if (TB_prevHeightDelta != TB_currHeadingORHeight){
			turn TB_BASE to x-axis (TB_prevHeightDelta  * TB_TILT_X) speed TB_TURNRATE;
			//dbg(TB_prevHeightDelta);
			// Store the value
			TB_prevHeightDelta = TB_currHeadingORHeight;
		}

		// get current heading
		TB_currHeadingORHeight = get HEADING;
		// calculate the delta
		TB_prevHeadingDelta = (WRAPDELTA(TB_currHeadingORHeight - TB_prevHeadingDelta) ) / TB_FRAMES;
		// modulate heading with speed
		TB_prevHeadingDelta = TB_prevHeadingDelta * ((get CURRENT_SPEED) * TB_ACCURACY / (TB_maxSpeed)) / (TB_ACCURACY * 10);
  
		#if TB_CANREVERSE == 1 
			// Reversing isnt very reliable, but can be used here to flip directions
			if (reversing){	TB_prevHeadingDelta = -1 * TB_prevHeadingDelta;	}
		#endif
		
		//Bank the unit if its turning
		if (TB_prevHeadingDelta != TB_currHeadingORHeight){

			turn TB_BASE to z-axis TB_prevHeadingDelta * ( TB_BANK_Z) speed TB_TURNRATE;
			TB_prevHeadingDelta = TB_currHeadingORHeight;
		}

		// Emit bubbles and wake from back of sub
		#ifdef TB_WAKE_PIECE
			tb_frame = (tb_frame + 1 ) % TB_WAKE_PERIOD;

			if (tb_frame == 0){
				emit-sfx TB_WAKE_BUBBLES from TB_WAKE_PIECE;
			}

			if (tb_frame == TB_WAKE_PERIOD/2){
				#ifdef TB_WAKE_PIECE2
					emit-sfx TB_WAKE_BUBBLES from TB_WAKE_PIECE2;
				#else
					emit-sfx TB_WAKE_BUBBLES from TB_WAKE_PIECE;
				#endif
				#ifdef TB_WAKE_FOAM
					emit-sfx TB_WAKE_FOAM from TB_WAKE_PIECE;
				#endif
			}
		#endif

		sleep (32 * TB_FRAMES);
	}
}