hasWpn = true
sleeptime = 310*2

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
		firepieces = {{gun = rgun, flare = rflare, loarm = rloarm, uparm = ruparm}, {gun = lgun, flare = lflare, loarm = lloarm, uparm = luparm}},
		aimfrompiece = aimy1,
		counter = 1,
		subcounter = 1,
	}

function DrawWeapon(id)
	Turn(torso, 2, ang(0), ang(300.00))
	Turn(luparm, 1, ang(0), ang(300.000000))
	Turn(ruparm, 1, ang(0), ang(300.000000))
	Turn(lloarm, 1, ang(-90), ang(300.000000))
	Turn(rloarm, 1, ang(-90), ang(300.000000))
	WaitForTurn(lloarm, 1)
	WaitForTurn(rloarm, 1)
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
	local gun = weapons[weaponID].firepieces[ct].gun
	local loarm = weapons[weaponID].firepieces[ct].loarm
	local uparm = weapons[weaponID].firepieces[ct].uparm
	local flare = weapons[weaponID].firepieces[ct].flare
	EmitSfx(flare, SFX.CEG)
	Move(gun, 2, 1.5)
	Turn(loarm, 1, ang(-92.5))
	Turn(uparm, 1, ang(2.5))
	Turn(torso, 2, ang((-1)^(weapons[weaponID].counter)*(2.5)))
	Move(gun, 2, 0, 3)
	Turn(loarm, 1, ang(-90), ang(30))
	Turn(uparm, 1, ang(0), ang(30))
	Turn(torso, 2, ang(0), ang(30))

	weapons[weaponID].subcounter = (weapons[weaponID].subcounter + 1)
	if weapons[weaponID].subcounter > 3 then
		weapons[weaponID].subcounter = 1
		weapons[weaponID].counter = weapons[weaponID].counter + 1
	end
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
