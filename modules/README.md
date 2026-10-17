# Modules

**A module** is a collection of all the code related to a particular area. It includes everything - gadgets, widgets, unit scripts, and modoptions.

## Creating a module

The loader reads the module's manifest.lua to decide whether to load it or not. Directories in `modules/` that don't have one are ignored by the module loader.

An example of a manifest.lua:
```lua
return {
	name = "transport", 
	description = "Code governing transports, such as loading rules or passenger state", 
	requires = { "defs" } -- The loader won't load this module, and logs an error, if its requirements aren't loaded.
}
```

`name` is a required field, and must match the name of the module directory.

**Directory structure**

The loader expects code in the following subdirectories:
`gadgets/`, 
`widgets/`, 
`rml_widgets/`, 
`scripts/`,
`policies/`,
`modes/`,

And the following files:
`api.lua`,
`api_unsynced.lua`,
`api_synced.lua`,
`enums.lua`,
`mode_verbs.lua`,
`modoptions.lua`,

It'll load the stuff in `<module>/gadgets/` as a gadget, `widgets/` as a widget, and so on.
It will only load unit scripts from `scripts/`. .cob files won't be loaded.

If you make a `modoptions.lua`, the loader will add its contents to the base modoptions.

**`modules/enums.lua`**

This file defines the enums for all the modules. You'll want to add an entry for yours here. The module handler uses the enum to refer to the module, and you need to provide the mapping from that to the directory name.

```lua
local Modules = {
	Defs = "defs",
	Game = "game",
	MyModule = "my_module",
}
```

**`<module>/state.lua`**

Module-scoped state and variables should be placed here. This file should declare a big struct with all the module's state and return it.
Consumers access this state by including state.lua, like so:
`local MyModuleState = require("modules/<module>/state")`

A state.lua looks like this:
```lua
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules

-- Type annotations for the type checker
---@class MyModuleState
---@field MyField table<integer, number> description of my field
... other fields...
local state = ModuleHandler.State(Modules.MyModule) ---@type MyModuleState

-- This gets run every time someone gets the state, so use previously set value, if there is one
state.MyField = state.MyField or {}
... initialize other fields

return state
```

**Note** Synced and unsynced get separate copies of state, so it's important that code producing this state is [idempotent](https://en.wikipedia.org/wiki/Idempotence).

**`<module>/api.lua`**
**`<module>/api_synced.lua`**
**`<module>/api_unsynced.lua`**

These files define the module's api. Together they act as a [service](https://en.wikipedia.org/wiki/Service_layer_pattern) for the module. Each function in this file is the only function that answers a given question. One canonical answer per game behavior.

Each file in a module speaks to one engine Lua handle (the engine's word for its Lua states: LuaRules synced, LuaRules unsynced, LuaUI), or to any of them in the case of `api.lua`, which runs in all.
* **api_unsynced** - what a widget asks that touches the unsynced engine
* **api_synced** - what a gadget asks that touches the synced engine
* **api** - neutral: it runs in any Lua state (a synced gadget, a widget, the lobby), so it calls nothing that `Spring.*` offers in one handle only.

Here is `modules/construction/api.lua`, trimmed:
```lua
local Placement = require("modules/construction/lib/placement")

---@class ConstructionApi
return {
	---@param unitDefID integer
	---@return boolean
	IsExtractor = function(unitDefID)
		return Placement.IsExtractor(unitDefID)
	end,

	---@return integer[] the unit def ids that extract metal
	Mexes = function()
		return Placement.ExtractorDefIDs("mex")
	end,

	---@return integer[] the unit def ids that extract energy from the ground
	Geos = function()
		return Placement.ExtractorDefIDs("geo")
	end,
}
```

Consumers require it as `local Construction = require("modules/construction/api")` and call `Construction.Mexes()`.

`spec/modules/handles_spec.lua` holds every module to it. `api.lua`, `policies/` and `lib/` may not `require` a file bound to one handle (`api_synced.lua`, `synced.lua`, anything under `widgets/`) and call nothing the engine offers in one handle only. The named files are one half only: `api_synced.lua` and any `synced.lua` call nothing offered only in the unsynced handle, `api_unsynced.lua` and anything under `widgets/` the reverse. For example `Spring.SetUnitPosition` exists only in the synced handle and `Spring.GetSelectedUnits` only in the unsynced one: `api.lua` may call neither, `api_synced.lua` the first and not the second.

A gadget is the one file that runs in both handles, a half for each chosen by `gadgetHandler:IsSyncedCode()`; the rule leaves gadgets alone. The two handles never call each other; they pass messages (`SendToUnsynced`, `SendLuaRulesMsg`).

**`<module>/policies/<name>.lua`**
Policies are a typed function from a context to a result, cut into named steps, assembled by the loader from every module that contributes one, and evaluated with no state but the context it's handed.

Here is a policy from `modules/construction/policies/assist.lua`, annotated with numeric comments correlating to the descriptions lines below:
```lua
local Policy = require("modules/policy")

-- (1)
-- May a builder help an ally's unit along
--
---@class ConstructionAssistContext -- (2)
---@field allied boolean
---@field targetComplete boolean
---@field targetIsBuilder boolean
---@field assistEnabled boolean

---@class ConstructionAssistPolicy: PolicySteps<ConstructionAssistContext, boolean> -- (3)
---@field AlliedAssistDisabled "AlliedAssistDisabled"
---@field Allowed "Allowed"

---@type ConstructionAssistPolicy
local Assist = { -- (4)
      AlliedAssistDisabled = "AlliedAssistDisabled",
      Allowed = "Allowed",
}
Policy.Single(Assist) -- (5)

Policies.On(Assist) -- (6)
      .Unless(Assist.AlliedAssistDisabled, function(ctx) -- (7)
              return not ctx.assistEnabled and ctx.allied and (not ctx.targetComplete or ctx.targetIsBuilder)
      end)
      .Answer(Assist.Allowed, function() -- (8)
              return true
      end)

---@class (partial) ConstructionContract -- (9)
local Contract = {}
Contract.Assist = Assist

return Contract -- (10)
```

So this policy reads top to bottom:

1. help doc explaining the entire policy block. Policy files can contain multiple policies, so having these header prefixes is useful vertical space to break up the policy blocks.
2. **ConstructionAssistContext** is the context it reads
3. **ConstructionAssistPolicy: PolicySteps<ConstructionAssistContext, boolean>** defines our policy as a list of steps, which produce a boolean.
4. The **Assist** is the policy, and its table represents specific name for each step (`AlliedAssistDisabled`, `Allowed`).
5. `Policy.Single(Assist)` registers Assist with the policy engine as a specific type of Policy. Single policies have a single answer.
6. `Policies.On(Assist)` - start a chain, evaluated in declaration order.
7. `.Unless(Assist.AlliedAssistDisabled, function(ctx)` - a logic gate. Passing (returning false in this case), proceeds on to the next step. Not passing returns false for T only by accident here.
8. `.Answer(Assist.Allowed, function()` - all of our gates passed, return true.
9. `---@class (partial) ConstructionContract` - this policies place on the module contract, which is what callers get from `ModuleHandler.Contract`
10. `return Contract` - hand the loader the contract for evaluation later.

Consumer example from `modules/construction/gadgets/game_allied_assist_mode.lua`:

```lua
---@param unitTeam integer the builder's team
---@param targetID integer|nil
---@param targetIsBuilder boolean
---@return boolean
local function mayAssist(unitTeam, targetID, targetIsBuilder)
	---@type ConstructionContract -- the module contract we created in the policy
	local Construction = ModuleHandler.Contract(Modules.Construction)
	---@type ConstructionAssistContext
	local ctx = {
		allied = isAlliedUnit(unitTeam, targetID) == true,
		targetComplete = targetID == nil or isComplete(targetID),
		targetIsBuilder = targetIsBuilder,
		assistEnabled = assistEnabled,
	}
	-- evaluate or "get an answer" from the policy
	return ModuleHandler.Evaluate(Construction.Assist, ctx) == true
end

local function isBuilderAllowedCommand(cmdID, p1, p2, p5, p6, unitTeam)
	if cmdID == CMD_GUARD then
		return mayAssist(unitTeam, p1, (p1 and canBuildStep[spGetUnitDefID(p1)]) == true)
    ...
```

EmmyLua can "Navigate To Definition" and "Find All References" on `Construction.Assist`.

See the `policies_getting_started` for more information.

**`<module>/modes/<name>.lua`** and **`<module>/mode_verbs.lua`**

A mode is a UI preset: a named bundle of claims on modoptions, written in a small grammar. Picking a mode in the lobby writes the modoptions it claims and locks the ones it says it owns. By the time the match starts the mode is gone; only the modoptions are left, and policies read those. Nothing in a gadget or a policy ever sees a mode.

Here is `modules/game/modes/standard.lua`, trimmed:

```lua
local ModeDSL = require("modules/game/mode_dsl")
local Mode = ModeDSL.Mode
local DeathMode, DraftMode = ModeDSL.DeathMode, ModeDSL.DraftMode
local TransportEnemy = require("modules/transport/enums").TransportEnemy

return Mode("Standard")
	.Desc("An ordinary game: no scripted mission, no PvE swarm.")
	.Ranked()
	.End(DeathMode.Commander)
	.Draft(DraftMode.Random)
	.FogOfWar(true)
	.EnemyTransporting(TransportEnemy.NotCommanders)
```

Each verb is one claim: `.FogOfWar(true)` claims the fog-of-war modoption and sets it. A mode belongs to a category, the axis the lobby shows it on: the game module's modes are the `game_mode` list ("Standard", "Territorial Domination", "Scavengers", ...), transfer's (`Enabled`, `Easy Tax`, `Tech Core`, ...) are the `transfer_mode` list. The category is not written in the mode; the grammar it is built with binds it.

**`<module>/mode_verbs.lua`
A module adds verbs to a category's grammar by shipping `mode_verbs.lua`. Here is `modules/transport/mode_verbs.lua`, trimmed:

```lua
return {
	category = ModeEnums.ModeCategories.Game,
	verbs = {
		EnemyTransporting = ModeBuilder.Verb(function(modeName, which)
			ModeBuilder.OneOf(modeName, "EnemyTransporting", TransportEnums.TransportEnemy, which)
			return { which = which }
		end, function(p, lock)
			return { [Opt.TransportEnemy] = { value = p.which, locked = lock.noun } }
		end),
	},
}
```

A verb is two functions:
1. `parse` (`function(modeName, which)`) checks what the mode wrote and keeps its parameters
2. `write` (`function(p, lock)`) turns them into modoptions.

That is why `standard.lua` can say `.EnemyTransporting(...)`: the game module's grammar merges every module's game verbs (`ModuleHandler.ModeVerbs("game")`), so transport owns the modoption, the verb and its checking, and the game module's mode just uses the word.

**Which modules are live.** The picked mode on each axis decides, by what it writes:

* A module that ships no modes is always live.
* A module that ships modes is live when one of its modes is picked, or when the picked mode writes any of its modoptions. If a mode uses a module's options, it wants that module on.

Tech ships `Tech Core` on the transfer axis and owns the tech dials, so:

* `Tech Core` picked: tech is live (its own mode).
* `Enabled` picked: tech is off (nothing of tech's is written).
* `Customize` picked: tech is live again, because `.Open(Tech, 1, 1.5)` writes the dials.

`ModuleHandler.LiveModulesFor(modOptions)` reads the picks off the `<category>_mode` modoptions. The live set decides whose providers and contributions take part when a policy is evaluated.