/* Hitweap.h -- Rock the unit when it takes a hit */

#ifndef __HITWEAP_H_
#define __HITWEAP_H_

/*
** HitByWeapon() -- Called when the unit is hit.  Makes it rock a bit
**							to look like it is shaking from the impact.
*/

HitByWeapon(anglex,anglez)
	{

	#define ROCK_SPEED 105
	#define RESTORE_SPEED 30


	turn base to z-axis anglez speed <105>;
	turn base to x-axis anglex speed <105>;

	wait-for-turn base around z-axis;
	wait-for-turn base around x-axis;

	turn base to z-axis <0> speed <30>;
	turn base to x-axis <0> speed <30>;
	}
#endif
