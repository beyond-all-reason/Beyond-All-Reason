---@meta

---@class Gadget : Callins, UnsyncedCallins, SyncedCallins
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

---@class GadgetInfo
---@field name string?
---@field desc string?
---@field author string?
---@field date string?
---@field license string?
---@field layer number?
---@field enabled boolean?

---@class FullGadgetInfo : GadgetInfo
---@field filename string
---@field basename string


---Get info about a gadget.
---@return GadgetInfo
function Gadget:GetInfo() end

---@type Gadget
---@diagnostic disable-next-line: lowercase-global
gadget = nil

---Shared table for gadgets.
GG = {}