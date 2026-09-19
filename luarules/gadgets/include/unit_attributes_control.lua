-- unit_attributes_control.lua -------------------------------------------------
-- A small effects system for applying unitdef and unit properties and states.
-- Effects can override a value (set) or scale it (multiply) and can be stacked.
--------------------------------------------------------------------------------

-- Attribute factors come in two types which are handled differently per-scope:
-- 1. `set`s take the narrowest scope: unit > unitdef-and-team > unitdef
-- 2. `multiply`s are unordered so each apply: unit x unitdef-and-team x unitdef
-- The full result, for a numeric type, is `(override or base) x (multipliers)`.
--
-- Attributes themselves are typed, also, so a boolean state has no multipliers.
-- It is up to attribute consumers to check the definitions for correct typing.
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
local gameSpeedInverse = 1 / gameSpeed

---@class AttributeFactor
---@field kind "set"|"multiply"
---@field value number|boolean|string
---@field seqnum integer tiebreaker, highest wins

local SOURCE_DEFAULT = "default"

local unitdefFactors = {} ---@type table<UnitDefID, table<string, table<string, AttributeFactor>?>?>
local unitdefTeamFactors = {} ---@type table<UnitDefID, table<TeamID, table<string, table<string, AttributeFactor>?>?>?>
local unitFactors = {} ---@type table<UnitID, table<string, table<string, AttributeFactor>?>?>
local appliedValues = {} ---@type table<UnitID, table<string, any>?>
local dirty = {} ---@type table<UnitID, table<string, true>?>
local baseValues = {} ---@type table<UnitDefID, table<string, any>?>
local baseWeaponValues = {} ---@type table<UnitDefID, number[]?>
local baseWeaponReloads = {} ---@type table<UnitDefID, number[]?>
local sequence = 0

-- Module internals ------------------------------------------------------------

local function nonexistent(attribute)
	Spring.Log("UnitAttributes", LOG.WARNING, "Attribute not found: " .. tostring(attribute))
end

-- The engine truncates to whole frames so the values we pass may be inexact.
local function toFrameTime(seconds)
	return math_max(math_round(seconds * gameSpeed, 0), 1) * gameSpeedInverse
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

local isBuilder = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	return unitDef.isBuilder == true, unitDefID
end) ---@as { UnitDefID : boolean? }

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
end) ---@as { UnitDefID : (false|fun(unitID:UnitID, key:any, value:any):integer)? }

local isEngageRangeConstant = table.map(UnitDefs, function(unitDef, unitDefID)
	---@cast unitDef table
	local engageRange = tonumber(unitDef.customParams.maxrange or 0) or 0
	return (engageRange ~= 0 and engageRange < (unitDef.maxWeaponRange or 0))
		or unitDef.customParams.nomaxrangexpscale ~= nil,
		unitDefID
end) ---@as { UnitDefID : boolean? }

local function setMoveTypeValue(unitID, key, value)
	local setter = moveTypeSetterByDef[spGetUnitDefID(unitID)]
	if not setter or spMoveCtrlIsEnabled(unitID) then
		return false
	end
	-- StrafeAirMoveType has no turnRate and overwrites its wanted speed on every frame.
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
	local costs = {} -- only ever contains one key-value pair
	return function(unitID, value)
		costs[costKey] = value
		spSetUnitCosts(unitID, costs)
	end
end

---@type table<string, string>
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
	local weapon = (unitDef.weapons or {})[1]
	local weaponDef = weapon and WeaponDefs[weapon.weaponDef]
	return weaponDef and weaponDef.reload or false, unitDefID
end) ---@as { UnitDefID : number|false }

---@type table<string, table<UnitDefID, (number|false)?>>
local baseTableByAttribute = {
	reloadTime = nominalReloadByDef,
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
		local prebuilt = baseTableByAttribute[attribute]
		if field then
			value = UnitDefs[unitDefID][field]
			values[attribute] = value
		elseif prebuilt then
			value = prebuilt[unitDefID] or nil
			values[attribute] = value
		end
	end
	return value
end

---@return number[]
local function getWeaponBaseRanges(unitDefID)
	local ranges = baseWeaponValues[unitDefID]
	if not ranges then
		ranges = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons or {}) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			ranges[index] = weaponDef and weaponDef.range or 0
		end
		baseWeaponValues[unitDefID] = ranges -- TODO: contains only ranges, so far
	end
	return ranges
end

---@return number[]
local function getWeaponBaseReloads(unitDefID)
	local reloads = baseWeaponReloads[unitDefID]
	if not reloads then
		reloads = {}
		for index, weapon in ipairs(UnitDefs[unitDefID].weapons or {}) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			reloads[index] = weaponDef and weaponDef.reload or 0
		end
		baseWeaponReloads[unitDefID] = reloads
	end
	return reloads
end

local function setMaxWeaponRange(unitID, value)
	local unitDefID = spGetUnitDefID(unitID)
	if not isEngageRangeConstant[unitDefID] then
		spSetUnitMaxRange(unitID, value)
	end

	local baseline = getBaseline(unitDefID, "maxWeaponRange")
	if not baseline or baseline <= 0 then
		return
	end

	local factor = value / baseline
	for index, range in ipairs(getWeaponBaseRanges(unitDefID)) do
		spSetUnitWeaponState(unitID, index, "range", range * factor)
	end
end

local function setReloadTime(unitID, value)
	local unitDefID = spGetUnitDefID(unitID)
	local baseline = getBaseline(unitDefID, "reloadTime")
	if not baseline or baseline <= 0 then
		return
	end

	local factor = value / baseline
	local gameFrame = spGetGameFrame()
	local luaEnv = getUnitScriptEnv(unitID)
	local reloadMax = 0.0

	for weaponNum, reload in ipairs(getWeaponBaseReloads(unitDefID)) do
		local previous = spGetUnitWeaponState(unitID, weaponNum, "reloadTime")
		local reloadTime = toFrameTime(reload * factor)
		spSetUnitWeaponState(unitID, weaponNum, "reloadTime", reloadTime)

		local reloadState = spGetUnitWeaponState(unitID, weaponNum, "reloadState")
		if previous and previous > 0 and reloadState and reloadState > gameFrame then
			local remaining = (reloadState - gameFrame) * reloadTime / previous
			spSetUnitWeaponState(unitID, weaponNum, "reloadState", gameFrame + remaining)
		end

		callUnitScript(unitID, luaEnv, reloadMethodByWeapon[weaponNum], reloadTime * 1000)
		reloadMax = math_max(reloadMax, reloadTime)
	end

	callUnitScript(unitID, luaEnv, "SetMaxReloadTime", reloadMax * 1000)
end

local speedData = { maxSpeed = 0, maxWantedSpeed = 0 }

-- See MobileCAI. The maxWantedSpeed is set per-order and changing it will break formation movement.
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
	if wanted == nil or current == nil or wanted >= current then
		speedData.maxWantedSpeed = value
	else
		speedData.maxWantedSpeed = nil
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
	maxHealth = spSetUnitMaxHealth,
	speed = setMaxSpeed,
	maxWantedSpeed = getMoveTypeValueSetter("maxWantedSpeed"),
	turnRate = getMoveTypeValueSetter("turnRate"),
	maxAcc = getMoveTypeValueSetter("accRate"),
	maxDec = getMoveTypeValueSetter("decRate"),
	buildSpeed = spSetUnitBuildSpeed,
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

	experience = spSetUnitExperience,
	cloaked = spSetUnitCloak,
}

local function step(root, key, create)
	local child = root[key]
	if child == nil and create then
		child = {}
		root[key] = child
	end
	return child
end

local function getUnitBucket(unitID, attribute, create)
	local attributes = step(unitFactors, unitID, create)
	return attributes and step(attributes, attribute, create)
end

local function getUnitDefBucket(unitDefID, teamID, attribute, create)
	if teamID == nil then
		local attributes = step(unitdefFactors, unitDefID, create)
		return attributes and step(attributes, attribute, create)
	end
	local teams = step(unitdefTeamFactors, unitDefID, create)
	local attributes = teams and step(teams, teamID, create)
	return attributes and step(attributes, attribute, create)
end

local function pruneChain(...)
	local chain = { ... }
	for index = #chain, 2, -2 do
		local parent, key = chain[index - 1], chain[index]
		local child = parent[key]
		if child == nil or next(child) ~= nil then
			return
		end
		parent[key] = nil
	end
end

local function pruneUnit(unitID, attribute)
	local attributes = unitFactors[unitID]
	if attributes then
		pruneChain(unitFactors, unitID, attributes, attribute)
	end
end

local function pruneUnitDef(unitDefID, teamID, attribute)
	if teamID == nil then
		local attributes = unitdefFactors[unitDefID]
		if attributes then
			pruneChain(unitdefFactors, unitDefID, attributes, attribute)
		end
		return
	end
	local teams = unitdefTeamFactors[unitDefID]
	local attributes = teams and teams[teamID]
	if attributes then
		pruneChain(unitdefTeamFactors, unitDefID, teams, teamID, attributes, attribute)
	end
end

local function record(bucket, source, kind, value)
	local factor = bucket[source]
	if value == nil then
		bucket[source] = nil
		return factor ~= nil
	end

	sequence = sequence + 1
	if not factor then
		bucket[source] = { kind = kind, value = value, seqnum = sequence }
		return true
	end

	-- A repeated multiply cannot move the composed value. A repeated set can, by taking the tiebreak.
	local unchanged = kind == "multiply" and factor.kind == kind and factor.value == value
	factor.kind = kind
	factor.value = value
	factor.seqnum = sequence
	return not unchanged
end

local function resolveSet(bucket)
	local value, seqnum
	if bucket then
		for _, factor in pairs(bucket) do
			if factor.kind == "set" and (seqnum == nil or factor.seqnum > seqnum) then
				value, seqnum = factor.value, factor.seqnum
			end
		end
	end
	return value, seqnum
end

local function applyMults(value, bucket)
	if bucket then
		for _, factor in pairs(bucket) do
			if factor.kind == "multiply" then
				value = value * factor.value
			end
		end
	end
	return value
end

local function composeValue(unitID, unitDefID, teamID, attribute, baseline)
	local attributes = unitdefFactors[unitDefID]
	local unitdefBucket = attributes and attributes[attribute]

	local teams = unitdefTeamFactors[unitDefID]
	attributes = teams and teams[teamID]
	local teamdefBucket = attributes and attributes[attribute]

	attributes = unitFactors[unitID]
	local unitBucket = attributes and attributes[attribute]

	local value, seqnum = resolveSet(unitBucket)
	if seqnum == nil then
		value, seqnum = resolveSet(teamdefBucket)
	end
	if seqnum == nil then
		value, seqnum = resolveSet(unitdefBucket)
	end
	if seqnum == nil then
		value = baseline
	end

	if type(value) == "number" then
		value = applyMults(value, unitdefBucket)
		value = applyMults(value, teamdefBucket)
		value = applyMults(value, unitBucket)
	end

	return value
end

local attributeSetPool = {}
local attributeSetCount = 0

local function addToPool(attributes)
	attributeSetCount = attributeSetCount + 1
	attributeSetPool[attributeSetCount] = attributes
end

local function markUnitDirty(unitID, attribute)
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

local function markUnitDefDirty(unitDefID, teamID, attribute)
	if teamID ~= nil then
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

local function setApplied(unitID, attribute, value)
	local applied = appliedValues[unitID]
	if value == nil then
		if applied then
			applied[attribute] = nil
			if next(applied) == nil then
				appliedValues[unitID] = nil
			end
		end
		return
	end
	if not applied then
		applied = {}
		appliedValues[unitID] = applied
	end
	applied[attribute] = value
end

local function recordUnitDefAttribute(unitDefID, attribute, value, source, kind, teamID)
	local entry = definitions[attribute]
	if not entry then
		nonexistent(attribute)
		return
	elseif
		entry.unitOnly
		or (entry.mobileOnly and not moveTypeSetterByDef[unitDefID])
		or (entry.builderOnly and not isBuilder[unitDefID])
	then
		return
	end

	local bucket = getUnitDefBucket(unitDefID, teamID, attribute, value ~= nil)
	if not bucket then
		return
	end

	if record(bucket, source or SOURCE_DEFAULT, kind, value) then
		markUnitDefDirty(unitDefID, teamID, attribute)
	end
	if value == nil then
		pruneUnitDef(unitDefID, teamID, attribute)
	end
end

local function recordUnitAttribute(unitID, attribute, value, source, kind)
	local entry = definitions[attribute]
	if not entry then
		nonexistent(attribute)
		return
	end

	if entry.state then
		if kind == "set" and value ~= nil then
			applyUnitAttribute[attribute](unitID, value)
		end
		return
	end

	local attributes = unitFactors[unitID]
	local bucket = attributes and attributes[attribute]
	if not bucket then
		if value == nil then
			return
		end
		if entry.mobileOnly or entry.builderOnly then
			local unitDefID = spGetUnitDefID(unitID)
			if entry.mobileOnly and not moveTypeSetterByDef[unitDefID] then
				return
			end
			if entry.builderOnly and not isBuilder[unitDefID] then
				return
			end
		end
		bucket = getUnitBucket(unitID, attribute, true)
	end

	if record(bucket, source or SOURCE_DEFAULT, kind, value) then
		markUnitDirty(unitID, attribute)
	end
	if value == nil then
		pruneUnit(unitID, attribute)
	end
end

-- Module functions ------------------------------------------------------------

---Overrides an attribute on a unitdef until the same source clears it.
---@param unitDefID UnitDefID
---@param attribute string
---@param value number|boolean|string|nil `nil` clears this source's factor.
---@param source string? Names the party holding the opinion. Defaults to "default".
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefAttribute(unitDefID, attribute, value, source, teamID)
	recordUnitDefAttribute(unitDefID, attribute, value, source, "set", teamID)
end

---Overrides an attribute on one unit until the same source clears it.
---@param unitID UnitID
---@param attribute string
---@param value number|boolean|string|nil `nil` clears this source's factor.
---@param source string? Names the party holding the opinion. Defaults to "default".
local function setUnitAttribute(unitID, attribute, value, source)
	recordUnitAttribute(unitID, attribute, value, source, "set")
end

---Scales an attribute across a unitdef, or across a unitdef on one team, until the same source clears it.
---@param unitDefID UnitDefID
---@param attribute string
---@param multiplier number? `nil` clears this source's factor.
---@param source string? Names the party holding the opinion. Defaults to "default".
---@param teamID TeamID? The def scope when nil, the def-and-team scope otherwise.
local function setUnitDefModifier(unitDefID, attribute, multiplier, source, teamID)
	recordUnitDefAttribute(unitDefID, attribute, multiplier, source, "multiply", teamID)
end

---Scales an attribute on one unit until the same source clears it.
---@param unitID UnitID
---@param attribute string
---@param multiplier number? `nil` clears this source's factor.
---@param source string? Names the party holding the opinion. Defaults to "default".
local function setUnitModifier(unitID, attribute, multiplier, source)
	recordUnitAttribute(unitID, attribute, multiplier, source, "multiply")
end

---Reads what a unit's attribute composes to now, or its unitdef value when no source is on it.
---@param unitID UnitID
---@param attribute string
---@return number|boolean|string|nil value The resulting value. Often redundant to a more simple callout/getter.
local function getUnitAttributeValue(unitID, attribute)
	local applied = appliedValues[unitID]
	local value = applied and applied[attribute]
	if value ~= nil then
		return value
	end

	-- We have generalized setters but not getters. So we do a lot of work here:
	local entry = definitions[attribute]
	if not entry then
		nonexistent(attribute)
		return
	elseif entry.state then
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
	for attribute in pairs(teams[newTeamID] or {}) do
		markUnitDirty(unitID, attribute)
	end
	for attribute in pairs(oldTeamID and teams[oldTeamID] or {}) do
		markUnitDirty(unitID, attribute)
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
						setApplied(unitID, attribute, nil)
					else
						setApplied(unitID, attribute, value)
					end
					applied = appliedValues[unitID]
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
				-- State attributes never become applied values because they have no baseline.
				-- They are not recorded, not returned in any module getter, and ignored here.
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
	UpdateAll = updateAll,
	ClearAll = clearAll,
}
