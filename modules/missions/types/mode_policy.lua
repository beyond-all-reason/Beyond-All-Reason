---@meta policy mode

--- The missions mode-preset surface: what modules/missions/modes/*.lua files
--- author against (via lib/mode_dsl.lua over modules/mode_builder.lua).

--- A mode noun: names the policy domain a verb acts on.
---@class MissionModeNoun
---@field domain string

--- The Mode chain (missions vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns.
---@class MissionModeChain
---@field Desc fun(desc: string): MissionModeChain
---@field Ranked fun(): MissionModeChain
---@field RetainValues fun(): MissionModeChain
---@field Hidden fun(): MissionModeChain
---@field Unlocked fun(): MissionModeChain
---@field Locked fun(): MissionModeChain
---@field Own fun(noun: MissionModeNoun): MissionModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return MissionModeChain
function Mode(name) end

---@type { End: MissionModeNoun }
Match = {}
