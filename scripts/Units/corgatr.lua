local necka = piece("necka")
local head = piece("head")
local neckb = piece("neckb")
local holder = piece("holder")

local missileFlares = { piece("flareaa"), piece("flareab"), piece("flareac"), piece("flaread") }
local rocketFlares = { piece("flareba"), piece("flarebb") }

local rad = math.rad
local GetGameFrame = Spring.GetGameFrame

local SIG_AIM = 2
local SIG_RESTORE = 4

local MAX_PITCH = rad(30)
local YAW_SPEED = rad(25)
local PITCH_SPEED = rad(15)
local COUNTER_SPEED = rad(22)
local RESTORE_DELAY = 5000

local weapons = UnitDefs[unitDefID].weapons
local ROCKET_RELOAD = WeaponDefs[weapons[2].weaponDef].reload * Game.gameSpeed

local MISSILE_COUNT = 8
local ROCKET_COUNT = 2
local MISSILE_DELAY = 1.75 * Game.gameSpeed
local CYCLE_RESET = 6 * Game.gameSpeed
local GATE_TIMEOUT = 2.5 * Game.gameSpeed
local NEW_ENGAGEMENT_GAP = 1.5 * Game.gameSpeed

local missileIndex = 1
local rocketIndex = 1
local missilesFired = 0
local rocketsFired = 0
local missileWindow = 0
local lastShotFrame = -CYCLE_RESET
local lastSalvoFrame = -ROCKET_RELOAD
local gateWaitStart = 0
local lastAimFrame = -NEW_ENGAGEMENT_GAP

local function ResetCycle()
	missilesFired = 0
	rocketsFired = 0
	missileIndex = 1
	rocketIndex = 1
end

local function RestoreAfterDelay()
	Signal(SIG_RESTORE)
	SetSignalMask(SIG_RESTORE + SIG_AIM)
	Sleep(RESTORE_DELAY)
	Turn(necka, y_axis, 0, YAW_SPEED)
	Turn(head, x_axis, 0, PITCH_SPEED)
	Turn(neckb, x_axis, 0, COUNTER_SPEED)
end

function script.Create()
	for i = 1, #missileFlares do
		Hide(missileFlares[i])
	end
	for i = 1, #rocketFlares do
		Hide(rocketFlares[i])
	end
end

function script.AimWeapon1(heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)

	local p = pitch
	if p > MAX_PITCH then
		p = MAX_PITCH
	elseif p < -MAX_PITCH then
		p = -MAX_PITCH
	end

	Turn(necka, y_axis, heading, YAW_SPEED)
	Turn(head, x_axis, -p, PITCH_SPEED)
	Turn(neckb, x_axis, p, COUNTER_SPEED)
	WaitForTurn(necka, y_axis)
	WaitForTurn(head, x_axis)
	StartThread(RestoreAfterDelay)

	local frame = GetGameFrame()
	if frame - lastShotFrame > CYCLE_RESET then
		ResetCycle()
	end
	if frame - lastAimFrame > NEW_ENGAGEMENT_GAP then
		gateWaitStart = frame
	end
	lastAimFrame = frame

	if rocketsFired >= ROCKET_COUNT and frame >= missileWindow then
		return true
	end
	return frame - gateWaitStart > GATE_TIMEOUT and frame - lastSalvoFrame >= ROCKET_RELOAD
end

function script.AimFromWeapon1()
	return head
end

function script.QueryWeapon1()
	return missileFlares[missileIndex]
end

-- Shot runs per shot, before QueryWeapon picks the muzzle
function script.Shot1()
	missilesFired = missilesFired + 1
	if missilesFired == 1 then
		lastSalvoFrame = GetGameFrame()
	end
	missileIndex = (missilesFired - 1) % #missileFlares + 1
	lastShotFrame = GetGameFrame()
	if missilesFired >= MISSILE_COUNT then
		ResetCycle()
	end
end

function script.AimWeapon2(heading, pitch)
	return true
end

function script.AimFromWeapon2()
	return head
end

function script.QueryWeapon2()
	return rocketFlares[rocketIndex]
end

function script.Shot2()
	rocketsFired = rocketsFired + 1
	rocketIndex = (rocketsFired - 1) % #rocketFlares + 1
	lastShotFrame = GetGameFrame()
	if rocketsFired >= ROCKET_COUNT then
		missileWindow = lastShotFrame + MISSILE_DELAY
	end
end

function script.Killed(recentDamage, maxHealth)
	local severity = recentDamage / maxHealth
	if severity <= 0.5 then
		Explode(head, SFX.FIRE + SFX.SMOKE + SFX.FALL)
		Explode(holder, SFX.FIRE + SFX.SMOKE + SFX.FALL)
		return 1
	else
		Explode(head, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.FALL)
		Explode(holder, SFX.EXPLODE_ON_HIT + SFX.FIRE + SFX.SMOKE + SFX.FALL)
		Explode(necka, SFX.FIRE + SFX.SMOKE + SFX.FALL)
		return 2
	end
end
