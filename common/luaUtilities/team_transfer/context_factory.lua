local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")
local TeamResourceData = VFS.Include("common/luaUtilities/team_transfer/team_resource_data.lua")

---@alias PolicyContextEnricher fun(ctx: PolicyContext, springRepo: SpringSynced, senderTeamID: number, receiverTeamID: number)

---@class ContextFactory
---@field create fun(springRepo: SpringSynced): ContextFactory
---@field registerPolicyContextEnricher fun(fn: PolicyContextEnricher)
---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceName, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitPolicyResult, unitValidationResult: UnitValidationResult): UnitTransferContext
local ContextFactory = {}

-- Shared across every VFS.Include of this file. VFS.Include does not cache (it
-- re-runs the file per call), so a module-local list would leave the registrar
-- (game_tech_blocking) and the consumer (the transfer controller) with separate,
-- disconnected registries. GG is the one table they both share.
GG = GG or {}
GG.policyContextEnrichers = GG.policyContextEnrichers or {}
local enrichers = GG.policyContextEnrichers

---@param fn PolicyContextEnricher
function ContextFactory.registerPolicyContextEnricher(fn)
  enrichers[#enrichers + 1] = fn
end

function ContextFactory.getEnrichers()
  local copy = {}
  for i = 1, #enrichers do copy[i] = enrichers[i] end
  return copy
end

-- mutate in place so the shared reference (and create()'s closures) stay valid
function ContextFactory.setEnrichers(list)
  for i = #enrichers, 1, -1 do enrichers[i] = nil end
  if list then
    for i = 1, #list do enrichers[i] = list[i] end
  end
end

---@param springRepo SpringSynced
---@return table Context factory with closures
function ContextFactory.create(springRepo)
  -- Per-snapshot resource memo: a refresh pass reads each team once instead of
  -- once per pair. Caller clears it (clearResourceCache) at the start of a pass.
  local resourceCache = {}

  local function getResource(teamID, resourceType)
    local perTeam = resourceCache[teamID]
    if not perTeam then
      perTeam = {}
      resourceCache[teamID] = perTeam
    end
    local data = perTeam[resourceType]
    if not data then
      data = TeamResourceData.Get(springRepo, teamID, resourceType)
      perTeam[resourceType] = data
    end
    return data
  end

  local function clearResourceCache()
    resourceCache = {}
  end

  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param extensions? table
  ---@return table
  local function buildContext(senderTeamID, receiverTeamID, extensions)
    ---@type TeamResources
    local senderResources = {
      metal = getResource(senderTeamID, TransferEnums.ResourceType.METAL),
      energy = getResource(senderTeamID, TransferEnums.ResourceType.ENERGY)
    }

    ---@type TeamResources
    local receiverResources = {
      metal = getResource(receiverTeamID, TransferEnums.ResourceType.METAL),
      energy = getResource(receiverTeamID, TransferEnums.ResourceType.ENERGY)
    }

    ---@type PolicyContext
    local ctx = {
      senderTeamId = senderTeamID,
      receiverTeamId = receiverTeamID,
      sender = senderResources,
      receiver = receiverResources,
      springRepo = springRepo,
      areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID) == true,
      isCheatingEnabled = springRepo.IsCheatingEnabled(),
      ext = {},
    }

    for _, enricher in ipairs(enrichers) do
      enricher(ctx, springRepo, senderTeamID, receiverTeamID)
    end

    if extensions then
      for k, v in pairs(extensions) do
        ctx[k] = v
      end
    end

    return ctx
  end

  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param commandType? string
  ---@return PolicyContext
  local function policy(senderTeamID, receiverTeamID, commandType)
    return buildContext(senderTeamID, receiverTeamID, {
      commandType = commandType
    })
  end

  ---@param transferCategory string
  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@return PolicyActionContext
  local function policyAction(senderTeamId, receiverTeamId, transferCategory)
    return buildContext(senderTeamId, receiverTeamId, {
      transferCategory = transferCategory
    })
  end

  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@param resourceType ResourceName
  ---@param desiredAmount number
  ---@param policyResult ResourcePolicyResult
  ---@return ResourceTransferContext
  local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
    local transferCategory = resourceType == TransferEnums.ResourceType.METAL and
        TransferEnums.TransferCategory.MetalTransfer or
        TransferEnums.TransferCategory.EnergyTransfer
    return buildContext(senderTeamId, receiverTeamId, {
      transferCategory = transferCategory,
      resourceType = resourceType,
      desiredAmount = desiredAmount,
      policyResult = policyResult
    })
  end

  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@param unitIds number[]
  ---@param given boolean?
  ---@param policyResult UnitPolicyResult
  ---@param validationResult UnitValidationResult
  ---@return UnitTransferContext
  local function unitTransfer(senderTeamId, receiverTeamId, unitIds, given, policyResult, validationResult)
    return buildContext(senderTeamId, receiverTeamId, {
        transferCategory = TransferEnums.TransferCategory.UnitTransfer,
        unitIds = unitIds,
        given = given,
        policyResult = policyResult,
        validationResult = validationResult
    })
  end

  return {
    policy = policy,
    action = policyAction,
    resourceTransfer = resourceTransfer,
    unitTransfer = unitTransfer,
    clearResourceCache = clearResourceCache,
  }
end

return ContextFactory
