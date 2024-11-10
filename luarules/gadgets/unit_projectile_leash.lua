function gadget:GetInfo()
	return {
		name = "Projectile Leash",
		desc = "Destroys projectiles if they exceed defined leash range",
		author = "SethDGamre",
		layer = 1,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

---- Optional unit customParams ----
-- use projectile_leash_range to destroy projectiles when they exceed its value.

local spGetUnitPosition = Spring.GetUnitPosition
local mathSqrt = math.sqrt
local spGetProjectilePosition = Spring.GetProjectilePosition
local spDeleteProjectile = Spring.DeleteProjectile
local spSpawnExplosion = Spring.SpawnExplosion

local defLeashTable = {}
local projectileOwnersWatchTable = {}
local projectilesOwnersTable = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.customParams.projectile_leash_range then
		defLeashTable[weaponDefID] = {}
		defLeashTable[weaponDefID].leashRange = tonumber(weaponDef.customParams.projectile_leash_range)
		defLeashTable[weaponDefID].weaponRange = weaponDef.range
		Script.SetWatchWeapon(weaponDefID, true)
	end
end

local function shouldProjectileBeDestroyed(proID, proOwnerID, proCoordinates, weaponRange, leashRange)
    local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
    local ownerX, ownerY, ownerZ = spGetUnitPosition(proOwnerID)

    local dx1 = proCoordinates.x - projectileX
    local dz1 = proCoordinates.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)

    local dx2 = ownerX - projectileX
    local dz2 = ownerZ - projectileZ
    local distanceToOwner = mathSqrt(dx2 * dx2 + dz2 * dz2)

    if distanceToOrigin > weaponRange and distanceToOwner > leashRange then
		return projectileX, projectileY, projectileZ
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if not defLeashTable[weaponDefID] then return end
	local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)

	projectileOwnersWatchTable[proOwnerID] = projectileOwnersWatchTable[proOwnerID] or {}
	projectileOwnersWatchTable[proOwnerID][proID] = {leashRange = defLeashTable[weaponDefID].leashRange, weaponRange = defLeashTable[weaponDefID].weaponRange, weaponDefID = weaponDefID, originCoordinates = {x = projectileX, y = projectileY, z = projectileZ}}

	projectilesOwnersTable[proID] = proOwnerID
end

function gadget:ProjectileDestroyed(proID)
	if not projectilesOwnersTable[proID] then return end
	projectileOwnersWatchTable[projectilesOwnersTable[proID]][proID] = nil
	projectilesOwnersTable[proID] = nil
end

function gadget:GameFrame(frame)
	if frame % 10 == 4 then
		for proOwnerID, proIDs in pairs(projectileOwnersWatchTable) do
			local hasProjectiles = false
			for proID, proData in pairs (proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = shouldProjectileBeDestroyed(proID, proOwnerID, proData.originCoordinates, proData.weaponRange, proData.leashRange)
				if projectileX then
					spDeleteProjectile(proID)
					spSpawnExplosion(projectileX, projectileY, projectileZ, 0, 0, 0, {weaponDef = proData.weaponDefID} )
					projectileOwnersWatchTable[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				projectileOwnersWatchTable[proOwnerID] = nil
			end
		end
	end
end