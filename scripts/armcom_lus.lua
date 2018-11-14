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

--Stats Table:
VFS.Include("unbaconfigs/stats.lua")
VFS.Include("unbaconfigs/buildoptions.lua")

local SIG_WALK = 2
local PlaySoundFile 	= Spring.PlaySoundFile
local GetUnitPosition 	= Spring.GetUnitPosition
local GetGameFrame 		= Spring.GetGameFrame
local HealRefreshTime	= 15
local CEGHeal = "heal"
local CEGLevelUp = "commander-levelup"
local ValidID = Spring.ValidUnitID

function Emit(pieceName, effectName)
local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID, pieceName)
Spring.SpawnCEG(effectName, x,y,z, dx, dy, dz)
end

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

function PassiveRepairs()
while true do
if ValidID(unitID) then
x,y,z = Spring.GetUnitPosition(unitID)
			local unittable = Spring.GetUnitsInSphere(x, y, z, repairRange)
				for _, uid in pairs(unittable) do
					if uid ~= unitID then
						if Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID), Spring.GetUnitTeam(uid)) == true and not (UnitDefs[Spring.GetUnitDefID(uid)].isBuilding) then
							local oldhp2, maxhp2,_,_,bprog = Spring.GetUnitHealth(uid)
							if oldhp2 / maxhp2 <= bprog then
								if oldhp2 >0 then
									local unit2DefID = Spring.GetUnitDefID(uid)
									local unit1DefID = Spring.GetUnitDefID(unitID)
									local buildTime2S = UnitDefs[unit2DefID].buildTime
									local workerTime1S = BuildSpeed[level]
									local workerTime1F = workerTime1S / 30
									local areaRepairTime1 = 0.1 * workerTime1F
									local HPRepairPerFrame = (maxhp2 / buildTime2S) * areaRepairTime1
									local newhp2 = oldhp2 + HPRepairPerFrame * HealRefreshTime
									if newhp2 > maxhp2*bprog then
										newhp2 = maxhp2
									end
									Spring.SetUnitHealth(uid, newhp2)	
									if Spring.GetGameFrame() %60 == 0 then
									x2, y2, z2 = Spring.GetUnitPosition(uid)
										if newhp2>oldhp2 then
											Spring.SpawnCEG(CEGHeal, x2, y2, z2, 0,1,0)
										end
									end
								end
							end
						end
					end
				end
Sleep(33 * HealRefreshTime)
end
end
end

function UnitSpeed()
	while (true) do
	if ValidID(unitID) then
		vx,vy,vz,Speed = Spring.GetUnitVelocity(unitID)
		currentSpeed = Speed*100*30/moveSpeed
		if (currentSpeed < 35) then currentSpeed = 35 end
		local mm, mu, em, eu = Spring.GetUnitResources(unitID)
		local null, fxp = Spring.GetUnitExperience(unitID)
		local movexp = (Speed or 0) * WalkToExpRatio
		local xptoadd = (mm * ResourcesMakeExp) + (mu * ResourcesUseExp) + ((em/60) * ResourcesMakeExp) + ((eu/60) * ResourcesUseExp) + movexp
		Spring.SetUnitExperience(unitID, null + xptoadd)
		randomness = math.random(-10,10)
		currentSpeed = currentSpeed + randomness
		Sleep (1)
	end
	end
end

function MotionControl()
	justmoved = true
	while (true) do
	if ValidID(unitID) then
		if (moving) then
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
end

function script.Create()
VFS.Include('luarules/configs/champions.lua')
local unitTeam = Spring.GetUnitTeam(unitID)
local unitDefID = Spring.GetUnitDefID(unitID)
local _, leader = Spring.GetTeamInfo(unitTeam)
local leader = Spring.GetPlayerInfo(leader)
if crown[leader] then
		Hide(head1)
		Show(piece("crown"))
		head1 = piece("crown")
		Move(head1, 2, 10)
end


if ValidID(unitID) then
for ct, piecenum in pairs (lvl1hides) do
	Hide(piecenum)
end
	level = 0
	randomness = math.random(-25,25)
	Hide (rbigflash)
	Hide (lfirept)
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
	Spring.UnitScript.StartThread(PassiveRepairs)
	Spring.SetUnitNanoPieces(unitID, {lfirept})
end
end

function HandleLevelUps()
while(true) do
if ValidID(unitID) then
local hp = Spring.GetUnitHealth(unitID)
if hp and hp > 1 and (Spring.GetUnitIsDead(unitID) == false) then
local null, fxp = Spring.GetUnitExperience(unitID)
local realxp = 10 * fxp
if realxp > 10 and level == 10 then
LevelUpModel(10)
LevelUpStats(10)
elseif realxp > 9 and level == 9 then
LevelUpModel(9)
LevelUpStats(9)
elseif realxp > 8 and level == 8 then
LevelUpModel(8)
LevelUpStats(8)
elseif realxp > 7 and level == 7 then
LevelUpModel(7)
LevelUpStats(7)
elseif realxp > 6 and level == 6 then
LevelUpModel(6)
LevelUpStats(6)
elseif realxp > 5 and level == 5 then
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
end
Sleep(1)
end
end
end

function switchpieces(piecenum1, piecenum2)
Hide(piecenum1)
Show(piecenum2)
end

function LevelUpStats(curLevel)
if ValidID(unitID) then
	level = curLevel + 1
	Spring.SetUnitMaxRange(unitID, Range[level])
	Spring.SetUnitArmored(unitID, true, DamageMultiplierNoDgun[level])

	for i = 23, 29 do
		if i - 22 == level - 1 or (i == 29 and i - 22 <= level -1) then
			Spring.SetUnitShieldState(unitID, i, true)
		else
			Spring.SetUnitShieldState(unitID, i, false)
		end
	end
	for i = 1,11 do
		Spring.SetUnitWeaponState(unitID,i, "range", Range[level])
	end
	for i = 12,22 do
		Spring.SetUnitWeaponState(unitID,i, "range", Range2[level])
	end
	Spring.SetUnitWeaponState(unitID,30, "reloadTime", ReloadTime3[level])
	Spring.SetUnitBuildSpeed(unitID, BuildSpeed[level], BuildSpeed[level], BuildSpeed[level]*0.7)
	Spring.SetUnitSensorRadius(unitID,"los", LOS[level])
	Spring.SetUnitSensorRadius(unitID,"airLos",LOS[level])
	Spring.SetUnitSensorRadius(unitID,"radar",Radar[level])
	Spring.SetUnitSensorRadius(unitID,"sonar",Sonar[level])
	Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", MoveSpeed[level]*30)
	curHP = Spring.GetUnitHealth(unitID)
	Spring.SetUnitHealth(unitID, curHP + HealOnLevelUp[level])
	Spring.SetUnitResourcing(unitID, "ume", EnergyMake[level])
	Spring.SetUnitResourcing(unitID, "umm", MetalMake[level])	
	cmdArrays = Spring.GetUnitCmdDescs(unitID)
	for ct, cmdarray in pairs(cmdArrays) do
		if cmdarray.id < 0 then
			if UnitDefs[-cmdarray.id] then
				local cmdIndex = Spring.FindUnitCmdDesc(unitID, cmdarray.id)
				disable = (level < ArmBuildOptions[UnitDefs[-cmdarray.id].name]) or (level >= (ArmBuildOptionsStop[UnitDefs[-cmdarray.id].name] or 12))
				cmdarray.disabled = disable
				Spring.EditUnitCmdDesc(unitID, cmdIndex, cmdarray)
			end
		elseif cmdarray.id == 31244 or cmdarray.id == 31143 then
				local cmdIndex = Spring.FindUnitCmdDesc(unitID, cmdarray.id)
				cmdarray.disabled = true
				Spring.EditUnitCmdDesc(unitID, cmdIndex, cmdarray)
		end
	end
end
end

function LevelUpModel(curLevel)
if ValidID(unitID) then
Emit(pelvis, CEGLevelUp)
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
	_,uwlaserheight = Spring.GetUnitPiecePosDir(unitID, torso)
	if uwlaserheight <= 0 then
		return false
	end
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
	_,uwlaserheight = Spring.GetUnitPiecePosDir(unitID, torso)
	if uwlaserheight > 0 then
		return false
	end
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
local x,y,z = Spring.GetUnitPosition(unitID)
local head = Spring.GetUnitHeading(unitID)
local featureID = Spring.CreateFeature(("armcom_dead"..level), x, y, z, head)
Spring.SetFeatureResurrect(featureID, "armcom", "s", 0)
return nil
end
