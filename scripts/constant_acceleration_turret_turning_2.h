//-------------------------------CONSTANT ACCELERATION TURRET TURNING---------------------------
// MaxVelocity and acceleration are in degrees per frame (not second!)
// Jerk is the minimum velocity of the turret
// A high precision requirement can result in overshoots if desired 
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// The shorthand will be CATT

// Usage:
// 1. Tune the defines in your script, see the defaults below, make sure you set the individual pieces!
// 2. Include this file after piece declarations
// 3. From the AimWeaponX corresponding to the turret to be accelerated, after the signals, 
//    call-script CATT1_Aim(heading, pitch)
// 4. return (1) from AimWeaponX after call-script finishes
// 5. Optionally call-script CATT1_Init() in Create()


#ifndef CATT2_PIECE_Y
	#define CATT2_PIECE_Y aimy
#endif

#ifndef CATT2_PIECE_X
	#define CATT2_PIECE_X aimx1
#endif

#ifdef CATT2_PIECE_X
	#ifndef CATT2_PITCH_SPEED 
		#define CATT2_PITCH_SPEED <90>
	#endif
#endif

#ifndef CATT2_MAX_VELOCITY
	#define CATT2_MAX_VELOCITY <3.0>
#endif

#ifndef CATT2_ACCELERATION
	#define CATT2_ACCELERATION <0.15>
#endif

#ifndef CATT2_JERK
	#define CATT2_JERK <0.5>
#endif

#ifndef CATT2_PRECISION
	#define CATT2_PRECISION <1.2>
#endif

#ifndef CATT2_RESTORE_SPEED
	#define CATT2_RESTORE_SPEED CATT2_MAX_VELOCITY / 3
#endif

#ifndef CATT2_RESTORE_DELAY
	#define CATT2_RESTORE_DELAY 6000
#endif

#ifndef DELTAHEADING
	#define DELTAHEADING(curr, prev) ((curr - prev + 98280) % 65520 - 32760)
#endif

#ifndef WRAPDELTA
	#define WRAPDELTA(ang) (((ang + 98280) % 65520) - 32760)
#endif

static-var CATT2velocity, CATT2position, CATT2gameFrame;

CATT2_Init(){
	CATT2velocity = 0;
	CATT2position = 0;
	CATT2gameFrame = 0;
}

CATT2_Restore() // no need to signal, as threads inherit parents signal masks
{
	sleep CATT2_RESTORE_DELAY;
	
	#ifdef HAS_STUN
		if (Stunned){
			return (0);
		}
	#endif
	
	#ifdef CATT2_PIECE_X
		turn CATT2_PIECE_X to x-axis <0.0> speed CATT2_PITCH_SPEED;
	#endif

	while ( get ABS(CATT2position) > CATT2_RESTORE_SPEED){
		if (CATT2position > 0 ) {
			CATT2position = CATT2position - CATT2_RESTORE_SPEED;
			CATT2velocity = (-1) * CATT2_RESTORE_SPEED;
		}
		else
		{
			CATT2position = CATT2position + CATT2_RESTORE_SPEED;
			CATT2velocity = CATT2_RESTORE_SPEED;
		}
		turn CATT2_PIECE_Y to y-axis CATT2position speed 30 * CATT2_RESTORE_SPEED;
		sleep 30;
	}
	CATT2velocity = 0;
}

CATT2_Aim(heading, pitch){
	/*
	// Set up signals in AimWeaponX(heading, pitch)
	signal SIGNAL_AIM1;
	set-signal-mask SIGNAL_AIM1;
	// Then 
	call-script TurretAccelerationAim1(heading, pitch);
	*/
	
	// Local vars
	var timetozero;
	var deceleratethreshold;
	var delta;

	#ifdef CATT2_PIECE_X
		turn CATT2_PIECE_X to x-axis <0.0> - pitch speed CATT2_PITCH_SPEED;
	#endif
	
	delta = heading - CATT2position;
	
	while( ( get ABS(delta) > CATT2_PRECISION ) OR (get ABS(CATT2velocity) > CATT2_JERK)){
		if (CATT2gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			CATT2gameFrame = get(GAME_FRAME);
	
			//Clamp CATT2position and CATT2delta between <-180>;<180>
			CATT2position 	= WRAPDELTA(CATT2position);
			delta 			= WRAPDELTA(delta);

			//number of frames required to decelerate to 0
			timetozero = get ABS(CATT2velocity) / CATT2_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(CATT2velocity)) - (timetozero * (timetozero - 1) * CATT2_ACCELERATION / 2); 
			
			#ifdef CATT2_DEBUG
				get PRINT ( delta , deceleratethreshold, CATT2velocity, timetozero );
			#endif 

			if (get ABS(delta) <= deceleratethreshold){ //we need to decelerate
				if (CATT2velocity > 0) CATT2velocity = CATT2velocity - CATT2_ACCELERATION;
				else 				   CATT2velocity = CATT2velocity + CATT2_ACCELERATION;
			}	
			else //we need to accelerate
			{
				if (delta > 0) CATT2velocity = get MIN(       CATT2_MAX_VELOCITY, CATT2velocity + CATT2_ACCELERATION); 
				else                CATT2velocity = get MAX((-1) * CATT2_MAX_VELOCITY, CATT2velocity - CATT2_ACCELERATION);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(CATT2velocity) < CATT2_JERK){
				if ((delta >        CATT2_JERK)) CATT2velocity =        CATT2_JERK;
				if ((delta < (-1) * CATT2_JERK)) CATT2velocity = (-1) * CATT2_JERK;
			}
			// Update our position with our velocity
			CATT2position = CATT2position + CATT2velocity; 
			delta = heading - CATT2position ; 	

			// Perform the turn with a NOW, this means that this will be run every frame!
			turn CATT2_PIECE_Y to y-axis CATT2position now;
			//turn CATT2_PIECE_Y to y-axis CATT2position speed 30 * CATT2velocity;
			if ((timetozero < 3) AND (timetozero != 0) AND (get ABS(CATT2velocity) < CATT2_JERK)) {
				CATT2velocity = 0;
				#ifndef CATT_DONTRESTORE
					start-script CATT2_Restore();
				#endif
				return;
			}
		}
		sleep 32;
	}
	CATT2velocity = 0;
	#ifndef CATT_DONTRESTORE
		start-script CATT2_Restore();
	#endif
}

#undef CATT_INDEX