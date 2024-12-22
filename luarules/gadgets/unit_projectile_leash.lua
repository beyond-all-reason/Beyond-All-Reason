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
local forcedDescentUpdateFrames = math.ceil(Game.gameSpeed / 5)
local compoundingMultiplier = 1.1 --compounding multiplier that influences the arc at which projectiles are forced to descend
local descentSpeedStartingMultiplier = 0.15
local flightTimeSlop = 0.9
local projectileWatchModulus = math.ceil(Game.gameSpeed / 3)

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathRandom = math.random
local mathCeil = math.ceil
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity

--tables
local defWatchTable = {}
local projectileMetaData = {}
local flightTimeWatch = {}
local projectileWatch = {}
local forcedDescentTable = {}
local killQueue = {}

--variables
local gameFrame = 0


for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
		local watchParams = {}
		if weaponDef.customParams.projectile_leash_range then
			watchParams.leashRangeSq = (tonumber(weaponDef.customParams.projectile_leash_range)) ^ 2
		end
		if (weaponDef.salvoSize and weaponDef.salvoSize > 1) or (weaponDef.projectiles and weaponDef.projectiles > 1) then
			watchParams.multiShot = true
		end

		local overRange = tonumber(weaponDef.customParams.projectile_overrange_distance) or weaponDef.range
		watchParams.overRangeSq = overRange ^ 2

		local ascentFrames = 0
		if weaponDef.type == "StarburstLauncher" then
			ascentFrames = weaponDef.uptime * Game.gameSpeed
		end
		watchParams.flightTimeFrames =
		math.max(math.floor(((overRange / weaponDef.projectilespeed) * flightTimeSlop + ascentFrames) - projectileWatchModulus), 1)
		watchParams.weaponDefID = weaponDefID
		Spring.Echo("flightTimeFrames", watchParams.flightTimeFrames)

		local destructionMethod = weaponDef.customParams.projectile_destruction_method or "explode"
		if destructionMethod == "descend" then
			watchParams.descentMethod = true
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


local function setDestructionFrame(proID)
	local triggerFrame = mathCeil(gameFrame + mathRandom(projectileWatchModulus))

	killQueue[triggerFrame] = killQueue[triggerFrame] or {}
	killQueue[triggerFrame][#killQueue[triggerFrame] + 1] = proID
end


function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	local defData = defWatchTable[weaponDefID]
	if not defData then return end

	local triggerFrame = gameFrame + defData.flightTimeFrames
	local triggerFrameTable = flightTimeWatch[triggerFrame]
	if not triggerFrameTable then
		triggerFrameTable = {}
		flightTimeWatch[triggerFrame] = triggerFrameTable
	end
	triggerFrameTable[#triggerFrameTable + 1] = proID

	local metaData = { weaponDefID = weaponDefID, proOwnerID = proOwnerID }
	local originX, _, originZ = spGetUnitPosition(proOwnerID)
	metaData.originX = originX
	metaData.originZ = originZ

	projectileMetaData[proID] = metaData
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if flightTimeWatch[frame] then
		for i, proID in ipairs(flightTimeWatch[frame]) do
			projectileWatch[proID] = true
		end
		flightTimeWatch[frame] = nil
	end

	if frame % projectileWatchModulus == 2 then
		for proID, bool in pairs(projectileWatch) do
			local projectileX, _, projectileZ = spGetProjectilePosition(proID)
			if projectileX then
				local proData = projectileMetaData[proID]
				local defData = defWatchTable[proData.weaponDefID]
				if distanceTooFar(defData.overRangeSq, proData.originX, proData.originZ, projectileX, projectileZ) then
					if defData.leashRangeSq then
						local ownerX, _, ownerZ = spGetUnitPosition(proData.proOwnerID)
						if not ownerX then
							setDestructionFrame(proID)
							projectileWatch[proID] = nil
						elseif distanceTooFar(defData.leashRangeSq, ownerX, ownerZ, projectileX, projectileZ) then
							setDestructionFrame(proID)
							projectileWatch[proID] = nil
						end
					else
						setDestructionFrame(proID)
						projectileWatch[proID] = nil
					end
				end
			else
				projectileWatch[proID] = nil -- remove destroyed projectiles
			end
		end
	end

	if killQueue[frame] then
		local descentMultiplier = descentSpeedStartingMultiplier
		for i, proID in ipairs(killQueue[frame]) do
			if defWatchTable[projectileMetaData[proID].weaponDefID].descentMethod then
				forcedDescentTable[proID] = descentMultiplier
			else
				spSetProjectileCollision(proID)
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
end
