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


#ifndef CATT3_PIECE_Y
	#define CATT3_PIECE_Y aimy
#endif

#ifndef CATT3_PIECE_X
	#define CATT3_PIECE_X aimx1
#endif

#ifdef CATT3_PIECE_X
	#ifndef CATT3_PITCH_SPEED 
		#define CATT3_PITCH_SPEED <90>
	#endif
#endif

#ifndef CATT3_MAX_VELOCITY
	#define CATT3_MAX_VELOCITY <3.0>
#endif

#ifndef CATT3_ACCELERATION
	#define CATT3_ACCELERATION <0.15>
#endif

#ifndef CATT3_JERK
	#define CATT3_JERK <0.5>
#endif

#ifndef CATT3_PRECISION
	#define CATT3_PRECISION <1.2>
#endif

#ifndef CATT3_RESTORE_SPEED
	#define CATT3_RESTORE_SPEED CATT3_MAX_VELOCITY / 3
#endif

#ifndef CATT3_RESTORE_DELAY
	#define CATT3_RESTORE_DELAY 6000
#endif

#ifndef DELTAHEADING
	#define DELTAHEADING(curr, prev) ((curr - prev + 98280) % 65520 - 32760)
#endif

#ifndef WRAPDELTA
	#define WRAPDELTA(ang) (((ang + 98280) % 65520) - 32760)
#endif

static-var CATT3velocity, CATT3position, CATT3gameFrame;

CATT3_Init(){
	CATT3velocity = 0;
	CATT3position = 0;
	CATT3gameFrame = 0;
}

CATT3_Restore() // no need to signal, as threads inherit parents signal masks
{
	sleep CATT3_RESTORE_DELAY;
	
	#ifdef HAS_STUN
		if (Stunned){
			return (0);
		}
	#endif
	
	#ifdef CATT3_PIECE_X
		turn CATT3_PIECE_X to x-axis <0.0> speed CATT3_PITCH_SPEED;
	#endif

	while ( get ABS(CATT3position) > CATT3_RESTORE_SPEED){
		if (CATT3position > 0 ) {
			CATT3position = CATT3position - CATT3_RESTORE_SPEED;
			CATT3velocity = (-1) * CATT3_RESTORE_SPEED;
		}
		else
		{
			CATT3position = CATT3position + CATT3_RESTORE_SPEED;
			CATT3velocity = CATT3_RESTORE_SPEED;
		}
		turn CATT3_PIECE_Y to y-axis CATT3position speed 30 * CATT3_RESTORE_SPEED;
		sleep 30;
	}
	CATT3velocity = 0;
}

CATT3_Aim(heading, pitch){
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

	#ifdef CATT3_PIECE_X
		turn CATT3_PIECE_X to x-axis <0.0> - pitch speed CATT3_PITCH_SPEED;
	#endif
	
	delta = heading - CATT3position;
	
	while( ( get ABS(delta) > CATT3_PRECISION ) OR (get ABS(CATT3velocity) > CATT3_JERK)){
		if (CATT3gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			CATT3gameFrame = get(GAME_FRAME);
	
			//Clamp CATT3position and CATT3delta between <-180>;<180>
			CATT3position 	= WRAPDELTA(CATT3position);
			delta 			= WRAPDELTA(delta);

			//number of frames required to decelerate to 0
			timetozero = get ABS(CATT3velocity) / CATT3_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(CATT3velocity)) - (timetozero * (timetozero - 1) * CATT3_ACCELERATION / 2); 
			
			#ifdef CATT3_DEBUG
				get PRINT ( delta , deceleratethreshold, CATT3velocity, timetozero );
			#endif 

			if (get ABS(delta) <= deceleratethreshold){ //we need to decelerate
				if (CATT3velocity > 0) CATT3velocity = CATT3velocity - CATT3_ACCELERATION;
				else 				   CATT3velocity = CATT3velocity + CATT3_ACCELERATION;
			}	
			else //we need to accelerate
			{
				if (delta > 0) CATT3velocity = get MIN(       CATT3_MAX_VELOCITY, CATT3velocity + CATT3_ACCELERATION); 
				else                CATT3velocity = get MAX((-1) * CATT3_MAX_VELOCITY, CATT3velocity - CATT3_ACCELERATION);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(CATT3velocity) < CATT3_JERK){
				if ((delta >        CATT3_JERK)) CATT3velocity =        CATT3_JERK;
				if ((delta < (-1) * CATT3_JERK)) CATT3velocity = (-1) * CATT3_JERK;
			}
			// Update our position with our velocity
			CATT3position = CATT3position + CATT3velocity; 
			delta = heading - CATT3position ; 	

			// Perform the turn with a NOW, this means that this will be run every frame!
			turn CATT3_PIECE_Y to y-axis CATT3position now;
			//turn CATT3_PIECE_Y to y-axis CATT3position speed 30 * CATT3velocity;
			if ((timetozero < 3) AND (timetozero != 0) AND (get ABS(CATT3velocity) < CATT3_JERK)) {
				CATT3velocity = 0;
				#ifndef CATT_DONTRESTORE
					start-script CATT3_Restore();
				#endif
				return;
			}
		}
		sleep 32;
	}
	CATT3velocity = 0;
	#ifndef CATT_DONTRESTORE
		start-script CATT3_Restore();
	#endif
}

#undef CATT_INDEX