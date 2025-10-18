-- Team Transfer Type Definitions
-- Minimal types focused on IntelliSense support and keeping the linter honest

---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
---@alias ResourceType "metal" | "energy"

---@class ValidationResult
---@field ok boolean
---@field reason string?
---@field translationTokens table?

---@class ResourceValidationResult : ValidationResult
---@field amount number
---@field resourceType ResourceType
---@field suggestedAmount number

---@class PolicyResult
---@field senderTeamId number
---@field receiverTeamId number

-- Resource Transfer Action

---@class ResourcePolicyResult : PolicyResult
---@field canShare boolean
---@field amountSendable number
---@field amountReceivable number
---@field taxedPortion number
---@field untaxedPortion number
---@field taxRate number
---@field resourceType ResourceType
---@field remainingTaxFreeAllowance number
---@field resourceShareThreshold number
---@field cumulativeSent number

---@class ResourceTransferContext : PolicyActionContext
---@field resourceType ResourceType
---@field desiredAmount number
---@field policyResult ResourcePolicyResult

---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId number
---@field receiverTeamId number
---@field policyResult ResourcePolicyResult

---@class PostResourceTransferContext : ResourceTransferContext
---@field transferResult ResourceTransferResult

-- Command Transfer Actions

---@class CommandTransferPolicyResult
---@field allowCommands boolean
---@field blockReason string?

--- Policy Context

---@class TeamInfo
---@field id number
---@field name string
---@field leader number
---@field isDead boolean
---@field isAI boolean
---@field side string
---@field allyTeam number

---@class RegisterInitializePolicyContext
---@field playerIds number[]
---@field springRepo ISpring

---@class TeamData
---@field id number
---@field isHuman boolean
---@field name string
---@field metal ResourceData
---@field energy ResourceData

---@class ResourceData
---@field current number
---@field storage number
---@field pull number
---@field income number
---@field expense number
---@field shareSlider number
---@field sent number
---@field received number

---@class TeamResources
---@field metal ResourceData
---@field energy ResourceData

---@class PolicyContext
---@field senderTeamId number
---@field receiverTeamId number
---@field resultSoFar table<TransferCategory, table>
---@field sender TeamResources
---@field receiver TeamResources
---@field springRepo ISpring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean

---@class PolicyActionContext : PolicyContext
---@field transferCategory string SharedEnums.TransferCategory

---@class ResourceTransferPolicyContext : PolicyActionContext
---@field amount number
---@field resource ResourceType
