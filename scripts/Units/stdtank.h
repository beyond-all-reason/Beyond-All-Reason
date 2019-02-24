/* stdtank.h -- Standard Tank scripts

   The following variables are assumed to exist:

		AimHeading
		AimPitch
		bSuccessfulAim

   The following piecenames are expected:

		turret
		barrel
		flash

*/

#ifndef __STDTANK_H_
#define __STDTANK_H_


AimPrimary( heading, pitch )
{
	// Save where we are going to check if we were interrupted

	AimHeading = heading;
	AimPitch = pitch;
	bSuccessfulAim = FALSE;

	turn turret to y-axis heading speed turretspeed;
	turn barrel to x-axis (0 - pitch) speed barrelspeed;

	wait-for-turn turret around y-axis;
	wait-for-turn barrel around x-axis;

	// If we were the one controlling this (somebody else was not in the way,)
	// 	then mark that the placement is correct

	if (AimHeading == heading AND AimPitch == pitch)
	{
		bSuccessfulAim = TRUE;
	}

	// We don't have to have been the one who initiated the movement,
	// 	but if it is correct, we can still tell the system, since it
	// 	only keeps track of its last request.

	return( bSuccessfulAim );
}


#ifndef STDTANK_NO_FIRECANNON
FirePrimary()
{
	dont-cache barrel;
	dont-cache turret;

	// Recoil

	move barrel to z-axis [-2.4] speed [500];
	wait-for-move barrel along z-axis;

	// Recoil recover

	move barrel to z-axis [0] speed [3.0];

	// Muzzle flash

	show flash;
	sleep 150;

	hide flash;
	wait-for-move barrel along z-axis;

	cache barrel;
	cache turret;
}
#endif

#endif
