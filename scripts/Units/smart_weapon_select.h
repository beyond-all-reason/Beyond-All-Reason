/* Rockunit.h -- Rock the unit when it fire a heavy weapon with lots of recoil
.bos script integration checklist:
1. just before Create() function, #include "smart_weapon_select.h"
2. in Create(), call-script ExecuteOverrideAimingState(AIMING_LOW);
3. in low AimWeapon function, call-script SmartAimSelect(AIMING_LOW);
4. in low weapon, if (AimingState != AIMING_LOW){ return 0; }
5. in high AimWeapon function, call-script SmartAimSelect(AIMING_HIGH);
6. in high weapon, if (AimingState != AIMING_LOW){ return 0; }
  */

#ifndef __SMARTSELECT_H_

static-var switchAimModeFrame, queueLowFrame, DisableLowAimFailureWatch, gameFrame, OverrideAimingState, AimingState;

#define __SMARTSELECT_H_

#define RESET_LOW_DELAY_FRAMES				15
#define RESET_HIGH_DELAY_FRAMES				450
#define RESET_HIGH_ERRORSTATE_FRAMES		900
#define ERROR_BUFFER_FRAMES					75
#define AIMING_NEITHER						0
#define AIMING_LOW							1
#define AIMING_HIGH							2
#define ERROR_DETECTED						2

OverrideAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW){
		OverrideAimingState = AIMING_LOW;
	} else if ((weaponNumber == AIMING_HIGH)){
		OverrideAimingState = AIMING_HIGH;
	}
	var highReloadState, lowReloadState, greatestReloadState;
	highReloadState = (get WEAPON_RELOADSTATE(AIMING_HIGH));
	lowReloadState = (get WEAPON_RELOADSTATE(AIMING_LOW));

	//prevent bonus shots
	if (highReloadState > lowReloadState ){
		greatestReloadState = highReloadState;
	} else{
		greatestReloadState = lowReloadState;
	}
	switchAimModeFrame = greatestReloadState;
}

ClearOverrideAimingState()
{
	OverrideAimingState = AIMING_NEITHER;
}

SetAimingState(weaponNumber)
{
	if (weaponNumber == AIMING_LOW && DisableLowAimFailureWatch != ERROR_DETECTED){
		switchAimModeFrame = (gameFrame + RESET_LOW_DELAY_FRAMES);
		AimingState = AIMING_LOW;
	} else if (queueLowFrame < gameFrame){
		if (DisableLowAimFailureWatch == ERROR_DETECTED){
			//if low aimed but failed to fire, aim high for longer.
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

		//check if the low weapon aimed but didn't fire.
		if ((DisableLowAimFailureWatch == FALSE) && ((lowReloadState + ERROR_BUFFER_FRAMES) <= gameFrame) && (queueLowFrame > switchAimModeFrame)){ //doubled to ensure the error is a firm error
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
