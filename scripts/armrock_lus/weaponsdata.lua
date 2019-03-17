hasWpn = true
sleeptime = 3800*2
--Weapon 1
	local headSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turrety"]))/30
	local pitchSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turretx"]))/30
	weapons[1] = { 
		curHead = 0, curPitch = 0, wtdHead = 0, wtdPitch = 0, -- Default position
		wpnReady = false, -- Default state (== drawn or hidden)
		headSpeed = headSpeed, -- Aimspeeds
		pitchSpeed = pitchSpeed, -- Aimspeeds
		aimx = aimx1, -- Piece for x aiming (pitch)
		aimy = aimy1, -- Piece for y aiming (head)
		canFire = false, -- Initial state: weapon not ready to fire
		signal = 2^1, -- Signal value for restore threads
		aimfrompiece = aimy1,
		-- counter = 1,
		-- subcounter = 1,
	}

function DrawWeapon(id)
	Turn(torso, 2, ang(0), ang(300.00))
	Turn(lmisspod, 1, ang(-90), ang(300.000000))
	Turn(rshield, 1, ang(90), ang(90))
	Move(rshield, 1, dist(1.5), dist(1.5))
	WaitForTurn(torso, 1)
	WaitForTurn(lmisspod, 1)
	WeaponDrawn(id)
end

function SetWantedAim(weaponID, heading, pitch)
	weapons[weaponID].wtdHead = heading
	weapons[weaponID].wtdPitch = -pitch
end

function WeaponFire(weaponID)
	EmitSfx(exhaust, SFX.CEG)
	Move(lbarrel, 2, 1.5)
	Move(lbarrel, 2, 0, 3)
end

function WeaponShot(weaponID)
end

function GetAimFromPiece(weaponID)
	return aimy1
end

function GetQueryPiece(weaponID)
	return flare
end
