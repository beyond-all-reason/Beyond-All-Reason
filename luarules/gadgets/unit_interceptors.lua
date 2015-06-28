function gadget:GetInfo()
	return {
		name     = "Don't target flyover nukes",
		desc     = "bla",
		author	 = "ashdnazg",
		date     = "Too late",
		license	 = "GNU GPL, v2 or later",
		layer    = 0,
		enabled  = true
	}
end

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
	local _, nukeTarget = Spring.GetProjectileTarget(targetProjectileID)
	local tx, _, tz = unpack(nukeTarget)
	return (ox - tx) ^ 2 + (oz - tz) ^ 2 < wd.coverageRange ^ 2
end


function gadget:Initialize()
	for wdid, wd in pairs(WeaponDefs) do
		if wd.interceptor > 0 and wd.coverageRange then
			Spring.Echo(wd.name)
			Script.SetWatchWeapon(wdid, true)
		end
	end
end