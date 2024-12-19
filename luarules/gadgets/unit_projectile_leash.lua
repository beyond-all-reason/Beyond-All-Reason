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
-- "descend" moves the projectile downward until it is destroyed by collision event.

--static values
local lazyUpdateFrames = math.ceil(Game.gameSpeed / 3 * 2)
local edgyUpdateFrames = math.ceil(Game.gameSpeed / 6)
local forcedDescentUpdateFrames = math.ceil(Game.gameSpeed / 5)
local minimumThresholdRange = 10 --so that starburst missiles don't trigger edgyWatch during ascent
local compoundingMultiplier = 1.1 --compounding multiplier that influences the arc at which projectiles are forced to descend
local descentSpeedStartingMultiplier = 0.1

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathSqrt = math.sqrt
local mathMax = math.max
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity

--tables
local defWatchTable = {}
local lazyProjectileWatch = {}
local edgyProjectileWatch = {}
local forcedDescentTable = {}


for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams.projectile_leash_range then
		defWatchTable[weaponDefID] = {}
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
		if destructionMethod == "descend" then
			defWatchTable[weaponDefID].descentMethod = true
		else
			defWatchTable[weaponDefID].explodeMethod = true
		end

		Script.SetWatchWeapon(weaponDefID, true)
	end
end


local function projectileOverRangeCheck(proOwnerID, weaponRange,  leashRange, originX, originZ, projectileX, projectileZ)
	local dx1 = originX - projectileX
	local dz1 = originZ - projectileZ
	local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)

	if distanceToOrigin > weaponRange then
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

local function projectileIsCloseToEdge(rangeThreshold, originX, originZ, projectileX, projectileZ)
	local dx1 = originX - projectileX
	local dz1 = originZ - projectileZ
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
		lazyProjectileWatch[proID] = {weaponDefID = weaponDefID, proOwnerID = proOwnerID, originX = originX, originZ = originZ}
	end
end

function gadget:GameFrame(frame)
	if frame % edgyUpdateFrames == 2 then
		for proID, proData in pairs(edgyProjectileWatch) do
			local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local defData = defWatchTable[proData.weaponDefID]
				if projectileOverRangeCheck(proData.proOwnerID, defData.overRange, defData.leashRange, proData.originX, proData.originZ, projectileX, projectileZ) then
					if defData.explodeMethod then
						spSetProjectileCollision(proID)
						edgyProjectileWatch[proID] = nil
					elseif defData.descentMethod then
						forcedDescentTable[proID] = descentSpeedStartingMultiplier
						edgyProjectileWatch[proID] = nil
					else
						Spring.Echo("invalid destruction method")
					end
				end
			else
				edgyProjectileWatch[proID] = nil -- remove destroyed projectiles
			end
		end
	end

	if frame % lazyUpdateFrames == 3 then
		for proID, proData in pairs(lazyProjectileWatch) do
			local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local defData = defWatchTable[proData.weaponDefID]
				if projectileIsCloseToEdge(defData.rangeThreshold, proData.originX, proData.originZ, projectileX, projectileZ) then
					edgyProjectileWatch[proID] = proData
					lazyProjectileWatch[proID] = nil
				end
			else
				lazyProjectileWatch[proID] = nil -- remove destroyed projectiles
			end
		end
	end

	if frame % forcedDescentUpdateFrames == 4 then
		for proID, descentMultiplier in pairs(forcedDescentTable) do
			local velocityX, velocityY, velocityZ, velocityW = spGetProjectileVelocity(proID)
			if velocityY then
				local newVelocityY = mathMax(velocityY - velocityW * descentMultiplier, -velocityW)
				spSetProjectileVelocity(proID, velocityX, newVelocityY, velocityZ)
				descentMultiplier = descentMultiplier * compoundingMultiplier
			else
				forcedDescentTable[proID] = nil
			end
		end
	end
end
