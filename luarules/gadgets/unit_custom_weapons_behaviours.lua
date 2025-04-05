local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Custom weapon behaviours",
		desc    = "Handler for special weapon behaviours",
		author  = "Doo",
		date    = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- customparams = {
--     speceffect      := string
--     speceffect_when := string
--     speceffect_def  := string?
-- }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local random = math.random
local math_sqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi

local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetProjectileTarget = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetProjectilePosition = Spring.GetProjectilePosition
local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpGetUnitIsDead = Spring.GetUnitIsDead
local SpSetProjectilePosition = Spring.SetProjectilePosition
local SpSetProjectileTarget = Spring.SetProjectileTarget
local SpSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')
local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local projectiles = {}
local projectilesData = {}
local checkingFunctions = {}
local applyingFunctions = {}
local weaponCustomParams = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function alwaysTrue()
	return true
end

local function elevationIsNonpositive(proID)
	local _, y = SpGetProjectilePosition(proID)
	return y <= 0
end

local function velocityIsNegative(proID)
	local _, vy = SpGetProjectileVelocity(proID)
	return vy < 0
end

local function doNothing()
	return
end

local defaultApply = doNothing
local defaultCheck = { when = 'always', check = alwaysTrue }

--------------------------------------------------------------------------------

checkingFunctions.cruise = {}
checkingFunctions.cruise["distance>0"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetTypeInt, target = SpGetProjectileTarget(proID)
		local tx, ty, tz
		if targetTypeInt == targetedGround then
			tx, ty, tz = target[1], target[2], target[3]
		elseif targetTypeInt == targetedUnit then
			do
				local _
				_, _, _, _, _, _, tx, ty, tz = Spring.GetUnitPosition(target, true, true)
			end
		end
		local px, py, pz = SpGetProjectilePosition(proID)
		local pvx, pvy, pvz, speed = SpGetProjectileVelocity(proID)
		local infos = projectiles[proID]
		if math_sqrt((px - tx) ^ 2 + (py - ty) ^ 2 + (pz - tz) ^ 2) > tonumber(infos.lockon_dist) then
			local nx, ny, nz = Spring.GetGroundNormal(px, pz)
			local elevation = SpGetGroundHeight(px, pz) + tonumber(infos.cruise_min_height)
			local correction = (pvx * nx + pvy * ny + pvz * nz) * ny
			local pvy2
			-- Always correct for ground clearance. Follow terrain after first ground clear.
			-- Then, follow terrain also, but avoid going into steep dives, eg after cliffs.
			if py < elevation then
				pvy2 = pvy - correction
				projectilesData[proID] = true
			elseif py > elevation and pvy > speed * -0.25 and projectilesData[proID] then
				pvy2 = pvy - correction
			end
			if pvy2 then
				SpSetProjectilePosition(proID, px, elevation, pz)
				SpSetProjectileVelocity(proID, pvx, pvy2, pvz)
			end
			return false
		end
	end
	return true
end

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetType, target = SpGetProjectileTarget(proID)
		if targetType == targetedUnit and SpGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(proID)
			-- Hardcoded to retarget only from the primary weapon and only units or ground
			local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)
			if ownerTargetType == 1 then
				SpSetProjectileTarget(proID, ownerTarget, targetedUnit)
			elseif ownerTargetType == 2 then
				SpSetProjectileTarget(proID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			end
			return false
		end
	end
	return true
end

checkingFunctions.sector_fire = {}
applyingFunctions.sector_fire = function(proID)
	local infos = projectiles[proID]
	local spread_angle = tonumber(infos.spread_angle)
	local max_range_reduction = tonumber(infos.max_range_reduction)

	local angle_factor = (spread_angle * (random() - 0.5)) * mathPi / 180
	local velocity_factor = 1 - (random() ^ (1 + max_range_reduction)) * max_range_reduction

	local cos_angle = mathCos(angle_factor)
	local sin_angle = mathSin(angle_factor)

	local vx, vy, vz = SpGetProjectileVelocity(proID)
	vx = vx * cos_angle - vz * sin_angle * velocity_factor
	vz = vx * sin_angle + vz * cos_angle * velocity_factor

	SpSetProjectileVelocity(proID, vx, vy, vz)
end

checkingFunctions.split = {}
checkingFunctions.split["yvel<0"] = velocityIsNegative
applyingFunctions.split = function(proID)
	local px, py, pz = SpGetProjectilePosition(proID)
	local vx, vy, vz, vw = SpGetProjectileVelocity(proID)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileDefID = WeaponDefNames[infos.speceffect_def].id
	local projectileParams = {
		pos     = { px, py, pz },
		owner   = ownerID,
		ttl     = 3000,
		gravity = gravityPerFrame,
		model   = infos.model,
		cegTag  = infos.cegtag,
	}
	for _ = 1, tonumber(infos.number) do
		projectileParams.speed = {
			vx - vw * (random(-100, 100) / 880),
			vy - vw * (random(-100, 100) / 440),
			vz - vw * (random(-100, 100) / 880)
		}
		Spring.SpawnProjectile(projectileDefID, projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

-- Water penetration behaviors

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<=0"] = elevationIsNonpositive
applyingFunctions.cannonwaterpen = function(proID)
	local px, py, pz = SpGetProjectilePosition(proID)
	local vx, vy, vz = SpGetProjectileVelocity(proID)
	local nvx, nvy, nvz = vx * 0.5, vy * 0.5, vz * 0.5
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileParams = {
		pos = { px, py, pz },
		speed = { nvx, nvy, nvz },
		owner = ownerID,
		ttl = 3000,
		gravity = -Game.gravity / 3600,
		model = infos.model,
		cegTag = infos.cegtag,
	}
	Spring.SpawnProjectile(WeaponDefNames[infos.speceffect_def].id, projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<=0"] = elevationIsNonpositive
applyingFunctions.torpwaterpen = function(proID)
	local vx, vyOld, vz = SpGetProjectileVelocity(proID)
	local targetType, targetID = SpGetProjectileTarget(proID)
	local vyNew = 0
	-- Only dive below surface if the target is at an appreciable depth.
	if targetType == targetedUnit and targetID then
		local _, unitPosY = Spring.GetUnitPosition(targetID)
		if unitPosY and unitPosY < -10 then
			vyNew = vyOld / 6
		end
	end
	-- Brake without halting, else torpedoes may overshoot close targets.
	SpSetProjectileVelocity(proID, vx / 1.3, vyNew, vz / 1.3)
end

checkingFunctions.torpwaterpenretarget = {}
do
	local checkFunction = checkingFunctions.retarget.always
	local applyFunction = applyingFunctions.torpwaterpen
	checkingFunctions.torpwaterpenretarget["ypos<=0"] = function(proID)
		local result = checkFunction(proID)
		local _, py = SpGetProjectilePosition(proID)
		if py <= 0 then applyFunction(proID) end
		return result
	end
end

--------------------------------------------------------------------------------

for speceffect in pairs(checkingFunctions) do
	if not applyingFunctions[speceffect] then
		applyingFunctions[speceffect] = defaultApply
	end
end

for speceffect in pairs(applyingFunctions) do
	if not checkingFunctions[speceffect] or not next(checkingFunctions[speceffect]) then
		checkingFunctions[speceffect] = checkingFunctions[speceffect] or {}
		checkingFunctions[speceffect][defaultCheck.when] = defaultCheck.check
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local speceffect = weaponDef.customParams.speceffect
			local when = weaponDef.customParams.speceffect_when
			local def = weaponDef.customParams.speceffect_def
			if def and not WeaponDefNames[def] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect_def=' .. def .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			elseif not checkingFunctions[speceffect][when] or not applyingFunctions[speceffect] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect=' .. speceffect .. ',speceffect_when=' .. (when or 'nil') .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			else
				weaponCustomParams[weaponDefID] = weaponDef.customParams
			end
		end
	end
	if not next(weaponCustomParams) then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "No custom weapons found. Removing.") -- todo: back to INFO
		gadgetHandler:RemoveGadget(self)
		return
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if weaponCustomParams[weaponDefID] then
		projectiles[proID] = weaponCustomParams[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectilesData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.speceffect_when](proID) then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectilesData[proID] = nil
		end
	end
end
