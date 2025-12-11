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

// Note: 
// When a unit cannot aim at a valid target (blocked by friendlies)
// then ALL AimWeapon() threads by the engine are terminated.
// The side effect that manifests here, is that since we call-script CATT1_Aim() from AimWeapon,
// we are still technically in the AimWeapon thread, and the CATT1_Aim() call. 
// A workaround is to spawn start-script CATT1_Aim(pitch,heading); from AimWeaponX with a signal mask of zero
// This ensures that the CATT1_Aim() thread is not killed when the AimWeapon thread is killed.
// Then we have to manually set the signal mask for CATT_Aim() to the desired value.

// The piece that will aim left-right
#ifndef CATT1_PIECE_Y
	#define CATT1_PIECE_Y aimy
#endif

// The piece that will aim up-down
#ifndef CATT1_PIECE_X
	//#define CATT1_PIECE_X aimx1
#endif

// Specify how fast to move up-down
#ifdef CATT1_PIECE_X
	#ifndef CATT1_PITCH_SPEED 
		#define CATT1_PITCH_SPEED <90>
	#endif
#endif

// Max left-right turn speed (per frame)
#ifndef CATT1_MAX_VELOCITY
	#define CATT1_MAX_VELOCITY <3.0>
#endif

// Max turning acceleration (per frame)
#ifndef CATT1_ACCELERATION
	#define CATT1_ACCELERATION <0.15>
#endif

// Starting velocity on turning (per frame)
#ifndef CATT1_JERK
	#define CATT1_JERK <0.5>
#endif

// Desired angular correctness
#ifndef CATT1_PRECISION
	#define CATT1_PRECISION <1.2>
#endif

// Left-right restore speed, default 1/3rd
#ifndef CATT1_RESTORE_SPEED
	#define CATT1_RESTORE_SPEED CATT1_MAX_VELOCITY / 3
#endif

// Optional 
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
	var temp;
	var pastChassisHeading;
	pastChassisHeading = get HEADING;

	#ifdef CATT1_PIECE_X
		turn CATT1_PIECE_X to x-axis <0.0> - pitch speed CATT1_PITCH_SPEED;
	#endif

	delta = WRAPDELTA(heading - CATT1position);

	while(ABSOLUTE_GREATER_THAN(delta, CATT1_PRECISION) OR ABSOLUTE_GREATER_THAN(CATT1velocity,  CATT1_JERK)){
		
	//while( ( get ABS(delta) > CATT1_PRECISION ) OR (get ABS(CATT1velocity) > CATT1_JERK)){
		if (CATT1gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			CATT1gameFrame = get(GAME_FRAME);


			//Clamp CATT1position and CATT1delta between <-180>;<180>
			CATT1position 	= WRAPDELTA(CATT1position);
			delta 			= WRAPDELTA(delta);

			//number of frames required to decelerate to 0
			timetozero = get ABS(CATT1velocity) / CATT1_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive' ensured by +1
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(CATT1velocity)) - (timetozero * (timetozero - 1) * CATT1_ACCELERATION / 2) + 1; 
			
			#ifdef CATT1_DEBUG
				get PRINT ( delta , deceleratethreshold, CATT1velocity, timetozero );
			#endif 
			
			if (ABSOLUTE_LESS_THAN(delta, deceleratethreshold)){ //we need to decelerate
				if (CATT1velocity > 0) CATT1velocity = CATT1velocity - CATT1_ACCELERATION;
				else 				   CATT1velocity = CATT1velocity + CATT1_ACCELERATION;

				// account for unit chassis turning, lets CATT units fire while turning.
				// if turret has decelerated to slower than chassis turn rate, then we can return and let AimWeapon return true.
				if (get ABS((get HEADING) - pastChassisHeading) > 0) // ABSOLUTE_LESS_THAN behaves bad if the second value is zero
				{
					if (ABSOLUTE_LESS_THAN(CATT1velocity, WRAPDELTA((get HEADING) - pastChassisHeading)))
					{
						// undo the deacceleration, then just tell the turret to continue turning at that slightly faster than chassis rate. 
						// and give a goal heading assuming the chassis will continue turing for 6 frames (based on 5-6 frame reaim time for CATT units)
						// sudden stops and not deacceleration may occur, but will be masked by the bulk unit turning. 
						// Ideally, the chassis turning would be tracked *after* the return to the AimWeapon function, but that would require a separately threaded CATT implementation
						if (CATT1velocity > 0) CATT1velocity = CATT1velocity + CATT1_ACCELERATION;
						else 				   CATT1velocity = CATT1velocity - CATT1_ACCELERATION;
						turn CATT1_PIECE_Y to y-axis (heading - 6*WRAPDELTA((get HEADING) - pastChassisHeading)) speed 30 * CATT1velocity;

						#ifndef CATT_DONTRESTORE
							start-script CATT1_Restore();
						#endif
						return;
					}
				}
			}	
			else //we need to accelerate
			{
				if (delta > 0) CATT1velocity = get MIN(       CATT1_MAX_VELOCITY, CATT1velocity + CATT1_ACCELERATION); 
				else           CATT1velocity = get MAX((-1) * CATT1_MAX_VELOCITY, CATT1velocity - CATT1_ACCELERATION);
			}
			pastChassisHeading = get HEADING; //track chassis heading
			
			//Apply jerk at very low velocities
			if (ABSOLUTE_LESS_THAN(CATT1velocity,  CATT1_JERK)){
				if ((delta >        CATT1_JERK)) CATT1velocity =        CATT1_JERK;
				if ((delta < (-1) * CATT1_JERK)) CATT1velocity = (-1) * CATT1_JERK;
			}

			// If we would need to move less than the delta, then just move the delta?

			// Update our position with our velocity
			CATT1position = CATT1position + CATT1velocity; 
			delta = heading - CATT1position ; 	

			// Perform the turn with a NOW, this means that this will be run every frame!
			//turn CATT1_PIECE_Y to y-axis CATT1position now;

			// Needs to use velocity, because if we use NOW, then any previous turn speed command wont be overridden!
			turn CATT1_PIECE_Y to y-axis CATT1position speed 30 * CATT1velocity;

			if ((timetozero < 3) AND (timetozero != 0) AND (get ABS(CATT1velocity) < CATT1_JERK)) {
				CATT1velocity = 0;
				#ifndef CATT_DONTRESTORE
					start-script CATT1_Restore();
				#endif
				return;}
			}
		sleep 32;
	}
	CATT1velocity = 0;
	#ifndef CATT_DONTRESTORE
		start-script CATT1_Restore();
	#endif
}

#undef CATT_INDEX

/*
// Blocking vs non-blocking AimWeapons
// also ensure once per frame calls



CalledAim(heading,pitch)


AimWeaponX(heading, pitch){
	signal SIGNAL_AIM1;
	set-signal-mask SIGNAL_AIM1;
	while (TRUE){

		if (ANGLE_DIFFERENCE_LESS_THAN(CATT1position - heading, CATT1_PRECISION)){
			return (1);
		}
		else{
			sleep 30;
		}
	}
}


*/