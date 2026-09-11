--------------------------------------------------------------------------------
-- common/unit_script_attributes.lua -------------------------------------------

local gameSpeed = Game.gameSpeed
local DEG2COBANGLE = COBSCALE / 360

local envType ---@type "cob"|"lus"

local function customNumber(def, key)
	local value = def.customParams[key] or def[key]
	return value ~= nil and tonumber(value) or nil
end

local function customTime(def, key)
	local value = customNumber(def, key)
	if not value then
		return
	elseif envType == "lus" then
		return value * gameSpeed
	else
		return math.round(value * gameSpeed, 0)
	end
end

local function customAngle(def, key)
	local value = customNumber(def, key)
	if not value then
		return
	elseif envType == "lus" then
		return math.rad(value)
	else
		return value * DEG2COBANGLE
	end
end

-- Attribute definitions -------------------------------------------------------

---@class UnitScriptAttributeDefinition
---@field params string|string[]
---@field requires "any"|"all"|nil default := "all"
---@field method string
---@field process fun(self:UnitScriptAttributeDefinition, def:table):number[]|number

---@type UnitScriptAttributeDefinition[]
local unitAttributeDefinitions = {
	--
}

---@type UnitScriptAttributeDefinition[]
local weaponAttributeDefinitions = {
	{
		method = "SetSweepfireTimeWeapon",
		params = { "sweepfire_firetime", "sweepfire_reloadtime" },
		requires = "any",
		process = function(self, def)
			return { customTime(def, self.params[1]) or 0, customTime(def, self.params[2]) or 0 }
		end,
	},
	{
		method = "SetTurretSpeedWeapon",
		params = { "turretspeedx", "turretspeedy" },
		process = function(self, def)
			return { customAngle(def, self.params[1]) or 0, customAngle(def, self.params[2]) or 0 }
		end,
	},
	{
		method = "SetTurretSpeedWeapon",
		params = "turretspeed",
		process = function(self, def)
			return { customAngle(def, self.params) or 0, customAngle(def, self.params) or 0 }
		end,
	},
}

-- Gathering -------------------------------------------------------------------

local function usesCobUnitScript(unitDef)
	return (unitDef.scriptName or ""):find("%.cob$") ~= nil
end

local function usesLuaUnitScript(unitDef)
	return (unitDef.scriptName or ""):find("%.lua$") ~= nil
end

local function hasAttribute(def, attribute)
	local customParams = def.customParams
	if type(attribute.params) ~= "table" then
		return customParams[attribute.params] ~= nil
	else
		local hasParams = table[attribute.requires or "all"] -- table.all or table.any
		return hasParams(attribute.params, function(param)
			return customParams[param] ~= nil
		end)
	end
end

local function getUnitAttributes(unitDef, out)
	for _, attribute in ipairs(unitAttributeDefinitions) do
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
		for _, attribute in ipairs(weaponAttributeDefinitions) do
			getWeaponAttribute(weaponNum, weaponDef, attribute, out)
		end
	end
end

-- Module exports --------------------------------------------------------------

local unitScriptAttributes = {}
local unitScriptIsCob = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	envType = nil
	if usesCobUnitScript(unitDef) then
		envType = "cob"
		unitScriptIsCob[unitDefID] = true
	elseif usesLuaUnitScript(unitDef) then
		envType = "lus"
	end
	if envType then
		local attributes = {}
		getUnitAttributes(unitDef, attributes)
		getWeaponAttributes(unitDef, attributes)
		if next(attributes) then
			unitScriptAttributes[unitDefID] = attributes
		end
	end
end

return {
	Get = function(unitDefID)
		return unitScriptAttributes[unitDefID]
	end,
	IsCob = function(unitDefID)
		return unitScriptIsCob[unitDefID] == true
	end,
}
