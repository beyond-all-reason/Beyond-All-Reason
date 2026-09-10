# Modules

**A module** is a collection of all the code related to a particular area. It includes everything - gadgets, widgets, unit scripts, and modoptions.

## Creating a module

The loader reads the module's manifest.lua to decide whether to load it or not. Directories in `modules/` that don't have one are ignored by the module loader.

An example of a manifest.lua:
```lua
return { name = "transport", 
		 description = "Code governing transports, such as loading rules or passenger state", 
		 requires = { "defs" } } -- The loader will raise a warning if the "defs" module isn't loaded.
```

`name` is a required field, and must match the name of the module directory.

**Directory structure**

The loader expects code in the following subdirectories:
`gadgets/`, 
`widgets/`, 
`rml_widgets/`, 
`scripts/`

It'll load the stuff in `<module>/gadgets/` as a gadget, `widgets/` as a widget, and so on.

If you make a `modoptions.lua`, the loader will add its contents to the base modoptions.

**`<module>/state.lua`**

Module-scoped state and variables should be placed here. This file should declare a big struct with all the module's state and return it.
Consumers access this state by including state.lua, like so:
`local MyModuleState = VFS.Include("modules/<module>/state.lua")`

A state.lua looks like this:
```lua
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

-- Type annotations for the type checker
---@class MyModuleState
---@field MyField table<integer, number> description of my field
... other fields...
local state = ModuleHandler.State(Modules.Transport) ---@type MyModuleState

-- This gets run every time someone gets the state, so use previously set value, if there is one
state.MyField = state.MyField or {}
... initialize other fields

return state
```
