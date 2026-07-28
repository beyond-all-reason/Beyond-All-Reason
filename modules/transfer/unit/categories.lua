local TransferEnums = VFS.Include("modules/context/enums.lua")

local sharing = {}

local combatGroupBuilders = {
	corfast = true, -- Twitcher
	armfark = true, -- Butler
	armconsul = true, -- Consul
}

---@param unitDef table Unit definition from UnitDefs
---@return string unitType One of TransferEnums.UnitType values
function sharing.classifyUnitDef(unitDef)
	if sharing.isCommanderDef(unitDef) then
		return TransferEnums.UnitType.Commander
	end

	-- ahead of the constructor check: fast T2 engineers fold into Combat
	if
		sharing.isCombatUnitDef(unitDef)
		or sharing.isTransportDef(unitDef)
		or sharing.isCombatGroupBuilderDef(unitDef)
	then
		return TransferEnums.UnitType.Combat
	end

	if sharing.isConstructorDef(unitDef) then
		return TransferEnums.UnitType.Constructor
	end

	if sharing.isFactoryDef(unitDef) then
		return TransferEnums.UnitType.Factory
	end

	if sharing.isResourceUnitDef(unitDef) then
		return TransferEnums.UnitType.Resource
	end

	if sharing.isUtilityUnitDef(unitDef) then
		return TransferEnums.UnitType.Utility
	end

	return TransferEnums.UnitType.Combat
end

---@param unitDef table
---@return boolean
function sharing.isCommanderDef(unitDef)
	return unitDef.customParams and unitDef.customParams.iscommander ~= nil
end

---@param unitDef table
---@return boolean
function sharing.isTransportDef(unitDef)
	return unitDef.canFly == true and unitDef.transportCapacity ~= nil and unitDef.transportCapacity > 0
end

---@param unitDef table
---@return boolean
function sharing.isCombatGroupBuilderDef(unitDef)
	return unitDef.name ~= nil and combatGroupBuilders[unitDef.name] == true
end

---@param unitDef table
---@return boolean
function sharing.isConstructorDef(unitDef)
	if unitDef.isFactory then
		return false
	end
	return unitDef.isBuilder == true or unitDef.canAssist == true
end

---MUST match the affected set in game_unit_transfer_controller so the tooltip prediction matches reality
---@param unitDef table
---@return boolean
function sharing.isMobileBuilderDef(unitDef)
	return unitDef ~= nil and unitDef.isBuilder == true and not unitDef.isImmobile and not unitDef.isFactory
end

---@param unitDef table
---@return boolean
function sharing.isFactoryDef(unitDef)
	return unitDef.isFactory == true
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean isCombat True if the unit is combat-focused
function sharing.isCombatUnitDef(unitDef)
	if
		unitDef.customParams
		and (
			unitDef.customParams.unitgroup == "weapon"
			or unitDef.customParams.unitgroup == "aa"
			or unitDef.customParams.unitgroup == "sub"
			or unitDef.customParams.unitgroup == "weaponaa"
			or unitDef.customParams.unitgroup == "weaponsub"
			or unitDef.customParams.unitgroup == "emp"
			or unitDef.customParams.unitgroup == "nuke"
			or unitDef.customParams.unitgroup == "antinuke"
			or unitDef.customParams.unitgroup == "explo"
		)
	then
		return true
	end

	if unitDef.weapons and #unitDef.weapons > 0 then
		return true
	end

	return false
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean
function sharing.isResourceUnitDef(unitDef)
	if
		unitDef.customParams
		and (
			unitDef.customParams.unitgroup == TransferEnums.ResourceType.ENERGY
			or unitDef.customParams.unitgroup == TransferEnums.ResourceType.METAL
		)
	then
		return true
	end

	return false
end

---@param unitDef table Unit definition from UnitDefs
---@return boolean
function sharing.isUtilityUnitDef(unitDef)
	if unitDef.customParams and unitDef.customParams.unitgroup == "util" then
		return true
	end

	return false
end

return sharing
