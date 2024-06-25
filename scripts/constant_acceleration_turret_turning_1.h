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


#ifndef CATT1_PIECE_Y
	#define CATT1_PIECE_Y aimy
#endif

#ifndef CATT1_PIECE_X
	#define CATT1_PIECE_X aimx1
#endif

#ifdef CATT1_PIECE_X
	#ifndef CATT1_PITCH_SPEED 
		#define CATT1_PITCH_SPEED <90>
	#endif
#endif

#ifndef CATT1_MAX_VELOCITY
	#define CATT1_MAX_VELOCITY <3.0>
#endif

#ifndef CATT1_ACCELERATION
	#define CATT1_ACCELERATION <0.15>
#endif

#ifndef CATT1_JERK
	#define CATT1_JERK <0.5>
#endif

#ifndef CATT1_PRECISION
	#define CATT1_PRECISION <1.2>
#endif

#ifndef CATT1_RESTORE_SPEED
	#define CATT1_RESTORE_SPEED CATT1_MAX_VELOCITY / 3
#endif

#ifndef CATT1_RESTORE_DELAY
	#define CATT1_RESTORE_DELAY 6000
#endif

#ifndef DELTAHEADING
	#define DELTAHEADING(curr, prev) ((curr - prev + 98280) % 65520 - 32760)
#endif

#ifndef WRAPDELTA
	#define WRAPDELTA(ang) (((ang + 98280) % 65520) - 32760)
#endif

static-var CATT1velocity, CATT1position, CATT1gameFrame;

CATT1_Init(){
	CATT1velocity = 0;
	CATT1position = 0;
	CATT1gameFrame = 0;
}

CATT1_Restore() // no need to signal, as threads inherit parents signal masks
{
	sleep CATT1_RESTORE_DELAY;
	
	#ifdef HAS_STUN
		if (Stunned){
			return (0);
		}
	#endif
	
	#ifdef CATT1_PIECE_X
		turn CATT1_PIECE_X to x-axis <0.0> speed CATT1_PITCH_SPEED;
	#endif

	while ( get ABS(CATT1position) > CATT1_RESTORE_SPEED){
		if (CATT1position > 0 ) {
			CATT1position = CATT1position - CATT1_RESTORE_SPEED;
			CATT1velocity = (-1) * CATT1_RESTORE_SPEED;
		}
		else
		{
			CATT1position = CATT1position + CATT1_RESTORE_SPEED;
			CATT1velocity = CATT1_RESTORE_SPEED;
		}
		turn CATT1_PIECE_Y to y-axis CATT1position speed 30 * CATT1_RESTORE_SPEED;
		sleep 30;
	}
	CATT1velocity = 0;
}

CATT1_Aim(heading, pitch){
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

	#ifdef CATT1_PIECE_X
		turn CATT1_PIECE_X to x-axis <0.0> - pitch speed CATT1_PITCH_SPEED;
	#endif
	
	delta = heading - CATT1position;
	
	while( ( get ABS(delta) > CATT1_PRECISION ) OR (get ABS(CATT1velocity) > CATT1_JERK)){
		if (CATT1gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			CATT1gameFrame = get(GAME_FRAME);
	
			//Clamp CATT1position and CATT1delta between <-180>;<180>
			CATT1position 	= WRAPDELTA(CATT1position);
			delta 			= WRAPDELTA(delta);

			//number of frames required to decelerate to 0
			timetozero = get ABS(CATT1velocity) / CATT1_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(CATT1velocity)) - (timetozero * (timetozero - 1) * CATT1_ACCELERATION / 2); 
			
			#ifdef CATT1_DEBUG
				get PRINT ( delta , deceleratethreshold, CATT1velocity, timetozero );
			#endif 

			if (get ABS(delta) <= deceleratethreshold){ //we need to decelerate
				if (CATT1velocity > 0) CATT1velocity = CATT1velocity - CATT1_ACCELERATION;
				else 				   CATT1velocity = CATT1velocity + CATT1_ACCELERATION;
			}	
			else //we need to accelerate
			{
				if (delta > 0) CATT1velocity = get MIN(       CATT1_MAX_VELOCITY, CATT1velocity + CATT1_ACCELERATION); 
				else                CATT1velocity = get MAX((-1) * CATT1_MAX_VELOCITY, CATT1velocity - CATT1_ACCELERATION);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(CATT1velocity) < CATT1_JERK){
				if ((delta >        CATT1_JERK)) CATT1velocity =        CATT1_JERK;
				if ((delta < (-1) * CATT1_JERK)) CATT1velocity = (-1) * CATT1_JERK;
			}
			// Update our position with our velocity
			CATT1position = CATT1position + CATT1velocity; 
			delta = heading - CATT1position ; 	

			// Perform the turn with a NOW, this means that this will be run every frame!
			turn CATT1_PIECE_Y to y-axis CATT1position now;
			//turn CATT1_PIECE_Y to y-axis CATT1position speed 30 * CATT1velocity;
		}
		sleep 32;
	}
	CATT1velocity = 0;
	#ifndef CATT_DONTRESTORE
		start-script CATT1_Restore();
	#endif
}

#undef CATT_INDEX