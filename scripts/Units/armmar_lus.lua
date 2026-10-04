dist = function(v)
	return v
end

ang = math.rad

timedTurn = function(piece, axis, goal, amount, t)
	local speed = amount/(t/1000)
	Turn(piece, axis, goal, speed)
end

timedMove = function(piece, axis, goal, amount, t)
	local speed = amount/(t/1000)
	Move(piece, axis, goal, speed)
end
	
unitDefID = Spring.GetUnitDefID(unitID)
defs = UnitDefs[unitDefID]
unitName = UnitDefs[unitDefID].name

-- rename scavenger unit
unitName = string.gsub(unitName, '_scav', '')

pi = math.pi
abs = math.abs
pi2 = pi*2
hasWpn = false
currentSpeed = 200
weapons = {}

include("units/"..unitName.."_lus/setup.lua")
include("units/"..unitName.."_lus/move.lua")
include("units/"..unitName.."_lus/weaponsdata.lua")
	
isMoving, isAiming, isBuilding, counter, canAim, isInLoop, isUW = false, false, false, 0, false, false, false
step = 1
	
function MotionControl()
	local justmoved = true
	while true do
		step = 1
		local aim = isAiming
		local move = isMoving
		if move then
			if aim then
				if not isUW then
					canAim = true
					StartThread(walklegs)
					while isInLoop do
						Sleep(1)
					end
				else
					canAim = true
					StartThread(swim)
					while isInLoop do
						Sleep(1)
					end
				end
			else
				if not isUW then
					canAim = false
					StartThread(walk)
					while isInLoop do
						Sleep(1)
					end
				else
					canAim = false
					StartThread(swim)
					while isInLoop do
						Sleep(1)
					end
				end
			end
			justmoved = true
		else
			canAim = true
			if justmoved then	
				StartThread(RestoreLegs)
				if not aim then
					StartThread(RestoreArms)
				end
				justmoved = false
			end
		end
		Sleep(1)
	end
end

function ypos()
	while true do
		local _,y = Spring.GetUnitPosition(unitID)
		isUW = (y < -60)
		Sleep(500)
	end
end

function WeaponControl()
	while true do
		for weaponID, data in pairs(weapons) do
		local data = weapons[weaponID]
			local curHead, wtdHead, curPitch, wtdPitch = data.curHead, data.wtdHead, data.curPitch, data.wtdPitch
			local wpnReady = data.wpnReady
			local headSpeed = data.headSpeed
			local pitchSpeed = data.pitchSpeed
			local aimy, aimx = data.aimy, data.aimx
			local headReady = false
			local pitchReady = false
			if curHead < 0 then
				curHead = pi2 + curHead
			elseif curHead >= pi2 then
				curHead = curHead -(pi2)
			end
			if curPitch < 0 then
				curPitch = pi2 + curPitch
			elseif curPitch >= pi2 then
				curPitch = curPitch -pi2
			end
			if canAim then
				local diffHead = wtdHead - curHead
				local diffPitch = wtdPitch - curPitch
				if diffHead < -pi then
					diffHead = diffHead + pi2
				elseif diffHead >= pi then
					diffHead = diffHead - pi2
				end
				if diffPitch < -pi then
					diffPitch = diffPitch + pi2
				elseif diffPitch >= pi then
					diffPitch = diffPitch - pi2
				end
				local absdiffHead = abs(diffHead)
				local absdiffPitch = abs(diffPitch)
				if absdiffHead > headSpeed then
					if diffHead < 0 then
						curHead = curHead - headSpeed
					else
						curHead = curHead + headSpeed
					end
				else
					curHead = wtdHead
					headReady = true
				end
				if absdiffPitch > pitchSpeed  then
					if diffPitch < 0 then
						curPitch = curPitch - pitchSpeed
					else
						curPitch = curPitch + pitchSpeed
					end
				else
					curPitch = wtdPitch
					pitchReady = true
				end
				for id,piecenum in pairs (aimy) do
					Turn(piecenum, 2, curHead)
				end
				for id,piecenum in pairs (aimx) do
					Turn(piecenum, 1, curPitch)
				end
				weapons[weaponID].curHead = curHead
				weapons[weaponID].curPitch = curPitch
				local canFire = headReady and pitchReady and wpnReady
				weapons[weaponID].canFire = canFire
			else
				weapons[weaponID].canFire = false
			end
		end
		Sleep(1)
	end
end
	
function script.StartMoving()
	isMoving = true
end

function script.StopMoving()
	isMoving = false
end	

function script.Create()
	InitialPiecesSetup()
	StartThread(MotionControl)
	StartThread(ypos)
	if hasWpn then
		StartThread(WeaponControl)
	end
end

function LastCallCheck(weaponID)
	local f = Spring.GetGameFrame()
	if not weapons[weaponID].lastCall then
		weapons[weaponID].lastCall = f
	end
	if  weapons[weaponID].lastCall ~= f-1 then
		weapons[weaponID].canFire = false
	end
	weapons[weaponID].lastCall = f
end

function RestoreWeaponAim(weaponID)
	weapons[weaponID].wtdHead = 0
	weapons[weaponID].wtdPitch = 0
end

function RestoreProgress(weaponID)
	return (weapons[weaponID].curHead == 0 and weapons[1].curPitch == 0)
end

function RestoreAfterDelay(weaponID)
	SetSignalMask(2)
	Sleep(sleeptime)
	RestoreWeaponAim(weaponID)
	RestoreArms()
	weapons[weaponID].wpnReady = false
	local restored = false
	while not restored do
		restored = RestoreProgress(weaponID)
		Sleep(100)
	end
	isAiming = false
end

function WeaponDrawn(weaponID)
	weapons[weaponID].wpnReady = true
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(2)
	StartThread(RestoreAfterDelay, weaponID)
	isAiming = true
	if not weapons[weaponID].wpnReady then
		StartThread(DrawWeapon, weaponID)
	end
	LastCallCheck(weaponID)
	SetWantedAim(weaponID, heading, pitch)
	return weapons[weaponID].canFire
end

function script.Shot(weaponID)
	WeaponShot(weaponID)
end

function script.FireWeapon(weaponID)
	WeaponFire(weaponID)
end

function script.AimFromWeapon(weaponID)
	return GetAimFromPiece(weaponID)
end

function script.QueryWeapon(weaponID)
	return GetQueryPiece(weaponID)
end

function script.Killed(recentDamage, maxHealth)
	-- fixme: could use exploding bits

	local severity = recentDamage / maxHealth
	if severity > 0.99 then
		return 3
	elseif severity > 0.50 then
		return 2
	else
		return 1
	end
end
