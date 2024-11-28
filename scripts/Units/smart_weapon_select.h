/* Rockunit.h -- Rock the unit when it fire a heavy weapon with lots of recoil */

#ifndef __SMARTSELECT_H_
#include "sfxtype.h"
#include "exptype.h"
static-var aimingState, switchAimModeFrame, queueLowFrame, firedLowFailed, gameFrame;

#define __SMARTSELECT_H_

#define RESET_LOW_DELAY_FRAMES				15
#define RESET_HIGH_DELAY_FRAMES				450
#define RESET_HIGH_ERRORSTATE_FRAMES		900
#define AIMING_NEITHER						0
#define AIMING_LOW							1
#define AIMING_HIGH							2
#define GAME_FRAME							134

OverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
			switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
			aimingState = AIMING_LOW;
	} else if ((weaponNumber == AIMING_HIGH)){
		switchAimModeFrame = (gameFrame + RESET_HIGH_DELAY_FRAMES);
		aimingState = AIMING_HIGH;
	}
}

SetAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
			switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
			aimingState = AIMING_LOW;
	} else if ((weaponNumber == AIMING_HIGH) && (queueLowFrame < gameFrame)){
		if (firedLowFailed == TRUE){
			//if low aimed but failed to fire, aim high for longer.
			switchAimModeFrame = (gameFrame + RESET_HIGH_ERRORSTATE_FRAMES);
		} else{
			switchAimModeFrame = (gameFrame + RESET_HIGH_DELAY_FRAMES);
		}
		aimingState = AIMING_HIGH;
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

		//prevent bonus shots, prevent unintentional
		if (highReloadState > lowReloadState ){
			greatestReloadState = highReloadState;
		} else{
			greatestReloadState = lowReloadState;
		}
		if (greatestReloadState > switchAimModeFrame){
			switchAimModeFrame = greatestReloadState;
		}

		//check if the low weapon aimed but didn't fire.
		if (((lowReloadState + RESET_LOW_DELAY_FRAMES) < gameFrame) && (queueLowFrame > switchAimModeFrame)){
			firedLowFailed = TRUE;
		} else{
			firedLowFailed = FALSE;
		}
		aimingState = AIMING_NEITHER;
	}
	
	if (aimingState == AIMING_NEITHER){
		call-script setAimingState(weaponNumber);
	}	
	return (aimingState);
}
#endif
