/*
HOW TO:
- Model MUST contain aimx1 and aimy1 pieces
- Script must have defined Weapon1TurretX and Weapon1TurretY static-vars (turret turn speeds)
- Script must have defined aimx1 and aimy1 pieces
- Change script as such:
Create()
{
	[...]
	start-script InitialSetup1();
	[...]
}

AimWeapon1(heading, pitch)
{
	[...]
	start-script Weapon1Drawn(); -- can call a function that draws weapons and then calls Weapon1Drawn() when done if there is an actual animation (ie pw)
	[...] -- Remove animations from aimWeapon scripts (use a DrawWeapon1() if an animation is needed, weapon1control will rotate the different aimpieces)
	start-script Weapon1SetWantedAim(heading, pitch);
	[...]
	return (canFire);
}

static-var  Stunned;
ExecuteRestoreAfterDelay()
{
    if (Stunned) {
        return (1);
    }
	start-script RestoreWeapon1();
 
	[...] -- other animations;
	call-script Weapon1Restored();
	[...] -- tell script wpn has been restored if needed for walkscripts
}
SetStunned(State)
{
    Stunned = State;
	if (!Stunned) {
	    start-script ExecuteRestoreAfterDelay();
	}
}
RestoreAfterDelay()
{
	[...]
	sleep sleeptime;
	start-script ExecuteRestoreAfterDelay();
}

- Weapon1Control moves the aim pieces depending on turretSpeeds, sets pitch = 1 when pitch reached and head = 1 when head reached
- Weapon1Drawn allows unit to fire by setting wpnReady1 = 1
- if pitch = 1, head = 1 and wpnReady = 1 then the weapon can shoot: canFire = 1 and aimweapon returns canFire
- Restore animations go in RestoreAfterDelay, RestoreWeapon1() restores aimy and aimx pieces orientation, Weapon1Restored() waits for these pieces to be restored
- Avoid wait-for-turn in AimWeapon and/or Weapon1Control as much as possible. If you have to (ie DrawWeapon1 of armpw, make sure you don't have multiple turns stacking with different goals

Notes 2024.04 Beherith
-- Static_Var_Weapon1Control is unused
-- Refactoring to use better, simpler code
-- (1.0 us mean instead of 3us)
-- Remember, that when start-scripted, Weapon1Control runs 1 frame late, this is bad on a reaimtime of 2
-- because the new aim thread will terminate the old one, hence the need for SIGNAL_CUSTOM
*/

static-var curHead1, wantedHead1, curPitch1, wantedPitch1, canFire, wpnReady1;


Weapon1Control()
{
	
	signal SIGNAL_CUSTOM;
	set-signal-mask SIGNAL_CUSTOM;
	var deltaangle;
	
	while (TRUE)
	{
		// Start off assuming that we are ready to fire:
		canFire = 1;

		deltaangle = WRAPDELTA(curHead1 - wantedHead1);

		//dbg(curHead1, curPitch1, deltaangle);
		
		// If we are further off than how much we can turn in one frame, then we arent ready
		if (ABSOLUTE_GREATER_THAN(deltaangle,(Weapon1TurretY / 30))){
			// We arent ready to fire: 
			canFire = 0;
			curHead1 = curHead1 - (SIGN(deltaangle))* (Weapon1TurretY / 30);
		}else{
			curHead1 = wantedHead1;
		}

		// Calculate current difference between wanted and actual angle:
		deltaangle = WRAPDELTA(curPitch1 - wantedPitch1);
		// If we are further off than how much we can turn in one frame, then we arent ready
		if (ABSOLUTE_GREATER_THAN(deltaangle,(Weapon1TurretX / 30))){
			// We arent ready to fire: 
			canFire = 0;
			curPitch1 = curPitch1 - (SIGN(deltaangle))* (Weapon1TurretX / 30);
		}else{
			curPitch1 = wantedPitch1;
		}

		canFire = canFire && wpnReady1;
		// Do it with speed instead of now so that the execution of these can be done in a multithreaded way
		turn aimy1 to y-axis curHead1 speed Weapon1TurretY;
		turn aimx1 to x-axis curPitch1 speed Weapon1TurretX;

		// Bailing out doesnt work well, as it leaves canFire in a true state, remember to:
		// canfire = ABSOLUTE_LESS_THAN(WRAPDELTA(heading - curHead1),(Weapon1TurretX / 30));
		if (canFire) return 0;
		else sleep 32;
	}
}

InitialSetup1()
{
	curHead1 = 0;
	curPitch1 = 0;
	wantedHead1 = 0;
	wantedPitch1 = 0;
	wpnReady1 = 0;
	start-script Weapon1Control();
}

#define Weapon1Drawn() wpnReady1 = 1


RestoreWeapon1()
{
	wantedHead1 = 0;
	wantedPitch1 = 0;
	start-script Weapon1Control();
}

Weapon1Restored()
{
	wpnReady1 = 0;
	while (curHead1 != 0)
	{
		sleep 25;
	}
	
	signal SIGNAL_CUSTOM;
}

#define Weapon1SetWantedAim(heading, pitch) wantedHead1 = heading; wantedPitch1 = <0> - pitch;
/*
Weapon1SetWantedAim(pitch, heading)
{
	wantedHead1 = heading;
	wantedPitch1 = <0> - pitch;
}*/