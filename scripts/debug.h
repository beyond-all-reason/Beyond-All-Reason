// This debugging header defines a lua debugging function as a helper
/*



*/

python code to generate all known callins and masks

numweapons = 6
weaponfuncs = [('AimWeapon',2), ('AimFromWeapon',1), ('FireWeapon',0), ('Shot',0), ('QueryWeapon',0), ('EndBurst',0), ('BlockShot',3), ('TargetWeight',2)]
otherfuncsparams = [
	('Create',0), 
	('Activate',0), 
	('Deactivate',0),
	('StartMoving',1),
	('StopMoving',0),
	('SetSFXOccupy',1),
	('MoveRate0',0),
	('MoveRate1',0),
	('MoveRate2',0),
	('MoveRate3',0),
	('SetDirection',1),
	('SetSpeed',0),
	('RockUnit',2),
	('HitByWeapon',2),
	('HitByWeaponID',4),
	('SetMaxReloadTime',1),
	('StartBuilding',2),
	('StopBuilding',0),
	('QueryNanoPiece',1),
	('QueryBuildInfo',1),
	('Falling',0),
	('Landed',0),
	('QueryTransport',1),
	('BeginTransport',1),
	('EndTransport',0),
	('TransportPickup',1),
	('TransportDrop',2),
	('StartUnload',0),
	('QueryLandingPadCount',1),
	('QueryLandingPad',0),

	]

#ifdef DEBUG
lua_CobDebug(callerID, line, param1, param2)
{
	param1 = param1;
	return 0;
	
	
	
	
}
	// known callins:
	#define CREATE 			1
	#define ACTIVATE 		2
	#define DEACTIVATE		3
	#define KILLED 			4
	#define STARTMOVING 	5
	#define STOPMOVING 		6
	
	#define AIMWEAPON1 		10
	#define AIMFROMWEAPON1 	11
	#define FireWeapon1 	12
	#define Shot1			13
	#define QueryWeapon1	14
	#define EndBurst1		15
	#define BlockShot1		16
	#define TargetWeight1	17
	
	#define AIMWEAPON2 		20
	#define AIMFROMWEAPON2 	22
	#define FireWeapon2 	22
	#define Shot2			23
	#define QueryWeapon2	24
	#define EndBurst2		25
	#define BlockShot2		26
	#define TargetWeight2	27
	
	#define AIMWEAPON3 		30
	#define AIMFROMWEAPON3 	33
	#define FireWeapon3 	32
	#define Shot3			33
	#define QueryWeapon3	34
	#define EndBurst3		35
	#define BlockShot3		36
	#define TargetWeight3	37
	
	#define AIMWEAPON4 		40
	#define AIMFROMWEAPON4 	44
	#define FireWeapon4 	42
	#define Shot4			43
	#define QueryWeapon4	44
	#define EndBurst4		45
	#define BlockShot4		46
	#define TargetWeight4	47
	
	#define AIMWEAPON5 		50
	#define AIMFROMWEAPON5 	55
	#define FireWeapon5 	52
	#define Shot5			53
	#define QueryWeapon5	54
	#define EndBurst5		55
	#define BlockShot5		56
	#define TargetWeight5	57
	
	#define AIMWEAPON6 		60
	#define AIMFROMWEAPON6 	66
	#define FireWeapon6 	62
	#define Shot6			63
	#define QueryWeapon6	64
	#define EndBurst6		65
	#define BlockShot6		66
	#define TargetWeight6	67
	
	#define AIMWEAPON7 		70
	#define AIMFROMWEAPON7 	77
	#define FireWeapon7 	72
	#define Shot7			73
	#define QueryWeapon7	74
	#define EndBurst7		75
	#define BlockShot7		76
	#define TargetWeight7	77
	
	#define MOVERATE0 		80
	#define MOVERATE1 		81
	#define MOVERATE2 		82
	#define MOVERATE3 		83
	#define SETDIRECTION 	84
	#define SETSPEED 		85
	#define SETSPEED 		85
	#define SETSPEED 		85
	#define SETSPEED 		85
	#define SETSPEED 		85
	#define SETSPEED 		85
	#define SETSPEED 		85
	
	#define RockUnit		

	// the -3 is needed because of the 
	#define	DEBUGFUNC(callerID, param1, param2) call-script lua_CobDebug(callerID, __LINE__, param1, param2)

	#ifdef WRAPFUNCTIONS
		#define Create() Create(){call-script lua_CobDebug(CREATE, __LINE__, 0,0); call-script wrap_Create();} \
			wrap_Create()
	#endif

#else
	#define DEBUGFUNC(a,b) 
#endif

