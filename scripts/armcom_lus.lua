--BASE PIECES:
local pelvis, torso, head, luparm, nanolath, nanospray, lfirept, ruparm, biggun, rbigflash, rthigh, rleg, lthigh, lleg = piece("pelvis", "torso", "head", "luparm", "nanolath", "nanospray", "lfirept", "ruparm", "biggun", "rbigflash", "rthigh", "rleg", "lthigh", "lleg")
local ground = piece("ground")
--shieldpiece
local shield = piece("shield")
--LVL1 : 
local pelvis1, torso1, head1, luparm1, nanolath1, nanospray1, lfirept1, ruparm1, biggun1, rbigflash1, rthigh1, rleg1, lthigh1, lleg1 = piece("pelvis1", "torso1", "head1", "luparm1", "nanolath1", "nanospray1", "lfirept1", "ruparm1", "biggun1", "rbigflash1", "rthigh1", "rleg1", "lthigh1", "lleg1")

--LVL2 :
local torso2 = piece("torso2")

--LVL3:
local nanolath3, nanospray3, lfirept3 = piece("nanolath3", "nanospray3", "lfirept3")

--LVL4:
local biggun4, rbigflash4 = piece("biggun4", "rbigflash4")

--LVL5:
local rthigh5, lthigh5, rleg5, lleg5 = piece("rthigh5", "lthigh5", "rleg5", "lleg5")
--MovePelvisY+5

--Pieces to hide at level 1 (spawn)
lvl1hides = {}
lvl1hides = {rthigh5, lthigh5, rleg5, lleg5, biggun4, rbigflash4, nanolath3, nanospray3, lfirept3, torso2}

--Stats Tables:
--Weapon: Laser
Range = {300,375,430,430,475,525,575,630,700,800,1000}
AOE = {12,12,12,16,16,16,24,24,24,32,32}
ReloadTime = {0.4,0.4,0.4,0.2,0.2,0.2,0.2,0.2,0.2,0.2,0.2}
Damages = {75,75,125,125,125,150,150,200,200,250,250}
--Weapon:SeaLaser
Range2 = {300,375,430,430,475,525,575,630,700,800,1000}
AOE2 = {12,12,12,16,16,16,24,24,24,32,32}
ReloadTime2 = {1,1,1,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5}
Damages21 = {75,75,125,125,125,150,150,200,200,250,250}
Damages22 = {0.5,0.5,0.5,0.75,0.75,0.75,1,1,1,1,1}
--Weapon:Dgun
ReloadTime3 = {0.9,0.9,0.8,0.8,0.7,0.7,0.6,0.6,0.6,0.5,0.4}
--Speeds
BuildSpeed = {300,325,350,400,450,500,550,600,700,800,900}
MoveSpeed = {1.25,1.275,1.3,1.35,1.40,1.45,1.5,1.5,1.5,1.5,1.5}
--Armor/hp
ShieldPower = {1000,1250,1500,2000,2500,3000,4000,4000,4000,4000,4000}
AdditionalMaxHealth = {-500,-250,0,500,1000,1500,2000,2500,3000,3500,4000}
DamageMultiplierNoDgun = {1,1,1,1,1,1,0.9,0.8,0.7,0.6,0.5}
--Vision
LOS = {450,500,550,600,625,650,675,700,725,750,800}
Sonar = {450,450,500,500,550,550,600,600,650,650,700}
Radar = {700,700,800,1000,1200,1400,1600,2000,2400,2800,3200}

local SIG_WALK = 2
local PlaySoundFile 	= Spring.PlaySoundFile
local GetUnitPosition 	= Spring.GetUnitPosition
local GetGameFrame 		= Spring.GetGameFrame
common = include("headers/common_includes_lus.lua")

function move(piece, axis, goal, speed)
if speed then
	Move(piece, axis, goal,speed*currentSpeed/100)
else
	Move(piece, axis, goal)
end
end

function turn(piece, axis, goal, speed)
if speed then
	Turn(piece, axis, math.rad(goal), math.rad(speed)*currentSpeed/100)
else
	Turn(piece, axis, math.rad(goal))
end
end



function UnitSpeed()
	while (true) do
		local mm, mu, em, eu = Spring.GetUnitResources(unitID)
		local null, fxp = Spring.GetUnitExperience(unitID)
		local xptoadd = (mm * 0.000000025) + (mu * 0.00000025) + ((em/60) * 0.000000025) + ((eu/60)*0.00000025)
		Spring.SetUnitExperience(unitID, null + xptoadd)
		vx,vy,vz,Speed = Spring.GetUnitVelocity(unitID)
		currentSpeed = Speed*100*30/moveSpeed
		if (currentSpeed < 35) then currentSpeed = 35 end
		randomness = math.random(-10,10)
		currentSpeed = currentSpeed + randomness
		Sleep (1)
	end
end

function MotionControl()
	justmoved = true
	while (true) do
	-- Spring.Echo(dgunning)
	-- Spring.Echo(aiming)
		if (moving) then
			-- Spring.Echo("moving")
			dgunning = false
			if (aiming) then
				walklegs()
			else
				walk()
			end
			justmoved = true
		else
			if( justmoved ) then
					move(pelvis , 2, 0)
					turn(pelvis , 1, 0, 50)
					turn(lthigh , 1, 0, 40)
					turn(rthigh , 1, 0, 40)
					turn(torso , 2,0, 10)
					turn(rleg , 1, 0, 180)
					turn(lleg , 1, 0, 180)
				if not (aiming) then
					turn(ruparm , 1, 0, 20)
					turn(luparm , 1, 0, 20)
					turn(nanolath , 1, 0,20)
					turn(biggun , 1, 0,20)
				end
				justmoved = false
			end
			Sleep (100)
		end
		Sleep (1)
	end
end

function script.Create()
for ct, piecenum in pairs (lvl1hides) do
	Hide(piecenum)
end
	for i = 1, #UnitDefs[Spring.GetUnitDefID(unitID)].weapons do
		Spring.Echo(i.." "..WeaponDefs[UnitDefs[Spring.GetUnitDefID(unitID)].weapons[i].weaponDef].name)
	end
-- Stats = {
-- bp=UnitDefs[Spring.GetUnitDefID(unitID)].buildSpeed,
-- Range = 300,
-- msec=UnitDefs[Spring.GetUnitDefID(unitID)].metalMake,
-- esec=UnitDefs[Spring.GetUnitDefID(unitID)].energyMake,
-- los=UnitDefs[Spring.GetUnitDefID(unitID)].losRadius,
-- airlos=UnitDefs[Spring.GetUnitDefID(unitID)].airLosRadius,
-- radar=UnitDefs[Spring.GetUnitDefID(unitID)].radarRadius,
-- sonar=UnitDefs[Spring.GetUnitDefID(unitID)].sonarRadius,
-- armor=1,
-- }
	level = 0
	-- side = math.random(0,1)
	randomness = math.random(-25,25)
	-- addheight = 0
	Hide (rbigflash)
	Hide (lfirept)
	-- Turn (lfirept, 1 , (1/(6.28*8))*90 )
	-- Move (lfirept, 1 , 0.5 )
	-- Move (lfirept, 3 , 0.25 )
	-- Turn (rbigflash, 1 , (1/(6.28*8))*90 )
	-- Move (rbigflash, 1 , 0.5 )
	-- Move (rbigflash , 2 , -0.35 )
	Hide (nanospray)
	moving = false
	aiming = false
	building = false
	justfired = false
	dgunning = false
	buildy = 0
	buildx = 0
	moveSpeed = UnitDefs[Spring.GetUnitDefID(unitID)].speed
	currentSpeed = 100
	Spring.UnitScript.StartThread(MotionControl)
	Spring.UnitScript.StartThread(UnitSpeed)
	Spring.UnitScript.StartThread(HandleLevelUps)
	Spring.SetUnitNanoPieces(unitID, {lfirept})
end

function HandleLevelUps()
while(true) do
local null, fxp = Spring.GetUnitExperience(unitID)
local realxp = 10 * fxp
-- Spring.Echo(level)
if realxp > 5 and level == 5 then
LevelUpModel(5)
LevelUpStats(5)
elseif realxp > 4 and level == 4 then
LevelUpModel(4)
LevelUpStats(4)
elseif realxp > 3 and level == 3 then
LevelUpModel(3)
LevelUpStats(3)
elseif realxp > 2 and level == 2 then
LevelUpModel(2)
LevelUpStats(2)
elseif realxp > 1 and level == 1 then
LevelUpModel(1)
LevelUpStats(1)
elseif realxp >= 0 and level == 0 then
LevelUpModel(0)
LevelUpStats(0)
end
Sleep(1)
end
end

function switchpieces(piecenum1, piecenum2)
Hide(piecenum1)
Show(piecenum2)
end

function LevelUpStats(curLevel)
	level = curLevel + 1
	Spring.SetUnitMaxRange(unitID, Range[level])
	for i = 23, 29 do
	-- if UnitDefs[Spring.GetUnitDefID(unitID)].weapons[i] then
		-- Spring.Echo(WeaponDefs[UnitDefs[Spring.GetUnitDefID(unitID)].weapons[i].weaponDef].name)
	-- end
		if i - 22 == level or (i == 29 and i - 22 <= level) then
			-- Spring.Echo(i.."activated")

			Spring.SetUnitShieldState(unitID, i, true)
		else
			-- Spring.Echo(i)
			Spring.SetUnitShieldState(unitID, i, false)
		end
	end
	for i = 1,11 do
		Spring.SetUnitWeaponState(unitID,i, "range", Range[level])
		-- Spring.SetUnitWeaponDamages(unitID,i, "damageAreaOfEffect", AOE[level])
		-- Spring.SetUnitWeaponState(unitID,i, "reloadTime", ReloadTime[level])
	end
	for i = 12,22 do
		Spring.SetUnitWeaponState(unitID,i, "range", Range2[level])
		-- Spring.SetUnitWeaponDamages(unitID,i, "damageAreaOfEffect", AOE2[level])
		-- Spring.SetUnitWeaponState(unitID,i, "reloadTime", ReloadTime2[level])
	end
	Spring.SetUnitWeaponState(unitID,30, "reloadTime", ReloadTime3[level])
	Spring.SetUnitBuildSpeed(unitID, BuildSpeed[level], BuildSpeed[level], BuildSpeed[level]*0.7)
	Spring.SetUnitSensorRadius(unitID,"los", LOS[level])
	Spring.SetUnitSensorRadius(unitID,"airLos",LOS[level])
	Spring.SetUnitSensorRadius(unitID,"radar",Radar[level])
	Spring.SetUnitSensorRadius(unitID,"sonar",Sonar[level])
	Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", MoveSpeed[level]*30)
	_,maxhealth = Spring.GetUnitHealth(unitID)
	Spring.SetUnitMaxHealth(unitID, maxhealth + AdditionalMaxHealth[level])
end

function LevelUpModel(curLevel)
if curLevel == 0 then
elseif curLevel == 1 then
	switchpieces(torso1, torso2)
elseif curLevel == 2 then
	switchpieces(nanolath1, nanolath3)
	nanospray = nanospray3
	lfirept = lfirept3
	Spring.SetUnitNanoPieces(unitID, {lfirept})

elseif curLevel == 3 then
	switchpieces(biggun1, biggun4)
	rbigflash = rbigflash4

elseif curLevel == 4 then
	switchpieces(rthigh1, rthigh5)
	switchpieces(lthigh1, lthigh5)
	switchpieces(rleg1, rleg5)
	switchpieces(lleg1, lleg5)
	Move(ground, 2, 5)

elseif curLevel == 5 then

end
end

function script.StartMoving()
	building = false
	moving = true
	dgunning = false
end
	
function script.StopMoving()
	moving = false
end

function script.AimFromWeapon(weapon)
if weapon <= 11 then
return torso
elseif weapon >= 12 and weapon <= 22 then
return torso
elseif weapon == 30 then
return biggun
elseif weapon >= 23 and weapon <= 29 then
return shield
end
end

function script.AimWeapon(weapon, heading, pitch)
-- Spring.Echo(weapon)
if weapon >= 23 and weapon <= 29 then
if weapon - 22 == level then
return true
else
return false
end
end
if weapon <= 11 then
	if weapon == level then
	if dgunning then
		return false
	else
		Spring.UnitScript.Signal(31)
		Spring.UnitScript.StartThread(Restore,3000)
		aiming = true
		Turn(luparm, 1, 0, math.rad(200))
		Turn(torso, 2, heading, math.rad(400))
		Turn(nanolath, 1, math.rad(-90)-pitch, math.rad(250))
		WaitForTurn(nanolath, 1)
		WaitForTurn(torso, 2)
		justfired = true
		return true
	end
	else
	return false
	end
elseif weapon >= 12 and weapon <= 22 then
	if weapon - 11 == level then
	_,uwlaserheight = Spring.GetUnitPosition(unitID)
	if uwlaserheight > -15 then
		return false
	else 
	if dgunning then
		return false
	else
		Spring.UnitScript.Signal(31)
		Spring.UnitScript.StartThread(Restore,3000)
		aiming = true
		Turn(luparm, 1, 0, math.rad(200))
		Turn(torso, 2, heading, math.rad(400))
		Turn(nanolath, 1, math.rad(-90)-pitch, math.rad(250))
		WaitForTurn(nanolath, 1)
		WaitForTurn(torso, 2)
		justfired = true
		return true
	end
	end
	else
	return false
	end
elseif weapon == 30 then
	Spring.UnitScript.Signal(31)
	Spring.UnitScript.StartThread(Restore,1000)
	dgunning = true
	aiming = true
	Turn(torso, 2, heading, math.rad(400))
	Turn(ruparm, 1, 0, math.rad(200))
	Turn(biggun, 1, math.rad(-90)-pitch, math.rad(200))
	WaitForTurn(biggun, 1)
	WaitForTurn(torso, 2)
	return true
end
end

function script.FireWeapon(weapon)
if weapon <= 11 then
Spring.UnitScript.Signal(31)
Spring.UnitScript.StartThread(Restore,3000)
justfired = false
elseif weapon >= 12 and weapon <= 22 then
Spring.UnitScript.Signal(31)
Spring.UnitScript.StartThread(Restore,3000)
justfired = false
elseif weapon == 3 then
Spring.UnitScript.Signal(31)
Spring.UnitScript.StartThread(Restore,1000)

dgunning = false
end
end

function script.QueryWeapon(weapon)
if weapon <= 11 then
return lfirept
elseif weapon >= 12 and weapon <= 22 then
return lfirept
elseif weapon == 30 then
return rbigflash
elseif weapon >= 23 and weapon <= 29 then
return shield
end
end

function script.StartBuilding(heading, pitch)
		Spring.UnitScript.Signal(31)
Spring.UnitScript.StartThread(Restore,3000)

		-- Spring.UnitScript.SetSignalMask(31)
		dgunning = false
		aiming = true
		building = true
		Turn(luparm, 1, 0, math.rad(200))
		Turn(torso, 2, heading, math.rad(400))
		Turn(nanolath, 1, math.rad(-90)-pitch, math.rad(250))
		WaitForTurn(nanolath, 1)
		WaitForTurn(torso, 2)
		SetUnitValue(COB.INBUILDSTANCE, 1)
		return true
end

function script.StopBuilding()
		Spring.UnitScript.Signal(31)
Spring.UnitScript.StartThread(Restore,3000)

		building = false
		SetUnitValue(COB.INBUILDSTANCE, 0)
end

function Restore(sleeptime)
Spring.UnitScript.SetSignalMask(31)
Sleep(sleeptime)
dgunning = false
	if building == false then
	Turn (torso, 2, 0,math.rad(110))
	Turn(nanolath, 1, 0, math.rad(45))
	Turn(biggun, 1, 0, math.rad(45))
	Turn(ruparm, 1, 0, math.rad(45))
	Turn(luparm, 1, 0, math.rad(45))
	Spring.UnitScript.WaitForTurn ( biggun, 1 )
	Spring.UnitScript.WaitForTurn ( biggun, 1 )
	Spring.UnitScript.WaitForTurn ( torso, 2 )
	dgunning = false
	aiming = false
end
end

function walk()

	if moving then
	
		move(pelvis , 2, -1.000000, 11.927711)
		move(head , 2, 0.000000)
		turn(pelvis , 1, 7.000000, 83.493976)
		turn(lthigh , 1, -42.000000, 500.963855)
		turn(rthigh , 1, 18.000000, 214.698795)
		turn(torso , 2, 4.000000, 47.710843)
		turn(ruparm , 1, -11.000000, 131.204819)
		turn(luparm , 1, 11.000000, 131.204819)
		turn(nanolath , 1, -42.000000, 500.963855)
		turn(biggun , 1, -63.000000, 751.445783)
		turn(rleg , 1, 39.000000, 465.180723)
		turn(lleg , 1, 42.000000, 500.963855)
		Sleep( 4000 / currentSpeed)
	end
	if moving then
	
		turn(torso , 2, 4.000000)
		turn(ruparm , 1, -13.000000, 23.855422)
		turn(luparm , 1, 12.000000, 11.927711)
		turn(nanolath , 1, -42.000000)
		Sleep( 4000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000)
		turn(pelvis , 1, 5.000000, 13.288591)
		turn(lthigh , 1, -30.000000, 79.731544)
		turn(rthigh , 1, 9.000000, 59.798658)
		turn(torso , 2, 3.000000, 6.644295)
		turn(ruparm , 1, -8.000000, 33.221477)
		turn(luparm , 1, 6.000000, 39.865772)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 52.000000, 86.375839)
		turn(lleg , 1, 28.000000, 93.020134)
		Sleep( 10000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000, 8.534483)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, -16.000000, 119.482759)
		turn(rthigh , 1, 0.000000, 76.810345)
		turn(torso , 2, 1.000000, 17.068966)
		turn(ruparm , 1, -3.000000, 42.672414)
		turn(luparm , 1, 0.000000, 51.206897)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 58.000000, 51.206897)
		turn(lleg , 1, 16.000000, 102.413793)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 4.000000, 8.534483)
		turn(lthigh , 1, 7.000000, 196.293103)
		turn(rthigh , 1, -6.000000, 51.206897)
		turn(torso , 2, 0.000000, 8.534483)
		turn(ruparm , 1, 3.000000, 51.206897)
		turn(luparm , 1, -6.000000, 51.206897)
		turn(nanolath , 1, -42.000000)
		turn(rleg , 1, 44.000000, 119.482759)
		turn(lleg , 1, 6.000000, 85.344828)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000, 8.534483)
		turn(lthigh , 1, 11.000000, 34.137931)
		turn(rthigh , 1, -34.000000, 238.965517)
		turn(torso , 2, -1.000000, 8.534483)
		turn(ruparm , 1, 7.000000, 34.137931)
		turn(luparm , 1, -8.000000, 17.068966)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 71.000000, 230.431034)
		turn(lleg , 1, 20.000000, 119.482759)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(lthigh , 1, 13.000000, 17.068966)
		turn(rthigh , 1, -43.000000, 76.810345)
		turn(torso , 2, -2.000000, 8.534483)
		turn(ruparm , 1, 8.000000, 8.534483)
		turn(luparm , 1, -9.000000, 8.534483)
		turn(rleg , 1, 55.000000, 136.551724)
		Sleep( 7000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, 17.000000, 34.137931)
		turn(rthigh , 1, -48.000000, 42.672414)
		turn(torso , 2, -3.000000, 8.534483)
		turn(ruparm , 1, 10.000000, 17.068966)
		turn(luparm , 1, -10.000000, 8.534483)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 34.000000, 179.224138)
		turn(lleg , 1, 20.000000)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000, 11.927711)
		turn(pelvis , 1, 7.000000, 23.855422)
		turn(lthigh , 1, 15.000000, 23.855422)
		turn(rthigh , 1, -40.000000, 95.421687)
		turn(torso , 2, -4.000000, 11.927711)
		turn(ruparm , 1, 11.000000, 11.927711)
		turn(luparm , 1, -11.000000, 11.927711)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 40.000000, 71.566265)
		turn(lleg , 1, 31.000000, 131.204819)
		Sleep( 4000 / currentSpeed)
	end
	if moving then
	
		turn(ruparm , 1, 13.000000, 23.855422)
		turn(luparm , 1, -12.000000, 11.927711)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		Sleep( 4000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000)
		turn(pelvis , 1, 5.000000, 13.288591)
		turn(lthigh , 1, 9.000000, 39.865772)
		turn(rthigh , 1, -34.000000, 39.865772)
		turn(torso , 2, -3.000000, 6.644295)
		turn(ruparm , 1, 8.000000, 33.221477)
		turn(luparm , 1, -8.000000, 26.577181)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -62.000000, 6.644295)
		turn(lleg , 1, 44.000000, 86.375839)
		Sleep( 10000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000, 8.534483)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, 1.000000, 68.275862)
		turn(rthigh , 1, -26.000000, 68.275862)
		turn(torso , 2, -2.000000, 8.534483)
		turn(ruparm , 1, 3.000000, 42.672414)
		turn(luparm , 1, -3.000000, 42.672414)
		turn(biggun , 1, -63.000000, 8.534483)
		turn(lleg , 1, 55.000000, 93.879310)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 4.000000, 8.534483)
		turn(lthigh , 1, -17.000000, 153.620690)
		turn(rthigh , 1, 4.000000, 256.034483)
		turn(torso , 2, 0.000000, 17.068966)
		turn(ruparm , 1, -3.000000, 51.206897)
		turn(luparm , 1, 4.000000, 59.741379)
		turn(nanolath , 1, -42.000000)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 8.000000, 273.103448)
		turn(lleg , 1, 60.000000, 42.672414)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000, 8.534483)
		turn(lthigh , 1, -30.000000, 110.948276)
		turn(rthigh , 1, 10.000000, 51.206897)
		turn(torso , 2, 2.000000, 17.068966)
		turn(ruparm , 1, -7.000000, 34.137931)
		turn(luparm , 1, 9.000000, 42.672414)
		turn(biggun , 1, -63.000000)
		turn(rleg , 1, 26.000000, 153.620690)
		turn(lleg , 1, 56.000000, 34.137931)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(lthigh , 1, -44.000000, 119.482759)
		turn(rthigh , 1, 12.000000, 17.068966)
		turn(torso , 2, 2.000000)
		turn(ruparm , 1, -7.000000)
		turn(luparm , 1, 10.000000, 8.534483)
		turn(lleg , 1, 56.000000)
		Sleep( 7000 / currentSpeed)
	end
	move(pelvis , 2, 0.000000)
	turn(pelvis , 1, 5.000000)
	turn(lthigh , 1, -44.000000)
	turn(rthigh , 1, 14.000000, 17.068966)
	turn(torso , 2, 3.000000, 8.534483)
	turn(ruparm , 1, -9.000000, 17.068966)
	turn(luparm , 1, 10.000000)
	turn(biggun , 1, -63.000000)
	turn(lleg , 1, 26.000000, 256.034483)
	Sleep( 8000 / currentSpeed)
end

function walklegs()

	if moving then
		move(pelvis , 2, -1.000000, 8.534483)
		move(head , 2, 0.000000)
		turn(pelvis , 1, 7.000000, 17.068966)
		turn(lthigh , 1, -42.000000, 17.068966)
		turn(rthigh , 1, 18.000000, 34.137931)
		turn(rleg , 1, 39.000000, 110.948276)
		turn(lleg , 1, 42.000000, 136.551724)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000)
		turn(pelvis , 1, 5.000000, 13.288591)
		turn(lthigh , 1, -30.000000, 79.731544)
		turn(rthigh , 1, 9.000000, 59.798658)
		turn(rleg , 1, 52.000000, 86.375839)
		turn(lleg , 1, 28.000000, 93.020134)
		Sleep( 10000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000, 8.534483)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, -16.000000, 119.482759)
		turn(rthigh , 1, 0.000000, 76.810345)
		turn(rleg , 1, 58.000000, 51.206897)
		turn(lleg , 1, 16.000000, 102.413793)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 4.000000, 8.534483)
		turn(lthigh , 1, 7.000000, 196.293103)
		turn(rthigh , 1, -6.000000, 51.206897)
		turn(rleg , 1, 44.000000, 119.482759)
		turn(lleg , 1, 6.000000, 85.344828)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000, 8.534483)
		turn(lthigh , 1, 11.000000, 34.137931)
		turn(rthigh , 1, -34.000000, 238.965517)
		turn(rleg , 1, 71.000000, 230.431034)
		turn(lleg , 1, 20.000000, 119.482759)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(lthigh , 1, 13.000000, 17.068966)
		turn(rthigh , 1, -43.000000, 76.810345)
		turn(rleg , 1, 55.000000, 136.551724)
		Sleep( 7000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, 17.000000, 34.137931)
		turn(rthigh , 1, -48.000000, 42.672414)
		turn(rleg , 1, 34.000000, 179.224138)
		turn(lleg , 1, 20.000000)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000, 8.534483)
		turn(pelvis , 1, 7.000000, 17.068966)
		turn(lthigh , 1, 15.000000, 17.068966)
		turn(rthigh , 1, -40.000000, 68.275862)
		turn(rleg , 1, 40.000000, 51.206897)
		turn(lleg , 1, 31.000000, 93.879310)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, -1.000000)
		turn(pelvis , 1, 5.000000, 13.288591)
		turn(lthigh , 1, 9.000000, 39.865772)
		turn(rthigh , 1, -34.000000, 39.865772)
		turn(lleg , 1, 44.000000, 86.375839)
		Sleep( 10000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000, 8.534483)
		turn(pelvis , 1, 5.000000)
		turn(lthigh , 1, 1.000000, 68.275862)
		turn(rthigh , 1, -26.000000, 68.275862)
		turn(lleg , 1, 55.000000, 93.879310)
		Sleep( 9000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 4.000000, 8.534483)
		turn(lthigh , 1, -17.000000, 153.620690)
		turn(rthigh , 1, 4.000000, 256.034483)
		turn(rleg , 1, 8.000000, 273.103448)
		turn(lleg , 1, 60.000000, 42.672414)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(pelvis , 1, 5.000000, 8.534483)
		turn(lthigh , 1, -30.000000, 110.948276)
		turn(rthigh , 1, 10.000000, 51.206897)
		turn(rleg , 1, 26.000000, 153.620690)
		turn(lleg , 1, 56.000000, 34.137931)
		Sleep( 8000 / currentSpeed)
	end
	if moving then
	
		move(pelvis , 2, 0.000000)
		turn(lthigh , 1, -44.000000, 119.482759)
		turn(rthigh , 1, 12.000000, 17.068966)
		turn(lleg , 1, 56.000000)
		Sleep( 7000 / currentSpeed)
	end
	move(pelvis , 2, 0.000000)
	turn(pelvis , 1, 5.000000)
	turn(lthigh , 1, -44.000000)
	turn(rthigh , 1, 14.000000, 17.068966)
	turn(lleg , 1, 26.000000, 256.034483)
	Sleep( 8000 / currentSpeed)
end

function script.Killed()
return 1
end