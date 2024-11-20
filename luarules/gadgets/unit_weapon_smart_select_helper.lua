function gadget:GetInfo()
	return {
		name = "Weapon Smart Select Helper",
		desc = "Prevents auto-target units from blocking manual command fire orders for lower priority weapons.",
		author = "SethDGamre",
		date = "2024.11.16",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--use customparams.smart_weapon_select_priority to define which weapon number is preferred over the other(s) and enable auto-targetting override.

--functions
local spGetGameFrame = Spring.GetGameFrame()

--tables
local smartWeaponsWatch = {}
local unitDefsWithSmartWeapons = {}
local cmdSuspensionTable = { 
		[CMD.ATTACK] = true, 
		[CMD.AREA_ATTACK] = true,
		[CMD.UNIT_SET_TARGET] = true,
}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		smartWeaponsWatch[unitDefID] = def.customParams.smart_weapon_select_priority
		for weaponNumber, weaponData in ipairs(def.weapons) do
			Spring.Echo("smart_weapon_select_priority", def.name, weaponNumber, weaponData)
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	--Spring.Echo("AllowWeaponTargetCheck", attackerID, attackerWeaponNum, attackerWeaponDefID, Spring.GetGameFrame())
	local command = Spring.GetUnitCommands(attackerID, -1)
	Spring.Echo((command))
	if command[1] then
		Spring.Echo(command[1].id, attackerID, attackerWeaponNum)
	end
	return false, true
	end

