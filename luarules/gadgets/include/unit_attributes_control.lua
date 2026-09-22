-- unit_attributes_control.lua -------------------------------------------------
-- Applies unitdef and unit attributes written by named sources, which stack.
--------------------------------------------------------------------------------

-- Attribute factors come in two types which are handled differently per-scope:
-- 1. `set`s take the narrowest scope: unit > unitdef-and-team > unitdef
-- 2. `multiply`s are unordered so each apply: unit x unitdef-and-team x unitdef
-- The full result, for a numeric type, is `(override or base) x (multipliers)`.
--
-- An `isUnitState` attribute is not composed. It writes straight to the unit,
-- keeps no factor (willfix), cannot be cleared (willfix), and has unit scope.
--
-- Each named "source" keeps only one factor per-scope per-entry in that scope.
-- A new value written to the same source and scope overrides any predecessors,
-- regardless of type, so e.g. a source may replace a `multiply` with a `set`.
-- Clearing a source/factor requires setting it back to `nil`, likely followed
-- by waiting for the next attributes update pass on the following g:GameFrame.

local definitions = VFS.Include("luarules/gadgets/include/unit_attributes.lua").Definitions

local math_max = math.max
local math_round = math.round

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local spSetUnitHealth = Spring.SetUnitHealth
local spSetUnitMaxHealth = Spring.SetUnitMaxHealth
local spSetUnitSensorRadius = Spring.SetUnitSensorRadius
local spSetUnitMaxRange = Spring.SetUnitMaxRange
local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spSetUnitWeaponDamages = Spring.SetUnitWeaponDamages
local spSetUnitBuildSpeed = Spring.SetUnitBuildSpeed
local spSetUnitCosts = Spring.SetUnitCosts
local spSetUnitMass = Spring.SetUnitMass
local spSetUnitStealth = Spring.SetUnitStealth
local spSetUnitSonarStealth = Spring.SetUnitSonarStealth
local spSetUnitSeismicSignature = Spring.SetUnitSeismicSignature
local spSetUnitTooltip = Spring.SetUnitTooltip
local spSetUnitExperience = Spring.SetUnitExperience
local spSetUnitCloak = Spring.SetUnitCloak
local spMoveCtrlIsEnabled = Spring.MoveCtrl.IsEnabled
local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData
local spSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData
local spSetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData

local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local unitScript = Spring.UnitScript or {}
local spCallLuaScript = unitScript.CallAsUnit

local gameSpeed = Game.gameSpeed

---@class AttributeFactor
---@field kind "set"|"multiply"
---@field value number|boolean|string
---@field sequence integer tiebreaker, highest wins

local SOURCE_DEFAULT = "default"

local unitdefFactors = {} ---@type table<UnitDefID, table<string, table<string, AttributeFactor>?>?>
local unitdefTeamFactors = {} ---@type table<UnitDefID, table<TeamID, table<string, table<string, AttributeFactor>?>?>?>
local unitFactors = {} ---@type table<UnitID, table<string, table<string, AttributeFactor>?>?>
local appliedValues = {} ---@type table<UnitID, table<string, any>?>
local dirty = {} ---@type table<UnitID, table<string, true?>?>
local baseValues = {} ---@type table<UnitDefID, table<string, any>?>
local baseWeapons = {} ---@type table<UnitDefID, WeaponBaseline[]?>
local baseDamages = {} ---@type table<UnitDefID, table<integer, table<integer, number>>?>
local sequence = 0

-- Module internals ------------------------------------------------------------

local function warn(attribute, reason)
	Spring.Log("UnitAttributes", LOG.WARNING, "Attribute " .. reason .. ": " .. tostring(attribute))
end

---The engine resolves effects in whole frames, so cast rounded values to exact ones.
local function toFrameTime(seconds)
	return math_max(math_round(seconds * gameSpeed, 0), 1) / gameSpeed
end

local function getUnitScriptEnv(unitID)
	local getScriptEnv = unitScript.GetScriptEnv
	return getScriptEnv and getScriptEnv(unitID)
end

local function callUnitScript(unitID, luaEnv, methodName, ...)
	if luaEnv then
		if luaEnv[methodName] then
			spCallLuaScript(unitID, luaEnv[methodName], ...)
		end
	elseif spGetCOBScriptID(unitID, methodName) then
		spCallCOBScript(unitID, methodName, 0, ...)
	end
end

local reloadMethodByWeapon = setmetatable({}, {
	__index = function(self, weaponNum)
		local methodName = "SetReloadTime" .. weaponNum
		self[weaponNum] = methodName
		return methodName
	end,
})

local applyOnExperience ---@type fun(unitID: UnitID)

local builderSpeedsByDef = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	if not unitDef.isBuilder then
		return false, unitDefID
	end
	local builderSpeeds = {
		repair = unitDef.repairSpeed,
		reclaim = unitDef.reclaimSpeed,
		resurrect = unitDef.resurrectSpeed,
		capture = unitDef.captureSpeed,
		terraform = unitDef.terraformSpeed,
	}
	return builderSpeeds, unitDefID
end) ---@as table<UnitDefID, false|BuilderSpeeds>

local moveTypeSetterByDef = table.map(UnitDefs, function(unitDef, unitDefID)
	local setter = false ---@as false|fun(unitID:UnitID, key:any, value:any):integer
	---@cast unitDef table what in the hell is wrong with emmylua. why, how, what?
	if unitDef.isHoveringAirUnit then
		setter = spSetGunshipMoveTypeData
	elseif unitDef.isAirUnit then
		setter = spSetAirMoveTypeData
	elseif not unitDef.isImmobile then
		setter = spSetGroundMoveTypeData
	end
	return setter, unitDefID
end) ---@as table<UnitDefID, false|fun(unitID: UnitID, key: any, value: any): integer>

local hasCustomEngageRange = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	local engageRange = tonumber(unitDef.customParams.maxrange) or 0
	return (engageRange ~= 0 and engageRange < (unitDef.maxWeaponRange or 0))
		or unitDef.customParams.rangexpscale ~= nil,
		unitDefID
end) ---@as table<UnitDefID, boolean?>

local function setMoveTypeValue(unitID, key, value)
	local setter = moveTypeSetterByDef[spGetUnitDefID(unitID)]
	if not setter or spMoveCtrlIsEnabled(unitID) then
		return false
	end
	-- StrafeAirMoveType has no turnRate and overwrites its wanted speed every frame, and a skipped
	-- write still counts, or the flush retries one this move type is never going to take.
	if setter == spSetAirMoveTypeData and (key == "turnRate" or key == "maxWantedSpeed") then
		return true
	end
	setter(unitID, key, value)
	return true
end

local function setMoveTypeData(unitID, data)
	local setter = moveTypeSetterByDef[spGetUnitDefID(unitID)]
	if not setter or spMoveCtrlIsEnabled(unitID) then
		return false
	end
	setter(unitID, data)
	return true
end

local function getMoveTypeValueSetter(key)
	return function(unitID, value)
		return setMoveTypeValue(unitID, key, value)
	end
end

local function getSensorRadiusSetter(sensorType)
	return function(unitID, value)
		spSetUnitSensorRadius(unitID, sensorType, value)
	end
end

local function getUnitCostSetter(costKey)
	local costs = {}
	return function(unitID, value)
		costs[costKey] = value
		spSetUnitCosts(unitID, costs)
	end
end

---@type table<string, string?>
local baseFieldByAttribute = {
	losRadius = "losRadius",
	airLosRadius = "airLosRadius",
	radarRadius = "radarRadius",
	sonarRadius = "sonarRadius",
	seismicRadius = "seismicRadius",
	jammerRadius = "jammerRadius",
	sonarJamRadius = "sonarJamRadius",
	maxHealth = "health",
	speed = "speed",
	maxWantedSpeed = "speed",
	turnRate = "turnRate",
	maxAcc = "maxAcc",
	maxDec = "maxDec",
	maxWeaponRange = "maxWeaponRange",
	buildSpeed = "buildSpeed",
	metalCost = "metalCost",
	energyCost = "energyCost",
	buildTime = "buildTime",
	mass = "mass",
	stealth = "stealth",
	sonarStealth = "sonarStealth",
	seismicSignature = "seismicSignature",
	tooltip = "tooltip",
}

local nominalReloadByDef = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	local weapon = unitDef.weapons[1]
	local weaponDef = weapon and WeaponDefs[weapon.weaponDef]
	return weaponDef and weaponDef.reload or false, unitDefID
end) ---@as table<UnitDefID, number|false>

local shieldPowerByDef = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	for _, weapon in ipairs(unitDef.weapons) do
		local weaponDef = WeaponDefs[weapon.weaponDef] ---@as table?
		if weaponDef and (weaponDef.shieldPower or 0) > 0 then
			return weaponDef.shieldPower, unitDefID
		end
	end
	return false, unitDefID
end) ---@as table<UnitDefID, number|false>

---@type table<string, table<UnitDefID, (false|number)?>?>
local prebuiltBaseByAttribute = {
	reloadTime = nominalReloadByDef,
	shieldMaxPower = shieldPowerByDef,
}

local function getBaseline(unitDefID, attribute)
	local values = baseValues[unitDefID]
	if not values then
		values = {}
		baseValues[unitDefID] = values
	end
	local value = values[attribute]
	if value == nil then
		local field = baseFieldByAttribute[attribute]
		local prebuilt = prebuiltBaseByAttribute[attribute]
		if field then
			value = UnitDefs[unitDefID][field]
			values[attribute] = value
		elseif prebuilt then
			value = prebuilt[unitDefID] or nil
			values[attribute] = value
		elseif definitions[attribute].multiplyOnly then
			value = 1
			values[attribute] = value
		end
	end
	return value
end

---@class WeaponBaseline
---@field range number
---@field reload number

---@return WeaponBaseline[]
local function getWeaponBaselines(unitDefID)
	local weapons = baseWeapons[unitDefID]
	if not weapons then
		weapons = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			weapons[index] = {
				range = weaponDef and weaponDef.range or 0,
				reload = weaponDef and weaponDef.reload or 0,
			}
		end
		baseWeapons[unitDefID] = weapons
	end
	return weapons
end

local function setMaxWeaponRange(unitID, value)
	local unitDefID = spGetUnitDefID(unitID)
	if not hasCustomEngageRange[unitDefID] then
		spSetUnitMaxRange(unitID, value)
	end

	local baseline = getBaseline(unitDefID, "maxWeaponRange")
	if not baseline or baseline <= 0 then
		return
	end

	local scale = value / baseline
	for index, weapon in ipairs(getWeaponBaselines(unitDefID)) do
		spSetUnitWeaponState(unitID, index, "range", weapon.range * scale)
	end
end

---Gets the damage by armor class per weapon, excluding non-damaging fakes.
---@return table<integer, table<integer, number>>
local function getWeaponDamages(unitDefID)
	local weapons = baseDamages[unitDefID]
	if not weapons then
		weapons = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			local damages = weaponDef and weaponDef.damages
			if damages then
				local armorClasses, isArmed = {}, false
				for armorClass, damage in pairs(damages) do
					-- Drops non-scaled weapondef properties, e.g.: impulse, cratering, ...
					if type(armorClass) == "number" then
						armorClasses[armorClass] = damage
						isArmed = isArmed or damage ~= 0
					end
				end
				if isArmed then
					weapons[index] = armorClasses
				end
			end
		end
		baseDamages[unitDefID] = weapons
	end
	return weapons
end

local damagesArray = table.new(#Game.armorTypes, 1) ---@as WeaponDamages reusable scratch table

local function setDamage(unitID, scale)
	for weaponNum, damages in pairs(getWeaponDamages(spGetUnitDefID(unitID))) do
		for armorIndex, damage in pairs(damages) do
			damagesArray[armorIndex] = damage * scale
		end
		spSetUnitWeaponDamages(unitID, weaponNum, damagesArray)
	end
end

local function setReloadTime(unitID, value)
	local unitDefID = spGetUnitDefID(unitID)
	local baseline = getBaseline(unitDefID, "reloadTime")
	if not baseline or baseline <= 0 then
		return
	end

	local scale = value / baseline
	local gameFrame = spGetGameFrame()
	local luaEnv = getUnitScriptEnv(unitID)
	local reloadMax = 0.0

	for weaponNum, weapon in ipairs(getWeaponBaselines(unitDefID)) do
		local previous = spGetUnitWeaponState(unitID, weaponNum, "reloadTime")
		local reloadTime = toFrameTime(weapon.reload * scale)
		spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadTime)

		local reloadState = spGetUnitWeaponState(unitID, weaponNum, "reloadState")
		if previous and previous > 0 and reloadState and reloadState > gameFrame then
			local framesLeft = (reloadState - gameFrame) * reloadTime / previous
			spSetUnitWeaponState(unitID, weaponNum, "reloadState", gameFrame + framesLeft)
		end

		callUnitScript(unitID, luaEnv, reloadMethodByWeapon[weaponNum], reloadTime * 1000)
		reloadMax = math_max(reloadMax, reloadTime)
	end

	callUnitScript(unitID, luaEnv, "SetMaxReloadTime", reloadMax * 1000)
end

local function setBuildSpeed(unitID, value)
	local unitDefID = spGetUnitDefID(unitID)
	local speeds = builderSpeedsByDef[unitDefID]
	local baseline = getBaseline(unitDefID, "buildSpeed")
	if not speeds or not baseline or baseline <= 0 then
		spSetUnitBuildSpeed(unitID, value)
		return
	end

	local scale = value / baseline
	spSetUnitBuildSpeed(
		unitID,
		value,
		speeds.repair * scale,
		speeds.reclaim * scale,
		speeds.resurrect * scale,
		speeds.capture * scale,
		speeds.terraform * scale
	)
end

local function setMaxHealth(unitID, value)
	local health, maxHealth = spGetUnitHealth(unitID)
	spSetUnitMaxHealth(unitID, value)
	if health and maxHealth and maxHealth > 0 then
		spSetUnitHealth(unitID, health * value / maxHealth)
	end
end

local speedData = {}

-- See MobileCAI. The maxWantedSpeed constantly resets so changing it will break formation movement.
local function setMaxSpeed(unitID, value)
	local applied = appliedValues[unitID]
	if applied and applied.maxWantedSpeed ~= nil then
		speedData.maxSpeed = value
		speedData.maxWantedSpeed = nil
		return setMoveTypeData(unitID, speedData)
	end

	local moveTypeData = spGetUnitMoveTypeData(unitID)
	local wanted = moveTypeData and moveTypeData.maxWantedSpeed
	local current = moveTypeData and moveTypeData.maxSpeed

	speedData.maxSpeed = value
	if wanted ~= current then
		speedData.maxWantedSpeed = nil
	else
		speedData.maxWantedSpeed = value
	end
	return setMoveTypeData(unitID, speedData)
end

---Each "apply" writes one attribute to the engine.
---
---A `false` return means the write was blocked or declined, and the attribute stays marked.
---Marked attributes are retried on a later frame, so (eg) MoveCtrl can release a unit properly.
---@alias UnitAttributeApply fun(unitID: UnitID, value: any): boolean?

---@type table<string, UnitAttributeApply>
local applyUnitAttribute = {
	losRadius = getSensorRadiusSetter("los"),
	airLosRadius = getSensorRadiusSetter("airLos"),
	radarRadius = getSensorRadiusSetter("radar"),
	sonarRadius = getSensorRadiusSetter("sonar"),
	seismicRadius = getSensorRadiusSetter("seismic"),
	jammerRadius = getSensorRadiusSetter("radarJammer"),
	sonarJamRadius = getSensorRadiusSetter("sonarJammer"),
	health = spSetUnitHealth,
	maxHealth = setMaxHealth,
	speed = setMaxSpeed,
	maxWantedSpeed = getMoveTypeValueSetter("maxWantedSpeed"),
	turnRate = getMoveTypeValueSetter("turnRate"),
	maxAcc = getMoveTypeValueSetter("accRate"),
	maxDec = getMoveTypeValueSetter("decRate"),
	buildSpeed = setBuildSpeed,
	metalCost = getUnitCostSetter("metalCost"),
	energyCost = getUnitCostSetter("energyCost"),
	buildTime = getUnitCostSetter("buildTime"),
	mass = spSetUnitMass,
	stealth = spSetUnitStealth,
	sonarStealth = spSetUnitSonarStealth,
	seismicSignature = spSetUnitSeismicSignature,
	tooltip = spSetUnitTooltip,

	maxWeaponRange = setMaxWeaponRange,
	reloadTime = setReloadTime,
	damage = setDamage,

	experience = function(unitID, value)
		spSetUnitExperience(unitID, value)
		applyOnExperience(unitID)
	end,
	cloaked = spSetUnitCloak,

	shieldMaxPower = function(unitID, value)
		GG.Shields.SetUnitShieldMaxPower(unitID, value)
	end,
}

local getUnitDefFactors, getUnitFactors ---@type function, function
do
	local function getChild(root, key, create)
		local child = root[key]
		if child == nil and create then
			child = {}
			root[key] = child
		end
		return child
	end

	getUnitDefFactors = function(unitDefID, teamID, attribute, create)
		if teamID == nil then
			local attributes = getChild(unitdefFactors, unitDefID, create)
			return attributes and getChild(attributes, attribute, create)
		end
		local teams = getChild(unitdefTeamFactors, unitDefID, create)
		local attributes = teams and getChild(teams, teamID, create)
		return attributes and getChild(attributes, attribute, create)
	end

	getUnitFactors = function(unitID, attribute, create)
		local attributes = getChild(unitFactors, unitID, create)
		return attributes and getChild(attributes, attribute, create)
	end
end

---@type function, function
local pruneUnitFactors, pruneUnitDefFactors
do
	local function prune(parent, key)
		local child = parent[key]
		if child == nil or next(child) ~= nil then
			return false
		end
		parent[key] = nil
		return true -- child was dropped, so the parent may be able to prune
	end

	pruneUnitFactors = function(unitID, attribute)
		local attributes = unitFactors[unitID]
		if attributes and prune(attributes, attribute) then
			prune(unitFactors, unitID)
		end
	end

	pruneUnitDefFactors = function(unitDefID, teamID, attribute)
		if teamID == nil then
			local attributes = unitdefFactors[unitDefID]
			if attributes and prune(attributes, attribute) then
				prune(unitdefFactors, unitDefID)
			end
			return
		end
		local teams = unitdefTeamFactors[unitDefID]
		local attributes = teams and teams[teamID]
		if attributes and prune(attributes, attribute) and prune(teams, teamID) then
			prune(unitdefTeamFactors, unitDefID)
		end
	end
end

---@return boolean changed `false` only when the composed value _cannot_ have changed
local function record(factors, source, kind, value)
	local factor = factors[source]
	if value == nil then
		factors[source] = nil
		return factor ~= nil
	end

	sequence = sequence + 1
	if not factor then
		factors[source] = { kind = kind, value = value, sequence = sequence }
		return true
	end

	-- A repeated multiply cannot change the final value. A repeated set can, via the tiebreak.
	local unchanged = kind == "multiply" and kind == factor.kind and value == factor.value

	factor.kind = kind
	factor.value = value
	factor.sequence = sequence
	return not unchanged
end

local function resolveSet(factors)
	local value, sequence
	if factors then
		for _, factor in pairs(factors) do
			if factor.kind == "set" and (sequence == nil or factor.sequence > sequence) then
				value, sequence = factor.value, factor.sequence
			end
		end
	end
	return value, sequence
end

local function applyMult(value, factors)
	if factors then
		for _, factor in pairs(factors) do
			if factor.kind == "multiply" then
				value = value * factor.value
			end
		end
	end
	return value
end

local function composeValue(unitID, unitDefID, teamID, attribute, baseline)
	local unitdefAttributes = unitdefFactors[unitDefID]
	local fromUnitDef = unitdefAttributes and unitdefAttributes[attribute]

	local teams = unitdefTeamFactors[unitDefID]
	local teamdefAttributes = teams and teams[teamID]
	local fromTeam = teamdefAttributes and teamdefAttributes[attribute]

	local unitAttributes = unitFactors[unitID]
	local fromUnit = unitAttributes and unitAttributes[attribute]

	local value, sequence = resolveSet(fromUnit)
	if sequence == nil then
		value, sequence = resolveSet(fromTeam)
	end
	if sequence == nil then
		value, sequence = resolveSet(fromUnitDef)
	end
	if sequence == nil then
		value = baseline
	end

	if type(value) == "number" then
		value = applyMult(value, fromUnitDef)
		value = applyMult(value, fromTeam)
		value = applyMult(value, fromUnit)
	end

	return value
end

---@type function, function
local addToPool, markUnitDirty
do
	-- Zero-allocation is not possible in this design but we can get close.
	local attributeSetPool = {} ---@type table<integer, table<string, true?>>
	local attributeSetCount = 0

	addToPool = function(attributes)
		attributeSetCount = attributeSetCount + 1
		attributeSetPool[attributeSetCount] = attributes
	end

	---@param unitID UnitID
	markUnitDirty = function(unitID, attribute)
		local attributes = dirty[unitID]
		if not attributes then
			if attributeSetCount > 0 then
				attributes = attributeSetPool[attributeSetCount]
				attributeSetPool[attributeSetCount] = nil
				attributeSetCount = attributeSetCount - 1
			else
				attributes = {}
			end
			dirty[unitID] = attributes
		end
		attributes[attribute] = true
	end
end

local function markUnitDefDirty(unitDefID, teamID, attribute)
	if teamID then
		for _, unitID in ipairs(spGetTeamUnitsByDefs(teamID, unitDefID)) do
			markUnitDirty(unitID, attribute)
		end
		return
	end

	for _, team in ipairs(spGetTeamList()) do
		for _, unitID in ipairs(spGetTeamUnitsByDefs(team, unitDefID)) do
			markUnitDirty(unitID, attribute)
		end
	end
end

---@return table<string, any>? applied # A table with the unit's applied values
local function setApplied(unitID, attribute, value)
	local applied = appliedValues[unitID]
	if value == nil then
		if applied then
			applied[attribute] = nil
			if next(applied) == nil then
				appliedValues[unitID] = nil
				return
			end
		end
		return applied
	end
	if not applied then
		applied = {}
		appliedValues[unitID] = applied
	end
	applied[attribute] = value
	return applied
end

local function checkUnitDefAttribute(entry, attribute, kind, value, unitDefID)
	if not entry then
		warn(attribute, "not found")
		return
	elseif entry.multiplyOnly and kind == "set" and value ~= nil then
		warn(attribute, "takes no set value")
		return
	elseif entry.unitOnly or entry.isUnitState then
		warn(attribute, "takes no unitdef scope")
		return
	elseif
		(entry.mobileOnly and not moveTypeSetterByDef[unitDefID])
		or (entry.builderOnly and not builderSpeedsByDef[unitDefID])
	then
		return
	end
	return true
end

local function checkUnitAttribute(entry, attribute, kind, value)
	if not entry then
		warn(attribute, "not found")
		return
	elseif entry.isUnitState then
		if kind ~= "set" then
			warn(attribute, "keeps no factors")
			return
		end
		return true
	elseif entry.multiplyOnly and kind == "set" and value ~= nil then
		warn(attribute, "takes no set value")
		return
	end
	return true
end

local function recordUnitDefAttribute(unitDefID, attribute, value, source, kind, teamID)
	local entry = definitions[attribute]
	if not checkUnitDefAttribute(entry, attribute, kind, value, unitDefID) then
		return
	end

	local factors = getUnitDefFactors(unitDefID, teamID, attribute, value ~= nil)
	if not factors then
		return
	end

	if record(factors, source or SOURCE_DEFAULT, kind, value) then
		markUnitDefDirty(unitDefID, teamID, attribute)
	end
	if value == nil then
		pruneUnitDefFactors(unitDefID, teamID, attribute)
	end
end

local function recordUnitAttribute(unitID, attribute, value, source, kind)
	local entry = definitions[attribute]
	if not checkUnitAttribute(entry, attribute, kind, value) then
		return
	end

	if kind == "set" and value ~= nil then
		applyUnitAttribute[attribute](unitID, value)
		if entry.isUnitState then
			return
		end
	end

	local attributes = unitFactors[unitID]
	local factors = attributes and attributes[attribute]
	if not factors then
		if value == nil then
			return
		end
		if entry.mobileOnly or entry.builderOnly then
			-- Tolerate without warnings for now:
			local unitDefID = spGetUnitDefID(unitID)
			if entry.mobileOnly and not moveTypeSetterByDef[unitDefID] then
				return
			end
			if entry.builderOnly and not builderSpeedsByDef[unitDefID] then
				return
			end
		end
		factors = getUnitFactors(unitID, attribute, true)
	end

	if record(factors, source or SOURCE_DEFAULT, kind, value) then
		markUnitDirty(unitID, attribute)
	end
	if value == nil then
		pruneUnitFactors(unitID, attribute)
	end
end

-- Module functions ------------------------------------------------------------

---Overrides an attribute on a unitdef until the same source clears it.
---@param unitDefID UnitDefID
---@param attribute string
---@param value number|boolean|string|nil # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefAttribute(unitDefID, attribute, value, source, teamID)
	recordUnitDefAttribute(unitDefID, attribute, value, source, "set", teamID)
end

---Overrides an attribute on one unit until the same source clears it.
---@param unitID UnitID
---@param attribute string
---@param value number|boolean|string|nil # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
local function setUnitAttribute(unitID, attribute, value, source)
	recordUnitAttribute(unitID, attribute, value, source, "set")
end

---Scales an attribute across a unitdef, or across a unitdef on one team, until the same source clears it.
---@param unitDefID UnitDefID
---@param attribute string
---@param multiplier number? # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefModifier(unitDefID, attribute, multiplier, source, teamID)
	recordUnitDefAttribute(unitDefID, attribute, multiplier, source, "multiply", teamID)
end

---Scales an attribute on one unit until the same source clears it.
---@param unitID UnitID
---@param attribute string
---@param multiplier number? # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
local function setUnitModifier(unitID, attribute, multiplier, source)
	recordUnitAttribute(unitID, attribute, multiplier, source, "multiply")
end

---Reads what a unit's attribute composes to now, or its unitdef value when no source is on it.
---@param unitID UnitID
---@param attribute string
---@return number|boolean|string|nil value # The resulting value. Often redundant to a more simple callout/getter.
local function getUnitAttributeValue(unitID, attribute)
	local applied = appliedValues[unitID]
	local value = applied and applied[attribute]
	if value ~= nil then
		return value
	end

	local entry = definitions[attribute]
	if not entry then
		warn(attribute, "not found")
		return
	elseif entry.isUnitState then
		return -- Ask the engine. The module writes state but cannot track it.
	end
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end
	return getBaseline(unitDefID, attribute)
end

-- Engine callin events --------------------------------------------------------

---@param unitID UnitID
---@param unitDefID UnitDefID
local function applyOnCreated(unitID, unitDefID)
	local attributes = unitdefFactors[unitDefID]
	if attributes then
		for attribute in pairs(attributes) do
			markUnitDirty(unitID, attribute)
		end
	end

	local teams = unitdefTeamFactors[unitDefID]
	local teamAttributes = teams and teams[spGetUnitTeam(unitID)] ---@type table?
	if teamAttributes then
		for attribute in pairs(teamAttributes) do
			markUnitDirty(unitID, attribute)
		end
	end
end

---@param unitID UnitID
function applyOnExperience(unitID)
	local applied = appliedValues[unitID]
	if applied and applied.maxHealth ~= nil then
		setApplied(unitID, "maxHealth", nil) -- `CUnit::AddExperience` recomputes `maxHealth`
		markUnitDirty(unitID, "maxHealth") -- so refresh
	end
end

---@param unitID UnitID
local function applyOnDestroyed(unitID)
	unitFactors[unitID] = nil
	appliedValues[unitID] = nil
	dirty[unitID] = nil
end

---@param unitID UnitID
---@param unitDefID UnitDefID
---@param newTeamID TeamID
---@param oldTeamID TeamID
local function applyOnGiven(unitID, unitDefID, newTeamID, oldTeamID)
	local teams = unitdefTeamFactors[unitDefID]
	if not teams then
		return
	end
	local newAttributes = teams[newTeamID]
	if newAttributes then
		for attribute in pairs(newAttributes) do
			markUnitDirty(unitID, attribute)
		end
	end

	local oldAttributes = teams[oldTeamID]
	if oldAttributes then
		for attribute in pairs(oldAttributes) do
			markUnitDirty(unitID, attribute)
		end
	end
end

---@param frame integer
local function updateAll(frame)
	if next(dirty) == nil then
		return
	end

	for unitID, attributes in pairs(dirty) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			local teamID = spGetUnitTeam(unitID)
			local applied = appliedValues[unitID]
			for attribute in pairs(attributes) do
				local baseline = getBaseline(unitDefID, attribute)
				local value = composeValue(unitID, unitDefID, teamID, attribute, baseline)
				local previous = applied and applied[attribute]
				if previous == nil then
					previous = baseline
				end
				-- MoveCtrl prevents updating the unit's moveTypeData so keep the attribute dirty.
				if value == previous or applyUnitAttribute[attribute](unitID, value) ~= false then
					if value == baseline then
						applied = setApplied(unitID, attribute, nil)
					else
						applied = setApplied(unitID, attribute, value)
					end
					attributes[attribute] = nil
				end
			end
		else
			for attribute in pairs(attributes) do
				attributes[attribute] = nil
			end
		end

		if next(attributes) == nil then
			dirty[unitID] = nil
			addToPool(attributes)
		end
	end
end

local function clearAll()
	for unitID, attributes in pairs(appliedValues) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			for attribute in pairs(attributes) do
				local baseline = getBaseline(unitDefID, attribute)
				if baseline ~= nil then
					applyUnitAttribute[attribute](unitID, baseline)
				end
			end
		end
	end

	unitdefFactors = {}
	unitdefTeamFactors = {}
	unitFactors = {}
	appliedValues = {}
	dirty = {}
end

-- Module export ---------------------------------------------------------------

return {
	Definitions = definitions,

	SetUnitDefAttribute = setUnitDefAttribute,
	SetUnitAttribute = setUnitAttribute,
	SetUnitDefModifier = setUnitDefModifier,
	SetUnitModifier = setUnitModifier,
	GetUnitAttributeValue = getUnitAttributeValue,

	ApplyOnCreated = applyOnCreated,
	ApplyOnDestroyed = applyOnDestroyed,
	ApplyOnGiven = applyOnGiven,
	ApplyOnExperience = applyOnExperience,
	UpdateAll = updateAll,
	ClearAll = clearAll,
}
