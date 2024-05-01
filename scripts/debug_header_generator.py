# (C) Beherith mysterme@gmail.com

numweapons = 6
weaponcallinsX = ['AimWeapon', 'AimFromWeapon', 'FireWeapon', 'Shot', 'QueryWeapon','EndBurst','BlockShot','TargetWeight']
weaponcallins = []
for i in range(1,7):
	weaponcallins += [n + str(i) for n in weaponcallinsX]
enginecallins = ['Create', 'Activate','Deactivate', 'StartMoving','StopMoving', 'SetSFXOccupy', 'MoveRate0', 'MoveRate1',
	'MoveRate2', 'MoveRate3', 'SetDirection', 'SetSpeed', 'RockUnit', 'HitByWeapon', 'HitByWeaponID', 'SetMaxReloadTime', 
	'StartBuilding', 'StopBuilding', 'QueryNanoPiece', 'QueryBuildInfo', 'Falling', 'Landed', 'QueryTransport', 'BeginTransport',
	'EndTransport', 'TransportPickup', 'TransportDrop', 'StartUnload', 'QueryLandingPadCount', 'QueryLandingPad']
commonfunctions = ['Debug','Open', 'Close', 'TryTransition', 'Killed', 'RestoreAfterDelay', 'ExecuteRestoreAfterDelay', 'SetStunned', 'Walk','StopWalking']

##ifdef DEBUG
#	#define print_Open(...) Open(__VA_ARGS__) {call-script lua_CobDebug(31, __LINE__, ## __VA_ARGS__ ); call-script wrap_Open(__VA_ARGS__);} \
#		wrap_Open(__VA_ARGS__)
#	#define dbg_Open(...) call-script lua_CobDebug(31, __LINE__, ## __VA_ARGS__ ); 
##else
#	#define print_Open(...) Open(__VA_ARGS__)
#	#define dbg_Open(...) ; 
#endif
count = 1
def makewrapper(fname):
	global count
	print('#ifdef DEBUG')
	print(f'	#define print_{fname}(...) {fname}(__VA_ARGS__) {{call-script lua_CobDebug({count}, __LINE__, ## __VA_ARGS__ ); call-script  wrap_{fname}(__VA_ARGS__);}} \\')
	print(f'		wrap_{fname}(__VA_ARGS__)')
	print(f'	#define dbg_{fname}(...) call-script lua_CobDebug({count}, __LINE__, ## __VA_ARGS__ );')
	print('#else')
	print(f'	#define print_{fname}(...) {fname}(__VA_ARGS__)')
	print(f'	#define dbg_{fname}(...)')
	print('#endif')
	print()
	count += 1


for callinlist in [commonfunctions, enginecallins, weaponcallins]:
	for callin in callinlist:
		makewrapper(callin)

count = 1
print('local callinids= {')

for callinlist in [commonfunctions, enginecallins, weaponcallins]:
	for callin in callinlist:
		print(f'	[{count}]	= "{callin}",')
		count += 1
print('}')
