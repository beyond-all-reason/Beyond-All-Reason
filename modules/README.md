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

| directory | what goes there | read by |
|---|---|---|
| `gadgets/` | gadgets, loaded as the game's own `luarules/gadgets/` are | the loader |
| `language/` | `language/<code>/*.json` - translation strings, merged with the game's `language/<code>/`. `units.json` there names and describes the module's units | the loader |
| `modes/` | declarative presets of game behavior configuration | the loader: the lobby lists them, the game reads the picked one for the live set |
| `policies/` | typed functions from a context to a result | the loader |
| `rml_widgets/` | RmlUi widgets | the loader |
| `scripts/` | unit scripts. Lua only, no `.cob` (engine restriction) | the loader |
| `units/` | unit defs. Subfolders are the same (`units/ArmBuildings/TechCore/armkeystone.lua`) | the loader |
| `widgets/` | widgets | the loader |
| `spec/` | unit tests | busted, on the host; the game ignores it |
| `tests/` | headless tests | the test runner, in a test match; the game ignores it |

By convention, we put stateless helper functions in `lib/`.

And the following files:

| file | what it is |
|---|---|
| `api.lua` | "common" entry-points to your module (a service). Runs in any engine Lua handle |
| `api_synced.lua` | "synced" function entry-points |
| `api_unsynced.lua` | "unsynced" function entry-points to your module |
| `synced.lua`, `unsynced.lua` | code behind `api_synced.lua` and `api_unsynced.lua` that is bound to that one handle; anything else under the module runs in any |
| `enums.lua` | please use these |
| `mode_verbs.lua` | lets a lobby preset set your modoptions: the verbs it may use, and what they write to modoptions |
| `modoptions.lua` | merge with the base modoptions |
| `state.lua` | cached state, typed, owned, and managed by your module |

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
* **api** - common: this file is available in all Lua states (gadgets, widgets, lobby), so it can only call Spring functions that are available everywhere

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

> As a BAR module developer, I want to be sure of which engine handle I am operating in.

`spec/modules/module_env_spec.lua` holds every module to it. `api.lua`, `policies/` and `lib/` may not `require` a file bound to one handle (`api_synced.lua`, `synced.lua`, anything under `widgets/`) and call nothing the engine offers in one handle only. The named files are one half only: `api_synced.lua` and any `synced.lua` call nothing offered only in the unsynced handle, `api_unsynced.lua` and anything under `widgets/` the reverse. For example `Spring.SetUnitPosition` exists only in the synced handle and `Spring.GetSelectedUnits` only in the unsynced one: `api.lua` may call neither, `api_synced.lua` the first and not the second.

A gadget is the one file that runs in both handles, a half for each chosen by `gadgetHandler:IsSyncedCode()`; the rule leaves gadgets alone. The two handles never call each other; they pass messages (`SendToUnsynced`, `SendLuaRulesMsg`).

### lib/
This directory holds your private module code.

### Policies

**`<module>/policies/<name>.lua`**
Policies are for module code you think others might want to extend. If you don't want to make extensible code, you don't need a policy, you need `lib/` and standard Lua code.

The first module to declare a particular policy is referred to as the "owner". People who extend the policy are "contributors". Owners have more control than contributors.

Policies lean heavily on the type system (EmmyLua). They declare an input called a Context and return a result. If a policy fails to return result, that policy "failed". Failure, and therefore error messages, is the responsibility of the owner.

Here is a policy from `modules/construction/policies/assist.lua`, annotated with numeric comments correlating to the description lines below:
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
7. `.Unless(Assist.AlliedAssistDisabled, function(ctx)` - a logic gate. Returning false passes, and evaluation proceeds to the next step. Returning true refuses: the policy answers with the owner's `Refusal`, or `false` when none is declared, which is what this boolean policy wants.
8. `.Answer(Assist.Allowed, function()` - all of our gates passed, return true.
9. `---@class (partial) ConstructionContract` - this policies place on the module contract, which is what callers get from `ModuleHandler.Contract`. The (partial) allows policies to construct this contract across multiple files.
10. `return Contract` - hand the loader the contract for evaluation later.

Consumer example from `modules/construction/gadgets/game_allied_assist_mode.lua`:

```lua
---@param unitTeam integer the builder's team
---@param targetID integer|nil
---@param targetIsBuilder boolean
---@return boolean
local function mayAssist(unitTeam, targetID, targetIsBuilder)
	---@type ConstructionContract -- (1)
	local Construction = ModuleHandler.Contract(Modules.Construction)
	---@type ConstructionAssistContext
	local ctx = {
		allied = isAlliedUnit(unitTeam, targetID) == true,
		targetComplete = targetID == nil or isComplete(targetID),
		targetIsBuilder = targetIsBuilder,
		assistEnabled = assistEnabled,
	}
	return ModuleHandler.Evaluate(Construction.Assist, ctx) == true -- (2)
end

local function isBuilderAllowedCommand(cmdID, p1, p2, p5, p6, unitTeam)
	if cmdID == CMD_GUARD then
		return mayAssist(unitTeam, p1, (p1 and canBuildStep[spGetUnitDefID(p1)]) == true)
    ...
```
1. the module contract we created in the policy
2. evaluate or "get an answer" from the policy

EmmyLua can "Navigate To Definition" and "Find All References" on `Construction.Assist`.

**The four kinds of policy**

`Policy.Single` is one of four. Each names how the steps several modules contribute are combined, and the loader combines them that way; a policy declares its kind once, where its steps are declared.

| kind | the steps combine as | result | example |
|---|---|---|---|
| `Single` | guards in order (`If`, `Unless`), the first refusal wins, then one `Answer` | `T` | may a builder help an ally's unit along |
| `Fold` | every `Apply` step runs on the same value, in declared order; the owner's steps first, then each contributor's | the value, `C` | every unit def through the base game's post, then transport's and tech's steps |
| `Product` | every `Factor` multiplies | a number | a loaded transport's speed: the base factor times the commander drag |
| `Facts` | named slots a module `Provide`s; the owner's `Default` answers a slot nobody filled, and a slot with no Default is the context's own field of that name; two live modules answering one slot is a load error | a table of answers | a team's tier; who holds a mex spot; a team's tax rate |

#### Contributing to another module's policy
A module adds a step to a policy it does not own by declaring the step's name under `Policy.Contributes(target, names)` and attaching it with the same verbs. Tech's `modules/tech/policies/creation.lua`:

```lua
---@type ConstructionContract
local Construction = Policies.Contract(Modules.Construction)

---@class TechConstructionCreationSteps: PolicySteps<ConstructionCreationContext, boolean>
---@field BelowTier "BelowTier"
local Creation = Policy.Contributes(Construction.Creation, { BelowTier = "BelowTier" })

Policies.For(Construction.CreationFacts).Provide(Construction.CreationFacts.Tier, function(ctx)
	return tonumber(ctx.springRepo.GetTeamRulesParam(ctx.teamID, "tech_level"))
end)

Policies.On(Creation).Unless(Creation.BelowTier, function(ctx)
	return ctx.tier ~= nil and ctx.unitDef.isFactory and required(ctx.unitDef) > ctx.tier
end)
```

Construction asks `Evaluate(Construction.Creation, ctx)` and knows nothing of tech. Construction declared a `Tier` fact it cannot answer (its `Default` is nil: no tier system); tech provides it, and refuses a lab above the team's tier. Delete `modules/tech` and every lab opens at tier one again. The loader refuses a step whose name neither the owner nor a contributor declared. A fact needs no Default to be provided: a slot nobody provides and the owner never defaulted is the context's own field of that name, which is how the engine's answer stands when no module knows better.

**What a step may read.** A step or a provider gets its context and nothing else. The context carries the modoptions (`ctx.modOptions`) and the engine (`ctx.springRepo`, the real `Spring` in the game and a stand-in in a spec); no policy file imports `Spring`. That is what makes a policy evaluable on the host without an engine.

**A module speaks its own words.** A lower module never names a higher one: construction has a `tier`, not a tech level; economy has `shares` and a `taxRate`, not transfer's sharing modes. Where a lower module needs a sentence only a higher one can write, it asks for the sentence as a fact. Transfer's tooltips ask `UnitTermsNotes.Opening`, a clause on what would open sharing further; tech provides "Constructors unlock at Tech 2 (1/3 Keystones)", in its own language file. Transfer never learns the word Keystone.

See the `policies_getting_started` for more information.

### Modes

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

Each verb is one claim: `.FogOfWar(true)` claims the fog-of-war modoption and sets it. A mode belongs to a category, the axis the lobby shows it on: the game module's modes are the `game_mode` list ("Standard", "FFA", "Team FFA", "Territorial Domination"), transfer's (`Enabled`, `Easy Tax`, `Tech Core`, ...) are the `transfer_mode` list. The category is not written in the mode; the grammar it is built with binds it.

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

Beside `verbs`, a fragment may bring two more things to the axis:

* `nouns = function(nouns)` adds the module's nouns to the grammar, or decorates another module's. Tech adds `Tech` and gives transfer's grants a tier: `Transfer.Units.Constructors.AtT2` is the same grant, written to the option tech reads once a team reaches Tech 2 (a noun may name the option it writes).
* `expose = function(modeName)` returns the module's dials at their starting point. A preset that lets the player tweak everything says `.Expose()` and gets every module's dials, open, without naming the modules; that is how `Customize` opens tech's dials without a line about tech.

An axis's lobby option (`transfer_mode`, `game_mode`) lists the presets its owner declared, then every other module's presets for that axis, with their names. Tech Core reaches the lobby with the tech module and leaves with it.

That is why `modules/game/modes/standard.lua` can say `.EnemyTransporting(...)`: the game module's grammar merges every module's game verbs (`ModuleHandler.ModeVerbs("game")`), so transport owns the modoption, the verb and its checking, and the game module's mode just uses the word.

**Which modules are live.** The picked mode on each axis decides, by what it writes:

* A module that ships no modes is always live.
* A module that ships modes is live when one of its modes is picked, or when the picked mode writes any of its modoptions. If a mode uses a module's options, it wants that module on.

Tech ships `Tech Core` on the transfer axis and owns the tech dials, so:

* `Tech Core` picked: tech is live (its own mode).
* `Enabled` picked: tech is off (nothing of tech's is written).
* `Customize` picked: tech is live again, because `.Expose()` wrote tech's dials.

`ModuleHandler.LiveModulesFor(modOptions)` reads the picks off the `<category>_mode` modoptions. The live set decides whose providers and contributions take part when a policy is evaluated.