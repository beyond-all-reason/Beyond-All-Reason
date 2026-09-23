-- unit_attributes.lua ---------------------------------------------------------

---@class UnitAttributeDefinition
---@field type "number"|"boolean"|"string"
---@field canBeNegative? boolean
---@field mobileOnly? boolean
---@field builderOnly? boolean
---@field multiplyOnly? boolean Its baseline value is always 1.0. Will drop any `set` operations.
---@field isUnitState? boolean Has no baseline value. Drops any `multiply` and any unitdef scope.
---@field perWeapon? boolean Composes to one value per weapon. Written with the weapon functions.

---@type table<string, UnitAttributeDefinition>
local definitions = {
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
	maxWeaponRange = { type = "number", perWeapon = true },
	reloadTime = { type = "number", perWeapon = true },
	experience = { type = "number", isUnitState = true },
	cloaked = { type = "boolean", isUnitState = true },
	shieldMaxPower = { type = "number" },
	damage = { type = "number", multiplyOnly = true, perWeapon = true },
}

return {
	Definitions = definitions,
}
