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
		flare = {rflare, lflare},
		cannon = {rcannon, lcannon},
		counter = 1,
		-- subcounter = 1,
	}

function DrawWeapon(id)
	Turn(torso, 2, ang(0), ang(300.00))
	Turn(ruparm, 1, ang(0), ang(300.000000))
	Turn(luparm, 1, ang(0), ang(300))
	WaitForTurn(torso, 1)
	WaitForTurn(ruparm, 1)
	WaitForTurn(luparm, 1)
	WeaponDrawn(id)
end

function SetWantedAim(weaponID, heading, pitch)
	weapons[weaponID].wtdHead = heading
	weapons[weaponID].wtdPitch = -pitch
end

function WeaponFire(weaponID)
end

function WeaponShot(weaponID)
	weapons[weaponID].counter = weapons[weaponID].counter + 1
	if weapons[weaponID].counter >= 3 then
	 weapons[weaponID].counter = 1
	end
	Move(weapons[weaponID].cannon[weapons[weaponID].counter], 3, -10)
	Move(weapons[weaponID].cannon[weapons[weaponID].counter], 3, 0, 5)
end

function GetAimFromPiece(weaponID)
	return aimy1
end

function GetQueryPiece(weaponID)
	return weapons[weaponID].flare[weapons[weaponID].counter]		
end
