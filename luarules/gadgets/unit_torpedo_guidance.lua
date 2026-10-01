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

-- Water penetration (torpedo)
-- Water entry and continuous surface-depth tracking are separate stages.

-- Shared torpedo motion constraints layered onto the engine's native guidance.
-- These values form a coordinated set and are not independent per-weapon tuning controls.
-- Weapon definitions retain native homing and accuracy; tracking_turn_radius only adjusts
-- entry-correction proximity. If the engine's native guidance model changes, these constraints
-- may require a separate set of values.
-- See doc/torpedo_motion_tuning.md for maintenance guidance.
-- Depths and distances are in elmos, speeds are in elmos/frame, times are in frames,
-- and correction strengths are normalized blends.

-- Surface-depth constraints
local surfaceTargetDepth = -2 -- Desired running depth against surface targets.
local surfaceDepthCorrection = 0.025 -- Converts depth error into vertical speed.
local minSurfaceDiveSpeed = -0.12 -- Fastest permitted dive while tracking the surface.
local maxUnderwaterSurfaceRiseSpeed = 1.25 -- Fastest permitted underwater rise.

-- Air-to-water entry constraints
local surfaceTransitionStartDepth = -12 -- Running-depth target used far from the target.
local minSurfaceEntryDiveSpeed = -0.3 -- Fastest permitted dive during entry smoothing.
local defaultEntryCorrectionRadius = 180 -- Default proximity range for stronger entry correction.
local surfaceEntryCorrectionDistance = 180 -- Range over which entry depth approaches surface depth.
local waterEntryCorrectionStartDepth = -2 -- Depth where entry correction begins.
local waterEntryCorrectionFullDepth = -10 -- Depth where entry correction reaches full strength.
local minWaterEntryCorrection = 0.2 -- Entry-correction strength far from the target.
local maxWaterEntryCorrection = 0.85 -- Entry-correction strength directly over the target.

-- Surface-target arrival constraints
local surfaceArrivalLeadFrames = 20 -- Lead time for reaching running depth before arrival.
local minSurfaceCorrectionFrames = 8 -- Shortest permitted arrival-correction interval.
local surfaceCorrectionRampStartFrames = 50 -- Arrival time where correction begins strengthening.
local surfaceCorrectionRampEndFrames = 20 -- Arrival time where correction reaches full strength.
local minSurfaceTrackingCorrection = 0.2 -- Long-range surface-tracking correction strength.
local maxSurfaceTrackingCorrection = 0.5 -- Close-range surface-tracking correction strength.

-- Terrain-avoidance constraints
local terrainAvoidanceClearance = 6 -- Minimum desired clearance above terrain.
local terrainAvoidanceLookaheadFrames = 4 -- Time projected ahead when checking terrain.
local terrainAvoidanceRampDepth = 12 -- Clearance range over which avoidance strengthens.
local terrainAvoidanceTargetReleaseDistance = 36 -- Minimum range for fading avoidance near the target.
local terrainAvoidanceDepthLeadRatio = 2 -- Release-distance multiplier for submerged unit targets.
local terrainAvoidanceGroundTargetLeadRatio = 3 -- Earlier avoidance release for ground targets.

-- Shore-launcher breach constraints
local minShoreSurfaceDiveSpeed = -4 -- Fastest permitted dive for shore-launched torpedoes.
local shoreTorpedoBreachCeiling = 2 -- Highest permitted position after entering the water.

-- Per-projectile runtime state; these fields are not trajectory configuration.
---@class TorpedoState
---@field allowWaterEntryHeadingCorrection boolean?
---@field surfaceTarget boolean?
---@field waterEntryHeadingCorrected boolean?
---@field shoreEnteredWater boolean?
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

---@param projectileID integer
---@param positionX number
---@param positionY number
---@param positionZ number
---@param velocityX number
---@param velocityY number
---@param velocityZ number
---@param speed number
---@param desiredVelocityY number
---@param smooth number
---@param predictTerrain boolean?
---@param terrainAvoidanceScale number?
local function setTorpedoPitchVelocity(
	projectileID,
	positionX,
	positionY,
	positionZ,
	velocityX,
	velocityY,
	velocityZ,
	speed,
	desiredVelocityY,
	smooth,
	predictTerrain,
	terrainAvoidanceScale
)
	local horizontalSpeed = math_diag(velocityX, velocityZ)
	if not speed or speed <= 0 or horizontalSpeed <= 0 then
		return
	end

	local terrainX, terrainY, terrainZ = positionX, positionY, positionZ
	if predictTerrain then
		terrainX = terrainX + velocityX * terrainAvoidanceLookaheadFrames
		terrainY = terrainY + velocityY * terrainAvoidanceLookaheadFrames
		terrainZ = terrainZ + velocityZ * terrainAvoidanceLookaheadFrames
	end
	local projectedTerrainClearance = terrainY - spGetGroundHeight(terrainX, terrainZ)
	local terrainAvoidanceBlend = 0.0
	if predictTerrain then
		terrainAvoidanceBlend = math_clamp(
			(terrainAvoidanceClearance + terrainAvoidanceRampDepth - projectedTerrainClearance)
				/ terrainAvoidanceRampDepth,
			0,
			1
		)
	elseif projectedTerrainClearance < terrainAvoidanceClearance then
		terrainAvoidanceBlend = 1
	end
	terrainAvoidanceBlend = terrainAvoidanceBlend * (terrainAvoidanceScale or 1)
	if terrainAvoidanceBlend > 0 then
		local normalX, normalY, normalZ = spGetGroundNormal(terrainX, terrainZ, true)
		local terrainVelocityY = velocityY - normalY * (velocityX * normalX + velocityY * normalY + velocityZ * normalZ)
		if predictTerrain then
			-- Submerged-target avoidance may flatten a dive, but must not create
			-- an upward trajectory that can eject the torpedo from the water.
			terrainVelocityY = math.min(terrainVelocityY, 0)
		end
		local blendedTerrainVelocityY = velocityY + (terrainVelocityY - velocityY) * terrainAvoidanceBlend
		desiredVelocityY = math_max(desiredVelocityY, blendedTerrainVelocityY)
	end

	-- Rebuild the full velocity at the desired pitch. Scaling X and Z together
	-- preserves horizontal heading while normalization preserves total speed.
	desiredVelocityY = math_clamp(desiredVelocityY, -speed, speed)
	local desiredHorizontalSpeed = math.sqrt(math_max(speed * speed - desiredVelocityY * desiredVelocityY, 0))
	local horizontalScale = desiredHorizontalSpeed / horizontalSpeed
	local desiredVelocityX = velocityX * horizontalScale
	local desiredVelocityZ = velocityZ * horizontalScale

	velocityX = velocityX + (desiredVelocityX - velocityX) * smooth
	velocityY = velocityY + (desiredVelocityY - velocityY) * smooth
	velocityZ = velocityZ + (desiredVelocityZ - velocityZ) * smooth

	local correctedSpeed = math_diag(velocityX, velocityY, velocityZ)
	if correctedSpeed > 0 then
		local speedScale = speed / correctedSpeed
		spSetProjectileVelocity(projectileID, velocityX * speedScale, velocityY * speedScale, velocityZ * speedScale)
	end
end

local function torpedoWaterPen(params, projectileID)
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
			velocityY,
			0.45,
			true,
			terrainAvoidanceScale
		)
		return false
	end

	local entryCorrectionRadius = params and params.tracking_turn_radius or defaultEntryCorrectionRadius
	local proximityBlend = 0.0
	local surfaceEntryBlend = 0.0
	local entryDepthBlend = math_clamp(
		(waterEntryCorrectionStartDepth - positionY) / (waterEntryCorrectionStartDepth - waterEntryCorrectionFullDepth),
		0,
		1
	)
	if targetX ~= nil and targetY ~= nil and targetZ ~= nil then
		local distance = math_diag(positionX - targetX, positionY - targetY, positionZ - targetZ)
		proximityBlend = math_clamp(1 - distance / entryCorrectionRadius, 0, 1)
		surfaceEntryBlend = math_clamp(1 - distance / surfaceEntryCorrectionDistance, 0, 1)
	end
	local entryTargetDepth = surfaceTransitionStartDepth
		+ (surfaceTargetDepth - surfaceTransitionStartDepth) * surfaceEntryBlend
	local desiredVelocityY = math_clamp(
		(entryTargetDepth - positionY) * surfaceDepthCorrection,
		minSurfaceEntryDiveSpeed,
		maxUnderwaterSurfaceRiseSpeed
	)

	setTorpedoPitchVelocity(
		projectileID,
		positionX,
		positionY,
		positionZ,
		velocityX,
		velocityY,
		velocityZ,
		speed,
		desiredVelocityY,
		(minWaterEntryCorrection + (maxWaterEntryCorrection - minWaterEntryCorrection) * proximityBlend)
			* entryDepthBlend
	)

	-- Keep rounding steep water entries until the torpedo is travelling near
	-- its normal surface-running descent rate, then hand off to tracking.
	if velocityY >= minSurfaceDiveSpeed then
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

	local minDiveSpeed = avoidLeavingWater and minShoreSurfaceDiveSpeed or minSurfaceDiveSpeed
	local desiredVelocityY = minDiveSpeed
	local correctionStrength = minSurfaceTrackingCorrection
	if arrivalFrames then
		local correctionFrames
		if avoidLeavingWater and positionY > surfaceTargetDepth then
			correctionFrames = math_max(arrivalFrames, 1)
			correctionStrength = maxSurfaceTrackingCorrection
		else
			correctionFrames = math_max(arrivalFrames - surfaceArrivalLeadFrames, minSurfaceCorrectionFrames)
			local arrivalBlend = math_clamp(
				(surfaceCorrectionRampStartFrames - arrivalFrames)
					/ (surfaceCorrectionRampStartFrames - surfaceCorrectionRampEndFrames),
				0,
				1
			)
			correctionStrength = minSurfaceTrackingCorrection
				+ (maxSurfaceTrackingCorrection - minSurfaceTrackingCorrection) * arrivalBlend
		end
		desiredVelocityY =
			math_clamp((surfaceTargetDepth - positionY) / correctionFrames, minDiveSpeed, maxUnderwaterSurfaceRiseSpeed)
	else
		desiredVelocityY = math_clamp(
			(surfaceTargetDepth - positionY) * surfaceDepthCorrection,
			minDiveSpeed,
			maxUnderwaterSurfaceRiseSpeed
		)
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
		desiredVelocityY,
		correctionStrength
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
				maxRiseSpeed,
				1
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
	local waterEntryMetatable = { __call = torpedoWaterPen }

	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		local customParams = weaponDef.customParams
		if customParams.avoid_leaving_water then
			torpedoAvoidLeavingWaterDefs[weaponDefID] = true
		end

		local effectName = customParams.speceffect
		if effectName == "torpwaterpen" then
			-- Preserve the existing required per-weapon entry-proximity parameter.
			local trackingTurnRadius = tonumber(customParams.tracking_turn_radius)
			if trackingTurnRadius ~= nil then
				weaponDefEffect[weaponDefID] = setmetatable({
					tracking_turn_radius = trackingTurnRadius,
				}, waterEntryMetatable)
				torpedoWaterPenDefs[weaponDefID] = true
			else
				Spring.Log(
					gadget:GetInfo().name,
					LOG.ERROR,
					weaponDef.name .. " has bad customparam: tracking_turn_radius"
				)
			end
			if customParams.def or customParams.when then
				Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, weaponDef.name .. " uses old customparams (def/when)")
			end
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

function gadget:GameFrame()
	for projectileID, effect in pairs(projectiles) do
		if effect(projectileID) then
			projectiles[projectileID] = nil
		end
	end
end
