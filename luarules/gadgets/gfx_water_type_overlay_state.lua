local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Water Type Overlay State",
		desc      = "Exposes GG.WaterTypeOverlay; applies lava/acid damage when overlay active",
		author    = "BARb",
		date      = "2026",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Skip entirely on real lava maps (map_lava.lua handles damage there)
local springLava = Spring.Lava
if springLava and springLava.isLavaMap then
	return
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------
local active = false
local activeType = nil  -- "lava" or "acid"
local targetLevel = 0
local currentLevel = 0
local baseWaterLevel = 0  -- engine water plane at activation time
local LERP_SPEED = 4.0  -- matches widget visual interpolation

------------------------------------------------------------------------
-- Damage config per type (health lost per second)
------------------------------------------------------------------------
local typeConfig = {
	lava = {
		damage          = 100,   -- HP/sec
		damageFeatures  = true,
		slowFraction    = 0.8,   -- 0.8 = 20% max speed when fully submerged
		effectDamage    = "lava-damage",
	},
	acid = {
		damage          = 50,
		damageFeatures  = true,
		slowFraction    = 0.6,   -- 0.6 = 40% max speed
		effectDamage    = nil,   -- no CEG for acid (set one if you add it)
	},
}

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------
local gameSpeed = Game.gameSpeed
local DAMAGE_RATE = 10  -- apply damage every N frames (same cadence as map_lava)

------------------------------------------------------------------------
-- Cached engine calls
------------------------------------------------------------------------
local spAddUnitDamage     = Spring.AddUnitDamage
local spAddFeatureDamage  = Spring.AddFeatureDamage
local spGetAllUnits       = Spring.GetAllUnits
local spGetAllFeatures    = Spring.GetAllFeatures
local spGetFeatureDefID   = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetMoveData       = Spring.GetUnitMoveTypeData
local spMoveCtrlEnabled   = Spring.MoveCtrl.IsEnabled
local spSetMoveData       = Spring.MoveCtrl.SetGroundMoveTypeData
local spGetGroundHeight   = Spring.GetGroundHeight
local spGetGroundExtremes = Spring.GetGroundExtremes
local spSpawnCEG          = Spring.SpawnCEG
local clamp               = math.clamp

------------------------------------------------------------------------
-- Unit def caches (built once at load)
------------------------------------------------------------------------
local canFly     = {}
local speedDefs  = {}
local turnDefs   = {}
local accDefs    = {}
local unitHeight = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		canFly[unitDefID] = true
	else
		speedDefs[unitDefID]  = unitDef.speed
		turnDefs[unitDefID]   = unitDef.turnRate
		accDefs[unitDefID]    = unitDef.maxAcc
	end
	unitHeight[unitDefID] = Spring.GetUnitDefDimensions(unitDefID).height
end

local geoThermal = {}
for featureDefID, featureDef in pairs(FeatureDefs) do
	if featureDef.geoThermal then
		geoThermal[featureDefID] = true
	end
end

------------------------------------------------------------------------
-- Per-unit tracking (slow restore on exit / deactivate)
------------------------------------------------------------------------
local affectedUnits = {}  -- unitID → { currentSlow, slowed }

local function updateSlow(unitID, unitDefID, unitSlow)
	if spMoveCtrlEnabled(unitID) then return false end
	local slowedMaxSpeed = speedDefs[unitDefID] * unitSlow
	local slowedTurnRate = turnDefs[unitDefID] * unitSlow
	local slowedAccRate  = accDefs[unitDefID]   * unitSlow
	local ok = pcall(function()
		spSetMoveData(unitID, { maxSpeed = slowedMaxSpeed, turnRate = slowedTurnRate, accRate = slowedAccRate })
	end)
	return ok
end

local function restoreAllUnits()
	for unitID, data in pairs(affectedUnits) do
		if data.slowed then
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				updateSlow(unitID, unitDefID, 1)
			end
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
			local x, y, z = spGetUnitBasePosition(unitID)
			if y and y < waterLevel then
				-- Compute slow factor based on submersion depth
				local unitSlow = clamp(1 - (((waterLevel - y) / unitHeight[unitDefID]) * slowFrac), 1 - slowFrac, 0.9)

				if not affectedUnits[unitID] then
					local moveType = spGetMoveData(unitID).name
					local maxSpd = speedDefs[unitDefID]
					local turn   = turnDefs[unitDefID]
					local acc    = accDefs[unitDefID]
					if moveType == "ground" and (maxSpd and maxSpd ~= 0) and (turn and turn ~= 0) and (acc and acc ~= 0) then
						affectedUnits[unitID] = { currentSlow = 1, slowed = true }
					else
						affectedUnits[unitID] = { slowed = false }
					end
				end

				local data = affectedUnits[unitID]
				if data.slowed and unitSlow ~= data.currentSlow then
					if updateSlow(unitID, unitDefID, unitSlow) then
						data.currentSlow = unitSlow
					end
				end

				spAddUnitDamage(unitID, dmg, 0, gaiaTeamID, 1)
				if effectDmg then
					spSpawnCEG(effectDmg, x, y + 5, z)
				end
			elseif affectedUnits[unitID] then
				if affectedUnits[unitID].slowed then
					updateSlow(unitID, unitDefID, 1)
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
		isActive = function() return active end,
		getActiveType = function() return activeType end,
		getLevel = function() return currentLevel end,
		getTargetLevel = function() return targetLevel end,
		setLevel = function(level)
			targetLevel = level
		end,
		activate = function(typeName)
			if typeName ~= "lava" and typeName ~= "acid" then return false end
			baseWaterLevel = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0
			currentLevel = baseWaterLevel + targetLevel
			active = true
			activeType = typeName
			return true
		end,
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
	if not active then return end

	local cfg = typeConfig[activeType]
	if not cfg then return end

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
function gadget:RecvLuaMsg(msg, playerID)
	local cleanMsg = msg:match("^%$c%$(.+)") or msg

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
function gadget:Shutdown()
	restoreAllUnits()
	GG.WaterTypeOverlay = nil
end
