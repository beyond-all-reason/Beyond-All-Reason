-- Context Factory with Closures
-- Functions that capture repositories in closures for cleaner APIs

local SharedEnums = VFS.Include("luarules/gadgets/team_transfer/shared_enums.lua")

---@class ContextFactory
---@field create fun(springRepo: SpringRepository): ContextFactory
---@field policy fun(senderTeamID: number, receiverTeamID: number): PolicyContext
---@field action fun(senderTeamId: number, receiverTeamId: number, transferCategory: string): PolicyActionContext
---@field resource fun(senderTeamId: number, receiverTeamId: number, resourceType: string, amount: number, policyResult: ResourcePolicyResult): ResourceTransferPolicyContext
---@field resourceTransfer fun(senderTeamId: number, receiverTeamId: number, resourceType: ResourceType, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
local ContextFactory = {}

---Create a context factory with repositories captured in closures
---@param springRepo SpringRepository
---@return table Context factory with closures
function ContextFactory.create(springRepo)
    ---Create context with optional extensions
    ---@param senderTeamID number
    ---@param receiverTeamID number
    ---@param extensions? table Additional fields to merge
    ---@return table Context
    local function buildContext(senderTeamID, receiverTeamID, extensions)
        -- Get resource data using the single source of truth
        local senderMetal = springRepo:GetTeamResourcesUnpacked(senderTeamID, SharedEnums.ResourceType.METAL)
        local senderEnergy = springRepo:GetTeamResourcesUnpacked(senderTeamID, SharedEnums.ResourceType.ENERGY)
        local receiverMetal = springRepo:GetTeamResourcesUnpacked(receiverTeamID, SharedEnums.ResourceType.METAL)
        local receiverEnergy = springRepo:GetTeamResourcesUnpacked(receiverTeamID, SharedEnums.ResourceType.ENERGY)

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

        ---@type ContextRepositories
        local repositories = {
            springRepo = springRepo,
        }

        ---@type PolicyContext
        local ctx = {
            senderTeamId = senderTeamID,
            receiverTeamId = receiverTeamID,
            resultSoFar = {},
            sender = senderResources,
            receiver = receiverResources,
            repositories = repositories,
            areAlliedTeams = springRepo:AreAlliedTeams(senderTeamID, receiverTeamID),
            isCheatingEnabled = springRepo:IsCheatingEnabled()
        }

        -- Merge extensions if provided
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
    local function action(senderTeamId, receiverTeamId, transferCategory)
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory
        })
    end

    ---@param senderTeamId number
    ---@param receiverTeamId number
    ---@param resourceType ResourceType
    ---@param amount number
    ---@param policyResult ResourcePolicyResult
    ---@return ResourceTransferPolicyContext
    local function resource(senderTeamId, receiverTeamId, resourceType, amount, policyResult)
        local transferCategory = resourceType == "metal" and SharedEnums.TransferCategory.MetalTransfer or SharedEnums.TransferCategory.EnergyTransfer
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory,
            resource = resourceType,
            amount = amount,
            policyResult = policyResult
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
        local transferCategory = resourceType == SharedEnums.ResourceType.METAL 
            and SharedEnums.TransferCategory.MetalTransfer 
            or SharedEnums.TransferCategory.EnergyTransfer
        return buildContext(senderTeamId, receiverTeamId, {
            transferCategory = transferCategory,
            resourceType = resourceType,
            desiredAmount = desiredAmount,
            policyResult = policyResult
        })
    end

    return {
        policy = policy,
        action = action,
        resource = resource,
        resourceTransfer = resourceTransfer,
    }
end

return ContextFactory
