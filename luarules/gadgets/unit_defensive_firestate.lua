local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Defensive",
		desc = "Limits defensive firestate to nearby targets",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local Firestates = VFS.Include("modules/firestates.lua")
local DEFENSIVE_FIRE_RANGE = 300
local DEFENSIVE_FIRE_RANGE_SQ = DEFENSIVE_FIRE_RANGE * DEFENSIVE_FIRE_RANGE

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRulesParam = Spring.GetUnitRulesParam

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if spGetUnitRulesParam(attackerID, Firestates.RULES_PARAM) ~= Firestates.DEFENSIVE then
		return true
	end

	local attackerX, _, attackerZ = spGetUnitPosition(attackerID)
	local targetX, _, targetZ = spGetUnitPosition(targetID)
	if not attackerX or not targetX then
		return true
	end

	local distanceX = attackerX - targetX
	local distanceZ = attackerZ - targetZ
	if distanceX * distanceX + distanceZ * distanceZ > DEFENSIVE_FIRE_RANGE_SQ then
		return false
	end

	return true
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if not weaponDef.customParams.bogus then
				Script.SetWatchAllowTarget(weaponDefID, true)
			end
		end
	end
end
