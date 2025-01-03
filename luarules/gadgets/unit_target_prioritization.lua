function gadget:GetInfo()
	return {
		name    = "Target Prioritization",
		desc    = "target prioritization",
		author  = "SethDGamre",
		date    = "2024.12.28",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false --	no unsynced code
end

----Localize Functions----
local spGetUnitDefID = Spring.GetUnitDefID

local function findMatch(string, pattern)
	if string.match(string,"%f[%a]"..pattern.."%f[%A]") then --ripped this off the internet somewhere. Checks whole string patterns parsed by spaces not part of greater whole.
		return true
	else
		return false
	end
end

----Unit Type Categorization Functions----
local function unitIsSpam(uDef)
	if (uDef.customParams.purpose and findMatch(uDef.customParams.purpose, "SPAM"))
		or (uDef.health < 400
		and uDef.weapons and next(uDef.weapons)
		and uDef.metalcost < 55)
	then
		return true
	else
		return false
	end
end


----Weapon Type Categorization Functions----
local function weaponIsAlphastrike(wDef)
	if wDef.customParams.purpose and wDef.customParams.purpose == "ALPHASTRIKE"
		or wDef.reloadTime and wDef.reloadTime < 3
	then
		return true
	else
		return false
	end
end

local function weaponIsAntispam(wDef)
	if wDef.customParams.purpose and wDef.customParams.purpose == "ALPHASTRIKE"
	then
		return true
	else
		return false
	end
end

----Constants----
local WEAPONTYPES = {
	HIGHALPHA = 1,
	ANTISPAM = 2,
}
local UNITTYPES = {
	SPAM = 1,
	FAST = 2,
}


----Weight Table Entries----
local weaponWeights = {
	[WEAPONTYPES.ANTISPAM] = {
		[UNITTYPES.FAST] = 1.1,
		[UNITTYPES.SPAM] = 1.5,
	},

	[WEAPONTYPES.HIGHALPHA] = {
		[UNITTYPES.FAST] = 0.2,
		[UNITTYPES.SPAM] = 0.5,
	}
}

----Other Tables----
local unitDefTypes = {}
local weaponDefTypes = {}


----Populate def tables----
for uDefID, uDef in ipairs(UnitDefs) do
	if unitIsSpam(uDef) then
		unitDefTypes[uDefID] = UNITTYPES.SPAM
	end
end

for wDefID, wDef in ipairs(WeaponDefs) do
	local typeWeights = {}
	if weaponIsAlphastrike(wDef) then
		typeWeights = weaponWeights[WEAPONTYPES.HIGHALPHA]
	elseif weaponIsAntispam(wDef) then
		typeWeights = weaponWeights[WEAPONTYPES.ANTISPAM]
	end
	weaponDefTypes[wDefID] = typeWeights
end

function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if not targetID then return true, defPriority end

	local weaponTypeWeights = weaponDefTypes[attackerWeaponDefID]
	local targetDefID = spGetUnitDefID(targetID)
	local targetType = unitDefTypes[targetDefID]
	if targetType then
	local newDefPriority = weaponTypeWeights[targetType] or defPriority
		return true, newDefPriority
	end
	
	return true, defPriority
end

--Sprung's return code: antispam[attackerWeaponDefID] and Spring.Utilities.GetUnitPower(targetID) or defPriority
