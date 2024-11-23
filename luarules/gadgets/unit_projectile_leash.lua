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
-- projectile_overrange_distance

--static values
local slowUpdateFrames = Game.gameSpeed / 3 * 2
local fastUpdateFrames = Game.gameSpeed / 10
local minimumThresholdRange = 10

local spGetUnitPosition = Spring.GetUnitPosition
local mathSqrt = math.sqrt
local spGetProjectilePosition = Spring.GetProjectilePosition
local spDeleteProjectile = Spring.DeleteProjectile
local spSpawnExplosion = Spring.SpawnExplosion

local defWatchTable = {}
local slowProjectileWatch = {}
local fastProjectileWatch = {}
local projectilesOwnersTable = {}


for weaponDefID, weaponDef in pairs(WeaponDefs) do
    if weaponDef.customParams.projectile_leash_range then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
        defWatchTable[weaponDefID].leashRange = tonumber(weaponDef.customParams.projectile_leash_range)

        -- Echo the leash range and leash threshold
        Spring.Echo("WeaponDefID:", weaponDefID, "Leash Range:", defWatchTable[weaponDefID].leashRange, "Projectile Speed:", weaponDef.projectilespeed, "Game Speed:", Game.gameSpeed, "Slow Update Frames:", slowUpdateFrames, "Leash Threshold:", defWatchTable[weaponDefID].leashThreshold, "Minimum Threshold Range:", minimumThresholdRange)
    end
    if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
        defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}

        defWatchTable[weaponDefID].weaponRange = weaponDef.range
        defWatchTable[weaponDefID].overRange = tonumber(weaponDef.customParams.projectile_overrange_distance) or weaponDef.range
        defWatchTable[weaponDefID].rangeThreshold = math.max((defWatchTable[weaponDefID].overRange - weaponDef.projectilespeed * slowUpdateFrames), minimumThresholdRange)
        defWatchTable[weaponDefID].weaponDefID = weaponDefID
        Script.SetWatchWeapon(weaponDefID, true)

        Spring.Echo("WeaponDefID:", weaponDefID, "Weapon Range:", weaponDef.range, "Over Range:", defWatchTable[weaponDefID].overRange, "Projectile Speed:", weaponDef.projectilespeed, "Game Speed:", Game.gameSpeed, "Slow Update Frames:", slowUpdateFrames, "Range Threshold:", defWatchTable[weaponDefID].rangeThreshold, "Minimum Threshold Range:", minimumThresholdRange)
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
end

local function isProjectileCloseToEdge(projectileOrigin, rangeThreshold, projectileX, projectileZ)
	if not projectileX then return false end
    local dx1 = projectileOrigin.x - projectileX
    local dz1 = projectileOrigin.z - projectileZ
    local distanceToOrigin = mathSqrt(dx1 * dx1 + dz1 * dz1)
	if distanceToOrigin > rangeThreshold then
		return true --zzz need to test this change
	else
		return false
	end
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if defWatchTable[weaponDefID] then
		local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
		slowProjectileWatch[proOwnerID] = slowProjectileWatch[proOwnerID] or {}

		if defWatchTable[weaponDefID] then
			slowProjectileWatch[proOwnerID] = slowProjectileWatch[proOwnerID] or {}
			slowProjectileWatch[proOwnerID][proID] = defWatchTable[weaponDefID]
			slowProjectileWatch[proOwnerID][proID].originCoordinates = {x = projectileX, z = projectileZ}
		end
		projectilesOwnersTable[proID] = proOwnerID
	end
end

function gadget:ProjectileDestroyed(proID)
	if not projectilesOwnersTable[proID] then return end
	slowProjectileWatch[projectilesOwnersTable[proID]] = nil
	projectilesOwnersTable[proID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	--zzz gonna need to queue unitID removal? no, i belirve they're removed if they have no table elements
end

function gadget:GameFrame(frame)
	if frame % fastUpdateFrames == 2 then
		for proOwnerID, proIDs in pairs(fastProjectileWatch) do
			local hasProjectiles = false
			for proID, proData in pairs(proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
				Spring.Echo("coordinates", projectileX, projectileY, projectileZ)
				if projectileOverRangeCheck(proOwnerID, proData.originCoordinates, proData.overRange, proData.leashRange, projectileX, projectileZ) then
					Spring.Echo("yes projectileX", frame)
					spDeleteProjectile(proID)
					spSpawnExplosion(projectileX, projectileY, projectileZ, 0, 0, 0, {weaponDef = proData.weaponDefID} )
				elseif not projectileX then
					Spring.Echo("no projectileX", frame)
					fastProjectileWatch[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				fastProjectileWatch[proOwnerID] = nil
			end
		end
	end
	--slow update
	if frame % slowUpdateFrames == 2 then
		--Spring.Echo(slowProjectileWatch, fastProjectileWatch)
		for proOwnerID, proIDs in pairs(slowProjectileWatch) do
			local hasProjectiles = false
			for proID, proData in pairs (proIDs) do
				hasProjectiles = true
				local projectileX, projectileY, projectileZ = spGetProjectilePosition(proID)
				if isProjectileCloseToEdge(proData.originCoordinates, proData.rangeThreshold, projectileX, projectileZ) then
					fastProjectileWatch[proOwnerID] = fastProjectileWatch[proOwnerID] or {}
					fastProjectileWatch[proOwnerID][proID] = proData
					slowProjectileWatch[proOwnerID][proID] = nil
				end
			end
			if hasProjectiles == false then
				slowProjectileWatch[proOwnerID] = nil
			end
		end
	end
end