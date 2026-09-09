# Modules

**A module** is a directory under `modules/` that owns one concern and ships its own game files: gadgets, widgets, unit scripts, modoptions. The game's own handlers load them from there, so a module is a place to put things, not a new kind of thing.

This is the loader. What a module *decides*, the policy pipelines, contracts and actions, lands in the next PR on top of it; nothing here changes how the game behaves.

## The layout

A module is one directory under `modules/`. The loader knows these files and folders and nothing else. Every entry is optional except the manifest.

**`manifest.lua`**

The manifest. Names the module (it must match the directory), describes it, and lists what it requires. No manifest, no module: any other directory under `modules/` is ignored.
```lua
return { name = "transport", description = "What a carrier may pick up, and how it flies loaded", requires = { "defs" } }
```

**`gadgets/`, `widgets/`, `rml_widgets/`, `scripts/`**

The game's own kinds of file, loaded the way the game already loads their loose equivalents. Gadgets and widgets are added to the handler's list; unit scripts join the script loader's registry under their `modules/` path, so a def names one as `modules/<module>/scripts/<file>.lua`.

**`modoptions.lua`**

The module's fragment of the game's options. The root `modoptions.lua` appends every module's fragment, so a module that ships options needs no change to the root file.

**`state.lua`**

What the module keeps in memory, declared once as a class and anchored once per Lua state through `ModuleHandler.State`. A file-level table that is written after load lives here, never in a `local`: `VFS.Include` is uncached, so a local is one copy per includer.

```lua
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class TransportState
---@field carriers table<integer, integer>
local state = ModuleHandler.State(Modules.Transport) ---@type TransportState

return state
```

Readers include `state.lua` and never call `State` themselves.

## What the loader refuses

- a directory under `modules/` with no `manifest.lua` is ignored
- a manifest whose name does not match its directory is an error naming both
- a `requires` entry that names no discovered module refuses the module, and whatever required it, with an error naming both

Every file under `modules/` is loaded by the game's own handlers, in the same Lua state as the loose file it stands beside, with the same VFS mode. Synced code sees the archive only.
