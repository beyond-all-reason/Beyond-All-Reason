-- unit_attributes.lua ---------------------------------------------------------
-- Attribute definitions are wanted values, not validation done in the controller.
-- Consumers may need to check against these before passing along unmanaged data.

---@class UnitAttributeDefinition
---@field type "number"|"boolean"|"string" Not checked by the attributes controller.
---@field nonNegative? boolean Not checked by the attributes controller.
---@field mobileOnly? boolean
---@field builderOnly? boolean
---@field unitOnly? boolean
---@field state? boolean Will drop any `multiply` operations.

---@type table<string, UnitAttributeDefinition>
local definitions = {
	losRadius = { type = "number", nonNegative = true },
	airLosRadius = { type = "number", nonNegative = true },
	radarRadius = { type = "number", nonNegative = true },
	sonarRadius = { type = "number", nonNegative = true },
	seismicRadius = { type = "number", nonNegative = true },
	jammerRadius = { type = "number", nonNegative = true },
	sonarJamRadius = { type = "number", nonNegative = true },
	health = { type = "number", unitOnly = true, state = true },
	maxHealth = { type = "number", nonNegative = true },
	speed = { type = "number", nonNegative = true, mobileOnly = true },
	turnRate = { type = "number", nonNegative = true, mobileOnly = true },
	maxAcc = { type = "number", nonNegative = true, mobileOnly = true },
	maxDec = { type = "number", nonNegative = true, mobileOnly = true },
	buildSpeed = { type = "number", nonNegative = true, builderOnly = true },
	metalCost = { type = "number", nonNegative = true },
	energyCost = { type = "number", nonNegative = true },
	buildTime = { type = "number", nonNegative = true },
	mass = { type = "number", nonNegative = true },
	stealth = { type = "boolean" },
	sonarStealth = { type = "boolean" },
	seismicSignature = { type = "number", nonNegative = true },
	tooltip = { type = "string" },
	maxWeaponRange = { type = "number", nonNegative = true },
	reloadTime = { type = "number", nonNegative = true },
	experience = { type = "number", nonNegative = true, unitOnly = true, state = true },
	cloaked = { type = "boolean", unitOnly = true, state = true },
}

return {
	Definitions = definitions,
}
