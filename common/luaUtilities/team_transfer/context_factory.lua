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

local enrichers = {}

---@param fn PolicyContextEnricher
function ContextFactory.registerPolicyContextEnricher(fn)
  enrichers[#enrichers + 1] = fn
end

function ContextFactory.getEnrichers()
  return enrichers
end

function ContextFactory.setEnrichers(list)
  enrichers = list
end

---@param springRepo SpringSynced
---@return table Context factory with closures
function ContextFactory.create(springRepo)
  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param extensions? table
  ---@return table
  local function buildContext(senderTeamID, receiverTeamID, extensions)
    ---@type TeamResources
    local senderResources = {
      metal = TeamResourceData.Get(springRepo, senderTeamID, TransferEnums.ResourceType.METAL),
      energy = TeamResourceData.Get(springRepo, senderTeamID, TransferEnums.ResourceType.ENERGY)
    }

    ---@type TeamResources
    local receiverResources = {
      metal = TeamResourceData.Get(springRepo, receiverTeamID, TransferEnums.ResourceType.METAL),
      energy = TeamResourceData.Get(springRepo, receiverTeamID, TransferEnums.ResourceType.ENERGY)
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
    local transferCategory = resourceType == TransferEnums.ResourceType.METAL and resourceType or
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
  }
end

return ContextFactory
