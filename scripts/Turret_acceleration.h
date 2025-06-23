//-------------------------------CONSTANT ACCELERATION TURRET TURNING---------------------------
// MaxVelocity and acceleration are in degrees per frame (not second!)
// Jerk is the minimum velocity of the turret
// A high precision requirement can result in overshoots if desired 
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.

// Usage:
// 1. Tune the defines in your script, see the defaults below, make sure you set the individual pieces!
// 2. Include this file after piece declarations
// 3. From the AimWeaponX corresponding to the turret to be accelerated:
//    call-script TurretAccelerationAim1(heading, pitch)
// 4. return (1) from AimWeaponX after call-script finishes


#define AIMY1_PIECE_Y aimy1
//#define AIMY1_PIECE_X aimx1

#ifdef AIMY1_PIECE_X
	#ifndef AIMY1_PITCH_SPEED 
		#define AIMY1_PITCH_SPEED <150>
	#endif
#endif

#ifndef MAX_AIMY1_VELOCITY
	#define MAX_AIMY1_VELOCITY <3.0>
#endif

#ifndef AIMY1_ACCELERATION
	#define AIMY1_ACCELERATION <0.15>
#endif

#ifndef AIMY1_JERK
	#define AIMY1_JERK <0.5>
#endif

#ifndef AIMY1_PRECISION
	#define AIMY1_PRECISION <1.2>
#endif

#ifndef AIMY1_RESTORE_SPEED
	#define AIMY1_RESTORE_SPEED <1.0>
#endif

#ifndef AIMY1_RESTORE_DELAY
	#define AIMY1_RESTORE_DELAY 6000
#endif

static-var aimy1delta, timetozero, deceleratethreshold;
static-var aimy1velocity, aimy1target, aimy1position, gameFrame;

RestoreBody1() // no need to signal, as threads inherit parents signal masks
{
	sleep AIMY1_RESTORE_DELAY;
	
	#ifdef AIMY1_PIECE_X
		turn AIMY1_PIECE_X to x-axis <0.0> speed AIMY1_PITCH_SPEED;
	#endif

	while ( get ABS(aimy1position) > AIMY1_RESTORE_SPEED){
		if (aimy1position > 0 ) {
			aimy1position = aimy1position - AIMY1_RESTORE_SPEED;
			aimy1velocity = (-1) * AIMY1_RESTORE_SPEED;
		}
		else
		{
			aimy1position = aimy1position + AIMY1_RESTORE_SPEED;
			aimy1velocity = AIMY1_RESTORE_SPEED;
		}
		turn AIMY1_PIECE_Y to y-axis aimy1position speed 30 * AIMY1_RESTORE_SPEED;
		sleep 30;
	}
	aimy1velocity = 0;
}

TurretAccelerationAim1(heading, pitch){
	/*
	// Set up signals in AimWeaponX(heading, pitch)
	signal SIGNAL_AIM1;
	set-signal-mask SIGNAL_AIM1;
	// Then 
	call-script TurretAccelerationAim1(heading, pitch);
	*/

	#ifdef AIMY1_PIECE_X
		turn AIMY1_PIECE_X to x-axis <0.0> - pitch speed AIMY1_PITCH_SPEED;
	#endif
	
	aimy1target = heading;
	aimy1delta = aimy1target - aimy1position;
	
	while( ( get ABS(aimy1delta) > AIMY1_PRECISION ) OR (get ABS(aimy1velocity) > AIMY1_JERK)){
		if (gameFrame != get(GAME_FRAME)){ //this is to make sure we dont get double-called, as previous aimweapon thread runs before new aimweaponthread can signal-kill previous one 
			gameFrame = get(GAME_FRAME);
	
			//Clamp aimy1position and aimy1delta between <-180>;<180>
			while (aimy1position >  <180>) aimy1position = aimy1position - <360>;
			while (aimy1position < <-180>) aimy1position = aimy1position + <360>;
			while (aimy1delta >  <180>) aimy1delta = aimy1delta - <360>;
			while (aimy1delta < <-180>) aimy1delta = aimy1delta + <360>;
		
			//number of frames required to decelerate to 0
			timetozero = get ABS(aimy1velocity) / AIMY1_ACCELERATION;
			
			//distance from target where we should start decelerating, always 'positive'
			//pos = t * v - (t*(t-1)*a/2)
			deceleratethreshold = timetozero * (get ABS(aimy1velocity)) - (timetozero * (timetozero - 1) * AIMY1_ACCELERATION / 2); 
			
			#ifdef AIMY1_DEBUG
				get PRINT ( aimy1delta , deceleratethreshold, aimy1velocity, timetozero );
			#endif 

			if (get ABS(aimy1delta) <= deceleratethreshold){ //we need to decelerate
				if (aimy1velocity > 0) aimy1velocity = aimy1velocity - AIMY1_ACCELERATION;
				else 				   aimy1velocity = aimy1velocity + AIMY1_ACCELERATION;
			}	
			else //we need to accelerate
			{
				if (aimy1delta > 0) aimy1velocity = get MIN(       MAX_AIMY1_VELOCITY, aimy1velocity + AIMY1_ACCELERATION); 
				else                aimy1velocity = get MAX((-1) * MAX_AIMY1_VELOCITY, aimy1velocity - AIMY1_ACCELERATION);
			}
			
			//Apply jerk at very low velocities
			if (get ABS(aimy1velocity) < AIMY1_JERK){
				if ((aimy1delta >        AIMY1_JERK)) aimy1velocity =        AIMY1_JERK;
				if ((aimy1delta < (-1) * AIMY1_JERK)) aimy1velocity = (-1) * AIMY1_JERK;
			}
			// Update our position with our velocity
			aimy1position = aimy1position + aimy1velocity; 
			aimy1delta = aimy1target - aimy1position ; 	

			// Perform the turn with a NOW, this means that this will be run every frame!
			turn AIMY1_PIECE_Y to y-axis aimy1position now;
		}
		sleep 32;
	}
	aimy1velocity = 0;
	start-script RestoreBody1();
	return (1);
}
