	rockonwaves, base, turret, sleeve, cannon1, flare1, cannon2, flare2 = piece("rockonwaves", "base", "turret", "gun", "barrel1", "flare1", "barrel2", "flare2")
	piecetable = {base, turret, sleeve, cannon1, flare1, cannon2, flare2}

function script.Create()
	StartThread(SmokeUnit, {base, turret})
	COBturretYSpeed = 200
	COBturretXSpeed = 220
	COBkickbackRestoreSpeed = 10
	kickback = -10
	restoreTime = 3000
	COBrockStrength = 5
	COBrockSpeed = 30
	COBrockRestoreSpeed = 30
	firingCEG = "barrelshot-medium"
	rockStrength = ProcessAngularSpeeds(COBrockStrength)
	rockSpeed = ProcessAngularSpeeds(COBrockSpeed)
	rockRestoreSpeed = ProcessAngularSpeeds(COBrockRestoreSpeed)
	turretYSpeed = ProcessAngularSpeeds(COBturretYSpeed)
	turretXSpeed = ProcessAngularSpeeds(COBturretXSpeed)
	kickbackRestoreSpeed = ProcessLinearSpeeds(COBkickbackRestoreSpeed)
	smokeCEGName1="unitsmoke"
	gun1 = 1
	gun2 = 1
	hp = 100
	Hide(flare1)
	Hide(flare2)
	StartThread(RockOnWaves)
end

function RockOnWaves()
f = 0
while true do
f = f + 1
Turn(rockonwaves, 1, math.sin(f/23)*0.05)
Turn(rockonwaves,3,math.sin(f/18)*0.05)
Move(rockonwaves,2,math.sin(f/20.5)*2)
Sleep (math.random(1,2))
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
		end
	end
ru = 0
function script.RockUnit (x,z)
Spring.UnitScript.SetSignalMask(31)
local ux, uy, uz = Spring.GetUnitDirection(unitID)
nux = (ux /math.sqrt(ux^2 + uz^2))
nuz = (uz /math.sqrt(ux^2 + uz^2))
RockXFactor = -z
RockZFactor = x
k = rockStrength
while k > 0.1*rockStrength do
-- Spring.Echo(k/rockStrength)
Turn (base, 1, -RockXFactor*k*math.sin(ru/23))
Turn (base, 3, RockZFactor*k*math.sin(ru/18))
ru = ru + 1
k = 0.99 * k
Sleep (math.random(1,2))
end
end


function ProcessLinearSpeeds(speed)
convertedSpeed = speed
return convertedSpeed
end

function ProcessAngularSpeeds(speed)
convertedSpeed = speed*(2*math.pi)/360
return convertedSpeed
end

function Norm3DVectr(dx, dy, dz)
ndx = (math.abs(dx)/dx)*math.sqrt((dx^2)/(dx^2 + dy^2 + dz^2))
ndy = (math.abs(dy)/dy)*math.sqrt((dy^2)/(dx^2 + dy^2 + dz^2))
ndz = (math.abs(dz)/dz)*math.sqrt((dz^2)/(dx^2 + dy^2 + dz^2))
if dx == 0 then ndz = 0 end
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
return sleeve
end

function script.AimWeapon1( heading, pitch )
	Turn (turret, 2, heading, turretYSpeed)
	Turn (sleeve, 1, (0-pitch),turretXSpeed)
	WaitForTurn(turret, 2)
	WaitForTurn(sleeve, 1)
	return (true)
end

function script.FireWeapon1()
-- Spring.Echo(gun1)
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
	end
	Spring.UnitScript.Signal(31)
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
