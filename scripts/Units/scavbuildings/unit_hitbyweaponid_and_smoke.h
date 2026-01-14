// Needs the following

//#define BASEPIECE base
//#define HITSPEED <20.0>
//how 'heavy' the unit is, on a scale of 1-10
//#define UNITSIZE 5
//#define MAXTILT 200
// #include "smokeunit_thread.h"


HitByWeapon(anglex, anglez, damage)	// angle[x|z] is always [-500;500], damage is multiplied by 100
{
	var amount;//, speedz, speedx;
	amount = damage / (100 * UNITSIZE);
	if (amount < 3  ) return (0);
	if (amount > MAXTILT) amount = MAXTILT;
	//get PRINT(anglex, anglez, amount, damage);
	//speedz = HITSPEED * get ABS(anglez) / 500; //nevermind this, the random error this produces actually looks better than the accurate version
	turn BASEPIECE to z-axis (anglez * amount) / 100  speed HITSPEED;
	turn BASEPIECE to x-axis <0> - (anglex * amount) /100 speed HITSPEED;
	wait-for-turn BASEPIECE around z-axis;
	wait-for-turn BASEPIECE around x-axis;
	turn BASEPIECE to z-axis <0.000000> speed HITSPEED / 4;
	turn BASEPIECE to x-axis <0.000000> speed HITSPEED / 4;
}
static-var isSmoking;
SmokeUnit(healthpercent) // ah yes, clever use of stack variables 
{
	while( TRUE )
	{
		healthpercent = get HEALTH;
		if (healthpercent > 66) {
			sleep 97;
			isSmoking = 0;
			return;
		}
		if (healthpercent < 4 ) healthpercent = 4;
		sleep healthpercent * 50;

		if( Rand( 1, 66 ) < healthpercent ) emit-sfx 257 from BASEPIECE;
		else emit-sfx 258 from BASEPIECE;
	}
}

HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
{
	if( get BUILD_PERCENT_LEFT) return (100);
	if (isSmoking == 0)	{ 
		isSmoking = 1;
		start-script SmokeUnit();
	}	
	start-script HitByWeapon(dmg, anglez,anglex); //I dont know why param order must be switched, and this also runs a frame later :(
	return (100); //return damage percent
}