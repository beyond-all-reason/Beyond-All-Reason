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

local defWatchTable = {}
local slowProjectileOwnersWatchTable = {}
local fastProjectileOwnersWatchTable = {}
local projectilesOwnersTable = {}
local slowUpdateFrames = Game.gameSpeed
local fastUpdateFrames = Game.gameSpeed / 10

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
		defWatchTable[weaponDefID] = {}

		defWatchTable[weaponDefID].weaponRange = weaponDef.range
		defWatchTable[weaponDefID].rangeThreshold = math.max((weaponDef.maxVelocity / slowUpdateFrames) - weaponDef.range, 0)
		Script.SetWatchWeapon(weaponDefID, true)
	end
	if weaponDef.customParams.projectile_leash_range then
		defWatchTable[weaponDefID].leashRange = tonumber(weaponDef.customParams.projectile_leash_range)
		defWatchTable[weaponDefID].leashThreshold = math.max((weaponDef.maxVelocity / slowUpdateFrames) - defWatchTable[weaponDefID].leashRange, 0)
	end
end

local function projectileOverRangeCheck(proID, proCoordinates, weaponRange, proOwnerID, leashRange)
    local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)

    local dx1 = proCoordinates.x - projectileX
    local dz1 = proCoordinates.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)

	local distanceToOwner
	if leashRange then
		local ownerX, ownerY, ownerZ = spGetUnitPosition(proOwnerID)
		local dx2 = ownerX - projectileX
		local dz2 = ownerZ - projectileZ
		distanceToOwner = mathSqrt(dx2 * dx2 + dz2 * dz2)

		if distanceToOrigin > weaponRange and distanceToOwner > leashRange then
			return projectileX, projectileY, projectileZ
		end
	else
		if distanceToOrigin > weaponRange then
			return projectileX, projectileY, projectileZ
		end
	end
end

local function isProjectileCloseToEdge(proID, proCoordinates, rangeThreshold, proOwnerID, leashThreshold)
    local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)

    local dx1 = proCoordinates.x - projectileX
    local dz1 = proCoordinates.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)

	local distanceToOwner
	if leashThreshold then
		local ownerX, ownerY, ownerZ = spGetUnitPosition(proOwnerID)
		local dx2 = ownerX - projectileX
		local dz2 = ownerZ - projectileZ
		distanceToOwner = mathSqrt(dx2 * dx2 + dz2 * dz2)

		if distanceToOrigin > rangeThreshold and distanceToOwner > leashThreshold then
			return projectileX, projectileY, projectileZ
		end
	else
		if distanceToOrigin > rangeThreshold then
			return projectileX, projectileY, projectileZ
		end
	end
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if defWatchTable[weaponDefID] then
		local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
		slowProjectileOwnersWatchTable[proOwnerID] = slowProjectileOwnersWatchTable[proOwnerID] or {}

		if defWatchTable[weaponDefID].leashRange then
			slowProjectileOwnersWatchTable[proOwnerID][proID] = {
				leashThreshold = defWatchTable[weaponDefID].leashThreshold,
				leashRange = defWatchTable[weaponDefID].leashRange,
				rangeThreshold = defWatchTable[weaponDefID].rangeThreshold,
				weaponRange = defWatchTable[weaponDefID].weaponRange,
				weaponDefID = weaponDefID,
				originCoordinates = {x = projectileX, y = projectileY, z = projectileZ}}
		else
			slowProjectileOwnersWatchTable[proOwnerID][proID] = {
				rangeThreshold = defWatchTable[weaponDefID].rangeThreshold,
				weaponRange = defWatchTable[weaponDefID].weaponRange,
				weaponDefID = weaponDefID,
				originCoordinates = {x = projectileX, y = projectileY, z = projectileZ}}
		end
		projectilesOwnersTable[proID] = proOwnerID
	end
end

function gadget:ProjectileDestroyed(proID)
	if not projectilesOwnersTable[proID] then return end
	slowProjectileOwnersWatchTable[projectilesOwnersTable[proID]][proID] = nil
	projectilesOwnersTable[proID] = nil
end

function gadget:GameFrame(frame)
	if frame % fastUpdateFrames == 4 then
		for proOwnerID, proIDs in pairs(fastProjectileOwnersWatchTable) do
			local hasProjectiles = false
			for proID, proData in pairs (proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = projectileOverRangeCheck(proID, proOwnerID, proData.originCoordinates, proData.weaponRange, proData.leashRange)
				if projectileX then
					spDeleteProjectile(proID)
					spSpawnExplosion(projectileX, projectileY, projectileZ, 0, 0, 0, {weaponDef = proData.weaponDefID} )
					fastProjectileOwnersWatchTable[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				fastProjectileOwnersWatchTable[proOwnerID] = nil
			end
		end
	end
	--slow update
	if frame % slowUpdateFrames == 4 then
		for proOwnerID, proIDs in pairs(slowProjectileOwnersWatchTable) do
			local hasProjectiles = false
			for proID, proData in pairs (proIDs) do
				hasProjectiles = true
				if isProjectileCloseToEdge(proID, proData.originCoordinates, proData.rangeThreshold, proOwnerID, proData.leashThreshold) then
					slowProjectileOwnersWatchTable[proOwnerID] = slowProjectileOwnersWatchTable[proOwnerID] or {}
					slowProjectileOwnersWatchTable[proOwnerID][proID] = proData
					slowProjectileOwnersWatchTable[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				slowProjectileOwnersWatchTable[proOwnerID] = nil
			end
		end
	end
end