---@meta policy mode

---@class ScavengersPackNoun

---@class ScavengersModeChain
---@field Desc fun(desc: string): ScavengersModeChain
---@field Ranked fun(enabled: boolean?): ScavengersModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): ScavengersModeChain
---@field Hidden fun(): ScavengersModeChain
---@field Unlocked fun(): ScavengersModeChain
---@field Locked fun(): ScavengersModeChain
---@field Sealed fun(): ScavengersModeChain pins the dials as well
---@field Difficulty fun(pack: ScavengersPackNoun, difficulty: string): ScavengersModeChain
---@field Boss fun(pack: ScavengersPackNoun, count: integer, timeMultiplier: number?): ScavengersModeChain
---@field Grace fun(pack: ScavengersPackNoun, multiplier: number): ScavengersModeChain
---@field Pace fun(pack: ScavengersPackNoun, timeMultiplier: number, countMultiplier: number): ScavengersModeChain
---@field Placement fun(pack: ScavengersPackNoun, placement: WaveBurrowPlacement): ScavengersModeChain
---@field Endless fun(pack: ScavengersPackNoun, endless: boolean): ScavengersModeChain
---@field Bot fun(aiName: string): ScavengersModeChain

---@param name string
---@return ScavengersModeChain
function Mode(name) end

---@type { Skirmish: ScavengersPackNoun, Assault: ScavengersPackNoun, Horde: ScavengersPackNoun }
Scavengers = {}
