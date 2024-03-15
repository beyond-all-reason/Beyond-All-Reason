// These are the general stubs for WobbleUnit and BankControl

// TODO: 
// [ ] use static-var and sum up everything on turn XZ?
// [ ] proper rockunit/hitbyweapon seems to require piece separation
// [ ] use get IN_WATER instead of shitty UNIT_XZ
// [ ] fold in HoverIdle and StartMoving stuff
// [ ] Fold in smokeunit, hitbyweaponID et al. 


#ifndef HOVER_BASE 
    #define HOVER_BASE base 
#endif


WobbleUnit()
{
}

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

// Up-down wobble Phase offset in degrees, default <0>
#ifndef HOVER_WOBBLE_PHASE
	#define HOVER_WOBBLE_PHASE <0>
#endif

// Up-down wobble amplitude, in elmos, default [0.7] 
#ifndef HOVER_WOBBLE_AMPLITUDE
	#define HOVER_WOBBLE_AMPLITUDE [0.7]
#endif

// How many elmos lower to go when over water than land, in elmos, default [-1.0]
#ifndef HOVER_WOBBLE_WATEROFFSET
	#define HOVER_WOBBLE_WATEROFFSET [-1.0]
#endif

static-var HOVER_BANK_X, HOVER_BANK_Z;

BankControl()
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
		
		HOVER_BANK_X = (currSpeed - prevSpeed);
		turn HOVER_BASE to x-axis HOVER_BANK_X speed HOVER_BANKSPEED;
		prevSpeed = currSpeed;
		

// Update up-down wobble
		wobbleFrame = wobbleFrame + HOVER_FRAMES;

		currWobble = (get KSIN( HOVER_WOBBLE_PHASE + wobbleFrame * ([1] / HOVER_WOBBLE_PERIOD)));
		currWobble = currWobble * (HOVER_WOBBLE_AMPLITUDE / 1024) + HOVER_WOBBLE_AMPLITUDE;
		
		//get PRINT(currWobble, wobbleFrame);
		
		move HOVER_BASE to y-axis ((get IN_WATER * HOVER_WOBBLE_WATEROFFSET)) + currWobble speed ((currWobble - prevWobble) * 30) /  HOVER_FRAMES;
		
		prevWobble = currWobble;

		sleep 33 * HOVER_FRAMES -1; // 3 frames
	}
}

// Also add recoil and rockunit here? or just fucking ignore the whole goddamned thing
#define HOVER_ROCK
#ifdef HOVER_ROCK
	RockUnit(anglex,anglez)
		{
		//get PRINT(anglex, anglez);
		//anglex = 0-anglex;
		anglez = 0-anglez;
		#define FIRST_SPEED 15
		#define SECOND_SPEED 12
		#define THIRD_SPEED 9
		#define FOURTH_SPEED 6
		#define FIFTH_SPEED 2
		#define SPEEDMUL 10

		turn HOVER_BASE to x-axis HOVER_BANK_X + anglex speed <FIRST_SPEED>  * anglex / 500;
		turn HOVER_BASE to z-axis HOVER_BANK_Z + anglez speed <FIRST_SPEED>  * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		turn HOVER_BASE to x-axis HOVER_BANK_X + (0-anglex) speed <SECOND_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis HOVER_BANK_Z + (0-anglez) speed <SECOND_SPEED> * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		turn HOVER_BASE to x-axis HOVER_BANK_X + (anglex/2) speed <THIRD_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis HOVER_BANK_Z + (anglez/2) speed <THIRD_SPEED> * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		turn base to x-axis HOVER_BANK_X - anglex/2 speed <FOURTH_SPEED>;
		turn base to z-axis HOVER_BANK_Z - anglez/2 speed <FOURTH_SPEED>;

		wait-for-turn base around z-axis;
		//wait-for-turn base around x-axis;

		turn HOVER_BASE to x-axis HOVER_BANK_X speed <FIFTH_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis HOVER_BANK_Z speed <FIFTH_SPEED> * anglez / 500;
		}
#endif