// This debugging header defines a lua debugging function as a helper
//
// 1. Include this file
// #include "../debug.h"
//
// 2. Before the include, specify if you want debugging on with:
//	#define DEBUG
//	- If the above define is not present, nothing is output, and all debug commands are stripped from the compiled file
//	- So that means that you can leave in your instrumention, just comment the #define DEBUG (leave in the include file though!)
//
// 3. RECOMMENDED USAGE: To write a debug message at any point use 
//	dbg(args);
//	- This will also smartly print out what line of the BOS file the print comes from
//	- You can pass up to 8 arguments
//	- Note that to figure out which function this was called from, the Lua counterpart of this debug header (dbg_cob_debug.lua) will read the .bos file 
//
// 4. Interpret infolog.
//	f:<25805.0> u:05541 corsolar.Open:74  p1=5 p2=6 p3=7 p4=8
//	- f:<gameframe.order> can tell you what gameframe it happened in, and also the order within the gameframe, as often things get called multiple times during a gameframe
//	- u:05541 is the unitID
//	- corsolar.Open:74  unitDefName, the name of the BOS function (unless vanilla dbg()), and the line of BOS code it came from
//	- p1=5 p2=6 p3=7 p4=8  values of any parameters passed
//  - Note that dbg(); seems to interfere with the return value of the AimWeapon function (always returning 1 when there is a dbg(); call present)
//  E.g.:
//  Open(){
//  	dbg(5,6,7,8); // will show this in console and infolog: f:<25805.0> u:05541 corsolar.Open:74  p1=5 p2=6 p3=7 p4=8
//  }
//
// 5. To write a debug message with a known callin, like in Activate, use:
//	dbg_Activate(args,...);
//	-- This will also name the function and line. 
//
// 6. To print each time a builtin engine callin is called (see list below), rename the function like so:
//	Open() -> print_Open()
//	- Any arguments passed will also be forwarded correctly and printed out
//	- Do not print_FUNCTIONS whos return values you depend on, such as AimWeaponX, HitByWeaponID and Killed

// IMPORTANT NOTE:
// DO NOT print_ FUNCTIONS whos return values you need!

#ifdef DEBUG
lua_CobDebug(callerID, line, p1, p2, p3, p4, p5, p6, p7, p8)
{
	return (0);
}

	#define dbg(...) call-script lua_CobDebug(1, __LINE__, ## __VA_ARGS__ ); 
#else
	
	#define dbg(...)
#endif

#ifdef DEBUG
	#define dbg_signal(x) call-script lua_CobDebug(1000, __LINE__,x ); signal x// oooh not captureable
#else
	#define dbg_signal(x) signal x// oooh not captureable
#endif


#ifdef DEBUG
	#define print_Debug(...) Debug(__VA_ARGS__) {call-script lua_CobDebug(1, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Debug(__VA_ARGS__);} \
		wrap_Debug(__VA_ARGS__)
	#define dbg_Debug(...) call-script lua_CobDebug(1, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Debug(...) Debug(__VA_ARGS__)
	#define dbg_Debug(...)
#endif

#ifdef DEBUG
	#define print_Open(...) Open(__VA_ARGS__) {call-script lua_CobDebug(2, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Open(__VA_ARGS__);} \
		wrap_Open(__VA_ARGS__)
	#define dbg_Open(...) call-script lua_CobDebug(2, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Open(...) Open(__VA_ARGS__)
	#define dbg_Open(...)
#endif

#ifdef DEBUG
	#define print_Close(...) Close(__VA_ARGS__) {call-script lua_CobDebug(3, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Close(__VA_ARGS__);} \
		wrap_Close(__VA_ARGS__)
	#define dbg_Close(...) call-script lua_CobDebug(3, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Close(...) Close(__VA_ARGS__)
	#define dbg_Close(...)
#endif

#ifdef DEBUG
	#define print_TryTransition(...) TryTransition(__VA_ARGS__) {call-script lua_CobDebug(4, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TryTransition(__VA_ARGS__);} \
		wrap_TryTransition(__VA_ARGS__)
	#define dbg_TryTransition(...) call-script lua_CobDebug(4, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TryTransition(...) TryTransition(__VA_ARGS__)
	#define dbg_TryTransition(...)
#endif

#ifdef DEBUG
	#define print_Killed(...) Killed(__VA_ARGS__) {call-script lua_CobDebug(5, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Killed(__VA_ARGS__);} \
		wrap_Killed(__VA_ARGS__)
	#define dbg_Killed(...) call-script lua_CobDebug(5, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Killed(...) Killed(__VA_ARGS__)
	#define dbg_Killed(...)
#endif

#ifdef DEBUG
	#define print_ExecuteRestoreAfterDelay(...) ExecuteRestoreAfterDelay(__VA_ARGS__) {call-script lua_CobDebug(6, __LINE__, ## __VA_ARGS__ ); call-script  wrap_ExecuteRestoreAfterDelay(__VA_ARGS__);} \
		wrap_ExecuteRestoreAfterDelay(__VA_ARGS__)
	#define dbg_ExecuteRestoreAfterDelay(...) call-script lua_CobDebug(6, __LINE__, ## __VA_ARGS__ );
#else
	#define print_ExecuteRestoreAfterDelay(...) ExecuteRestoreAfterDelay(__VA_ARGS__)
	#define dbg_ExecuteRestoreAfterDelay(...)
#endif

#ifdef DEBUG
	#define print_SetStunned(...) SetStunned(__VA_ARGS__) {call-script lua_CobDebug(7, __LINE__, ## __VA_ARGS__ ); call-script  wrap_SetStunned(__VA_ARGS__);} \
		wrap_SetStunned(__VA_ARGS__)
	#define dbg_SetStunned(...) call-script lua_CobDebug(7, __LINE__, ## __VA_ARGS__ );
#else
	#define print_SetStunned(...) SetStunned(__VA_ARGS__)
	#define dbg_SetStunned(...)
#endif

#ifdef DEBUG
	#define print_Walk(...) Walk(__VA_ARGS__) {call-script lua_CobDebug(8, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Walk(__VA_ARGS__);} \
		wrap_Walk(__VA_ARGS__)
	#define dbg_Walk(...) call-script lua_CobDebug(8, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Walk(...) Walk(__VA_ARGS__)
	#define dbg_Walk(...)
#endif

#ifdef DEBUG
	#define print_StopWalking(...) StopWalking(__VA_ARGS__) {call-script lua_CobDebug(9, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StopWalking(__VA_ARGS__);} \
		wrap_StopWalking(__VA_ARGS__)
	#define dbg_StopWalking(...) call-script lua_CobDebug(9, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StopWalking(...) StopWalking(__VA_ARGS__)
	#define dbg_StopWalking(...)
#endif

#ifdef DEBUG
	#define print_Create(...) Create(__VA_ARGS__) {call-script lua_CobDebug(10, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Create(__VA_ARGS__);} \
		wrap_Create(__VA_ARGS__)
	#define dbg_Create(...) call-script lua_CobDebug(10, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Create(...) Create(__VA_ARGS__)
	#define dbg_Create(...)
#endif

#ifdef DEBUG
	#define print_Activate(...) Activate(__VA_ARGS__) {call-script lua_CobDebug(11, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Activate(__VA_ARGS__);} \
		wrap_Activate(__VA_ARGS__)
	#define dbg_Activate(...) call-script lua_CobDebug(11, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Activate(...) Activate(__VA_ARGS__)
	#define dbg_Activate(...)
#endif

#ifdef DEBUG
	#define print_Deactivate(...) Deactivate(__VA_ARGS__) {call-script lua_CobDebug(12, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Deactivate(__VA_ARGS__);} \
		wrap_Deactivate(__VA_ARGS__)
	#define dbg_Deactivate(...) call-script lua_CobDebug(12, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Deactivate(...) Deactivate(__VA_ARGS__)
	#define dbg_Deactivate(...)
#endif

#ifdef DEBUG
	#define print_StartMoving(...) StartMoving(__VA_ARGS__) {call-script lua_CobDebug(13, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StartMoving(__VA_ARGS__);} \
		wrap_StartMoving(__VA_ARGS__)
	#define dbg_StartMoving(...) call-script lua_CobDebug(13, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StartMoving(...) StartMoving(__VA_ARGS__)
	#define dbg_StartMoving(...)
#endif

#ifdef DEBUG
	#define print_StopMoving(...) StopMoving(__VA_ARGS__) {call-script lua_CobDebug(14, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StopMoving(__VA_ARGS__);} \
		wrap_StopMoving(__VA_ARGS__)
	#define dbg_StopMoving(...) call-script lua_CobDebug(14, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StopMoving(...) StopMoving(__VA_ARGS__)
	#define dbg_StopMoving(...)
#endif

#ifdef DEBUG
	#define print_SetSFXOccupy(...) SetSFXOccupy(__VA_ARGS__) {call-script lua_CobDebug(15, __LINE__, ## __VA_ARGS__ ); call-script  wrap_SetSFXOccupy(__VA_ARGS__);} \
		wrap_SetSFXOccupy(__VA_ARGS__)
	#define dbg_SetSFXOccupy(...) call-script lua_CobDebug(15, __LINE__, ## __VA_ARGS__ );
#else
	#define print_SetSFXOccupy(...) SetSFXOccupy(__VA_ARGS__)
	#define dbg_SetSFXOccupy(...)
#endif

#ifdef DEBUG
	#define print_MoveRate0(...) MoveRate0(__VA_ARGS__) {call-script lua_CobDebug(16, __LINE__, ## __VA_ARGS__ ); call-script  wrap_MoveRate0(__VA_ARGS__);} \
		wrap_MoveRate0(__VA_ARGS__)
	#define dbg_MoveRate0(...) call-script lua_CobDebug(16, __LINE__, ## __VA_ARGS__ );
#else
	#define print_MoveRate0(...) MoveRate0(__VA_ARGS__)
	#define dbg_MoveRate0(...)
#endif

#ifdef DEBUG
	#define print_MoveRate1(...) MoveRate1(__VA_ARGS__) {call-script lua_CobDebug(17, __LINE__, ## __VA_ARGS__ ); call-script  wrap_MoveRate1(__VA_ARGS__);} \
		wrap_MoveRate1(__VA_ARGS__)
	#define dbg_MoveRate1(...) call-script lua_CobDebug(17, __LINE__, ## __VA_ARGS__ );
#else
	#define print_MoveRate1(...) MoveRate1(__VA_ARGS__)
	#define dbg_MoveRate1(...)
#endif

#ifdef DEBUG
	#define print_MoveRate2(...) MoveRate2(__VA_ARGS__) {call-script lua_CobDebug(18, __LINE__, ## __VA_ARGS__ ); call-script  wrap_MoveRate2(__VA_ARGS__);} \
		wrap_MoveRate2(__VA_ARGS__)
	#define dbg_MoveRate2(...) call-script lua_CobDebug(18, __LINE__, ## __VA_ARGS__ );
#else
	#define print_MoveRate2(...) MoveRate2(__VA_ARGS__)
	#define dbg_MoveRate2(...)
#endif

#ifdef DEBUG
	#define print_MoveRate3(...) MoveRate3(__VA_ARGS__) {call-script lua_CobDebug(19, __LINE__, ## __VA_ARGS__ ); call-script  wrap_MoveRate3(__VA_ARGS__);} \
		wrap_MoveRate3(__VA_ARGS__)
	#define dbg_MoveRate3(...) call-script lua_CobDebug(19, __LINE__, ## __VA_ARGS__ );
#else
	#define print_MoveRate3(...) MoveRate3(__VA_ARGS__)
	#define dbg_MoveRate3(...)
#endif

#ifdef DEBUG
	#define print_SetDirection(...) SetDirection(__VA_ARGS__) {call-script lua_CobDebug(20, __LINE__, ## __VA_ARGS__ ); call-script  wrap_SetDirection(__VA_ARGS__);} \
		wrap_SetDirection(__VA_ARGS__)
	#define dbg_SetDirection(...) call-script lua_CobDebug(20, __LINE__, ## __VA_ARGS__ );
#else
	#define print_SetDirection(...) SetDirection(__VA_ARGS__)
	#define dbg_SetDirection(...)
#endif

#ifdef DEBUG
	#define print_SetSpeed(...) SetSpeed(__VA_ARGS__) {call-script lua_CobDebug(21, __LINE__, ## __VA_ARGS__ ); call-script  wrap_SetSpeed(__VA_ARGS__);} \
		wrap_SetSpeed(__VA_ARGS__)
	#define dbg_SetSpeed(...) call-script lua_CobDebug(21, __LINE__, ## __VA_ARGS__ );
#else
	#define print_SetSpeed(...) SetSpeed(__VA_ARGS__)
	#define dbg_SetSpeed(...)
#endif

#ifdef DEBUG
	#define print_RockUnit(...) RockUnit(__VA_ARGS__) {call-script lua_CobDebug(22, __LINE__, ## __VA_ARGS__ ); call-script  wrap_RockUnit(__VA_ARGS__);} \
		wrap_RockUnit(__VA_ARGS__)
	#define dbg_RockUnit(...) call-script lua_CobDebug(22, __LINE__, ## __VA_ARGS__ );
#else
	#define print_RockUnit(...) RockUnit(__VA_ARGS__)
	#define dbg_RockUnit(...)
#endif

#ifdef DEBUG
	#define print_HitByWeapon(...) HitByWeapon(__VA_ARGS__) {call-script lua_CobDebug(23, __LINE__, ## __VA_ARGS__ ); call-script  wrap_HitByWeapon(__VA_ARGS__);} \
		wrap_HitByWeapon(__VA_ARGS__)
	#define dbg_HitByWeapon(...) call-script lua_CobDebug(23, __LINE__, ## __VA_ARGS__ );
#else
	#define print_HitByWeapon(...) HitByWeapon(__VA_ARGS__)
	#define dbg_HitByWeapon(...)
#endif

#ifdef DEBUG
	#define print_HitByWeaponID(...) HitByWeaponID(__VA_ARGS__) {call-script lua_CobDebug(24, __LINE__, ## __VA_ARGS__ ); call-script  wrap_HitByWeaponID(__VA_ARGS__);} \
		wrap_HitByWeaponID(__VA_ARGS__)
	#define dbg_HitByWeaponID(...) call-script lua_CobDebug(24, __LINE__, ## __VA_ARGS__ );
#else
	#define print_HitByWeaponID(...) HitByWeaponID(__VA_ARGS__)
	#define dbg_HitByWeaponID(...)
#endif

#ifdef DEBUG
	#define print_SetMaxReloadTime(...) SetMaxReloadTime(__VA_ARGS__) {call-script lua_CobDebug(25, __LINE__, ## __VA_ARGS__ ); call-script  wrap_SetMaxReloadTime(__VA_ARGS__);} \
		wrap_SetMaxReloadTime(__VA_ARGS__)
	#define dbg_SetMaxReloadTime(...) call-script lua_CobDebug(25, __LINE__, ## __VA_ARGS__ );
#else
	#define print_SetMaxReloadTime(...) SetMaxReloadTime(__VA_ARGS__)
	#define dbg_SetMaxReloadTime(...)
#endif

#ifdef DEBUG
	#define print_StartBuilding(...) StartBuilding(__VA_ARGS__) {call-script lua_CobDebug(26, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StartBuilding(__VA_ARGS__);} \
		wrap_StartBuilding(__VA_ARGS__)
	#define dbg_StartBuilding(...) call-script lua_CobDebug(26, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StartBuilding(...) StartBuilding(__VA_ARGS__)
	#define dbg_StartBuilding(...)
#endif

#ifdef DEBUG
	#define print_StopBuilding(...) StopBuilding(__VA_ARGS__) {call-script lua_CobDebug(27, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StopBuilding(__VA_ARGS__);} \
		wrap_StopBuilding(__VA_ARGS__)
	#define dbg_StopBuilding(...) call-script lua_CobDebug(27, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StopBuilding(...) StopBuilding(__VA_ARGS__)
	#define dbg_StopBuilding(...)
#endif

#ifdef DEBUG
	#define print_QueryNanoPiece(...) QueryNanoPiece(__VA_ARGS__) {call-script lua_CobDebug(28, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryNanoPiece(__VA_ARGS__);} \
		wrap_QueryNanoPiece(__VA_ARGS__)
	#define dbg_QueryNanoPiece(...) call-script lua_CobDebug(28, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryNanoPiece(...) QueryNanoPiece(__VA_ARGS__)
	#define dbg_QueryNanoPiece(...)
#endif

#ifdef DEBUG
	#define print_QueryBuildInfo(...) QueryBuildInfo(__VA_ARGS__) {call-script lua_CobDebug(29, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryBuildInfo(__VA_ARGS__);} \
		wrap_QueryBuildInfo(__VA_ARGS__)
	#define dbg_QueryBuildInfo(...) call-script lua_CobDebug(29, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryBuildInfo(...) QueryBuildInfo(__VA_ARGS__)
	#define dbg_QueryBuildInfo(...)
#endif

#ifdef DEBUG
	#define print_Falling(...) Falling(__VA_ARGS__) {call-script lua_CobDebug(30, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Falling(__VA_ARGS__);} \
		wrap_Falling(__VA_ARGS__)
	#define dbg_Falling(...) call-script lua_CobDebug(30, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Falling(...) Falling(__VA_ARGS__)
	#define dbg_Falling(...)
#endif

#ifdef DEBUG
	#define print_Landed(...) Landed(__VA_ARGS__) {call-script lua_CobDebug(31, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Landed(__VA_ARGS__);} \
		wrap_Landed(__VA_ARGS__)
	#define dbg_Landed(...) call-script lua_CobDebug(31, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Landed(...) Landed(__VA_ARGS__)
	#define dbg_Landed(...)
#endif

#ifdef DEBUG
	#define print_QueryTransport(...) QueryTransport(__VA_ARGS__) {call-script lua_CobDebug(32, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryTransport(__VA_ARGS__);} \
		wrap_QueryTransport(__VA_ARGS__)
	#define dbg_QueryTransport(...) call-script lua_CobDebug(32, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryTransport(...) QueryTransport(__VA_ARGS__)
	#define dbg_QueryTransport(...)
#endif

#ifdef DEBUG
	#define print_BeginTransport(...) BeginTransport(__VA_ARGS__) {call-script lua_CobDebug(33, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BeginTransport(__VA_ARGS__);} \
		wrap_BeginTransport(__VA_ARGS__)
	#define dbg_BeginTransport(...) call-script lua_CobDebug(33, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BeginTransport(...) BeginTransport(__VA_ARGS__)
	#define dbg_BeginTransport(...)
#endif

#ifdef DEBUG
	#define print_EndTransport(...) EndTransport(__VA_ARGS__) {call-script lua_CobDebug(34, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndTransport(__VA_ARGS__);} \
		wrap_EndTransport(__VA_ARGS__)
	#define dbg_EndTransport(...) call-script lua_CobDebug(34, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndTransport(...) EndTransport(__VA_ARGS__)
	#define dbg_EndTransport(...)
#endif

#ifdef DEBUG
	#define print_TransportPickup(...) TransportPickup(__VA_ARGS__) {call-script lua_CobDebug(35, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TransportPickup(__VA_ARGS__);} \
		wrap_TransportPickup(__VA_ARGS__)
	#define dbg_TransportPickup(...) call-script lua_CobDebug(35, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TransportPickup(...) TransportPickup(__VA_ARGS__)
	#define dbg_TransportPickup(...)
#endif

#ifdef DEBUG
	#define print_TransportDrop(...) TransportDrop(__VA_ARGS__) {call-script lua_CobDebug(36, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TransportDrop(__VA_ARGS__);} \
		wrap_TransportDrop(__VA_ARGS__)
	#define dbg_TransportDrop(...) call-script lua_CobDebug(36, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TransportDrop(...) TransportDrop(__VA_ARGS__)
	#define dbg_TransportDrop(...)
#endif

#ifdef DEBUG
	#define print_StartUnload(...) StartUnload(__VA_ARGS__) {call-script lua_CobDebug(37, __LINE__, ## __VA_ARGS__ ); call-script  wrap_StartUnload(__VA_ARGS__);} \
		wrap_StartUnload(__VA_ARGS__)
	#define dbg_StartUnload(...) call-script lua_CobDebug(37, __LINE__, ## __VA_ARGS__ );
#else
	#define print_StartUnload(...) StartUnload(__VA_ARGS__)
	#define dbg_StartUnload(...)
#endif

#ifdef DEBUG
	#define print_QueryLandingPadCount(...) QueryLandingPadCount(__VA_ARGS__) {call-script lua_CobDebug(38, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryLandingPadCount(__VA_ARGS__);} \
		wrap_QueryLandingPadCount(__VA_ARGS__)
	#define dbg_QueryLandingPadCount(...) call-script lua_CobDebug(38, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryLandingPadCount(...) QueryLandingPadCount(__VA_ARGS__)
	#define dbg_QueryLandingPadCount(...)
#endif

#ifdef DEBUG
	#define print_QueryLandingPad(...) QueryLandingPad(__VA_ARGS__) {call-script lua_CobDebug(39, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryLandingPad(__VA_ARGS__);} \
		wrap_QueryLandingPad(__VA_ARGS__)
	#define dbg_QueryLandingPad(...) call-script lua_CobDebug(39, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryLandingPad(...) QueryLandingPad(__VA_ARGS__)
	#define dbg_QueryLandingPad(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon1(...) AimWeapon1(__VA_ARGS__) {call-script lua_CobDebug(40, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon1(__VA_ARGS__);} \
		wrap_AimWeapon1(__VA_ARGS__)
	#define dbg_AimWeapon1(...) call-script lua_CobDebug(40, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon1(...) AimWeapon1(__VA_ARGS__)
	#define dbg_AimWeapon1(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon1(...) AimFromWeapon1(__VA_ARGS__) {call-script lua_CobDebug(41, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon1(__VA_ARGS__);} \
		wrap_AimFromWeapon1(__VA_ARGS__)
	#define dbg_AimFromWeapon1(...) call-script lua_CobDebug(41, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon1(...) AimFromWeapon1(__VA_ARGS__)
	#define dbg_AimFromWeapon1(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon1(...) FireWeapon1(__VA_ARGS__) {call-script lua_CobDebug(42, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon1(__VA_ARGS__);} \
		wrap_FireWeapon1(__VA_ARGS__)
	#define dbg_FireWeapon1(...) call-script lua_CobDebug(42, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon1(...) FireWeapon1(__VA_ARGS__)
	#define dbg_FireWeapon1(...)
#endif

#ifdef DEBUG
	#define print_Shot1(...) Shot1(__VA_ARGS__) {call-script lua_CobDebug(43, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot1(__VA_ARGS__);} \
		wrap_Shot1(__VA_ARGS__)
	#define dbg_Shot1(...) call-script lua_CobDebug(43, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot1(...) Shot1(__VA_ARGS__)
	#define dbg_Shot1(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon1(...) QueryWeapon1(__VA_ARGS__) {call-script lua_CobDebug(44, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon1(__VA_ARGS__);} \
		wrap_QueryWeapon1(__VA_ARGS__)
	#define dbg_QueryWeapon1(...) call-script lua_CobDebug(44, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon1(...) QueryWeapon1(__VA_ARGS__)
	#define dbg_QueryWeapon1(...)
#endif

#ifdef DEBUG
	#define print_EndBurst1(...) EndBurst1(__VA_ARGS__) {call-script lua_CobDebug(45, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst1(__VA_ARGS__);} \
		wrap_EndBurst1(__VA_ARGS__)
	#define dbg_EndBurst1(...) call-script lua_CobDebug(45, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst1(...) EndBurst1(__VA_ARGS__)
	#define dbg_EndBurst1(...)
#endif

#ifdef DEBUG
	#define print_BlockShot1(...) BlockShot1(__VA_ARGS__) {call-script lua_CobDebug(46, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot1(__VA_ARGS__);} \
		wrap_BlockShot1(__VA_ARGS__)
	#define dbg_BlockShot1(...) call-script lua_CobDebug(46, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot1(...) BlockShot1(__VA_ARGS__)
	#define dbg_BlockShot1(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight1(...) TargetWeight1(__VA_ARGS__) {call-script lua_CobDebug(47, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight1(__VA_ARGS__);} \
		wrap_TargetWeight1(__VA_ARGS__)
	#define dbg_TargetWeight1(...) call-script lua_CobDebug(47, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight1(...) TargetWeight1(__VA_ARGS__)
	#define dbg_TargetWeight1(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon2(...) AimWeapon2(__VA_ARGS__) {call-script lua_CobDebug(48, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon2(__VA_ARGS__);} \
		wrap_AimWeapon2(__VA_ARGS__)
	#define dbg_AimWeapon2(...) call-script lua_CobDebug(48, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon2(...) AimWeapon2(__VA_ARGS__)
	#define dbg_AimWeapon2(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon2(...) AimFromWeapon2(__VA_ARGS__) {call-script lua_CobDebug(49, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon2(__VA_ARGS__);} \
		wrap_AimFromWeapon2(__VA_ARGS__)
	#define dbg_AimFromWeapon2(...) call-script lua_CobDebug(49, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon2(...) AimFromWeapon2(__VA_ARGS__)
	#define dbg_AimFromWeapon2(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon2(...) FireWeapon2(__VA_ARGS__) {call-script lua_CobDebug(50, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon2(__VA_ARGS__);} \
		wrap_FireWeapon2(__VA_ARGS__)
	#define dbg_FireWeapon2(...) call-script lua_CobDebug(50, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon2(...) FireWeapon2(__VA_ARGS__)
	#define dbg_FireWeapon2(...)
#endif

#ifdef DEBUG
	#define print_Shot2(...) Shot2(__VA_ARGS__) {call-script lua_CobDebug(51, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot2(__VA_ARGS__);} \
		wrap_Shot2(__VA_ARGS__)
	#define dbg_Shot2(...) call-script lua_CobDebug(51, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot2(...) Shot2(__VA_ARGS__)
	#define dbg_Shot2(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon2(...) QueryWeapon2(__VA_ARGS__) {call-script lua_CobDebug(52, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon2(__VA_ARGS__);} \
		wrap_QueryWeapon2(__VA_ARGS__)
	#define dbg_QueryWeapon2(...) call-script lua_CobDebug(52, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon2(...) QueryWeapon2(__VA_ARGS__)
	#define dbg_QueryWeapon2(...)
#endif

#ifdef DEBUG
	#define print_EndBurst2(...) EndBurst2(__VA_ARGS__) {call-script lua_CobDebug(53, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst2(__VA_ARGS__);} \
		wrap_EndBurst2(__VA_ARGS__)
	#define dbg_EndBurst2(...) call-script lua_CobDebug(53, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst2(...) EndBurst2(__VA_ARGS__)
	#define dbg_EndBurst2(...)
#endif

#ifdef DEBUG
	#define print_BlockShot2(...) BlockShot2(__VA_ARGS__) {call-script lua_CobDebug(54, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot2(__VA_ARGS__);} \
		wrap_BlockShot2(__VA_ARGS__)
	#define dbg_BlockShot2(...) call-script lua_CobDebug(54, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot2(...) BlockShot2(__VA_ARGS__)
	#define dbg_BlockShot2(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight2(...) TargetWeight2(__VA_ARGS__) {call-script lua_CobDebug(55, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight2(__VA_ARGS__);} \
		wrap_TargetWeight2(__VA_ARGS__)
	#define dbg_TargetWeight2(...) call-script lua_CobDebug(55, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight2(...) TargetWeight2(__VA_ARGS__)
	#define dbg_TargetWeight2(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon3(...) AimWeapon3(__VA_ARGS__) {call-script lua_CobDebug(56, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon3(__VA_ARGS__);} \
		wrap_AimWeapon3(__VA_ARGS__)
	#define dbg_AimWeapon3(...) call-script lua_CobDebug(56, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon3(...) AimWeapon3(__VA_ARGS__)
	#define dbg_AimWeapon3(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon3(...) AimFromWeapon3(__VA_ARGS__) {call-script lua_CobDebug(57, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon3(__VA_ARGS__);} \
		wrap_AimFromWeapon3(__VA_ARGS__)
	#define dbg_AimFromWeapon3(...) call-script lua_CobDebug(57, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon3(...) AimFromWeapon3(__VA_ARGS__)
	#define dbg_AimFromWeapon3(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon3(...) FireWeapon3(__VA_ARGS__) {call-script lua_CobDebug(58, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon3(__VA_ARGS__);} \
		wrap_FireWeapon3(__VA_ARGS__)
	#define dbg_FireWeapon3(...) call-script lua_CobDebug(58, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon3(...) FireWeapon3(__VA_ARGS__)
	#define dbg_FireWeapon3(...)
#endif

#ifdef DEBUG
	#define print_Shot3(...) Shot3(__VA_ARGS__) {call-script lua_CobDebug(59, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot3(__VA_ARGS__);} \
		wrap_Shot3(__VA_ARGS__)
	#define dbg_Shot3(...) call-script lua_CobDebug(59, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot3(...) Shot3(__VA_ARGS__)
	#define dbg_Shot3(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon3(...) QueryWeapon3(__VA_ARGS__) {call-script lua_CobDebug(60, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon3(__VA_ARGS__);} \
		wrap_QueryWeapon3(__VA_ARGS__)
	#define dbg_QueryWeapon3(...) call-script lua_CobDebug(60, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon3(...) QueryWeapon3(__VA_ARGS__)
	#define dbg_QueryWeapon3(...)
#endif

#ifdef DEBUG
	#define print_EndBurst3(...) EndBurst3(__VA_ARGS__) {call-script lua_CobDebug(61, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst3(__VA_ARGS__);} \
		wrap_EndBurst3(__VA_ARGS__)
	#define dbg_EndBurst3(...) call-script lua_CobDebug(61, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst3(...) EndBurst3(__VA_ARGS__)
	#define dbg_EndBurst3(...)
#endif

#ifdef DEBUG
	#define print_BlockShot3(...) BlockShot3(__VA_ARGS__) {call-script lua_CobDebug(62, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot3(__VA_ARGS__);} \
		wrap_BlockShot3(__VA_ARGS__)
	#define dbg_BlockShot3(...) call-script lua_CobDebug(62, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot3(...) BlockShot3(__VA_ARGS__)
	#define dbg_BlockShot3(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight3(...) TargetWeight3(__VA_ARGS__) {call-script lua_CobDebug(63, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight3(__VA_ARGS__);} \
		wrap_TargetWeight3(__VA_ARGS__)
	#define dbg_TargetWeight3(...) call-script lua_CobDebug(63, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight3(...) TargetWeight3(__VA_ARGS__)
	#define dbg_TargetWeight3(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon4(...) AimWeapon4(__VA_ARGS__) {call-script lua_CobDebug(64, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon4(__VA_ARGS__);} \
		wrap_AimWeapon4(__VA_ARGS__)
	#define dbg_AimWeapon4(...) call-script lua_CobDebug(64, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon4(...) AimWeapon4(__VA_ARGS__)
	#define dbg_AimWeapon4(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon4(...) AimFromWeapon4(__VA_ARGS__) {call-script lua_CobDebug(65, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon4(__VA_ARGS__);} \
		wrap_AimFromWeapon4(__VA_ARGS__)
	#define dbg_AimFromWeapon4(...) call-script lua_CobDebug(65, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon4(...) AimFromWeapon4(__VA_ARGS__)
	#define dbg_AimFromWeapon4(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon4(...) FireWeapon4(__VA_ARGS__) {call-script lua_CobDebug(66, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon4(__VA_ARGS__);} \
		wrap_FireWeapon4(__VA_ARGS__)
	#define dbg_FireWeapon4(...) call-script lua_CobDebug(66, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon4(...) FireWeapon4(__VA_ARGS__)
	#define dbg_FireWeapon4(...)
#endif

#ifdef DEBUG
	#define print_Shot4(...) Shot4(__VA_ARGS__) {call-script lua_CobDebug(67, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot4(__VA_ARGS__);} \
		wrap_Shot4(__VA_ARGS__)
	#define dbg_Shot4(...) call-script lua_CobDebug(67, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot4(...) Shot4(__VA_ARGS__)
	#define dbg_Shot4(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon4(...) QueryWeapon4(__VA_ARGS__) {call-script lua_CobDebug(68, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon4(__VA_ARGS__);} \
		wrap_QueryWeapon4(__VA_ARGS__)
	#define dbg_QueryWeapon4(...) call-script lua_CobDebug(68, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon4(...) QueryWeapon4(__VA_ARGS__)
	#define dbg_QueryWeapon4(...)
#endif

#ifdef DEBUG
	#define print_EndBurst4(...) EndBurst4(__VA_ARGS__) {call-script lua_CobDebug(69, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst4(__VA_ARGS__);} \
		wrap_EndBurst4(__VA_ARGS__)
	#define dbg_EndBurst4(...) call-script lua_CobDebug(69, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst4(...) EndBurst4(__VA_ARGS__)
	#define dbg_EndBurst4(...)
#endif

#ifdef DEBUG
	#define print_BlockShot4(...) BlockShot4(__VA_ARGS__) {call-script lua_CobDebug(70, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot4(__VA_ARGS__);} \
		wrap_BlockShot4(__VA_ARGS__)
	#define dbg_BlockShot4(...) call-script lua_CobDebug(70, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot4(...) BlockShot4(__VA_ARGS__)
	#define dbg_BlockShot4(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight4(...) TargetWeight4(__VA_ARGS__) {call-script lua_CobDebug(71, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight4(__VA_ARGS__);} \
		wrap_TargetWeight4(__VA_ARGS__)
	#define dbg_TargetWeight4(...) call-script lua_CobDebug(71, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight4(...) TargetWeight4(__VA_ARGS__)
	#define dbg_TargetWeight4(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon5(...) AimWeapon5(__VA_ARGS__) {call-script lua_CobDebug(72, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon5(__VA_ARGS__);} \
		wrap_AimWeapon5(__VA_ARGS__)
	#define dbg_AimWeapon5(...) call-script lua_CobDebug(72, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon5(...) AimWeapon5(__VA_ARGS__)
	#define dbg_AimWeapon5(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon5(...) AimFromWeapon5(__VA_ARGS__) {call-script lua_CobDebug(73, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon5(__VA_ARGS__);} \
		wrap_AimFromWeapon5(__VA_ARGS__)
	#define dbg_AimFromWeapon5(...) call-script lua_CobDebug(73, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon5(...) AimFromWeapon5(__VA_ARGS__)
	#define dbg_AimFromWeapon5(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon5(...) FireWeapon5(__VA_ARGS__) {call-script lua_CobDebug(74, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon5(__VA_ARGS__);} \
		wrap_FireWeapon5(__VA_ARGS__)
	#define dbg_FireWeapon5(...) call-script lua_CobDebug(74, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon5(...) FireWeapon5(__VA_ARGS__)
	#define dbg_FireWeapon5(...)
#endif

#ifdef DEBUG
	#define print_Shot5(...) Shot5(__VA_ARGS__) {call-script lua_CobDebug(75, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot5(__VA_ARGS__);} \
		wrap_Shot5(__VA_ARGS__)
	#define dbg_Shot5(...) call-script lua_CobDebug(75, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot5(...) Shot5(__VA_ARGS__)
	#define dbg_Shot5(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon5(...) QueryWeapon5(__VA_ARGS__) {call-script lua_CobDebug(76, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon5(__VA_ARGS__);} \
		wrap_QueryWeapon5(__VA_ARGS__)
	#define dbg_QueryWeapon5(...) call-script lua_CobDebug(76, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon5(...) QueryWeapon5(__VA_ARGS__)
	#define dbg_QueryWeapon5(...)
#endif

#ifdef DEBUG
	#define print_EndBurst5(...) EndBurst5(__VA_ARGS__) {call-script lua_CobDebug(77, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst5(__VA_ARGS__);} \
		wrap_EndBurst5(__VA_ARGS__)
	#define dbg_EndBurst5(...) call-script lua_CobDebug(77, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst5(...) EndBurst5(__VA_ARGS__)
	#define dbg_EndBurst5(...)
#endif

#ifdef DEBUG
	#define print_BlockShot5(...) BlockShot5(__VA_ARGS__) {call-script lua_CobDebug(78, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot5(__VA_ARGS__);} \
		wrap_BlockShot5(__VA_ARGS__)
	#define dbg_BlockShot5(...) call-script lua_CobDebug(78, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot5(...) BlockShot5(__VA_ARGS__)
	#define dbg_BlockShot5(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight5(...) TargetWeight5(__VA_ARGS__) {call-script lua_CobDebug(79, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight5(__VA_ARGS__);} \
		wrap_TargetWeight5(__VA_ARGS__)
	#define dbg_TargetWeight5(...) call-script lua_CobDebug(79, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight5(...) TargetWeight5(__VA_ARGS__)
	#define dbg_TargetWeight5(...)
#endif

#ifdef DEBUG
	#define print_AimWeapon6(...) AimWeapon6(__VA_ARGS__) {call-script lua_CobDebug(80, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimWeapon6(__VA_ARGS__);} \
		wrap_AimWeapon6(__VA_ARGS__)
	#define dbg_AimWeapon6(...) call-script lua_CobDebug(80, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimWeapon6(...) AimWeapon6(__VA_ARGS__)
	#define dbg_AimWeapon6(...)
#endif

#ifdef DEBUG
	#define print_AimFromWeapon6(...) AimFromWeapon6(__VA_ARGS__) {call-script lua_CobDebug(81, __LINE__, ## __VA_ARGS__ ); call-script  wrap_AimFromWeapon6(__VA_ARGS__);} \
		wrap_AimFromWeapon6(__VA_ARGS__)
	#define dbg_AimFromWeapon6(...) call-script lua_CobDebug(81, __LINE__, ## __VA_ARGS__ );
#else
	#define print_AimFromWeapon6(...) AimFromWeapon6(__VA_ARGS__)
	#define dbg_AimFromWeapon6(...)
#endif

#ifdef DEBUG
	#define print_FireWeapon6(...) FireWeapon6(__VA_ARGS__) {call-script lua_CobDebug(82, __LINE__, ## __VA_ARGS__ ); call-script  wrap_FireWeapon6(__VA_ARGS__);} \
		wrap_FireWeapon6(__VA_ARGS__)
	#define dbg_FireWeapon6(...) call-script lua_CobDebug(82, __LINE__, ## __VA_ARGS__ );
#else
	#define print_FireWeapon6(...) FireWeapon6(__VA_ARGS__)
	#define dbg_FireWeapon6(...)
#endif

#ifdef DEBUG
	#define print_Shot6(...) Shot6(__VA_ARGS__) {call-script lua_CobDebug(83, __LINE__, ## __VA_ARGS__ ); call-script  wrap_Shot6(__VA_ARGS__);} \
		wrap_Shot6(__VA_ARGS__)
	#define dbg_Shot6(...) call-script lua_CobDebug(83, __LINE__, ## __VA_ARGS__ );
#else
	#define print_Shot6(...) Shot6(__VA_ARGS__)
	#define dbg_Shot6(...)
#endif

#ifdef DEBUG
	#define print_QueryWeapon6(...) QueryWeapon6(__VA_ARGS__) {call-script lua_CobDebug(84, __LINE__, ## __VA_ARGS__ ); call-script  wrap_QueryWeapon6(__VA_ARGS__);} \
		wrap_QueryWeapon6(__VA_ARGS__)
	#define dbg_QueryWeapon6(...) call-script lua_CobDebug(84, __LINE__, ## __VA_ARGS__ );
#else
	#define print_QueryWeapon6(...) QueryWeapon6(__VA_ARGS__)
	#define dbg_QueryWeapon6(...)
#endif

#ifdef DEBUG
	#define print_EndBurst6(...) EndBurst6(__VA_ARGS__) {call-script lua_CobDebug(85, __LINE__, ## __VA_ARGS__ ); call-script  wrap_EndBurst6(__VA_ARGS__);} \
		wrap_EndBurst6(__VA_ARGS__)
	#define dbg_EndBurst6(...) call-script lua_CobDebug(85, __LINE__, ## __VA_ARGS__ );
#else
	#define print_EndBurst6(...) EndBurst6(__VA_ARGS__)
	#define dbg_EndBurst6(...)
#endif

#ifdef DEBUG
	#define print_BlockShot6(...) BlockShot6(__VA_ARGS__) {call-script lua_CobDebug(86, __LINE__, ## __VA_ARGS__ ); call-script  wrap_BlockShot6(__VA_ARGS__);} \
		wrap_BlockShot6(__VA_ARGS__)
	#define dbg_BlockShot6(...) call-script lua_CobDebug(86, __LINE__, ## __VA_ARGS__ );
#else
	#define print_BlockShot6(...) BlockShot6(__VA_ARGS__)
	#define dbg_BlockShot6(...)
#endif

#ifdef DEBUG
	#define print_TargetWeight6(...) TargetWeight6(__VA_ARGS__) {call-script lua_CobDebug(87, __LINE__, ## __VA_ARGS__ ); call-script  wrap_TargetWeight6(__VA_ARGS__);} \
		wrap_TargetWeight6(__VA_ARGS__)
	#define dbg_TargetWeight6(...) call-script lua_CobDebug(87, __LINE__, ## __VA_ARGS__ );
#else
	#define print_TargetWeight6(...) TargetWeight6(__VA_ARGS__)
	#define dbg_TargetWeight6(...)
#endif


#ifdef BENCHMARK

static-var benchstatic1, benchstatic2, benchstatic3;

#define ABSOLUTE(value) \
	(value * ( value > 0) - value * ( value <0 ))


#define ABSOLUTE2(value) if (value < 0 ) value = -1*value;

BenchMarkCall1(callvar){
	//callvar = callvar + 1 ;
	//benchstatic1 = callvar;
	//callvar = get MIN(callvar, benchstatic2);
	return (callvar);
}

BenchMarkCall2(callvar){
	//callvar = callvar + 1 ;
	//benchstatic1 = callvar;
	//callvar = get MAX(callvar, benchstatic2);
	return (callvar);
}

BenchMark1(count){
	var bench1;
	var bench2;
	var bench3;
	benchstatic3 = benchstatic3 + 1;
	bench1 = 0;

	while ((bench1 < count) && (bench1 < 1000)){
		bench1 = bench1 +1 ;
		bench2 = get MAX_SPEED;
		bench2 = bench2 + 1;
		bench3 = get CURRENT_SPEED;
		//bench2 = get ABS(bench2);
		bench2 = ABSOLUTE(bench2);
		if ((bench1 & 0x1) == 1 ){
			//bench2 = get ABS(bench1);
			//ABSOLUTE2(bench2);
			bench2 = bench2 *2;
			call-script BenchMarkCall1();
		}else{
			//bench2 = get ABS(bench2);
			//ABSOLUTE2(bench2);
			bench2 = bench2 *2;
			call-script BenchMarkCall2();
		}
		//turn base to y-axis <0.3> * bench1 speed <3000>;
		benchstatic1 = bench1;
		benchstatic2 = benchstatic1 / (bench1 + 1);
		bench1 = benchstatic1;
	}
	return (0);

}

StartBench(cnt){
	benchstatic3 = 0;
	while(1){
		call-script BenchMark1(cnt);
		sleep 1;
	}
}
#endif