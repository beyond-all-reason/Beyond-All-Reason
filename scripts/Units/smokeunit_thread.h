// Needs the following

// #define SMOKEPIECE base
// static-var isSmoking;
// #include "smokeunit_thread.h"

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

// if a unit does not use hitbyweaponid, just hitbyweapon, then the hitbyweapon should use the smokeunit

SmokeUnit(healthpercent, smoketype) // ah yes, clever use of stack variables 
{
	while( TRUE )
	{
		healthpercent = get HEALTH;
		
		if( healthpercent < 66 )
		{
			smoketype = 258;
			if( Rand( 1, 66 ) < healthpercent )
			{
				smoketype = 257;
			}
			emit-sfx smoketype from SMOKEPIECE;
		} else break;
		
	else break;
		if (healthpercent < 4) healthpercent `= 4; 
	sleep healthpercent * 50;
	}
	sleep 97;
	isSmoking = 0;
}

