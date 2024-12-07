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
call-script SmartAimSelect(AIMING_LOW);
if (AimingState != AIMING_LOW){ 
	return 0;
}

3. in beginning of high AimWeapon function:
call-script SmartAimSelect(AIMING_LOW);
if (AimingState != AIMING_LOW){ 
	return 0;
}

4. OPTIONAL: if unit's movement turn speed can exceed its turret turn speed, place this before call-script SmartAimSelect(AIMING_LOW);
if (bMoving == TRUE){
	DisableLowAimFailureWatch = TRUE;
} else if (DisableLowAimFailureWatch == TRUE){
	DisableLowAimFailureWatch = FALSE;
}
  */

#ifndef __SMARTSELECT_H_

static-var AimingState;

#define __SMARTSELECT_H_

#define AIMING_LOW							1
#define AIMING_HIGH							2

OverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
		aimingState = AIMING_LOW;
	} else{
		aimingState = AIMING_HIGH;
	}
}

#endif
