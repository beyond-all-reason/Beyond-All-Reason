local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Projectile Over-Range and Leashing",
		desc = "Destroys projectiles if they exceed defined ranges",
		author = "SethDGamre",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

---- unit customParams ----
-- use weaponDef customparams overrange_distance to destroy projectiles exceeding its limit.
-- use weaponDef customparams leash_distance to destroy projectiles when they exceed range/overrange_distance and leash_distance relative to unit position.

---- optional customParams ----
-- use weaponDef customparams projectile_destruction_method = "string" to change how projectiles are destroyed.
-- "explode" (default if undefined) detonates the projectile.
-- "descend" moves the projectile downward until it is destroyed by collision event.
-- "expire" sets the TTL (time to live) of the projectile to 0. Awaiting pending engine addition 1/27/25

--static values
local lateralMultiplier = 0.85
local compoundingMultiplier = 1.1 --compounding multiplier that influences the arc at which projectiles are forced to descend
local descentSpeedStartingMultiplier = 0.15

local descentModulo = math.floor(Game.gameSpeed / 4)
local leashModulo = math.ceil(Game.gameSpeed / 3)

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathRandom = math.random
local mathCeil = math.ceil
local mathSqrt = math.sqrt
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSetProjectileTimeToLive = Spring.SetProjectileTimeToLive

--tables
local defWatchTable = {}
local proMetaData = {}
local flightTimeWatch = {}
local descentTable = {}
local killQueue = {}
local leashWatch = {}

--variables
local gameFrame = 0

local function calculateFlightFrames(initialVelocity, maximumVelocity, accelerationRate, totalDistance)
	local totalFrames = 0

	-- Frames to reach maximum velocity
	local framesToMaxVelocity = (maximumVelocity - initialVelocity) / accelerationRate

	-- Distance traveled while accelerating
	local distanceAccelerating = initialVelocity * framesToMaxVelocity + 0.5 * accelerationRate * framesToMaxVelocity^2

	if distanceAccelerating > totalDistance then
		-- We already traveled too much, so just calculate time with accelerated movement + quadratic equation formula
		totalFrames = (mathSqrt(initialVelocity^2 + 2 * totalDistance * accelerationRate) - initialVelocity) / accelerationRate
	else
		-- Linear movement after accelerating
		totalFrames = framesToMaxVelocity + (totalDistance - distanceAccelerating) / maximumVelocity
	end

	-- Return the floored value of total frames
	return math.floor(totalFrames)
end

local function uptimeTurnFrames(turnRate)
	local framesRequired = math.floor(math.rad(90) / turnRate)--the turning period is negated from uptime frames for StarburstMissiles
	return framesRequired
end

for weaponDefID, weaponDef in pairs(WeaponDefs) do
	local customParams = weaponDef.customParams
	if customParams.leash_distance or customParams.overrange_distance then
		--populate def watch tables
		local watchParams = {}
		if customParams.leash_distance then
			watchParams.leashRangeSq = tonumber(customParams.leash_distance) ^ 2
		end
		local overRange = tonumber(customParams.overrange_distance) or weaponDef.range
		watchParams.overRange = overRange

		--accurately predict what frame the desired overrange will be reached
		local ascentFrames = 0
		if weaponDef.type == "StarburstLauncher" then
			ascentFrames = math.floor(weaponDef.uptime * Game.gameSpeed - uptimeTurnFrames(weaponDef.turnRate))
		end
		watchParams.flightTimeFrames = calculateFlightFrames(weaponDef.startvelocity, weaponDef.projectilespeed,
			weaponDef.weaponAcceleration, overRange) + ascentFrames
		watchParams.weaponDefID = weaponDefID

		--destruction methods
		local destructionMethod = customParams.projectile_destruction_method or "explode"
		if destructionMethod == "descend" then
			watchParams.descentMethod = true
		elseif destructionMethod == "expire" then
			watchParams.expireMethod = true
		end

		defWatchTable[weaponDefID] = watchParams
		Script.SetWatchProjectile(weaponDefID, true)
	end
end


local function leashCheck(maxRangeSq, proOwnerID, proX, proZ)
	local ownerX, _, ownerZ = spGetUnitPosition(proOwnerID)
	if ownerX then
		local dx = ownerX - proX
		local dz = ownerZ - proZ
		if (dx * dx + dz * dz) > maxRangeSq then
			return true
		end
	else
		return true
	end
end


local function recalculateFlightTime(proID, maxRange, x1, z1, x2, z2)
	local dx = x2 - x1
	local dz = z2 - z1
	local distance = mathSqrt(dx * dx + dz * dz)

	-- Check if the projectile is within the max range
	if distance < maxRange then
		local vx, _, vz = spGetProjectileVelocity(proID)
		if not vx then return false end --invalid projectile

		local remainingDistance = maxRange - distance

		local proSpeed = mathSqrt(vx * vx + vz * vz)

		local frames = mathCeil(remainingDistance / proSpeed)

		return frames
	else
		return false
	end
end

local function setDestructionFrame(proID, newFlightTime)
	local triggerFrame = gameFrame + newFlightTime

	killQueue[triggerFrame] = killQueue[triggerFrame] or {}
	killQueue[triggerFrame][#killQueue[triggerFrame] + 1] = proID
end


local function setFlightTimeFrame(proID, newFlightTime)
	local triggerFrame = gameFrame + newFlightTime

	flightTimeWatch[triggerFrame] = flightTimeWatch[triggerFrame] or {}
	flightTimeWatch[triggerFrame][#flightTimeWatch[triggerFrame] + 1] = proID
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	local defData = defWatchTable[weaponDefID]
	if not defData then return end

	setFlightTimeFrame(proID, defData.flightTimeFrames)

	local metaData = { weaponDefID = weaponDefID, proOwnerID = proOwnerID }
	local originX, _, originZ = spGetUnitPosition(proOwnerID)
	metaData.originX = originX
	metaData.originZ = originZ

	proMetaData[proID] = metaData
end

function gadget:ProjectileDestroyed(proID)
	proMetaData[proID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if flightTimeWatch[frame] then
		for _, proID in ipairs(flightTimeWatch[frame]) do
			local projectileX, _, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local proData = proMetaData[proID]
				if proData then
					local defData = defWatchTable[proData.weaponDefID]
					local newFlightTime = recalculateFlightTime(proID, defData.overRange, proData.originX, proData.originZ, projectileX, projectileZ)
					if newFlightTime then
						setFlightTimeFrame(proID, newFlightTime)
					else
						if defData.leashRangeSq then
							leashWatch[proID] = defData.leashRangeSq
						else
							setDestructionFrame(proID, 1) --destroy next frame
						end
					end
				end
			else
				proMetaData[proID] = nil
			end
		end
		flightTimeWatch[frame] = nil
	end

	if frame % leashModulo == 3 then
		for proID, leashRangeSq in pairs(leashWatch) do
			local projectileX, _, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local proData = proMetaData[proID]
				if leashCheck(leashRangeSq, proData.proOwnerID, projectileX, projectileZ) then
					setDestructionFrame(proID, mathRandom(leashModulo)) --destroy randomly between now and next frame check to reduce simultaneous projectile destructions
					leashWatch[proID] = nil
				end
			else
				leashWatch[proID] = nil
				proMetaData[proID] = nil
			end
		end
	end

	if killQueue[frame] then
		local descentMultiplier = descentSpeedStartingMultiplier
		for _, proID in ipairs(killQueue[frame]) do
			local proData = proMetaData[proID]
			if proData then
				local defData = defWatchTable[proData.weaponDefID]
				if defData.descentMethod then
					descentTable[proID] = descentMultiplier
				elseif defData.expireMethod then
					spSetProjectileTimeToLive(proID, frame)
				else
					spSetProjectileCollision(proID)
				end
			end
			proMetaData[proID] = nil
		end
		killQueue[frame] = nil
	end

	if frame % descentModulo == 3 then
		for proID, descentMultiplier in pairs(descentTable) do
			local velocityX, velocityY, velocityZ, velocityOverall = spGetProjectileVelocity(proID)
			if velocityY then
				local newVelocityY = velocityY - velocityOverall * descentMultiplier
				spSetProjectileVelocity(proID, velocityX * lateralMultiplier, newVelocityY, velocityZ * lateralMultiplier)
				descentTable[proID] = descentMultiplier * compoundingMultiplier
			else
				descentTable[proID] = nil
			end
		end
	end
end
