---@meta policy mode

--- Modifiers (Hidden, Unlocked, Locked) apply to the most recent policy.
---@class TransferModeChain
---@field Desc fun(desc: string): TransferModeChain
---@field Ranked fun(enabled: boolean?): TransferModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): TransferModeChain
---@field Hidden fun(): TransferModeChain
---@field Unlocked fun(): TransferModeChain
---@field Locked fun(): TransferModeChain
---@field Sealed fun(): TransferModeChain pins the dials as well
---@field Allow fun(noun: TransferGrant): TransferModeChain
---@field Deny fun(noun: TransferGrant): TransferModeChain
---@field Tax fun(noun: TransferGrant, rate: number): TransferModeChain
---@field Stun fun(noun: TransferGrant, seconds: number?): TransferModeChain
---@field Defer fun(noun: TransferGrant): TransferModeChain
---@field Delay fun(noun: TransferGrant, seconds: number): TransferModeChain
---@field Gate fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain
---@field Open fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain

---The category is not a parameter: the grammar binds every chain from this module to "transfer".
---@param name string
---@return TransferModeChain
function Mode(name) end
