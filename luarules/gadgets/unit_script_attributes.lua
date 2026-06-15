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

-- Conversion functions for customParams

local gameSpeed = Game.gameSpeed

-- COB cannot handle these conversions itself due to integer precision issues. LUS is fine.
local DEG2COBANGLE = COBSCALE / 360
local SEC2COBTIME = 1000

local function customCobTime(text)
	return tonumber(text) * SEC2COBTIME
end

local function customCobFrames(text)
	return math.round(customCobTime(text) * gameSpeed)
end

local function customArray(text)
	return table.map(tostring(text):split("%s"), function(v, k) return tonumber(v), k end)
end

local function customArrayToCobAngle(text)
	local array = customArray(text)
	if array then
		return table.map(array, function (v, k) return v * DEG2COBANGLE, k end)
	end
end

-- Configured attributes and script callins

local unitCustomParams = {
	--
}

local weaponCustomParams = {
	sweepfire_firetime   = { method = "SetSweepfireFireTime", numbered = true, convert = customCobFrames },
	sweepfire_reloadtime = { method = "SetSweepfireReloadTime", numbered = true, convert = customCobFrames },
	turretspeeds         = { method = "SetWeaponTurretSpeed", numbered = true, convert = customArrayToCobAngle }, -- TODO: These customparams have spent years in retirement.
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

local function getUnitAttributes(customParams, attributes)
	for key, attribute in pairs(unitCustomParams) do
		if customParams[key] ~= nil then
			if attribute.convert then
				attributes[attribute.method] = attribute.convert(customParams[key])
			else
				attributes[attribute.method] = customParams[key]
			end
		end
	end
end

local function getWeaponAttributes(weapons, attributes)
	for weaponNum, weapon in ipairs(weapons) do
		local customParams = WeaponDefs[weapon.weaponDef].customParams
		for key, attribute in pairs(weaponCustomParams) do
			if customParams[key] ~= nil then
				local method = attribute.method .. (attribute.numbered and weaponNum or "")
				if attribute.convert then
					attributes[method] = attribute.convert(customParams[key])
				else
					attributes[method] = customParams[key]
				end
			end
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
