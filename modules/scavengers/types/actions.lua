---@meta actions

--- Scavengers' mission vocabulary. The verbs are Waves'; what this module
--- contributes is the set of packs that exist, so a mission file's
--- Scavengers.Skirmish is a checked name and not a string.

--- The packs. Skirmish is pressure with no ending of its own — a mission's
--- triggers end it. Assault is a real fight. Horde is the multiplayer mode,
--- boss included.
---@class ScavengerPacks
---@field Skirmish WavePackRef
---@field Assault WavePackRef
---@field Horde WavePackRef

---@type ScavengerPacks
Scavengers = {}
