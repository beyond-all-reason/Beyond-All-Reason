---@meta

---@class Widget : Addon, RulesUnsyncedCallins
---
---Widgets cannot control game logic and receive only unsynced callins.
---
---**Attention:** To prevent complaints from Lua Language Server, e.g.
---
---> ```md
---> Duplicate field `CommandNotify` (duplicate-set-field)
---> ```
---
---Add this line at the top of your widget script:
---
---```lua
---local widget = widget ---@type Widget
---```
---@see Callins
---@see UnsyncedCallins

---@type Widget
---@diagnostic disable-next-line: lowercase-global
widget = nil

---Shared table for widets.
WG = {}