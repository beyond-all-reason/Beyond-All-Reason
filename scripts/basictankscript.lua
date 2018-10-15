	uDef = UnitDefs[Spring.GetUnitDefID(unitID)]
	basename = uDef.customParams and uDef.customParams.basename or "base"
	turretname = uDef.customParams and uDef.customParams.turretname or "turret"
	sleevename = uDef.customParams and uDef.customParams.sleevename or "sleeve"
	cannon1name = uDef.customParams and uDef.customParams.cannon1name or "barrel"
	flare1name = uDef.customParams and uDef.customParams.flare1name or "flare"
	flare2name = uDef.customParams and uDef.customParams.flare2name or nil
	cannon2name = uDef.customParams and uDef.customParams.cannon2name or nil
	driftRatio = tonumber(uDef.customParams and uDef.customParams.driftratio) or 1
	smokeCEGName1 = uDef.customParams and uDef.customParams.smokecegname1 or "unitsmoke"
	smokeCEGName2 = uDef.customParams and uDef.customParams.smokecegname2 or "unitsmokefire"
	smokeCEGName3 = uDef.customParams and uDef.customParams.smokecegname3 or "unitfire"
	smokeCEGName4 = uDef.customParams and uDef.customParams.smokecegname4 or "unitsparkles"	
	
if uDef.weapons[1] and uDef.weapons[1].mainDirX == 0 and uDef.weapons[1].mainDirY == 0 and uDef.weapons[1].maxAngleDif ~= -1 then
	local maxDiffDeg = uDef.weapons[1].maxAngleDif*360*65536*2
	local maxDiffRad = math.rad(maxDiffDeg)
	allowedHeadings1 = {}
	allowedHeadings1 = {0 - maxDiffDeg, 2*math.pi + maxDiffDeg}
end

if uDef.weapons[2] and uDef.weapons[2].mainDirX == 0 and uDef.weapons[2].mainDirY == 0 and uDef.weapons[2].maxAngleDif ~= -1 then
	local maxDiffDeg = uDef.weapons[2].maxAngleDif
	local maxDiffRad = math.rad(maxDiffDeg)
	allowedHeadings2 = {}
	allowedHeadings2 = {0 - maxDiffDeg, 2*math.pi + maxDiffDeg}
end
	
if cannon2name and flare2name then
	base, turret, sleeve, cannon1, flare1, flare2, cannon2 = piece(basename, turretname, sleevename, cannon1name, flare1name, flare2name, cannon2name)
	piecetable = {base, turret, sleeve, cannon1, flare1, cannon2, flare2}
else
	base, turret, sleeve, cannon1, flare1 = piece(basename, turretname, sleevename, cannon1name, flare1name)
	piecetable = {base, turret, sleeve, cannon1, flare1}
end

function script.Create()	
	wpn1_lasthead = 10000
	wpn2_lasthead = 10000
	COBturretYSpeed = tonumber(uDef.customParams and uDef.customParams.cobturretyspeed) or 200
	COBturretXSpeed = tonumber(uDef.customParams and uDef.customParams.cobturretxspeed) or 200
	COBkickbackRestoreSpeed = tonumber(uDef.customParams and uDef.customParams.kickbackrestorespeed) or 10
	kickback = tonumber(uDef.customParams and uDef.customParams.kickback) or -2	
	restoreTime = tonumber(uDef.customParams and uDef.customParams.restoretime) or 3000	
	COBrockStrength = tonumber(uDef.customParams and uDef.customParams.rockstrength) or 20
	COBrockSpeed = tonumber(uDef.customParams and uDef.customParams.rockspeed) or 60
	COBrockRestoreSpeed = tonumber(uDef.customParams and uDef.customParams.rockrestorespeed) or 60
	firingCEG = uDef.customParams and uDef.customParams.firingceg or "barrelshot-medium"
	rockStrength = ProcessAngularSpeeds(COBrockStrength)
	rockSpeed = ProcessAngularSpeeds(COBrockSpeed)
	rockRestoreSpeed = ProcessAngularSpeeds(COBrockRestoreSpeed)
	turretYSpeed = ProcessAngularSpeeds(COBturretYSpeed)
	turretXSpeed = ProcessAngularSpeeds(COBturretXSpeed)
	kickbackRestoreSpeed = COBkickbackRestoreSpeed
	gun1 = 1
	difference = 0
	StartThread(SmokeUnit, {base, turret})
	hp = 100
	if flare1 then
		Hide(flare1)
	end
	if flare2 then
		Hide(flare2)
	end
end

function SmokeUnit(smokePieces)
	local n = #smokePieces
	while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
		Sleep(1000)
	end
	while true do
		local health = GetUnitValue(COB.HEALTH)
		if (health <= 66) then
			randomnumber = math.random(1,(100-health))
			if  randomnumber >=80 then
			Emit(smokePieces[math.random(1,n)], smokeCEGName1)
			elseif randomnumber >= 66 then
			Emit(smokePieces[math.random(1,n)], smokeCEGName1)
			elseif randomnumber >= 50 then
			Emit(smokePieces[math.random(1,n)], smokeCEGName1)
			elseif randomnumber >= 34 then
			Emit(smokePieces[math.random(1,n)], smokeCEGName1)
			end
		end
		Sleep(health/100 * math.random(2500,15000))
		hp = health
		if hp >60 then 
			if not flare2 then
			if flare2name then
			Emit (cannon2,"unitsparkles")
			Sleep(100)
			flare2 = piece(flare2name)
			Show(cannon2)
			end
			end
		end
	end
end

function script.RockUnit (x,z)
	local ux, uy, uz = Spring.GetUnitDirection(unitID)
	nux = (ux /math.sqrt(ux^2 + uz^2))
	nuz = (uz /math.sqrt(ux^2 + uz^2))
	RockXFactor = -z
	RockZFactor = x
	Turn (base, 1, -RockXFactor*rockStrength, rockSpeed)
	Turn (base, 3, RockZFactor*rockStrength, rockSpeed)
	Sleep (50)
	Turn (base, 1, 0, rockRestoreSpeed)
	Turn (base, 3, 0, rockRestoreSpeed)
end

function ProcessAngularSpeeds(speed)
convertedSpeed = speed*(2*math.pi)/360
return convertedSpeed
end

function GetIsTerrainWater()
	x,y,z = Spring.GetUnitPosition(unitID)
	if Spring.GetGroundHeight(x,z)<= -8 then
		return true
	else
		return false
	end
end

function script.ChangeHeading(curDelta)
	if not lastDelta then lastDelta = curDelta end
	delta = (lastDelta*80 + curDelta*20)/100
	_,_,_,vw = Spring.GetUnitVelocity(unitID)
	currentSpeed = vw * 30 / uDef.speed
	difference = math.rad(delta/25) * driftRatio * currentSpeed
	Turn (base, 2, difference, currentSpeed)
	lastDelta = delta
end

function Norm3DVectr(dx, dy, dz)
	ndx = (math.abs(dx)/dx)*math.sqrt((dx^2)/(dx^2 + dy^2 + dz^2))
	ndy = (math.abs(dy)/dy)*math.sqrt((dy^2)/(dx^2 + dy^2 + dz^2))
	ndz = (math.abs(dz)/dz)*math.sqrt((dz^2)/(dx^2 + dy^2 + dz^2))
	if dx == 0 then ndx = 0 end
	if dy == 0 then ndy = 0 end
	if dz == 0 then ndz = 0 end
	return ndx, ndy, ndz
end

function Emit(pieceName, effectName)
	local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID, pieceName)
	ndx, ndy, ndz = Norm3DVectr(dx, dy, dz)
	Spring.SpawnCEG(effectName, x,y,z, ndx, ndy, ndz)
end

function EmitRand(pieceName, effectName)
	local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID, pieceName)
	x,y,z,dx,dy,dz = x + 1.5*dx - 0.75*dz*(math.random(50,150)/100), y + 1.5*dy ,z + 1.5*dz + 0.75 * dx *(math.random(50,150)/100), dx,dy,dz
	Spring.SpawnCEG(effectName, x,y,z, dx, dy, dz)
end

function script.StartMoving()
end
	
function script.StopMoving()
end

function Restore(sleeptime)
	Spring.UnitScript.SetSignalMask(31)
	Sleep(sleeptime)
	Turn (turret, 2, 0, turretYSpeed/2)
	Turn (sleeve, 1, 0, turretXSpeed/2)	
	wpn1_lasthead = 10000
	wpn2_lasthead = 10000
	Spring.UnitScript.WaitForTurn ( turret, 2 )
	Spring.UnitScript.WaitForTurn ( sleeve, 2 )
end

function script.QueryWeapon1()
	if flare2 then
		if gun1 == 2 then
			return flare1
		else
			return flare2
		end
	else
		return flare1	
	end
end

function script.AimFromWeapon1()
	return turret
end

function script.AimWeapon1( heading, pitch )
	Spring.UnitScript.Signal(31)
	if allowedHeadings1 ~= nil and (heading > allowedHeadings1[1] and heading < allowedHeadings1[2]) then
		Turn (turret, 2, 0, turretYSpeed)
		return(false)
	end
	Spring.UnitScript.StartThread(Restore, restoreTime)
	Turn (turret, 2, heading - difference*(2*math.pi/360), turretYSpeed)
	Turn (sleeve, 1, (0-pitch),turretXSpeed)
	if (math.abs(wpn1_lasthead - heading) > 2*math.pi) or ((math.abs(wpn1_lasthead - heading) >= turretYSpeed/30) and (math.abs(wpn1_lasthead - heading) <= (2*math.pi - turretYSpeed/30))) then
		wpn1_lasthead = 10000
		WaitForTurn(turret, 2)
		WaitForTurn(sleeve, 1)
	end
	wpn1_lasthead = heading
	return (true)
end

function script.Shot1()
	if flare2 then
		if gun1 == 1 then
			Emit(flare1, firingCEG)
			Move(cannon1, 3, kickback)
			Move(cannon1, 3, 0, kickbackRestoreSpeed)
			gun1 = 2
		else
			Emit(flare2, firingCEG)
			Move(cannon2, 3, kickback)
			Move(cannon2, 3, 0, kickbackRestoreSpeed)
			gun1 = 1
			if hp < 30 then
			Explode(cannon2, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
			Hide(cannon2)
			flare2 = nil
			end
		end
	else
		Emit(flare1, firingCEG)
		Move(cannon1, 3, kickback)
		Move(cannon1, 3, 0, kickbackRestoreSpeed)
	end
	Spring.UnitScript.Signal(31)
	Spring.UnitScript.StartThread(Restore,restoreTime)
end

function script.QueryWeapon2()
	if flare2 then
		if gun1 == 2 then
			return flare1
		else
			return flare2
		end
	else
		return flare1	
	end
end

function script.AimFromWeapon2()
	return turret
end

function script.AimWeapon2( heading, pitch )
	x,y,z = Spring.GetUnitPiecePosDir(unitID, turret)
	if y < 0 then
		Spring.UnitScript.Signal(31)
		if allowedHeadings2 ~= nil and (heading > allowedHeadings2[1] and heading < allowedHeadings2[2]) then
			Turn (turret, 2, 0, turretYSpeed)
			return(false)
		end
		Spring.UnitScript.StartThread(Restore, restoreTime)
		Turn (turret, 2, heading - difference*(2*math.pi/360), turretYSpeed)
		Turn (sleeve, 1, (0-pitch),turretXSpeed)
		if (math.abs(wpn2_lasthead - heading) > 2*math.pi) or ((math.abs(wpn2_lasthead - heading) >= turretYSpeed/30) and (math.abs(wpn2_lasthead - heading) <= (2*math.pi - turretYSpeed/30))) then
			wpn2_lasthead = 10000
			WaitForTurn(turret, 2)
			WaitForTurn(sleeve, 1)
		end
		wpn2_lasthead = heading
		return (true)
	else
		-- Spring.Echo("overwater")
		return (false)
	end
end

function script.Shot2()
	if flare2 then
		if gun1 == 1 then
			Emit(flare1, firingCEG)
			Move(cannon1, 3, kickback)
			Move(cannon1, 3, 0, kickbackRestoreSpeed)
			gun1 = 2
		else
			Emit(flare2, firingCEG)
			Move(cannon2, 3, kickback)
			Move(cannon2, 3, 0, kickbackRestoreSpeed)
			gun1 = 1
			if hp < 30 then
			Explode(cannon2, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
			Hide(cannon2)
			flare2 = nil
			end
		end
	else
		Emit(flare1, firingCEG)
		Move(cannon1, 3, kickback)
		Move(cannon1, 3, 0, kickbackRestoreSpeed)
	end
	Spring.UnitScript.Signal(31)
	Spring.UnitScript.StartThread(Restore,restoreTime)
end

function DeathRun()
	smokePieces = {base, turret}
	if Spring.GetGameFrame() >= 30*60*7 then
		if f == 1 then
			Spring.SetUnitNoSelect(unitID, true)
			while f <= 18 do
				randomnumber = math.random(1,4)
				if randomnumber == 1 then
					smokeCEGName = smokeCEGName1
				elseif randomnumber == 2 then
					smokeCEGName = smokeCEGName2
				elseif randomnumber == 3 then
					smokeCEGName = smokeCEGName3
				else
					smokeCEGName = smokeCEGName4
				end
				EmitRand(smokePieces[math.random(1,2)], smokeCEGName) --CEG name in quotes (string)
				Sleep(math.random(5,100))
				f = f + 1
			end
		end
		EmitRand(base, "genericunitexplosion-small" )
	end
	return 1
end

function script.Killed(recentDamage, maxHealth)
	severity = recentDamage*100/maxHealth
	if severity <= 25 then
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,7)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER)
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 1
	elseif severity <=50 then
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,5)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER)
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 2
	elseif severity <= 99 then
		randomnumber = math.random(1,2)
		if randomnumber == 1 then
			f = 1
			while DeathRun()~=1 do
			end
		end
		for count, piece in pairs(piecetable) do

			randomnumber = math.random(1,3)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER)
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 3
	else
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,2)
			if randomnumber == 1 then
				if piece == base then 
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL + SFX.SHATTER)
				else
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
				end
			elseif randomnumber == 2 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.SHATTER + SFX.NO_HEATCLOUD)
			else
				Explode(piece, SFX.SHATTER + SFX.NO_HEATCLOUD)
			end
			Hide(piece)
		end
		return 3
	end
end
