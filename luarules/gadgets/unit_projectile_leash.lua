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
local descentSpeedStartingMultiplier = 0.1
local flightTimeSlopMultiplier = 0.9
local projectileWatchModulus = math.ceil(Game.gameSpeed / 3)

--functions
local spGetUnitPosition = Spring.GetUnitPosition
local mathMax = math.max
local mathRandom = math.random
local mathCeil = math.ceil
local spGetProjectilePosition = Spring.GetProjectilePosition
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectileVelocity = Spring.SetProjectileVelocity

--tables
local defWatchTable = {}
local projectileMetaData = {}
local flightTimeProjectileWatch = {}
local edgyProjectileWatch = {}
local forcedDescentTable = {}
local randomDestructionBufferTable = {}

--variables
local gameFrame = 0


for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams.projectile_leash_range then
		defWatchTable[weaponDefID] = {}
		defWatchTable[weaponDefID].leashRangeSq = (tonumber(weaponDef.customParams.projectile_leash_range)) ^ 2
	end
	if weaponDef.customParams.projectile_leash_range or weaponDef.customParams.projectile_overrange_distance then
		defWatchTable[weaponDefID] = defWatchTable[weaponDefID] or {}
		
		local overRange = tonumber(weaponDef.customParams.projectile_overrange_distance) or weaponDef.range
		defWatchTable[weaponDefID].overRangeSq = overRange ^ 2

		local ascentFrames = 0
		if weaponDef.type == "StarburstLauncher" then
			ascentFrames = weaponDef.uptime * Game.gameSpeed
		end
		defWatchTable[weaponDefID].flightTimeFrames = math.floor((overRange / weaponDef.projectilespeed) * flightTimeSlopMultiplier + ascentFrames)

		Spring.Echo(weaponDef.name, "flightTimeFrames", defWatchTable[weaponDefID].flightTimeFrames)
		--zzz gotta add the key-value frame table thing to iterate over only the projectiles in THIS flightTimeFrames... Bet I can also eliminate the table transference too

		defWatchTable[weaponDefID].weaponDefID = weaponDefID

		local destructionMethod = weaponDef.customParams.projectile_destruction_method or "explode"
		if destructionMethod == "descend" then
			defWatchTable[weaponDefID].descentMethod = true
		end

		Script.SetWatchWeapon(weaponDefID, true)
	end
end


local function projectileOverRangeCheck(proOwnerID, weaponRangeSq, leashRangeSq, originX, originZ, projectileX, projectileZ)
    local dx1, dz1 = originX - projectileX, originZ - projectileZ
    if (dx1 * dx1 + dz1 * dz1) > weaponRangeSq then
        if leashRangeSq then
            local ownerX, _, ownerZ = spGetUnitPosition(proOwnerID)
            if ownerX then
                local ox2, oz2 = ownerX - projectileX, ownerZ - projectileZ
                if (ox2 * ox2 + oz2 * oz2) > leashRangeSq then
                    return true
                end
            end
            return false
        end
        return true
    end
    return false
end

local populateOriginsQueue = {}

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if defWatchTable[weaponDefID] then
		local roundedFrame = 6
		local originX, originy, originZ = spGetUnitPosition(proOwnerID)
		local triggerFrame = mathCeil(gameFrame + defWatchTable[weaponDefID].flightTimeFrames/ roundedFrame) * roundedFrame
		flightTimeProjectileWatch[triggerFrame] = flightTimeProjectileWatch[triggerFrame] or {}
		flightTimeProjectileWatch[triggerFrame][#flightTimeProjectileWatch[triggerFrame] + 1] = proID
		populateOriginsQueue[proID] = true
		projectileMetaData[proID] = {weaponDefID = weaponDefID, proOwnerID = proOwnerID}

	end
end

function gadget:GameFrame(frame)
	gameFrame = frame

	if flightTimeProjectileWatch[frame] then
		for i, proID in ipairs(flightTimeProjectileWatch[frame]) do
			edgyProjectileWatch[proID] = true
		end
		flightTimeProjectileWatch[frame] = nil
	end


	if frame % projectileWatchModulus == 3 then
		local randomRoundedFrame = 6
		local frameDelay = 3
		for proID, bool in pairs(edgyProjectileWatch) do
			local projectileX, _, projectileZ = spGetProjectilePosition(proID)
			if projectileX  and not populateOriginsQueue[proID] then
				local proData = projectileMetaData[proID]
				local defData = defWatchTable[proData.weaponDefID]
				if projectileOverRangeCheck(proData.proOwnerID, defData.overRangeSq, defData.leashRangeSq, proData.originX, proData.originZ, projectileX, projectileZ) then

					local triggerFrame = mathCeil((frame + mathRandom(projectileWatchModulus) / randomRoundedFrame) * randomRoundedFrame) + frameDelay

					randomDestructionBufferTable[triggerFrame] = randomDestructionBufferTable[triggerFrame] or {}
					randomDestructionBufferTable[triggerFrame][#randomDestructionBufferTable[triggerFrame] + 1] = proID
					edgyProjectileWatch[proID] = nil
				end
			else
				edgyProjectileWatch[proID] = nil -- remove destroyed projectiles
			end
		end
	end


	if randomDestructionBufferTable[frame] then
		local descentMultiplier = descentSpeedStartingMultiplier
		for i, proID in ipairs(randomDestructionBufferTable[frame]) do
			if defWatchTable[projectileMetaData[proID].weaponDefID].descentMethod then
				forcedDescentTable[proID] = descentMultiplier
			else
				spSetProjectileCollision(proID)
			end
			projectileMetaData[proID] = nil
		end
		randomDestructionBufferTable[frame] = nil
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

	if frame % 15 == 3 then
		for proID, bool in pairs(populateOriginsQueue) do
			local proData = projectileMetaData[proID]
			proData.originX, _, proData.originZ = spGetUnitPosition(projectileMetaData[proID].proOwnerID)
			populateOriginsQueue[proID] = nil
		end
	end
end
