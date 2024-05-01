/* Rockunit.h -- Rock the unit when it fire a heavy weapon with lots of recoil */

#ifndef __ROCKUNIT_H_
#define __ROCKUNIT_H_


RockUnit(anglex,anglez)
	{

	#define ROCK_SPEED 50
	#define RESTORE_SPEED 20

	turn base to x-axis anglex speed <50>;
	turn base to z-axis anglez speed <50>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	turn base to z-axis <0> speed <20>;
	turn base to x-axis <0> speed <20>;
	}
#endif
