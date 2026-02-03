local GlobalEnums = VFS.Include("modes/global_enums.lua")

---@class ContextFactory
---@field create fun(springRepo: ISpring): ContextFactory
---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitPolicyResult, unitValidationResult: UnitValidationResult): UnitTransferContext
local ContextFactory = {}

---@param springRepo ISpring
---@return table Context factory with closures
function ContextFactory.create(springRepo)
  ---Create context with optional extensions
  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param extensions? table Additional fields to merge
  ---@return table Context
  local function buildContext(senderTeamID, receiverTeamID, extensions)
    ---@type TeamResources
    local senderResources = {
      metal = springRepo.GetTeamResourceData(senderTeamID, GlobalEnums.ResourceType.METAL),
      energy = springRepo.GetTeamResourceData(senderTeamID, GlobalEnums.ResourceType.ENERGY)
    }

    ---@type TeamResources
    local receiverResources = {
      metal = springRepo.GetTeamResourceData(receiverTeamID, GlobalEnums.ResourceType.METAL),
      energy = springRepo.GetTeamResourceData(receiverTeamID, GlobalEnums.ResourceType.ENERGY)
    }

    ---@type PolicyContext
    local ctx = {
      senderTeamId = senderTeamID,
      receiverTeamId = receiverTeamID,
      sender = senderResources,
      receiver = receiverResources,
      springRepo = springRepo,
      areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID),
      isCheatingEnabled = springRepo.IsCheatingEnabled()
    }

    if extensions then
      for k, v in pairs(extensions) do
        ctx[k] = v
      end
    end

    return ctx
  end

  ---Create policy context
  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param commandType? string
  ---@return PolicyContext
  local function policy(senderTeamID, receiverTeamID, commandType)
    return buildContext(senderTeamID, receiverTeamID, {
      commandType = commandType
    })
  end

  ---Create action context
  ---@param transferCategory string
  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@return PolicyActionContext
  local function policyAction(senderTeamId, receiverTeamId, transferCategory)
    return buildContext(senderTeamId, receiverTeamId, {
      transferCategory = transferCategory
    })
  end

  ---Create resource transfer context for transfer actions
  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@param resourceType ResourceType
  ---@param desiredAmount number
  ---@param policyResult ResourcePolicyResult
  ---@return ResourceTransferContext
  local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
    local transferCategory = resourceType == GlobalEnums.ResourceType.METAL and resourceType or
        GlobalEnums.TransferCategory.EnergyTransfer
    return buildContext(senderTeamId, receiverTeamId, {
      transferCategory = transferCategory,
      resourceType = resourceType,
      desiredAmount = desiredAmount,
      policyResult = policyResult
    })
  end

  ---Create unit transfer context for transfer actions
  ---@param senderTeamId number
  ---@param receiverTeamId number
  ---@param unitIds number[]
  ---@param given boolean?
  ---@param policyResult UnitPolicyResult\
  ---@param validationResult UnitValidationResult
  ---@return UnitTransferContext
  local function unitTransfer(senderTeamId, receiverTeamId, unitIds, given, policyResult, validationResult)
    return buildContext(senderTeamId, receiverTeamId, {
        transferCategory = GlobalEnums.TransferCategory.UnitTransfer,
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
