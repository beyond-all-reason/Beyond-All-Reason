---@meta policy mode

--- The raptors mode vocabulary: what a preset under modules/raptors/modes
--- may say. The verbs come from the shared PvE grammar in modules/waves; the
--- noun is the swarm, declared ahead of the pack it will name when raptors
--- migrates onto the wave director.

--- The raptor swarm as a mode noun. Every dial takes one, same as every
--- other PvE flavor, so the preset reads identically to scavengers'.
---@class RaptorsPackNoun

--- The Mode chain (raptors vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns. The lock modifiers apply
--- to the option the preceding verb wrote, which is how Difficulty and
--- Endless are left open for the lobby while everything else is pinned.
---@class RaptorsModeChain
---@field Desc fun(desc: string): RaptorsModeChain
---@field Ranked fun(): RaptorsModeChain
---@field RetainValues fun(): RaptorsModeChain
---@field Hidden fun(): RaptorsModeChain
---@field Unlocked fun(): RaptorsModeChain
---@field Locked fun(): RaptorsModeChain
---@field Difficulty fun(pack: RaptorsPackNoun, difficulty: string): RaptorsModeChain
---@field Boss fun(pack: RaptorsPackNoun, count: integer, timeMultiplier: number?): RaptorsModeChain
---@field Grace fun(pack: RaptorsPackNoun, multiplier: number): RaptorsModeChain
---@field Pace fun(pack: RaptorsPackNoun, timeMultiplier: number, countMultiplier: number): RaptorsModeChain
---@field Placement fun(pack: RaptorsPackNoun, placement: WaveBurrowPlacement): RaptorsModeChain
---@field Endless fun(pack: RaptorsPackNoun, endless: boolean): RaptorsModeChain
--- Field a bot. The one thing the modoptions cannot express: raptors are
--- activated by a raptors AI being present, not by an option, which is what
--- keeps every existing lobby working.
---@field Bot fun(aiName: string): RaptorsModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return RaptorsModeChain
function Mode(name) end

---@type { Swarm: RaptorsPackNoun }
Raptors = {}
