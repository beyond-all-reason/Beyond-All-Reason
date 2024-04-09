// Author Beherith (mysterme@gmail.com)
// unit_hitbyweaponid_and_smoke.h
// This header defines wether a unit should rock when hit by a weapon
// And wether it should emit smoke if the unit's health is below a threshold
// Note: DO NOT use this if you intend to use the HitByWeaponId or HitByWeapon callins!
// NOTE: Due to the architecture, reloading a cob script while a unit isSmoking wont clear the static var so it wont ever smoke again
// Needs the following

//#define BASEPIECE base
//#define HITSPEED <20.0>
//#define UNITSIZE 5
//#define MAXTILT 200 // Set to 0 for not tilting
// #include "unit_hitbyweaponid_and_smoke.h"

// Where the smoke should be emitted from
#ifndef BASEPIECE
	#define BASEPIECE base
#endif

// How much tilt is allowed, set to 0 for no movement
#ifndef MAXTILT
	#define MAXTILT 200
#endif

// How fast the unit should tilt when hit
#ifndef HITSPEED
	#define HITSPEED <20.0>
#endif

// How 'heavy' the unit is, on a scale of 1-10
#ifndef UNITSIZE
	#define UNITSIZE 5
#endif

// The health percentage threshold below which the unit will emit smoke
#ifndef HEALTH_SMOKE_THRESHOLD
	#define HEALTH_SMOKE_THRESHOLD 65
#endif

static-var isSmoking;

#if MAXTILT > 0
	HitByWeaponId(anglex, anglez, weaponid, damage) //weaponID is always 0,lasers and flamers give angles of 0
	{
		#if (HEALTH_SMOKE_THRESHOLD > 1)
			// Dont even start a thread if we arent low health
			if ((get HEALTH) > HEALTH_SMOKE_THRESHOLD) return (100);
			// Dont start a thread if we are being built
			if (get BUILD_PERCENT_LEFT) return (100);
			// Start a thread if werent previously smoking
			if (isSmoking == 0)	{ 
				isSmoking = 1;
				start-script DamagedSmoke();
			}	
		#endif
		// this must be start-scripted, because we need to return the full damage taken immediately
		start-script HitByWeapon(damage, anglez, anglex); //I dont know why param order must be switched, and this also runs a frame later :(
		return (100); //return damage percent
	}

	HitByWeapon(anglex, anglez, damageamount)	// angle[x|z] is always [-500;500], but engine does not give us damage, hence the need for HitByWeaponId
	{
		damageamount = damageamount / (100 * UNITSIZE);
		if (damageamount < 3  ) return (0);
		if (damageamount > MAXTILT) damageamount = MAXTILT;
		turn BASEPIECE to z-axis (anglez * damageamount) / 100  speed HITSPEED;
		turn BASEPIECE to x-axis <0> - (anglex * damageamount) /100 speed HITSPEED;
		
		// The astute will notice that since the speed on both axes is the same, these will wait more. 
		// This looks subjectively better than an even speed along both axes
		wait-for-turn BASEPIECE around z-axis;
		wait-for-turn BASEPIECE around x-axis;
		turn BASEPIECE to z-axis <0.000000> speed HITSPEED / 4;
		turn BASEPIECE to x-axis <0.000000> speed HITSPEED / 4;
	}
#else
	HitByWeapon(anglex, anglez)	// angle[x|z] is always [-500;500], but engine does not give us damage, hence the need for HitByWeaponId
	{
		#if (HEALTH_SMOKE_THRESHOLD > 1)
			// Dont even start a thread if we arent low health
			if ((get HEALTH) > HEALTH_SMOKE_THRESHOLD) return (100);
			// Dont start a thread if we are being built
			if (get BUILD_PERCENT_LEFT) return (100);
			// Start a thread if werent previously smoking
			if (isSmoking == 0)	{ 
				isSmoking = 1;
				start-script DamagedSmoke();
			}	
		#endif
	}
#endif

DamagedSmoke() // ah yes, clever use of stack variables 
{
	var current_health_pct; // [0-100]
	while( TRUE )
	{
		current_health_pct = get HEALTH;
		if (current_health_pct > HEALTH_SMOKE_THRESHOLD) {
			isSmoking = 0;
			return;
		}

		if (current_health_pct < 4) current_health_pct = 4;

		// Less health means blacker smoke
		if( Rand( 1, HEALTH_SMOKE_THRESHOLD ) < current_health_pct ) {
			emit-sfx 257 from BASEPIECE;
		}
		else {
			emit-sfx 258 from BASEPIECE;
		}

		// Sleep after emission to get immediate visual of unit taking damage via smoke effect
		sleep (current_health_pct * 50);
	}
}

