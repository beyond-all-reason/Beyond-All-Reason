// These are the general stubs for WobbleUnit and BankControl

// TODO: use static-var and sum up everything on turn XZ?


#ifndef HOVER_BASE 
    #define HOVER_BASE base 
#endif


WobbleUnit()
{
    var wobble_status;
    wobble_status = 0;
	while( TRUE )
	{
        if( get GROUND_WATER_HEIGHT(get UNIT_XZ) < 0 ) //Over Water
        {
            move HOVER_BASE to y-axis [-0.750000] + [1.5] * wobble_status speed [0.50000];
			wait-for-move HOVER_BASE along y-axis;
        }
        else
        {
            move HOVER_BASE to y-axis ([1.0] * wobble_status) speed [0.50000];
			wait-for-move HOVER_BASE along y-axis;
        }
		wobble_status = !wobble_status;
		sleep 100;
	}
}

// should be gated on startmoving stopmoving
// also note that this will interfere with hitbyweapon and recoil stuff

#ifndef HOVER_MAXBANKANGLE
	#define HOVER_MAXBANKANGLE <9>
#endif

#ifndef HOVER_BANKSPEED
	#define HOVER_BANKSPEED <23>
#endif

BankControl()
{
	var prevHeading, currHeading, deltaHeading;
	prevHeading = GET HEADING;

	var prevDiffSpeed, currSpeed, deltaSpeed;
	prevDiffSpeed = GET CURRENT_SPEED;

	while (TRUE)
	{
		currHeading = GET HEADING;

		// if we already acted on this in prev iteration, then dont do anything
		if (deltaHeading != (currHeading - prevHeading)) {
			deltaHeading = currHeading - prevHeading;

			//Remove Extreme values
			if ( deltaHeading > HOVER_MAXBANKANGLE ) deltaHeading = HOVER_MAXBANKANGLE;
			if ( deltaHeading < -1 * HOVER_MAXBANKANGLE ) deltaHeading = -1 * HOVER_MAXBANKANGLE;
			
			// Tune speed so that things are smooth?
			turn HOVER_BASE to z-axis deltaHeading speed HOVER_BANKSPEED;
		}

		prevHeading = currHeading;

		sleep 98; // 3 frames
	}
}

// Also add recoil and rockunit here? or just fucking ignore the whole goddamned thing
#define HOVER_ROCK
#ifdef HOVER_ROCK
	RockUnit(anglex,anglez)
		{
		get PRINT(anglex, anglez);
		//anglex = 0-anglex;
		//anglez = 0-anglez;
		#define FIRST_SPEED 15
		#define SECOND_SPEED 12
		#define THIRD_SPEED 9
		#define FOURTH_SPEED 6
		#define FIFTH_SPEED 2

		turn HOVER_BASE to x-axis anglex speed <FIRST_SPEED>  * anglex / 500;
		turn HOVER_BASE to z-axis anglez speed <FIRST_SPEED>  * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		turn HOVER_BASE to x-axis (0-anglex) speed <SECOND_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis (0-anglez) speed <SECOND_SPEED> * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		turn HOVER_BASE to x-axis (anglex/2) speed <THIRD_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis (anglez/2) speed <THIRD_SPEED> * anglez / 500;

		wait-for-turn HOVER_BASE around z-axis;

		//turn base to x-axis <0-anglex/2> speed <FOURTH_SPEED>;
		//turn base to z-axis <0-anglez/2> speed <FOURTH_SPEED>;

		//wait-for-turn base around z-axis;
		//wait-for-turn base around x-axis;

		turn HOVER_BASE to x-axis <0> speed <FIFTH_SPEED> * anglex / 500;
		turn HOVER_BASE to z-axis <0> speed <FIFTH_SPEED> * anglez / 500;
		}
#endif