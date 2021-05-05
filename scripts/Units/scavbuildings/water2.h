/* Rockunit.h -- Rock the unit when it fire a heavy weapon with lots of recoil */

#ifndef __ROCKUNIT_H_
#define __ROCKUNIT_H_


RockUnit(anglex,anglez)
	{

	#define FIRST_SPEED 15
	#define SECOND_SPEED 12
	#define THIRD_SPEED 9

	turn base to x-axis anglex speed <FIRST_SPEED>;
	turn base to z-axis anglez speed <FIRST_SPEED>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	turn base to x-axis (0-anglex) speed <SECOND_SPEED>;
	turn base to z-axis (0-anglez) speed <SECOND_SPEED>;

	//wait-for-turn base around z-axis;
	//wait-for-turn base around x-axis;

	//turn base to x-axis <0> speed <THIRD_SPEED>;
	//turn base to z-axis <0> speed <THIRD_SPEED>;


	}
#endif
