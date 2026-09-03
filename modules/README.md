# Modules

The whole thing in five sentences. A module is a directory that answers questions for one concern, like "may this transport pick that up." A pipeline is the ordered list of rules that answers one question, and each rule has a name. A contract is the list of those names, so another module or a mod can say "put my rule after this one" or "replace that one." A context is the plain table of facts the gadget hands the pipeline when it asks: who, where, what the modoptions say. A mode is a preset of modoptions that says which dials are locked or hidden.

## Modules

A module is one directory under `modules/` that owns one concern. Its `module.lua` manifest names it and lists what it requires; directories with no manifest are ignored.

```lua
return {
	name = "transfer",
	description = "Allied transfer: units, resources, take, and the tax on what flows",
	requires = { "construction", "economy" },
}
```

Code never names a module by string. `modules/enums.lua` exports `Modules`, one entry per module, added in the commit that adds the module, and every loader call takes it: `ModuleHandler.LoadPolicies(Modules.Transfer)`. A rename follows every reader. The only other way to refer to a module is its contract, which is what a preset's `.Uses` and the facts accessors take.

Inside a module the loader knows the folders that correspond to the game's own and loads them the way the game already loads their loose equivalents:

- `gadgets/`, `widgets/`, `rml_widgets/` and `spec/`, as today.
- `scripts/`, listed next to `scripts/` by the unit script loader; a def names a Lua unit script by its full `modules/` path. COB scripts and models stay where the engine looks for them.
- `contract.lua`, `policies/`, `actions/`, `lib/`, `state.lua` and `api.lua` are the module's own and are reached by ordinary include paths. What each of them is for is below.

Def post-processing belongs to a module too. The small `defs` module owns the `unit_def` and `weapon_def` pipelines whose first stage is the base game's `alldefs_post`, so a module that must touch a def contributes a named stage instead of editing gamedata. Transport's enemy-transport rule is the first.

## Policy runtime

Most of what a module does is answer a question: may this transport load that unit? What does this team's tax rate come to? Who won? Each is answered by a pipeline: a list of named steps, run in order.

- A guard checks a condition. `If(WithinReach, ...)` lets the request through when the condition holds; `Unless(Submerged, ...)` lets it through when the condition does not. Otherwise the pipeline refuses. The predicate answers the step's own name, so the code reads like the sentence: if within reach, unless submerged.
- A `Select` produces the answer. The last step of a pipeline is always one. An earlier `Select` may answer early, or pass by returning nothing.

Transport's load pipeline:

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

No guard ever says yes. `Unless` and `If` are inversions of the same thing: each can only refuse, and otherwise hands the question to the next step. So no step is a rule by itself. The whole statement is the rule, read top to bottom, and the only step that can end it with a yes is a `Select`.

That makes "yes, regardless of the rest" a matter of placement rather than a verb. The same pipeline with one `Select` added (and a `Stunned` stage added to the contract for demonstration only):

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

reads as: no submerged unit, ever; a stunned unit skips the checks; everyone else takes the long route. As boolean logic this is `notSubmerged and (stunned or (withinReach and notMovingEnemy))`. Order is precedence. Mods can easily insert their own stages into this pipeline with `Before(load.Submerged)` (or `After`).

**Contexts.** Each step gets a context: a plain table of facts the gadget gathered from the engine for this one ask. Here is transport asking, exactly as it ships:

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

The contract names that shape once, so `ctx` is typed inside every predicate without an annotation on the predicate itself:

```lua
---@class TransportLoadContext
---@field goalY number
---@field height number|nil
---@field carrierDef table|nil
---@field passengerDef table|nil
---@field allied boolean|nil
```

Facts are values, never functions and never memories. The gadget reads the engine once per ask, and anything that has to be remembered between asks, a timer or a count, stays in the gadget, which measures it and hands the number in. That is what lets a policy be tested with a table literal and its answer be sent anywhere.

**The contract.** A module declares its pipelines once, in `contract.lua`. It is the one file to read if you want to know what a module decides, which of those decisions others may change, and which facts it takes from them.

Each pipeline entry declares three things:

- Its step names. Everyone, the owner and any mod, refers to a step through these.
- How it combines its steps' results, the strategy, below.
- The context it reads, as a type, so `ctx` is typed inside every predicate.

```lua
local Load = { Submerged = "Submerged", WithinReach = "WithinReach", MovingEnemy = "MovingEnemy", Allowed = "Allowed" }

return PolicyBuilder.Contract("transport", {
	Load = PolicyBuilder.Single(Load),
	LoadedSpeed = PolicyBuilder.Product(LoadedSpeed),
})
```

**Combination strategies.** The contract's declaration decides how the runtime evaluates a pipeline. There are four.

- **Single.** A list of guards ending in a Select. `Unless` and `If` refuse; the first Select that answers ends it. Use it when the question has one answer: may this transport load that unit (a yes or no), or what is this team's tax rate (a value). Most pipelines are Single, including the load pipeline above.
- **Product.** Every stage is a Select that returns a number, and the answers multiply into one. Nothing refuses. The modifier question: how fast does this transport fly loaded, where the base speed and the commander drag each contribute a factor.
- **Fold.** Every stage is a Select that receives one context, may edit it, and passes it on. Nothing refuses and nothing ends it early; the pipeline hands the context back. Def post-processing: `alldefs_post` is the Base stage and each module's def edits are named stages after or before it.
- **Facts.** Not a pipeline: the named facts a decision reads, which other modules may fill in before the pipeline is asked (see Mods). Transfer's `TeamPairing` facts include `TaxRate`, and Tech Core fills it with the tiered rate. Every declared fact is a promise: the owner gives it a `Default`, transfer's is the flat modoption rate, so a pipeline can read it whether or not anyone else is loaded. Any number of modules may provide the same fact. Which of them answers is the mode's decision, below, never a load-time race between modules. A fact informs a decision; it is not the decision.

One more declaration sits alongside them. **Contributes** names the stages a module adds to another module's pipeline, so a third party can place a rule against them by reference and the runtime can refuse to assemble the target if a declared name never lands. It is independent of strategy: transfer contributes a guard to construction's Single build pipeline, transport a stage to the defs Fold.

**Refusal.** A pipeline may declare, once, what a no looks like. Instead of a bare `false`, the owner hands back a shape (`{ may = false, hoverFrames = 40, hoverFramesNeeded = 60 }`) so a widget can draw the reason and a caller can ask again with a bigger fact. It is a Select for failure.

Three words that used to be one. A **context** is the per-ask table a pipeline reads. **Facts** are the fields on it that a contract declares and other modules may fill. A **request** is what an action executes. Only the first is ever called `ctx`.

## Actions

A pipeline says whether a thing may happen and on what terms. An action is the thing happening, and it is deliberately the only effectful code in a module. Each file under `actions/` registers a pure precondition and one execute. This is transfer's unit action, `modules/transfer/actions/units.lua`, with the shape checks and the result table trimmed. Nothing in it asks the engine a question: the api resolved the pair's grant and applied it to each unit before the request arrived.

```lua
Actions.RegisterValidate(function(request)
	if request.from == request.to then
		return false, "a team cannot share with itself"
	end
	if not request.grant.canShare then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	if request.validation.status == UnitValidationOutcome.Failure then
		return false, "none of the units may pass under the active mode"
	end
	return true
end)

Actions.RegisterExecute(function(request)
	local policyResult, validation = request.grant, request.validation
	for _, unitID in ipairs(validation.validUnitIds) do
		Spring.TransferUnit(unitID, request.to, true)
		applyStun(unitID, Spring.GetUnitDefID(unitID), policyResult) -- stunSeconds and stunCategory come off the policy result
	end
	Spring.SendLuaUIMsg("unit_transfer:success:" .. request.from, "")
	return { success = true, outcome = validation.status, validationResult = validation, policyResult = policyResult }
end)
```

The module's `api.lua` gathers, runs validate, then execute, and a caller never reaches execute around it. What an action executes is a request: the command's parameters plus the policy result it was granted, and an action never resolves that grant itself. Every pipeline has two types, written `<C, T>`. `C` is the context: the facts the gadget gathered before asking. `T` is the result: what the pipeline hands back once it has decided. The result is the contract between deciding and doing, and it is always a plain table. The same table serves the gadget that acts on it, the event it sends, and the widget that draws it, so nothing in it can be a closure or a handle. Transfer's tax rate and stun seconds are fields on its result, and the actions read them off.

Time is handled the same way. When a load needs 60 hover frames, the pipeline does not wait or remember anything; it returns the 60 as a term on the result, and the gadget counts the frames.

If you have built this before as blockers, modifiers and listeners around an `AllowX` call, the mapping is exact. Blockers are `Unless` and `If`. Modifiers are `Enrich`, run once, up front, with no "modify and re-query" loop, so an answer never depends on how many times it was asked. Listeners are not in the pipeline at all: they are whoever consumes the result.

## Mods

A mod, or another module, changes a decision by aiming the same builder at the owner's contract. It can add, move, replace or remove a step:

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

That is the whole of a mod that stops tanks from being transported. Transport's own file is untouched, and there is nothing to register: any file under `policies/` is found. A new step joins the end of the checks, just before the answer; `.Before(name)` and `.After(name)` place it elsewhere. The owner's steps run first and other modules' follow in module-name order.

Every step is a name in a contract. The owner's come from its own stages, and anyone else's from what its contract declares with `Contributes`. A string typed inline in a policy file is refused at load, naming the file and the contract it should have gone in. That is what makes a step something a third module can place itself against, and it is why the mistakes you would expect are all load errors that name the file: an unknown step name, two modules adding the same name, a declared name that never lands, a `Single` pipeline that does not end in a `Select`.

Facts pass between modules the same way. Transfer builds a pairing context (sender team, receiver team, resources) and Tech Core wants to add the team's blocking terms to it, so transfer's contract declares the facts others may fill, and Tech Core fills them:

```lua
TeamPairing = PolicyBuilder.Facts({ TechBlocking = "techBlocking", TaxRate = "taxRate" }),
```

```lua
Policies.Enrich(Contract.TeamPairing).Provide(Contract.TeamPairing.TaxRate, function(ctx, springRepo, senderTeamID)
	return ...
end)
```

Two mods may both say they can fill the same fact. Say Tech Core provides `TaxRate`, and a future flat-tax experiment provides it too. Nothing in the code picks between them; the mode does.

A preset switches modules on. Selecting a preset makes the module that ships it live, plus any module the preset names with `.Uses`. A module that ships no presets is always live. Live means its providers get asked. Not live means they are skipped, as if the file were not there. Transfer's presets cover every case:

- **Tech Core** ships in the tech module, so selecting it makes tech live. Tech's `TaxRate` provider answers with the tiered rate.
- **Customize** ships in transfer and says `.Uses(TechModule)`, so tech is live here too. Same answer.
- **Enabled** ships in transfer and names nobody. Tech is not live, so its provider is never asked, and transfer's own `Default` answers with the flat modoption rate.

```lua
-- modules/transfer/modes/customize.lua
local TechModule = VFS.Include("modules/tech/contract.lua")

return Mode("Customize")
	.Uses(TechModule)
	...
```

A module is named by its contract, never by a string, so a typo is an include error at load rather than a preset that quietly switches nothing on.

```lua
-- modules/transfer/policies/terms_defaults.lua: what the fact means when no live module fills it
Policies.Enrich(Contract.TeamTerms).Default(Contract.TeamTerms.TaxRate, function(ctx)
	return modOptionTax(ctx.opts)
end)
```

Every fact a contract declares must have a `Default` from its owner, or the contract fails at load. So a fact is a promise: it always has an answer, and the only question is who gives it. A provider that returns nil is saying "not my case", and the answer falls through to the next live provider, or to the Default.

What if two live providers both answer? That is a mistake, and it is caught before any game exists. At load the runtime walks every combination of presets a lobby could select. If any combination leaves two live providers for one fact, it refuses to start and names the presets and both files. Should it happen in a running game anyway, two answers for one ask is the same error.

There is no registry to add yourself to and no global to poke. Providers, defaults and presets are all read from files, so the lobby, the synced game and the widgets see the same set. State a module keeps in memory has one home: its `state.lua`. That file declares the table's class, asks the runtime for the module's one table per Lua state with `ModuleHandler.State(Modules.X)`, and returns it, so every reader in the module includes `state.lua` and is typed against one declaration. The rule is that a file-level table written after load goes there and never in a `local`, because `VFS.Include` is uncached and a local is one copy per includer, so a cache in one file becomes five caches in five. Constants and pure functions may stay local. The defs module's one include of alldefs_post is the case in this runtime, and the module handler anchors itself the same way so the policy files are read once per state rather than once per gadget.

## Conclusion

I am really excited for this work. It gives us opinionated mechanisms that isolate complexity and let runtime behaviour be extended declaratively.

Here is what that buys us. A mod that changes a rule is one policy file and a contract, and the file it changes is untouched. Tech Core, the whole tier system as a sharing mode, is a module in its own PR up this chain, and nothing below it knows it exists. The air transport rework sits on the transport module and asks the same pipeline everyone else does. The lobby reads presets straight out of the game archive, so a mode is one file for the game, the lobby and SPADS alike. Experiments stop being forks: two can ship in the tree at once and the mode decides which one is live.
