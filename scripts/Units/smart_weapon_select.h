/*
Header Name: Smart Weapon Select
Purpose: Automatically switch between a preferred and backup weapon (E.G high/low trajectory)
Author: SethDGamre SethDGamre@Gmail.com
License: GPL V2.0

By including this header file, you can have two weapons dynamically selected. AIMING_LOW trajectory is preferred
and if it fails AIMING_HIGH is allowed to steal for a period of time outlined in the #defines below. This aiming
script is required to work in conjunction with a gadget unit_weapon_smart_select_helper.lua which handles and feeds
to this script the manual targetting events.

.bos script integration checklist:

1. somewhere before Create() function:
#include "smart_weapon_select.h"

2. in beginning of low AimWeapon function:
if (AimingState != AIMING_PREFERRED){ 
	return 0;
}

3. in beginning of high AimWeapon function:
if (AimingState != AIMING_DEFERRED){ 
	return 0;
}
  */

#ifndef __SMARTSELECT_H_

static-var AimingState;

#define __SMARTSELECT_H_

#define AIMING_PREFERRED	1
#define AIMING_DEFERRED		2

SetAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_PREFERRED){
		AimingState = AIMING_PREFERRED;
	} else{
		AimingState = AIMING_DEFERRED;
	}
}

#endif
