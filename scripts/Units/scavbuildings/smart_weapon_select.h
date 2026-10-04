/*
Header Name: Smart Weapon Select
Purpose: Automatically switch between a preferred and backup weapon (E.G high/low trajectory)
Author: SethDGamre SethDGamre@Gmail.com
License: GPL V2.0

By including this header file, you can have two weapons dynamically selected. AIMING_PRIORITY trajectory is preferred
and if it fails AIMING_BACKUP is allowed to steal for a period of time outlined in the #defines below. This aiming
script is required to work in conjunction with a gadget unit_weapon_smart_select_helper.lua which handles and feeds
to this script the manual targetting events.

.bos script integration checklist:

1. somewhere before Create() function:
#include "smart_weapon_select.h"

2. in the preferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_PRIORITY)
	{
		return(0);
	}
3. in the deferred AimWeaponX() function, add the following at the beginning:
	if (AimingState != AIMING_BACKUP)
	{
		return(0);
	}
4. If using a dummy weapon, return (0); in its AimWeaponX() function and QueryWeaponX(piecenum) should be set to a static piece lower than the turret.
	This is necessary until engine changes allow for abritrary XYZ source coordinates for cannon projectiles in Spring.GetWeaponHaveFreeLineOfFire. At which point,
	dummy weapons should be removed and source position should be fed directly into the function via the gadget unit_weapon_smart_select_helper.lua

  */

#ifndef __SMARTSELECT_H_

static-var AimingState;

#define __SMARTSELECT_H_

#define AIMING_PRIORITY		0
#define AIMING_BACKUP		1

SetAimingState(newState)
{
	if (newState == AIMING_PRIORITY){
		AimingState = AIMING_PRIORITY;
	} else{
		AimingState = AIMING_BACKUP;
	}
}

#endif
