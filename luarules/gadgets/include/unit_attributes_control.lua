-- unit_attributes_control.lua -------------------------------------------------
-- Applies unitdef and unit attributes written by named sources, which stack.
--------------------------------------------------------------------------------

-- Attribute factors come in two types which are handled differently per-scope:
-- 1. `set`s take the narrowest scope: unit > unitdef-and-team > unitdef
-- 2. `multiply`s are unordered so each apply: unit x unitdef-and-team x unitdef
-- The full result, for a numeric type, is `(override or base) x (multipliers)`.
--
-- An `isUnitState` attribute is not composed across multiple factors. It writes
-- straight to the unit and always updates rather than performing comparisons.
--
-- Each named "source" keeps only one factor per-scope per-entry in that scope.
-- A new value written to the same source and scope overrides any predecessors,
-- regardless of type, so e.g. a source may replace a `multiply` with a `set`.
-- Clearing a source/factor requires setting it back to `nil`, then waiting
-- for the next attributes update pass on the following g:GameFrame.
--
-- A `perWeapon` attribute composes to one value per weapon and is written with
-- its own functions. Factors on specific weapon numbers are more specified than
-- factors over all weapons within the same scope (unitdef, def-and-team, unit).

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
local armorTypeMin, armorTypeMax = 0, #Game.armorTypes

---@class AttributeFactor
---@field kind AttributeFactorKind
---@field value number|boolean|string
---@field sequence integer tiebreaker, highest wins

---@alias AttributeFactorKind "set"|"multiply"

local SOURCE_DEFAULT = "default"

local unitdefFactors = {} ---@type table<UnitDefID, table<string, table<string, AttributeFactor>?>?>
local unitdefTeamFactors = {} ---@type table<UnitDefID, table<TeamID, table<string, table<string, AttributeFactor>?>?>?>
local unitFactors = {} ---@type table<UnitID, table<string, table<string, AttributeFactor>?>?>
local appliedValues = {} ---@type table<UnitID, table<string, any>?>
local dirty = {} ---@type table<UnitID, table<string, true?>?>
local appliedWeapons = {} ---@type table<UnitID, table<string, number[]>?>
local sequenceNum = -1e8

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
	---@cast unitDef table
	local setter = false ---@as false|fun(unitID:UnitID, key:any, value:any):integer
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
	-- `StrafeAirMoveType` has no turnRate and may overwrite its wanted speed on each frame.
	if setter == spSetAirMoveTypeData and (key == "turnRate" or key == "maxWantedSpeed") then
		return true -- Don't readd to the next flush.
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
}

local reloadScaleByDef = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	return unitDef.weapons[1] ~= nil and 1.0 or false, unitDefID
end) ---@as table<UnitDefID, 1|false>

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

---Computed at load for unit attributes that have no unitDef property.
---@type table<string, table<UnitDefID, (false|number)?>?>
local derivedBaseByAttribute = {
	reloadTime = reloadScaleByDef,
	shieldMaxPower = shieldPowerByDef,
}

local baseValues = {} ---@type table<UnitDefID, table<string, any>?>
local baseWeapons = {} ---@type table<UnitDefID, WeaponBaseline[]?>
local baseVectors = {} ---@type table<UnitDefID, table<string, number[]>?>
local baseDamages = {} ---@type table<UnitDefID, table<integer, table<integer, number>>?>
local baseExplosions = {} ---@type table<UnitDefID, table<integer, number>[]?>

for unitDefID in ipairs(UnitDefs) do
	baseValues[unitDefID] = {}
end

local function getBaseline(unitDefID, attribute)
	local values = baseValues[unitDefID]
	local value = values[attribute]
	if value == nil then
		local field = baseFieldByAttribute[attribute]
		local derived = derivedBaseByAttribute[attribute]
		if field then
			value = UnitDefs[unitDefID][field]
			values[attribute] = value
		elseif derived then
			value = derived[unitDefID] or nil
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

---@type table<string, string?>
local weaponFieldByAttribute = {
	maxWeaponRange = "range",
	reloadTime = "reload",
}

---@return WeaponBaseline[]
local function getWeaponBaselines(unitDefID)
	local weapons = baseWeapons[unitDefID]
	if not weapons then
		weapons = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef] ---@as table
			weapons[index] = {
				range = weaponDef.range or 1.0,
				reload = weaponDef.reload or 1.0,
			}
		end
		baseWeapons[unitDefID] = weapons
	end
	return weapons
end

local function setMaxWeaponRange(unitID, ranges)
	local unitDefID = spGetUnitDefID(unitID)
	local rangeMax = 0

	for weaponNum in ipairs(getWeaponBaselines(unitDefID)) do
		spSetUnitWeaponState(unitID, weaponNum, "range", ranges[weaponNum])
		rangeMax = math_max(rangeMax, ranges[weaponNum])
	end

	if not hasCustomEngageRange[unitDefID] then
		spSetUnitMaxRange(unitID, rangeMax)
	end
end

---@param weaponDefs table[]
local function getDamagesFromList(weaponDefs)
	local weapons = {}
	for index, weaponDef in ipairs(weaponDefs) do
		local damages = weaponDef.damages ---@as table?
		if damages then
			local realDamages, isArmed = {}, false
			for armorIndex = armorTypeMin, armorTypeMax do
				realDamages[armorIndex] = damages[armorIndex]
				isArmed = isArmed or damages[armorIndex] ~= 0
			end
			if isArmed then
				weapons[index] = realDamages
			end
		end
	end
	return weapons
end

---Gets the damage by armor class per weapon, excluding non-damaging fakes.
---@return table<integer, table<integer, number>>
local function getWeaponDamages(unitDefID)
	local weapons = baseDamages[unitDefID]
	if not weapons then
		local weaponDefList = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons) do
			weaponDefList[index] = WeaponDefs[weapon.weaponDef]
		end
		weapons = getDamagesFromList(weaponDefList)
		baseDamages[unitDefID] = weapons
	end
	return weapons
end

local explosionFieldByIndex = { "deathExplosion", "selfDExplosion" }
local explosionTargetByIndex = { "explode", "selfDestruct" }

---@return table<integer, table<integer, number>> # Left out when nondamaging, as ordinary weapons are
local function getExplosionDamages(unitDefID)
	local explosions = baseExplosions[unitDefID]
	if not explosions then
		local unitDef = UnitDefs[unitDefID]
		local weaponDefList = {}
		for index, field in ipairs(explosionFieldByIndex) do
			weaponDefList[index] = WeaponDefNames[unitDef[field]]
		end
		explosions = getDamagesFromList(weaponDefList)
		baseExplosions[unitDefID] = explosions
	end
	return explosions
end

---The same weapondef used in many weapons on the same unitdef maps to its first instance.
---@type table<UnitDefID, table<WeaponDefID, integer>?>
local weaponNumbersByDef = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	local weapons = unitDef.weapons
	if weapons[1] then
		local weaponNumbers = {}
		for weaponNum, weapon in ipairs(weapons) do
			local weaponDefID = weapon.weaponDef
			if not weaponNumbers[weaponDefID] then
				weaponNumbers[weaponDefID] = weaponNum
			end
		end
		weaponNumbersByDef[unitDefID] = weaponNumbers
	end
end

---Consumer code paths are given a weaponDefID but need to know a weaponNum to look up factors.
---This is a fast lookup for a very hot path in e.g. :ProjectileCreated, :ProjectileDestroyed.
---@type table<UnitID, table<WeaponDefID, number>?>
local weaponDamageFactors = {}

-- Some gadgets spawn submunitions that have to inherit (some of) their parent's weapon factors.
local spawnedWeaponDefs = {} ---@type table<WeaponDefID, true?>
local spawnedDefsByParent = {} ---@type table<WeaponDefID, WeaponDefID[]?>

-- Ignores WeaponDamages properties that we do not scale, e.g. impulse, cratering.
local damagesArray = table.new(armorTypeMax, 1 - armorTypeMin) ---@as number[] reusable scratch table
local weaponVector = {} ---@type number[] reusable scratch, one composed value per weapon

local function setDamage(unitID, scales)
	local unitDefID = spGetUnitDefID(unitID)

	for weaponNum, damages in pairs(getWeaponDamages(unitDefID)) do
		local scale = scales[weaponNum]
		for armorIndex = armorTypeMin, armorTypeMax do
			damagesArray[armorIndex] = damages[armorIndex] * scale
		end
		---@cast damagesArray WeaponDamages
		spSetUnitWeaponDamages(unitID, weaponNum, damagesArray)
	end

	local weaponNumbers = weaponNumbersByDef[unitDefID]
	if weaponNumbers then
		local factors = weaponDamageFactors[unitID]
		if not factors then
			factors = {}
			weaponDamageFactors[unitID] = factors
		end
		for weaponDefID, weaponNum in pairs(weaponNumbers) do
			local scale = scales[weaponNum]
			local factor = scale ~= 1.0 and scale or nil
			factors[weaponDefID] = factor
			local spawned = spawnedDefsByParent[weaponDefID]
			if spawned then
				for i = 1, #spawned do
					factors[spawned[i]] = factor
				end
			end
		end
	end

	-- Explosions are only modified directly. They ignore effects on "all weapons".
	local applied = appliedWeapons[unitID]
	local previous = applied and applied.damage
	local weaponCount = #getWeaponBaselines(unitDefID)
	local explosions = getExplosionDamages(unitDefID)
	for index = 1, #explosionTargetByIndex do
		local damages = explosions[index]
		local scale = scales[weaponCount + index]
		local before = previous and previous[weaponCount + index] or 1.0
		if damages and (scale ~= 1.0 or before ~= 1.0) then
			for armorIndex = armorTypeMin, armorTypeMax do
				damagesArray[armorIndex] = damages[armorIndex] * scale
			end
			spSetUnitWeaponDamages(unitID, explosionTargetByIndex[index], damagesArray)
		end
	end
end

local function setReloadTime(unitID, times)
	local unitDefID = spGetUnitDefID(unitID)
	local gameFrame = spGetGameFrame()
	local luaEnv = getUnitScriptEnv(unitID)
	local reloadMax = 0.0

	-- Rescale reloads for slowing effects to apply and restore immediately.
	-- Units can have animation states tied to reload state and reload time.
	for weaponNum in ipairs(getWeaponBaselines(unitDefID)) do
		local previous = spGetUnitWeaponState(unitID, weaponNum, "reloadTime")
		local reloadTime = toFrameTime(times[weaponNum])
		spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadTime)

		local reloadState = spGetUnitWeaponState(unitID, weaponNum, "reloadState")
		if previous and previous > 0 and reloadState and reloadState > gameFrame then
			-- Round ahead of the engine truncating integers passed from Lua:
			local framesLeft = math_round((reloadState - gameFrame) * reloadTime / previous, 0)
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
		-- Rescaled how the engine does when handling XP:
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

local function getChild(root, key, create)
	local child = root[key]
	if child == nil and create then
		child = {}
		root[key] = child
	end
	return child
end

local function prune(parent, key)
	local child = parent[key]
	if child == nil or next(child) ~= nil then
		return false
	end
	parent[key] = nil
	return true -- child was dropped, so the parent may be able to prune.
end

local getUnitDefFactors, getUnitFactors ---@type function, function
do
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

local pruneUnitFactors, pruneUnitDefFactors ---@type function, function
do
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

---@param kind AttributeFactorKind
---@return boolean changed `false` only when the composed value _cannot_ have changed
local function record(factors, source, kind, value)
	local factor = factors[source]
	if value == nil then
		factors[source] = nil
		return factor ~= nil
	end

	sequenceNum = sequenceNum + 1
	if not factor then
		factors[source] = { kind = kind, value = value, sequence = sequenceNum }
		return true
	end

	-- When a source repeats the same multiply, the result is never changed.
	-- When a source repeats the same set, the sequence increases which changes the tiebreak.
	local unchanged = kind == "multiply" and kind == factor.kind and value == factor.value

	factor.kind = kind
	factor.value = value
	factor.sequence = sequenceNum
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

---@type function, function, function
local addToPool, takeFromPool, markUnitDirty
do
	-- Zero-allocation is not possible in this design but we can get close.
	local attributeSetPool = {} ---@type table<integer, table<string, true?>>
	local attributeSetCount = 0

	addToPool = function(attributes)
		attributeSetCount = attributeSetCount + 1
		attributeSetPool[attributeSetCount] = attributes
	end

	takeFromPool = function()
		if attributeSetCount == 0 then
			return {}
		end
		local attributes = attributeSetPool[attributeSetCount]
		attributeSetPool[attributeSetCount] = nil
		attributeSetCount = attributeSetCount - 1
		return attributes
	end

	---@param unitID UnitID
	markUnitDirty = function(unitID, attribute)
		local attributes = dirty[unitID]
		if not attributes then
			attributes = takeFromPool()
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

-- Weapon attributes -----------------------------------------------------------

local WEAPON_ALL = 0 -- Packing index for non-specific weapon attributes scopes.
local WEAPON_DEATH = -1 -- TODO: remove or complete the `perExplosion` checks
local WEAPON_SELFD = -2
local WEAPON_CLUSTER = -3 -- Weaponless weapondefs
local WEAPON_SPLIT = -4 -- Weaponless weapondefs

local weaponSlotKeysByDef = {} ---@type table<UnitDefID, integer[]?>
local explosionSlotKeysByDef = {} ---@type table<UnitDefID, integer[]?>

---@return integer[] slotsToKeys
local function getWeaponKeys(unitDefID, perExplosion)
	local cache = perExplosion and explosionSlotKeysByDef or weaponSlotKeysByDef
	local slotKeys = cache[unitDefID]
	if not slotKeys then
		slotKeys = {}
		local weaponCount = #getWeaponBaselines(unitDefID)
		for i = 1, weaponCount do
			slotKeys[i] = i
		end
		if perExplosion then
			slotKeys[weaponCount + 1] = WEAPON_DEATH
			slotKeys[weaponCount + 2] = WEAPON_SELFD
		end
		cache[unitDefID] = slotKeys
	end
	return slotKeys
end

---@return integer? slot
local function getWeaponSlot(unitDefID, weaponKey, perExplosion)
	if weaponKey > 0 then
		return weaponKey
	elseif not perExplosion then
		return nil
	elseif weaponKey == WEAPON_DEATH then
		return #getWeaponBaselines(unitDefID) + 1
	elseif weaponKey == WEAPON_SELFD then
		return #getWeaponBaselines(unitDefID) + 2
	end
end

---A composed vector used to compare a unit's weapons at baseline vs modified.
---@return number[]
local function getBaselineVector(unitDefID, attribute)
	local vectors = baseVectors[unitDefID]
	if not vectors then
		vectors = {}
		baseVectors[unitDefID] = vectors
	end
	local vector = vectors[attribute]
	if not vector then
		vector = {}
		local field = weaponFieldByAttribute[attribute]
		local weapons = getWeaponBaselines(unitDefID)
		for slot, key in ipairs(getWeaponKeys(unitDefID, true)) do
			local weapon = key > 0 and weapons[key]
			vector[slot] = weapon and field and weapon[field] or 1.0 -- OK: default value unused, for comparisons
		end
		vectors[attribute] = vector
	end
	return vector
end

local unitWeaponFactors = {} ---@type table<UnitID, table<string, WeaponFactors?>?>
local unitdefWeaponFactors = {} ---@type table<UnitDefID, table<string, WeaponFactors?>?>
local unitdefTeamWeaponFactors = {} ---@type table<UnitDefID, table<TeamID, table<string, WeaponFactors?>?>?>
local dirtyWeapons = {} ---@type table<UnitID, table<string, true?>?>

---@alias WeaponFactors table<integer, table<string, AttributeFactor>?>

local function getWeaponFactors(attributes, attribute, weaponKey, create)
	local weapons = attributes and getChild(attributes, attribute, create)
	return weapons and getChild(weapons, weaponKey, create)
end

local function pruneWeaponFactors(root, key, attributes, attribute, weaponKey)
	local weapons = attributes and attributes[attribute]
	if weapons and prune(weapons, weaponKey) and prune(attributes, attribute) then
		prune(root, key)
	end
end

local function markUnitWeaponDirty(unitID, attribute)
	local attributes = dirtyWeapons[unitID]
	if not attributes then
		attributes = takeFromPool()
		dirtyWeapons[unitID] = attributes
	end
	attributes[attribute] = true
end

local function markUnitDefWeaponDirty(unitDefID, teamID, attribute)
	if teamID then
		for _, unitID in ipairs(spGetTeamUnitsByDefs(teamID, unitDefID)) do
			markUnitWeaponDirty(unitID, attribute)
		end
		return
	end
	for _, team in ipairs(spGetTeamList()) do
		for _, unitID in ipairs(spGetTeamUnitsByDefs(team, unitDefID)) do
			markUnitWeaponDirty(unitID, attribute)
		end
	end
end

---@return any value, integer? sequence, boolean? named # Whether the factor named this weapon.
local function resolveWeaponSet(weapon, allWeapons)
	local value, sequence = resolveSet(weapon)
	if sequence ~= nil then
		return value, sequence, true
	end
	value, sequence = resolveSet(allWeapons)
	return value, sequence, false
end

---@param out number[]
---@return number[] out
local function composeWeaponVector(unitID, unitDefID, teamID, attribute, baseVector, out)
	local attributes = unitWeaponFactors[unitID]
	local fromUnit = attributes and attributes[attribute]

	local teams = unitdefTeamWeaponFactors[unitDefID]
	attributes = teams and teams[teamID]
	local fromTeam = attributes and attributes[attribute]

	attributes = unitdefWeaponFactors[unitDefID]
	local fromUnitDef = attributes and attributes[attribute]

	local unitAllWeapons = fromUnit and fromUnit[WEAPON_ALL]
	local teamAllWeapons = fromTeam and fromTeam[WEAPON_ALL]
	local unitdefAllWeapons = fromUnitDef and fromUnitDef[WEAPON_ALL]

	local baseline = getBaseline(unitDefID, attribute)
	local weaponSlotKeys = getWeaponKeys(unitDefID, true)
	local slotCount = #weaponSlotKeys
	local startExtraSlots = #getWeaponBaselines(unitDefID) + 1

	for slot = 1, slotCount do
		local weaponKey = weaponSlotKeys[slot]
		local unitWeapon = fromUnit and fromUnit[weaponKey]
		local teamWeapon = fromTeam and fromTeam[weaponKey]
		local unitdefWeapon = fromUnitDef and fromUnitDef[weaponKey]

		if slot == startExtraSlots then
			unitAllWeapons, teamAllWeapons, unitdefAllWeapons = nil, nil, nil
		end

		local value, sequence, named
		if unitWeapon or unitAllWeapons then
			value, sequence, named = resolveWeaponSet(unitWeapon, unitAllWeapons)
		end
		if sequence == nil and (teamWeapon or teamAllWeapons) then
			value, sequence, named = resolveWeaponSet(teamWeapon, teamAllWeapons)
		end
		if sequence == nil and (unitdefWeapon or unitdefAllWeapons) then
			value, sequence, named = resolveWeaponSet(unitdefWeapon, unitdefAllWeapons)
		end

		if sequence == nil then
			value = baseVector[slot]
		elseif not named then
			-- Unnamed sets include all weapons. Each weapon moves by proportion in that case.
			-- Negative values are possible, but we cannot stretch against a zero base value.
			if baseline and baseline ~= 0 then
				value = baseVector[slot] * value / baseline
			else
				value = baseVector[slot]
			end
		end

		if unitdefAllWeapons then
			value = applyMult(value, unitdefAllWeapons)
		end
		if unitdefWeapon then
			value = applyMult(value, unitdefWeapon)
		end
		if teamAllWeapons then
			value = applyMult(value, teamAllWeapons)
		end
		if teamWeapon then
			value = applyMult(value, teamWeapon)
		end
		if unitAllWeapons then
			value = applyMult(value, unitAllWeapons)
		end
		if unitWeapon then
			value = applyMult(value, unitWeapon)
		end
		out[slot] = value
	end
	-- Safely reuse a scratch tbl:
	for slot = slotCount + 1, #out do
		out[slot] = nil
	end
	return out
end

local function sameVector(vector, other)
	for index = 1, #vector do
		if vector[index] ~= other[index] then
			return false
		end
	end
	return true
end

---@return table<string, number[]>? applied
local function setAppliedWeapons(unitID, attribute, vector)
	local applied = appliedWeapons[unitID]
	if vector == nil then
		if applied then
			applied[attribute] = nil
			if next(applied) == nil then
				appliedWeapons[unitID] = nil
				return
			end
		end
		return applied
	end
	if not applied then
		applied = {}
		appliedWeapons[unitID] = applied
	end
	local held = applied[attribute]
	if not held then
		held = {}
		applied[attribute] = held
	end
	for index = 1, #vector do
		held[index] = vector[index]
	end
	return applied
end

local function checkWeaponAttribute(attribute, weaponKey, kind, value, unitDefID)
	local entry = definitions[attribute]
	if not entry then
		warn(attribute, "not found")
		return
	elseif not entry.perWeapon then
		warn(attribute, "is not written per weapon")
		return
	elseif entry.multiplyOnly and kind == "set" and value ~= nil then
		warn(attribute, "is multiplication-only")
		return
	elseif weaponKey < 0 then
		if weaponKey < WEAPON_SELFD then
			warn(attribute, "names an explosion that does not exist")
			return
		end
	elseif weaponKey ~= WEAPON_ALL and not getWeaponBaselines(unitDefID)[weaponKey] then
		warn(attribute, "names a weapon the unitdef does not have")
		return
	end
	return true
end

local function recordUnitWeaponAttribute(unitID, weaponKey, attribute, value, source, kind)
	weaponKey = weaponKey or WEAPON_ALL

	local unitDefID
	if weaponKey > 0 then
		unitDefID = spGetUnitDefID(unitID)
		if not unitDefID then
			return
		end
	end

	if not checkWeaponAttribute(attribute, weaponKey, kind, value, unitDefID) then
		return
	end

	local attributes = getChild(unitWeaponFactors, unitID, value ~= nil)
	local factors = getWeaponFactors(attributes, attribute, weaponKey, value ~= nil)
	if not factors then
		return
	end

	if record(factors, source or SOURCE_DEFAULT, kind, value) then
		markUnitWeaponDirty(unitID, attribute)
	end
	if value == nil then
		pruneWeaponFactors(unitWeaponFactors, unitID, attributes, attribute, weaponKey)
	end
end

local function recordUnitDefWeaponAttribute(unitDefID, weaponKey, attribute, value, source, kind, teamID)
	weaponKey = weaponKey or WEAPON_ALL
	if not checkWeaponAttribute(attribute, weaponKey, kind, value, unitDefID) then
		return
	end

	local root, key, attributes
	if teamID == nil then
		root, key = unitdefWeaponFactors, unitDefID
		attributes = getChild(unitdefWeaponFactors, unitDefID, value ~= nil)
	else
		local teams = getChild(unitdefTeamWeaponFactors, unitDefID, value ~= nil)
		root, key = teams, teamID
		attributes = teams and getChild(teams, teamID, value ~= nil)
	end

	local factors = getWeaponFactors(attributes, attribute, weaponKey, value ~= nil)
	if not factors then
		return
	end

	if record(factors, source or SOURCE_DEFAULT, kind, value) then
		markUnitDefWeaponDirty(unitDefID, teamID, attribute)
	end
	if value == nil then
		pruneWeaponFactors(root, key, attributes, attribute, weaponKey)
		if teamID ~= nil then
			prune(unitdefTeamWeaponFactors, unitDefID)
		end
	end
end

local function updateWeapons()
	for unitID, attributes in pairs(dirtyWeapons) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			local teamID = spGetUnitTeam(unitID)
			local applied = appliedWeapons[unitID]
			for attribute in pairs(attributes) do
				local baseVector = getBaselineVector(unitDefID, attribute)
				local vector = composeWeaponVector(unitID, unitDefID, teamID, attribute, baseVector, weaponVector)
				local previous = applied and applied[attribute] or baseVector
				if sameVector(vector, previous) or applyUnitAttribute[attribute](unitID, vector) ~= false then
					if sameVector(vector, baseVector) then
						applied = setAppliedWeapons(unitID, attribute, nil)
					else
						applied = setAppliedWeapons(unitID, attribute, vector)
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
			dirtyWeapons[unitID] = nil
			addToPool(attributes)
		end
	end
end

local function markWeaponsOnCreated(unitID, unitDefID, teamID)
	local attributes = unitdefWeaponFactors[unitDefID]
	if attributes then
		for attribute in pairs(attributes) do
			markUnitWeaponDirty(unitID, attribute)
		end
	end

	local teams = unitdefTeamWeaponFactors[unitDefID]
	attributes = teams and teams[teamID]
	if attributes then
		for attribute in pairs(attributes) do
			markUnitWeaponDirty(unitID, attribute)
		end
	end
end

local function markWeaponsOnGiven(unitID, unitDefID, newTeamID, oldTeamID)
	local teams = unitdefTeamWeaponFactors[unitDefID]
	if not teams then
		return
	end
	local attributes = teams[newTeamID]
	if attributes then
		for attribute in pairs(attributes) do
			markUnitWeaponDirty(unitID, attribute)
		end
	end
	attributes = teams[oldTeamID]
	if attributes then
		for attribute in pairs(attributes) do
			markUnitWeaponDirty(unitID, attribute)
		end
	end
end

local function dropUnitWeapons(unitID)
	unitWeaponFactors[unitID] = nil
	appliedWeapons[unitID] = nil
	weaponDamageFactors[unitID] = nil
	dirtyWeapons[unitID] = nil
end

local function clearWeapons()
	for unitID, attributes in pairs(appliedWeapons) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			for attribute in pairs(attributes) do
				applyUnitAttribute[attribute](unitID, getBaselineVector(unitDefID, attribute))
			end
		end
	end

	unitWeaponFactors = {}
	unitdefWeaponFactors = {}
	unitdefTeamWeaponFactors = {}
	dirtyWeapons = {}

	-- Consumers read these for live values:
	for unitID in pairs(appliedWeapons) do
		appliedWeapons[unitID] = nil
	end
	for unitID in pairs(weaponDamageFactors) do
		weaponDamageFactors[unitID] = nil
	end
end

---@param kind AttributeFactorKind
local function checkUnitDefAttribute(entry, attribute, kind, value, unitDefID)
	if not entry then
		warn(attribute, "not found")
		return
	elseif entry.multiplyOnly and kind == "set" and value ~= nil then
		warn(attribute, "is multiplication-only")
		return
	elseif entry.perWeapon then
		warn(attribute, "is written per weapon")
		return
	elseif entry.unitOnly or entry.isUnitState then
		warn(attribute, "cannot be set on unitdefs")
		return
	elseif
		(entry.mobileOnly and not moveTypeSetterByDef[unitDefID])
		or (entry.builderOnly and not builderSpeedsByDef[unitDefID])
	then
		warn(attribute, "has an inappropriate def (" .. UnitDefs[unitDefID].name .. ")")
		return
	end
	return true
end

---@param kind AttributeFactorKind
local function checkUnitAttribute(entry, attribute, kind, value)
	if not entry then
		warn(attribute, "not found")
		return
	elseif entry.perWeapon then
		warn(attribute, "is written per weapon")
		return
	elseif entry.isUnitState then
		if kind ~= "set" then
			warn(attribute, "cannot be multiplied")
			return
		end
		return true
	elseif entry.multiplyOnly and kind == "set" and value ~= nil then
		warn(attribute, "is multiplication-only")
		return
	end
	return true
end

---@param kind AttributeFactorKind
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

---@param kind AttributeFactorKind
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

---Overrides an attribute on one weapon of a unit until the same source clears it.
---@param unitID UnitID
---@param weaponKey integer? Can be the weaponNum, WEAPON_DEATH, WEAPON_SELFD, or WEAPON_ALL/nil.
---@param attribute string
---@param value number|nil # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
local function setUnitWeaponAttribute(unitID, weaponKey, attribute, value, source)
	recordUnitWeaponAttribute(unitID, weaponKey, attribute, value, source, "set")
end

---Scales an attribute on one weapon of a unit until the same source clears it.
---@param unitID UnitID
---@param weaponKey integer? Can be the weaponNum, WEAPON_DEATH, WEAPON_SELFD, or WEAPON_ALL/nil.
---@param attribute string
---@param multiplier number? # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
local function setUnitWeaponModifier(unitID, weaponKey, attribute, multiplier, source)
	recordUnitWeaponAttribute(unitID, weaponKey, attribute, multiplier, source, "multiply")
end

---Overrides an attribute on one weapon across a unitdef until the same source clears it.
---@param unitDefID UnitDefID
---@param weaponKey integer? Can be the weaponNum, WEAPON_DEATH, WEAPON_SELFD, or WEAPON_ALL/nil.
---@param attribute string
---@param value number|nil # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefWeaponAttribute(unitDefID, weaponKey, attribute, value, source, teamID)
	recordUnitDefWeaponAttribute(unitDefID, weaponKey, attribute, value, source, "set", teamID)
end

---Scales an attribute on one weapon across a unitdef until the same source clears it.
---@param unitDefID UnitDefID
---@param weaponKey integer? Can be the weaponNum, WEAPON_DEATH, WEAPON_SELFD, or WEAPON_ALL/nil.
---@param attribute string
---@param multiplier number? # `nil` clears this source's factor.
---@param source string? Names the caller or subject of the effect (default := `"default"`)
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefWeaponModifier(unitDefID, weaponKey, attribute, multiplier, source, teamID)
	recordUnitDefWeaponAttribute(unitDefID, weaponKey, attribute, multiplier, source, "multiply", teamID)
end

---Reads what one weapon's attribute composes to now, or its weapondef value when nothing is on it.
---@param unitID UnitID
---@param weaponKey integer weaponNum, WEAPON_DEATH, or WEAPON_SELFD
---@param attribute string
---@return number? value
local function getUnitWeaponAttributeValue(unitID, weaponKey, attribute)
	local entry = definitions[attribute]
	if not entry then
		warn(attribute, "not found")
		return
	elseif not entry.perWeapon then
		warn(attribute, "is not written per weapon")
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	local slot = getWeaponSlot(unitDefID, weaponKey, true)
	if not slot then
		return
	end

	local applied = appliedWeapons[unitID]
	local vector = applied and applied[attribute]
	if vector then
		return vector[slot]
	end
	return getBaselineVector(unitDefID, attribute)[slot]
end

---Reads the currently composed attribute value, first, then the unitdef value, if possible.
---
---Factors are applied on the following frame, so can be up to one frame behind. The engine
---getters are more general; they are not pending nor stale and can fetch unit states, also.
---@param unitID UnitID
---@param attribute string
---@return number|boolean|string|nil value `nil` only for unit state or unknown attributes
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
	elseif entry.perWeapon then
		warn(attribute, "is read per weapon")
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
	markWeaponsOnCreated(unitID, unitDefID, spGetUnitTeam(unitID))

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
	dropUnitWeapons(unitID)

	unitFactors[unitID] = nil
	appliedValues[unitID] = nil
	dirty[unitID] = nil
end

---@param unitID UnitID
---@param unitDefID UnitDefID
---@param newTeamID TeamID
---@param oldTeamID TeamID
local function applyOnGiven(unitID, unitDefID, newTeamID, oldTeamID)
	markWeaponsOnGiven(unitID, unitDefID, newTeamID, oldTeamID)

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
	if next(dirtyWeapons) ~= nil then
		updateWeapons()
	end
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

-- Spawned weapondefs ----------------------------------------------------------

---A spawned submunition or secondary damage effect inherits its parent's factors.
---@param weaponDefID WeaponDefID the spawned weapondef
---@param parentWeaponDefID WeaponDefID the weapon it is spawned from
local function setWeaponDefParent(weaponDefID, parentWeaponDefID)
	-- TODO: move runtime rules checks to load time
	for _, weaponNumbers in pairs(weaponNumbersByDef) do
		if weaponNumbers[weaponDefID] then
			warn(weaponDefID, "is a unit weapon and cannot be a spawned weapondef")
			return
		end
	end

	local spawned = spawnedDefsByParent[parentWeaponDefID]
	if not spawned then
		spawned = {}
		spawnedDefsByParent[parentWeaponDefID] = spawned
	end
	for i = 1, #spawned do
		if spawned[i] == weaponDefID then
			return
		end
	end
	spawned[#spawned + 1] = weaponDefID
	spawnedWeaponDefs[weaponDefID] = true
end

---@return number? damage
local function applyOnPreDamaged(damage, weaponDefID, attackerID)
	-- Weapondefs bound to a unit's weapons are scaled already.
	if spawnedWeaponDefs[weaponDefID] then
		local factors = weaponDamageFactors[attackerID]
		local factor = factors and factors[weaponDefID]
		if factor then
			return damage * factor
		end
	end
end

-- Shutdown --------------------------------------------------------------------

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

	clearWeapons()
end

-- Module export ---------------------------------------------------------------

return {
	Definitions = definitions,

	WEAPON_ALL = WEAPON_ALL,
	WEAPON_DEATH = WEAPON_DEATH,
	WEAPON_SELFD = WEAPON_SELFD,

	SetUnitDefAttribute = setUnitDefAttribute,
	SetUnitAttribute = setUnitAttribute,
	SetUnitDefModifier = setUnitDefModifier,
	SetUnitModifier = setUnitModifier,
	GetUnitAttributeValue = getUnitAttributeValue,

	SetUnitDefWeaponAttribute = setUnitDefWeaponAttribute,
	SetUnitWeaponAttribute = setUnitWeaponAttribute,
	SetUnitDefWeaponModifier = setUnitDefWeaponModifier,
	SetUnitWeaponModifier = setUnitWeaponModifier,
	GetUnitWeaponAttributeValue = getUnitWeaponAttributeValue,

	---Every composed weapon value, first by attribute, then by weapon slot.
	---@type table<UnitID, table<string, number[]>?>
	AppliedWeaponValues = appliedWeapons,
	---Faster lookup for the composed damage value given only unitID, weaponDefID.
	---@type table<UnitID, table<WeaponDefID, number>?>
	WeaponDamageFactors = weaponDamageFactors,

	SetWeaponDefParent = setWeaponDefParent,
	ApplyOnPreDamaged = applyOnPreDamaged,

	ApplyOnCreated = applyOnCreated,
	ApplyOnDestroyed = applyOnDestroyed,
	ApplyOnGiven = applyOnGiven,
	ApplyOnExperience = applyOnExperience,
	UpdateAll = updateAll,
	ClearAll = clearAll,
}
