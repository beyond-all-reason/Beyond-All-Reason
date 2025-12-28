local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local EconomyLog = VFS.Include("common/luaUtilities/economy/economy_log.lua")
local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")

local ResourceType = SharedEnums.ResourceType
local RESOURCE_TYPES = SharedEnums.ResourceTypes

local Gadgets = {}
Gadgets.__index = Gadgets

local EPSILON = 1e-6
local LIFT_ITERATIONS = 40

---@class SenderDescriptor
---@field member EconomyShareMember
---@field costBudget number
---@field untaxedSupply number
---@field taxedReceivable number
---@field costSpent number
---@field untaxedDelivered number
---@field taxedDelivered number
---@field ledger EconomyFlowLedger

---@class ReceiverDescriptor
---@field member EconomyShareMember
---@field need number
---@field received number
---@field unsatisfied number?
---@field ledger EconomyFlowLedger

local memberCache = {} ---@type table<number, EconomyShareMember>
local groupCache = {} ---@type table<number, EconomyShareMember[]>
local groupSizes = {} ---@type table<number, number>
local ledgerCache = {} ---@type table<number, EconomyFlowLedger>
local senderDescCache = {} ---@type table<number, SenderDescriptor>
local receiverDescCache = {} ---@type table<number, ReceiverDescriptor>
local teamLedgerCache = {} ---@type table<number, table<ResourceType, EconomyFlowLedger>>
local cumulativeCache = {} ---@type table<number, table<ResourceType, number>>

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
        local cumulativeSent = ResourceShared.GetCumulativeSent(teamId, resourceType, springRepo)
        local remaining = math.max(0, threshold - cumulativeSent)

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

---@param member EconomyShareMember
---@param target number
---@param taxRate number
---@return number
local function supplyDelta(member, target, taxRate)
  if member.current <= target + EPSILON then
    return 0
  end
  local costBudget = member.current - target
  local untaxedBudget = math.min(costBudget, member.remainingTaxFreeAllowance)
  local taxedCostBudget = costBudget - untaxedBudget
  if taxedCostBudget < 0 then
    taxedCostBudget = 0
  end
  local receivable = untaxedBudget
  if taxRate < 1 and taxedCostBudget > 0 then
    receivable = receivable + taxedCostBudget * (1 - taxRate)
  end
  return receivable
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param taxRate number
---@return number
local function resolveLift(members, memberCount, taxRate)
  if memberCount == 0 then
    return 0
  end
  local maxLift = 0
  for i = 1, memberCount do
    local headroom = members[i].storage - members[i].shareCursor
    if headroom > maxLift then
      maxLift = headroom
    end
  end
  local function balance(lift)
    local supply = 0
    local demand = 0
    for i = 1, memberCount do
      local member = members[i]
      local target = member.shareCursor + lift
      if target > member.storage then
        target = member.storage
      end
      if member.current < target - EPSILON then
        demand = demand + (target - member.current)
      else
        supply = supply + supplyDelta(member, target, taxRate)
      end
    end
    return supply - demand
  end
  local lo, hi = 0, maxLift
  for _ = 1, LIFT_ITERATIONS do
    local mid = 0.5 * (lo + hi)
    if balance(mid) >= 0 then
      lo = mid
    else
      hi = mid
    end
  end
  return lo
end

---@param members EconomyShareMember[]
---@param memberCount number
---@param lift number
---@param taxRate number
---@return table<number, EconomyFlowLedger>
local function allocateGroup(members, memberCount, lift, taxRate)
  local senders = {}
  local receivers = {}
  local senderCount = 0
  local receiverCount = 0

  for i = 1, memberCount do
    local member = members[i]
    local teamId = member.teamId

    local ledger = ledgerCache[teamId]
    if not ledger then
      ledger = {}
      ledgerCache[teamId] = ledger
    end
    ledger.sent = 0
    ledger.received = 0
    ledger.untaxed = 0
    ledger.taxed = 0

    local target = member.shareCursor + lift
    if target > member.storage then
      target = member.storage
    end
    member.target = target

    if member.current > target + EPSILON then
      local costBudget = member.current - target
      local untaxedBudget = math.min(costBudget, member.remainingTaxFreeAllowance)
      local taxedCostBudget = costBudget - untaxedBudget
      if taxedCostBudget < 0 then
        taxedCostBudget = 0
      end
      local taxedReceivable = 0
      if taxRate < 1 and taxedCostBudget > 0 then
        taxedReceivable = taxedCostBudget * (1 - taxRate)
      end

      senderCount = senderCount + 1
      local desc = senderDescCache[teamId]
      if not desc then
        desc = {}
        senderDescCache[teamId] = desc
      end
      desc.member = member
      desc.costBudget = costBudget
      desc.untaxedSupply = untaxedBudget
      desc.taxedReceivable = taxedReceivable
      desc.costSpent = 0
      desc.untaxedDelivered = 0
      desc.taxedDelivered = 0
      desc.ledger = ledger
      senders[senderCount] = desc
    elseif target > member.current + EPSILON then
      receiverCount = receiverCount + 1
      local desc = receiverDescCache[teamId]
      if not desc then
        desc = {}
        receiverDescCache[teamId] = desc
      end
      desc.member = member
      desc.need = target - member.current
      desc.received = 0
      desc.ledger = ledger
      receivers[receiverCount] = desc
    end
  end

  if receiverCount > 0 and senderCount > 0 then
    for r = 1, receiverCount do
      local receiver = receivers[r]
      local remainingNeed = receiver.need
      for s = 1, senderCount do
        if remainingNeed <= EPSILON then
          break
        end

        local sender = senders[s]
        local take = 0
        if sender.untaxedSupply > EPSILON then
          take = math.min(remainingNeed, sender.untaxedSupply)
          sender.untaxedSupply = sender.untaxedSupply - take
          sender.costSpent = sender.costSpent + take
          sender.untaxedDelivered = sender.untaxedDelivered + take
          receiver.received = receiver.received + take
          remainingNeed = remainingNeed - take
        end

        if remainingNeed <= EPSILON then
          if take > EPSILON then
            EconomyLog.Transfer(sender.member.teamId, receiver.member.teamId, sender.member.resourceType, take, take, 0)
          end
          break
        end

        if sender.taxedReceivable > EPSILON and taxRate < 1 then
          local deliver = math.min(remainingNeed, sender.taxedReceivable)
          sender.taxedReceivable = sender.taxedReceivable - deliver
          sender.taxedDelivered = sender.taxedDelivered + deliver
          local cost = deliver / (1 - taxRate)
          sender.costSpent = sender.costSpent + cost
          receiver.received = receiver.received + deliver
          remainingNeed = remainingNeed - deliver

          local transferAmount = take + deliver
          if transferAmount > EPSILON then
            EconomyLog.Transfer(sender.member.teamId, receiver.member.teamId, sender.member.resourceType, transferAmount, take, deliver)
          end
        elseif take > EPSILON then
          EconomyLog.Transfer(sender.member.teamId, receiver.member.teamId, sender.member.resourceType, take, take, 0)
        end
      end
      receiver.unsatisfied = remainingNeed
    end
  end

  for i = 1, senderCount do
    local sender = senders[i]
    local member = sender.member
    local resource = member.resource
    local ledger = sender.ledger
    if sender.costSpent > 0 then
      local newCurrent = member.current - sender.costSpent
      if newCurrent < 0 then
        newCurrent = 0
      end
      if newCurrent > member.storage then
        newCurrent = member.storage
      end
      resource.current = newCurrent
      local allowance = member.remainingTaxFreeAllowance - sender.untaxedDelivered
      member.remainingTaxFreeAllowance = allowance > 0 and allowance
      member.cumulativeSent = member.cumulativeSent + sender.costSpent
      ledger.sent = sender.costSpent
      ledger.untaxed = sender.untaxedDelivered
      ledger.taxed = sender.taxedDelivered
    end
  end

  for i = 1, receiverCount do
    local receiver = receivers[i]
    local member = receiver.member
    local resource = member.resource
    local ledger = receiver.ledger
    if receiver.received > 0 then
      local newCurrent = member.current + receiver.received
      if newCurrent > member.storage then
        newCurrent = member.storage
      end
      resource.current = newCurrent
      ledger.received = receiver.received
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
      local key = ResourceShared.GetCumulativeParam(resourceType)
      springRepo.SetTeamRulesParam(teamId, key, value)
    end
  end
end

---@param springRepo ISpring
---@param teamsList table<number, TeamResourceData>
---@return table<number, TeamResourceData>
---@return EconomyFlowSummary
function Gadgets.Solve(springRepo, teamsList)
  if not teamsList then
    return teamsList, {}
  end
  
  local teamCount = 0
  for _ in pairs(teamsList) do teamCount = teamCount + 1 end
  if teamCount == 0 then
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
    local groups, sizes = collectMembers(teamsList, resourceType, thresholds, springRepo)
    for allyTeam, members in pairs(groups) do
      local memberCount = sizes[allyTeam] or 0
      if memberCount > 0 then
        for i = 1, memberCount do
          local m = members[i]
          local shareSliderNormalized = m.shareCursor / math.max(1, m.storage)
          EconomyLog.TeamInput(m.teamId, m.allyTeam, resourceType, m.current, m.storage, shareSliderNormalized, m.cumulativeSent, m.shareCursor)
        end

        local lift = resolveLift(members, memberCount, taxRate)

        local totalSupply, totalDemand = 0, 0
        local senderCount, receiverCount = 0, 0
        for i = 1, memberCount do
          local m = members[i]
          local target = m.shareCursor + lift
          if target > m.storage then target = m.storage end
          local role, delta
          if m.current > target + EPSILON then
            totalSupply = totalSupply + supplyDelta(m, target, taxRate)
            role = "sender"
            delta = m.current - target
            senderCount = senderCount + 1
          elseif target > m.current + EPSILON then
            totalDemand = totalDemand + (target - m.current)
            role = "receiver"
            delta = target - m.current
            receiverCount = receiverCount + 1
          else
            role = "neutral"
            delta = 0
          end
          EconomyLog.TeamWaterfill(m.teamId, allyTeam, resourceType, m.current, target, role, delta)
        end
        EconomyLog.GroupLift(allyTeam, resourceType, lift, memberCount, totalSupply, totalDemand, senderCount, receiverCount)

        local ledgers = allocateGroup(members, memberCount, lift, taxRate)

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
      EconomyLog.TeamOutput(teamId, ResourceType.METAL, team.metal.current, m.sent, m.received)
    end
    if team.energy then
      local e = ledger[ResourceType.ENERGY]
      EconomyLog.TeamOutput(teamId, ResourceType.ENERGY, team.energy.current, e.sent, e.received)
    end
  end

  if next(cumulativeCache) then
    updateCumulative(springRepo, cumulativeCache)
  end

  return teamsList, teamLedgerCache
end

return Gadgets