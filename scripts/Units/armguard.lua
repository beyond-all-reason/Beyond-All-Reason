-- includes
include "include/constantFunctions.lua"

-- Piece assignment
local base, turret, barrel1, flare1, barrel2, flare2, sleeves
	= piece("base", "turret", "barrel1", "flare1", "barrel2", "flare2", "sleeves")
	
-- Signal definitions
local SIG_AIM1 = 1
local SIG_AIM2 = 2

-- Variables
local gunMode 				-- 0 is low , 1 is high
local isAimingNow 			-- love how simple this fix is to stop double gun fire
local weapon1LastHeading = 0
local weapon2LastHeading = 0

-- Constants
local TURRET_TURN_SPEED = 30.005495
local BARREL_TURN_SPEED = 45.005495
local BARREL_RETRACT_AMOUNT = -6.250000
local BARREL_RESTORE_SPEED = 2.500000
local RESTORE_GUNS_DELAY = 2500
local RESTORE_BARREL_DELAY = 100
local RESTORE_DELAY = 100
local RELOAD_DELAY = 2000
local LARGE_MUZZLE_FLASH_FX = 1024
local SMOKE_AMOUNT = 12			--lower more, higher less, zero defaults to 8

local SFXTYPE_BLACKSMOKE = 258

-- Collections
local aimPoints = {
	sleeves,
	sleeves, 				-- two weapons sharing the same barrels
}

local firePoints = {
	flare1,
	flare2,
}

local barrels = {
	barrel1,
	barrel2,
}

local smokePiece = {
	base, 
	turret,
}

-- Helpers
-- local function restoreMainGuns()
	-- Sleep(RESTORE_GUNS_DELAY)
	-- Turn(turret, y_axis, 0, math.rad(TURRET_TURN_SPEED))
	-- Turn(sleeves, x_axis, 0, math.rad(BARREL_TURN_SPEED))
-- end

local function restoreBarrel(num)
	Sleep(RESTORE_BARREL_DELAY)
	Move(barrels[num], z_axis, 0, BARREL_RESTORE_SPEED)
end

local function restoreAfterDelay()
	SetSignalMask(SIG_AIM)
	Sleep(RESTORE_DELAY)
end

local function reload()
	Sleep(RELOAD_DELAY)
end

-- Main Animation functions
function script.Create()
	--Spring.Echo("piece numbers: " .. base.. turret.. barrel1..flare1..barrel2..flare2..sleeves)
	Hide(flare1)			--  1       2         6       7         4       5        3
	Hide(flare2)
	currentBarrel = 0
	gunMode = 0
	isAimingNow = false
	StartThread (SmokeUnit(unitID, smokePiece, SMOKE_AMOUNT))
end

function script.Activate()
	--Spring.Echo("Activate")
	gunMode = 1
end

function script.Deactivate()
	--Spring.Echo("Deactivate")
	gunMode = 0
end

-- Weapons
function script.QueryWeapon(num)
	--Spring.Echo("query weapon number: " .. num)
	return firePoints[num]
end

function QueryBarrel(num)
	return barrels[num]
end

function script.AimFromWeapon(num)
	--Spring.Echo("aim from weapon number: " .. num)
	return aimPoints[num]
end

function script.AimWeapon(num, heading, pitch)
	--Spring.Echo("aim_weapon" .. num .. " gunMode: " .. gunMode .. " gun_2: " .. gun_2)
	if num == 1 then
		if (gunMode == 1 or isAimingNow == true) then
			return false
		end
		Signal(SIG_AIM1)
		isAimingNow = true
		Turn(turret, y_axis, heading, math.rad(TURRET_TURN_SPEED))
		Turn(sleeves, x_axis, -pitch, math.rad(BARREL_TURN_SPEED))
		WaitForTurn(turret, y_axis)
		WaitForTurn(sleeves, x_axis)
		--StartThread(restoreMainGuns)
		StartThread(restoreAfterDelay)
		weapon1LastHeading = heading
		isAimingNow = false
		return true
	else
		if (gunMode == 0 or isAimingNow == true) then
			return false
		end
		Signal(SIG_AIM1)
		isAimingNow = true
		Turn(turret, y_axis, heading, math.rad(TURRET_TURN_SPEED))
		Turn(sleeves, x_axis, -pitch, math.rad(BARREL_TURN_SPEED))
		WaitForTurn(turret, y_axis)
		WaitForTurn(sleeves, x_axis)
		--StartThread(restoreMainGuns)
		StartThread(restoreAfterDelay)
		weapon2LastHeading = heading
		isAimingNow = false
		return true
	end
end

function script.Shot(num)
	if (currentBarrel == 0) then
		--Spring.Echo("Fire barrel: " .. currentBarrel)
		EmitSfx(flare1, LARGE_MUZZLE_FLASH_FX)
		Move(barrel1, z_axis, BARREL_RETRACT_AMOUNT)
		StartThread(restoreBarrel, 1)
	end
	if (currentBarrel == 1) then
		--Spring.Echo("Fire barrel: " .. currentBarrel)
		EmitSfx(flare2, LARGE_MUZZLE_FLASH_FX)
		Move(barrel2, z_axis, BARREL_RETRACT_AMOUNT)
		StartThread(restoreBarrel, 2)
	end
	currentBarrel = currentBarrel + 1
	
	if (currentBarrel >= 2) then 
		currentBarrel = 0
	end
	StartThread(reload)
end

-- Death explosion
function script.Killed(recentDamage, maxHealth)

	local sfxEXP 	= SFX.EXPLODE
	local sfxNOHEAT 	= SFX.NO_HEATCLOUD
	local sfxFIRE	= SFX.FIRE
	local sfxSMOKE 	= SFX.SMOKE
	local sfxFALL	= SFX.FALL
	local sfxEOH	= SFX.EXPLODE_ON_HIT

	local severity = recentDamage / maxHealth
	
	if (severity <= .25) then
		corpsetype = 1 
		--Explode( base, sfxEXP + sfxNOHEAT)
		Explode( turret, sfxEXP + sfxNOHEAT)
		Explode( sleeves, sfxEXP + sfxNOHEAT)
		Explode( barrel2, sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT) 
		Explode( flare2, sfxEXP + sfxNOHEAT)
		Explode( barrel1, sfxEXP + sfxNOHEAT)
		Explode( flare1, sfxEXP + sfxNOHEAT)
		return(corpsetype)
		
	elseif (severity <= .50) then
		corpsetype = 2 
		--Explode( base, sfxEXP + sfxNOHEAT) 
		Explode( turret, sfxFALL + sfxNOHEAT) 
		Explode( sleeves, sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( barrel2, sfxFALL + sfxNOHEAT)
		Explode( flare2, sfxFALL + sfxNOHEAT)
		Explode( barrel1, sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( flare1, sfxFALL + sfxNOHEAT)
		return(corpsetype)
		
	elseif (severity <= .99) then -- 99
		corpsetype = 3 
		--Explode( base, sfxEXP + sfxNOHEAT)
		Explode( turret, sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( sleeves, sfxEOH + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( barrel2, sfxEOH + sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( flare2, sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( barrel1, sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( flare1, sfxSMOKE + sfxFALL + sfxNOHEAT)
		return(corpsetype)
	else
		corpsetype = 3 
		--Explode( base, sfxEXP + sfxNOHEAT)
		Explode( turret, sfxEOH + sfxFIRE + sfxFALL + sfxNOHEAT)
		Explode( sleeves, sfxEOH + sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( barrel2, sfxEOH + sfxFIRE + sfxFALL + sfxNOHEAT)
		Explode( flare2, sfxEOH + sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( barrel1, sfxEOH + sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		Explode( flare1, sfxEOH + sfxFIRE + sfxSMOKE + sfxFALL + sfxNOHEAT)
		return corpsetype
	end
end