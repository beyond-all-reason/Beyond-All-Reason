// -------------------------------- WARSHIP ------------------------
// bar_ship_common.h
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// This is a collection of functions that provide a physical simulation of a ship
//	- The ship is modeled as a body with two different axes of rotation moments of inertia
// 		- Thus the rotations around X (pitch) and Z (roll) are independently calculated
//	- Movement of the ship changes the pitch and roll targets (of where the centers should be)
//  - List of movements:
//		- pitch backwards when going near full speed 
//		- pitch backwards when accelerating
//  	- roll into the turn when turning
//		- maintain the energy of the system, with adjustable constant and turn velocity dependent damping factors
//		- additional kickback velocity when firing weapons (aimdirs must be tracked, energy must be defined)
//		- Hit by weapon also adds energy to system via velocity
//		- if the unit goes idle and stops moving, add random energy into the system via a velocity kick
// Notes
//	- For increased precision, the energy of the ship is modeled at x256 fixed points (vs Cob Angular Units)
//	- Yes it is very easy to make the system go absolutely crazy
//	- By defaults, updates are performed every 2 frames, this is a good balance between performance and visuals		
//	- Uses its own DamagedSmoke because HitByWeaponID has to be hooked into
//	- Does not need a separate ground piece
//  - You can correct the aim pitch of a turret due to movement with RB_AIMPITCHCORRECTION(heading)
// Usage
//	- Actually read through the defines and think!
//	- #define what defaults you want to change
//  - #include this file
//  - call-script InitRockBoat(); from Create()
//	- start-script BoatPhysics(); from Create() after waiting for construction completion in 
//  - Recoil: Store the aim directions of weapons from AimWeaponX in static-vars, and pass them into 
//		- start/call-script RecoilRockBoat(heading,power,sleep); 
//		- Directly add energy into the system via RB_RECOILBOAT(heading, power)
//      -- OR set #define RB_ROCKUNIT 100 to recoil on all shots
//	- Set the usual UNITSIZE (default (WIDTH+LENGTH)/2) and MAXTILT for HitByWeapon

// Notes, Todo etc:
// [X] Make damping factor scale with current pitch and roll
// [X] Fix rounding of angular acceleration at <1.0
// [X] Rock when slow, do this by modulating the 'target pos' 
// [X] pitch forward when moving fast
// [X] bank when turning 
// [X] Bounce on high speed
//		[X] boats should rise upwards
//		[X] Ensure the bounce piece move happens before rot, yes move is before rot
// [X] Idle waves 
// [X] Independent axis damping if not specified
// [X] Damping should be velocity dependent!
// [X] Better Recoil handling 
// [X] Integrate SmokeUnit
// [ ] Minimize usage of local vars
// [X] Slave large turrets to RB_pitch/RB_roll (RB_AIMPITCHCORRECTION)
//		[X] Static-var the RB_pitch/RB_roll
// [NOTNEEEDED] separate ground and base, like for all other ships anyway too
//		[-] Movement physics based stuff should go onto base
//		[-] Recoil and hitbyweapon can go onto ground
//		[-] These could maybe use different speeds based on power, like missiles and stuff arent trivial
// [ ] Emit less wakes when decelerating
// [X] Do NOT use RockUnit, as there is only one callin for all weapons, and boats usually have more than one
// [X] Validate that updates every 2 frames are sufficient


//-------------------- INTERNAL DEFINES ------------------


//#define DEBUG
//#include ".../debug.h"


//-------------------- MANDATORY DEFINES ------------------

// The base piece to move
#ifndef RB_BASE
	#define RB_BASE BASE
#endif

// mass of boat in arbitrary units
#ifndef RB_MASS
	#define RB_MASS 40
#endif

//Virtual Length of the boat, longer boats will have lower frequency pitches
#ifndef RB_LENGTH
	#define RB_LENGTH 8
#endif 

// Virtual width of boat, wider boats will roll slower
#ifndef RB_WIDTH
	#define RB_WIDTH 3
#endif

// How strongly the ship will pitch back and forth with high speed travel
#ifndef RB_PITCH_SPEED
	#define RB_PITCH_SPEED 100
#endif


// How strongly the ship will pitch back and forth with forward acceleration
#ifndef RB_PITCH_ACCELERATION
	#define RB_PITCH_ACCELERATION 10
#endif

// How strongly the ship will roll left and right when turning
#ifndef RB_ROLL_ACCELERATION
	#define RB_ROLL_ACCELERATION 4
#endif

// How often should BoatPhysics update, Only set it to 1 for rare, fast boats
#ifndef RB_FRAMES
	#define RB_FRAMES 2
#endif

// RB_DAMPFACTOR is the velocity dependent damping, so faster moves are damped more.
// Higher numbers mean less damping
// This shouldnt ever be less than 1000
#define RB_DAMPFACTOR 2000

// Constant damping factors, higher number more damping. 
#define RB_PITCH_DAMPING 4
#define RB_ROLL_DAMPING  2

// How tall, in elmos, the unit should Bounce at full speed
#ifndef RB_BOUNCE_HEIGHT
	#define RB_BOUNCE_HEIGHT [2.0]
#endif

// in degrees per frame
#ifndef RB_BOUNCE_PERIOD
	#define RB_BOUNCE_PERIOD <5>
#endif

// Enables bow splashes if the piece is named here
//#define RB_BOWSPLASH_PIECE bow

// What point of the sine wave should the bow splash be emitted at?
#ifndef RB_BOWSPLASH1_PHASE
	#define RB_BOWSPLASH1_PHASE <90>
#endif

// What other point of the sine wave should the bow splash be emitted at
#ifndef RB_BOWSPLASH2_PHASE
	#define RB_BOWSPLASH2_PHASE <270>
#endif

#ifndef RB_BOWSPLASH_CEG
	#define RB_BOWSPLASH_CEG 1024+2
#endif

// When reaching each Bowsplash phase angle, how many bowsplash CEGS to emit (one per update)
#ifndef RB_BOWSPLASH_COUNT
    #define RB_BOWSPLASH_COUNT 3
#endif

// Which CEG is to be used for the wake effect
#ifndef RB_WAKE_CEG
	#define RB_WAKE_CEG 1024+1
#endif

// Which piece the wake CEG effect should be emitted from
#ifndef RB_WAKE_PIECE
	#define RB_WAKE_PIECE wake
#endif


// Every X frames emit wake CEG

#ifndef RB_WAKE_PERIOD
	#define RB_WAKE_PERIOD 6
#endif

// anglez is left-right, +500 right
// anglex is front-back, where +500 is front
#ifndef UNITSIZE
	#define UNITSIZE (RB_LENGTH + RB_WIDTH)/2
#endif
#ifndef MAXTILT
	#define MAXTILT 100
#endif

// The amount of energy imparted to the boat when it becomes idle to rock it around
#ifndef RB_IDLE_KICK 
	#define RB_IDLE_KICK 5000
#endif

#ifndef RB_IDLE_THRESHOLD
    #define RB_IDLE_THRESHOLD 32
#endif


//------------------- OPTIONAL DEFINES ------------------



// How often should the speed/position of the boat be adjusted
// 1: 1.8% CPU/1k, for flagships only
// 2: 1.1% CPU/1k  for smaller boats
// 3: 0.8% CPU/1k  if you really wanna save a tiny bit of perf

// ------------------ INTERNAL DEFINES ------------------

#define RB_INERTIA_PITCH ((RB_MASS) * (RB_WIDTH * RB_WIDTH + RB_LENGTH * RB_LENGTH) / (10))
#define RB_INERTIA_ROLL  ((RB_MASS) * (RB_WIDTH * RB_WIDTH + RB_WIDTH  * RB_WIDTH ) / (10))

#define RB_RECOILBOAT(heading, power) \
	RB_pitch_velocity = RB_pitch_velocity - (get KCOS(heading) * (power / RB_MASS)); \
	RB_roll_velocity  = RB_roll_velocity  - (get KSIN(heading) * (power / RB_MASS));

#define RB_PRECISION 256

// Goes from <-180> - <180> (32760)
// 16 instructions
#define DELTAHEADING(curr, prev) ((curr - prev + 98280) % 65520 - 32760)

// Pitch is the X axis
// Roll is the Z axis
static-var RB_pitch, RB_roll, maxSpeed;
// Target is changed by the movement of the unit
//static-var RB_pitch_target, RB_roll_target;
// Velocity is changed by impulse from being shot and from shooting
static-var RB_pitch_velocity, RB_roll_velocity;

// Always zero this in startmoving
static-var RB_bounce_frame;

InitRockBoat(){

	RB_pitch = 0;
	RB_roll = 0;
	maxSpeed = get MAX( get (MAX_SPEED), 10000);
	RB_pitch_velocity = 0;
	RB_roll_velocity = 0; 

	#ifdef DEBUG
		RB_pitch_velocity = 150000;
		RB_roll_velocity = 150000; 	
		//dbg(RB_INERTIA_PITCH, RB_INERTIA_ROLL);
		/*
		var deltat;
		deltat = get GAME_FRAME;
		sleep 63;
		while(1){
			sleep 32;
			if ((currpitch / 100) == 0 ){
				
				deltat = (get GAME_FRAME) - deltat;
				dbg(deltat, currpitch);
				return(0);
			}
		}
		*/
	#endif
}


BoatPhysics(){
	var torque_pitch;
	var torque_roll;

	turn RB_BASE to x-axis RB_pitch now;
	turn RB_BASE to z-axis RB_roll  now;
	
	var currHeading, currSpeed, prevHeading_delta, prevSpeed_delta;	
	prevSpeed_delta = (1024  * get (CURRENT_SPEED) ) / maxSpeed;
	prevHeading_delta = WRAPDELTA(get (HEADING));

	var cos_bounce;
	cos_bounce = 0;

	var wake_freq;
	wake_freq = 0;

	while (1){
		// Get Speed and Heading, store the deltas
        // currSpeed is relative, 1024x
		currSpeed =   (1024 * (get (CURRENT_SPEED))) / maxSpeed; // usually around 100,000
		prevSpeed_delta = currSpeed - prevSpeed_delta;

		currHeading = get (HEADING);
		prevHeading_delta = WRAPDELTA(currHeading - prevHeading_delta); // usually at most a few thousand

		// Move the pitch target backwards when going fast
		// And keep it back when going fast
		torque_pitch = (-1 * RB_PITCH_SPEED) *( RB_PITCH_ACCELERATION * prevSpeed_delta + currSpeed) ;
		
		// Roll the boat more when turning at high speed
		torque_roll = RB_ROLL_ACCELERATION * (prevHeading_delta * currSpeed) / (4 * RB_FRAMES) ;
        //dbg(torque_roll,prevHeading_delta, currSpeed);

		// Save the curr heading and speed, as we wont be using them again
		prevHeading_delta = currHeading;
		prevSpeed_delta = currSpeed;

		// Calculate restoring torque due to displacement
		torque_pitch =  ( (RB_pitch - torque_pitch) * (-1 * RB_LENGTH));
		torque_roll =   ( (RB_roll  - torque_roll ) * (-1 * RB_WIDTH ));
		
		// Update angular velocity with angular acceleration
		RB_pitch_velocity = RB_pitch_velocity +  (torque_pitch  / (RB_INERTIA_PITCH * RB_FRAMES ));
		RB_roll_velocity  = RB_roll_velocity  +  (torque_roll   / (RB_INERTIA_ROLL  * RB_FRAMES )) ;
		

		// Simple damping to simulate resistance from water and air
		// OVERFLOW WARNING HERE ON LOW DAMPFACTOR: NEGATIVE SUBTRACTIONS HERE!
		RB_pitch_velocity =  (RB_pitch_velocity * (256 -  (RB_FRAMES * RB_PITCH_DAMPING) - (get ABS(RB_pitch_velocity))/(RB_DAMPFACTOR/ RB_FRAMES)))/256  ;
		RB_roll_velocity  =  (RB_roll_velocity  * (256 -  (RB_FRAMES * RB_ROLL_DAMPING ) - (get ABS(RB_roll_velocity ))/(RB_DAMPFACTOR/ RB_FRAMES)))/256  ;
		
		// Update pitch and roll based on angular velocity
		RB_pitch = RB_pitch + RB_FRAMES * RB_pitch_velocity;
		RB_roll  = RB_roll  + RB_FRAMES * RB_roll_velocity;
		
		// emit a wakesplash on up and down bounce
		// increment bounce phase and modulo it
		if (currSpeed != 0){
			RB_bounce_frame = ((RB_bounce_frame + (RB_FRAMES * RB_BOUNCE_PERIOD)) % <360>);

            #ifdef RB_BOWSPLASH_PIECE
                // BowSplash Phase 1
                if (ABSOLUTE_LESS_THAN(RB_bounce_frame - RB_BOWSPLASH1_PHASE, (RB_BOWSPLASH_COUNT * RB_FRAMES * RB_BOUNCE_PERIOD))){
                    emit-sfx RB_BOWSPLASH_CEG from RB_BOWSPLASH_PIECE;
                    //dbg(1,RB_bounce_frame, RB_BOWSPLASH1_PHASE);
                }

                // BowSplash Phase 2
                if (ABSOLUTE_LESS_THAN(RB_bounce_frame - RB_BOWSPLASH2_PHASE, (RB_BOWSPLASH_COUNT * RB_FRAMES * RB_BOUNCE_PERIOD))){
                    emit-sfx RB_BOWSPLASH_CEG from RB_BOWSPLASH_PIECE;
                    //dbg(2,RB_bounce_frame);
                }
            #endif

			// WakeSplash:
			wake_freq = wake_freq + 1; 
			if (!(wake_freq % (RB_WAKE_PERIOD / RB_FRAMES))){
                #ifndef RB_WAKE_PIECE2
    				emit-sfx RB_WAKE_CEG from RB_WAKE_PIECE;
                #else
                    if(wake_freq & 0x01) emit-sfx RB_WAKE_CEG from RB_WAKE_PIECE;
                    else emit-sfx RB_WAKE_CEG from RB_WAKE_PIECE2;
                #endif
			}
			
			// Calculate Bounce, be careful that your int doesnt overflow
			// Start at the -1 point of the cosine with + <180>
			cos_bounce = (get KCOS(RB_bounce_frame + <180>) + 1024);

            // Weight it with current speed
			cos_bounce = cos_bounce * ((RB_BOUNCE_HEIGHT / 1024) * currSpeed) ;

			move RB_BASE to y-axis cos_bounce / 1024 speed [500];
		}
		//If we are stationary, give us a kick
		else
		{
			if (ABSOLUTE_LESS_THAN(RB_pitch_velocity, RB_IDLE_THRESHOLD)) {
				RB_pitch_velocity = Rand(-1 *  RB_IDLE_KICK, RB_IDLE_KICK);
			}

			if (ABSOLUTE_LESS_THAN(RB_roll_velocity, RB_IDLE_THRESHOLD)) {
				RB_roll_velocity =  Rand(-1 * RB_IDLE_KICK, RB_IDLE_KICK);
			}
		}

		// Execute corresponding movements
		#if (RB_FRAMES == 1)
			if (RB_pitch_velocity != 0) turn RB_BASE to x-axis (RB_pitch/RB_PRECISION) speed (30 * RB_pitch_velocity )/RB_PRECISION;  
			if (RB_roll_velocity  != 0) turn RB_BASE to z-axis (RB_roll /RB_PRECISION) speed (30 * RB_roll_velocity  )/RB_PRECISION; 
		#else
			turn RB_BASE to x-axis (RB_pitch/RB_PRECISION) speed (30 * RB_pitch_velocity) / RB_PRECISION;
			turn RB_BASE to z-axis (RB_roll /RB_PRECISION) speed (30 * RB_roll_velocity ) / RB_PRECISION;
		#endif
	
		sleep 33 * RB_FRAMES - 1;
	}
}

// This is for correcting the pitch of an aim on a moving boat
#define RB_AIMPITCHCORRECTION(heading) (get KSIN(heading)*(RB_roll/(-256)) + (get KCOS(heading))*(RB_pitch/(-256)) )/1024

// Pass in the heading of the current aiming here 
// You will need to save the headings of weapons 
// heading: 0 is forward, 16K is 90deg left, -16K is 90 deg right
// This can be start-script-ed, if a frame of delay is needed but immediate return is needed
RecoilRockBoat(heading, power, delay){
	// Add with negative sign as we want it to move backwards from heading;
	if (delay) sleep delay;
	RB_RECOILBOAT(heading, power)
}

static-var isSmoking;

// MUST IMMEDIATELY RETURN DAMAGE AMOUNT!
HitByWeaponId(anglex, anglez, weaponid, damage) 
{
	// Dont do anything if we are being built
	if (get BUILD_PERCENT_LEFT) return (100);
    #ifdef RB_ONHIT
        RB_ONHIT
    #endif

	damage = damage / (100 * UNITSIZE);
	if (damage < 3  ) return (100);
	if (damage > MAXTILT) damage = MAXTILT;

	RB_pitch_velocity = RB_pitch_velocity - (anglex * damage) ;
	RB_roll_velocity  = RB_roll_velocity  + (anglez * damage) ;

	// Dont start a damagedSmoke thread if we arent low health
	if ((get HEALTH) > 65){
		// Start a thread if werent previously smoking
		if (isSmoking == 0)	{ 
			isSmoking = 1;
			start-script DamagedSmoke();
		}	
	}	
	return (100); //return damage percent
}

#ifdef RB_ROCKUNIT
RockUnit(anglex, anglez)
{
    #ifdef RB_ROCKUNIT_SLEEP
        sleep RB_ROCKUNIT_SLEEP;
    #endif
	RB_pitch_velocity = RB_pitch_velocity + (anglex * RB_ROCKUNIT) ;
	RB_roll_velocity  = RB_roll_velocity  - (anglez * RB_ROCKUNIT) ;
}
#endif

DamagedSmoke() 
{
	var current_health_pct; // [0-100]
	while( TRUE )
	{
		current_health_pct = (get HEALTH); 
		if (current_health_pct < 4) current_health_pct = 4;
		if (current_health_pct > 65) {
            // We no longer need to smoke, so terminate this thread by returning
			isSmoking = 0;
			return;
		}

		// Less health means blacker smoke
		if( Rand(1,65) < current_health_pct ) {
			emit-sfx 257 from RB_BASE;
		}
		else {
			emit-sfx 258 from RB_BASE;
		}

		// Sleep after emission to get immediate visual of unit taking damage via smoke effect
		sleep (current_health_pct * 50);
	}
}


