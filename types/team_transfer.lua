-- Team Transfer Type Definitions
-- Minimal types focused on IntelliSense support and keeping the linter honest

---@alias TransferCategory "metal_transfer" | "energy_transfer" | "unit_transfer" | "guard_transfer" | "repair_transfer" | "reclaim_transfer"
---@alias ResourceType ResourceName

---@class ValidationResult
---@field ok boolean
---@field reason string?
---@field translationTokens table?

---@class PolicyResult
---@field senderTeamId number
---@field receiverTeamId number

-- Unit Transfer Action

---@class UnitPolicyResult : PolicyResult
---@field canShare boolean
---@field sharingMode string

---@class UnitTransferContext : PolicyActionContext
---@field unitIds number[]
---@field given boolean?
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

---@class UnitDefValidationSummary
---@field ok boolean
---@field name string
---@field unitDefID number
---@field unitCount number

---@class UnitValidationResult
---@field status string SharedEnums.UnitValidationOutcome
---@field invalidUnitCount number
---@field invalidUnitIds number[]
---@field invalidUnitNames string[]
---@field validUnitCount number
---@field validUnitIds number[]
---@field validUnitNames string[]

---@class UnitTransferResult
---@field outcome string SharedEnums.UnitValidationOutcome
---@field senderTeamId number
---@field receiverTeamId number
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

-- Unit Sharing Globals

---@class UnitSharingPolicyGlobals
---@field unitSharingMode string
---@field allowedList table<number, boolean>

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
---@field taxExcess boolean Whether thresholds apply (true = use thresholds, false = always tax)

---@class ResourceTransferContext : PolicyActionContext
---@field resourceType ResourceType
---@field desiredAmount number
---@field policyResult ResourcePolicyResult

---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field untaxed number
---@field senderTeamId number
---@field receiverTeamId number
---@field policyResult ResourcePolicyResult

--- Policy Context

---@class RegisterInitializePolicyContext
---@field playerIds number[]
---@field springRepo ISpring

---@class TeamResources
---@field metal ResourceData
---@field energy ResourceData

---@class PolicyContext
---@field senderTeamId number
---@field receiverTeamId number
---@field sender TeamResources
---@field receiver TeamResources
---@field springRepo ISpring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean

---@class PolicyActionContext : PolicyContext
---@field transferCategory string SharedEnums.TransferCategory

---@class EconomyShareMember
---@field teamId number
---@field allyTeam number
---@field resourceType ResourceType
---@field resource ResourceData
---@field current number effective current = resource.current + resource.excess
---@field storage number
---@field shareCursor number
---@field remainingTaxFreeAllowance number
---@field cumulativeSent number
---@field threshold number
---@field target number?

---@class EconomyFlowLedger
---@field received number
---@field sent number
---@field untaxed number
---@field taxed number

---@alias EconomyFlowSummary table<number, table<ResourceType, EconomyFlowLedger>>

---@class EconomyWaterFillSolution
---@field targetLift number
---@field needs table<number, number>
---@field supply table<number, number>
