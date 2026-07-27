---@meta policy mode

--- The sharing mode-preset surface: what modules/transfer/modes/*.lua files
--- author against (via mode_dsl.lua over modules/mode_builder.lua).


--- The Mode chain (sharing vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns. Modifiers (Hidden,
--- Unlocked, Locked) apply to the most recent policy.
---@class SharingModeChain
---@field Desc fun(desc: string): SharingModeChain
---@field Ranked fun(): SharingModeChain
---@field RetainValues fun(): SharingModeChain
---@field Hidden fun(): SharingModeChain
---@field Unlocked fun(): SharingModeChain
---@field Locked fun(): SharingModeChain
---@field Allow fun(noun: TransferGrant): SharingModeChain
---@field Deny fun(noun: TransferGrant): SharingModeChain
---@field Tax fun(noun: TransferGrant, rate: number): SharingModeChain
---@field Stun fun(noun: TransferGrant, seconds: number?): SharingModeChain
---@field Defer fun(noun: TransferGrant): SharingModeChain
---@field Delay fun(noun: TransferGrant, seconds: number): SharingModeChain
---@field Gate fun(noun: TransferGrant, t2: number, t3: number): SharingModeChain
---@field Open fun(noun: TransferGrant, t2: number, t3: number): SharingModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return SharingModeChain
function Mode(name) end
