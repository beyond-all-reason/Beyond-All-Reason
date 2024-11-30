/*
Header Name: Smart Weapon Select
Purpose: Automatically switch between a preferred and backup weapo (E.G high/low trajectory)
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

static-var switchAimModeFrame, queueLowFrame, gameFrame, OverrideAimingState, AimingState, DisableLowAimFailureWatch;

#define __SMARTSELECT_H_

#define RESET_LOW_DELAY_FRAMES				15
#define RESET_HIGH_DELAY_FRAMES				450
#define RESET_HIGH_ERRORSTATE_FRAMES		900
#define ERROR_BUFFER_FRAMES					75
#define ERROR_COOLDOWN_FRAMES				150
#define AIMING_NEITHER						0
#define AIMING_LOW							1
#define AIMING_HIGH							2
#define ERROR_DETECTED						2

OverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
		OverrideAimingState = AIMING_LOW;
	} else{
		OverrideAimingState = AIMING_HIGH;
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
	if (weaponNumber == AIMING_LOW && DisableLowAimFailureWatch != ERROR_DETECTED){
		switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
		AimingState = AIMING_LOW;
	} else if (queueLowFrame < gameFrame){
		if (DisableLowAimFailureWatch == ERROR_DETECTED){
			//if low aimed but failed to fire, aim high for longer because the target is probably in a limbo space between low and high.
			switchAimModeFrame = (gameFrame + RESET_HIGH_ERRORSTATE_FRAMES);
		} else{
			switchAimModeFrame = (gameFrame + RESET_HIGH_DELAY_FRAMES);
		}
		AimingState = AIMING_HIGH;
	}
}

ExecuteOverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW && DisableLowAimFailureWatch == FALSE){
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
		get PRINT(gameFrame, queueLowFrame, switchAimModeFrame, greatestReloadState);
		//check if the low weapon aimed but didn't fire.
		if ((DisableLowAimFailureWatch == FALSE) && //allows moving units to optionally suspend errorstate to prevent slow turret turn-rates from producing undesired errorstates
		(queueLowFrame > switchAimModeFrame) &&  //the low aim is actively trying to target something
		((gameFrame - greatestReloadState) < ERROR_COOLDOWN_FRAMES)){ //this isn't the first shot made within the last ERROR_COOLDOWN_FRAMES 1000 - 1000 = 50 < 150 = false
			DisableLowAimFailureWatch = ERROR_DETECTED;
		} else{
			DisableLowAimFailureWatch = FALSE;
		}
		AimingState = AIMING_NEITHER;
	}
	
	if (AimingState == AIMING_NEITHER){
		if (OverrideAimingState != AIMING_NEITHER){
			call-script ExecuteOverrideAimingState(OverrideAimingState);
			OverrideAimingState = AIMING_NEITHER;
		} else {
			call-script SetAimingState(weaponNumber);
		}
	}
}
#endif
