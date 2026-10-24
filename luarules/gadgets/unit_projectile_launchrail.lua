local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Projectile launch alignment",
		desc = "Keeps a projectile aligned with its launch piece until it travels clear of the weapon",
		author = "Egzothicki",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetProjectileDirection = Spring.GetProjectileDirection
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetUnitWeaponVectors = Spring.GetUnitWeaponVectors
local spSetProjectilePosition = Spring.SetProjectilePosition

local railLengths = {} -- [weaponDefID] = length
local railWeaponNums = {} -- [weaponDefID] = weapon number on the owning unitdef
local railedProjectiles = {} -- [projectileID] = { ownerID, weaponNum, direction, length }

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		local length = tonumber(weaponDef.customParams.launchrail_length)
		if length and length > 0 then
			railLengths[weaponDefID] = length
		end
	end

	if not next(railLengths) then
		gadgetHandler:RemoveGadget(self)
		return
	end

	for _, unitDef in pairs(UnitDefs) do
		for weaponNum, weapon in ipairs(unitDef.weapons) do
			if railLengths[weapon.weaponDef] then
				railWeaponNums[weapon.weaponDef] = weaponNum
			end
		end
	end

	for weaponDefID in pairs(railLengths) do
		Script.SetWatchProjectile(weaponDefID, true)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	local length = railLengths[weaponDefID]
	local weaponNum = railWeaponNums[weaponDefID]
	if not length or not weaponNum or not proOwnerID then
		return
	end

	local directionX, directionY, directionZ = spGetProjectileDirection(projectileID)
	if not directionX or (directionX == 0 and directionY == 0 and directionZ == 0) then
		directionX, directionY, directionZ = 0, 1, 0
	end

	railedProjectiles[projectileID] = {
		ownerID = proOwnerID,
		weaponNum = weaponNum,
		directionX = directionX,
		directionY = directionY,
		directionZ = directionZ,
		length = length,
	}
end

function gadget:ProjectileDestroyed(projectileID)
	railedProjectiles[projectileID] = nil
end

function gadget:GameFramePost(frame)
	for projectileID, rail in pairs(railedProjectiles) do
		local released = true

		if spGetProjectileTimeToLive(projectileID) > 0 then
			local anchorX, anchorY, anchorZ = spGetUnitWeaponVectors(rail.ownerID, rail.weaponNum)
			if anchorX then
				local positionX, positionY, positionZ = spGetProjectilePosition(projectileID)
				local travel = (positionX - anchorX) * rail.directionX
					+ (positionY - anchorY) * rail.directionY
					+ (positionZ - anchorZ) * rail.directionZ

				if travel < rail.length then
					spSetProjectilePosition(
						projectileID,
						anchorX + rail.directionX * travel,
						anchorY + rail.directionY * travel,
						anchorZ + rail.directionZ * travel
					)
					released = false
				end
			end
		end

		if released then
			railedProjectiles[projectileID] = nil
		end
	end
end
