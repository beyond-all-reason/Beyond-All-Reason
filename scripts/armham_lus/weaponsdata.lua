hasWpn = true -- does the unit have weapons?
sleeptime = 1750*2 -- what's the restore delay ? (2* reloadtime sounds like a good default)
--Weapon 1
	local headSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turrety"]))/30 -- don't forget to set the turret speeds in the unitdefs
	local pitchSpeed = math.rad(tonumber(defs.customParams["wpn"..(tostring(1)).."turretx"]))/30 -- don't forget to set the turret speeds in the unitdefs
	weapons[1] = { 
		curHead = 0, curPitch = 0, wtdHead = 0, wtdPitch = 0, -- Default position
		wpnReady = true, -- Default state (== drawn or hidden)
		headSpeed = headSpeed, -- Aimspeeds
		pitchSpeed = pitchSpeed, -- Aimspeeds
		aimx = aimx1, -- Piece for x aiming (pitch)
		aimy = aimy1, -- Piece for y aiming (head)
		canFire = false, -- Initial state: weapon not ready to fire
		signal = 2^1, -- Signal value for restore threads
		aimfrompiece = aimy1, -- The piece from witch the aim calculations are done by engine
		firepieces = {flare = {rflare, lflare}, barrel = {rbarrel, lbarrel}, arm = {rarm, larm}}, -- when switching from right to left cannon, otherwise you don't need this
		counter = 1, -- when switching from right to left cannon, otherwise you don't need this
		-- subcounter = 1, -- when switching from right to left cannon between bursts (ie peewee 3rounds left then 3rounds right), otherwise you don't need this
	}

function DrawWeapon(id) -- do you need an animation of the unit drawing its weapons? (do it here and end it with "WeaponDrawn(weaponID)")
	WeaponDrawn(id)
end

function SetWantedAim(weaponID, heading, pitch) -- there shouldn't be any need to change this, unless the unit does aim in the x axis (wtdPitch always 0)
	weapons[weaponID].wtdHead = heading
	weapons[weaponID].wtdPitch = -pitch
end

function WeaponFire(weaponID) -- if you want an animation on each "fire" (1 per burst)

end

function WeaponShot(weaponID) -- if you want an animation on each "shot" (triggered at each projectile from a burst)
	local ct = weapons[weaponID].counter
	ct = ((ct + 1 <= 2) and ct + 1) or 1
	local flare = weapons[weaponID].firepieces.flare[ct]
	local barrel = weapons[weaponID].firepieces.flare[ct]
	local arm = weapons[weaponID].firepieces.flare[ct]
	EmitSfx(flare, SFX.CEG)
	Move(barrel, 2, 1.5)
	Turn(arm, 1, ang(-1.5))
	Move(barrel, 2, 0, 3)
	Turn(arm, 1, 0, ang(3))
	weapons[weaponID].counter = ct
end

function GetAimFromPiece(weaponID) -- Where should it aim from ?
	return weapons[weaponID].aimfrompiece
end

function GetQueryPiece(weaponID) -- where should it fire from ?
	return weapons[weaponID].firepieces.flare[weapons[weaponID].counter]
end
