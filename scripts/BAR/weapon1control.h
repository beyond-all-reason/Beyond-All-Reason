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
	start-script Weapon1SetWtdAim(heading, pitch);
	[...]
	return (aim1);
}

RestoreAfterDelay()
{
	[...]
	sleep sleeptime;
	start-script RestoreWeapon1();
	[...] -- other animations;
	call-script Weapon1Restored();
	[...] -- tell script wpn has been restored if needed for walkscripts
}

- Weapon1Control moves the aim pieces depending on turretSpeeds, sets pitch = 1 when pitch reached and head = 1 when head reached
- Weapon1Drawn allows unit to fire by setting wpnReady1 = 1
- if pitch = 1, head = 1 and wpnReady = 1 then the weapon can shoot: aim1 = 1 and aimweapon returns aim1
- Restore animations go in RestoreAfterDelay, RestoreWeapon1() restores aimy and aimx pieces orientation, Weapon1Restored() waits for these pieces to be restored
*/

static-var curHead1, wtdHead1, head1, curPitch1, wtdPitch1, pitch1, aim1, wpnReady1;

Weapon1Control()
{
	while (TRUE)
	{
		if (curHead1 > <180>)
		{
			curHead1 = <-360> + curHead1;
		}
		if (curPitch1 > <180>)
		{
			curPitch1 = <-360> + curPitch1;
		}
		if (curHead1 < <-180>)
		{
			curHead1 = <360> + curHead1;
		}
		if (curPitch1 < <-180>)
		{
			curPitch1 = <360> + curPitch1;
		}
		if (Static_Var_3 == 1)
		{
			if (((get ABS(curHead1 - wtdHead1)) > <360>) OR(((get ABS(curHead1 - wtdHead1)) > (Weapon1TurretY / 30)) AND ((get ABS(curHead1 - wtdHead1)) < <360> - (Weapon1TurretY / 30))))
			{
				head1 = 0;
				if(curHead1 < wtdHead1) {
					if(get ABS(curHead1 - wtdHead1)< <180>)
					   curHead1 = curHead1 + (Weapon1TurretY / 30);
					else curHead1 = curHead1 - (Weapon1TurretY / 30);
					}

				else {
					if(get ABS(curHead1 - wtdHead1)< <180>)
					   curHead1 = curHead1 - (Weapon1TurretY / 30);
					else curHead1 = curHead1 + (Weapon1TurretY / 30);
					}
			}
			else
			{
				head1 = 1;
				curHead1 = wtdHead1;
			}
			if (((get ABS(curPitch1 - wtdPitch1)) > <360>) OR(((get ABS(curPitch1 - wtdPitch1)) > (Weapon1TurretX / 30)) AND ((get ABS(curPitch1 - wtdPitch1)) < <360> - (Weapon1TurretX / 30))))
			{
				pitch1 = 0;
				if(curPitch1 < wtdPitch1) {
					if(get ABS(curPitch1 - wtdPitch1)< <180>)
					   curPitch1 = curPitch1 + (Weapon1TurretX / 30);
					else curPitch1 = curPitch1 - (Weapon1TurretX / 30);
					}

				else {
					if(get ABS(curPitch1 - wtdPitch1)< <180>)
					   curPitch1 = curPitch1 - (Weapon1TurretX / 30);
					else curPitch1 = curPitch1 + (Weapon1TurretX / 30);
					}
			}
			else
			{
				pitch1 = 1;
				curPitch1 = wtdPitch1;
			}
			if (pitch1 == 1 AND head1 == 1 AND wpnReady1 == 1 AND wtdHead1 != 0)
			{
				aim1 = 1;
			}
			else
			{
				aim1 = 0;
			}
			turn aimy1 to y-axis curHead1 now;
			turn aimx1 to x-axis curPitch1 now;
		}
		sleep 1;
	}
}

InitialSetup1()
{
	curHead1 = 0;
	curPitch1 = 0;
	wtdHead1 = 0;
	wtdPitch1 = 0;
	wpnReady1 = 0;
	start-script Weapon1Control();
}

Weapon1Drawn()
{
	wpnReady1 = 1;
}

RestoreWeapon1()
{
	wtdHead1 = 0;
	wtdPitch1 = 0;
}

Weapon1Restored()
{
	wpnReady1 = 0;
	while (curHead1 != 0)
	{
		sleep 25;
	}
	return (TRUE);
}

Weapon1SetWtdAim(pitch, heading)
{
	wtdHead1 = heading;
	wtdPitch1 = <0> - pitch;
}