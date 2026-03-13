local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")

local sharing = {}

---Classify a unit definition by type
---Each unit def resolves to exactly 1 category
---@param unitDef table Unit definition from UnitDefs
---@return string unitType One of TransferEnums.UnitType values
function sharing.classifyUnitDef(unitDef)
	if sharing.isT1TransportDef(unitDef) then
		return TransferEnums.UnitType.Transport
	end

	if sharing.isProductionUnitDef(unitDef) then
		if sharing.isT2ConstructorDef(unitDef) then
			return TransferEnums.UnitType.T2Constructor
		end
		return TransferEnums.UnitType.Production
	end

	if sharing.isResourceUnitDef(unitDef) then
		return TransferEnums.UnitType.Resource
	end

	if sharing.isUtilityUnitDef(unitDef) then
		return TransferEnums.UnitType.Utility
	end

	if sharing.isCombatUnitDef(unitDef) then
		return TransferEnums.UnitType.Combat
	end

	return TransferEnums.UnitType.Combat
end

---@param unitDef table
---@return boolean
function sharing.isT1TransportDef(unitDef)
	return unitDef.canFly == true
		and unitDef.transportCapacity ~= nil and unitDef.transportCapacity > 0
		and tostring(unitDef.customParams and unitDef.customParams.techlevel or "1") == "1"
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean isT2Con True if the unit is a T2 constructor
function sharing.isT2ConstructorDef(unitDef)
	local techlevel = unitDef.customParams and unitDef.customParams.techlevel
	local techlevelStr = techlevel and tostring(techlevel)
	return not unitDef.isFactory
			and #(unitDef.buildOptions or {}) > 0
			and techlevelStr == "2"
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean isCombat True if the unit is combat-focused
function sharing.isCombatUnitDef(unitDef)
	if unitDef.customParams and (
				unitDef.customParams.unitgroup == "weapon" or
				unitDef.customParams.unitgroup == "aa" or
				unitDef.customParams.unitgroup == "sub" or
				unitDef.customParams.unitgroup == "weaponaa" or
				unitDef.customParams.unitgroup == "weaponsub" or
				unitDef.customParams.unitgroup == "emp" or
				unitDef.customParams.unitgroup == "nuke" or
				unitDef.customParams.unitgroup == "antinuke" or
				unitDef.customParams.unitgroup == "explo"
			) then
		return true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		return true
	end

	return false
end

---Factories, constructors, nano turrets, assist units
---@param unitDef table Unit definition from UnitDefs
---@return boolean
function sharing.isProductionUnitDef(unitDef)
	if unitDef.canAssist or unitDef.isFactory or unitDef.isBuilder then
		return true
	end

	return false
end

---Metal extractors and energy producers
---@param unitDef table Unit definition from UnitDefs
---@return boolean
function sharing.isResourceUnitDef(unitDef)
	if unitDef.customParams and (
				unitDef.customParams.unitgroup == TransferEnums.ResourceType.ENERGY or
				unitDef.customParams.unitgroup == TransferEnums.ResourceType.METAL
			) then
		return true
	end

	return false
end

---Radar, storage, and other support buildings
---@param unitDef table Unit definition from UnitDefs
---@return boolean
function sharing.isUtilityUnitDef(unitDef)
	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
		return true
	end

	return false
end

return sharing
