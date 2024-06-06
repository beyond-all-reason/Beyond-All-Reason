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
	Move(gun, 2, 1.5)
	Turn(loarm, 1, ang(-92.5))
	Turn(uparm, 1, ang(2.5))
	Move(gun, 2, 0, 3)
	Turn(loarm, 1, ang(-90), ang(5))
	Turn(uparm, 1, ang(0), ang(5))
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
