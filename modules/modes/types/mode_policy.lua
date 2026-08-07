---@meta policy mode

--- The game axis's mode-preset surface: what modules/modes/modes/*.lua files
--- author against (via mode_dsl.lua over modules/mode_builder.lua). The axis
--- governs the Main options, so its verbs speak about the base rules of a
--- match; flavors bring their own chains for their own dials.

--- The Mode chain (game axis vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns.
---@class GameModeChain
---@field Desc fun(desc: string): GameModeChain
---@field Ranked fun(): GameModeChain
---@field RetainValues fun(): GameModeChain
---@field Hidden fun(): GameModeChain
---@field Unlocked fun(): GameModeChain
---@field Locked fun(): GameModeChain
---@field End fun(deathmode: string): GameModeChain
---@field Wreckage fun(enabled: boolean): GameModeChain
---@field ShuffleStartBoxes fun(enabled: boolean): GameModeChain

---Start a mode chain; the key is the name's snake_case.
---@param name string
---@return GameModeChain
function Mode(name) end
