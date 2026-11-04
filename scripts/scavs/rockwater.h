/* Rockunit.h -- Rock the unit when it fire a heavy weapon with lots of recoil */

#ifndef __ROCKUNIT_H_
#define __ROCKUNIT_H_


RockUnit(anglex,anglez)
	{

	#define FIRST_SPEED 15
	#define SECOND_SPEED 12
	#define THIRD_SPEED 9
	#define FOURTH_SPEED 6
	#define FIFTH_SPEED 3

	turn base to x-axis anglex speed <FIRST_SPEED>;
	turn base to z-axis anglez speed <FIRST_SPEED>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	turn base to x-axis (0-anglex) speed <SECOND_SPEED>;
	turn base to z-axis (0-anglez) speed <SECOND_SPEED>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	turn base to x-axis (anglex/2) speed <THIRD_SPEED>;
	turn base to z-axis (anglez/2) speed <THIRD_SPEED>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	//turn base to x-axis <0-anglex/2> speed <FOURTH_SPEED>;
	//turn base to z-axis <0-anglez/2> speed <FOURTH_SPEED>;

	//wait-for-turn base around z-axis;
	//wait-for-turn base around x-axis;

	turn base to x-axis <0> speed <FIFTH_SPEED>;
	turn base to z-axis <0> speed <FIFTH_SPEED>;
	}
#endif
