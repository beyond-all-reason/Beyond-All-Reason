---@meta

---@class Gadget : Addon, RulesSyncedCallins
---
---Gadgets can control game logic and receive synced and unsynced callins.
---
---**Attention:** Callins from `SyncedCallins` will only work on the unsynced
---portion of the gadget.
---
---**Attention:** To prevent complaints from Lua Language Server, e.g.
---
---> ```md
---> Duplicate field `CommandNotify` (duplicate-set-field)
---> ```
---
---Add this line at the top of your gadget script:
---
---```lua
---local gadget = gadget ---@type Gadget
---```
---
---@see Callins
---@see SyncedCallins
---@see UnsyncedCallins
---@see Spring.IsSyncedCode
---
---@field ghInfo FullGadgetInfo
local Gadget = {}

---@class FullGadgetInfo : AddonInfo
---@field filename string
---@field basename string

---@type Gadget
---@diagnostic disable-next-line: lowercase-global
gadget = nil

---Shared table for gadgets.
GG = {}