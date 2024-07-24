//-------------------------------KINEMATIC TURRET TURNING---------------------------
// MaxVelocity and acceleration are in degrees per frame (not second!)
// Jerk is the minimum velocity of the turret
// A high precision requirement can result in overshoots if desired 
// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// The shorthand will be CATT

// Usage:
// 1. Tune the defines in your script, see the defaults below, make sure you set the individual pieces!
// 2. Include this file after piece declarations
// 3. From the AimWeaponX corresponding to the turret to be accelerated, no signals needed
// AimWeapon1(heading, pitch)
// {
//	KT1_SET_TARGET(heading,pitch, restore_delay);
//	if (KT1_CAN_FIRE) return (1);
//	return (0);
//}

// 4. Check for KT1_CAN_FIRE_STOPPED if you want the turret to only fire when stopped
//      Or use KT1_CAN_FIRE if you dont care if the turret has stopped
// 5. start-script KT1_Aim() in Create()

// Note: 


// The piece that will aim left-right
#ifndef KT1_PIECE_Y
	#define KT1_PIECE_Y aimy
#endif

// The piece that will aim up-down, dont define it if you dont want up-down motion
#ifndef KT1_PIECE_X
	//#define KT1_PIECE_X aimx1
#endif

// Specify how fast to move up-down (per second)
#ifdef KT1_PIECE_X
	#ifndef KT1_PITCH_SPEED 
		#define KT1_PITCH_SPEED <90>
	#endif
#endif

// Max left-right turn speed (per frame)
#ifndef KT1_MAX_VELOCITY
	#define KT1_MAX_VELOCITY <3.0>
#endif

// Turning acceleration (per frame)
#ifndef KT1_ACCELERATION
	#define KT1_ACCELERATION <0.15>
#endif

// Minimum velocity on turning (per frame)
#ifndef KT1_JERK
	#define KT1_JERK <0.5>
#endif

// Desired angular correctness before firing
#ifndef KT1_PRECISION
	#define KT1_PRECISION <1.2>
#endif

// Optionally, if you want to restore to a default position after a while
#ifndef KT1_RESTORE_DELAY
	#define KT1_RESTORE_DELAY 6000
#endif

// Define KT1_HAS_STUNNED if it has a STUNNED static-var
//#define KT1_HAS_STUNNED

//--------------------------------------------- end config --------------------------------------------

#ifndef WRAPDELTA
	#define WRAPDELTA(ang) (((ang + 98280) % 65520) - 32760)
#endif

static-var KT1gameFrame, KT1velocity, KT1heading,  KT1targetheading, KT1deltaheading,  KT1pitch, KT1targetpitch;

// This macro sets our target for the aim thread
// TODO: We must set our deltas whenever we set a new target too!
#define KT1_SET_TARGET(heading, pitch, restore_delay) \
    KT1targetheading = WRAPDELTA(heading); \
    KT1targetpitch = pitch; \
    KT1gameFrame = (restore_delay / 30); \
    KT1deltaheading = WRAPDELTA(KT1targetheading - KT1heading);

// We need to be able to check from anywhere for all of the below to be true:
// 1. We are within heading precision of the target
// 2. We are within pitch precision of the target
// 3. We are not moving too fast
// 4. Ensure that all pitch and heading values are within <-180;180>
#define KT1_CAN_FIRE_STOPPED \
    ABSOLUTE_LESS_THAN(KT1deltaheading, KT1_PRECISION) & \
    ABSOLUTE_LESS_THAN(KT1targetpitch - KT1pitch, KT1_PRECISION) & \
    ABSOLUTE_LESS_THAN(KT1velocity, KT1_JERK)

#define KT1_CAN_FIRE \
    ABSOLUTE_LESS_THAN(KT1deltaheading, KT1_PRECISION) & \
    ABSOLUTE_LESS_THAN(KT1targetpitch - KT1pitch, KT1_PRECISION)

KT1_Aim(){
	
	var timetojerkspeed;
	var deceleratethreshold;
	var delta;
    var absvelocity;
    var deltasign;


    KT1velocity = 0;
    KT1heading = 0;
    KT1targetheading = 0;
    KT1targetpitch = 0; 
    KT1deltaheading = 0;
	
    while (TRUE){
        #if 1 // 300 cmds , ~ 1.2 us worst case

        // Check if we need to restore:
        #ifdef KT1_RESTORE_DELAY
            if (KT1gameframe >= 0){
                if (KT1gameframe == 0){
                    KT1targetheading = 0;
                    KT1targetpitch = 0;
                }
                KT1gameframe = KT1gameframe - 1;
            }
        #endif


        KT1deltaheading = WRAPDELTA(KT1targetheading - KT1heading);
        
        // We must move if our delta or velocity are nonzero
        if (KT1deltaheading | KT1velocity) {
            deltasign = SIGN(KT1deltaheading);
            absvelocity = get ABS(KT1velocity);
            // How many frames will it take to decelerate to go below our jerk speed?
            // Ceiling of the absolute value of the velocity divided by the acceleration
			timetojerkspeed = ((get MAX(absvelocity - (KT1_JERK-KT1_ACCELERATION), 0)) / KT1_ACCELERATION) + 2;

            // What distance will we travel if we only decelerate from now until we reach jerk velocity?
            // Bigger number means we will slow down sooner
            // Well we can always travel just jerk velocity:
            //deceleratethreshold = (((absvelocity) + KT1_JERK) * timetojerkspeed) / 2 ;

            deceleratethreshold = get MAX( (((absvelocity) + KT1_JERK) * timetojerkspeed) / 2, KT1_JERK);
            
            #ifdef KT1_DEBUG
                get PRINT(KT1deltaheading, KT1velocity, timetojerkspeed, deceleratethreshold);
            #endif

            // We need to accelerate if our deltaheading is greater than the deceleration threshold
            if (ABSOLUTE_GREATER_THAN(KT1deltaheading, deceleratethreshold)){
                // We are already faster than our jerk, accelerate up to at most KT1_MAX_VELOCITY
                if (ABSOLUTE_GREATER_THAN(KT1velocity, KT1_JERK)){
                    KT1velocity = deltasign * get MIN(KT1_MAX_VELOCITY, KT1velocity * deltasign + KT1_ACCELERATION);
                
                // We are slower than our jerk, accelerate up to at least KT1_JERK
                }else{
                    KT1velocity = deltasign * get MAX(KT1_JERK, KT1velocity * deltasign + KT1_ACCELERATION);
                }
            }	
            // We need to slow down
            else 
            {
                // We are faster than our jerk:
                if (ABSOLUTE_GREATER_THAN(KT1velocity, KT1_JERK)){
                    // Depending on going left or right
                    // Todo, this may be incorrect on overshoot conditions
			    	if (KT1velocity > 0) KT1velocity = KT1velocity - KT1_ACCELERATION;
			    	else 				 KT1velocity = KT1velocity + KT1_ACCELERATION;
                }
                // We are slower than our jerk, then check if we can jerk into place!
                else{
                    // We cannot jerk into place:
                    if (ABSOLUTE_GREATER_THAN(KT1deltaheading, KT1_JERK)){
                        // Happens when we overshoot:
                        KT1velocity = deltasign * KT1_JERK;
                    }
                    // We can jerk into place, so just snap there. 
                    else
                    {
                        KT1velocity = KT1deltaheading;
                    }
                }
            }

            // Now perform the actual movements, and update our position
            #ifdef KT1_HAS_STUNNED
                if (Stunned) KT1velocity = 0;
            #endif
            KT1heading = KT1heading + KT1velocity;
            turn KT1_PIECE_Y to y-axis KT1heading speed 30 * KT1velocity;
       
            // Ensure our internal position is updated so KT1_CAN_FIRE is correct
            KT1deltaheading = WRAPDELTA(KT1targetheading - KT1heading);
        }

        // Handle pitch:
        #ifdef KT1_PIECE_X
            // We need to move if our pitch is nonzero
            if (KT1targetpitch != KT1pitch){
                // We are pretty far away from our target pitch:
                if (ABSOLUTE_GREATER_THAN(KT1targetpitch - KT1pitch, KT1_PITCH_SPEED)){
                    if (KT1targetpitch > KT1pitch) KT1pitch = KT1pitch + KT1_PITCH_SPEED;
                    else KT1pitch = KT1pitch - KT1_PITCH_SPEED;
                }
                // We are quite close to our target pitch:
                else
                {
                    KT1pitch = KT1targetpitch;
                }
                turn KT1_PIECE_X to x-axis <0.0> - KT1pitch speed KT1_PITCH_SPEED;
            }
        #endif
        #endif
        sleep 32;
    }
}
