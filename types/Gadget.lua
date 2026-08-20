---@meta

---@class Gadget : Addon, RulesSyncedCallins
---@field [string] any
---@field ghInfo FullGadgetInfo
---@see Callins
---@see SyncedCallins
---@see UnsyncedCallins
---@see Spring.IsSyncedCode

---@class FullGadgetInfo : AddonInfo
---@field filename string
---@field basename string

---@type Gadget
---@diagnostic disable-next-line: lowercase-global
gadget = nil

---Shared cross-gadget namespace. Gadgets publish arbitrary keys onto it at
---runtime (e.g. `GG.Crashing` from `unit_crashing_aircraft.lua`), so it is
---modelled as an open table — the analyzer cannot know the key set.
---@class GGTable
---@field [string] any

---@type GGTable
GG = {}
