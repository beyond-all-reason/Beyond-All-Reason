---@meta policy mode

--- The transfer mode-preset surface: what modules/transfer/modes/*.lua files
--- author against (via mode_dsl.lua over modules/mode_builder.lua).


--- The Mode chain (transfer vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns. Modifiers (Hidden,
--- Unlocked, Locked) apply to the most recent policy.
---@class TransferModeChain
---@field Desc fun(desc: string): TransferModeChain
---@field Ranked fun(enabled: boolean?): TransferModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): TransferModeChain
---@field Hidden fun(): TransferModeChain
---@field Unlocked fun(): TransferModeChain
---@field Locked fun(): TransferModeChain
---@field Allow fun(noun: TransferGrant): TransferModeChain
---@field Deny fun(noun: TransferGrant): TransferModeChain
---@field Tax fun(noun: TransferGrant, rate: number): TransferModeChain
---@field Stun fun(noun: TransferGrant, seconds: number?): TransferModeChain
---@field Defer fun(noun: TransferGrant): TransferModeChain
---@field Delay fun(noun: TransferGrant, seconds: number): TransferModeChain
---@field Gate fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain
---@field Open fun(noun: TransferGrant, t2: number, t3: number): TransferModeChain

---Start a mode chain; the key is the name's snake_case. The category is
---not a parameter: the grammar binds every chain from this module to
---"transfer".
---@param name string
---@return TransferModeChain
function Mode(name) end
