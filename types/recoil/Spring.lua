---@meta

---The engine as a type per Lua handle. `Recoil` is the union: every function
---and constant, whichever handle registers it, which is what `Spring` has
---always been typed as. `Recoil.Shared` is what both handles offer, the view
---a file that runs in any handle may hold; `Recoil.Synced` and
---`Recoil.Unsynced` extend it with what one handle registers alone.
---
---Nothing moves at run time: the engine registers into `Spring` as before.
---A file bound to one handle casts it to that handle's view where it imports
---it, and the checker refuses the other handle's functions there:
---
---```lua
---local Spring = Spring --[[@as Recoil.Synced]]
---```
---@class Recoil : Recoil.Synced, Recoil.Unsynced
local Recoil = {}

---@type Recoil
Spring = {}
