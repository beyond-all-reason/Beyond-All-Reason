	uDef = UnitDefs[Spring.GetUnitDefID(unitID)]
	basename = uDef.customParams and uDef.customParams.basename or "base"
	turretname = uDef.customParams and uDef.customParams.turretname or "turret"
	sleevename = uDef.customParams and uDef.customParams.sleevename or "sleeve"
	cannon1name = uDef.customParams and uDef.customParams.cannon1name or "barrel"
	flare1name = uDef.customParams and uDef.customParams.flare1name or "flare"
	flare2name = uDef.customParams and uDef.customParams.flare2name or nil
	cannon2name = uDef.customParams and uDef.customParams.cannon2name or nil
	driftRatio = tonumber(uDef.customParams and uDef.customParams.driftratio) or 1
	smokeCEGName1 = uDef.customParams and uDef.customParams.smokecegname1 or "unitsmokefire"
	smokeCEGName2 = uDef.customParams and uDef.customParams.smokecegname2 or "unitsmokefirefire"
	smokeCEGName3 = uDef.customParams and uDef.customParams.smokecegname3 or "unitsmokefire"
	smokeCEGName4 = uDef.customParams and uDef.customParams.smokecegname4 or "unitsparkles"	
	wake1name, wake2name, wake3name, wake4name = "wake1", "wake2", "wake3", "wake4"
if cannon2name and flare2name then
	base, turret, sleeve, cannon1, flare1, flare2, cannon2, wake1, wake2, wake3, wake4 = piece(basename, turretname, sleevename, cannon1name, flare1name, flare2name, cannon2name,"wake1", "wake2", "wake3", "wake4")
	piecetable = {base, turret, sleeve, cannon1, flare1, cannon2, flare2}
else
	base, turret, sleeve, cannon1, flare1, wake1, wake2, wake3, wake4, wake5, wake6, wake7, wake8 = piece(basename, turretname, sleevename, cannon1name, flare1name,"wake1", "wake2", "wake3", "wake4","wake5", "wake6", "wake7", "wake8")
	piecetable = {base, turret, sleeve, cannon1, flare1}
end

function script.Create()
	StartThread(SmokeUnit, {base, turret})
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
	kickbackRestoreSpeed = ProcessLinearSpeeds(COBkickbackRestoreSpeed)
	gun1 = 1
	Spring.UnitScript.StartThread(UnitTurns)
	Spring.UnitScript.StartThread(UnitJumps)	
	hp = 100
	if flare1 then
	Hide(flare1)
	end
	if flare2 then
	Hide(flare2)
	end
end

function walk()
f= 0
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)	
	while (true) do
			x,y,z = Spring.GetUnitPosition(unitID)

			dx, dy, dz = Spring.GetUnitDirection(unitID)
			frontleft = Spring.GetGroundHeight(x+45*dx+10*(-dz), z+45*dz+10*dx)
			frontright = Spring.GetGroundHeight(x+45*dx+10*(dz), z+45*dz+10*(-dx))
			rearleft = Spring.GetGroundHeight(x-45*dx+10*(-dz), z-45*dz+10*dx)
			rearright = Spring.GetGroundHeight(x-45*dx+10*(dz), z-45*dz+10*(-dx))
			
			if frontleft <= 0 then frontleft = 0 end
			if frontright <= 0 then frontright = 0 end
			if rearleft <= 0 then rearleft = 0 end
			if rearright <= 0 then rearright = 0 end
			
			mediumfront = (frontleft + frontright) / 2
			mediumrear = (rearleft + rearright) / 2
			mediumleft = (frontleft + rearleft) / 2
			mediumright = (frontright + rearright) / 2
			
			alpha = math.atan((mediumfront - mediumrear)/(2025*dx^2 + 2025*dz^2))
			beta = math.atan((mediumleft - mediumright)/(100*dx^2 + 100*dz^2))
			-- Spring.Echo(beta)

			mediumheight = (mediumfront + mediumrear) / 2
			heightdiff = y - mediumheight
	
			Turn (base, 3, -beta*5, 0.5)
			Turn (base, 1, -alpha*20, 0.5)			
			if not Spring.UnitScript.IsInMove(base, 2) then
			Move (base, 2, 8 - heightdiff/2 + (math.random(-1,1)*3), 1)
			end

			if f%3 == 0 then
			Move(wake5, 3, 24)
			Move(wake5, 1, 5)
			Move(wake6, 3, 16)
			Move(wake6, 1, 5)
			Move(wake7, 3, -5)
			Move(wake7, 1, 25)
			Move(wake8, 3, -10)
			Move(wake8, 1, 25)
			Move(wake1, 3, -10)
			Move(wake1, 1, 5)
			Move(wake2, 3, 0)
			Move(wake2, 1, -20)
				Emit(wake1, 'unitsmokefire')
				Emit(wake2, 'unitsmokefire')
				-- Emit(wake3, 'unitsmokefire')
				-- Emit(wake4, 'unitsmokefire')
				-- Emit(wake5, 'unitsmokefire')
				-- Emit(wake6, 'unitsmokefire')
				-- Emit(wake7, 'unitsmokefire')
				Emit(wake8, 'unitsmokefire')
			x,y,z = Spring.GetUnitPosition(unitID)

				if Spring.GetGroundHeight(x,z) >= 0 then
				-- Move(wake1, 2, 0)
				-- Move(wake2, 2, 0)
				-- Move(wake3, 2, 0)
				-- Move(wake4, 2, 0)
				Emit(wake1, 'dirtsmall')
				Emit(wake2, 'dirtsmall')
				Emit(wake3, 'dirtsmall')
				Emit(wake4, 'dirtsmall')
				else
				-- Move(wake1, 2, -8)
				-- Move(wake2, 2, -8)
				-- Move(wake3, 2, -8)
				-- Move(wake4, 2, -8)
				Spring.UnitScript.EmitSfx(wake1, SFX.WAKE)
				Spring.UnitScript.EmitSfx(wake2, SFX.WAKE)
				Spring.UnitScript.EmitSfx(wake3, SFX.WAKE)
				Spring.UnitScript.EmitSfx(wake4, SFX.WAKE)
				end
			end
			Sleep(50)
			f = f + 1
	end
end

	function SmokeUnit(smokePieces)
		local n = #smokePieces
		while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
			Sleep(1000)
		end
		while true do
			local health = GetUnitValue(COB.HEALTH)
			if (health <= 66) then -- only smoke if less then 2/3rd health left
				randomnumber = math.random(1,(100-health))
				if  randomnumber >=80 then
				Emit(smokePieces[math.random(1,n)], smokeCEGName1) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName2) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName3) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName4) --CEG name in quotes (string)
				elseif randomnumber >= 66 then
				Emit(smokePieces[math.random(1,n)], smokeCEGName1) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName2) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName3) --CEG name in quotes (string)
				elseif randomnumber >= 50 then
				Emit(smokePieces[math.random(1,n)], smokeCEGName1) --CEG name in quotes (string)
				-- EmitRand(smokePieces[math.random(1,n)], smokeCEGName2) --CEG name in quotes (string)
				elseif randomnumber >= 34 then
				Emit(smokePieces[math.random(1,n)], smokeCEGName1) --CEG name in quotes (string)
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


function ProcessLinearSpeeds(speed)
convertedSpeed = speed
return convertedSpeed
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

function UnitTurns()
t = 0
heading = {}
vw = 0
while (true) do
difference = 0
heading[t] = Spring.GetUnitHeading(unitID)
if heading[t-1] then
	if heading[t-1] ~= heading[t] then
		difference = heading[t] - heading[t-1]

		else
		difference = 0
	end
	if math.abs(difference * 8 * 360 / 65536) <= 15 then
	-- difference = 0
	end
	difference = difference * 8 * 360 / 65536
	if difference > 50 then 
	difference = 50
	elseif difference < -50 then
	difference = -50
	end
	if difference ~= 0 then
	end

	if heading[t-2] then
		heading[t-2] = nil
	end
	_,_,_,vw = Spring.GetUnitVelocity(unitID)
	difference = (difference * vw * 30 / 112.5) * driftRatio
end
t = t+1
if vw * 30 / 112.5 > 1 then
-- Turn (base, 2, difference*(2*math.pi/360), vw * 30 / 112.5)
else
-- Turn (base, 2, difference*(2*math.pi/360), 1)
end
Sleep (50)
end
end

function UnitJumps()
k = 0
verticalSpeed = {}
while (true) do
_,verticalSpeed[k] = Spring.GetUnitVelocity(unitID)
	if verticalSpeed[k-1] then
	YAccel = (verticalSpeed[k]*30 - verticalSpeed[k-1]*30)/0.1
		if YAccel < - Game.gravity*0.15 then
			-- Move(base, 2,  2 , 5)	
		else
			-- Move(base, 2,  0 , 15)			
		end
	end
	if verticalSpeed[k-2] then
	verticalSpeed[k-2] = nil
	end
k = k+1
Sleep(100)
end
end

function Emit(pieceName, effectName)
local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID, pieceName)
Spring.SpawnCEG(effectName, x,y,z, 0, 0, -1)
end

function EmitRand(pieceName, effectName)
local x,y,z,dx,dy,dz	= Spring.GetUnitPiecePosDir(unitID, pieceName)
x,y,z,dx,dy,dz = x + 1.5*dx - 0.75*dz*(math.random(50,150)/100), y + 1.5*dy ,z + 1.5*dz + 0.75 * dx *(math.random(50,150)/100), dx,dy,dz
Spring.SpawnCEG(effectName, x,y,z, dx, dy, dz)
end

function script.StartMoving()
StartThread(walk)
end
	
function script.StopMoving()
-- Signal(SIG_WALK)
end

function Restore(sleeptime)
Spring.UnitScript.SetSignalMask(31)
Sleep(sleeptime)
	Turn (turret, 2, 0, turretYSpeed/2)
	Turn (sleeve, 1, 0, turretXSpeed/2)	
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
	Spring.UnitScript.StartThread(Restore, restoreTime)
	Turn (turret, 2, heading - difference*(2*math.pi/360), turretYSpeed)
	Turn (sleeve, 1, (0-pitch),turretXSpeed)
	WaitForTurn(turret, 2)
	WaitForTurn(sleeve, 1)
	return (true)
end

function script.Shot1()
-- Spring.Echo(gun1)
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
if f == 1 then
Spring.SetUnitNoSelect(unitID, true)
while f <=25 do
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
return 1
end

function script.Killed(recentDamage, maxHealth)
	severity = recentDamage*100/maxHealth
	if severity <= 25 then
		for count, piece in pairs(piecetable) do
			randomnumber = math.random(1,7)
			if randomnumber == 1 then
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
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
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
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
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
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
				Explode(piece, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.NO_HEATCLOUD + SFX.FALL)
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
