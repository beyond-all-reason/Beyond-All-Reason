---@meta policy mode

--- The game axis's mode-preset surface: what modules/modes/modes/*.lua files
--- author against (via mode_dsl.lua over modules/mode_builder.lua). The axis
--- governs the Main options, so its verbs speak about the base rules of a
--- match; flavors bring their own chains for their own dials.

--- The Mode chain (game axis vocabulary). Every verb returns the chain; the
--- chain IS the ModeConfig the preset file returns.
---@class GameModeChain
---@field Desc fun(desc: string): GameModeChain
---@field Ranked fun(enabled: boolean?): GameModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): GameModeChain
---@field Hidden fun(): GameModeChain
---@field Unlocked fun(): GameModeChain
---@field Locked fun(): GameModeChain
---@field End fun(deathmode: string): GameModeChain territorial_domination brings its round dials along
---@field Wreckage fun(enabled: boolean): GameModeChain
---@field ShuffleStartBoxes fun(enabled: boolean): GameModeChain
---@field MaxUnits fun(count: number): GameModeChain
---@field Draft fun(draft: string): GameModeChain
---@field Anonymous fun(anonymous: string): GameModeChain
---@field PausedCommands fun(enabled: boolean): GameModeChain
---@field CustomWidgets fun(enabled: boolean): GameModeChain
---@field UnitControlWidgets fun(enabled: boolean): GameModeChain
---@field FixedAlliances fun(enabled: boolean): GameModeChain
---@field MapDeformation fun(enabled: boolean): GameModeChain
---@field FogOfWar fun(enabled: boolean): GameModeChain
---@field NoRush fun(minutes: number, middleFree: boolean?): GameModeChain
---@field SlowComTransport fun(enabled: boolean): GameModeChain
---@field Restrictions fun(): GameModeChain

---Start a mode chain; the key is the name's snake_case. The category is
---not a parameter: the grammar binds every chain from this module to
---"game".
---@param name string
---@return GameModeChain
function Mode(name) end
