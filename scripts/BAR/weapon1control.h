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

Weapon1SetWtdAim(heading, pitch)
{
	wtdHead1 = heading;
	wtdPitch1 = <0> - pitch;
}