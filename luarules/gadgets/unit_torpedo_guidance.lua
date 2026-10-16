local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Torpedo guidance",
		desc = "Water entry, surface tracking and terrain avoidance for torpedoes",
		author = "Doo, 26Projects",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Engine access and projectile dispatch ----------------------------------------

local math_clamp = math.clamp
local math_max = math.max
local math_diag = math.diag
local CallAsTeam = CallAsTeam
local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte("g")
local targetedUnit = string.byte("u")

-- Retain the existing speceffect selectors for weapon definitions and tweakdefs.
local specialEffectFunction = {}
local weaponDefEffect = {}
---@type table<number, true?>
local torpedoAvoidLeavingWaterDefs = {}
---@type table<number, true?>
local torpedoWaterPenDefs = {}
local projectiles = {}
---@type table<number, number>
local weaponPitchStep = {}
local gameFrame = -1

local function isProjectileInWater(projectileID)
	local _, positionY = spGetProjectilePosition(projectileID)
	return positionY ~= nil and positionY <= 0
end

local readAs = { read = -1 }

local function readAsTeam(teamID, ...)
	local read = readAs
	read.read = teamID or -1
	return CallAsTeam(read, ...)
end

---@return number? targetX xyz coords
---@return number? targetY
---@return number? targetZ
local function getTargetPositionWithError(projectileID, targetType, target)
	if targetType == nil then
		targetType, target = spGetProjectileTarget(projectileID)
	end
	if targetType == targetedUnit then
		local teamID = spGetProjectileTeamID(projectileID) or spGetUnitTeam(spGetProjectileOwnerID(projectileID) or -1)
		local _, _, _, targetX, targetY, targetZ = readAsTeam(teamID, spGetUnitPosition, target, false, true)
		return targetX, targetY, targetZ -- unit aim position
	elseif targetType == targetedGround then
		return target[1], target[2], target[3]
	end
end

-- Shared motion goals. Distances are elmos; times are simulation frames.
-- WeaponDefs.turnRate supplies the ordinary pitch limit. Close-target recovery,
-- terrain avoidance and shore breach protection can exceed it.
-- See doc/torpedo_motion_tuning.md for the geometry and test cases.
local surfaceTargetDepth = -2
local surfaceTransitionStartDepth = -12
local surfaceEntryCorrectionDistance = 180
local surfaceArrivalLeadFrames = 20.0
local minSurfaceCorrectionFrames = 8
local entryHandoffDiveSpeed = -0.12

-- Preserve the tested terrain handoff while changing the steering calculation.
local terrainAvoidanceClearance = 6
local terrainAvoidanceLookaheadFrames = 4
local terrainAvoidanceRampDepth = 12
local terrainAvoidanceTargetReleaseDistance = 36
local terrainAvoidanceDepthLeadRatio = 2
local terrainAvoidanceGroundTargetLeadRatio = 3
local shoreTorpedoBreachCeiling = 2

-- Per-projectile runtime state; these fields are not trajectory configuration.
---@class TorpedoState
---@field allowWaterEntryHeadingCorrection boolean?
---@field surfaceTarget boolean?
---@field waterEntryHeadingCorrected boolean?
---@field shoreEnteredWater boolean?
---@field pitch number?
---@field pitchFrame number?
---@type table<integer, TorpedoState>
local torpedoStates = {}

---@return TorpedoState
local function getOrCreateTorpedoState(projectileID)
	local state = torpedoStates[projectileID]
	if not state then
		state = {}
		torpedoStates[projectileID] = state
	end
	return state
end

local function getTorpedoTargetPosition(projectileID, targetType, target, state)
	local targetX, targetY, targetZ = getTargetPositionWithError(projectileID, targetType, target)
	if targetY ~= nil then
		-- Retain only the target class when it leaves sensor coverage. The engine
		-- continues horizontal homing; Lua only needs this for vertical guidance.
		state.surfaceTarget = targetY >= -10
	end
	return targetX, targetY, targetZ, state.surfaceTarget
end

---@return number?
local function getSurfaceArrivalFrames(
	projectileID,
	targetID,
	positionX,
	positionZ,
	velocityX,
	velocityZ,
	targetX,
	targetZ
)
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	if horizontalSpeed <= 0.01 then
		return
	end

	local horizontalDistance = math_diag(targetX - positionX, targetZ - positionZ)
	local arrivalFrames = horizontalDistance / horizontalSpeed
	local teamID = spGetProjectileTeamID(projectileID) or spGetUnitTeam(spGetProjectileOwnerID(projectileID) or -1)
	local targetVelocityX, _, targetVelocityZ = readAsTeam(teamID, spGetUnitVelocity, targetID)
	if targetVelocityX ~= nil and targetVelocityZ ~= nil then
		local predictedTargetX = targetX + targetVelocityX * arrivalFrames
		local predictedTargetZ = targetZ + targetVelocityZ * arrivalFrames
		horizontalDistance = math_diag(predictedTargetX - positionX, predictedTargetZ - positionZ)
		arrivalFrames = horizontalDistance / horizontalSpeed
	end
	return arrivalFrames
end

-- Steer in the vertical plane; the engine keeps ownership of horizontal heading.
-- A circle tangent to the current path and passing through the aim point has
-- curvature 2*sin(pitchError)/distance. This supplies the close-shot exception.
---@param projectileID integer
---@param positionX number
---@param positionY number
---@param positionZ number
---@param velocityX number
---@param velocityY number
---@param velocityZ number
---@param speed number
---@param wantedPitch number? Nil retains native pitch for submerged targets.
---@param aimDistance number? Straight-line distance to the vertical aim point.
---@param predictTerrain boolean?
---@param terrainAvoidanceScale number?
---@param emergency boolean? Shore breach override, bypassing the turn limit.
local function setTorpedoPitchVelocity(
	projectileID,
	positionX,
	positionY,
	positionZ,
	velocityX,
	velocityY,
	velocityZ,
	speed,
	wantedPitch,
	aimDistance,
	predictTerrain,
	terrainAvoidanceScale,
	emergency
)
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	if not speed or speed <= 0 or horizontalSpeed <= 0 then
		return
	end

	local state = getOrCreateTorpedoState(projectileID)
	local currentPitch = math.atan2(velocityY, horizontalSpeed)
	local pitch = currentPitch
	if wantedPitch ~= nil then
		local previousPitch = currentPitch
		if state.pitchFrame == gameFrame - 1 and state.pitch ~= nil then
			previousPitch = state.pitch
		end
		local projectileDefID = spGetProjectileDefID(projectileID)
		local turnStep = projectileDefID and weaponPitchStep[projectileDefID] or 0.0
		if aimDistance then
			local errorAngle = math.min(math.abs(wantedPitch - previousPitch), math.pi * 0.5)
			local requiredStep = 2 * speed * math.sin(errorAngle) / math_max(aimDistance, speed)
			turnStep = math_max(turnStep, requiredStep)
		end
		if not emergency and previousPitch < 0 then
			-- Begin recovering while the levelling arc still fits above the seabed.
			-- The same R*(1-cos(pitch)) geometry used for surfacing gives the
			-- minimum turn needed to spend no more than the available depth.
			local floorHeight = math_max(
				spGetGroundHeight(positionX, positionZ),
				spGetGroundHeight(
					positionX + velocityX * terrainAvoidanceLookaheadFrames,
					positionZ + velocityZ * terrainAvoidanceLookaheadFrames
				)
			)
			-- Reserve the next downward step as well as the continuous arc.
			local availableDepth = positionY - floorHeight - terrainAvoidanceClearance + math.min(velocityY, 0)
			local recoveryStep = speed * (1 - math.cos(previousPitch)) / math_max(availableDepth, speed)
			if recoveryStep > turnStep then
				turnStep = recoveryStep
				wantedPitch = math_max(wantedPitch, 0)
			end
		end

		-- Start levelling a rising surface-bound torpedo while its circular arc
		-- still fits below running depth: remaining rise = R * (1 - cos(pitch)).
		if not emergency and previousPitch > 0 and turnStep > 0 and wantedPitch >= 0 then
			local riseToLevel = speed / turnStep * (1 - math.cos(previousPitch))
			if positionY + riseToLevel >= surfaceTargetDepth then
				wantedPitch = 0
			end
		end

		if emergency then
			pitch = wantedPitch
		else
			-- Reference our last output so native pitch steering and this correction
			-- share one frame's allowance. X/Z heading remains the engine's result.
			pitch = previousPitch + math_clamp(wantedPitch - previousPitch, -turnStep, turnStep)
		end
	end

	-- Keep the existing slope-aware terrain correction as a safety override.
	-- Submerged targets otherwise retain the engine's pitch, including its lead.
	local terrainX, terrainY, terrainZ = positionX, positionY, positionZ
	if predictTerrain then
		terrainX = terrainX + velocityX * terrainAvoidanceLookaheadFrames
		terrainY = terrainY + velocityY * terrainAvoidanceLookaheadFrames
		terrainZ = terrainZ + velocityZ * terrainAvoidanceLookaheadFrames
	end
	local clearance = terrainY - spGetGroundHeight(terrainX, terrainZ)
	local terrainBlend = 0.0
	if predictTerrain then
		terrainBlend = math_clamp(
			(terrainAvoidanceClearance + terrainAvoidanceRampDepth - clearance) / terrainAvoidanceRampDepth,
			0,
			1
		)
	elseif clearance < terrainAvoidanceClearance then
		terrainBlend = 1
	end
	terrainBlend = terrainBlend * (terrainAvoidanceScale or 1)
	if terrainBlend > 0 and not emergency then
		local normalX, normalY, normalZ = spGetGroundNormal(terrainX, terrainZ, true)
		local terrainVelocityY = velocityY - normalY * (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
		if predictTerrain then
			terrainVelocityY = math.min(terrainVelocityY, 0)
		end
		terrainVelocityY = math_max(velocityY, velocityY + (terrainVelocityY - velocityY) * terrainBlend)
		terrainVelocityY = math_clamp(terrainVelocityY, -speed, speed)
		local terrainHorizontalSpeed = math.sqrt(math_max(speed * speed - terrainVelocityY * terrainVelocityY, 0))
		-- Retain the tested 45% terrain blend; only its pitch is needed here.
		local terrainPitch = math.atan2(
			velocityY + (terrainVelocityY - velocityY) * 0.45,
			horizontalSpeed + (terrainHorizontalSpeed - horizontalSpeed) * 0.45
		)
		pitch = math_max(pitch, terrainPitch)
	end

	local horizontalScale = speed * math.cos(pitch) / horizontalSpeed
	spSetProjectileVelocity(
		projectileID,
		velocityX * horizontalScale,
		speed * math.sin(pitch),
		velocityZ * horizontalScale
	)
	state.pitch = pitch
	state.pitchFrame = gameFrame
end

local function torpedoWaterPen(projectileID)
	local state = getOrCreateTorpedoState(projectileID)
	local targetType, target = spGetProjectileTarget(projectileID)
	local targetX, targetY, targetZ, surfaceTarget = getTorpedoTargetPosition(projectileID, targetType, target, state)
	if not isProjectileInWater(projectileID) then
		return false
	end

	local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	if
		velocityX == nil
		or velocityY == nil
		or velocityZ == nil
		or speed == nil
		or positionX == nil
		or positionY == nil
		or positionZ == nil
	then
		return true
	end
	-- Hover-attack aircraft can fire without a bomber-style aligned attack run.
	-- Reset their horizontal bearing once so entry smoothing cannot amplify a stale
	-- heading; other launchers retain their entry heading and native guidance.
	if
		state.allowWaterEntryHeadingCorrection
		and not state.waterEntryHeadingCorrected
		and targetX ~= nil
		and targetZ ~= nil
	then
		local targetDirectionX = targetX - positionX
		local targetDirectionZ = targetZ - positionZ
		local targetHorizontalDistance = math_diag(targetDirectionX, targetDirectionZ)
		local horizontalSpeed = math_diag(velocityX, velocityZ)
		if targetHorizontalDistance > 0.01 and horizontalSpeed > 0.01 then
			velocityX = targetDirectionX / targetHorizontalDistance * horizontalSpeed
			velocityZ = targetDirectionZ / targetHorizontalDistance * horizontalSpeed
			spSetProjectileVelocity(projectileID, velocityX, velocityY, velocityZ)
			state.waterEntryHeadingCorrected = true
		end
	end
	if surfaceTarget == nil then
		return false
	end
	if not surfaceTarget then
		-- Preserve native submerged-target tracking while anticipating the
		-- seafloor, then release avoidance near the intended impact point.
		local terrainAvoidanceScale = 1.0
		if targetX ~= nil and targetY ~= nil and targetZ ~= nil then
			local targetOffsetX = positionX - targetX
			local targetOffsetY = positionY - targetY
			local targetOffsetZ = positionZ - targetZ
			local targetDistance = math_diag(targetOffsetX, targetOffsetY, targetOffsetZ)
			local targetHorizontalDistance = math_diag(targetOffsetX, targetOffsetZ)
			local depthLeadRatio = targetType == targetedGround and terrainAvoidanceGroundTargetLeadRatio
				or terrainAvoidanceDepthLeadRatio
			local horizontalReleaseDistance =
				math_max(terrainAvoidanceTargetReleaseDistance, math.abs(targetOffsetY) * depthLeadRatio)
			local targetDistanceScale = math_clamp(targetDistance / terrainAvoidanceTargetReleaseDistance, 0, 1)
			local horizontalReleaseScale = math_clamp(targetHorizontalDistance / horizontalReleaseDistance, 0, 1)
			terrainAvoidanceScale = targetDistanceScale * horizontalReleaseScale
		end
		setTorpedoPitchVelocity(
			projectileID,
			positionX,
			positionY,
			positionZ,
			velocityX,
			velocityY,
			velocityZ,
			speed,
			nil,
			nil,
			true,
			terrainAvoidanceScale
		)
		return false
	end

	-- Allow the initial dive to reach running depth before rounding the entry.
	if positionY >= surfaceTargetDepth then
		return false
	end
	local horizontalDistance = speed * surfaceArrivalLeadFrames
	local surfaceEntryBlend = 0.0
	if targetX ~= nil and targetY ~= nil and targetZ ~= nil then
		local distance = math_diag(positionX - targetX, positionY - targetY, positionZ - targetZ)
		horizontalDistance = math_diag(positionX - targetX, positionZ - targetZ)
		surfaceEntryBlend = math_clamp(1 - distance / surfaceEntryCorrectionDistance, 0, 1)
	end
	local entryTargetDepth = surfaceTransitionStartDepth
		+ (surfaceTargetDepth - surfaceTransitionStartDepth) * surfaceEntryBlend
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	horizontalDistance = math.min(
		horizontalDistance,
		math_max(
			horizontalDistance - horizontalSpeed * surfaceArrivalLeadFrames,
			horizontalSpeed * minSurfaceCorrectionFrames
		)
	)
	local depthError = entryTargetDepth - positionY
	local wantedPitch = math.atan2(depthError, horizontalDistance)
	setTorpedoPitchVelocity(
		projectileID,
		positionX,
		positionY,
		positionZ,
		velocityX,
		velocityY,
		velocityZ,
		speed,
		wantedPitch,
		math_diag(horizontalDistance, depthError)
	)

	if velocityY >= entryHandoffDiveSpeed then
		projectiles[projectileID] = specialEffectFunction.torpsurfacetrack
	end
	return false
end

local function torpedoSurfaceTrack(projectileID)
	local state = getOrCreateTorpedoState(projectileID)
	local projectileDefID = spGetProjectileDefID(projectileID)
	local avoidLeavingWater = projectileDefID and torpedoAvoidLeavingWaterDefs[projectileDefID]
	local inWater = isProjectileInWater(projectileID)

	if avoidLeavingWater and inWater then
		state.shoreEnteredWater = true
	elseif not inWater then
		if state.shoreEnteredWater then
			local _, positionY = spGetProjectilePosition(projectileID)
			local velocityX, velocityY, velocityZ = spGetProjectileVelocity(projectileID)
			if positionY == nil or velocityX == nil or velocityY == nil or velocityZ == nil then
				return false
			end
			local returnSpeed = -positionY

			if velocityY > returnSpeed then
				spSetProjectileVelocity(projectileID, velocityX, returnSpeed, velocityZ)
			end
			return false
		end
		return
	end

	local targetType, targetID = spGetProjectileTarget(projectileID)
	if targetType ~= targetedUnit or not targetID then
		return false
	end

	local targetX, _, targetZ, surfaceTarget = getTorpedoTargetPosition(projectileID, targetType, targetID, state)
	if surfaceTarget == false then
		return true
	end
	if surfaceTarget == nil then
		return false
	end

	local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
	local velocityX, velocityY, velocityZ, speed = spGetProjectileVelocity(projectileID)
	if
		positionX == nil
		or positionY == nil
		or positionZ == nil
		or velocityX == nil
		or velocityY == nil
		or velocityZ == nil
		or speed == nil
	then
		return false
	end
	---@type number?
	local arrivalFrames
	if targetX ~= nil and targetZ ~= nil then
		arrivalFrames = getSurfaceArrivalFrames(
			projectileID,
			targetID,
			positionX,
			positionZ,
			velocityX,
			velocityZ,
			targetX,
			targetZ
		)
	end

	-- Aim to reach running depth before horizontal arrival. The same pitch rule
	-- handles entry and surface travel; this stage only chooses the aim point.
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	local correctionFrames = surfaceArrivalLeadFrames
	if arrivalFrames then
		correctionFrames = math.min(
			math_max(arrivalFrames - surfaceArrivalLeadFrames, minSurfaceCorrectionFrames),
			math_max(arrivalFrames, 1)
		)
		if avoidLeavingWater and positionY > surfaceTargetDepth then
			correctionFrames = math_max(arrivalFrames, 1)
		end
	end
	local aimDistance = math_max(horizontalSpeed, speed * 0.01) * correctionFrames
	local depthError = surfaceTargetDepth - positionY
	setTorpedoPitchVelocity(
		projectileID,
		positionX,
		positionY,
		positionZ,
		velocityX,
		velocityY,
		velocityZ,
		speed,
		math.atan2(depthError, aimDistance),
		math_diag(aimDistance, depthError)
	)

	if avoidLeavingWater then
		local currentVelocityX, currentVelocityY, currentVelocityZ, currentSpeed = spGetProjectileVelocity(projectileID)
		if currentVelocityX == nil or currentVelocityY == nil or currentVelocityZ == nil or currentSpeed == nil then
			return false
		end
		local maxRiseSpeed = shoreTorpedoBreachCeiling - positionY

		if currentVelocityY > maxRiseSpeed then
			setTorpedoPitchVelocity(
				projectileID,
				positionX,
				positionY,
				positionZ,
				currentVelocityX,
				currentVelocityY,
				currentVelocityZ,
				currentSpeed,
				math.asin(math_clamp(maxRiseSpeed / currentSpeed, -1, 1)),
				nil,
				false,
				nil,
				true
			)
		end
	end

	return false
end

specialEffectFunction.torpwaterpen = torpedoWaterPen
specialEffectFunction.torpsurfacetrack = torpedoSurfaceTrack

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		local customParams = weaponDef.customParams
		if customParams.avoid_leaving_water then
			torpedoAvoidLeavingWaterDefs[weaponDefID] = true
		end

		local effectName = customParams.speceffect
		-- Lua WeaponDefs.turnRate is already converted to radians/frame by the
		-- engine. Its normalized tangent step turns through atan(turnRate).
		weaponPitchStep[weaponDefID] = weaponDef.tracks and math.atan(math_max(weaponDef.turnRate or 0, 0)) or 0
		if effectName == "torpwaterpen" then
			weaponDefEffect[weaponDefID] = torpedoWaterPen
			torpedoWaterPenDefs[weaponDefID] = true
		elseif effectName == "torpsurfacetrack" then
			weaponDefEffect[weaponDefID] = torpedoSurfaceTrack
		end
	end

	if next(weaponDefEffect) then
		for weaponDefID in pairs(weaponDefEffect) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
	else
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	if weaponDefEffect[weaponDefID] then
		projectiles[projectileID] = weaponDefEffect[weaponDefID]
	end

	if torpedoWaterPenDefs[weaponDefID] then
		local ownerUnitDefID = proOwnerID and spGetUnitDefID(proOwnerID)
		local ownerUnitDef = ownerUnitDefID and UnitDefs[ownerUnitDefID]
		local state = getOrCreateTorpedoState(projectileID)
		state.allowWaterEntryHeadingCorrection = ownerUnitDef and ownerUnitDef.hoverAttack or false
	end
end

function gadget:ProjectileDestroyed(projectileID)
	projectiles[projectileID] = nil
	torpedoStates[projectileID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame
	for projectileID, effect in pairs(projectiles) do
		if effect(projectileID) then
			projectiles[projectileID] = nil
		end
	end
end
