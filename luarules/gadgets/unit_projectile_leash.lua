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

---- Optional unit customParams ----

-- use weaponDef customparams.projectile_overrange_distance to destroy projectiles exceeding its limit.
-- use weaponDef customparams.projectile_leash_range to destroy projectiles when they exceed range/projectile_overrange_distance and projectile_leash_range relative to unit position.

--static values
local lazyUpdateFrames = math.ceil(Game.gameSpeed / 3 * 2)
local edgyUpdateFrames = math.ceil(Game.gameSpeed / 6)
local minimumThresholdRange = 10 --so that starburst missiles don't trigger edgyWatch during ascent

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathSqrt = math.sqrt
local tableCopy = table.copy
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision

--tables
local defWatchTable = {}
local lazyProjectileWatch = {}
local edgyProjectileWatch = {}


for weaponDefID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.customParams.projectile_leash_range then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
        defWatchTable[weaponDefID].leashRange = tonumber(weaponDef.customParams.projectile_leash_range)
    end
    if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
        defWatchTable[weaponDefID].weaponRange = weaponDef.range
        defWatchTable[weaponDefID].overRange = tonumber(weaponDef.customParams.projectile_overrange_distance) or weaponDef.range
        defWatchTable[weaponDefID].rangeThreshold = math.max((defWatchTable[weaponDefID].overRange - weaponDef.projectilespeed * lazyUpdateFrames), minimumThresholdRange)
        defWatchTable[weaponDefID].weaponDefID = weaponDefID
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
					spSetProjectileCollision(proID)
					edgyProjectileWatch[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				edgyProjectileWatch[proOwnerID] = nil
			end
		end
	end

	if frame % lazyUpdateFrames == 2 then
		for proOwnerID, proIDs in pairs(lazyProjectileWatch) do
			local hasProjectiles = false
			for proID, proData in pairs (proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
				if not projectileX then
					lazyProjectileWatch[proOwnerID][proID] = nil
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
end