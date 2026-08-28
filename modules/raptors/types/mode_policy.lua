---@meta policy mode

---@class RaptorsPackNoun

--- The lock modifiers apply to the option the preceding verb wrote, which is how Difficulty and
--- Endless are left open for the lobby while everything else is pinned.
---@class RaptorsModeChain
---@field Desc fun(desc: string): RaptorsModeChain
---@field Ranked fun(enabled: boolean?): RaptorsModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): RaptorsModeChain
---@field Hidden fun(): RaptorsModeChain
---@field Unlocked fun(): RaptorsModeChain
---@field Locked fun(): RaptorsModeChain
---@field Sealed fun(): RaptorsModeChain pins the dials as well
---@field Difficulty fun(pack: RaptorsPackNoun, difficulty: string): RaptorsModeChain
---@field Boss fun(pack: RaptorsPackNoun, count: integer, timeMultiplier: number?): RaptorsModeChain
---@field Grace fun(pack: RaptorsPackNoun, multiplier: number): RaptorsModeChain
---@field Pace fun(pack: RaptorsPackNoun, timeMultiplier: number, countMultiplier: number): RaptorsModeChain
---@field Placement fun(pack: RaptorsPackNoun, placement: WaveBurrowPlacement): RaptorsModeChain
---@field Endless fun(pack: RaptorsPackNoun, endless: boolean): RaptorsModeChain
---@field Boost fun(pack: RaptorsPackNoun, multiplier: number): RaptorsModeChain
--- Field a bot. The one thing the modoptions cannot express: raptors are
--- activated by a raptors AI being present, not by an option, which is what
--- keeps every existing lobby working.
---@field Bot fun(aiName: string): RaptorsModeChain

---@param name string
---@return RaptorsModeChain
function Mode(name) end

---@type { Skirmish: RaptorsPackNoun, Assault: RaptorsPackNoun, Swarm: RaptorsPackNoun }
Raptors = {}
