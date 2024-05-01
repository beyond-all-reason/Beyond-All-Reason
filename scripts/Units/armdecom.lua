-------------------------------------------------------
-- License:	Public Domain
-- Author:	Steve (Smoth) Smith
-- Date:	4/19/2014
-------------------------------------------------------

-- Piece names
	head		= piece 'head'
	base		= piece 'torso'
	l_arm		= piece 'luparm'
	l_forearm	= piece 'biggun'
	r_arm		= piece 'ruparm'
	r_forearm	= piece 'rloarm'
	lflare		= piece 'lflare'
	nano		= piece 'nano'
	laserflare	= piece 'laserflare'
	cod			= piece 'pelvis'
	right_l		= piece 'rthigh'
	left_l		= piece 'lthigh'
	shin_l		= piece 'lleg'
	shin_r		= piece 'rleg'
	foot_r		= piece 'rfoot'
	foot_l		= piece 'lfoot'
	dish		= piece 'dish'
	teleport    = piece 'teleport'

-- State variables
	isMoving, isAiming, isAimingDgun, isBuilding, counter = false, false, false, false, 0

-- used to restore build aiming
	buildY, buildX	= 0, 0
	firedWeapon		= false

-- Unit Speed
	speedMult		=	1.25

-- Unit animation preferences
	leftArm		=	true;
	rightArm	=	true;
	heavy		=	true;

-- Signal definitions
local SIG_AIM			=	2
local SIG_WALK			=	4

function script.StartMoving()
	isMoving = true
	StartThread(walk)
end

function script.StopMoving()
	isMoving = false
	StartThread(poser)
end

--#include "\headers\smoke.h"
include("include/walk.lua")

--------------------------------------------------------
--Teleport
--------------------------------------------------------
local function TeleportControl()
	Move(teleport,y_axis,1850,200000)
	Turn(teleport, x_axis, math.rad(90),math.rad(200000))
	Sleep(100)
	EmitSfx(teleport, 1025)
	Sleep(2200)
	EmitSfx(cod, 1026)
	Sleep(100)
	local counter = 0
	while counter < 23 do
		EmitSfx(teleport, 2051)
		Sleep(88)
		counter = counter + 1
	end
	Sleep(1000)
	Move(teleport,y_axis,0,200000)
end

--------------------------------------------------------
--start ups :)
--------------------------------------------------------
function script.Create()
	-- Initial State
	--StartThread(TeleportControl)
	Hide(nano)
	Turn(r_forearm, x_axis, math.rad(-15),math.rad(130))
	Turn(lflare, x_axis,math.rad(90))
	Turn(nano, x_axis,math.rad(90))
	Turn(laserflare, x_axis,math.rad(90))

	Spin(dish, y_axis, 2.5)

	if(heavy == true ) then
		SquatStance()
	else
		StandStance()
	end
	-- should do this instead of query nano piece
	Spring.SetUnitNanoPieces( unitID, {nano} )
end

-----------------------------------------------------------------------
--gun functions;
-----------------------------------------------------------------------
function script.AimFromWeapon(weaponID)
	if weaponID == 3 then
		return l_arm
	elseif weaponID == 4 then
		return base
	else
		return r_arm
	end
end

function script.QueryWeapon(weaponID)
	if weaponID == 3 then
		return lflare
	else
		return laserflare
	end
end

function Teleport()
	StartThread(TeleportControl)
end

-----------------------------------------------------------------------
-- This coroutine is restarted with each time a unit reaims,
-- not the most efficient and should be optimized. Possible
-- augmentation needed to lus.
-----------------------------------------------------------------------
local function RestoreAfterDelayLeft()
	Sleep(300)

	Turn(base, y_axis, 0, math.rad(305))
	Turn(l_forearm, x_axis, math.rad(-38), math.rad(95))
	Turn(l_arm, x_axis, 0, math.rad(95))

	isAiming = false
	isAimingDgun = false
end

local function RestoreAfterDelayRight()
	Sleep(1500)

	Turn(base, y_axis, 0, math.rad(305))
	Turn(r_forearm, x_axis, math.rad(-38), math.rad(95))
	Turn(r_arm, x_axis, 0, math.rad(95))

	isAiming = false
	isAimingDgun = false
end

function script.AimWeapon(weaponID, heading, pitch)
	--Never fire fake weapon used in comGate
	if weaponID == 4 then
		return false
	end

	-- Spring.Echo("AimWeapon " .. weaponID)
	-- weapon2 is supposed to only fire underwater, check for it.
	if weaponID == 2 then
		local _, basepos, _ = Spring.GetUnitPosition(unitID)
		if basepos > -16 then
			return false
		end
	end

	Turn(base, x_axis, 0, math.rad(395))
	Turn(cod, x_axis, 0, math.rad(395))

	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	isAiming = true

	if weaponID == 3 then
		FixArms(true, false)
		isAimingDgun = true

		Turn(base, y_axis, heading, math.rad(300))
		Turn(l_forearm, x_axis, math.rad(-85), math.rad(390))
		Turn(l_arm,	x_axis, math.rad(-5) - pitch, math.rad(390))

		WaitForTurn(base, y_axis)
		WaitForTurn(l_arm, x_axis)
		WaitForTurn(l_forearm, x_axis)
		-- Spring.Echo("AimWeapon done turning")

		StartThread(RestoreAfterDelayLeft)

		firedWeapon		= false
		-- Spring.Echo("AimWeapon end")
		return true
	elseif not isAimingDgun then
		FixArms(false, true)

		Turn(base, y_axis, heading, math.rad(300))
		Turn(r_forearm, x_axis, math.rad(-55), math.rad(390))
		Turn(r_arm,	x_axis, math.rad(-45) - pitch, math.rad(390))

		WaitForTurn(base, y_axis)
		WaitForTurn(r_arm, x_axis)
		WaitForTurn(r_forearm, x_axis)
		-- Spring.Echo("AimWeapon " .. weaponID .. " done turning")

		StartThread(RestoreAfterDelayRight)

		firedWeapon		= false
		-- Spring.Echo("AimWeapon " .. weaponID .. " end")
		return true
	end
end

function script.FireWeapon(weaponID)
	Sleep(500)
	firedWeapon		= true
	isAiming = false
	if weaponID == 3 then
		isAimingDgun = false
	end
end

function script.StartBuilding(heading, pitch)
	Show(nano)
--	Spring.Echo("StartBuilding")
	Spring.SetUnitNanoPieces( unitID, {nano} )
	isBuilding		= true;


	Turn(base, x_axis, 0, math.rad(395))
	Turn(cod, x_axis, 0, math.rad(395))

	Turn(base, y_axis, heading, math.rad(300))
	Turn(r_forearm, x_axis, math.rad(-55), math.rad(390))
	Turn(r_arm,	x_axis, math.rad(-55) - pitch, math.rad(390))

	WaitForTurn(r_arm, x_axis)
	SetUnitValue(COB.INBUILDSTANCE, 1)
end

function script.StopBuilding()
	Hide(nano)
	--Sleep(200) --SLEEPING HERE WILL FUCK YOUR SHIT UP!
	isBuilding		= false;
	SetUnitValue(COB.INBUILDSTANCE, 0)
--	Spring.Echo("Stop Building", isAiming, isBuilding, isMoving)
end

-----------------------------------------------------------------------
-- death stuffs
-----------------------------------------------------------------------
function script.Killed(recentDamage, maxHealth)
	return 1 --cause commdeath does nothing but.
	-- fall over
--	Turn(cod, x_axis, math.rad(270), 5)
	-- reset parts
	-- Turn(base, y_axis, 0, 8)
	-- Turn(r_arm, z_axis, 4, 3)
	-- Turn(l_arm, z_axis, -4, 3)
	-- fall
	-- Move(cod, y_axis, -30, 100)
	-- Turn(base, x_axis, 0.5, 8)
	-- Turn(right_l, x_axis, -0.5, 8)
	-- Turn(left_l, x_axis, -0.5, 8)
	-- WaitForMove(cod, y_axis)
	-- land
	-- Turn(r_forearm, x_axis, 0, 5)
	-- Turn(l_forearm, x_axis, 0, 5)
	-- Move(cod, y_axis, -35, 200)
	-- Turn(base, x_axis, 0, 10)
	-- Turn(right_l, x_axis, 0, 10)
	-- Turn(left_l, x_axis, 0, 10)
	-- WaitForMove(cod, y_axis)

	-- local severity = recentDamage/maxHealth
	-- if (severity <= 99) then
		-- Explode(l_arm, SFX.FALL)
		-- Explode(r_arm, SFX.FALL)
		-- Explode(l_arm, SFX.FALL)
		-- Explode(l_forearm, SFX.FALL)
		-- Explode(r_arm, SFX.FALL)
		-- Explode(r_forearm, SFX.FALL)
		-- return 3
	-- else
		-- return 0
	-- end
end
