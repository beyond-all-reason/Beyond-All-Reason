local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")

local ResourceType = SharedEnums.ResourceType
local RESOURCE_TYPES = SharedEnums.ResourceTypes

local Gadgets = {}
Gadgets.__index = Gadgets

local EPSILON = 1e-6
local tracyAvailable = tracy and tracy.ZoneBeginN and tracy.ZoneEnd

local memberCache = {} ---@type table<number, EconomyShareMember>
local groupCache = {} ---@type table<number, EconomyShareMember[]>
local groupSizes = {} ---@type table<number, number>
local teamLedgerCache = {} ---@type table<number, table<ResourceType, EconomyFlowLedger>>
local cumulativeCache = {} ---@type table<number, table<ResourceType, number>>
local cppMembersCache = {} ---@type table[]
local teamIdMapCache = {} ---@type number[]

---@param value number?
---@return number
local function normalizeSlider(value)
  if type(value) ~= "number" then
    return 0
  end
  if value > 1 then
    value = value * 0.01
  end
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

---@param teamsList table<number, TeamResourceData>
---@param resourceType ResourceType
---@param thresholds table<ResourceType, number>
---@param springRepo ISpring
---@return table<number, EconomyShareMember[]>, table<number, number>
local function collectMembers(teamsList, resourceType, thresholds, springRepo)
  for allyTeam in pairs(groupCache) do
    groupSizes[allyTeam] = 0
  end

  local field = resourceType == ResourceType.METAL and ResourceType.METAL or ResourceType.ENERGY
  local threshold = thresholds[resourceType]
  for teamId, team in pairs(teamsList) do
    if not team.isDead then
      local resource = team[field]
      if resource then
        local allyTeam = team.allyTeam
        local storage = resource.storage
        local excess = resource.excess
        local current = resource.current + excess
        local shareCursor = storage * normalizeSlider(resource.shareSlider)
        if shareCursor > storage then
          shareCursor = storage
        end
        local cumulativeSent = ResourceShared.GetPassiveCumulativeSent(teamId, resourceType, springRepo)
        local remaining = threshold - cumulativeSent
        if remaining < 0 then remaining = 0 end

        local member = memberCache[teamId]
        if not member then
          member = {}
          memberCache[teamId] = member
        end
        member.teamId = teamId
        member.allyTeam = allyTeam
        member.resourceType = resourceType
        member.resource = resource
        member.current = current
        member.storage = storage
        member.shareCursor = shareCursor
        member.remainingTaxFreeAllowance = remaining
        member.cumulativeSent = cumulativeSent
        member.threshold = threshold

        local group = groupCache[allyTeam]
        if not group then
          group = {}
          groupCache[allyTeam] = group
        end
        local size = (groupSizes[allyTeam] or 0) + 1
        groupSizes[allyTeam] = size
        group[size] = member
      end
    end
  end
  return groupCache, groupSizes
end

local LIFT_ITERATIONS = 32

local function effectiveSupply(m, target, rate)
  if m.current <= target + EPSILON then return 0 end
  local grossDelta = m.current - target
  local taxFree = math.min(grossDelta, m.remainingTaxFreeAllowance or 0)
  local taxable = math.max(0, grossDelta - (m.remainingTaxFreeAllowance or 0))
  local afterTax = taxable * (1 - rate)
  return taxFree + afterTax
end

local function demand(m, target)
  if m.current >= target - EPSILON then return 0 end
  return target - m.current
end

local function balance(mems, memberCount, lift, rate)
  local supply, dem = 0, 0
  for i = 1, memberCount do
    local m = mems[i]
    local target = math.min(m.shareCursor + lift, m.storage)
    supply = supply + effectiveSupply(m, target, rate)
    dem = dem + demand(m, target)
  end
  return supply - dem
end

local function calcGrossForEffective(effective, allowance, taxRate)
  if taxRate >= 1 - EPSILON then
    return math.min(effective, allowance)
  end
  if effective <= allowance then
    return effective
  end
  local taxableAfterTax = effective - allowance
  local taxablePre = taxableAfterTax / (1 - taxRate)
  return allowance + taxablePre
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param taxRate number
---@return number lift
---@return table deltas
local function solveWaterfill(members, memberCount, taxRate)
  if memberCount == 0 then
    return 0, {}
  end

  local maxLift = 0
  for i = 1, memberCount do
    local m = members[i]
    local headroom = m.storage - m.shareCursor
    if headroom > maxLift then maxLift = headroom end
  end

  local lo, hi = 0, maxLift
  for _ = 1, LIFT_ITERATIONS do
    local mid = 0.5 * (lo + hi)
    if balance(members, memberCount, mid, taxRate) >= 0 then
      lo = mid
    else
      hi = mid
    end
  end
  local lift = lo

  local totalSupply, totalDemand = 0, 0
  local senderData = {}
  local receiverData = {}

  for i = 1, memberCount do
    local m = members[i]
    local target = math.min(m.shareCursor + lift, m.storage)
    if m.current > target + EPSILON then
      local eff = effectiveSupply(m, target, taxRate)
      senderData[i] = { idx = i, member = m, target = target, effective = eff }
      totalSupply = totalSupply + eff
    elseif m.current < target - EPSILON then
      local dem = demand(m, target)
      receiverData[i] = { idx = i, member = m, target = target, demand = dem }
      totalDemand = totalDemand + dem
    end
  end

  local flowRatio = 1
  if totalDemand > EPSILON and totalSupply < totalDemand - EPSILON then
    flowRatio = totalSupply / totalDemand
  end

  local deltas = {}

  for i, sd in pairs(senderData) do
    local m = sd.member
    local d = { gross = 0, net = 0, taxed = 0 }
    local eff = sd.effective
    local allowance = m.remainingTaxFreeAllowance or 0
    local grossSend = calcGrossForEffective(eff, allowance, taxRate)
    d.gross = -grossSend
    local taxFree = math.min(grossSend, allowance)
    local taxable = math.max(0, grossSend - allowance)
    d.taxed = taxable * taxRate
    d.net = -(taxFree + taxable - d.taxed)
    if math.abs(d.gross) >= EPSILON then
      deltas[i] = d
    end
  end

  for i, rd in pairs(receiverData) do
    local d = { gross = 0, net = 0, taxed = 0 }
    local received = rd.demand * flowRatio
    d.gross = received
    d.net = received
    if math.abs(d.gross) >= EPSILON then
      deltas[i] = d
    end
  end

  return lift, deltas
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param taxRate number
---@return number lift
---@return table deltas
local function solveWithCppOrLua(members, memberCount, taxRate)
  -- Use C++ solver if available, otherwise pure Lua
  if Spring and Spring.SolveWaterfill then
    for i = memberCount + 1, #cppMembersCache do
      cppMembersCache[i] = nil
    end
    for i = memberCount + 1, #teamIdMapCache do
      teamIdMapCache[i] = nil
    end

    for i = 1, memberCount do
      local m = members[i]
      local entry = cppMembersCache[i]
      if not entry then
        entry = {}
        cppMembersCache[i] = entry
      end
      entry.current = m.current
      entry.storage = m.storage
      entry.shareTarget = m.shareCursor
      entry.allowance = m.remainingTaxFreeAllowance
      teamIdMapCache[i] = m.teamId
    end

    local result = Spring.SolveWaterfill(cppMembersCache, taxRate)
    return result.lift, result.deltas
  end

  return solveWaterfill(members, memberCount, taxRate)
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param lift number
---@param deltas table
---@param taxRate number
---@return table<number, EconomyFlowLedger>
local function applyDeltas(members, memberCount, lift, deltas, taxRate)
  local ledgerCache = {}

  for i = 1, memberCount do
    local member = members[i]
    local teamId = member.teamId
    local delta = deltas[i]

    local ledger = ledgerCache[teamId]
    if not ledger then
      ledger = { sent = 0, received = 0, untaxed = 0, taxed = 0 }
      ledgerCache[teamId] = ledger
    end

    local target = member.shareCursor + lift
    if target > member.storage then
      target = member.storage
    end
    member.target = target

    if delta and math.abs(delta.gross) > EPSILON then
      local resource = member.resource
      if delta.gross < 0 then
        local grossSend = -delta.gross
        local taxFree = math.min(grossSend, member.remainingTaxFreeAllowance)
        local taxable = grossSend - taxFree
        if taxable < 0 then taxable = 0 end
        local taxedReceivable = taxable * (1 - taxRate)

        local newCurrent = member.current - grossSend
        if newCurrent < 0 then newCurrent = 0 end
        if newCurrent > member.storage then newCurrent = member.storage end
        resource.current = newCurrent

        local allowance = member.remainingTaxFreeAllowance - taxFree
        member.remainingTaxFreeAllowance = allowance > 0 and allowance or 0
        member.cumulativeSent = member.cumulativeSent + grossSend

        ledger.sent = grossSend
        ledger.untaxed = taxFree
        ledger.taxed = taxedReceivable
      else
        local received = delta.net
        local newCurrent = member.current + received
        if newCurrent > member.storage then newCurrent = member.storage end
        resource.current = newCurrent

        ledger.received = received
      end
    end
  end

  for i = 1, memberCount do
    local member = members[i]
    local resource = member.resource
    if resource.current > member.storage then
      EconomyLog.StorageCapped(member.teamId, member.resourceType, resource.current, member.storage)
      resource.current = member.storage
    end
  end

  return ledgerCache
end

---@param springRepo ISpring
---@param updates table<number, table<ResourceType, number>>
local function updateCumulative(springRepo, updates)
  for teamId, perResource in pairs(updates) do
    for resourceType, value in pairs(perResource) do
      local key = ResourceShared.GetPassiveCumulativeParam(resourceType)
      springRepo.SetTeamRulesParam(teamId, key, value)
    end
  end
end

---@param springRepo ISpring
---@param teamsList table<number, TeamResourceData>
---@return table<number, TeamResourceData>
---@return EconomyFlowSummary
function Gadgets.Solve(springRepo, teamsList)
  if tracyAvailable then tracy.ZoneBeginN("WaterfillSolver.Solve") end

  if not teamsList then
    if tracyAvailable then tracy.ZoneEnd() end
    return teamsList, {}
  end

  local teamCount = 0
  for _ in pairs(teamsList) do teamCount = teamCount + 1 end
  if teamCount == 0 then
    if tracyAvailable then tracy.ZoneEnd() end
    return teamsList, {}
  end

  local taxRate, thresholds = SharedConfig.getTaxConfig(springRepo)

  for teamId in pairs(cumulativeCache) do
    local perResource = cumulativeCache[teamId]
    perResource[ResourceType.METAL] = nil
    perResource[ResourceType.ENERGY] = nil
  end

  for teamId in pairs(teamsList) do
    local teamLedger = teamLedgerCache[teamId]
    if not teamLedger then
      teamLedger = {
        [ResourceType.METAL] = {},
        [ResourceType.ENERGY] = {},
      }
      teamLedgerCache[teamId] = teamLedger
    end
    local m = teamLedger[ResourceType.METAL]
    m.sent = 0
    m.received = 0
    m.untaxed = 0
    m.taxed = 0
    local e = teamLedger[ResourceType.ENERGY]
    e.sent = 0
    e.received = 0
    e.untaxed = 0
    e.taxed = 0
  end

  for _, resourceType in ipairs(RESOURCE_TYPES) do
    if tracyAvailable then tracy.ZoneBeginN("CollectMembers:" .. resourceType) end
    local groups, sizes = collectMembers(teamsList, resourceType, thresholds, springRepo)
    if tracyAvailable then tracy.ZoneEnd() end

    for allyTeam, members in pairs(groups) do
      local memberCount = sizes[allyTeam] or 0
      if memberCount > 0 then
        for i = 1, memberCount do
          local m = members[i]
          local shareSliderNormalized = m.shareCursor / math.max(1, m.storage)
          EconomyLog.TeamInput(m.teamId, m.allyTeam, resourceType, m.current, m.storage, shareSliderNormalized, m.cumulativeSent, m.shareCursor)
        end

        local lift, deltas = solveWithCppOrLua(members, memberCount, taxRate)

        if tracyAvailable and tracy.LuaTracyPlot then
          tracy.LuaTracyPlot("Economy/Lift/" .. resourceType, lift)
        end

        local totalSupply, totalDemand = 0, 0
        local senderCount, receiverCount = 0, 0
        for i = 1, memberCount do
          local m = members[i]
          local target = m.shareCursor + lift
          if target > m.storage then target = m.storage end
          local delta = deltas[i]
          local role, deltaVal
          if delta and delta.gross < -EPSILON then
            totalSupply = totalSupply + (-delta.net)
            role = "sender"
            deltaVal = -delta.gross
            senderCount = senderCount + 1
          elseif delta and delta.gross > EPSILON then
            totalDemand = totalDemand + delta.gross
            role = "receiver"
            deltaVal = delta.gross
            receiverCount = receiverCount + 1
          else
            role = "neutral"
            deltaVal = 0
          end
          EconomyLog.TeamWaterfill(m.teamId, allyTeam, resourceType, m.current, target, role, deltaVal)
        end
        EconomyLog.GroupLift(allyTeam, resourceType, lift, memberCount, totalSupply, totalDemand, senderCount, receiverCount)

        if tracyAvailable then tracy.ZoneBeginN("ApplyDeltas") end
        local ledgers = applyDeltas(members, memberCount, lift, deltas, taxRate)
        if tracyAvailable then tracy.ZoneEnd() end

        for i = 1, memberCount do
          local member = members[i]
          local teamId = member.teamId
          local ledger = ledgers[teamId]
          if ledger then
            local summary = teamLedgerCache[teamId][resourceType]
            summary.sent = summary.sent + ledger.sent
            summary.received = summary.received + ledger.received
            summary.untaxed = summary.untaxed + (ledger.untaxed or 0)
            summary.taxed = summary.taxed + (ledger.taxed or 0)

            if ledger.sent > EPSILON then
              local perResource = cumulativeCache[teamId]
              if not perResource then
                perResource = {}
                cumulativeCache[teamId] = perResource
              end
              perResource[resourceType] = member.cumulativeSent
            end
          end
        end
      end
    end
  end

  for teamId, team in pairs(teamsList) do
    local ledger = teamLedgerCache[teamId]
    if team.metal then
      local m = ledger[ResourceType.METAL]
      team.metal.sent = m.sent
      team.metal.received = m.received
      EconomyLog.TeamOutput(teamId, ResourceType.METAL, team.metal.current, m.sent, m.received)
    end
    if team.energy then
      local e = ledger[ResourceType.ENERGY]
      team.energy.sent = e.sent
      team.energy.received = e.received
      EconomyLog.TeamOutput(teamId, ResourceType.ENERGY, team.energy.current, e.sent, e.received)
    end
  end

  if next(cumulativeCache) then
    updateCumulative(springRepo, cumulativeCache)
  end

  if tracyAvailable then tracy.ZoneEnd() end
  return teamsList, teamLedgerCache
end

local resultPool = {}
local resultPoolSize = 0

local function getPooledResult(teamId, resourceType)
  local key = teamId * 10 + (resourceType == ResourceType.METAL and 1 or 2)
  local entry = resultPool[key]
  if not entry then
    entry = { teamId = 0, resourceType = "", current = 0, sent = 0, received = 0 }
    resultPool[key] = entry
    resultPoolSize = resultPoolSize + 1
  end
  return entry
end

---@param springRepo ISpring
---@param teamsList table<number, TeamResourceData>
---@return EconomyTeamResult[]
function Gadgets.SolveToResults(springRepo, teamsList)
  if tracyAvailable then tracy.ZoneBeginN("WaterfillSolver.SolveToResults") end

  local updatedTeams, allLedgers = Gadgets.Solve(springRepo, teamsList)
  
  local results = {}
  local idx = 0
  
  for teamId, team in pairs(updatedTeams) do
    local ledger = allLedgers[teamId]
    
    if team.metal then
      idx = idx + 1
      local entry = getPooledResult(teamId, ResourceType.METAL)
      entry.teamId = teamId
      entry.resourceType = ResourceType.METAL
      entry.current = team.metal.current
      entry.sent = ledger[ResourceType.METAL].sent
      entry.received = ledger[ResourceType.METAL].received
      results[idx] = entry
    end
    
    if team.energy then
      idx = idx + 1
      local entry = getPooledResult(teamId, ResourceType.ENERGY)
      entry.teamId = teamId
      entry.resourceType = ResourceType.ENERGY
      entry.current = team.energy.current
      entry.sent = ledger[ResourceType.ENERGY].sent
      entry.received = ledger[ResourceType.ENERGY].received
      results[idx] = entry
    end
  end
  
  if tracyAvailable then tracy.ZoneEnd() end
  return results
end

return Gadgets
