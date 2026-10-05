local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Don't target flyover nukes",
		desc = "Antinukes can target flyover nukes, this gadget ensures that they don't.",
		author = "Beherith",
		date = "2023.11.09",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false --	no unsynced code
end

-- Localize and pre-compute things
local math_sqrt = math.sqrt
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity

local unitTargetType = string.byte("u")
local featureTargetType = string.byte("f")
local groundTargetType = string.byte("g")
local projectileTargetType = string.byte("p")

local interceptorUnitDefWeapCovSqr = {} ---@type table<number, number?>
local interceptorUnitDefWeapFrames = {} ---@type table<number, number?>

local sweepFramesToTarget = {} ---@type table<ProjectileID, number?>
local sweepFrame = -1

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	--interceptorWeaponID is actually weaponNum, e.g.: gadget:AllowWeaponInterceptTarget( 24871, 1, 6540)
	--old method using the below method hammered cache hard:
	--local coverageRange = WeaponDefs[UnitDefs[Spring.GetUnitDefID(interceptorUnitID)].weapons[interceptorWeaponID].weaponDef].coverageRange
	local hash = 100000 * interceptorWeaponID + spGetUnitDefID(interceptorUnitID)

	local launchFrames = interceptorUnitDefWeapFrames[hash]
	if launchFrames then
		local frame = spGetGameFrame()
		if frame ~= sweepFrame then
			sweepFrame = frame
			sweepFramesToTarget = {}
		end
		local framesToTarget = sweepFramesToTarget[targetProjectileID]
		if framesToTarget and framesToTarget > launchFrames then
			return false
		end
	end

	local targetType, targetID = spGetProjectileTarget(targetProjectileID)
	if not targetType then
		return false
	end

	local covSquared = interceptorUnitDefWeapCovSqr[hash]

	local ox, _, oz = spGetUnitPosition(interceptorUnitID)
	local tx, ty, tz
	if targetType == unitTargetType then -- unit
		tx, ty, tz = spGetUnitPosition(targetID)
	elseif targetType == featureTargetType then -- feature
		tx, ty, tz = spGetFeaturePosition(targetID)
	elseif targetType == projectileTargetType then --PROJECTILE
		tx, ty, tz = spGetProjectilePosition(targetID)
	elseif targetType == groundTargetType then -- ground
		tx, tz = targetID[1], targetID[3]
	end

	if launchFrames then
		local px, _, pz = spGetProjectilePosition(targetProjectileID)
		local _, _, _, speed = spGetProjectileVelocity(targetProjectileID)
		---@diagnostic disable-next-line: need-check-nil
		local framesToTarget = math_sqrt((px - tx) * (px - tx) + (pz - tz) * (pz - tz)) / speed
		sweepFramesToTarget[targetProjectileID] = framesToTarget
		if framesToTarget > launchFrames then
			return false
		end
	end

	---@diagnostic disable-next-line: need-check-nil
	return (ox - tx) * (ox - tx) + (oz - tz) * (oz - tz) < covSquared
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		for weaponNum = 1, #weapons do
			local WeaponDefID = weapons[weaponNum].weaponDef
			local WeaponDef = WeaponDefs[WeaponDefID] ---@as table
			if WeaponDef.coverageRange and WeaponDef.coverageRange > 0 then
				interceptorUnitDefWeapCovSqr[100000 * weaponNum + unitDefID] = WeaponDef.coverageRange
					* WeaponDef.coverageRange
				---@diagnostic disable-next-line: need-check-nil, undefined-field
				local launchTime = tonumber(WeaponDef.customParams.terminal_intercept_time)
				if launchTime then
					interceptorUnitDefWeapFrames[100000 * weaponNum + unitDefID] = launchTime * Game.gameSpeed
				end
			end
			if WeaponDef.interceptor > 0 and WeaponDef.coverageRange then
				Script.SetWatchAllowTarget(WeaponDefID, true)
			end
		end
	end
end
