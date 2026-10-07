-- unit_attributes.lua ---------------------------------------------------------

---@class UnitAttributeDefinition
---@field type "number"|"boolean"|"string"
---@field canBeNegative? boolean
---@field mobileOnly? boolean
---@field builderOnly? boolean
---@field multiplyOnly? boolean Its baseline value is always 1.0. Will drop any `set` operations.
---@field isUnitState? boolean Has no baseline value. Drops any `multiply` and any unitdef scope.

---@class WeaponAttributeDefinition
---@field type "number"
---@field perWeapon? true
---@field perExplosion? boolean Composes for both weapons and the death and self-destruct explosions.
---@field multiplyOnly? boolean Its baseline value is always 1.0. Will drop any `set` operations.

---@type table<string, UnitAttributeDefinition?>
local unitAttributes = {
	losRadius = { type = "number" },
	airLosRadius = { type = "number" },
	radarRadius = { type = "number" },
	sonarRadius = { type = "number" },
	seismicRadius = { type = "number" },
	jammerRadius = { type = "number" },
	sonarJamRadius = { type = "number" },
	health = { type = "number", isUnitState = true },
	maxHealth = { type = "number" },
	speed = { type = "number", mobileOnly = true },
	maxWantedSpeed = { type = "number", mobileOnly = true },
	turnRate = { type = "number", mobileOnly = true },
	maxAcc = { type = "number", mobileOnly = true },
	maxDec = { type = "number", mobileOnly = true },
	buildSpeed = { type = "number", builderOnly = true },
	metalCost = { type = "number" },
	energyCost = { type = "number" },
	buildTime = { type = "number" },
	mass = { type = "number" },
	stealth = { type = "boolean" },
	sonarStealth = { type = "boolean" },
	seismicSignature = { type = "number" },
	experience = { type = "number", isUnitState = true },
	cloaked = { type = "boolean", isUnitState = true },
	shieldMaxPower = { type = "number" },
}

---@type table<string, WeaponAttributeDefinition?>
local weaponAttributes = {
	maxWeaponRange = { type = "number" },
	reloadTime = { type = "number" },
	damage = { type = "number", multiplyOnly = true, perExplosion = true },
	-- The engine applies these as magnitudes relative to damage, so `damage` scales them, also.
	impulse = { type = "number", multiplyOnly = true, perExplosion = true },
	cratering = { type = "number", multiplyOnly = true, perExplosion = true },
}

-- Definition names are unique across unit and weapon attributes so can share one lookup table.
local definitions = {} ---@type table<string, UnitAttributeDefinition|WeaponAttributeDefinition|nil>
for attribute, entry in pairs(unitAttributes) do
	definitions[attribute] = entry
end
for attribute, entry in pairs(weaponAttributes) do
	if definitions[attribute] then
		error("Attribute is defined for both units and weapons: " .. attribute)
	end
	entry.perWeapon = true
	definitions[attribute] = entry
end

local WEAPON_ALL = 0 -- Packing index for non-specific weapon attributes scopes.
local WEAPON_DEATH = -1
local WEAPON_SELFD = -2

return {
	UnitAttributeDefinitions = unitAttributes,
	WeaponAttributeDefinitions = weaponAttributes,
	AttributeDefinitions = definitions,

	WEAPON_ALL = WEAPON_ALL,
	WEAPON_DEATH = WEAPON_DEATH,
	WEAPON_SELFD = WEAPON_SELFD,
}
