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

// **OPTIONAL**
//if turret turn speeds cause shots not to fire in time to prevent lengthy errorstate high trajectory, define these before the #include. Both these conditions must be met to trigger.
//the maximum age of a reload frame to be allowed to trigger an error state
#ifndef ERROR_RECENCY_FRAMES
#define ERROR_RECENCY_FRAMES				300
#endif

//how long it takes for an attempt to aim and fire times out triggering error state
#ifndef ERROR_MISFIRE_FRAMES
#define ERROR_MISFIRE_FRAMES				120
#endif
//**END OPTIONAL**

#ifndef __SMARTSELECT_H_

static-var switchAimModeFrame, gameFrame, forceAimingState, queueLowFrame, AimingState, DisableLowAimFailureWatch;

#define __SMARTSELECT_H_

#define RESET_LOW_DELAY_FRAMES				30
#define RESET_HIGH_DELAY_FRAMES				450
#define RESET_HIGH_ERRORSTATE_FRAMES		900
#define AIMING_NEITHER						0
#define AIMING_LOW							1
#define AIMING_HIGH							2
#define ERROR_DETECTED						2

OverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
		forceAimingState = AIMING_LOW;
	} else{
		forceAimingState = AIMING_HIGH;
	}

	//to prevent bonus shots from switching weapons shortly after firing the other fired.
	var highReloadState, lowReloadState, greatestReloadState;
	highReloadState = (get WEAPON_RELOADSTATE(AIMING_HIGH));
	lowReloadState = (get WEAPON_RELOADSTATE(AIMING_LOW));

	if (highReloadState > lowReloadState ){
		greatestReloadState = highReloadState;
	} else{
		greatestReloadState = lowReloadState;
	}
	switchAimModeFrame = greatestReloadState;
}

SetAimingState(weaponNumber)
{
	if (DisableLowAimFailureWatch == ERROR_DETECTED){
			//if low aimed but failed to fire, aim high for longer because the target is probably in a limbo space between low and high.
			switchAimModeFrame = (gameFrame + RESET_HIGH_ERRORSTATE_FRAMES);
			AimingState = AIMING_HIGH;
	} else if (weaponNumber == AIMING_LOW){
		switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
		AimingState = AIMING_LOW;
	} else if (queueLowFrame < gameFrame){
			switchAimModeFrame = (gameFrame + RESET_HIGH_DELAY_FRAMES);
			AimingState = AIMING_HIGH;
	}
}

ExecuteforceAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
		switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
		AimingState = AIMING_LOW;
	} else{
		switchAimModeFrame = (gameFrame + RESET_HIGH_DELAY_FRAMES);
		AimingState = AIMING_HIGH;
	}
}

SmartAimSelect(weaponNumber)
{
	var highReloadState, lowReloadState, greatestReloadState;
	gameFrame = (get GAME_FRAME);

	//define a period where low is given priority to steal.
	if (weaponNumber == AIMING_LOW){
		queueLowFrame = (switchAimModeFrame + RESET_LOW_DELAY_FRAMES);
	}

	if (switchAimModeFrame < gameFrame){
		highReloadState = (get WEAPON_RELOADSTATE(AIMING_HIGH));
		lowReloadState = (get WEAPON_RELOADSTATE(AIMING_LOW));

		//prevent bonus shots
		if (highReloadState > lowReloadState ){
			greatestReloadState = highReloadState;
		} else{
			greatestReloadState = lowReloadState;
		}
		if (greatestReloadState > switchAimModeFrame){
			switchAimModeFrame = greatestReloadState;
		}
		//check if the low weapon aimed but didn't fire.
		if ((DisableLowAimFailureWatch == FALSE) && //allows moving units to optionally suspend errorstate to prevent slow turret turn-rates from producing undesired errorstates
		(weaponNumber == AIMING_LOW) &&  //the low aim is actively trying to target something
		(greatestReloadState > gameFrame - ERROR_RECENCY_FRAMES) && //this isn't the first shot made within the last ERROR_COOLDOWN_FRAMES
		(greatestReloadState < gameFrame - ERROR_MISFIRE_FRAMES)){  //it hasn't fired within the last 
			DisableLowAimFailureWatch = ERROR_DETECTED;
		} else{
			DisableLowAimFailureWatch = FALSE;
		}
		AimingState = AIMING_NEITHER;
	}
	
	if (AimingState == AIMING_NEITHER){
		if (forceAimingState != AIMING_NEITHER){
			call-script ExecuteforceAimingState(forceAimingState);
			forceAimingState = AIMING_NEITHER;
		} else {
			call-script SetAimingState(weaponNumber);
		}
	}
}

#endif
