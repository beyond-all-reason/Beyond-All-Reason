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

static-var CATT1velocity, CATT1position, CATT1gameFrame, CATT_isAiming, CATT_nextChassisHeading, CATT_pastChassisHeading, CATT_goalHeading, CATT_delta;

CATT1_Init(){
	CATT1velocity = 0;
	CATT1position = 0;
	CATT1gameFrame = 0;
	CATT_isAiming = 0;
	CATT_nextChassisHeading = 0;
	CATT_pastChassisHeading = 0;
	CATT_goalHeading = 0;
	CATT_delta = 0;
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


CATT1_AimWithChassis(frames) // no need to signal, as threads inherit parents signal masks
{
	// local vars here
	var i;
	var timetozero;
	var deceleratethreshold;
	var chassisVelocity;
	i = 0;

	while ((i < frames) OR (get ABS(CATT1velocity) > 0)) // continue turning with chassis for X frames, or until signal kill, or until velocity is zeroed
	{
		++i;

		//Clamp CATT1position and CATT1delta between <-180>;<180>
		CATT1position = WRAPDELTA(CATT1position);
		CATT_delta = WRAPDELTA(CATT_delta);
		CATT_goalHeading = WRAPDELTA(CATT_goalHeading);

		CATT_nextChassisHeading = get HEADING; // get current heading
		chassisVelocity = WRAPDELTA(CATT_nextChassisHeading - CATT_pastChassisHeading); // get unit chassis current turning speed

		//number of frames required to decelerate to 0 speed relative to ground
		timetozero = get ABS(CATT1velocity - chassisVelocity) / CATT1_ACCELERATION;

		//distance from target where we should start decelerating, always 'positive' ensured by +1 (+1 is small compared in COB angular units)
		//if we assume we start decelerating now to zero relative speed, average speed is half of current speed, so distance is current speed *  time to slow down * 1/2
		//minus a factor due to discrete acceleration per frame
		deceleratethreshold = timetozero * (get ABS(CATT1velocity - chassisVelocity)) / 2 - (timetozero * CATT1_ACCELERATION / 2) + 1;

		if (ABSOLUTE_LESS_THAN(CATT_delta, deceleratethreshold)) { //we need to decelerate
			if (CATT_delta > 0) CATT1velocity = get MAX((-1) * chassisVelocity, CATT1velocity - CATT1_ACCELERATION);
			if (CATT_delta < 0) CATT1velocity = get MIN((-1) * chassisVelocity, CATT1velocity + CATT1_ACCELERATION);

			if (get ABS(CATT1velocity) == get ABS(chassisVelocity)) // if turret velocity was min/max to chassisVelocity, re-accelerate it so it stays ahead of chassis
			{
				if (CATT_delta > 0) CATT1velocity = get MIN(CATT1_MAX_VELOCITY, CATT1velocity + CATT1_ACCELERATION);
				if (CATT_delta < 0) CATT1velocity = get MAX((-1) * CATT1_MAX_VELOCITY, CATT1velocity - CATT1_ACCELERATION);
			}
		}
		else //we need to accelerate
		{
			if (CATT_delta > 0) CATT1velocity = get MIN(CATT1_MAX_VELOCITY, CATT1velocity + CATT1_ACCELERATION);
			if (CATT_delta < 0) CATT1velocity = get MAX((-1) * CATT1_MAX_VELOCITY, CATT1velocity - CATT1_ACCELERATION);
		}

		//Apply jerk at very low velocities
		if (ABSOLUTE_LESS_THAN(CATT1velocity, CATT1_JERK)) {
			if ((CATT_delta > 0)) CATT1velocity = CATT1_JERK;
			if ((CATT_delta < 0)) CATT1velocity = (-1) * CATT1_JERK;
		}

		// If we would need to move less than the delta, then just move the delta?
		if ((CATT_delta >= 0)) CATT1velocity = get MIN(CATT_delta, CATT1velocity);
		if ((CATT_delta <= 0)) CATT1velocity = get MAX(CATT_delta, CATT1velocity);

		// Update our position with our velocity
		CATT1position = CATT1position + CATT1velocity;
		CATT_goalHeading = CATT_goalHeading - chassisVelocity;
		CATT_delta = CATT_goalHeading - CATT1position;

		// Needs to use velocity, because if we use NOW, then any previous turn speed command wont be overridden!
		turn CATT1_PIECE_Y to y-axis CATT1position speed 30 * CATT1velocity;
		CATT_pastChassisHeading = CATT_nextChassisHeading; //track chassis heading
		if (frames == 1) //exits if this is the 1 frame call-script from AimWeaponX->CATT1_Aim
		{
			return;
		}
		sleep 32;
	}
	CATT_isAiming = 0; //unset isAiming, becasue pastChassisHeading will stop being tracked once this thread is over, so will need to be reset when aiming again 
	#ifndef CATT_DONTRESTORE
		start-script CATT1_Restore(); // spin up restore thread
	#endif
}

CATT1_Aim(heading, pitch) {
	/*
	// Set up signals in AimWeaponX(heading, pitch)
	signal SIGNAL_AIM1;
	set-signal-mask SIGNAL_AIM1;
	// Then
	call-script CATT1_Aim(heading, pitch);

	// and call CATT1_Init() in Create()
	*/

	CATT_goalHeading = heading; // save heading from AimWeaponX into variable space here

	if (CATT_isAiming == 0) // If this is the first time aiming in a while, initialize pastChassisHeading
	{
		CATT_pastChassisHeading = get HEADING;
	}
	CATT_isAiming = 1; // Tell CATT we are aiming

	#ifdef CATT1_PIECE_X
		turn CATT1_PIECE_X to x - axis <0.0> -pitch speed CATT1_PITCH_SPEED; // no CATT for pitch, just pitch turret up, does not block firing
		// TODO, add option to block firing if pitch is not in position?
	#endif

	CATT_delta = WRAPDELTA(CATT_goalHeading - CATT1position); // determine how much rotation is needed to turn and face the goal heading
	call-script CATT1_AimWithChassis(1); // run the CATT script once, when AimWeaponX is called
	start-script CATT1_AimWithChassis(15); // then spin up a separate thread (that starts next frame) that will handle turret aiming for the other frames (for at 15 frames)

	// while loop to check if turret is within tolerance each frame. CATT1_AimWithChassis will update delta.
	// breaks, returns to AimWeaponX, and that passes true to engine to allow firing, when turret is within tolerance
	while (ABSOLUTE_GREATER_THAN(CATT_delta, CATT1_PRECISION))
	{
		sleep 32;
	}
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