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

---Shared table for gadgets.
GG = {}
