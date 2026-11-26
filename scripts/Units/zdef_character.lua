-- Articulated 11-bone Lua unit script driven by all 8 embedded GLB/MDL animation clips:
-- (Idle, Walk, Run, Attack, Bite, Hit, Death, Scream)
local ANIM_DATA = VFS.Include("scripts/Units/zdef_anim_data.lua") or {}

local pieceMap = Spring.GetUnitPieceMap(unitID) or {}
local function safePiece(name)
	if pieceMap[name] then
		return piece(name)
	end
	return nil
end

local base = safePiece("base")
local hips = safePiece("hips") or safePiece("body") or base
local torso = safePiece("torso") or hips
local head = safePiece("head")
local uarm_l = safePiece("uarm_l")
local larm_l = safePiece("larm_l")
local uarm_r = safePiece("uarm_r")
local larm_r = safePiece("larm_r")
local uleg_l = safePiece("uleg_l")
local lleg_l = safePiece("lleg_l")
local uleg_r = safePiece("uleg_r")
local lleg_r = safePiece("lleg_r")
local flare = safePiece("flare") or larm_r or torso

local PIECES = {
	hips = hips,
	torso = torso,
	head = head,
	uarm_l = uarm_l,
	larm_l = larm_l,
	uarm_r = uarm_r,
	larm_r = larm_r,
	uleg_l = uleg_l,
	lleg_l = lleg_l,
	uleg_r = uleg_r,
	lleg_r = lleg_r,
}

local unitDefID = Spring.GetUnitDefID(unitID)
local unitName = (unitDefID and UnitDefs[unitDefID] and UnitDefs[unitDefID].name) or "zdef_zombie_walker"
local unitClips = ANIM_DATA[unitName] or ANIM_DATA["zdef_zombie_walker"] or {}
local isZombie = (unitName:find("zombie") ~= nil)

local SIG_MOVE = 2
local SIG_AIM = 4
local SIG_IDLE = 8
local SIG_HIT = 16
local isMoving = false
local isAiming = false
local isDying = false
local lastHitTime = 0
local aimHeading = 0.0
local aimPitch = 0.0
local lostLimbs = {} -- pieceName -> true when dismembered (legs uleg_l, lleg_l, uleg_r, lleg_r, hips NEVER detach!)

local function dropPieceThread(pnum)
	-- Infantry bullet hit: limb/head/torso simply drops straight down to the ground (NO upward Explode fling!)
	Turn(pnum, x_axis, math.rad(78), math.rad(380))
	Turn(pnum, z_axis, math.rad(math.random(-45, 45)), math.rad(300))
	Move(pnum, y_axis, -7.5, 24.0)
	Sleep(260)
	Hide(pnum)
end

local function dropZombiePieceByBullet(pname, pnum)
	if not pnum or lostLimbs[pname] then return false end
	lostLimbs[pname] = true
	if pname == "uarm_l" and larm_l and not lostLimbs["larm_l"] then
		lostLimbs["larm_l"] = true
		Hide(larm_l)
	elseif pname == "uarm_r" and larm_r and not lostLimbs["larm_r"] then
		lostLimbs["larm_r"] = true
		Hide(larm_r)
	end
	StartThread(dropPieceThread, pnum)
	return true
end

local function blastZombiePieceByOrdnance(pname, pnum)
	-- Heavy Ordnance (Tank 120mm HE, A-10 30mm GAU-8, AC-130 105mm, F-16 Missile/Bomb):
	-- Violently blasts pieces flying through the air!
	if not pnum or lostLimbs[pname] then return false end
	lostLimbs[pname] = true
	if pname == "uarm_l" and larm_l and not lostLimbs["larm_l"] then
		lostLimbs["larm_l"] = true
		Explode(larm_l, SFX.FALL + SFX.NO_HEATCLOUD)
		Hide(larm_l)
	elseif pname == "uarm_r" and larm_r and not lostLimbs["larm_r"] then
		lostLimbs["larm_r"] = true
		Explode(larm_r, SFX.FALL + SFX.NO_HEATCLOUD)
		Hide(larm_r)
	end
	local flags = SFX.FALL + SFX.NO_HEATCLOUD
	if pname == "torso" or math.random(1, 100) <= 35 then
		flags = SFX.SHATTER + SFX.FALL + SFX.NO_HEATCLOUD
	end
	Explode(pnum, flags)
	Hide(pnum)
	return true
end

local function applyPoseFrame(frameTable, durationSec, skipUpperBody)
	if not frameTable then return end
	local dt = math.max(0.04, durationSec or 0.16)
	for pname, pnum in pairs(PIECES) do
		if pnum and not lostLimbs[pname] and not (skipUpperBody and (pname == "torso" or pname == "head" or pname == "uarm_l" or pname == "larm_l" or pname == "uarm_r" or pname == "larm_r")) then
			local rot = frameTable[pname]
			local rx = (rot and rot[1]) or 0.0
			local ry = (rot and rot[2]) or 0.0
			local rz = (rot and rot[3]) or 0.0
			if rx > 1.65 then rx = 1.65 elseif rx < -1.65 then rx = -1.65 end
			if ry > 1.35 then ry = 1.35 elseif ry < -1.35 then ry = -1.35 end
			if rz > 1.35 then rz = 1.35 elseif rz < -1.35 then rz = -1.35 end
			local speed = math.max(1.4, math.abs(rx) / dt + 2.0)

			-- When infantry/paratrooper is aiming or firing at a target:
			-- Keep torso y_axis + x_axis locked onto (aimHeading - hips.ry, -aimPitch) so the rifle barrel ALWAYS points directly at the bullet trajectory!
			if not isZombie and isAiming then
				if pname == "torso" then
					local hipsRot = frameTable.hips
					local hipsRy = (hipsRot and hipsRot[2]) or 0.0
					rx = rx - aimPitch
					ry = aimHeading - hipsRy
					speed = math.rad(480)
				elseif pname == "hips" then
					-- While stationary and aiming, keep hips aligned with torso so the whole soldier faces the target!
					if not isMoving then
						ry = ry + aimHeading * 0.35
					end
				end
			end

			Turn(pnum, x_axis, rx, speed)
			Turn(pnum, y_axis, ry, speed)
			Turn(pnum, z_axis, rz, speed)
		end
	end
end

local function IdleLoop()
	Signal(SIG_IDLE)
	SetSignalMask(SIG_IDLE)
	local clip = unitClips.Idle
	if not clip or #clip == 0 then return end
	local step = 1
	while not isMoving and not isDying do
		applyPoseFrame(clip[step], 0.42, isAiming)
		Sleep(420)
		step = (step % #clip) + 1
	end
end

local function MoveLoop()
	Signal(SIG_MOVE)
	SetSignalMask(SIG_MOVE)
	Signal(SIG_IDLE)
	local step = 1
	while isMoving and not isDying do
		-- Dynamically read current gait ("walk" or "run") set by tactical AI / zombie state
		local gait = Spring.GetUnitRulesParam(unitID, "zdef_gait")
		local isRunning = (gait == "run")
		if gait == nil then
			-- Fallback: check live unit speed vs walk threshold
			local vx, _, vz = Spring.GetUnitVelocity(unitID)
			local spd30 = math.sqrt((vx or 0) * (vx or 0) + (vz or 0) * (vz or 0)) * 30.0
			isRunning = isZombie and (spd30 > 18.0) or (spd30 > 24.5)
		end

		local clip = (isRunning and unitClips.Run) or unitClips.Walk or unitClips.Run
		if not clip or #clip == 0 then return end
		local stepMs
		if isZombie then
			stepMs = isRunning and 155 or 245 -- Slow shambling Walk (245ms/frame) vs aggressive Run (155ms/frame)
		else
			stepMs = isRunning and 130 or 205 -- Tactical Walk (205ms/frame) vs Combat Sprint Run (130ms/frame)
		end
		local stepSec = stepMs / 1000.0
		if step > #clip then step = 1 end

		applyPoseFrame(clip[step], stepSec, isAiming and not isZombie)
		if hips then
			local bobAmp = isRunning and 0.42 or 0.22
			local bob = ((step % 2 == 1) and bobAmp) or 0.0
			Move(hips, y_axis, bob, isRunning and 4.2 or 2.5)
		end
		Sleep(stepMs)
		step = (step % #clip) + 1
	end
end

local function PlayScreamIntro()
	if not isZombie or not unitClips.Scream or #unitClips.Scream < 4 then return end
	if unitName == "zdef_zombie_soldier" or unitName == "zdef_zombie_brute" or (unitID % 5 == 0) then
		for i = 2, #unitClips.Scream do
			if isMoving or isDying then break end
			applyPoseFrame(unitClips.Scream[i], 0.14, false)
			Sleep(140)
		end
	end
end

local function RestoreAimAfterDelay()
	Sleep(2200)
	isAiming = false
	aimHeading = 0.0
	aimPitch = 0.0
	if torso and not isDying then
		Turn(torso, y_axis, 0, math.rad(180))
		Turn(torso, x_axis, 0, math.rad(180))
	end
	if hips and not isMoving and not isDying then
		Turn(hips, y_axis, 0, math.rad(180))
	end
	if not isMoving and not isDying then
		StartThread(IdleLoop)
	end
end

function script.Create()
	if flare and flare ~= torso and flare ~= larm_r then
		Hide(flare)
	end
	StartThread(PlayScreamIntro)
	StartThread(IdleLoop)
end

function script.StartMoving()
	if isDying then return end
	isMoving = true
	StartThread(MoveLoop)
end

function script.StopMoving()
	isMoving = false
	Signal(SIG_MOVE)
	if hips and not isDying then
		Move(hips, y_axis, 0, 5.0)
	end
	if not isDying then
		StartThread(IdleLoop)
	end
end

-- Play embedded GLB 'Hit' flinch animation when shot by bullets!
local function HitFlinchThread()
	Signal(SIG_HIT)
	SetSignalMask(SIG_HIT)
	if isDying then return end
	local hitClip = unitClips.Hit
	if hitClip and #hitClip >= 4 then
		applyPoseFrame(hitClip[2], 0.08, false)
		Sleep(85)
		applyPoseFrame(hitClip[4], 0.09, false)
		Sleep(90)
		applyPoseFrame(hitClip[6], 0.10, false)
	elseif torso then
		Turn(torso, x_axis, -0.28, math.rad(360))
		Sleep(90)
		Turn(torso, x_axis, 0.0, math.rad(220))
	end
end

function script.HitByWeapon(x, z, weaponDefID, damage)
	if isDying then return damage end

	-- Progressive Dismemberment when Zombie is shot by Infantry AKS-74U / MRAP bullets:
	-- Single random upper-body piece (larm_l, larm_r, uarm_l, uarm_r, head) simply drops down to the ground (rụng xuống) without flying/exploding!
	-- Legs (uleg_l, lleg_l, uleg_r, lleg_r, hips) NEVER detach so walking/standing physics never glitch!
	if isZombie then
		local isOrdnance = ((Spring.GetUnitRulesParam(unitID, "zdef_gib_death") or 0) == 1)
		if not isOrdnance then
			local hp, maxHp = Spring.GetUnitHealth(unitID)
			if hp and maxHp and maxHp > 0 then
				local hpRatio = (hp - (damage or 0)) / maxHp
				if hpRatio < 0.75 and not lostLimbs["larm_l"] and math.random(1, 100) <= 35 then
					dropZombiePieceByBullet("larm_l", larm_l)
				elseif hpRatio < 0.58 and not lostLimbs["larm_r"] and math.random(1, 100) <= 35 then
					dropZombiePieceByBullet("larm_r", larm_r)
				elseif hpRatio < 0.42 and not lostLimbs["uarm_l"] and math.random(1, 100) <= 30 then
					dropZombiePieceByBullet("uarm_l", uarm_l)
				elseif hpRatio < 0.28 and not lostLimbs["uarm_r"] and math.random(1, 100) <= 30 then
					dropZombiePieceByBullet("uarm_r", uarm_r)
				elseif hpRatio < 0.15 and not lostLimbs["head"] and math.random(1, 100) <= 35 then
					dropZombiePieceByBullet("head", head)
				end
			end
		end
	end

	local now = Spring.GetGameFrame()
	if now - lastHitTime >= 12 then
		lastHitTime = now
		StartThread(HitFlinchThread)
	end
	return damage
end

function script.AimFromWeapon1()
	return torso or hips or base
end

function script.QueryWeapon1()
	return flare or larm_r or torso or base
end

function script.AimWeapon1(heading, pitch)
	if isDying then return false end
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	isAiming = true
	aimHeading = heading or 0.0
	aimPitch = pitch or 0.0

	if not isZombie and unitClips.Attack and unitClips.Attack[1] then
		-- applyPoseFrame automatically adds aimHeading and compensates for hips.ry so rifle points straight at target!
		applyPoseFrame(unitClips.Attack[1], 0.08, false)
	elseif torso then
		Turn(torso, y_axis, aimHeading, math.rad(540))
		Turn(torso, x_axis, -aimPitch, math.rad(360))
	end
	if torso then
		WaitForTurn(torso, y_axis)
	end
	StartThread(RestoreAimAfterDelay)
	return true
end

local function PlayAttackClip()
	if isDying then return end
	-- Zombies alternate between embedded 'Attack' (claw swipe) and 'Bite' (neck lunge) clips!
	local clip = unitClips.Attack
	if isZombie and unitClips.Bite and (math.random(1, 100) <= 50) then
		clip = unitClips.Bite
	end
	if clip and #clip >= 4 then
		applyPoseFrame(clip[2], 0.10, false)
		Sleep(100)
		applyPoseFrame(clip[4], 0.12, false)
		Sleep(120)
		applyPoseFrame(clip[6], 0.14, false)
	end
end

function script.FireWeapon1()
	if flare then
		EmitSfx(flare, 1024)
	end
	StartThread(PlayAttackClip)
end

function script.Killed(recentDamage, maxHealth)
	isDying = true
	isMoving = false
	Signal(SIG_MOVE)
	Signal(SIG_AIM)
	Signal(SIG_IDLE)
	Signal(SIG_HIT)

	if isZombie then
		-- ONLY use violent flying-gib dismemberment when killed by Heavy Ordnance (Tank 120mm HE, A-10 30mm GAU-8, AC-130 105mm, F-16 Missiles/Bombs),
		-- NEVER when killed by infantry rifle bullets (even under squad focus-fire where recentDamage >= 120)!
		local isHeavyGib = ((Spring.GetUnitRulesParam(unitID, "zdef_gib_death") or 0) == 1)
		if isHeavyGib then
			-- Heavy Ordnance Kill: Violently tear the zombie apart into flying pieces!
			blastZombiePieceByOrdnance("head", head)
			blastZombiePieceByOrdnance("larm_l", larm_l)
			blastZombiePieceByOrdnance("uarm_l", uarm_l)
			blastZombiePieceByOrdnance("larm_r", larm_r)
			blastZombiePieceByOrdnance("uarm_r", uarm_r)
			blastZombiePieceByOrdnance("torso", torso)
			return 0
		else
			-- Infantry Bullet Kill: At most ONE random remaining upper-body piece (head, arm, or torso) simply drops down (rụng xuống)
			-- while the zombie collapses onto the ground into a lying corpse!
			local candidates = {}
			if head and not lostLimbs["head"] then candidates[#candidates + 1] = { "head", head } end
			if larm_l and not lostLimbs["larm_l"] then candidates[#candidates + 1] = { "larm_l", larm_l } end
			if larm_r and not lostLimbs["larm_r"] then candidates[#candidates + 1] = { "larm_r", larm_r } end
			if uarm_l and not lostLimbs["uarm_l"] then candidates[#candidates + 1] = { "uarm_l", uarm_l } end
			if uarm_r and not lostLimbs["uarm_r"] then candidates[#candidates + 1] = { "uarm_r", uarm_r } end
			if torso and not lostLimbs["torso"] then candidates[#candidates + 1] = { "torso", torso } end
			if #candidates > 0 and math.random(1, 100) <= 65 then
				local pick = candidates[math.random(1, #candidates)]
				dropZombiePieceByBullet(pick[1], pick[2])
			end

			local deathClip = unitClips.Death
			if deathClip and #deathClip >= 6 then
				applyPoseFrame(deathClip[2], 0.08, false)
				Sleep(80)
				applyPoseFrame(deathClip[4], 0.09, false)
				if hips then
					Move(hips, y_axis, -3.5, 18.0)
					Turn(hips, x_axis, math.rad(55), math.rad(300))
				end
				Sleep(90)
				applyPoseFrame(deathClip[6], 0.10, false)
				if hips then
					Move(hips, y_axis, -6.5, 24.0)
					Turn(hips, x_axis, math.rad(86), math.rad(340))
				end
				Sleep(95)
			end
			return 1 -- Spawns zdef_zombie_*_dead.s3o lying corpse feature!
		end
	end

	return 0
end
