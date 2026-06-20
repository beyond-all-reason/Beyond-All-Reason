local SharedConfig = VFS.Include("common/luaUtilities/economy/shared_config.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local Comms = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_comms.lua")
local Shared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local WaterfillSolver = VFS.Include("common/luaUtilities/economy/economy_waterfill_solver.lua")
local PolicyEvents = VFS.Include("common/luaUtilities/team_transfer/policy_events.lua")

local ResourceType = TransferEnums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local Gadgets = {
  SendTransferChatMessages = Comms.SendTransferChatMessages,
}

local function isNonPlayerTeam(springRepo, teamId)
  if teamId == springRepo.GetGaiaTeamID() then
    return true
  end
  local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
  if isAiTeam then
    return true
  end
  -- Spring.GetTeamLuaAI returns "" (not nil) for teams without a LuaAI, so guard both.
  local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
  return luaAI ~= nil and luaAI ~= ""
end

-- Encapsulate legacy AllowResourceTransfer gate rules
---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult|nil
local function TryDenyPolicy(ctx, resourceType)
  if not SharedConfig.isResourceSharingEnabled(ctx.springRepo) then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
  end

  if ctx.isCheatingEnabled then
    return nil
  end

  if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
  end

  local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
  if numActivePlayers ~= nil and tonumber(numActivePlayers) == 0 then
    return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
  end
  return nil
end

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
  local policyResult = ctx.policyResult
  local desiredAmount = ctx.desiredAmount
  if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
    ---@type ResourceTransferResult
    return {
      success = false,
      sent = 0,
      received = 0,
      senderTeamId = ctx.senderTeamId,
      receiverTeamId = ctx.receiverTeamId,
      policyResult = policyResult,
    }
  end

  local received, sent = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)

  local springRepo = ctx.springRepo
  local resourceType = policyResult.resourceType
  -- deduct via SetTeamResource; AddTeamResource clamps its amount to >= 0
  local senderCurrent = springRepo.GetTeamResources(ctx.senderTeamId, resourceType)
  springRepo.SetTeamResource(ctx.senderTeamId, resourceType, math.max(0, senderCurrent - sent))
  springRepo.AddTeamResource(ctx.receiverTeamId, resourceType, received)

  ---@type ResourceTransferResult
  local result = {
    success = true,
    sent = sent,
    received = received,
    senderTeamId = ctx.senderTeamId,
    receiverTeamId = ctx.receiverTeamId,
    policyResult = policyResult
  }

  return result
end

local policyResultPool = {}

---Resolve a context's effective resource tax rate in [0,1] (sender tech tax, else base).
---ctx.taxRate (enricher, set only when >= 0) and getTaxConfig (clamped to [0,1]) both
---guarantee a non-negative input, and the (< 1) cap handles the upper bound, so no extra
---clamp is needed.
---@param ctx PolicyContext
---@return number
local function resolveEffectiveRate(ctx)
  local taxRate = ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)
  return (taxRate < 1) and taxRate or 1
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function Gadgets.CalcResourcePolicy(ctx, resourceType)
  local rejected = TryDenyPolicy(ctx, resourceType)
  if rejected then return rejected end

  local effectiveRate = resolveEffectiveRate(ctx)

  local senderData, receiverData
  if resourceType == METAL then
    senderData = ctx.sender.metal
    receiverData = ctx.receiver.metal
  else
    senderData = ctx.sender.energy
    receiverData = ctx.receiver.energy
  end

  local taxedSendable = math.max(0, senderData.current) * (1 - effectiveRate)
  local capacity = receiverData.storage - receiverData.current

  local result = policyResultPool[resourceType]
  if not result then
    result = {}
    policyResultPool[resourceType] = result
  end

  Shared.CombineResourcePolicy(taxedSendable, effectiveRate, capacity,
    ctx.senderTeamId, ctx.receiverTeamId, resourceType, result)
  result.techBlocking = ctx.ext and ctx.ext.techBlocking or nil

  return result
end

---@param springRepo SpringSynced
---@param teamId number
---@return boolean
local function teamActive(springRepo, teamId)
  local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
  if n == nil then return true end
  return tonumber(n) ~= 0
end

---Compute and cache one team's resource factor record for a single resource.
---@param springRepo SpringSynced
---@param teamId number
---@param resourceType ResourceName
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
  local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
  local effectiveRate = resolveEffectiveRate(ctx)
  local isNonPlayer = isNonPlayerTeam(springRepo, teamId)
  local active = teamActive(springRepo, teamId)
  local factor = {
    taxedSendable = math.max(0, data.current) * (1 - effectiveRate),
    taxRate = effectiveRate,
    capacity = data.storage - data.current,
    isNonPlayer = isNonPlayer,
    active = active,
  }
  springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(resourceType), Shared.SerializeResourceFactor(factor))
  -- Policy fields only; live amounts (taxedSendable/capacity) would fire every economy tick.
  local signature = string.format("%s|%s|%s", tostring(effectiveRate), tostring(active), tostring(isNonPlayer))
  PolicyEvents.NotifyIfChanged(teamId, resourceType, signature)
end

---Refresh the per-team resource factor cache. O(teams): each team's factor is independent,
---so there is no per-pair work and no amortization. GetCachedPolicyResult reconstructs
---any (sender,receiver) pair on read from these factors plus live gates.
---@param springRepo SpringSynced
---@param frame number
---@param lastUpdate number
---@param updateRate number
---@param contextFactory table
---@return number lastUpdate New last update frame
function Gadgets.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
  if frame < lastUpdate + updateRate then
    return lastUpdate
  end

  contextFactory.clearResourceCache()

  local allTeams = springRepo.GetTeamList()
  for _, teamId in ipairs(allTeams) do
    local ctx = contextFactory.policy(teamId, teamId)
    Gadgets.CacheTeamFactor(springRepo, teamId, METAL, ctx)
    Gadgets.CacheTeamFactor(springRepo, teamId, ENERGY, ctx)
  end

  return frame
end

---@param springRepo SpringSynced
---@param teamsList TeamResourceData[]
function Gadgets.WaterfillSolve(springRepo, teamsList)
  return WaterfillSolver.Solve(springRepo, teamsList)
end

return Gadgets
