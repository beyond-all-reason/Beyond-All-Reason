-- unit_attributes_rules.lua ---------------------------------------------------
-- Whether GG.UnitAttributes would accept a write, for checking writes ahead of
-- time. The controller does not call these. It is for consumer code and tests.
--
-- The functions below require the `entry` to be passed. The rules don't get to
-- know anything about the definitions so can formulate zero special exceptions.
--------------------------------------------------------------------------------

-- The explosion keys used in `Spring.SetUnitWeaponDamages`.
local EXPLOSIONS = { explode = true, selfDestruct = true }

local function wasAllowed(reason, parameter)
	if reason then
		return false, reason, parameter
	end
	return true
end

local function kindReason(entry, perWeapon)
	if entry == nil then
		return "not found", "attribute"
	elseif perWeapon and not entry.perWeapon then
		return "is not written per weapon", "attribute"
	elseif not perWeapon and entry.perWeapon then
		return "is written per weapon", "attribute"
	end
end

local function valueReason(entry, value)
	if value == nil then
		return
	end
	local valueType = type(value)
	if entry.multiplyOnly then
		return "is multiplication-only", "attribute"
	elseif valueType ~= entry.type then
		return "takes a " .. entry.type .. ", got " .. valueType, "value"
	elseif valueType == "number" and value < 0 and not entry.canBeNegative then
		return "must be >= 0, got " .. value, "value"
	end
end

local function multiplierReason(entry, multiplier)
	if multiplier == nil then
		return
	end
	local multiplierType = type(multiplier)
	if multiplierType ~= "number" then
		return "takes a number multiplier, got " .. multiplierType, "multiplier"
	elseif multiplier < 0 and not entry.canBeNegative then
		return "must be >= 0, got " .. multiplier, "multiplier"
	end
end

local function weaponReason(entry, weapon, unitDef)
	if weapon == nil then
		return
	elseif EXPLOSIONS[weapon] then
		if not entry.perExplosion then
			return "is not written per explosion", "weapon"
		end
	elseif unitDef and not unitDef.weapons[weapon] then
		return "names a weapon the unitdef does not have", "weapon"
	end
end

---Whether `SetUnitAttribute` would accept this value.
---@param entry UnitAttributeDefinition?
---@param value any `nil` clears
---@return boolean ok
---@return string? reason
---@return "attribute"|"value"? parameter
local function canSetUnitAttribute(entry, value)
	local reason, parameter = kindReason(entry, false)
	if not reason then
		reason, parameter = valueReason(entry, value)
	end
	return wasAllowed(reason, parameter)
end

---Whether `SetUnitDefAttribute` would accept this value.
---@param entry UnitAttributeDefinition?
---@param value any `nil` clears
---@return boolean ok
---@return string? reason
---@return "attribute"|"value"? parameter
local function canSetUnitDefAttribute(entry, value)
	local reason, parameter = kindReason(entry, false)
	if not reason and entry.isUnitState then
		reason, parameter = "cannot be set on unitdefs", "attribute"
	elseif not reason then
		reason, parameter = valueReason(entry, value)
	end
	return wasAllowed(reason, parameter)
end

---Whether `SetUnitModifier` or `SetUnitDefModifier` would accept this multiplier.
---@param entry UnitAttributeDefinition?
---@param multiplier any `nil` clears
---@return boolean ok
---@return string? reason
---@return "attribute"|"multiplier"? parameter
local function canSetUnitModifier(entry, multiplier)
	local reason, parameter = kindReason(entry, false)
	if not reason and (entry.isUnitState or entry.type ~= "number") then
		reason, parameter = "cannot be multiplied", "attribute"
	elseif not reason then
		reason, parameter = multiplierReason(entry, multiplier)
	end
	return wasAllowed(reason, parameter)
end

---Whether `SetUnitWeaponAttribute` or `SetUnitDefWeaponAttribute` would accept this value.
---@param entry WeaponAttributeDefinition?
---@param value any `nil` clears
---@param weapon integer|"explode"|"selfDestruct"|nil `nil` is every weapon
---@param unitDef table? checks that the weapon exists when given
---@return boolean ok
---@return string? reason
---@return "attribute"|"value"|"weapon"? parameter
local function canSetUnitWeaponAttribute(entry, value, weapon, unitDef)
	local reason, parameter = kindReason(entry, true)
	if not reason then
		reason, parameter = weaponReason(entry, weapon, unitDef)
	end
	if not reason then
		reason, parameter = valueReason(entry, value)
	end
	return wasAllowed(reason, parameter)
end

---Whether `SetUnitWeaponModifier` or `SetUnitDefWeaponModifier` would accept this multiplier.
---@param entry WeaponAttributeDefinition?
---@param multiplier any `nil` clears
---@param weapon integer|"explode"|"selfDestruct"|nil `nil` is every weapon
---@param unitDef table? checks that the weapon exists when given
---@return boolean ok
---@return string? reason
---@return "attribute"|"multiplier"|"weapon"? parameter
local function canSetUnitWeaponModifier(entry, multiplier, weapon, unitDef)
	local reason, parameter = kindReason(entry, true)
	if not reason then
		reason, parameter = weaponReason(entry, weapon, unitDef)
	end
	if not reason then
		reason, parameter = multiplierReason(entry, multiplier)
	end
	return wasAllowed(reason, parameter)
end

---Whether an attribute has any effect on a unitdef.
---@param entry UnitAttributeDefinition
---@param unitDef table
---@return boolean ok
---@return string? reason
local function affectsUnitDef(entry, unitDef)
	if (entry.mobileOnly and unitDef.isImmobile) or (entry.builderOnly and not unitDef.isBuilder) then
		return false, "has an inappropriate def (" .. unitDef.name .. ")"
	end
	return true
end

return {
	CanSetUnitAttribute = canSetUnitAttribute,
	CanSetUnitDefAttribute = canSetUnitDefAttribute,
	CanSetUnitModifier = canSetUnitModifier,
	CanSetUnitDefModifier = canSetUnitModifier,
	CanSetUnitWeaponAttribute = canSetUnitWeaponAttribute,
	CanSetUnitDefWeaponAttribute = canSetUnitWeaponAttribute,
	CanSetUnitWeaponModifier = canSetUnitWeaponModifier,
	CanSetUnitDefWeaponModifier = canSetUnitWeaponModifier,
	AffectsUnitDef = affectsUnitDef,
}
