-- Targeting Library for Scavengers and Raptors
-- Provides weighted target selection based on various criteria

local PveTargeting = {}

-- Default weights (all max priority)
local DEFAULT_WEIGHTS = {
  evenPlayerSpread = 1.0,
  eco = 1.0,
  tech = 1.0,
  damageEfficiencyAreas = 1.0,
  unitRandom = 0.0
}

-- Gadget-level default weights (can be overridden by each gadget)
local gadgetWeights = nil

-- Precomputed static data for performance
local unitDefEcoValues = {} -- unitDefID -> rawEcoValue
local unitDefTechLevels = {} -- unitDefID -> rawTechLevel  
local targetCandidateUnitDefs = {} -- unitDefID -> true for valid target candidates
local precomputedDataInitialized = false

-- Weight priority: modoption > customparam > gadget > default
local function getEffectiveWeights(modoptions, gadgetOverride)
  local weights = table.copy(DEFAULT_WEIGHTS)

  -- Apply gadget override weights (lowest priority)
  -- Priority: gadgetOverride > gadgetWeights > DEFAULT_WEIGHTS
  local overrideWeights = gadgetOverride or gadgetWeights
  if overrideWeights then
    for key, value in pairs(overrideWeights) do
      if weights[key] ~= nil then
        weights[key] = value
      end
    end
  end

  if modoptions then
    local modoptionMapping = {
      scav_targeting_eco = 'eco',
      scav_targeting_tech = 'tech',
      scav_targeting_even_player_spread = 'evenPlayerSpread',
      scav_targeting_damage_efficiency_areas = 'damageEfficiencyAreas',
      scav_targeting_unit_random = 'unitRandom'
    }

    for modoptionKey, weightKey in pairs(modoptionMapping) do
      local modoptionValue = modoptions[modoptionKey]
      -- Only apply if user explicitly set the modoption (not nil/default)
      if modoptionValue ~= nil and modoptionValue ~= '' then
        local numValue = tonumber(modoptionValue)
        if numValue then
          weights[weightKey] = math.max(0, math.min(1, numValue))
        end
      end
    end

    -- Also apply the random factor to unitRandom for position-based randomness
    local randomValue = modoptions.scav_targeting_random
    if randomValue ~= nil and randomValue ~= '' then
      local numValue = tonumber(randomValue)
      if numValue then
        weights.unitRandom = math.max(0, math.min(1, numValue))
      end
    end
  end

  return weights
end

-- Precompute static unit data for performance
local function initializePrecomputedData()
  if precomputedDataInitialized then
    return
  end
  
  for unitDefID, unitDef in pairs(UnitDefs) do
    local isEco = unitDef.metalMake > 0 or unitDef.energyMake > 0 or unitDef.extractsMetal > 0 or
                  unitDef.energyUpkeep < 0 or (unitDef.customParams and unitDef.customParams.metal_extractor)
    local isCommander = unitDef.customParams and unitDef.customParams.iscommander
    if (isEco and not unitDef.canMove) or isCommander then

      local ecoScore = 0

      -- Metal/Energy production
      if unitDef.metalMake and unitDef.metalMake > 0 then
        ecoScore = ecoScore + unitDef.metalMake * 60
      end

      if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
        ecoScore = ecoScore + unitDef.extractsMetal * 60
      end

      if unitDef.energyMake and unitDef.energyMake > 0 then
        ecoScore = ecoScore + unitDef.energyMake
      end

      if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
        ecoScore = ecoScore - unitDef.energyUpkeep
      end

      if unitDef.windGenerator and unitDef.windGenerator > 0 then
        ecoScore = ecoScore + unitDef.windGenerator * 0.75
      end

      if unitDef.tidalGenerator and unitDef.tidalGenerator > 0 then
        ecoScore = ecoScore + unitDef.tidalGenerator * 15
      end

      if unitDef.customParams and unitDef.customParams.energyconv_capacity and
        tonumber(unitDef.customParams.energyconv_capacity) > 0 then
        ecoScore = ecoScore + tonumber(unitDef.customParams.energyconv_capacity) / 3
      end

      if ecoScore > 0 then
        unitDefEcoValues[unitDefID] = ecoScore
      end

      local techLevel = unitDef.customParams and unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) or 1

      if techLevel > 1 then
        unitDefTechLevels[unitDefID] = techLevel
      end

      targetCandidateUnitDefs[unitDefID] = true
    end
  end

  precomputedDataInitialized = true

  -- Count target candidate unit types
  local count = 0
  for _ in pairs(targetCandidateUnitDefs) do
    count = count + 1
  end

end

-- Initialize targeting system
function PveTargeting.Initialize(teamID, allyTeamID, options)
  options = options or {}

  -- Initialize precomputed data once
  initializePrecomputedData()

  -- Get excluded allyteams (caller and gaia only)
  local excludedAllyTeams = {}
  excludedAllyTeams[allyTeamID] = true -- Always exclude the calling team's allyteam

  -- Also exclude gaia
  local gaiaTeamID = Spring.GetGaiaTeamID()
  if gaiaTeamID then
    local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
    if gaiaAllyTeamID then
      excludedAllyTeams[gaiaAllyTeamID] = true
    end
  end

  -- Get map dimensions for tile-based calculations
  local mapSizeX = Game.mapSizeX
  local mapSizeZ = Game.mapSizeZ
  -- 192 is the size of 4 afus next to each other. A regularly occurring value/multiple in buildings and maps. 192*2 might be too large.
  local tileSize = 192

  -- Calculate grid dimensions (number of tiles in each direction)
  local numTilesX = math.ceil(mapSizeX / tileSize)
  local numTilesZ = math.ceil(mapSizeZ / tileSize)

  local weights = getEffectiveWeights(Spring.GetModOptions(), options.gadgetWeights)

  Spring.Echo(
    'Initializing PveTargeting with weights: ' .. Json.encode(weights)
  )

  return {
    teamID = teamID,
    allyTeamID = allyTeamID,
    excludedAllyTeams = excludedAllyTeams,
    weights = weights,
    playerTargetCounts = {}, -- Track targeting frequency per player (for even spread)
    damageAreaStats = {}, -- Track damage efficiency per map area (for tactical targeting)
    tileSize = tileSize,
    numTilesX = numTilesX,
    numTilesZ = numTilesZ,
    lastUpdateFrame = 0,
    scoreCache = {},
    scoreCacheValidUntil = 0
  }
end

-- Convert world position to grid tile coordinates
local function worldToTile(x, z, tileSize)
  local tileX = math.floor(x / tileSize)
  local tileZ = math.floor(z / tileSize)
  return tileX, tileZ
end

-- Get tile key for damage area stats
local function getTileKey(tileX, tileZ)
  return tileX .. ',' .. tileZ
end

local function invalidateScoreCache(context)
  context.scoreCacheValidUntil = 0
  context.scoreCache = {}
end

-- Update area-based damage statistics for efficiency scoring
function PveTargeting.UpdateDamageStats(context, damageDealt, damageTaken, targetPos)
  -- Only update area-based damage stats if position is provided
  if targetPos and targetPos.x and targetPos.z then
    local tileX, tileZ = worldToTile(targetPos.x, targetPos.z, context.tileSize)
    local tileKey = getTileKey(tileX, tileZ)

    if not context.damageAreaStats[tileKey] then
      context.damageAreaStats[tileKey] = {
        damageDealt = 0,
        damageTaken = 0,
        efficiency = 1.0,
        lastUpdate = Spring.GetGameFrame()
      }
    end

    local areaStats = context.damageAreaStats[tileKey]
    areaStats.damageDealt = areaStats.damageDealt + damageDealt
    areaStats.damageTaken = areaStats.damageTaken + damageTaken

    -- Calculate area efficiency
    if areaStats.damageTaken > 0 then
      areaStats.efficiency = areaStats.damageDealt / areaStats.damageTaken
    else
      areaStats.efficiency = areaStats.damageDealt > 0 and 2.0 or 1.0
    end

    areaStats.lastUpdate = Spring.GetGameFrame()
  end
end

-- Get all potential targets (no caching since targets change frequently)
local function getPotentialTargets(context)
  local targets = {}
  local validTeams = {}

  -- Get all teams except those in excluded allyteams
  for _, teamID in ipairs(Spring.GetTeamList()) do
    if teamID ~= context.teamID then
      local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
      if allyTeamID and not context.excludedAllyTeams[allyTeamID] then
        validTeams[teamID] = true
      end
    end
  end

  -- Collect only precomputed target candidates from valid teams
  for teamID, _ in pairs(validTeams) do
    local teamUnits = Spring.GetTeamUnits(teamID)
    for _, unitID in ipairs(teamUnits) do
      if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
        local unitDefID = Spring.GetUnitDefID(unitID)
        local x, y, z = Spring.GetUnitBasePosition(unitID)

        if x and unitDefID and targetCandidateUnitDefs[unitDefID] then
          table.insert(
            targets,
            {
              unitID = unitID,
              unitDefID = unitDefID,
              teamID = teamID,
              x = x,
              y = y,
              z = z,
              unitDef = UnitDefs[unitDefID]
            }
          )
        end
      end
    end
  end

  return targets
end

-- Calculate raw economic value for a target (using precomputed lookup)
local function calculateRawEcoValue(target)
  return unitDefEcoValues[target.unitDefID] or 0
end

-- Calculate raw tech level for a target (using precomputed lookup)
local function calculateRawTechLevel(target)
  return unitDefTechLevels[target.unitDefID] or 1
end

-- Calculate area-based damage efficiency score for a target's position
local function calculateDamageEfficiencyAreaRawValue(context, target)
  if not target.x or not target.z then
    return 0.0 -- Default score if no position
  end

  local tileX, tileZ = worldToTile(target.x, target.z, context.tileSize)
  local tileKey = getTileKey(tileX, tileZ)

  local areaStats = context.damageAreaStats[tileKey]
  if not areaStats then
    return 0.5 -- Default neutral score for unexplored areas
  end

  -- Higher efficiency = higher score (we want to target areas where we're winning)
  return areaStats.efficiency
end

-- Calculate even player spread score (lower = better spread)
local function calculateEvenSpreadRawValue(context, target)
  if not context.playerTargetCounts[target.teamID] then
    context.playerTargetCounts[target.teamID] = 0
  end

  -- Find minimum target count across all players
  local minCount = math.huge
  local totalCount = 0
  local playerCount = 0
  for teamID, count in pairs(context.playerTargetCounts) do
    minCount = math.min(minCount, count)
    totalCount = totalCount + count
    playerCount = playerCount + 1
  end

  -- Handle edge cases to prevent division by zero and infinite values
  if totalCount == 0 or playerCount == 0 then
    return 0.5 -- Neutral score when no targeting data exists
  end

  local currentCount = context.playerTargetCounts[target.teamID]
  local spread = 1.0 - ((currentCount - minCount) / totalCount)

  -- Clamp to valid range to prevent infinite values
  return math.max(0.0, math.min(1.0, spread))
end

local function normalize(value, min, max)
  -- Prevent division by zero when min == max
  if max == min then
    return 0.5 -- Neutral score when all values are the same
  end

  -- Clamp value to valid range and normalize
  local clampedValue = math.max(min, math.min(max, value))
  return (clampedValue - min) / (max - min)
end

-- Calculate combined score for a target
local function calculateTargetScores(
  candidates,
  weights,
  minEcoValue,
  maxEcoValue,
  minTechLevel,
  maxTechLevel,
  minDamageEfficiencyArea,
  maxDamageEfficiencyArea,
  minEvenSpreadScore,
  maxEvenSpreadScore)
  -- local weightedCandidates = {}
  local total = 0

  for _, candidate in pairs(candidates) do
    local ecoScore = normalize(candidate.rawValues.eco, minEcoValue, maxEcoValue)
    local techScore = normalize(candidate.rawValues.tech, minTechLevel, maxTechLevel)
    local damageAreaScore =
      normalize(candidate.rawValues.damageEfficiencyArea, minDamageEfficiencyArea, maxDamageEfficiencyArea)
    local spreadScore = normalize(candidate.rawValues.evenSpread, minEvenSpreadScore, maxEvenSpreadScore)

    -- Validate scores and replace NaN/infinite values with safe defaults
    if not ecoScore or ecoScore ~= ecoScore or ecoScore == math.huge or ecoScore == -math.huge then
      ecoScore = 0.5
    end
    if not techScore or techScore ~= techScore or techScore == math.huge or techScore == -math.huge then
      techScore = 0.5
    end
    if
      not damageAreaScore or damageAreaScore ~= damageAreaScore or damageAreaScore == math.huge or
        damageAreaScore == -math.huge
     then
      damageAreaScore = 0.5
    end
    if not spreadScore or spreadScore ~= spreadScore or spreadScore == math.huge or spreadScore == -math.huge then
      spreadScore = 0.5
    end

    local totalScore =
      weights.eco * ecoScore + weights.tech * techScore + weights.damageEfficiencyAreas * damageAreaScore +
      weights.evenPlayerSpread * spreadScore

    -- Validate total score
    if not totalScore or totalScore ~= totalScore or totalScore == math.huge or totalScore == -math.huge then
      totalScore = 0.5
    end

    total = total + totalScore
    candidate.cumulative = total
    candidate.totalScore = totalScore
  end

  return candidates, total
end

-- Efficiently shuffle weighted candidates while preserving weights
local function shuffleWeightedCandidates(weightedCandidates)
  local shuffled = {}
  local n = #weightedCandidates

  -- Copy the array
  for i = 1, n do
    shuffled[i] = weightedCandidates[i]
  end

  -- Fisher-Yates shuffle
  for i = n, 2, -1 do
    local j = math.random(i)
    shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
  end

  return shuffled
end

-- Get cached targets and scores or calculate new ones if cache is expired
local function getCachedTargetsAndScores(context, weights)
  local currentFrame = Spring.GetGameFrame()

  -- Check if we have valid cached scores
  if currentFrame < context.scoreCacheValidUntil and context.scoreCache.weightedCandidates and context.scoreCache.total then
    return context.scoreCache.weightedCandidates, context.scoreCache.total
  end

  local candidates = getPotentialTargets(context)

  -- Calculate all min/max values for normalization
  local minEcoValue, maxEcoValue = math.huge, 0
  local minTechLevel, maxTechLevel = math.huge, 0
  local minDamageEfficiencyArea, maxDamageEfficiencyArea = math.huge, 0
  local minEvenSpreadScore, maxEvenSpreadScore = math.huge, 0

  for _, target in ipairs(candidates) do
    -- Eco values
    local rawEcoValue = calculateRawEcoValue(target)
    minEcoValue = math.min(minEcoValue, rawEcoValue)
    maxEcoValue = math.max(maxEcoValue, rawEcoValue)

    -- Tech levels
    local rawTechLevel = calculateRawTechLevel(target)
    minTechLevel = math.min(minTechLevel, rawTechLevel)
    maxTechLevel = math.max(maxTechLevel, rawTechLevel)

    -- Damage efficiency areas
    local rawDamageEfficiencyAreaValue = calculateDamageEfficiencyAreaRawValue(context, target)
    minDamageEfficiencyArea = math.min(minDamageEfficiencyArea, rawDamageEfficiencyAreaValue)
    maxDamageEfficiencyArea = math.max(maxDamageEfficiencyArea, rawDamageEfficiencyAreaValue)

    -- Even player spread scores
    local rawEvenSpreadValue = calculateEvenSpreadRawValue(context, target)
    minEvenSpreadScore = math.min(minEvenSpreadScore, rawEvenSpreadValue)
    maxEvenSpreadScore = math.max(maxEvenSpreadScore, rawEvenSpreadValue)

    target.rawValues = {
      eco = rawEcoValue,
      tech = rawTechLevel,
      damageEfficiencyArea = rawDamageEfficiencyAreaValue,
      evenSpread = rawEvenSpreadValue
    }
  end

  -- Ensure min values are valid
  if minEcoValue == math.huge then
    minEcoValue = 0
  end
  if minTechLevel == math.huge then
    minTechLevel = 1
  end
  if minDamageEfficiencyArea == math.huge then
    minDamageEfficiencyArea = 0
  end
  if minEvenSpreadScore == math.huge then
    minEvenSpreadScore = 0
  end

  -- Ensure max values are valid and greater than min values to prevent division by zero
  if maxEcoValue <= minEcoValue then
    maxEcoValue = minEcoValue + 1
  end
  if maxTechLevel <= minTechLevel then
    maxTechLevel = minTechLevel + 1
  end
  if maxDamageEfficiencyArea <= minDamageEfficiencyArea then
    maxDamageEfficiencyArea = minDamageEfficiencyArea + 1
  end
  if maxEvenSpreadScore <= minEvenSpreadScore then
    maxEvenSpreadScore = minEvenSpreadScore + 1
  end

  -- Additional safety check: validate that all values are finite
  if
    not (minEcoValue and maxEcoValue and minTechLevel and maxTechLevel and minDamageEfficiencyArea and
      maxDamageEfficiencyArea and
      minEvenSpreadScore and
      maxEvenSpreadScore)
   then
    minEcoValue, maxEcoValue = 0, 1
    minTechLevel, maxTechLevel = 1, 2
    minDamageEfficiencyArea, maxDamageEfficiencyArea = 0, 1
    minEvenSpreadScore, maxEvenSpreadScore = 0, 1
  end

  local weightedCandidates, total =
    calculateTargetScores(
    candidates,
    weights,
    minEcoValue,
    maxEcoValue,
    minTechLevel,
    maxTechLevel,
    minDamageEfficiencyArea,
    maxDamageEfficiencyArea,
    minEvenSpreadScore,
    maxEvenSpreadScore
  )

  -- Cache the results
  context.scoreCache = {
    candidates = candidates,
    weights = weights,
    minEcoValue = minEcoValue,
    maxEcoValue = maxEcoValue,
    minTechLevel = minTechLevel,
    maxTechLevel = maxTechLevel,
    minDamageEfficiencyArea = minDamageEfficiencyArea,
    maxDamageEfficiencyArea = maxDamageEfficiencyArea,
    weightedCandidates = weightedCandidates,
    minEvenSpreadScore = minEvenSpreadScore,
    maxEvenSpreadScore = maxEvenSpreadScore,
    total = total
  }
  context.scoreCacheValidUntil = currentFrame + 10 * Game.gameSpeed -- 10 seconds cache

  return weightedCandidates, total
end

-- Get a weighted random target
function PveTargeting.GetRandomTarget(context, options)
  options = options or {}
  local weights = options.weights or context.weights

  -- Get cached targets and scores (only recalculates if cache expired)
  local weightedCandidates, total = getCachedTargetsAndScores(context, weights)
  if not weightedCandidates or #weightedCandidates == 0 then
    return nil
  end

  -- Filter candidates by type if specified
  if options.targetType then
    local filtered = {}
    for _, target in ipairs(weightedCandidates) do
      local unitDef = target.unitDef
      if options.targetType == 'mobile' and unitDef.canMove then
        table.insert(filtered, target)
      elseif options.targetType == 'structure' and not unitDef.canMove then
        table.insert(filtered, target)
      elseif options.targetType == 'factory' and unitDef.isFactory then
        table.insert(filtered, target)
      elseif
        options.targetType == 'eco' and (unitDef.metalMake > 0 or unitDef.energyMake > 0 or unitDef.extractsMetal > 0)
       then
        table.insert(filtered, target)
      end
    end
    weightedCandidates = filtered
    
    -- Recalculate cumulative values for filtered candidates
    total = 0
    for i = 1, #weightedCandidates do
      total = total + weightedCandidates[i].totalScore
      weightedCandidates[i].cumulative = total
    end
  end

  if #weightedCandidates == 0 then
    return nil
  end

  -- Special case: if all weights are 0, return random
  local totalWeight = 0
  for _, weight in pairs(weights) do
    totalWeight = totalWeight + weight
  end
  if totalWeight == 0 then
    return weightedCandidates[math.random(#weightedCandidates)]
  end

  if total == 0 then
    return weightedCandidates[math.random(#weightedCandidates)]
  end

  -- Pick a random point on the total score range
  local r = math.random() * total
  for i = 1, #weightedCandidates do
    if r <= weightedCandidates[i].cumulative then
      local selectedCandidate = weightedCandidates[i]

      -- Update target count for even spread tracking
      if not context.playerTargetCounts[selectedCandidate.teamID] then
        context.playerTargetCounts[selectedCandidate.teamID] = 0
      end
      context.playerTargetCounts[selectedCandidate.teamID] = context.playerTargetCounts[selectedCandidate.teamID] + 1

      return selectedCandidate
    end
  end

  -- Fallback
  return weightedCandidates[#weightedCandidates]
end

-- Get a random position near a target or general area
function PveTargeting.GetRandomTargetPosition(context, options)
  options = options or {}
  local target = PveTargeting.GetRandomTarget(context, options)

  if target then
    local spread = options.positionSpread or 0
    return {
      x = target.x + math.random(-spread, spread),
      y = target.y,
      z = target.z + math.random(-spread, spread),
      target = target
    }
  else
    -- Fallback to random map position
    local mapSizeX = Game.mapSizeX
    local mapSizeZ = Game.mapSizeZ
    local x = math.random(16, mapSizeX - 16)
    local z = math.random(16, mapSizeZ - 16)
    return {
      x = x,
      y = Spring.GetGroundHeight(x, z),
      z = z,
      target = nil
    }
  end
end

-- Set gadget-level default weights
function PveTargeting.SetGadgetWeights(weights)
  gadgetWeights = table.copy(weights)
end

-- Get damage efficiency statistics for a specific map area
function PveTargeting.GetAreaDamageStats(context, x, z)
  if not x or not z then
    return nil
  end

  local tileX, tileZ = worldToTile(x, z, context.tileSize)
  local tileKey = getTileKey(tileX, tileZ)

  return context.damageAreaStats[tileKey]
end

-- Get all area damage statistics (for analysis/debugging)
function PveTargeting.GetAllAreaDamageStats(context)
  return context.damageAreaStats
end

-- Export damage stats to gamerulesparams for visualization
function PveTargeting.ExportDamageStatsToGameRules(context)
  if not context or not context.damageAreaStats then
    return false
  end

  -- Convert keys to strings for JSON encoding and add tile position info
  local exportStats = {}
  for key, stats in pairs(context.damageAreaStats) do
    local tileX, tileZ = string.match(key, '([^,]+),([^,]+)')
    if tileX and tileZ then
      exportStats[key] = {
        x = tonumber(tileX) * context.tileSize + context.tileSize / 2,
        z = tonumber(tileZ) * context.tileSize + context.tileSize / 2,
        tileSize = context.tileSize,
        damageDealt = stats.damageDealt,
        damageTaken = stats.damageTaken,
        efficiency = stats.efficiency,
        lastUpdate = stats.lastUpdate
      }
    end
  end

  -- Export to gamerulesparams for UI access
  if table.stringifyKeys then
    Spring.SetGameRulesParam('pveDamageEfficiencyAreas', Json.encode(table.stringifyKeys(exportStats)))
  else
    Spring.SetGameRulesParam('pveDamageEfficiencyAreas', Json.encode(exportStats))
  end

  return true
end

-- Manually invalidate score cache (useful for external systems)
function PveTargeting.InvalidateScoreCache(context)
  invalidateScoreCache(context)
end

-- Get grid information for area calculations
function PveTargeting.GetGridInfo(context)
  return {
    tileSize = context.tileSize,
    numTilesX = context.numTilesX,
    numTilesZ = context.numTilesZ
  }
end

-- Calculate distance between two 3D points
local function calculateDistance(pos1, pos2)
  local dx = pos1.x - pos2.x
  local dy = pos1.y - pos2.y
  local dz = pos1.z - pos2.z
  -- math.diag exists in the BAR repository, so we use it here
  return math.diag(dx, dy, dz)
end

-- Efficient nearest-neighbor assignment of units to targets
-- Each unit gets assigned to its closest available target
-- @param units: table of unit objects with position data {unitID, x, y, z, ...}
-- @param targets: table of target objects with position data {targetID, x, y, z, ...}
-- @param options: optional {allowMultipleUnitsPerTarget = false, maxDistance = nil}
-- @return: table mapping unitID -> {targetID, target, distance}
function PveTargeting.GetGreedyAssignment(units, targets, options)
  options = options or {}
  local allowMultiple = options.allowMultipleUnitsPerTarget or false
  local maxDistance = options.maxDistance

  if not units or not targets or #units == 0 or #targets == 0 then
    return {}
  end

  local assignments = {}
  local usedTargets = {}

  -- For each unit, find its closest target
  for _, unit in ipairs(units) do
    local unitID = unit.unitID or unit.squadID
    if unit.x and unit.y and unit.z and unitID then
      local bestDistance = math.huge
      local bestTarget = nil

      for _, target in ipairs(targets) do
        if target.x and target.y and target.z then
          -- Skip if target already assigned (unless multiple assignments allowed)
          local targetKey = target.targetID or target.unitID or target
          if allowMultiple or not usedTargets[targetKey] then
            local distance = calculateDistance(unit, target)
            if distance < bestDistance and (not maxDistance or distance <= maxDistance) then
              bestDistance = distance
              bestTarget = target
            end
          end
        end
      end

      if bestTarget then
        local targetKey = bestTarget.targetID or bestTarget.unitID or bestTarget
        assignments[unitID] = {
          targetID = targetKey,
          target = bestTarget,
          distance = bestDistance
        }

        if not allowMultiple then
          usedTargets[targetKey] = true
        end
      end
    end
  end

  return assignments
end

-- Squad-level assignment for better integration with RTS squad systems
-- @param squads: table of squad objects {squadID, units = {unit1, unit2, ...}, centerPos = {x,y,z}}
-- @param targets: table of target objects
-- @param options: optional configuration
-- @return: table mapping squadID -> target assignment
function PveTargeting.GetSquadAssignments(squads, targets, options)
  options = options or {}

  if not squads or not targets or #squads == 0 or #targets == 0 then
    return {}
  end

  -- Calculate squad center positions if not provided
  local squadPositions = {}
  for _, squad in ipairs(squads) do
    if squad.centerPos then
      squadPositions[#squadPositions + 1] = {
        squadID = squad.squadID,
        x = squad.centerPos.x,
        y = squad.centerPos.y,
        z = squad.centerPos.z,
        squad = squad
      }
    elseif squad.units and #squad.units > 0 then
      -- Calculate center of squad units
      local sumX, sumY, sumZ = 0, 0, 0
      local validUnits = 0

      for _, unitID in ipairs(squad.units) do
        local x, y, z = Spring.GetUnitBasePosition(unitID)
        if x then
          sumX = sumX + x
          sumY = sumY + y
          sumZ = sumZ + z
          validUnits = validUnits + 1
        end
      end

      if validUnits > 0 then
        squadPositions[#squadPositions + 1] = {
          squadID = squad.squadID,
          x = sumX / validUnits,
          y = sumY / validUnits,
          z = sumZ / validUnits,
          squad = squad
        }
      end
    else
      -- Use squad position directly if it has x,y,z
      if squad.x and squad.y and squad.z and squad.squadID then
        squadPositions[#squadPositions + 1] = {
          squadID = squad.squadID,
          x = squad.x,
          y = squad.y,
          z = squad.z,
          squad = squad
        }
      end
    end
  end

  return PveTargeting.GetGreedyAssignment(squadPositions, targets, options)
end

-- Redistribute existing targets among squads for optimal distance-based assignments
-- Useful for RTS AI systems that want to reassign squad targets for better tactical positioning
-- @param squadData: table of squad objects with current targets
--   Example: {{squadID=1, x=100, y=0, z=200, currentTarget={x=500, y=0, z=600, unitID=123}}, ...}
-- @param options: optional configuration {allowMultipleUnitsPerTarget, maxDistance}
-- @return: table mapping squadID -> new target assignment with metadata
--   Example: {[1] = {targetID="500,0,600", target={x=500, y=0, z=600}, distance=450, metadata={unitID=123}}}
function PveTargeting.RedistributeSquadTargets(squadData, options)
  options = options or {}

  if not squadData or #squadData == 0 then
    return {}
  end

  -- Collect unique existing targets from all squads
  local existingTargets = {}
  local targetMetadata = {} -- Store additional metadata per target

  for _, squad in ipairs(squadData) do
    if squad.currentTarget and squad.currentTarget.x and squad.currentTarget.y and squad.currentTarget.z then
      local targetKey = squad.currentTarget.x .. ',' .. squad.currentTarget.y .. ',' .. squad.currentTarget.z
      if not existingTargets[targetKey] then
        existingTargets[targetKey] = {
          x = squad.currentTarget.x,
          y = squad.currentTarget.y,
          z = squad.currentTarget.z,
          targetID = targetKey
        }
        -- Store any additional metadata if provided
        if squad.currentTarget.unitID then
          targetMetadata[targetKey] = {unitID = squad.currentTarget.unitID}
        end
      end
    end
  end

  -- Convert to array format for assignment function
  local potentialTargets = {}
  for _, target in pairs(existingTargets) do
    potentialTargets[#potentialTargets + 1] = target
  end

  if #potentialTargets == 0 then
    return {}
  end

  -- Create squad position data for assignment
  local squadPositions = {}
  for _, squad in ipairs(squadData) do
    if squad.squadID and squad.x and squad.y and squad.z then
      squadPositions[#squadPositions + 1] = {
        squadID = squad.squadID,
        x = squad.x,
        y = squad.y,
        z = squad.z,
        squad = squad
      }
    end
  end

  if #squadPositions == 0 then
    return {}
  end

  -- Get optimized assignments
  local assignments =
    PveTargeting.GetGreedyAssignment(
    squadPositions,
    potentialTargets,
    {
      allowMultipleUnitsPerTarget = options.allowMultipleUnitsPerTarget or false,
      maxDistance = options.maxDistance or math.huge
    }
  )

  -- Enhance assignments with metadata
  for squadID, assignment in pairs(assignments) do
    local metadata = targetMetadata[assignment.targetID]
    if metadata then
      assignment.metadata = metadata
    end
  end

  return assignments
end

-- Get optimized unit assignments for a list of units and potential targets
-- @param context: PveTargeting context object
-- @param units: table of units with position data
-- @param options: optional configuration {maxDistance, targetType, etc.}
-- @return: table mapping unitID -> target assignment
function PveTargeting.GetOptimizedAssignments(context, units, options)
  options = options or {}

  if not units or #units == 0 then
    return {}
  end

  -- Get potential targets using existing targeting system
  local potentialTargets = getPotentialTargets(context)

  -- Filter targets by type if specified
  if options.targetType then
    local filtered = {}
    for _, target in ipairs(potentialTargets) do
      local unitDef = target.unitDef
      if options.targetType == 'mobile' and unitDef.canMove then
        table.insert(filtered, target)
      elseif options.targetType == 'structure' and not unitDef.canMove then
        table.insert(filtered, target)
      elseif options.targetType == 'factory' and unitDef.isFactory then
        table.insert(filtered, target)
      elseif
        options.targetType == 'eco' and (unitDef.metalMake > 0 or unitDef.energyMake > 0 or unitDef.extractsMetal > 0)
       then
        table.insert(filtered, target)
      end
    end
    potentialTargets = filtered
  end

  if #potentialTargets == 0 then
    return {}
  end

  -- Convert units to proper format if needed
  local formattedUnits = {}
  for i, unit in ipairs(units) do
    if type(unit) == 'number' then
      -- Assume it's a unitID, get position
      local x, y, z = Spring.GetUnitBasePosition(unit)
      if x then
        table.insert(
          formattedUnits,
          {
            unitID = unit,
            x = x,
            y = y,
            z = z
          }
        )
      end
    elseif unit.unitID and unit.x then
      -- Already properly formatted
      table.insert(formattedUnits, unit)
    end
  end

  -- Get greedy assignment
  local assignments = PveTargeting.GetGreedyAssignment(formattedUnits, potentialTargets)

  -- Filter by maximum distance if specified
  if options.maxDistance then
    for unitID, assignment in pairs(assignments) do
      if assignment.distance > options.maxDistance then
        assignments[unitID] = nil
      end
    end
  end

  return assignments
end

return PveTargeting
