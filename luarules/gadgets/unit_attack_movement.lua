-- This file is part of Beyond All Reason (GPL v2 or later).
local gadget = gadget ---@type Gadget
local mode = Spring.GetModOptions().attackmovementmode

function gadget:GetInfo()
	return {
		name = "Lua attack movement",
		desc = "Attack movement policy with native weapon geometry",
		author = "Aron, OpenAI Codex",
		date = "2026-10-27",
		license = "GNU GPL, v2 or later",
		layer = 100000,
		enabled = mode == "lua" or mode == "fallback",
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- These are policy choices, not copies of live engine settings. Native attack
-- movement does not run when this controller handles the update.
local ENGAGEMENT_FRACTION = 0.9
local TURN_RETRY_FRAMES = 30
local CHASE_FRAMES = 80
local CHASE_SPEED_FACTOR = 1.1
local STRAFE_SIN, STRAFE_COS = 0.6, 0.8
local STRAFE_CLOSE_FRACTION = 0.3
local TARGET_BORDER_FACTOR = 0.8
local GOAL_BASE_TOLERANCE, GOAL_DISTANCE_FACTOR = 10, 0.2
local CLOSE_DISTANCE_SQ = 32 * 32
local state = {}

function gadget:Initialize()
	if
		not (
			Spring.TestUnitAttackWeapon
			and Spring.GetUnitAttackTargetPosition
			and Spring.SetUnitFacingTarget
			and Spring.FinishUnitAttackCommand
		)
	then
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:UnitDestroyed(unitID)
	state[unitID] = nil
end

local function stop(unitID)
	Spring.ClearUnitGoal(unitID, false)
end

local function move(unitID, x, y, z, radius, speed)
	-- Preserve an already-active identical goal rather than restarting its path.
	Spring.SetUnitMoveGoal(unitID, x, y, z, radius or Game.squareSize, speed)
end

local function approach(unitID, targetID, x, y, z, tx, ty, tz, border)
	local radius = Spring.GetUnitRadius(targetID) * border * TARGET_BORDER_FACTOR
	local def = UnitDefs[Spring.GetUnitDefID(targetID)]
	if def.isImmobile then
		local footprintRadius = math.sqrt(def.xsize * def.xsize + def.zsize * def.zsize) * 0.5 * Game.squareSize
		radius = math.max(radius, footprintRadius + 2 * Game.squareSize)
	end
	local dx, dy, dz = math.normalize(tx - x, ty - y, tz - z)
	move(unitID, tx - dx * radius, ty - dy * radius, tz - dz * radius)
end

function gadget:AttackCommandMovement(unitID, cmdTag, cmdID, cmdOptions, targetID, tx, ty, tz, temporary)
	if mode == "fallback" then
		return false
	end
	local def = UnitDefs[Spring.GetUnitDefID(unitID)]
	local _, moveState = Spring.GetUnitStates(unitID, false, false, false)
	local holdPosition = moveState == 0
	local manual = cmdID == CMD.MANUALFIRE
	local userTarget = math.bit_and(cmdOptions, CMD.OPT_INTERNAL) == 0
	local frame = Spring.GetGameFrame()
	local range = Spring.GetUnitMaxRange(unitID)
	local engagementRange = range * ENGAGEMENT_FRACTION
	local x, y, z, mx, my, mz = Spring.GetUnitPosition(unitID, true)
	local motion = Spring.GetUnitMoveTypeData(unitID)
	local memory = state[unitID]
	if not memory then
		-- Import only the initial engine-seeded side. Subsequent changes belong
		-- to Lua; do not consume another value from the shared simulation RNG.
		memory = { lastApproach = -1, strafeLeft = motion.strafeLeft }
		state[unitID] = memory
	end
	local function face(radius)
		Spring.SetUnitFacingTarget(unitID, tx, ty, tz, radius)
	end
	local function assign()
		if targetID then
			return Spring.SetUnitTarget(unitID, targetID, manual, userTarget)
		end
		return Spring.SetUnitTarget(unitID, tx, ty, tz, manual, userTarget)
	end
	local function stopAndFace()
		stop(unitID)
		face(math.max(engagementRange, 10))
	end

	if not targetID then
		if manual then
			if assign() then
				face(engagementRange)
				stop(unitID)
			end
			return true
		end
		for weaponNum = 1, #def.weapons do
			if Spring.TestUnitAttackWeapon(unitID, weaponNum, { orientation = "heading" }) then
				if assign() then
					stopAndFace()
					return true
				end
				face(engagementRange)
			end
		end
		local dx, dz = tx - x, tz - z
		if dx * dx + dz * dz < engagementRange * engagementRange then
			assign()
			stopAndFace()
		end
		return true
	end

	local bx, by, bz
	bx, by, bz, tx, ty, tz = Spring.GetUnitPosition(targetID, true)
	local dx, dy, dz = mx - tx, my - ty, mz - tz
	local distanceSq = dx * dx + dz * dz
	local distance = math.sqrt(distanceSq)
	local pointingRadius = math.min(Spring.GetUnitSensorRadius(unitID, "los"), engagementRange)
	local rotateWeapon, needsTurn, border = nil, false, 0
	for weaponNum, weapon in ipairs(def.weapons) do
		local wd = WeaponDefs[weapon.weaponDef]
		if not manual or wd.manualFire then
			border = math.abs(wd.targetBorder)
			if Spring.TestUnitAttackWeapon(unitID, weaponNum) then
				rotateWeapon = weaponNum
				break
			end
			needsTurn = needsTurn or Spring.GetUnitWeaponState(unitID, weaponNum, "onlyForward")
		end
	end
	if rotateWeapon then
		local vx, vy, vz, speed = Spring.GetUnitVelocity(targetID)
		local targetBehind = dx * vx + dy * vy + dz * vz < 0
		if
			not def.stopToAttack
			and not holdPosition
			and targetBehind
			and not def.isHoveringAirUnit
			and Spring.TestUnitAttackWeapon(unitID, rotateWeapon, { orientation = "heading" })
		then
			move(
				unitID,
				x + vx * CHASE_FRAMES,
				y + vy * CHASE_FRAMES,
				z + vz * CHASE_FRAMES,
				Game.squareSize,
				speed * CHASE_SPEED_FACTOR
			)
		else
			stop(unitID)
			if frame > memory.lastApproach + TURN_RETRY_FRAMES then
				face(pointingRadius)
			end
		end
		assign()
		return true
	end
	if temporary and holdPosition then
		stop(unitID)
		Spring.FinishUnitAttackCommand(unitID)
		return true
	end
	if distance < engagementRange then
		if def.isHoveringAirUnit or distanceSq < CLOSE_DISTANCE_SQ or needsTurn then
			stop(unitID)
			face(pointingRadius)
		elseif def.strafeToAttack then
			if motion.progressState == "failed" then
				memory.strafeLeft = not memory.strafeLeft
			end
			local direction = memory.strafeLeft and 1 or -1
			local scale = distance < range * STRAFE_CLOSE_FRACTION and 1 / STRAFE_COS or STRAFE_COS
			move(
				unitID,
				bx + (dx * STRAFE_COS - dz * STRAFE_SIN * direction) * scale,
				by,
				bz + (dx * STRAFE_SIN * direction + dz * STRAFE_COS) * scale
			)
		end
		return true
	end
	local ex, ey, ez = Spring.GetUnitAttackTargetPosition(unitID)
	local gx, gz = ex - motion.goalx, ez - motion.goalz
	local baseDx, baseDz = bx - x, bz - z
	local tolerance = GOAL_BASE_TOLERANCE + math.sqrt(baseDx * baseDx + baseDz * baseDz) * GOAL_DISTANCE_FACTOR
	if gx * gx + gz * gz > tolerance * tolerance then
		approach(unitID, targetID, x, y, z, ex, ey, ez, border)
		if needsTurn then
			face(pointingRadius)
		end
		memory.lastApproach = frame
	end
	return true
end
