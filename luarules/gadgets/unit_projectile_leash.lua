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
-- use weaponDef customparams.overrange_distance to destroy projectiles exceeding its limit.
-- use weaponDef customparams.leash_distance to destroy projectiles when they exceed range/overrange_distance and leash_distance relative to unit position.

---- optional customParams ----
-- use weaponDef customparams.weaponDef.customParams.projectile_destruction_method = "string" to change how projectiles are destroyed.
-- "explode" (default if undefined) detonates the projectile.
-- "descend" moves the projectile downward until it is destroyed by collision event.

--static values
local forcedDescentUpdateFrames = math.ceil(Game.gameSpeed / 5)
local compoundingMultiplier = 1.1 --compounding multiplier that influences the arc at which projectiles are forced to descend
local gravityMultiplier = 1.8
local descentSpeedStartingMultiplier = 0.15
local myGravityFallback = 0.1445 --positive values give upwards gravity

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathRandom = math.random
local mathCeil = math.ceil
local mathFloor = math.floor
local mathSqrt = math.sqrt
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spGetProjectileGravity = Spring.GetProjectileGravity
local spSetProjectileGravity = Spring.SetProjectileGravity

--tables
local defWatchTable = {}
local projectileMetaData = {}
local flightTimeWatch = {}
local projectileWatch = {}
local forcedDescentTable = {}
local gravityIncreaseTable = {}
local killQueue = {}

--variables
local gameFrame = 0


for weaponDefID, weaponDef in pairs(WeaponDefs) do

	if weaponDef.customParams.leash_distance or weaponDef.customParams.overrange_distance then
		local watchParams = {}
		if weaponDef.customParams.leash_distance then
			watchParams.leashRangeSq = (tonumber(weaponDef.customParams.leash_distance)) ^ 2
		end

		local overRange = tonumber(weaponDef.customParams.overrange_distance) or weaponDef.range
		watchParams.overRange = overRange
		watchParams.overRangeSq = overRange ^ 2

		local ascentFrames = 0
		if weaponDef.type == "StarburstLauncher" then
			ascentFrames = weaponDef.uptime * Game.gameSpeed
		end
		watchParams.flightTimeFrames =
		math.max(math.floor(((overRange / weaponDef.projectilespeed) + ascentFrames)), 1)
		watchParams.weaponDefID = weaponDefID

		local destructionMethod = weaponDef.customParams.projectile_destruction_method or "explode"
		if destructionMethod == "descend" then
			watchParams.descentMethod = true
		elseif destructionMethod == "gravity" then
			watchParams.gravityMethod = true
			watchParams.myGravity = -weaponDef.myGravity or -myGravityFallback --positive values give upwards gravity
			if watchParams.myGravity == 0 then
				watchParams.myGravity = -myGravityFallback
			end
		end



		defWatchTable[weaponDefID] = watchParams
		Script.SetWatchWeapon(weaponDefID, true)
	end
end


local function distanceTooFar(maxRangeSq, x1, z1, x2, z2)
	local dx = x2 - x1
	local dz = z2 - z1
	if (dx * dx + dz * dz) > maxRangeSq then
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
        if not vx then return false end
        
        local proSpeed = mathSqrt(vx * vx + vz * vz)

        local remainingDistance = maxRange - distance

        if remainingDistance <= 0 then
            return false
        end

        local frames = mathCeil(remainingDistance / proSpeed)

        return frames
    else
        return false
    end
end



local function projectileOverRangeCheck(weaponRange, originX, originZ, projectileX, projectileZ)
	local dx1 = originX - projectileX
	local dz1 = originZ - projectileZ
	local weaponRangeSq = weaponRange * weaponRange
	local distanceToOriginSq = dx1 * dx1 + dz1 * dz1
	if distanceToOriginSq > weaponRangeSq then
		if leashRange then
			local distanceToOwner
			local ownerX, ownerY, ownerZ = spGetUnitPosition(proOwnerID)
			if ownerX then
				local dx2 = ownerX - projectileX
				local dz2 = ownerZ - projectileZ
				distanceToOwner = mathSqrt(dx2 * dx2 + dz2 * dz2)
				if distanceToOwner > leashRange then
					return true
				end
			end
			return false
		end
		return true
	end
	return false
end


local function setDestructionFrame(proID, newFlightTime)
	local triggerFrame = gameFrame + newFlightTime --mathCeil(gameFrame + mathRandom(projectileWatchModulus))

	killQueue[triggerFrame] = killQueue[triggerFrame] or {}
	killQueue[triggerFrame][#killQueue[triggerFrame] + 1] = proID
end


local function setCheckFrame(proID, newFlightTime)
	local triggerFrame = gameFrame + newFlightTime

	flightTimeWatch[triggerFrame] = flightTimeWatch[triggerFrame] or {}
	flightTimeWatch[triggerFrame][#flightTimeWatch[triggerFrame] + 1] = proID
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	local defData = defWatchTable[weaponDefID]
	if not defData then return end

	setCheckFrame(proID, defData.flightTimeFrames)

	local metaData = { weaponDefID = weaponDefID, proOwnerID = proOwnerID }
	local originX, _, originZ = spGetUnitPosition(proOwnerID)
	metaData.originX = originX
	metaData.originZ = originZ

	projectileMetaData[proID] = metaData
end

function gadget:ProjectileDestroyed(proID)
	projectileMetaData[proID] = nil
	gravityIncreaseTable[proID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if flightTimeWatch[frame] then
		for i, proID in ipairs(flightTimeWatch[frame]) do
			local projectileX, _, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local proData = projectileMetaData[proID]
				local defData = defWatchTable[proData.weaponDefID]
				local newFlightTime = recalculateFlightTime(proID, defData.overRange, proData.originX, proData.originZ, projectileX, projectileZ)
				if newFlightTime then
					setDestructionFrame(proID, newFlightTime)
				else
					setDestructionFrame(proID, 1) --destroy this frame
				end
			else
				projectileMetaData[proID] = nil
			end
		end
		flightTimeWatch[frame] = nil
	end

	if killQueue[frame] then
		local descentMultiplier = descentSpeedStartingMultiplier
		for i, proID in ipairs(killQueue[frame]) do
			local proData = projectileMetaData[proID]
			if proData then
				local defData = defWatchTable[proData.weaponDefID]
				if defData.descentMethod then
					forcedDescentTable[proID] = descentMultiplier
				elseif defData.gravityMethod then
					gravityIncreaseTable[proID] = defData.myGravity
				else
					spSetProjectileCollision(proID)
				end
			end
			projectileMetaData[proID] = nil
		end
		killQueue[frame] = nil
	end

	if frame % forcedDescentUpdateFrames == 4 then
		for proID, descentMultiplier in pairs(forcedDescentTable) do
			local velocityX, velocityY, velocityZ, velocityOverall = spGetProjectileVelocity(proID)
			if velocityY then
				local newVelocityY = velocityY - velocityOverall * descentMultiplier
				spSetProjectileVelocity(proID, velocityX, newVelocityY, velocityZ)
				descentMultiplier = descentMultiplier * compoundingMultiplier
			else
				forcedDescentTable[proID] = nil
			end
		end
	end

	if frame % 10 == 4 then
		for proID, myGravity in pairs(gravityIncreaseTable) do
			myGravity = myGravity * gravityMultiplier
			gravityIncreaseTable[proID] = myGravity
			spSetProjectileGravity(proID, myGravity)
			Spring.Echo(myGravity, frame, gravityMultiplier)
		end
	end
end
