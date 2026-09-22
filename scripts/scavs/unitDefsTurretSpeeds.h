/* unitDefsTurretSpeeds.h -- sets turret speed via unitDefs (through lua gadget Spring.CallCOBScript())
   The following variables are assumed to exist:
		Weapon1TurretX, Weapon1TurretY
		...
		Weapon10TurretX, Weapon10TurretY
   Define TURRET_SPEED_WEAPONS before including this file to compile only weapons 1 through that number.
*/

#ifndef TURRET_SPEED_WEAPONS
	#define TURRET_SPEED_WEAPONS 10
#endif

static-var Weapon1TurretX, Weapon1TurretY;
SetTurretSpeedWeapon1(var1,var2)
{
	Weapon1TurretX = var1;
	Weapon1TurretY = var2;	
}

#if TURRET_SPEED_WEAPONS >= 2
static-var Weapon2TurretX, Weapon2TurretY;
SetTurretSpeedWeapon2(var1,var2)
{
	Weapon2TurretX = var1;
	Weapon2TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 3
static-var Weapon3TurretX, Weapon3TurretY;
SetTurretSpeedWeapon3(var1,var2)
{
	Weapon3TurretX = var1;
	Weapon3TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 4
static-var Weapon4TurretX, Weapon4TurretY;
SetTurretSpeedWeapon4(var1,var2)
{
	Weapon4TurretX = var1;
	Weapon4TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 5
static-var Weapon5TurretX, Weapon5TurretY;
SetTurretSpeedWeapon5(var1,var2)
{
	Weapon5TurretX = var1;
	Weapon5TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 6
static-var Weapon6TurretX, Weapon6TurretY;
SetTurretSpeedWeapon6(var1,var2)
{
	Weapon6TurretX = var1;
	Weapon6TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 7
static-var Weapon7TurretX, Weapon7TurretY;
SetTurretSpeedWeapon7(var1,var2)
{
	Weapon7TurretX = var1;
	Weapon7TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 8
static-var Weapon8TurretX, Weapon8TurretY;
SetTurretSpeedWeapon8(var1,var2)
{
	Weapon8TurretX = var1;
	Weapon8TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 9
static-var Weapon9TurretX, Weapon9TurretY;
SetTurretSpeedWeapon9(var1,var2)
{
	Weapon9TurretX = var1;
	Weapon9TurretY = var2;	
}
#endif

#if TURRET_SPEED_WEAPONS >= 10
static-var Weapon10TurretX, Weapon10TurretY;
SetTurretSpeedWeapon10(var1,var2)
{
	Weapon10TurretX = var1;
	Weapon10TurretY = var2;	
}
#endif