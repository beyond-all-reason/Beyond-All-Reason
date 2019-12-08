hasWpn = true
sleeptime = 310*2

--Weapon 1
	local headSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turrety"]))/30
	local pitchSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turretx"]))/30
	weapons[1] = { 
		curHead = 0, curPitch = 0, wtdHead = 0, wtdPitch = 0, -- Default position
		wpnReady = true, -- Default state (== drawn or hidden)
		headSpeed = headSpeed, -- Aimspeeds
		pitchSpeed = pitchSpeed, -- Aimspeeds
		aimx = aimx1, -- Piece for x aiming (pitch)
		aimy = aimy1, -- Piece for y aiming (head)
		canFire = false, -- Initial state: weapon not ready to fire
		signal = 2^1, -- Signal value for restore threads
		firepieces = {{cannon = rcannon, flare = rflare, uparm = ruparm}, {cannon = lcannon, flare = lflare, uparm = luparm}},
		aimfrompiece = aimy1,
		counter = 1,
	}

function DrawWeapon(id)
	Turn(torso, 2, ang(0), ang(200.00))
	Turn(luparm, 1, ang(0), ang(200.000000))
	Turn(ruparm, 1, ang(0), ang(200.000000))
	WaitForTurn(luparm, 1)
	WaitForTurn(ruparm, 1)
	WeaponDrawn(id)
end

function SetWantedAim(weaponID, heading, pitch)
	weapons[weaponID].wtdHead = heading
	weapons[weaponID].wtdPitch = -pitch
end

function WeaponFire(weaponID)
end

function WeaponShot(weaponID)
	local ct = weapons[weaponID].counter
	local cannon = weapons[weaponID].firepieces[ct].cannon
	local uparm = weapons[weaponID].firepieces[ct].uparm
	local flare = weapons[weaponID].firepieces[ct].flare
	EmitSfx(flare, SFX.CEG)
	Move(cannon, 2, 1.5)
	Turn(uparm, 1, ang(2.5))
	Turn(torso, 2, ang((-1)^(weapons[weaponID].counter)*(2.5)))
	Move(cannon, 2, 0, 3)
	Turn(uparm, 1, ang(0), ang(30))
	Turn(torso, 2, ang(0), ang(30))

	weapons[weaponID].counter = weapons[weaponID].counter + 1
	if weapons[weaponID].counter > 2 then
		weapons[weaponID].counter = 1
	end
end

function GetAimFromPiece(weaponID)
	return weapons[weaponID].aimfrompiece
end

function GetQueryPiece(weaponID)
	return weapons[weaponID].firepieces[weapons[weaponID].counter].flare
end
