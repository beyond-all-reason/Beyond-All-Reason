local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "Unit Script Attributes",
		desc    = "Sends customparam values to scripts at unit creation",
		author  = "efrec",
		version = "1.0",
		date    = "2026-06",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- after unit_script.lua
		enabled = true,
	}
end

local gameSpeed = Game.gameSpeed
local DEG2COBANGLE = COBSCALE / 360

-- Conversion functions for customParams

local function customNumber(def, key)
	local value = def.customParams[key] or def[key]
	return value ~= nil and tonumber(value) or nil
end

local function customFrames(def, key)
	local value = customNumber(def, key)
	return value and math.round(value * gameSpeed) or nil
end

local function customCobAngle(def, key)
	local value = customNumber(def, key)
	return value and value * DEG2COBANGLE or nil
end

-- Attribute definitions

---@class UnitScriptAttributeDefinition
---@field params string|string[]
---@field requires "any"|"all"|nil default := "all"
---@field method string
---@field numbered boolean|nil Whether to append the weapon number to the method name.
---@field process fun(self:UnitScriptAttributeDefinition, def:table):any

---@type UnitScriptAttributeDefinition[]
local unitAttributeDefinitions = {
	--
}

---@type UnitScriptAttributeDefinition[]
local weaponAttributeDefinitions = {
	{
		method   = "SetSweepfireTimeWeapon",
		numbered = true,
		params   = { "sweepfire_firetime", "sweepfire_reloadtime" },
		requires = "any",
		process  = function(self, def) return { customFrames(def, self.params[1]) or 0, customFrames(def, self.params[2]) or 0 } end,
	},
	{
		method   = "SetTurretSpeedWeapon",
		numbered = true,
		params   = { "turretspeedx", "turretspeedy" },
		process  = function(self, def) return { customCobAngle(def, self.params[1]) or 0, customCobAngle(def, self.params[2]) or 0 } end,
	},
	{
		method   = "SetTurretSpeedWeapon",
		numbered = true,
		params   = "turretspeed",
		process  = function(self, def) return { customCobAngle(def, self.params) or 0, customCobAngle(def, self.params) or 0 } end,
	},
}

-- Initialization and setup

local spCallCobScript = Spring.CallCOBScript
local callLUS = Spring.UnitScript.CallAsUnit
local callCOB = function(unitID, funcName, ...)
	spCallCobScript(unitID, funcName, 0, ...) -- Adaptor for COB to add the return count.
end
local function getUnitScriptCall(unitID)
	local lusEnv = Spring.UnitScript.GetScriptEnv(unitID)
	return lusEnv
		and function(unitID, funcName, ...)
			callLUS(unitID, lusEnv[funcName], ...) -- Hold `env` in a temporary closure.
		end
		or callCOB
end

local function hasAttribute(def, attribute)
	local customParams = def.customParams
	if type(def.params) ~= "table" then
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
	local method = attribute.method .. (attribute.numbered and weaponNum or "")
	if not out[method] then
		out[method] = attribute:process(weaponDef)
	end
end

local function getWeaponAttributes(weapons, out)
	for weaponNum, weapon in ipairs(weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef]
		for index, attribute in ipairs(weaponAttributeDefinitions) do
			getWeaponAttribute(weaponNum, weaponDef, attribute, out)
		end
	end
end

local unitScriptAttributes = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	local attributes = {}
	getUnitAttributes(unitDef.customParams, attributes)
	getWeaponAttributes(unitDef.weapons, attributes)
	if next(attributes) then
		unitScriptAttributes[unitDefID] = attributes
	end
end

-- Engine callins

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local attributes = unitScriptAttributes[unitDefID]
	if attributes then
		local call = getUnitScriptCall(unitID)
		for methodName, arguments in pairs(attributes) do
			if type(arguments) == "table" then
				call(unitID, methodName, unpack(arguments))
			else
				call(unitID, methodName, arguments)
			end
		end
	end
end
