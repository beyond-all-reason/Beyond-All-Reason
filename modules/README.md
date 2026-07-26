# Modules

A module is a directory that answers questions for one concern, like "may this transport pick that up." A pipeline is the ordered list of rules that answers one question, and a mod changes the answer by adding, moving or replacing one rule in that list, never by editing the file it lives in. The rules read facts a gadget gathered and return plain data, so they can be tested with a table literal. A contract names every rule and every fact so that another module can refer to them without strings. Everything that can go wrong in wiring it up is a load error that names the file.

Read **The modules** for where this is going, then **How a decision flows**: it walks one real decision through the whole thing, and every word is met inside a working example. **The layout** then says where the pieces live. **Vocabulary** at the end is the reference, three columns per entry, the thing, why it exists, and the smallest real example; land on it from a search, not from the top.

## The modules

Each module owns one concern and answers its questions through pipelines in its own contract. What is in review, in stack order, and what is a candidate:

| Module | Owns | Status |
|---|---|---|
| `defs` | Def post-processing as a fold: what the base game does to every unit and weapon def, and where a module adds its own. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/9110) |
| `modes` | The mode grammar and the game axis: one selector, the presets, the export the lobby reads. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/9111) |
| `transport` | Who may load and unload what, and how fast a loaded transport flies. The first module with real rules; the air transport rework builds on it. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8965) |
| `construction` | What may be built, and by whom: assist, reclaim, resurrect, build delay, geo and mex upgrades. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8520) |
| `economy` | How a shared pool is distributed. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8524) |
| `transfer` | What may pass between allied teams: units, resources, take, and the tax on what flows. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8521) |
| `tech` | The keystones that raise a team's tier, and the tier as a fact construction and transfer read. Tech Core is its preset. | [in review](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/8490), [Tech Core](https://github.com/beyond-all-reason/Beyond-All-Reason/pull/9038) |
| `combat` | Damage, targeting and protection as a lifetime. | candidate |
| `placement` | Where a thing may legally stand, answered once. | candidate |
| `matchflow` | How and when a game ends. | candidate |

Modules land one at a time, each with its own contract, policies and specs.

## How a decision flows

A gadget gathers facts and asks. The pipeline decides. The module's actions act. Here is transport asking, exactly as it ships:

```lua
function gadget:AllowUnitTransport(_, transporterDefID, _, transporteeID, transporteeDefID)
	local _, y = Spring.GetUnitPosition(transporteeID)
	return decideLoad({
		goalY = y,
		height = Spring.GetUnitHeight(transporteeID),
		carrierDef = UnitDefs[transporterDefID],
		passengerDef = UnitDefs[transporteeDefID],
	})
end
```

**The context.** Each step gets that table: plain facts the gadget read from the engine for this one ask. Facts are values, never functions and never memories. Anything that has to be remembered between asks, a timer or a count, stays in the gadget, which measures it and hands the number in. That is what lets a policy be tested with a table literal and its answer be sent anywhere.

**Order is precedence.** No guard ever says yes; each can only refuse and otherwise hand the question on. So no step is a rule by itself. The whole statement is the rule, read top to bottom, and "yes, regardless of the rest" is a matter of placement, not a verb. The load pipeline with one Select added (and a `Stunned` stage added to the contract, for demonstration only):

```lua
Policies.Pipeline(load)
	.Unless(load.Submerged, submerged)
	.Select(load.Stunned, function(ctx)
		if ctx.stunned then
			return true -- answered; nothing below runs
		end
		-- nil: not my case, keep going
	end)
	.If(load.WithinReach, withinReach)
	.Unless(load.MovingEnemy, movingEnemy)
	.Select(load.Allowed, function()
		return true
	end)
```

reads as: no submerged unit, ever; a stunned unit skips the checks; everyone else takes the long route. As boolean logic, `notSubmerged and (stunned or (withinReach and notMovingEnemy))`.

**The result.** Every pipeline has two types, written `<C, T>`. `C` is the context, `T` is the result. The result is the contract between deciding and doing, and it is always a plain table, because the same table serves the gadget that acts on it, the event it sends, and the widget that draws it. Time is handled the same way: when a load needs 60 hover frames, the pipeline returns the 60 as a term on the result and the gadget counts the frames.

**The action.** An action executes a request: the command's parameters plus the result it was granted. `api.lua` gathers, runs validate, then execute, and an action never resolves its own grant. Transfer's unit action, trimmed:

```lua
Actions.RegisterValidate(function(request)
	if request.from == request.to then
		return false, "a team cannot share with itself"
	end
	if not request.grant.canShare then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	return true
end)

Actions.RegisterExecute(function(request)
	for _, unitID in ipairs(request.validation.validUnitIds) do
		Spring.TransferUnit(unitID, request.to, true)
		applyStun(unitID, Spring.GetUnitDefID(unitID), request.grant)
	end
	return { success = true, validationResult = request.validation, policyResult = request.grant }
end)
```

If you have built this before as blockers, modifiers and listeners around an `AllowX` call, the mapping is exact. Blockers are `Unless` and `If`. Modifiers are facts, filled once, up front, with no "modify and re-query" loop. Listeners are not in the pipeline at all: they are whoever consumes the result.

**Three words that used to be one.** A *context* is the per-ask table a pipeline reads. *Facts* are the fields on it that a contract declares and other modules may fill. A *request* is what an action executes. Only the first is ever called `ctx`.

### A mod

A mod, or another module, changes a decision by aiming the same builder at the owner's contract. This is the whole of a mod that stops tanks being transported. Transport's own file is untouched:

```lua
-- modules/notanks/contract.lua: the step this mod adds, named where others can find it
local Transport = VFS.Include("modules/transport/contract.lua")

return PolicyBuilder.Contract("notanks", {
	Load = PolicyBuilder.Contributes(Transport.Load, { TanksStayOnTheGround = "TanksStayOnTheGround" }),
})
```

```lua
-- modules/notanks/policies/load.lua
local Transport = VFS.Include("modules/transport/contract.lua")
local Contract = VFS.Include("modules/notanks/contract.lua")

Policies.Pipeline(Transport.Load).Unless(Contract.Load.TanksStayOnTheGround, function(ctx)
	local moveDef = ctx.passengerDef and ctx.passengerDef.moveDef
	return moveDef ~= nil and moveDef.name:lower():find("^tank") ~= nil
end)
```

The owner's steps run first, other modules' follow in module-name order, and a new step joins just before the answer unless `.Before` or `.After` says otherwise. Guards compose with AND: anyone can add one, and adding can only tighten. Loosening a rule you do not own touches that rule, by name: `Remove` it, `Replace` it, or exempt from all of them with a Select above. That asymmetry is deliberate. Tightening is safe to let anyone do blind; loosening is not.

### A fact

Where an owner expects loosening, it puts the knob on the context as a fact, so nobody has to `Replace` anything. Transfer declares the facts others may fill, and Tech Core, a module up the chain, fills one:

```lua
-- transfer's contract
TeamPairing = PolicyBuilder.Facts({ TechBlocking = "techBlocking", TaxRate = "taxRate" }),
```

```lua
-- tech's policy file
Policies.Enrich(Contract.TeamPairing).Provide(Contract.TeamPairing.TaxRate, function(ctx, springRepo, senderTeamID)
	return tieredRate(ctx, springRepo, senderTeamID)
end)
```

```lua
-- transfer's own default: what the fact means when no live module fills it
Policies.Enrich(Contract.TeamTerms).Default(Contract.TeamTerms.TaxRate, function(ctx)
	return modOptionTax(ctx.opts)
end)
```

Two modules may both provide the same fact. The mode decides which one is live: a preset makes the module that ships it live, plus any module it names with `.Uses`, and a module that ships no presets is always live. Tech's provider is live under the Tech Core preset, and under Customize because that preset says `.Uses(TechModule)`; under Enabled it is not, and transfer's Default answers. At load the runtime walks every combination of presets a lobby could select and refuses one that would leave two live providers for one fact, naming the presets and both files. Should it happen in a running game anyway, two answers for one ask is the same error.

### What the loader refuses

Everything that can go wrong in wiring is a load error that names the file:

- a directory under `modules/` with no `module.lua`, or a manifest whose name does not match its directory
- a step added under a name no contract declares
- a name in a contract that never lands on the pipeline, the owner's or a contributor's
- two modules adding the same step name
- a Single pipeline that does not end in a Select
- a declared fact with no Default from its owner
- a preset combination that leaves two providers live for one fact
- a policy or action file that returns a value, which the include shim would cache and the registration would be lost

There is no registry to add yourself to and no global to poke. Contracts, policies, defaults and presets are all read from files, so the lobby, the synced game and the widgets see the same set.

## The layout

A module is one directory under `modules/`. The loader knows these files and folders and nothing else. Every entry is optional except the manifest.

| File | Why | Example |
|---|---|---|
| `module.lua` | The manifest. Names the module (it must match the directory) and lists what it requires. No manifest, no module: any other directory under `modules/` is ignored. | `return { name = "defs", description = "Def post-processing as pipelines", requires = {} }` |
| `contract.lua` | The one file to read to know what a module decides, which of those decisions others may change, and which facts it takes from them. Declares each pipeline's step names, how its steps combine, and the context it reads. | see **In contract.lua** below |
| `policies/` | The rules. Each file builds pipelines against a contract, its own or another module's, with `Policies.Pipeline(...)`. Any file here is found; there is nothing to register. | `modules/transport/policies/transport.lua` |
| `actions/` | The only effectful code. One file per action, registering a pure `validate` and one `execute`. A pipeline decides, an action does. | `modules/transfer/actions/units.lua` |
| `state.lua` | What the module keeps in memory, declared once as a class and anchored once per Lua state. A file-level table that is written after load lives here, never in a `local`: `VFS.Include` is uncached, so a local is one copy per includer. | see **In a gadget, widget or lib** below |
| `api.lua` | What other modules and the game's own files call. Included directly, `VFS.Include("modules/defs/api.lua") ---@type DefsApi`, so it is typed at the call site. | `Defs.PrebakeUnitDefs()` from `gamedata/unitdefs_post.lua` |
| `lib/` | The module's own helpers. Ordinary include paths, no loader involvement. | `modules/defs/lib/base.lua` |
| `enums.lua` | The module's names as values, so nothing refers to them by string. `modules/enums.lua` at the root is the enum of modules themselves. | `Modules.Defs`, `TransportEnums.ModOptions.CommanderTransportSlow` |
| `modes/` | Presets, one file each, written in the mode grammar. A preset makes the module that ships it live. | `modules/modes/modes/ffa.lua` |
| `modoptions.lua` | The module's fragment of the game's options. The root `modoptions.lua` appends every module's fragment, so a module that ships options needs no change to the root file. | `modules/modes/modoptions.lua` |
| `gadgets/`, `widgets/`, `rml_widgets/`, `scripts/` | The game's own kinds of file, loaded the way the game already loads their loose equivalents. Gadgets and widgets are added to the handler's list; unit scripts join the script loader's registry under their `modules/` path. | `modules/transport/gadgets/transport_rules.lua` |

Every file under `modules/` is loaded by the game's own handlers, in the same Lua state as the loose file it stands beside, with the same VFS mode. Synced code sees the archive only.

## Vocabulary

Every word the builder gives you, grouped by the file you write it in.

### In contract.lua

A contract declares pipelines and facts, keyed by PascalCase member. The runtime derives the data-facing key from the member, `UnitDef` becomes `unit_def`, so declarations are code-case and everything read at runtime is data-case.

| Thing | Why | Example |
|---|---|---|
| `PolicyBuilder.Contract(owner, { ... })` | Stamps every member with its owner and category, so a pipeline's identity travels with its stage enum wherever it is included. | `return PolicyBuilder.Contract("defs", { UnitDef = PolicyBuilder.Fold(UnitDef) })` |
| `Single(stages)` | A list of guards ending in a Select. Guards refuse; the first Select that answers ends it. For a question with one answer: a yes or no, or a value. Most pipelines. | `Load = PolicyBuilder.Single(Load)` |
| `Product(stages)` | Every stage is a Select returning a number, and the numbers multiply. Nothing refuses. For a modifier: loaded speed is the base speed times the commander drag. | `LoadedSpeed = PolicyBuilder.Product(LoadedSpeed)` |
| `Fold(stages)` | Every stage is a Select that receives one context, may edit it, and passes it on. Nothing refuses, nothing ends early, the context comes back. For post-processing: every unit def goes through every stage. | `UnitDef = PolicyBuilder.Fold(UnitDef)` |
| `Facts(names)` | Not a pipeline. The facts a decision reads, which other modules may fill before the pipeline is asked. A fact informs a decision; it is not the decision. | `TeamPairing = PolicyBuilder.Facts({ TaxRate = "taxRate" })` |
| `Contributes(target, names)` | The stages this module adds to another module's pipeline, named here so a third module can place a rule against them by reference. A declared name that never lands is a load error. | `UnitDef = PolicyBuilder.Contributes(Defs.UnitDef, { EnemyTransport = "EnemyTransport" })` |
| `---@class XContext` | The shape of the facts a pipeline reads, declared beside the stages, so `ctx` is typed inside every predicate without an annotation on the predicate. | `---@class DefContext` with `---@field def table` |

The stage enum is the contract's promise: a name in it is a step on the pipeline, or load fails. That holds for the owner's own stages and for anything declared with `Contributes`.

```lua
-- modules/defs/contract.lua, whole
local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class DefContext one def, on its way through post-processing
---@field name string
---@field def table the def table, edited in place
---@field modOptions table

---@class UnitDefStages: PolicyStages<DefContext, DefContext>
---@field Base string the base game's post-processing, gamedata/alldefs_post.lua
local UnitDef = { Base = "Base" }

return PolicyBuilder.Contract("defs", {
	UnitDef = PolicyBuilder.Fold(UnitDef),
	WeaponDef = PolicyBuilder.Fold({ Base = "Base" }),
})
```

### In a policy file

A policy file runs with one extra name in scope, `Policies`, bound to a registrar for that load. It builds pipelines and returns nothing.

| Thing | Why | Example |
|---|---|---|
| `Policies.Pipeline(stages)` | Opens a chain against a contract's stage enum, the owner's or another module's. | `Policies.Pipeline(Contract.Load)` |
| `.Unless(stage, fn)` | A guard that can only refuse. True refuses, false passes. It never says yes, so a mod adding one can only tighten. The predicate answers the stage's name: unless submerged. | `.Unless(load.Submerged, function(ctx) return ctx.submerged end)` |
| `.If(stage, fn)` | The same guard inverted: false refuses, true passes. If within reach. | `.If(load.WithinReach, withinReach)` |
| `.Select(stage, fn)` | The only step that can answer. Returns the pipeline's result, or nil to pass to the next step. A Single pipeline always ends in one. | `.Select(load.Allowed, function() return true end)` |
| `.Refusal(fn)` | What a no looks like, declared once by the owner. Instead of a bare `false`, a shape a widget can draw and a caller can act on. | `.Refusal(function(ctx) return { may = false, reason = "submerged" } end)` |
| `.Before(stage)`, `.After(stage)` | Where the step just added goes. Without either, a new step joins the end of the checks, just before the answer. | `.Unless(Mine.NoTanks, isTank).Before(load.Submerged)` |
| `.Replace(stage, fn)` | Swap the closure under an existing name, keeping its position. | `.Replace(load.MovingEnemy, function() return false end)` |
| `.Remove(stage)` | Drop an existing step. | `.Remove(load.Submerged)` |
| `Policies.Enrich(facts)` | Opens a provider chain against a contract's facts. | `Policies.Enrich(Contract.TeamPairing)` |
| `.Provide(fact, fn)` | Answers a fact, per ask, from the context. Nil declines and the next live provider or the Default answers. | `.Provide(Contract.TeamPairing.TaxRate, function(ctx) return tieredRate(ctx) end)` |
| `.Default(fact, fn)` | The owner's answer when no live module provides. Every declared fact must have one, or load fails. | `.Default(Contract.TeamTerms.TaxRate, function(ctx) return modOptionTax(ctx.opts) end)` |

Transport's load pipeline, as it ships:

```lua
local load = Contract.Load

Policies.Pipeline(load)
	.Unless(load.Submerged, submerged)
	.If(load.WithinReach, withinReach)
	.Unless(load.MovingEnemy, function(ctx)
		return ctx.allied == false and (ctx.passengerSpeed or 0) >= NAP_MAX_SPEED
	end)
	.Select(load.Allowed, function()
		return true
	end)
```

Every step is a name in a contract: the owner's from its own stages, anyone else's from what its contract declares with `Contributes`. A string typed inline is refused at load, naming the file and the contract it should have gone in.

### In a gadget, widget or lib

| Thing | Why | Example |
|---|---|---|
| `Modules.X` | A module by name, from `modules/enums.lua`. Code never names a module by string. | `local Modules = VFS.Include("modules/enums.lua").Modules` |
| `ModuleHandler.LoadPolicies(Modules.X)` | The module's assembled pipelines, keyed by data-case category, every contributor's steps applied. Read once at file scope. | `local pipelines = ModuleHandler.LoadPolicies(Modules.Transport) ---@type TransportPipelines` |
| `ModuleHandler.Evaluate(pipeline, ctx, ...)` | Asks. Runs the steps in order under the contract's strategy and returns the result, or the refusal. | `return ModuleHandler.Evaluate(pipelines.load, ctx) == true` |
| `ModuleHandler.Enrich(facts, modOptions, ctx, ...)` | Fills a contract's facts for one ask: the live providers answer, nil declines, the Default fills the rest. | `local terms = ModuleHandler.Enrich(Contract.TeamTerms, opts, ctx)` |
| `ModuleHandler.LoadActions(Modules.X)` | The module's actions by name. `api.lua` fronts this: validate, then execute, and nothing reaches execute around it. | `ModuleHandler.LoadActions(Modules.Transfer).byName.units` |
| `ModuleHandler.State(Modules.X)` | The module's one in-memory table per Lua state. Called only from the module's `state.lua`, which declares its class and returns it. | see below |
| `Actions.RegisterValidate(fn)`, `Actions.RegisterExecute(fn)` | In an action file: the pure precondition over the request, and the one effectful function. Validate must come first; execute is required. | `modules/transfer/actions/units.lua` |

```lua
-- modules/defs/state.lua, whole
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class DefsState
---@field alldefs table|nil gamedata/alldefs_post.lua, included on first use
local state = ModuleHandler.State(Modules.Defs) ---@type DefsState

return state
```

Readers include `state.lua`, never call `State` themselves, and get the class:

```lua
local state = VFS.Include("modules/defs/state.lua") ---@type DefsState
if state.alldefs == nil then
	state.alldefs = VFS.Include("gamedata/alldefs_post.lua")
end
```

## What to keep

- A pipeline is the whole rule; a step is not. Read it top to bottom, and place your step where the precedence says.
- A guard can only refuse, and only a Select can answer. Loosening touches the rule by name; tightening never does.
- Facts inform a decision and are filled before it runs; a Select makes the decision. The mode decides whose fact is live.
- The contract is the map: every step and every fact is a name there, and every wiring mistake is a load error that points at it.
- A gadget gathers and acts; it never decides. State it must keep lives in `state.lua`, once per Lua state.

## Modes

`mode_builder` turns a preset file into a ModeConfig. It has no runtime of its own; each module binds its own vocabulary over it, and preset files read as a dot-only chain. A preset is a whitelist: it claims the options it needs and says which are shown, hidden or locked, and the lobby shows exactly what it claims.

### In a preset

Every verb is documented where the editor shows it, `modules/modes/types/mode_policy.lua`, with the option it writes. The ones every module shares:

| Thing | Why | Example |
|---|---|---|
| `Mode(name)` | Starts a preset. The category is not a parameter: the grammar binds every chain from a module to that module's axis, and the name only names it. | `return Mode("FFA")` |
| `.Desc(text)` | The sentence the lobby shows under the mode's name. | `.Desc("Free for all: every player for themselves.")` |
| `.Ranked()` | Whether the mode may count for rating. Never saying it means unranked, and the pin is written either way, so the lobby never has to pin it itself. | `.Ranked()` |
| a claim verb | Writes one option. Verbs that pick from a list take an enum, not a string. A bare claim is a suggestion and leaves its option open. | `.End(DeathMode.OwnCommander)`, `.MaxUnits(2000)` |
| `.Locked()` | Pins the last claim's structure; its dials stay editable. | `.Wreckage(true).Locked()` |
| `.Sealed()` | Pins the last claim outright, dials included. | `.UnitRestrictions().Sealed()` |
| `.Hidden()` | Keeps the last claim out of the lobby UI; its pin still applies. | `.FogOfWar(true).Hidden()` |
| `.Unlocked()` | The last claim is fully editable. Rule verbs come back pinned, so this is how a preset opens one. | `.Allow(Transfer.Units).Unlocked()` |
| `.Uses(contract)` | A module whose fact providers this preset makes live, besides the one that ships it. Named by its contract, never a string. | `.Uses(TechModule)` |
| `.RetainValues()` | A non-sticky preset: picking it exposes and unlocks its claims but keeps the current values as the starting point. | `.RetainValues()` |

The FFA preset, whole:

```lua
local ModeDSL = VFS.Include("modules/modes/mode_dsl.lua") ---@type GameModeDSL
local Mode = ModeDSL.Mode
local DeathMode, DraftMode, AnonymousMode = ModeDSL.DeathMode, ModeDSL.DraftMode, ModeDSL.AnonymousMode

return Mode("FFA")
	.Desc("Free for all: every player for themselves. Losing your commander resigns you, and the fallen leave wreckage behind.")
	.Ranked()
	.End(DeathMode.OwnCommander)
	.Wreckage(true).Locked()
	.MaxUnits(2000)
	.Draft(DraftMode.Random)
	.Anonymous(AnonymousMode.Disabled)
	.EnemyTransporting("notcoms")
	.UnitRestrictions()
```

### The game axis

A match is exactly one way of being played, so there is one selector, `game_mode`, owned by the mode infrastructure rather than any flavor. The presets are Standard, FFA, Team FFA and Territorial Domination.

- Section entries in a module's `modoptions.lua` can declare `mode_category` (which axis governs their options) and `mode_key` (which preset reveals them).
- The root `modoptions.lua` appends every module's fragment through `ModuleHandler.ModOptions()`, so a module that ships options needs no change to the root file.
- `modules/modes/lib/values.lua` is the one formatter for a mode value on the wire (booleans as `1`/`0`, numbers at float32 precision). The export widget bakes `modes.json` with it and the lobby includes it out of the game archive, so neither side carries a copy. `tools/headless_testing/startscript_modes_export.txt` runs that export headless.
- A preset says what it makes live. The runtime walks every combination of presets at load and refuses one that leaves two providers live for one fact.
