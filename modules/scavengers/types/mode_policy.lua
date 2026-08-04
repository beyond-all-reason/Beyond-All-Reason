---@meta policy mode

--- The scavengers mode vocabulary: what a preset under modules/scavengers/modes
--- may say. Declared here because a mode preset checks against the mode surface
--- of its OWN module — the trigger vocabulary in actions.lua is a different
--- language for a different kind of file, and the two never mix.
---
--- The verbs come from the shared PvE grammar in modules/waves; the nouns are
--- the packs, so a mode dials the same Horde a mission could name.

--- A wave pack as a mode noun. Every dial takes one, because a module can run
--- more than one director and a preset has to say which it is tuning.
---@class ScavengersPackNoun

--- The Mode chain (scavengers vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns. The lock modifiers apply to
--- the option the preceding verb wrote, which is how Difficulty and Endless are
--- left open for the lobby while everything else is pinned.
---@class ScavengersModeChain
---@field Desc fun(desc: string): ScavengersModeChain
---@field Ranked fun(): ScavengersModeChain
---@field RetainValues fun(): ScavengersModeChain
---@field Hidden fun(): ScavengersModeChain
---@field Unlocked fun(): ScavengersModeChain
---@field Locked fun(): ScavengersModeChain
---@field Difficulty fun(pack: ScavengersPackNoun, difficulty: string): ScavengersModeChain
---@field Boss fun(pack: ScavengersPackNoun, count: integer, timeMultiplier: number?): ScavengersModeChain
---@field Grace fun(pack: ScavengersPackNoun, multiplier: number): ScavengersModeChain
---@field Pace fun(pack: ScavengersPackNoun, timeMultiplier: number, countMultiplier: number): ScavengersModeChain
---@field Placement fun(pack: ScavengersPackNoun, placement: WaveBurrowPlacement): ScavengersModeChain
---@field Endless fun(pack: ScavengersPackNoun, endless: boolean): ScavengersModeChain
--- Field a bot. The one thing the modoptions cannot express: scavengers are
--- activated by a scavengers AI being present, not by an option, which is what
--- keeps every existing lobby working.
---@field Bot fun(aiName: string): ScavengersModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return ScavengersModeChain
function Mode(name) end

---@type { Skirmish: ScavengersPackNoun, Assault: ScavengersPackNoun, Horde: ScavengersPackNoun }
Scavengers = {}
