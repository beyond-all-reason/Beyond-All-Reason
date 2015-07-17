function gadget:GetInfo()
	return {
		name     = "Don't target flyover nukes",
		desc     = "bla",
		author	 = "ashdnazg + [teh]decay",
		date     = "Too late",
		license	 = "GNU GPL, v2 or later",
		layer    = 0,
		enabled  = true
	}
end


-- changelog:
-- 17 jul 2015 [teh]decay - fixed error: unit_interceptors.lua"]:27: bad argument #1 to 'unpack' (table expected, got number)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false	--	no unsynced code
end

local interceptors = {}

function gadget:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID)
	local ud = UnitDefs[Spring.GetUnitDefID(interceptorUnitID)]
	local wd = WeaponDefs[ud.weapons[interceptorWeaponID + 1].weaponDef]
	local ox, _, oz = Spring.GetUnitPosition(interceptorUnitID)

    --Spring.GetProjectileTarget( number projectileID ) -> nil | [number targetTypeInt, number targetID | table targetPos = {x, y, z}]
	local target_type_or_targetPos, targetID = Spring.GetProjectileTarget(targetProjectileID)

    if targetID then -- target = unit
        local tx,_, tz = Spring.GetUnitPosition(targetID)
        return (ox - tx) ^ 2 + (oz - tz) ^ 2 < wd.coverageRange ^ 2
    elseif target_type_or_targetPos then -- table with coordinates
        local tx, _, tz = unpack(target_type_or_targetPos)
        return (ox - tx) ^ 2 + (oz - tz) ^ 2 < wd.coverageRange ^ 2
    end
end


function gadget:Initialize()
	for wdid, wd in pairs(WeaponDefs) do
		if wd.interceptor > 0 and wd.coverageRange then
			Script.SetWatchWeapon(wdid, true)
		end
	end
end