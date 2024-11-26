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

-- use weaponDef customparams.projectile_overrange_distance to destroy projectiles exceeding its limit.
-- use weaponDef customparams.projectile_leash_range to destroy projectiles when they exceed range/projectile_overrange_distance and projectile_leash_range relative to unit position.

---- optional customParams ----
-- use weaponDef customparams.weaponDef.customParams.projectile_destruction_method = "string" to change how projectiles are destroyed.
-- "explode" (default if undefined) detonates the projectile.
-- "targetground" retargets the ground at its last heading at the edge of its overrange/leash range after exceeding weaponDef.range.
-- "descend" moves the projectile downward until it is destroyed by collision event.

--static values
local lazyUpdateFrames = math.ceil(Game.gameSpeed / 3 * 2)
local edgyUpdateFrames = math.ceil(Game.gameSpeed / 6)
local forcedDescentUpdateFrames = math.ceil(Game.gameSpeed / 5)
local minimumThresholdRange = 10 --so that starburst missiles don't trigger edgyWatch during ascent
local descentMultiplier = 1.1 --compounding multiplier that influences the arc at which projectiles are forced to descend
local descentSpeedStartingMultiplier = 0.1

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathSqrt = math.sqrt
local tableCopy = table.copy
local mathMax = math.max
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity

--tables
local defWatchTable = {}
local lazyProjectileWatch = {}
local edgyProjectileWatch = {}
local forcedDescentTable = {}


for weaponDefID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.customParams.projectile_leash_range then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
        defWatchTable[weaponDefID].leashRange = tonumber(weaponDef.customParams.projectile_leash_range)
    end
    if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
		defWatchTable[weaponDefID].range = weaponDef.range
        defWatchTable[weaponDefID].weaponRange = weaponDef.range
        defWatchTable[weaponDefID].overRange = tonumber(weaponDef.customParams.projectile_overrange_distance) or weaponDef.range
        defWatchTable[weaponDefID].rangeThreshold = math.max((defWatchTable[weaponDefID].overRange - weaponDef.projectilespeed * lazyUpdateFrames), minimumThresholdRange)
        defWatchTable[weaponDefID].weaponDefID = weaponDefID

		local destructionMethod = weaponDef.customParams.projectile_destruction_method or "explode"
		if destructionMethod == "targetground" then
			defWatchTable[weaponDefID].targetGroundMethod = true
		elseif destructionMethod == "descend" then
			defWatchTable[weaponDefID].descentMethod = true
			defWatchTable[weaponDefID].maxDescentSpeed = weaponDef.projectilespeed
		else
			defWatchTable[weaponDefID].explodeMethod = true
		end

        Script.SetWatchWeapon(weaponDefID, true)
	end
end


local function projectileOverRangeCheck(proOwnerID, projectileOrigin, weaponRange,  leashRange, projectileX, projectileZ)
	if not projectileX then return false end
	
    local dx1 = projectileOrigin.x - projectileX
    local dz1 = projectileOrigin.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)

	local distanceToOwner
	if leashRange then
		local ownerX, ownerY, ownerZ = spGetUnitPosition(proOwnerID)
		local dx2 = ownerX - projectileX
		local dz2 = ownerZ - projectileZ
		distanceToOwner = mathSqrt(dx2 * dx2 + dz2 * dz2)

		if distanceToOrigin > weaponRange and distanceToOwner > leashRange then
			return true
		end
	else
		if distanceToOrigin > weaponRange then
			return true
		end
	end
	return false
end

local function projectileIsCloseToEdge(projectileOrigin, rangeThreshold, projectileX, projectileZ)
	if not projectileX then return false end
    local dx1 = projectileOrigin.x - projectileX
    local dz1 = projectileOrigin.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)
	if distanceToOrigin > rangeThreshold then
		return true
	else
		return false
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if defWatchTable[weaponDefID] then
		local originX, originy, originZ = spGetUnitPosition(proOwnerID)
		lazyProjectileWatch[proOwnerID] = lazyProjectileWatch[proOwnerID] or {}
		lazyProjectileWatch[proOwnerID][proID] = tableCopy(defWatchTable[weaponDefID])
		lazyProjectileWatch[proOwnerID][proID].origin = {x = originX, z = originZ}
	end
end

function gadget:GameFrame(frame)
	if frame % edgyUpdateFrames == 2 then
		for proOwnerID, proIDs in pairs(edgyProjectileWatch) do
			local hasProjectiles = false
			for proID, proData in pairs(proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
				if not projectileX then
					edgyProjectileWatch[proOwnerID][proID] = nil
				elseif projectileOverRangeCheck(proOwnerID, proData.origin, proData.overRange, proData.leashRange, projectileX, projectileZ) then
					if proData.explodeMethod then
						spSetProjectileCollision(proID)
						edgyProjectileWatch[proOwnerID][proID] = nil
					elseif proData.descentMethod then
						forcedDescentTable[proID] = {[1] = -proData.maxDescentSpeed, [2] = descentSpeedStartingMultiplier}
						edgyProjectileWatch[proOwnerID][proID] = nil
					else
						Spring.Echo("invalid destruction method")
					end

				end
			end
			if hasProjectiles == false then
				edgyProjectileWatch[proOwnerID] = nil
			end
		end
	end

	if frame % lazyUpdateFrames == 3 then
		for proOwnerID, proIDs in pairs(lazyProjectileWatch) do
			local hasProjectiles = false
			for proID, proData in pairs(proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
				if not projectileX then
					lazyProjectileWatch[proOwnerID][proID] = nil -- remove destroyed projectiles
				elseif projectileIsCloseToEdge(proData.origin, proData.rangeThreshold, projectileX, projectileZ) then
					edgyProjectileWatch[proOwnerID] = edgyProjectileWatch[proOwnerID] or {}
					edgyProjectileWatch[proOwnerID][proID] = proData
					lazyProjectileWatch[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				lazyProjectileWatch[proOwnerID] = nil
			end
		end
	end

	if frame % forcedDescentUpdateFrames == 4 then
		for proID, proData in pairs(forcedDescentTable) do
			local velocityX, velocityY, velocityZ = spGetProjectileVelocity(proID)
			if velocityY then
				--[1] is maxDescentSpeed
				--[2] is descentSpeedMultiplier
				local newVelocityY = mathMax(velocityY + proData[1] * proData[2], proData[1])
				spSetProjectileVelocity(proID, velocityX, newVelocityY, velocityZ)
				proData[2] = proData[2] * descentMultiplier
			else
				forcedDescentTable[proID] = nil
			end

		end
	end
end