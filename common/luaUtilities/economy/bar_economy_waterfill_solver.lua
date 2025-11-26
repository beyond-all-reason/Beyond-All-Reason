local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local ResourceType = SharedEnums.ResourceType
local RESOURCE_TYPES = SharedEnums.ResourceTypes
local MOD_OPTIONS = SharedEnums.ModOptions

local Gadgets = {}
Gadgets.__index = Gadgets

local EPSILON = 1e-6
local LIFT_ITERATIONS = 40

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

---@param teamsList TeamResourceData[]
local function resetTickFields(teamsList)
  for _, team in ipairs(teamsList) do
    if team.metal then
      team.metal.sent = 0
      team.metal.received = 0
    end
    if team.energy then
      team.energy.sent = 0
      team.energy.received = 0
    end
  end
end

---@param teamsList TeamResourceData[]
---@param resourceType ResourceType
---@param policies table<number, table<ResourceType, ResourcePolicyResult>>
---@param springRepo ISpring
---@return table<number, EconomyShareMember[]>
local function collectMembers(teamsList, resourceType, policies, springRepo)
  local grouped = {}
  local field = resourceType == ResourceType.METAL and "metal" or "energy"
  for _, team in ipairs(teamsList) do
    if not team.isDead then
      local teamId = team.id
      if teamId then
        local resource = team[field]
        if resource then
          local storage = math.max(0, resource.storage or 0)
          local current = math.max(0, resource.current or 0)
          local shareCursor = storage * normalizeSlider(resource.shareSlider or 0)
          if shareCursor > storage then
            shareCursor = storage
          end
          
          local policy = policies[teamId] and policies[teamId][resourceType]
          local remaining = 0
          local taxRate = 0
          
          if policy then
             remaining = policy.remainingTaxFreeAllowance
             taxRate = policy.taxRate
          end
          
          local group = grouped[team.allyTeam]
          if group == nil then
            group = {}
            grouped[team.allyTeam] = group
          end
          group[#group + 1] = {
            teamId = teamId,
            allyTeam = team.allyTeam,
            resourceType = resourceType,
            resource = resource,
            current = current,
            storage = storage,
            shareCursor = shareCursor,
            remainingTaxFreeAllowance = remaining,
            taxRate = taxRate,
          }
        end
      end
    end
  end
  return grouped
end

---@param member EconomyShareMember
---@param target number
---@return number
local function supplyDelta(member, target)
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
  if member.taxRate < 1 and taxedCostBudget > 0 then
    receivable = receivable + taxedCostBudget * (1 - member.taxRate)
  end
  return receivable
end

---@param members EconomyShareMember[]
---@return number
local function resolveLift(members)
  if #members == 0 then
    return 0
  end
  local maxLift = 0
  for i = 1, #members do
    local headroom = members[i].storage - members[i].shareCursor
    if headroom > maxLift then
      maxLift = headroom
    end
  end
  local function balance(lift)
    local supply = 0
    local demand = 0
    for i = 1, #members do
      local member = members[i]
      local target = member.shareCursor + lift
      if target > member.storage then
        target = member.storage
      end
      if member.current < target - EPSILON then
        demand = demand + (target - member.current)
      else
        supply = supply + supplyDelta(member, target)
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
---@param lift number
---@return table<number, EconomyFlowLedger>
local function allocateGroup(members, lift)
  local senders = {}
  local receivers = {}
  local ledgers = {}

  for i = 1, #members do
    local member = members[i]
    local ledger = { sent = 0, received = 0, untaxed = 0, taxed = 0 }
    ledgers[member.teamId] = ledger
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
      if member.taxRate < 1 and taxedCostBudget > 0 then
        taxedReceivable = taxedCostBudget * (1 - member.taxRate)
      end
      senders[#senders + 1] = {
        member = member,
        costBudget = costBudget,
        untaxedSupply = untaxedBudget,
        taxedReceivable = taxedReceivable,
        costSpent = 0,
        untaxedDelivered = 0,
        taxedDelivered = 0,
      }
    elseif target > member.current + EPSILON then
      receivers[#receivers + 1] = {
        member = member,
        need = target - member.current,
        received = 0,
      }
    end
  end

  if #receivers > 0 and #senders > 0 then
    for r = 1, #receivers do
      local receiver = receivers[r]
      local remainingNeed = receiver.need
      for s = 1, #senders do
        if remainingNeed <= EPSILON then
          break
        end

        local sender = senders[s]
        if sender.untaxedSupply > EPSILON then
          local take = math.min(remainingNeed, sender.untaxedSupply)
          sender.untaxedSupply = sender.untaxedSupply - take
          sender.costSpent = sender.costSpent + take
          sender.untaxedDelivered = sender.untaxedDelivered + take
          receiver.received = receiver.received + take
          remainingNeed = remainingNeed - take
        end

        if remainingNeed <= EPSILON then
          break
        end

        local taxRate = sender.member.taxRate
        if sender.taxedReceivable > EPSILON and taxRate < 1 then
          local deliver = math.min(remainingNeed, sender.taxedReceivable)
          sender.taxedReceivable = sender.taxedReceivable - deliver
          sender.taxedDelivered = sender.taxedDelivered + deliver
          local cost = deliver / (1 - taxRate)
          sender.costSpent = sender.costSpent + cost
          receiver.received = receiver.received + deliver
          remainingNeed = remainingNeed - deliver
        end
      end
    end
  end

  for s = 1, #senders do
    local sender = senders[s]
    local member = sender.member
    local ledger = ledgers[member.teamId]
    ledger.sent = sender.costSpent
    ledger.untaxed = sender.untaxedDelivered
    ledger.taxed = sender.costSpent - sender.untaxedDelivered
  end

  return ledgers
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
---@param teamsList TeamResourceData[]
---@param policies table<number, table<ResourceType, ResourcePolicyResult>>
---@return TeamResourceData[], table<number, table<ResourceType, EconomyFlowLedger>>
function Gadgets.ProcessEconomy(springRepo, teamsList, policies)
  if not teamsList or #teamsList == 0 then
    return teamsList, {}
  end

  resetTickFields(teamsList)

  local cumulativeUpdates = {}
  local allLedgers = {}

  for _, resourceType in ipairs(RESOURCE_TYPES) do
    local groups = collectMembers(teamsList, resourceType, policies, springRepo)
    for _, members in pairs(groups) do
      local memberById = {}
      for i = 1, #members do
        memberById[members[i].teamId] = members[i]
      end
      local lift = resolveLift(members)
      local ledgers = allocateGroup(members, lift)
      for teamId, ledger in pairs(ledgers) do
        local perTeam = allLedgers[teamId]
        if not perTeam then
          perTeam = {}
          allLedgers[teamId] = perTeam
        end
        local summary = perTeam[resourceType]
        if not summary then
          summary = { sent = 0, received = 0, untaxed = 0, taxed = 0 }
          perTeam[resourceType] = summary
        end
        summary.sent = summary.sent + ledger.sent
        summary.received = summary.received + ledger.received
        summary.untaxed = summary.untaxed + ledger.untaxed
        summary.taxed = summary.taxed + ledger.taxed

        if ledger.sent > EPSILON then
          local member = memberById[teamId]
          local perResource = cumulativeUpdates[teamId]
          if not perResource then
            perResource = {}
            cumulativeUpdates[teamId] = perResource
          end
          -- Update cumulative sent using the policy's tracking if available, 
          -- but here we just need to add the delta to the spring param.
          -- The policy object has 'cumulativeSent' snapshot, but we need to write back to Spring.
          -- We can use the member's cumulativeSent (which came from spring) + ledger.sent
           perResource[resourceType] = ResourceShared.GetCumulativeSent(teamId, resourceType, springRepo) + ledger.sent
        end
      end
    end
  end

  if next(cumulativeUpdates) then
    updateCumulative(springRepo, cumulativeUpdates)
  end

  return teamsList, allLedgers
end

return Gadgets