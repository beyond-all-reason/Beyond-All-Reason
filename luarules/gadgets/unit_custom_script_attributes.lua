local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Script Attributes",
		desc    = "Sends customparam values to COB scripts at unit creation",
		author  = "efrec",
		version = "1.0",
		date    = "2026-06",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- try to complete init/creation early
		enabled = true,
	}
end

local debug = false

local spCallCobScript = Spring.CallCOBScript
local gameSpeed = Game.gameSpeed
local DEG2COBANGLE = COBSCALE / 360

-- Conversion functions for customParams

local function customNumber(def, key)
	local value = def.customParams[key] or def[key]
	return value ~= nil and tonumber(value) or nil
end

local function customFrames(def, key)
	local value = customNumber(def, key)
	return value and math.round(value * gameSpeed, 0) or nil
end

local function customAngle(def, key)
	local value = customNumber(def, key)
	return value and value * DEG2COBANGLE or nil
end

-- Attribute definitions

---@class UnitScriptAttributeDefinition
---@field params string|string[]
---@field requires "any"|"all"|nil default := "all"
---@field method string
---@field process fun(self:UnitScriptAttributeDefinition, def:table):any

---@type UnitScriptAttributeDefinition[]
local unitAttributeDefinitions = {
	--
}

---@type UnitScriptAttributeDefinition[]
local weaponAttributeDefinitions = {
	{
		method   = "SetSweepfireTimeWeapon",
		params   = { "sweepfire_firetime", "sweepfire_reloadtime" },
		requires = "any",
		process  = function(self, def) return { customFrames(def, self.params[1]) or 0, customFrames(def, self.params[2]) or 0 } end,
	},
	{
		method   = "SetTurretSpeedWeapon",
		params   = { "turretspeedx", "turretspeedy" },
		process  = function(self, def) return { customAngle(def, self.params[1]) or 0, customAngle(def, self.params[2]) or 0 } end,
	},
	{
		method   = "SetTurretSpeedWeapon",
		params   = "turretspeed",
		process  = function(self, def) return { customAngle(def, self.params) or 0, customAngle(def, self.params) or 0 } end,
	},
}

-- Initialization

local function usesCobUnitScript(unitDef)
	return (unitDef.scriptName or ""):find(".cob$") ~= nil
end

local function hasAttribute(def, attribute)
	local customParams = def.customParams
	if type(attribute.params) ~= "table" then
		return customParams[attribute.params] ~= nil
	else
		local hasParams = table[attribute.requires or "all"] -- table.all or table.any
		return hasParams(attribute.params, function(param) return customParams[param] ~= nil end)
	end
end

local function getUnitAttributes(unitDef, out)
	for index, attribute in ipairs(unitAttributeDefinitions) do
		if hasAttribute(unitDef, attribute) and not out[attribute.method] then
			out[attribute.method] = attribute:process(unitDef)
		end
	end
end

local function getWeaponAttribute(weaponNum, weaponDef, attribute, out)
	if not hasAttribute(weaponDef, attribute) then
		return
	end
	local method = attribute.method .. tostring(weaponNum)
	if not out[method] then
		out[method] = attribute:process(weaponDef)
	end
end

local function getWeaponAttributes(unitDef, out)
	for weaponNum, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		for index, attribute in ipairs(weaponAttributeDefinitions) do
			getWeaponAttribute(weaponNum, weaponDef, attribute, out)
		end
	end
end

local unitScriptAttributes = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if usesCobUnitScript(unitDef) then
		local attributes = {}
		getUnitAttributes(unitDef, attributes)
		getWeaponAttributes(unitDef, attributes)
		if next(attributes) then
			unitScriptAttributes[unitDefID] = attributes
		end
	end
end

-- Engine callins

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local attributes = unitScriptAttributes[unitDefID]
	if attributes then
		for methodName, arguments in pairs(attributes) do
			if type(arguments) == "table" then
				spCallCobScript(unitID, methodName, 0, unpack(arguments))
			else
				spCallCobScript(unitID, methodName, 0, arguments)
			end
		end
	end
end

-- Debug

if debug then
	for _, definitions in ipairs { unitAttributeDefinitions, weaponAttributeDefinitions } do
		for _, definition in ipairs(definitions) do
			local process = definition.process
			definition.process = function (self, def)
				Spring.Echo("Processing " .. definition.method .. " for " .. def.name)
				return process(self, def)
			end
		end
	end

	local __CallCobScript = spCallCobScript
	spCallCobScript = function(unitID, funcName, retArgs, ...)
		Spring.Echo(("Script attribute: %d, %s, %s"):format(unitID, funcName, table.concat({...}, ", ")))
		__CallCobScript(unitID, funcName, retArgs, ...)
	end
end
