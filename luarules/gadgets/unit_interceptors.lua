local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name     = "Don't target flyover nukes",
		desc     = "Antinukes can target flyover nukes, this gadget ensures that they dont.",
		author	 = "Beherith",
		date     = "2023.11.09",
		license	 = "GNU GPL, v2 or later",
		layer    = 0,
		enabled  = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false	--	no unsynced code
end

-- Localize and pre-compute things
local spGetUnitDefID = Spring.GetUnitDefID
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetProjectilePosition = Spring.GetProjectilePosition

local unitTargetType = string.byte('u')
local featureTargetType = string.byte('f')
local groundTargetType = string.byte('g')
local projectileTargetType = string.byte('p')

-- Hashes (100000 * interceptorweaponID + unitDefID) to coveragesquared. This, along with other above optimizations make this significantly (100x) faster
local interceptorUnitDefWeapCovSqr = {} 

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	--interceptorWeaponID is actually weaponNum, e.g.: gadget:AllowWeaponInterceptTarget( 24871, 1, 6540)
	--old method using the below method hammered cache hard:
	--local coverageRange = WeaponDefs[UnitDefs[Spring.GetUnitDefID(interceptorUnitID)].weapons[interceptorWeaponID].weaponDef].coverageRange
    --Spring.GetProjectileTarget( number projectileID ) -> nil | [number targetTypeInt, number targetID | table targetPos = {x, y, z}]
	local targetType, targetID = spGetProjectileTarget(targetProjectileID)

    if targetType then
		local unitDefID = spGetUnitDefID(interceptorUnitID)
		local covSquared = interceptorUnitDefWeapCovSqr[100000 * interceptorWeaponID + unitDefID]
		
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

        return (ox - tx)*(ox - tx) + (oz - tz)*(oz - tz) < covSquared
    end
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		for weaponNum = 1, #weapons do
			local WeaponDefID = weapons[weaponNum].weaponDef
			local WeaponDef = WeaponDefs[WeaponDefID]
			if WeaponDef.coverageRange and WeaponDef.coverageRange > 0 then 
				interceptorUnitDefWeapCovSqr[100000 * weaponNum + unitDefID] = WeaponDef.coverageRange * WeaponDef.coverageRange
			end
			if WeaponDef.interceptor > 0 and WeaponDef.coverageRange then
				Script.SetWatchAllowTarget(WeaponDefID, true)
			end
		end
	end
end
