local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Water Type Overlay State",
		desc = "Exposes GG.WaterTypeOverlay; applies lava/acid damage when overlay active",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Skip entirely on real lava maps (map_lava.lua handles damage there)
local springLava = BAR.Lava
if springLava and springLava.isLavaMap then
	return
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local active = false
local activeType = nil -- "lava" or "acid"
local targetLevel = 0
local currentLevel = 0
local baseWaterLevel = 0 -- engine water plane at activation time
local LERP_SPEED = 4.0 -- matches widget visual interpolation

------------------------------------------------------------------------
-- Damage config per type (health lost per second)
------------------------------------------------------------------------
local typeConfig = {
	lava = {
		damage = 100, -- HP/sec
		damageFeatures = true,
		slowFraction = 0.8, -- 0.8 = 20% max speed when fully submerged
		effectDamage = "lava-damage",
	},
	acid = {
		damage = 50,
		damageFeatures = true,
		slowFraction = 0.6, -- 0.6 = 40% max speed
		effectDamage = nil, -- no CEG for acid (set one if you add it)
	},
}

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------
local gameSpeed = Game.gameSpeed
local DAMAGE_RATE = 10 -- apply damage every N frames (same cadence as map_lava)
local ATTRIBUTE_SOURCE = "wateroverlay"

------------------------------------------------------------------------
-- Cached engine calls
------------------------------------------------------------------------
local spAddUnitDamage = Spring.AddUnitDamage
local spAddFeatureDamage = Spring.AddFeatureDamage
local spGetAllUnits = Spring.GetAllUnits
local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundExtremes = Spring.GetGroundExtremes
local spSpawnCEG = Spring.SpawnCEG
local floor = math.floor
local clamp = math.clamp

------------------------------------------------------------------------
-- Unit/feature def caches (built lazily on first activation)
-- The overlay only ever activates from the editor, so a normal match must
-- not pay this full-def-table scan (one GetUnitDefDimensions call per unit
-- def) at load. buildDefCaches() runs once, the first time the overlay is
-- activated.
------------------------------------------------------------------------
local canFly = {}
local canBeSlowed = {} ---@type table<UnitDefID, boolean?>
local unitHeight = {} ---@type table<UnitDefID, number>
local geoThermal = {}
local defCachesBuilt = false

local function buildDefCaches()
	if defCachesBuilt then
		return
	end
	defCachesBuilt = true

	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.canFly then
			canFly[unitDefID] = true
		else
			canBeSlowed[unitDefID] = not unitDef.isImmobile
				and (unitDef.turnRate or 0) ~= 0
				and (unitDef.maxAcc or 0) ~= 0
		end
		unitHeight[unitDefID] = Spring.GetUnitDefDimensions(unitDefID).height
	end

	for featureDefID, featureDef in pairs(FeatureDefs) do
		if featureDef.geoThermal then
			geoThermal[featureDefID] = true
		end
	end
end

------------------------------------------------------------------------
-- Per-unit tracking (slow restore on exit / deactivate)
------------------------------------------------------------------------
local affectedUnits = {} -- unitID → { currentSlow, slowed }

local SLOW_STEP = 0.05 -- avoid rewriting move data on every damage tick
local SLOW_STEP_INV = 1 / SLOW_STEP

local function getWaterSlow(unitDefID, y, waterLevel, slowFrac)
	local height = unitHeight[unitDefID]
	local unitSlow = clamp(1 - (((waterLevel - y) / height) * slowFrac), 1 - slowFrac, 0.9)
	return floor(unitSlow * SLOW_STEP_INV + 0.5) * SLOW_STEP
end

---@param unitID UnitID
---@param unitSlow number? A nil clears this source's factor.
local function updateSlow(unitID, unitSlow)
	local setUnitModifier = GG.UnitAttributes.SetUnitModifier
	setUnitModifier(unitID, "speed", unitSlow, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "turnRate", unitSlow, ATTRIBUTE_SOURCE)
	setUnitModifier(unitID, "maxAcc", unitSlow, ATTRIBUTE_SOURCE)
end

local function restoreAllUnits()
	for unitID, data in pairs(affectedUnits) do
		if data.slowed then
			updateSlow(unitID, nil)
		end
	end
	affectedUnits = {}
end

------------------------------------------------------------------------
-- Core damage loop (mirrors map_lava.lua logic)
------------------------------------------------------------------------
local minGroundHeight = 0
local GROUND_EXTREMES_RATE = 300

local function damageCheck(cfg, waterLevel)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local dmg = cfg.damage * (DAMAGE_RATE / gameSpeed)
	local slowFrac = cfg.slowFraction
	local effectDmg = cfg.effectDamage

	local allUnits = spGetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID and not canFly[unitDefID] then
			local unitData = affectedUnits[unitID]
			local x, y, z = spGetUnitBasePosition(unitID)
			if y and y < waterLevel then
				if not unitData then
					unitData = { currentSlow = 1.0, slowed = canBeSlowed[unitDefID] == true }
					affectedUnits[unitID] = unitData
				end

				local unitSlow = getWaterSlow(unitDefID, y, waterLevel, slowFrac)
				if unitData.slowed and unitSlow ~= unitData.currentSlow then
					updateSlow(unitID, unitSlow)
					unitData.currentSlow = unitSlow
				end

				spAddUnitDamage(unitID, dmg, 0, gaiaTeamID, 1)
				if effectDmg then
					spSpawnCEG(effectDmg, x, y + 5, z)
				end
			elseif unitData then
				if unitData.slowed then
					updateSlow(unitID, nil)
				end
				affectedUnits[unitID] = nil
			end
		end
	end

	if cfg.damageFeatures then
		local allFeatures = spGetAllFeatures()
		for _, featureID in ipairs(allFeatures) do
			local fDefID = spGetFeatureDefID(featureID)
			if not geoThermal[fDefID] then
				local x, y, z = spGetFeaturePosition(featureID)
				if y and y < waterLevel then
					spAddFeatureDamage(featureID, dmg, 0, gaiaTeamID)
					if effectDmg then
						spSpawnCEG(effectDmg, x, y + 5, z)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- GG API
------------------------------------------------------------------------
function gadget:Initialize()
	minGroundHeight = select(3, spGetGroundExtremes())

	GG.WaterTypeOverlay = {
		---@return boolean active Whether a hazardous water overlay is currently applied.
		isActive = function()
			return active
		end,
		---@return "lava"|"acid"|nil typeName `nil` while the overlay is inactive.
		getActiveType = function()
			return activeType
		end,
		---@return number level Current absolute world height of the overlay surface.
		getLevel = function()
			return currentLevel
		end,
		---@return number level Offset from the base water plane the overlay eases toward.
		getTargetLevel = function()
			return targetLevel
		end,
		---Sets the height the overlay surface eases toward, relative to the base water plane.
		---@param level number
		setLevel = function(level)
			targetLevel = level
		end,
		---Turns the overlay on and starts damaging units in it.
		---@param typeName "lava"|"acid"
		---@return boolean started `false` when `typeName` is not a supported overlay type.
		activate = function(typeName)
			---@diagnostic disable-next-line: unnecessary-if
			if typeName ~= "lava" and typeName ~= "acid" then
				return false
			end
			buildDefCaches()
			baseWaterLevel = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0
			currentLevel = baseWaterLevel + targetLevel
			active = true
			activeType = typeName
			return true
		end,
		---Turns the overlay off and restores any unit state it changed.
		deactivate = function()
			if active then
				restoreAllUnits()
			end
			active = false
			activeType = nil
		end,
	}
end

------------------------------------------------------------------------
-- GameFrame: apply damage when overlay active
------------------------------------------------------------------------
function gadget:GameFrame(f)
	if not active then
		return
	end

	local cfg = typeConfig[activeType]
	if not cfg then
		return
	end

	-- Refresh cached ground extremes periodically
	if f % GROUND_EXTREMES_RATE == 0 then
		minGroundHeight = select(3, spGetGroundExtremes())
	end

	-- Smooth interpolation toward target level (ease-out, same as widget visual)
	local goal = baseWaterLevel + targetLevel
	local dt = 1.0 / gameSpeed
	local diff = goal - currentLevel
	if math.abs(diff) > 0.01 then
		currentLevel = currentLevel + diff * (1 - math.exp(-LERP_SPEED * dt))
	else
		currentLevel = goal
	end

	if f % DAMAGE_RATE == 0 then
		if currentLevel >= minGroundHeight then
			damageCheck(cfg, currentLevel)
		elseif next(affectedUnits) then
			restoreAllUnits()
		end
	end
end

------------------------------------------------------------------------
-- Message from widget
------------------------------------------------------------------------
-- Prefix embedded in messages when cheat was active at send time. During
-- replay the recorded prefix survives while live cheat is always false, so it
-- is the only trust signal available there.
local CHEAT_SIG = "$c$"

function gadget:RecvLuaMsg(msg, playerID)
	if type(msg) ~= "string" then
		return
	end

	local certified = msg:sub(1, #CHEAT_SIG) == CHEAT_SIG
	local cleanMsg = certified and msg:sub(#CHEAT_SIG + 1) or msg

	-- Only react to water-overlay commands; ignore all other LuaRules traffic
	-- so the auth check below never runs on unrelated messages.
	if cleanMsg:sub(1, 13) ~= "wateroverlay:" then
		return
	end

	-- Auth gate: require live cheat, or a $c$-certified message during replay
	-- only. Without this any modified client could send this message in a live
	-- no-cheat match and flip the map into lava/acid mode, applying map-wide
	-- Gaia damage to every unit and feature.
	if not (Spring.IsCheatingEnabled() or (certified and Spring.IsReplay())) then
		return
	end

	if cleanMsg == "wateroverlay:deactivate" then
		GG.WaterTypeOverlay.deactivate()
		return true
	end

	local typeName = cleanMsg:match("^wateroverlay:activate:(%a+)$")
	if typeName then
		GG.WaterTypeOverlay.activate(typeName)
		return true
	end

	local levelStr = cleanMsg:match("^wateroverlay:level:(.+)$")
	if levelStr then
		local level = tonumber(levelStr)
		if level then
			targetLevel = level
		end
		return true
	end
end

------------------------------------------------------------------------
-- Cleanup
------------------------------------------------------------------------
function gadget:UnitDestroyed(unitID)
	affectedUnits[unitID] = nil
end

function gadget:Shutdown()
	restoreAllUnits()
	GG.WaterTypeOverlay = nil
end
