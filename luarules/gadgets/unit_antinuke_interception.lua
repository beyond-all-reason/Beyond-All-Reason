local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name = "Terminal-Phase Interceptors",
		desc = "Intercepts semiballistics as they descend towards their target",
		author = "efrec",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- The engine offers to fire interceptors starting at their maximum ttl/coverage.
-- We delay accepting that request until as late as possible for the drama of it,
-- then make many, many corrections so an interception remains highly successful.

-- That gives a new interception plan with a few steps:
-- 1. Reject `AllowWeaponInterceptTarget` until the last possible sweep interval.
-- 2. Remove the interceptor's projectile target so the engine does not reaim it.
-- 3. Set our own aim predictions ahead of the soon-to-drop-turn inbound warhead.
-- 4. Claim the warhead again once the engine can take over aim to save on perf.

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local blastCushion = 2.0 -- warhead explosion radius multiplier for safety checks
local chaseFactorDefault = 0.2 -- must match unit_custom_weapons_verticalize.lua
local commitMarginFrames = 45 -- unscientific confidence margin added to our guess
local claimLeadFrames = 20 -- claim the warhead this far ahead of retargeting it
local solveLeadFrames = 2 -- polling frames used to predict interceptor ascent end
local solveIterations = 5 -- fixed-point steps for the meeting-point solve
local solveRetries = 6 -- impatience, sweeps to wait on a warhead to level out

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_min = math.min
local math_max = math.max
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_asin = math.asin
local math_acos = math.acos
local math_atan2 = math.atan2
local math_clamp = math.clamp
local math_diag = math.diag
local math_floor = math.floor
local math_huge = math.huge
local math_pi = math.pi

local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileTarget = Spring.GetProjectileTarget
local spSetProjectileTarget = Spring.SetProjectileTarget
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight

local targetedProjectile = string.byte("p")

-- CInterceptHandler::Update
local sweepInterval = 15
-- CStarburstProjectile gives up tracking at this angle difference (as a dotprod).
local turnToTargetDot = 0.99
-- Guess whether the warhead is still pitching over or has achieved level flight.
local sinAtLevel = 0.02

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local interceptors = {} -- weaponDefID -> interceptor weapon
local interceptables = {} -- weaponDefID -> warhead weapon
local weaponNumDefs = {} -- hash of unitDefID/weaponNum -> weaponDefID

local warheads = {} -- projectileID -> tracked warhead
local missiles = {} -- projectileID -> launched interceptor
local scheduled = {} -- frame -> list of missileIDs

local gameFrame = 0

--------------------------------------------------------------------------------
-- Geometry --------------------------------------------------------------------

local function distanceXZ(x1, z1, x2, z2)
	return math_diag(x1 - x2, z1 - z2)
end

---Rotate a unit vector toward another by `rate` radians, same as the engine does:
---This normalizes a sum rather than doing a slerp, so small `rate`s lag slightly.
local function turnToward(dx, dy, dz, ex, ey, ez, rate)
	local ax, ay, az = ex - dx, ey - dy, ez - dz
	local dot = ax * dx + ay * dy + az * dz
	ax, ay, az = ax - dx * dot, ay - dy * dot, az - dz * dot
	local length = math_diag(ax, ay, az)
	if length <= 0 then
		return dx, dy, dz
	end
	ax, ay, az = ax / length * rate, ay / length * rate, az / length * rate
	local nx, ny, nz = dx + ax, dy + ay, dz + az
	length = math_diag(nx, ny, nz)
	if length <= 0 then
		return dx, dy, dz
	end
	return nx / length, ny / length, nz / length
end

--------------------------------------------------------------------------------
-- Warhead flight plan ---------------------------------------------------------

---Taken from unit_custom_weapons_verticalize. -- TODO: make a common module
local function getDiveSpeed(warhead, speed)
	local gain = warhead.diveSpeedGain
	local diveSpeed = 0.5 * (gain + math_sqrt(gain * gain + 4 * speed * speed))
	return math_min(diveSpeed, warhead.speedMax)
end

local function getSpeedAfter(warhead, speed, distance)
	return math_min(warhead.speedMax, math_sqrt(speed * speed + 2 * warhead.acceleration * distance))
end

local function getFramesOver(warhead, speed, distance)
	local acceleration = warhead.acceleration
	if acceleration <= 0 then
		return distance / math_max(speed, 1e-3)
	end
	local speedAfter = getSpeedAfter(warhead, speed, distance)
	local frames = (speedAfter - speed) / acceleration
	if speedAfter < warhead.speedMax then
		return frames
	end
	local accelDistance = (warhead.speedMax * warhead.speedMax - speed * speed) / (2 * acceleration)
	return (warhead.speedMax - speed) / acceleration + (distance - accelDistance) / warhead.speedMax
end

local function getDistanceOver(warhead, speed, frames)
	local acceleration = warhead.acceleration
	local accelFrames = 0.0
	if acceleration > 0 then
		accelFrames = math_clamp((warhead.speedMax - speed) / acceleration, 0, frames)
	end
	local distance = speed * accelFrames + 0.5 * acceleration * accelFrames * accelFrames
	return distance + (frames - accelFrames) * math_min(warhead.speedMax, speed + acceleration * accelFrames)
end

---Get all information needed to predict future position, ignoring LOS and common sense.
---If the interceptor needs it for a firing solution, it gets it, some* questions asked.
local function getWarheadState(projectileID, tracked)
	---@diagnostic disable: param-type-mismatch, need-check-nil --- each var reads as `number?`
	local px, py, pz = spGetProjectilePosition(projectileID)
	if not px then
		return
	end

	local vx, vy, vz, speed = spGetProjectileVelocity(projectileID)
	if not speed or speed <= 0 then
		return
	end

	local warhead = tracked.warhead
	local distance2D = distanceXZ(px, pz, tracked.targetX, tracked.targetZ)
	local sinCurrent = math_clamp(-vy / speed, -1, 1)

	local horizontal = math_diag(vx, vz)
	local ascending = horizontal <= 0 or sinCurrent < -sinAtLevel
	local hx, hz = 0.0, 0.0

	local leadFrames = 0.0
	if not ascending then
		hx, hz = vx / horizontal, vz / horizontal
	else
		-- Until the warhead stops climbing, its velocity tells us nothing about its path.
		-- We use magical infons from the spirit emitters to keep gameplay semireasonable.
		local dx, dz = tracked.targetX - px, tracked.targetZ - pz
		local bearing = math_diag(dx, dz)
		if bearing <= 0 then
			return
		end
		hx, hz = dx / bearing, dz / bearing

		local climb = math_max(0.0, tracked.cruiseY - py)
		leadFrames = getFramesOver(warhead, speed, climb) + (math_pi * 0.5 / warhead.turnRate)

		speed = getSpeedAfter(warhead, speed, climb)
		py = math_max(py, tracked.cruiseY)
		px, pz = px + hx * speed / warhead.turnRate, pz + hz * speed / warhead.turnRate

		distance2D = distanceXZ(px, pz, tracked.targetX, tracked.targetZ)
		sinCurrent = 0 -- invalidate
	end

	local diveRadius = (1 + warhead.chaseFactor) * getDiveSpeed(warhead, warhead.speedMax) / warhead.turnRate
	for _ = 1, 2 do
		local entrySpeed = getSpeedAfter(warhead, speed, math_max(0, distance2D - diveRadius))
		diveRadius = (1 + warhead.chaseFactor) * getDiveSpeed(warhead, entrySpeed) / warhead.turnRate
	end

	-- Within the dive radius, infer the curvature rather than predicting it.
	-- Probably do not need to gate recalculating this, but maybe try later.
	if distance2D < diveRadius and sinCurrent > 0 and sinCurrent < 0.98 then
		diveRadius = distance2D / (1 - sinCurrent)
	end

	return {
		px = px,
		py = py,
		pz = pz,
		hx = hx,
		hz = hz,
		speed = speed,
		sinDive = sinCurrent,
		diveRadius = diveRadius,
		groundDistance = distance2D,
		floorY = tracked.targetY,
		ascending = ascending,
		leadFrames = leadFrames,
	}
	---@diagnostic enable: param-type-mismatch
end

local function predictWarhead(warhead, state, frames)
	local distance = getDistanceOver(warhead, state.speed, frames)
	local radius = state.diveRadius
	local angle = math_asin(math_clamp(state.sinDive, 0, 1))
	local cruise = math_max(0.0, state.groundDistance - radius)

	if distance <= cruise then
		return state.px + state.hx * distance, state.py, state.pz + state.hz * distance
	end

	-- The descent curve's radius is wider than the remaining height to target.
	-- The inbound warhead will impact the ground partway through verticalizing.
	local angleEnd = math_min(math_pi * 0.5, angle + (distance - cruise) / radius)
	local cosFloor = math_cos(angle) - (state.py - state.floorY) / radius
	if cosFloor > -1 and math_cos(angleEnd) < cosFloor then
		angleEnd = math_acos(math_clamp(cosFloor, -1, 1))
	end
	local along = cruise + radius * (math_sin(angleEnd) - math_sin(angle))
	local drop = radius * (math_cos(angle) - math_cos(angleEnd))
	return state.px + state.hx * along, state.py - drop, state.pz + state.hz * along
end

---Check whether the warhead's explosion radius covers either the target position
---or the interceptor battery attempting to shoot at it, to handle flyover nukes.
local function isInsideBlast(tracked, px, py, pz, ux, uy, uz)
	local standoff = tracked.standoff
	if math_diag(px - tracked.targetX, py - tracked.targetY, pz - tracked.targetZ) <= standoff then
		return true
	end
	return ux ~= nil and math_diag(px - ux, py - uy, pz - uz) <= standoff
end

---Bisect the trajectory very many times to determine a safe intercept position.
local function getStandoffFrames(warhead, tracked, state, ux, uy, uz)
	local px, py, pz = state.px, state.py, state.pz
	if isInsideBlast(tracked, px, py, pz, ux, uy, uz) then
		return 0 -- near
	end

	local lo, hi = 0.0, 8.0
	for _ = 1, 10 do
		px, py, pz = predictWarhead(warhead, state, hi)
		if isInsideBlast(tracked, px, py, pz, ux, uy, uz) then
			break
		end
		lo = hi
		hi = hi * 2
		if hi > 8 * (2 ^ 10) then
			return -- far
		end
	end

	for _ = 1, 14 do
		local mid = (lo + hi) * 0.5
		px, py, pz = predictWarhead(warhead, state, mid)
		if isInsideBlast(tracked, px, py, pz, ux, uy, uz) then
			hi = mid
		else
			lo = mid
		end
	end
	return hi -- wherever you are
end

--------------------------------------------------------------------------------
-- Interceptor flight plan -----------------------------------------------------

---The engine ascends with acceleration, turns with no acceleration, then resumes.
---The turn covers radius * cos(angleRise) of the line of sight before it is done.
local function getFlightFrames(weapon, lx, ly, lz, tx, ty, tz)
	local upFrames = weapon.upTimeFrames
	local speed = math_min(weapon.speedMax, weapon.speedMin + upFrames * weapon.acceleration)
	local apex = ly + weapon.speedMin * upFrames + 0.5 * weapon.acceleration * upFrames * upFrames

	local dx, dy, dz = tx - lx, ty - apex, tz - lz
	local ground = math_diag(dx, dz)
	local slant = math_diag(dx, dy, dz)
	if slant <= 0 then
		return upFrames
	end

	local angleRise = math_atan2(dy, ground)
	local turnFrames = math_max(0, math_pi * 0.5 - angleRise) / weapon.turnRate
	local turned = math_max(0.0, slant - speed / weapon.turnRate * math_cos(angleRise))
	local runFrames = (math_sqrt(speed * speed + 2 * weapon.acceleration * turned) - speed) / weapon.acceleration

	return upFrames + turnFrames + runFrames -- gross
end

---Run a simulation of `CStarburstProjectile::UpdateTrajectory` on the interceptor.
---The simulation takes a fixed target position and iterates up until `claimFrame`.
---The `limit` enforces time-to-live and acts as our early-exit so is good to keep.
local function simulateEngagement(weapon, missile, warhead, state, ax, ay, az, claimFrame, limit)
	local px, py, pz = missile.px, missile.py, missile.pz
	local dx, dy, dz = missile.dx, missile.dy, missile.dz
	local speed, upTime, turning = missile.speed, missile.upTime, missile.turning

	local acceleration = weapon.acceleration
	local speedMax = weapon.speedMax
	local turnRate = weapon.turnRate
	local tracking = weapon.tracking
	local maxGoodDif = weapon.maxGoodDif

	local closest, closestFrame = math_huge, limit
	local reached, reachedFrame = math_huge, limit

	for frame = 1, limit do
		local wx, wy, wz = predictWarhead(warhead, state, frame)
		local tx, ty, tz = ax, ay, az
		if frame > claimFrame then
			tx, ty, tz = wx, wy, wz
		end

		if upTime > 0 then
			upTime = upTime - 1
			speed = math_min(speed + acceleration, speedMax)
		else
			local ex, ey, ez = tx - px, ty - py, tz - pz
			local length = math_diag(ex, ey, ez)
			if length <= 0 then
				break
			end
			ex, ey, ez = ex / length, ey / length, ez / length
			local dotProduct = ex * dx + ey * dy + ez * dz

			if turning then
				if dotProduct > turnToTargetDot then
					dx, dy, dz = ex, ey, ez
					turning = false
				else
					dx, dy, dz = turnToward(dx, dy, dz, ex, ey, ez, turnRate)
				end
			else
				if dotProduct > maxGoodDif then
					dx, dy, dz = ex, ey, ez
				else
					dx, dy, dz = turnToward(dx, dy, dz, ex, ey, ez, tracking)
				end
				speed = math_min(speed + acceleration, speedMax)
			end
		end

		px, py, pz = px + dx * speed, py + dy * speed, pz + dz * speed

		local toPoint = math_diag(px - ax, py - ay, pz - az)
		if toPoint < reached then
			reached, reachedFrame = toPoint, frame
		elseif claimFrame >= limit and upTime <= 0 and toPoint > reached + speed then
			break -- overshot the fixed point
		end

		local toWarhead = math_diag(px - wx, py - wy, pz - wz)
		if toWarhead < closest then
			closest, closestFrame = toWarhead, frame
		elseif toWarhead > closest and frame > claimFrame then
			break -- prediction cannot improve
		end
	end

	return closest, closestFrame, reachedFrame
end

---Match the interceptor's time of flight to the warhead's time to arrive, replacing
---the engine's pursuit-style guidance with an aggressive head-on trajectory approach.
-- TODO: Our solver is bad and we should feel bad. Still, we don't run this many times.
local function solveAimPoint(weapon, missile, warhead, tracked, state, standoffFrames)
	local limit = missile.timeToLive
	local frames = math_min(standoffFrames, limit)

	for _ = 1, solveIterations - 1 do
		local ax, ay, az = predictWarhead(warhead, state, frames)
		local _, _, arrival = simulateEngagement(weapon, missile, warhead, state, ax, ay, az, limit, limit)
		frames = math_clamp(frames + 0.6 * (arrival - frames), 1, limit)
	end

	local claimFrame = math_max(0, math_floor(frames) - claimLeadFrames)
	local ax, ay, az = predictWarhead(warhead, state, frames)
	local aimed = simulateEngagement(weapon, missile, warhead, state, ax, ay, az, claimFrame, limit)

	-- Never do worse than the engine's pursuit guidance. Maybe can remove this later.
	local pursued = simulateEngagement(weapon, missile, warhead, state, ax, ay, az, 0, limit)
	if pursued <= aimed then
		return nil, nil, nil, 0, pursued
	end

	return ax, ay, az, claimFrame, aimed
end

--------------------------------------------------------------------------------
-- Scheduling ------------------------------------------------------------------

local function scheduleAt(projectileID, frame)
	frame = math_max(math_floor(frame), gameFrame + 1) -- can't clamp, don't know the sort
	local bin = scheduled[frame]
	if not bin then
		bin = {}
		scheduled[frame] = bin
	end
	bin[#bin + 1] = projectileID
end

--------------------------------------------------------------------------------
-- Interception decisions ------------------------------------------------------

---True when there is no longer time to wait out another sweep. The closed form runs
---long by a handful of frames against the engine, which `commitMarginFrames` absorbs.
local function shouldCommit(tracked, unitID, weapon)
	local state = getWarheadState(tracked.projectileID, tracked)
	if not state then
		return true -- ?
	end

	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then
		return true -- ?
	end

	local standoffFrames = getStandoffFrames(tracked.warhead, tracked, state, ux, uy, uz)
	if not standoffFrames then
		return false -- far
	end
	standoffFrames = standoffFrames + state.leadFrames

	local ax, ay, az = predictWarhead(tracked.warhead, state, standoffFrames)
	local flightFrames = getFlightFrames(weapon, ux, uy, uz, ax, ay, az)
	if flightFrames > weapon.timeToLive then
		return true -- ?
	end

	return standoffFrames - flightFrames <= sweepInterval + commitMarginFrames
end

local function planInterception(projectileID, missile)
	local tracked = warheads[missile.warheadID]
	if not tracked then
		return false
	end

	---@diagnostic disable: need-check-nil --- too many vars to assert, all `number?`
	local px, py, pz = spGetProjectilePosition(projectileID)
	local vx, vy, vz, speed = spGetProjectileVelocity(projectileID)
	local state = getWarheadState(missile.warheadID, tracked)

	if not px or not speed or speed <= 0 or not state then
		return false -- we fail, hand it back to the engine
	end

	local weapon = missile.weapon
	missile.px, missile.py, missile.pz = px, py, pz
	missile.dx, missile.dy, missile.dz = vx / speed, vy / speed, vz / speed
	missile.speed = speed
	missile.upTime = math_max(0, weapon.upTimeFrames - (gameFrame - missile.launchFrame))
	missile.turning = true

	if state.ascending then
		missile.solveTries = (missile.solveTries or 0) + 1
		if missile.solveTries > solveRetries then
			return false -- out of patience; we fail, hand it back to the engine
		end
		scheduleAt(projectileID, gameFrame + sweepInterval)
		return true
	end

	local mergeFrames =
		getStandoffFrames(tracked.warhead, tracked, state, missile.originX, missile.originY, missile.originZ)
	if not mergeFrames or mergeFrames <= 0 then
		return false -- already inside its own blast; nothing left to protect by waiting
	end

	local ax, ay, az, claimFrame = solveAimPoint(weapon, missile, tracked.warhead, tracked, state, mergeFrames)
	if not ax then
		return false -- within safety for engine pursuit
	end

	-- Drop the projectile target, control via target position.
	spSetProjectileTarget(projectileID, ax, ay, az)
	missile.aimX, missile.aimY, missile.aimZ = ax, ay, az
	scheduleAt(projectileID, gameFrame + claimFrame)
	return true
	---@diagnostic enable: need-check-nil
end

local function armInterception(projectileID, missile)
	if missile.armed then
		return
	end
	if not warheads[missile.warheadID] then
		return
	end
	-- Reacquire the projectile, resume `CWeaponProjectile::UpdateInterception`.
	spSetProjectileTarget(projectileID, missile.warheadID, targetedProjectile)
	missile.armed = true
end

--------------------------------------------------------------------------------
-- Registration ----------------------------------------------------------------

local function getInterceptorWeapon(weaponDef)
	if weaponDef.interceptor <= 0 or weaponDef.coverageRange <= 0 then
		return
	end
	if weaponDef.type ~= "StarburstLauncher" then
		return
	end
	if weaponDef.turnRate <= 0 or weaponDef.weaponAcceleration <= 0 then
		return
	end

	local tracking = weaponDef.tracks and weaponDef.turnRate or 0

	return {
		coverageRange = weaponDef.coverageRange,
		killRadius = weaponDef.damageAreaOfEffect, -- already a radius; the tag is a diameter; sheesh
		upTimeFrames = weaponDef.uptime * Game.gameSpeed,
		acceleration = weaponDef.weaponAcceleration,
		speedMax = weaponDef.projectilespeed,
		speedMin = weaponDef.startvelocity,
		turnRate = weaponDef.turnRate,
		tracking = tracking,
		maxGoodDif = math_cos(tracking * 0.6),
		timeToLive = weaponDef.flightTime,
	}
end

local function getInterceptableWeapon(weaponDef)
	if weaponDef.targetable <= 0 then
		return
	end
	if weaponDef.type ~= "StarburstLauncher" or not weaponDef.customParams.cruise_and_verticalize then
		return
	end
	if weaponDef.turnRate <= 0 then
		return
	end

	-- Not a required value. See `unit_custom_weapons_verticalize.lua`.
	local chaseFactor = tonumber(weaponDef.customParams.cruise_chase_factor) or chaseFactorDefault

	return {
		blastRadius = weaponDef.damageAreaOfEffect,
		acceleration = weaponDef.weaponAcceleration,
		speedMax = weaponDef.projectilespeed,
		turnRate = weaponDef.turnRate,
		chaseFactor = chaseFactor,
		diveSpeedGain = math_pi * weaponDef.weaponAcceleration * (1 + chaseFactor) / weaponDef.turnRate,
	}
end

local function registerWarhead(projectileID, weaponDefID)
	local targetType, target = spGetProjectileTarget(projectileID)
	if type(target) ~= "table" then
		return
	end

	local warhead = interceptables[weaponDefID] ---@type table

	warheads[projectileID] = {
		projectileID = projectileID,
		warhead = warhead,
		targetX = target[1],
		targetY = math_max(spGetGroundHeight(target[1], target[3]) or 0, 0),
		targetZ = target[3],
		cruiseY = target[2], -- verticalize aims at a cruise altitude
		standoff = blastCushion * warhead.blastRadius,
		commit = {}, -- we could, technically, shoot more than 1:1
	}
end

local function registerMissile(projectileID, weaponDefID)
	local targetType, target = spGetProjectileTarget(projectileID)
	if targetType ~= targetedProjectile or not warheads[target] then
		return
	end

	local weapon = interceptors[weaponDefID] ---@type table
	local missile = {
		weapon = weapon,
		warheadID = target,
		launchFrame = gameFrame,
		timeToLive = weapon.timeToLive,
		armed = false,
	}
	missiles[projectileID] = missile

	-- Dropping the object now also stops UpdateInterception firing while the missile
	-- is still climbing through the warhead's altitude, which would detonate it here.
	local px, py, pz = spGetProjectilePosition(projectileID)
	if px then
		-- The launch point is the second thing the standoff has to protect.
		missile.originX, missile.originY, missile.originZ = px, py, pz
		spSetProjectileTarget(projectileID, px, py + weapon.speedMax * sweepInterval, pz)
	end

	scheduleAt(projectileID, gameFrame + math_max(1, weapon.upTimeFrames - solveLeadFrames))
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:GameFrame(frame)
	gameFrame = frame

	local checkList = scheduled[frame]
	if checkList then
		scheduled[frame] = nil
		for i = 1, #checkList do
			local projectileID = checkList[i]
			local missile = missiles[projectileID]
			if missile then
				if missile.aimX then
					armInterception(projectileID, missile)
				elseif not planInterception(projectileID, missile) then
					armInterception(projectileID, missile) -- degrade to the engine's own pursuit
				end
			end
		end
	end

	-- The engine sweeps interceptors this frame, so our interceptor commits become stale.
	-- We use this to refresh our own predictions, also, removing hashed gates for g:AWIT.
	if frame % sweepInterval == 0 then
		for _, tracked in pairs(warheads) do
			tracked.commit = {}
		end
	end
end

function gadget:AllowWeaponInterceptTarget(unitID, weaponNum, projectileID)
	local warhead = warheads[projectileID]
	if not warhead then
		return true -- who are you people
	end

	local unitDefID = spGetUnitDefID(unitID)
	local weapon = unitDefID and interceptors[weaponNumDefs[100000 * weaponNum + unitDefID]]
	if not weapon then
		return true -- why are you in my house
	end

	local hashID = 100000 * weaponNum + unitID
	local commit = warhead.commit[hashID]
	if not commit then
		commit = shouldCommit(warhead, unitID, weapon)
		warhead.commit[hashID] = commit
	end
	return commit
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if interceptables[weaponDefID] then
		registerWarhead(projectileID, weaponDefID)
	elseif interceptors[weaponDefID] then
		registerMissile(projectileID, weaponDefID)
	end
end

function gadget:ProjectileDestroyed(projectileID, ownerID, weaponDefID)
	warheads[projectileID] = nil
	missiles[projectileID] = nil
end

function gadget:Initialize()
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		local interceptor = getInterceptorWeapon(weaponDef)
		if interceptor then
			interceptors[weaponDefID] = interceptor
			Script.SetWatchProjectile(weaponDefID, true)
			Script.SetWatchAllowTarget(weaponDefID, true)
		end
		local interceptable = getInterceptableWeapon(weaponDef)
		if interceptable then
			interceptables[weaponDefID] = interceptable
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end

	if not next(interceptors) or not next(interceptables) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No interceptor and warhead pairing found.")
		gadgetHandler:RemoveGadget()
		return
	end

	-- AllowWeaponInterceptTarget hands us a weapon number, not a weapon def.
	-- This has a cheap unique hash so we use that and check for instability.
	for unitDefID, unitDef in pairs(UnitDefs) do
		local unitWeapons = unitDef.weapons
		for weaponNum = 1, #unitWeapons do
			local weaponDefID = unitWeapons[weaponNum].weaponDef
			if interceptors[weaponDefID] then
				local hashID = 100000 * weaponNum + unitDefID
				assert(hashID <= 2 ^ 24) -- max sequantial float32 as integer
				weaponNumDefs[hashID] = weaponDefID
			end
		end
	end
end
