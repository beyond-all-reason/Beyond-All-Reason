local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")

---@class ContextFactory
---@field create fun(springRepo: ISpring): ContextFactory
---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field unitTransfer fun(senderTeamId: number, receiverTeamId: number, unitIds: number[], given: boolean, policyResult: UnitTransferPolicyResult): UnitTransferContext
local ContextFactory = {}

---@param springRepo ISpring
---@param teamID number
---@param resourceType string
---@return ResourceData Complete resource data for the team
local function getTeamResourcesUnpacked(springRepo, teamID, resourceType)
  local current, storage, pull, income, expense, share, sent, received = springRepo.GetTeamResources(teamID,
    resourceType)

  return {
    current = current,
    storage = storage,
    pull = pull,
    income = income,
    expense = expense,
    shareSlider = share,
    sent = sent,
    received = received
  }
end

---@param springRepo ISpring
---@return table Context factory with closures
function ContextFactory.create(springRepo)
  ---Create context with optional extensions
  ---@param senderTeamID number
  ---@param receiverTeamID number
  ---@param extensions? table Additional fields to merge
  ---@return table Context
  local function buildContext(senderTeamID, receiverTeamID, extensions)
    local senderMetal = getTeamResourcesUnpacked(springRepo, senderTeamID, SharedEnums.ResourceType.METAL)
    local senderEnergy = getTeamResourcesUnpacked(springRepo, senderTeamID, SharedEnums.ResourceType.ENERGY)
    local receiverMetal = getTeamResourcesUnpacked(springRepo, receiverTeamID, SharedEnums.ResourceType.METAL)
    local receiverEnergy = getTeamResourcesUnpacked(springRepo, receiverTeamID, SharedEnums.ResourceType.ENERGY)

    ---@type TeamResources
    local senderResources = {
      metal = senderMetal,
      energy = senderEnergy
    }

    ---@type TeamResources
    local receiverResources = {
      metal = receiverMetal,
      energy = receiverEnergy
    }

    ---@type PolicyContext
    local ctx = {
      senderTeamId = senderTeamID,
      receiverTeamId = receiverTeamID,
      resultSoFar = {},
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
    local transferCategory = resourceType == SharedEnums.ResourceType.METAL and resourceType or
        SharedEnums.TransferCategory.EnergyTransfer
    return buildContext(senderTeamId, receiverTeamId, {
      transferCategory = transferCategory,
      resourceType = resourceType,
      desiredAmount = desiredAmount,
      policyResult = policyResult
    })
  end

  return {
    policy = policy,
    action = policyAction,
  }
end

return ContextFactory
