---@meta policy mode

---@class MissionModeNoun
---@field domain string

---@class MissionModeChain
---@field Desc fun(desc: string): MissionModeChain
---@field Ranked fun(enabled: boolean?): MissionModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): MissionModeChain
---@field Hidden fun(): MissionModeChain
---@field Unlocked fun(): MissionModeChain
---@field Locked fun(): MissionModeChain
---@field Sealed fun(): MissionModeChain pins the dials as well
---@field Own fun(noun: MatchflowModeNoun): MissionModeChain
---@field Loads fun(noun: MissionModeNoun): MissionModeChain
---@field Choose fun(noun: MissionModeNoun): MissionModeChain
---@field Bot fun(aiName: string): MissionModeChain a bot the lobby fields; a mission's is the seat-filler

---@param name string
---@return MissionModeChain
function Mode(name) end

---@type { EveryUnitDef: MissionModeNoun, Mission: MissionModeNoun }
Match = {}
