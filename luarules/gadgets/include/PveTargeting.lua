-- Targeting Library for Scavengers and Raptors
-- Provides weighted target selection based on various criteria

local PveTargeting = {}

-- Default weights (all max priority)
local DEFAULT_WEIGHTS = {
  evenPlayerSpread = 1.0,
  eco = 1.0,
  tech = 1.0,
  damageEfficiencyAreas = 1.0,
  unitRandom = 0.0,
  areaRandom = 0.0
}

-- Gadget-level default weights (can be overridden by each gadget)
local gadgetWeights = nil

-- Weight priority: modoption > customparam > gadget > default
local function getEffectiveWeights(modoptions, customParams, gadgetOverride)
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

  -- Apply custom params (medium priority)
  if customParams and customParams.targeting_weights and VFS then
    local success, parsedWeights = pcall(Json.decode, customParams.targeting_weights)
    if success and parsedWeights and type(parsedWeights) == 'table' then
      for key, value in pairs(parsedWeights) do
        if weights[key] ~= nil and type(value) == 'number' then
          weights[key] = math.max(0, math.min(1, value))
        end
      end
    end
  end

  if modoptions then
    local modoptionMapping = {
      scav_targeting_eco = 'eco',
      scav_targeting_tech = 'tech',
      scav_targeting_even_player_spread = 'evenPlayerSpread',
      scav_targeting_damage_efficiency_areas = 'damageEfficiencyAreas',
      scav_targeting_random = 'unitRandom'
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

    -- Also apply the random factor to areaRandom for position-based randomness
    local randomValue = modoptions.scav_targeting_random
    if randomValue ~= nil and randomValue ~= '' then
      local numValue = tonumber(randomValue)
      if numValue then
        weights.areaRandom = math.max(0, math.min(1, numValue))
      end
    end
  end

  return weights
end

-- Initialize targeting system
function PveTargeting.Initialize(teamID, allyTeamID, options)
  options = options or {}

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

  local weights = getEffectiveWeights(Spring.GetModOptions(), nil, options.gadgetWeights)

  Spring.Echo(
    'Initializing PveTargeting with ' .. numTilesX .. 'x' .. numTilesZ .. ' tiles and weights: ' .. Json.encode(weights)
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
    targetCache = {},
    cacheValidUntil = 0
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

-- Get all potential targets with caching
local function getPotentialTargets(context, maxAge)
  maxAge = maxAge or (10 * Game.gameSpeed) -- 10 seconds default cache
  local currentFrame = Spring.GetGameFrame()

  if currentFrame < context.cacheValidUntil then
    return context.targetCache
  end

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

  -- Collect only eco buildings and commanders from valid teams (excludes caller + gaia allyteams)
  for teamID, _ in pairs(validTeams) do
    local teamUnits = Spring.GetTeamUnits(teamID)
    for _, unitID in ipairs(teamUnits) do
      if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
        local unitDefID = Spring.GetUnitDefID(unitID)
        local unitDef = UnitDefs[unitDefID]
        local x, y, z = Spring.GetUnitPosition(unitID)

        if x and unitDefID and unitDef then
          local isEco =
            unitDef.metalMake > 0 or unitDef.energyMake > 0 or unitDef.extractsMetal > 0 or unitDef.energyUpkeep < 0 or
            (unitDef.customParams and unitDef.customParams.metal_extractor)
          -- Only include non-mobile units (buildings) and commanders
          if (isEco and not unitDef.canMove) or (unitDef.customParams and unitDef.customParams.iscommander) then
            table.insert(
              targets,
              {
                unitID = unitID,
                unitDefID = unitDefID,
                teamID = teamID,
                x = x,
                y = y,
                z = z,
                unitDef = unitDef
              }
            )
          end
        end
      end
    end
  end

  context.targetCache = targets
  context.cacheValidUntil = currentFrame + maxAge

  return targets
end

-- Calculate raw economic value for a target
local function calculateRawEcoValue(target)
  if not target.unitDef then
    return 0
  end

  local unitDef = target.unitDef
  local score = 0

  -- Metal/Energy production
  if unitDef.metalMake and unitDef.metalMake > 0 then
    score = score + unitDef.metalMake * 60
  end

  if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
    score = score + unitDef.extractsMetal * 60
  end

  if unitDef.energyMake and unitDef.energyMake > 0 then
    score = score + unitDef.energyMake
  end

  if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
    score = score - unitDef.energyUpkeep
  end

  if unitDef.windGenerator and unitDef.windGenerator > 0 then
    score = score + unitDef.windGenerator * 0.75
  end

  if unitDef.tidalGenerator and unitDef.tidalGenerator > 0 then
    score = score + unitDef.tidalGenerator * 15
  end

  if
    unitDef.customParams and unitDef.customParams.energyconv_capacity and
      tonumber(unitDef.customParams.energyconv_capacity) > 0
   then
    score = score + tonumber(unitDef.customParams.energyconv_capacity) / 3
  end

  return score
end

-- Calculate normalized economic score for a target
local function calculateEcoScore(target, minEcoValue, maxEcoValue)
  local rawValue = calculateRawEcoValue(target)

  -- Normalize to 0-1 range using actual min/max values
  if maxEcoValue > minEcoValue then
    return (rawValue - minEcoValue) / (maxEcoValue - minEcoValue)
  else
    return rawValue > 0 and 1.0 or 0.0
  end
end

-- Calculate raw tech level for a target
local function calculateRawTechLevel(target)
  if not target.unitDef or not target.unitDef.customParams then
    return 1
  end

  return tonumber(target.unitDef.customParams.techlevel) or 1
end

-- Calculate normalized tech level score for a target
local function calculateTechScore(target, minTechLevel, maxTechLevel)
  local rawTechLevel = calculateRawTechLevel(target)

  -- Normalize to 0-1 range using actual min/max values
  if maxTechLevel > minTechLevel then
    return (rawTechLevel - minTechLevel) / (maxTechLevel - minTechLevel)
  else
    return rawTechLevel > minTechLevel and 1.0 or 0.0
  end
end

-- Calculate area-based damage efficiency score for a target's position
local function calculateDamageEfficiencyAreaScore(context, target)
  if not target.x or not target.z then
    return 0.5 -- Default neutral score if no position
  end

  local tileX, tileZ = worldToTile(target.x, target.z, context.tileSize)
  local tileKey = getTileKey(tileX, tileZ)

  local areaStats = context.damageAreaStats[tileKey]
  if not areaStats then
    return 0.5 -- Default neutral score for unexplored areas
  end

  -- Higher efficiency = higher score (we want to target areas where we're winning)
  return math.min(1.0, areaStats.efficiency / 2.0)
end

-- Calculate even player spread score (lower = better spread)
local function calculateEvenSpreadScore(context, target)
  if not context.playerTargetCounts[target.teamID] then
    context.playerTargetCounts[target.teamID] = 0
  end

  -- Find minimum target count across all players
  local minCount = math.huge
  local totalCount = 0
  for teamID, count in pairs(context.playerTargetCounts) do
    minCount = math.min(minCount, count)
    totalCount = totalCount + count
  end

  if totalCount == 0 then
    return 1.0
  end

  local currentCount = context.playerTargetCounts[target.teamID]
  local spread = 1.0 - ((currentCount - minCount) / totalCount)

  return math.max(0, spread)
end

-- Calculate combined score for a target
local function calculateTargetScore(context, target, weights, minEcoValue, maxEcoValue, minTechLevel, maxTechLevel)
  local ecoScore = calculateEcoScore(target, minEcoValue, maxEcoValue)
  local techScore = calculateTechScore(target, minTechLevel, maxTechLevel)
  local damageAreaScore = calculateDamageEfficiencyAreaScore(context, target)
  local spreadScore = calculateEvenSpreadScore(context, target)
  local randomScore = math.random() -- For random components

  local totalScore =
    weights.eco * ecoScore + weights.tech * techScore + weights.damageEfficiencyAreas * damageAreaScore +
    weights.evenPlayerSpread * spreadScore +
    weights.unitRandom * randomScore +
    weights.areaRandom * randomScore

  return totalScore
end

-- Get a weighted random target
function PveTargeting.GetRandomTarget(context, options)
  options = options or {}
  local weights = options.weights or context.weights

  -- Get all potential targets
  local candidates = getPotentialTargets(context)
  if #candidates == 0 then
    return nil
  end

  -- Filter candidates by type if specified
  if options.targetType then
    local filtered = {}
    for _, target in ipairs(candidates) do
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
    candidates = filtered
  end

  if #candidates == 0 then
    return nil
  end

  -- Special case: if all weights are 0, return random
  local totalWeight = 0
  for _, weight in pairs(weights) do
    totalWeight = totalWeight + weight
  end
  if totalWeight == 0 then
    return candidates[math.random(#candidates)]
  end

  -- Calculate min/max eco values for normalization
  local minEcoValue = math.huge
  local maxEcoValue = 0
  for _, target in ipairs(candidates) do
    local rawValue = calculateRawEcoValue(target)
    minEcoValue = math.min(minEcoValue, rawValue)
    maxEcoValue = math.max(maxEcoValue, rawValue)
  end

  -- Ensure min is valid
  if minEcoValue == math.huge then
    minEcoValue = 0
  end

  -- Calculate min/max tech levels for normalization
  local minTechLevel = math.huge
  local maxTechLevel = 0
  for _, target in ipairs(candidates) do
    local rawTechLevel = calculateRawTechLevel(target)
    minTechLevel = math.min(minTechLevel, rawTechLevel)
    maxTechLevel = math.max(maxTechLevel, rawTechLevel)
  end

  -- Ensure min is valid
  if minTechLevel == math.huge then
    minTechLevel = 1
  end

  -- Calculate scores and build cumulative weight table
  local total = 0
  local weightedCandidates = {}

  for i, target in ipairs(candidates) do
    local score = calculateTargetScore(context, target, weights, minEcoValue, maxEcoValue, minTechLevel, maxTechLevel)
    total = total + score
    weightedCandidates[i] = {target = target, cumulative = total}
  end

  if total == 0 then
    return candidates[math.random(#candidates)]
  end

  -- Pick a random point on the total score range
  local r = math.random() * total
  for i = 1, #weightedCandidates do
    if r <= weightedCandidates[i].cumulative then
      local selectedTarget = weightedCandidates[i].target

      -- Update target count for even spread tracking
      if not context.playerTargetCounts[selectedTarget.teamID] then
        context.playerTargetCounts[selectedTarget.teamID] = 0
      end
      context.playerTargetCounts[selectedTarget.teamID] = context.playerTargetCounts[selectedTarget.teamID] + 1

      return selectedTarget
    end
  end

  -- Fallback
  return candidates[#candidates]
end

-- Get a random position near a target or general area
function PveTargeting.GetRandomTargetPosition(context, options)
  options = options or {}
  local target = PveTargeting.GetRandomTarget(context, options)

  if target then
    local spread = options.positionSpread or 256
    return {
      x = target.x + math.random(-spread, spread),
      y = target.y,
      z = target.z + math.random(-spread, spread),
      target = target
    }
  else
    -- Fallback to random map position
    local mapSizeX = (Game and Game.mapSizeX) or 4096
    local mapSizeZ = (Game and Game.mapSizeZ) or 4096
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
        local x, y, z = Spring.GetUnitPosition(unitID)
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
      local x, y, z = Spring.GetUnitPosition(unit)
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
