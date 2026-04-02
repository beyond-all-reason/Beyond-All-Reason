// Needs the following

// #define SMOKEPIECE base
// static-var isSmoking;
// #include "smokeunit_thread.h"



// if a unit does not use hitbyweaponid, just hitbyweapon, then the hitbyweapon should use the smokeunit

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

		if( Rand( 1, 66 ) < healthpercent ) emit-sfx 257 from SMOKEPIECE;
		else emit-sfx 258 from SMOKEPIECE;
	}
}

// this is what a pure hitbyweapon can look like, without any of the motion garbage
//HitByWeapon(anglex, anglez) //weaponID is always 0,lasers and flamers give angles of 0
//{
//	if( get BUILD_PERCENT_LEFT) return (0);
//	if (isSmoking == 0)	{ 
//		isSmoking = 1;
//		start-script SmokeUnit();
//	}	
//}

// this is what the hitbyweaponid should look like:


//HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
//{
//	if( get BUILD_PERCENT_LEFT) return (100);
//	if (isSmoking == 0)	{ 
//		isSmoking = 1;
//		start-script SmokeUnit();
//	}	
//	start-script HitByWeapon(dmg, anglez,anglex); //I dont know why param order must be switched, and this also runs a frame later :(
//	return (100); //return damage percent
//}

/*

#define SMOKEPIECE base
static-var isSmoking;
SmokeUnit(healthpercent) // ah yes, clever use of stack variables 
{
	while( TRUE )
	{
		healthpercent = get HEALTH;
		if (healthpercent > 66) break;
		if (healthpercent < 4 ) healthpercent = 4;
		sleep healthpercent * 50;

		if( Rand( 1, 66 ) < healthpercent ) emit-sfx 257 from SMOKEPIECE;
		else emit-sfx 258 from SMOKEPIECE;
	}
	sleep 97;
	isSmoking = 0;
}

HitByWeaponId(anglex, anglez, weaponid, dmg) //weaponID is always 0,lasers and flamers give angles of 0
{
	if( get BUILD_PERCENT_LEFT) return (100);
	if (isSmoking == 0)	{ 
		isSmoking = 1;
		start-script SmokeUnit();
	}	
	
*/