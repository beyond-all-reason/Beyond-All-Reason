// Author Beherith mysterme@gmail.com. License: GNU GPL v2.
// These are the general stubs for WobbleUnit and BankControl

// TODO: 
// [ ] use static-var and sum up everything on turn XZ?
// [X] proper rockunit/hitbyweapon seems to require piece separation
// [X] use get IN_WATER instead of shitty UNIT_XZ
// [X] fold in HoverIdle and StartMoving stuff
// [ ] Fold in smokeunit, hitbyweaponID et al. 


#ifndef HOVER_BASE 
    #define HOVER_BASE base 
#endif

//#ifndef HOVER_ROCKBASE
//	#define HOVER_ROCKBASE HOVER_BASE
//#endif
// should be gated on startmoving stopmoving
// also note that this will interfere with hitbyweapon and recoil stuff

// How far a hovercraft can bank while turning, in degrees, default <9>
#ifndef HOVER_MAXBANKANGLE
	#define HOVER_MAXBANKANGLE <9>
#endif

// How quickly hovercraft will bank in their turning and acceleration directions, in degrees/sec, default <15>
#ifndef HOVER_BANKSPEED
	#define HOVER_BANKSPEED <15>
#endif

// Update rate of banking and wobble, frames, default 3
#ifndef HOVER_FRAMES 
	#define HOVER_FRAMES 3
#endif

// Up-down wobble period in frames, default 46
#ifndef HOVER_WOBBLE_PERIOD
	#define HOVER_WOBBLE_PERIOD 46
#endif

// Up-down wobble amplitude, in elmos, default [0.7] 
#ifndef HOVER_WOBBLE_AMPLITUDE
	#define HOVER_WOBBLE_AMPLITUDE [0.7]
#endif

// How many elmos lower to go when over water than land, in elmos, default [-1.0]
#ifndef HOVER_WOBBLE_WATEROFFSET
	#define HOVER_WOBBLE_WATEROFFSET [-1.0]
#endif

// Optionally define
// #define HOVER_WAKEPIECE

#ifndef HOVER_IDLE_SFX
	#define HOVER_IDLE_SFX 1024 + 2
#endif

#ifndef HOVER_WAKE_SFX_1
	#define HOVER_WAKE_SFX_1 1024 + 0
#endif

#ifndef HOVER_WAKE_SFX_2
	#define HOVER_WAKE_SFX_2 1024 + 1
#endif

static-var HOVER_BANK_X, HOVER_BANK_Z;

HoverCraftMotion()
{
	HOVER_BANK_X = 0;
	HOVER_BANK_Z = 0;
	var prevHeading, currHeading, deltaHeading;
	prevHeading = GET HEADING;

	var prevSpeed, currSpeed, deltaSpeed;
	prevSpeed = 0;

	var wobbleFrame, prevWobble, currWobble;
	wobbleFrame = RAND(1, HOVER_WOBBLE_PERIOD);
	prevWobble = 0;

	var inWater;
	inWater = get IN_WATER;

	#ifdef HOVER_WAKEPIECE
	var movementWake;
	movementWake = 0;
	#endif 

	while (TRUE)
	{
// Update left-right banking:
		currHeading = GET HEADING;
		// if we already acted on this in prev iteration, then dont do anything
		if (deltaHeading != (currHeading - prevHeading)) {
			deltaHeading = currHeading - prevHeading;
			//get PRINT(get GAME_FRAME, deltaHeading, currHeading );
			//Remove Extreme values
			if ( deltaHeading > HOVER_MAXBANKANGLE ) deltaHeading = HOVER_MAXBANKANGLE;
			if ( deltaHeading < -1 * HOVER_MAXBANKANGLE ) deltaHeading = -1 * HOVER_MAXBANKANGLE;
			
			// Tune speed so that things are smooth?
			HOVER_BANK_Z = deltaHeading;
			turn HOVER_BASE to z-axis HOVER_BANK_Z speed HOVER_BANKSPEED;
		}
		prevHeading = currHeading;
// Update forward-backward banking:
		currSpeed = get CURRENT_SPEED * <1.0> / HOVER_MAXBANKANGLE;
		// oh noes dis fucks with RockUnit :(
		if (HOVER_BANK_X != (currSpeed - prevSpeed)){
			HOVER_BANK_X = (currSpeed - prevSpeed);
			turn HOVER_BASE to x-axis HOVER_BANK_X speed HOVER_BANKSPEED;
		}			
		prevSpeed = currSpeed;
		

// Update up-down wobble
		wobbleFrame = wobbleFrame + HOVER_FRAMES;

		currWobble = (get KSIN( wobbleFrame * ([1] / HOVER_WOBBLE_PERIOD)));
		currWobble = currWobble * (HOVER_WOBBLE_AMPLITUDE / 1024) + HOVER_WOBBLE_AMPLITUDE;
		
		//get PRINT(currWobble, wobbleFrame);
		
		inWater = get IN_WATER;
		move HOVER_BASE to y-axis ((inWater * HOVER_WOBBLE_WATEROFFSET)) + currWobble speed ((currWobble - prevWobble) * 30) /  HOVER_FRAMES;
		
		prevWobble = currWobble;


// Emit idle wakes:
		#ifdef HOVER_WAKEPIECE
			if (inWater){
				movementWake = movementWake + 1;
				if (currSpeed > 0){
					if ((movementWake % 2) == 0){
						//dbg(movementWake);
						emit-sfx HOVER_WAKE_SFX_1 from HOVER_WAKEPIECE;
						if (movementWake & 0x02) emit-sfx HOVER_WAKE_SFX_2 from HOVER_WAKEPIECE;
					}
				}else{
					if ((movementWake % 18 ) ==0){
						//dbg(movementWake);
						emit-sfx HOVER_IDLE_SFX from HOVER_WAKEPIECE;
					}
				}
			}
		#endif
		sleep 33 * HOVER_FRAMES -1; // 3 frames
	}
}

// Also add recoil and rockunit here
// NOTE THAT THIS IS MUTUALLY EXCLUSIVE WITH RECOIL_POWER

#ifdef HOVER_ROCKBASE
	RockUnit(anglex,anglez)
		{
		//get PRINT(anglex, anglez);
		//anglex = 0-anglex;
		anglez = 0-anglez;
		#define HOVER_ROCK_SPEED1 <16>
		#define HOVER_ROCK_SPEED2 <13>
		#define HOVER_ROCK_SPEED3 <9.2>
		#define HOVER_ROCK_SPEED4 <5>
		#define HOVER_ROCK_SPEED5 <3.3>
		#define SPEEDMUL 10

		//var x_gt_z;
		//x_gt_z = 0;
		//if((get ABS(anglex)) > (get ABS(anglez))) x_gt_z = 1;

		turn HOVER_ROCKBASE to x-axis HOVER_BANK_X + anglex speed HOVER_ROCK_SPEED1  * anglex / 500;
		turn HOVER_ROCKBASE to z-axis HOVER_BANK_Z + anglez speed HOVER_ROCK_SPEED1  * anglez / 500;

		// Should wait for both, as the speed here isnt trivial
		wait-for-turn HOVER_ROCKBASE around z-axis;

		turn HOVER_ROCKBASE to x-axis HOVER_BANK_X - anglex speed HOVER_ROCK_SPEED2 * anglex / 500;
		turn HOVER_ROCKBASE to z-axis HOVER_BANK_Z - anglez speed HOVER_ROCK_SPEED2 * anglez / 500;

		wait-for-turn HOVER_ROCKBASE around x-axis;

		turn HOVER_ROCKBASE to x-axis HOVER_BANK_X + (anglex/2) speed HOVER_ROCK_SPEED3 * anglex / 500;
		turn HOVER_ROCKBASE to z-axis HOVER_BANK_Z + (anglez/2) speed HOVER_ROCK_SPEED3 * anglez / 500;

		wait-for-turn HOVER_ROCKBASE around z-axis;

		turn HOVER_ROCKBASE to x-axis HOVER_BANK_X - anglex/2 speed HOVER_ROCK_SPEED4;
		turn HOVER_ROCKBASE to z-axis HOVER_BANK_Z - anglez/2 speed HOVER_ROCK_SPEED4;

		wait-for-turn HOVER_ROCKBASE around x-axis;
		
		// Restore it:
		turn HOVER_ROCKBASE to x-axis HOVER_BANK_X speed HOVER_ROCK_SPEED5 * anglex / 500;
		turn HOVER_ROCKBASE to z-axis HOVER_BANK_Z speed HOVER_ROCK_SPEED5 * anglez / 500;
		}
#endif