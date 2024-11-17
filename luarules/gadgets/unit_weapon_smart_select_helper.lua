function gadget:GetInfo()
	return {
		name = "Weapon Smart Select Helper",
		desc = "Prevents auto-target units from blocking manual command fire orders for lower priority weapons.",
		author = "SethDGamre",
		date = "2024.11.16",
		license = "GNU GPL, v2 or later",
		layer = 1100,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then return end

--use customparams.smart_weapon_select_priority to define which weapon number is preferred over the other(s) and enable auto-targetting override.

--functions
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local spAddUnitDamage = Spring.AddUnitDamage
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spTestMoveOrder = Spring.TestMoveOrder
local spGetUnitHealth = Spring.GetUnitHealth
local spDestroyUnit = Spring.DestroyUnit

--tables
local smartWeaponsWatch = {}
local unitDefsWithSmartWeapons = {}

for unitDefID, def in ipairs(UnitDefs) do
	if def.customParams.smart_weapon_select_priority then
		smartWeaponsWatch[unitDefID] = def.customParams.smart_weapon_select_priority
		for weaponNumber, weaponData in ipairs(def.weapons) do
			Spring.Echo("Shitshit", weaponNumber, weaponData, weaponData.name)
			Script.SetWatchWeapon(weaponData.weaponDef, true)
		end
	end
end

for weaponDefID, weaponDef in ipairs(WeaponDefs) do

end

function gadget:GameFrame(frame)
	
end

-- function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
-- 	Spring.Echo("AllowCommand", unitID, unitDefID, unitTeam, cmdID)
-- 	return true
-- end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	Spring.Echo("AllowWeaponTargetCheck", attackerID, attackerWeaponNum, attackerWeaponDefID, Spring.GetGameFrame())
	return false, true
end