-- Team transfer type definitions: minimal types for IntelliSense and the linter.

---@alias PolicyType "metal_transfer" | "energy_transfer" | "unit_transfer"

--- Per-resource snapshot from the BAR-owned GG.GetTeamResourceData (Spring.GetTeamResources plus Lua-owned sent/received).
---@class ResourceData
---@field resourceType ResourceName
---@field current number Engine-owned snapshot; read-only to Lua
---@field storage number Engine-owned snapshot; read-only to Lua
---@field pull number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field income number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field expense number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field shareSlider number Engine stores, Lua interprets
---@field sent number
---@field received number
---@field excess number Overflow pool to redistribute (solver input); last tick's wasted amount in GetTeamResourceData

---@class TeamResourceData
---@field allyTeam integer
---@field isDead boolean
---@field metal ResourceData? absent when the snapshot skipped the resource (solver guards on it)
---@field energy ResourceData? absent when the snapshot skipped the resource (solver guards on it)
---@field [ResourceName] ResourceData? dynamic lookup form of the metal/energy fields

---@class PolicyResult
---@field senderTeamId integer
---@field receiverTeamId integer

-- Unit Transfer Action
---@class UnitPolicyResult : PolicyResult
---@field canShare boolean
---@field sharingModes string[]
---@field stunSeconds number?
---@field stunCategory string?
---@field buildDelaySeconds number?
---@field techBlocking? TechBlockingContext

---@class UnitTransferContext : PolicyActionContext
---@field unitIds integer[]
---@field given boolean?
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

---@class UnitValidationResult
---@field status string TransferEnums.UnitValidationOutcome
---@field buildDelayedUnitCount integer? Valid units that will receive the constructor build delay
---@field stunnedUnitCount integer? Valid units that will be stunned (stun category)
---@field invalidUnitCount integer
---@field invalidUnitIds integer[]
---@field invalidUnitNames string[]
---@field validUnitCount integer
---@field validUnitIds integer[]
---@field validUnitNames string[]

---@class UnitTransferResult
---@field success boolean
---@field outcome string TransferEnums.UnitValidationOutcome
---@field senderTeamId integer
---@field receiverTeamId integer
---@field validationResult UnitValidationResult
---@field policyResult UnitPolicyResult

---@class GameUnitTransferController
---@field AllowUnitTransfer fun(unitID: integer, unitDefID: integer, fromTeamID: integer, toTeamID: integer, capture: boolean): boolean
---@field TeamShare fun(srcTeamID: integer, dstTeamID: integer)

-- Resource Transfer Action

---@class ResourcePolicyResult : PolicyResult
---@field canShare boolean
---@field amountSendable number
---@field amountReceivable number
---@field taxedPortion number
---@field taxRate number
---@field resourceType ResourceName
---@field techBlocking? TechBlockingContext

---@class ResourceTransferContext : PolicyActionContext
---@field resourceType ResourceName
---@field desiredAmount number
---@field policyResult ResourcePolicyResult

---@class ResourceTransferResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId integer
---@field receiverTeamId integer
---@field policyResult ResourcePolicyResult? absent when the transfer was denied before a policy resolved

--- Policy Context

---@class TeamResources
---@field metal ResourceData
---@field energy ResourceData

---@class TechUnlockInfo
---@field unlockLevel number    Tech level at which this domain next changes
---@field unlockThreshold number Keystones needed to reach that level
---@field unlockValue any        What activates (mode string for units, rate number for tax)

---@class TechBlockingContext
---@field level number              Current latched tech level (1/2/3)
---@field points number             Alive Keystone count
---@field t2Threshold number        Computed T2 threshold (per-player * team size)
---@field t3Threshold number        Computed T3 threshold
---@field nextLevel number          Next tech level to reach (2 or 3, or 3 if maxed)
---@field nextThreshold number      Keystones needed for next level
---@field unitTransfer? TechUnlockInfo Next unit sharing mode change
---@field metalTransfer? TechUnlockInfo Next metal tax rate change
---@field energyTransfer? TechUnlockInfo Next energy tax rate change

---@class PolicyContextExtensions
---@field techBlocking? TechBlockingContext

---@class PolicyContext
---@field senderTeamId integer
---@field receiverTeamId integer
---@field sender TeamResources
---@field receiver TeamResources
---@field springRepo EngineSynced
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean
---@field ext PolicyContextExtensions
---@field unitSharingModes? string[] Effective sharing modes (set by enricher, e.g. tech blocking)
---@field taxRate? number           Effective tax rate (set by enricher, e.g. tech blocking)

---@class PolicyActionContext : PolicyContext
---@field policyType string TransferEnums.PolicyType

---@class EconomyShareMember
---@field teamId integer
---@field allyTeam integer
---@field resourceType ResourceName
---@field resource ResourceData
---@field current number effective current = resource.current + resource.excess
---@field storage number
---@field shareCursor number
---@field target number?

--- Solver output; the controller applies pools, excess, and sent/received itself.
---@class EconomyTeamResult
---@field teamId integer
---@field resourceType ResourceName
---@field delta number Net change vs the snapshot (informational; conservation/tests)
---@field sent number
---@field received number
---@field excess number Wasted overflow this tick

---@class EconomyFlowLedger
---@field received number
---@field sent number
---@field taxed number
---@field wasted number Overflow lost to full storages this window
---@field snapshot number Pool level when the window opened (delta base for publishing); 0 on per-solve ledgers

--- Per-member flow inside one waterfill solve (solver-internal).
---@class EconomyShareDelta
---@field gross number Signed pool movement (negative = send)
---@field net number Post-tax amount credited to the receiver
---@field taxed number Amount withheld by tax

---@alias EconomyFlowSummary table<integer, table<ResourceName, EconomyFlowLedger>>

---@class ResourceShareParams
---@field senderTeamID integer
---@field targetTeamID integer
---@field resourceType string
---@field amount number
