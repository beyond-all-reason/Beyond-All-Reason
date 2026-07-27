---@meta dsl

--- The sharing mode-preset surface: what modules/transfer/modes/*.lua files
--- author against (via mode_dsl.lua over modules/mode_builder.lua).

--- A mode noun: names the policy domain a verb acts on; sub-nouns carry a
--- unit category, .AtT2/.AtT3 variants the tech tier.
---@class SharingModeNoun
---@field domain string
---@field category string|nil
---@field tier integer|nil

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
---@field Allow fun(noun: SharingModeNoun): SharingModeChain
---@field Deny fun(noun: SharingModeNoun): SharingModeChain
---@field Tax fun(noun: SharingModeNoun, rate: number): SharingModeChain
---@field Stun fun(noun: SharingModeNoun, seconds: number?): SharingModeChain
---@field Defer fun(noun: SharingModeNoun): SharingModeChain
---@field Delay fun(noun: SharingModeNoun, seconds: number): SharingModeChain
---@field Gate fun(noun: SharingModeNoun, t2: number, t3: number): SharingModeChain
---@field Open fun(noun: SharingModeNoun, t2: number, t3: number): SharingModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return SharingModeChain
function Mode(name) end

---@type { Units: SharingModeNoun, Resources: SharingModeNoun }
Share = {}

---@type { Allied: SharingModeNoun }
Assist = {}

---@type { AlliedUnits: SharingModeNoun }
Reclaim = {}

---@type { Partial: SharingModeNoun }
Resurrect = {}

---@type { Constructors: SharingModeNoun }
Build = {}

---@type SharingModeNoun
Take = {}

---@type SharingModeNoun
Tech = {}
