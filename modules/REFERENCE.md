# Modules: reference

Every word the builder gives you, grouped by the file you write it in. [README.md](README.md) is the walkthrough; this is the lookup.

## In contract.lua

A contract declares pipelines and facts. It is a lexical scope that reads top to bottom, with each member typed and named explicitly: the context, the result, each pipeline, and each stage on it. [The contract](README.md#the-contract) in the README walks a complete one line by line. The stage enum is the contract's promise: a name in it is a stage on the pipeline, or load fails. That holds for the owner's own stages and for anything declared with `Contributes`.

**`PolicyBuilder.Contract(Modules.X, { ... })`**

<sub>Type: `(Modules, table) → Contract`</sub>

Stamps every member with its owner and category, so a pipeline's identity travels with its stage enum wherever it is included. An optional third argument, `function(Policies)`, is the module's policy inline; the loader runs it like a file under `policies/`.
```lua
return PolicyBuilder.Contract(Modules.Defs, { UnitDef = PolicyBuilder.Fold(UnitDef) })
```

**`Single(stages)`**

<sub>Type: `stages → PolicyStages<C, T>`</sub>

A single pipeline answers one question once. Most pipelines are this.
* Guards (If/Unless) come first and can only refuse.
* Then Answers, in order; the first one that returns a value is the result, and one that returns nil passes to the next. 
* A guard refusal, or every Answer declining to provide a value, returns the Refusal if the owner declared one and `false` if not.

```lua
Load = PolicyBuilder.Single(Load) -- in the contract

Policies.On(Load) -- in a policy
	.Refusal(function() return false end)
	.Unless(Load.Submerged, isUnderwater) -- true refuses
	.If(Load.WithinReach, isClose) -- false refuses
	.Answer(Load.Allowed, function() return true end) -- the first non-nil Answer is the result
```

**`Product(stages)`**

<sub>Type: `stages → PolicyStages<C, number>`</sub>

A product pipeline multiplies each Factor's return value together and that is the result. Any module can add a stage, and they stack. A Factor can return nil to contribute nothing. Only Factors are allowed; the loader refuses a guard or an Answer by name. If no stage returns a number at all, the pipeline has nothing to return and throws at runtime.
```lua
Speed = PolicyBuilder.Product(Speed) -- in the contract

Policies.On(Speed) -- in a policy: 0.5 × 0.75 × 1.25
	.Factor(Speed.Base, function() return 0.5 end)
	.Factor(Speed.Cargo, function() return 0.75 end)
	.Factor(Speed.Boost, function() return 1.25 end)
```

**`Fold(stages)`**

<sub>Type: `stages → PolicyStages<C, C>`</sub>

A fold pipeline runs every Apply, in order, on the same context, and returns that context. An Apply edits it in place and returns nothing. Only Applies are allowed; the loader refuses a guard or an Answer by name. Nothing refuses and nothing ends early. Use it for post-processing, where every unit def goes through every stage.
```lua
UnitDef = PolicyBuilder.Fold(UnitDef) -- in the contract

Policies.On(UnitDef) -- in a policy: both run, on the same def, in this order
	.Apply(UnitDef.Base, function(ctx) ctx.def.health = ctx.def.health * 1.1 end)
	.Apply(UnitDef.Scavenger, function(ctx) ctx.def.name = "scav_" .. ctx.def.name end)
```

**`Facts(names)`**

<sub>Type: `names → PolicyFacts<C>`</sub>

Not a pipeline. The facts a decision reads, which other modules may fill before the pipeline is asked. A fact informs a decision; it is not the decision. One fact, three files:
```lua
-- transfer/contract.lua: the fact, declared and typed by its owner
TeamTerms = PolicyBuilder.Facts({ TaxRate = "taxRate" }),

-- transfer/policies/terms_defaults.lua: what it means when nobody else answers
Policies.On(Contract.TeamTerms).Default(Contract.TeamTerms.TaxRate, function(ctx)
	return modOptionTax(ctx.opts)
end)

-- tech/policies/tech_blocking.lua: live under Tech Core, and the rate follows the team's tier
Policies.On(Contract.TeamTerms).Provide(Contract.TeamTerms.TaxRate, function(ctx)
	local level = tonumber(ctx.springRepo.GetTeamRulesParam(ctx.teamId, "tech_level")) or 1
	return TechTier.resolveByTechLevel(ctx.opts, "tax_resource_sharing_amount", level)
end)
```
Transfer never learns that tech exists. The mode says whose answer is live.

**`Contributes(target, names)`**

<sub>Type: `(PolicyStages, names) → names`</sub>

The stages this module adds to another module's pipeline, named here so a third module can place a rule against them by reference. A declared name that never lands is a load error.
```lua
local Defs = VFS.Include("modules/defs/contract.lua") ---@type DefsContract

return PolicyBuilder.Contract(Modules.Transport, {
	Load = PolicyBuilder.Single(Load),
	UnitDef = PolicyBuilder.Contributes(Defs.UnitDef, { EnemyTransport = "EnemyTransport" }),
})
```

**`---@class XContext`**

<sub>Type: `C`</sub>

The [context](README.md#what-flows-through-it) as a type, declared beside the stages, so `ctx` is typed inside every predicate without an annotation on the predicate.
```lua
---@class DefContext
---@field def table
```

## In a policy file

A policy file runs with one extra name in scope, `Policies`, bound to a registrar for that load. It builds pipelines and returns nothing.

**`Policies.On(stages)`**

<sub>Type: `PolicyStages<C, T> → PolicyPipeline<C, T>` · `PolicyFacts<C> → PolicyEnrichment<C>`</sub>

Opens a chain against a contract's stage enum, the owner's or another module's.
```lua
Policies.On(Contract.Load)
```

**`.Unless(stage, fn)`**

<sub>Type: `(stage, C → bool) → Stage<C, T>`</sub>

A guard that can only refuse. True refuses, false passes. It never says yes, so a mod adding one can only tighten. The predicate answers the stage's name: unless submerged.
```lua
.Unless(load.Submerged, function(ctx) return ctx.goalY + ctx.height < 0 end)
```

**`.If(stage, fn)`**

<sub>Type: `(stage, C → bool) → Stage<C, T>`</sub>

The same guard inverted: false refuses, true passes. If within reach.
```lua
.If(load.WithinReach, function(ctx) return ctx.distance <= ctx.reach end)
```

**`.Answer(stage, fn)`**

<sub>Type: `(stage, C → T?) → Stage<C, T>`</sub>

Single only. The only stage that can answer: returns the pipeline's result, or nil to pass to the next stage. If every Answer declines, the pipeline refuses: nothing said yes is a no. A Single pipeline always ends in one.
```lua
.Answer(load.Allowed, function() return true end)

local function terms(ctx, canShare)
	return { canShare = canShare, stunSeconds = ctx.stunSeconds }
end

-- above the guards, an Answer is an exemption: nil is "not my case, keep going"
.Answer(unitTransfer.Cheating, function(ctx)
	if ctx.isCheatingEnabled then
		return terms(ctx, true)
	end
end)
```

**`.Factor(stage, fn)`**

<sub>Type: `(stage, C → number?) → Stage<C, number>`</sub>

Product only. Returns a multiplier, or nil to contribute nothing. The loader refuses it on any other kind of pipeline, by stage name.
```lua
.Factor(loadedSpeed.CommanderDrag, function(ctx) return ctx.carriesCommander and 0.5 or nil end)
```

**`.Apply(stage, fn)`**

<sub>Type: `(stage, C → ()) → Stage<C, C>`</sub>

Fold only. Runs on the context, edits it in place, returns nothing. The loader refuses it on any other kind of pipeline, by stage name.
```lua
.Apply(UnitDef.Base, function(ctx) base().UnitDef_Post(ctx.name, ctx.def) end)
```

**`.Refusal(fn)`**

<sub>Type: `C → T`</sub>

What a no looks like, declared once by the owner, wherever the no happens: a guard refusing, or every Answer declining. Instead of a bare `false`, a shape a widget can draw and a caller can act on.
```lua
.Refusal(function(ctx) return terms(ctx, false) end) -- the record a grant gets, with canShare flipped
```

**`.Before(stage)`, `.After(stage)`**

<sub>Type: `Stage → Stage`</sub>

Where the stage just added goes. Without either, a new stage joins the end of the checks, just before the answer.
```lua
-- the mod from above: tanks are refused before transport even looks at the water
.Unless(Contract.Load.TanksStayOnTheGround, isTank).Before(Transport.Load.Submerged)
```

**`.Replace(stage, fn)`**

<sub>Type: `(stage, C → T?) → Stage<C, T>`</sub>

Swap the closure under an existing name, keeping its position.
```lua
.Replace(load.MovingEnemy, function() return false end) -- a mod that lets you nap a moving enemy
```

**`.Remove(stage)`**

<sub>Type: `Stage → ∅`</sub>

Drop an existing stage.
```lua
.Remove(load.AlliedNano) -- allied nano turrets may be carried after all
```

Every stage is a name in a contract: the owner's from its own stages, anyone else's from what its contract declares with `Contributes`. A string typed inline is refused at load, naming the file and the contract it should have gone in.

## On a facts chain

Facts are filled before a pipeline is asked, not decided inside it. Anyone may provide one; the owner must default every one it declares.

**`Policies.On(facts)`**

<sub>Type: `PolicyFacts<C> → PolicyEnrichment<C>`</sub>

Opens a provider chain against a contract's facts.
```lua
Policies.On(Contract.TeamPairing)
```

**`.Provide(fact, fn)`**

<sub>Type: `(fact, C → V?) → Provision<C>`</sub>

Answers a fact, per ask, from the context. Nil declines and the next live provider or the Default answers.
```lua
.Provide(Contract.TeamPairing.TaxRate, function(ctx) return tieredRate(ctx) end)
```

**`.Default(fact, fn)`**

<sub>Type: `(fact, C → V) → Provision<C>`</sub>

The owner's answer when no live module provides. Every declared fact must have one, or load fails.
```lua
.Default(Contract.TeamTerms.TaxRate, function(ctx) return modOptionTax(ctx.opts) end)
```

## In a gadget, widget or lib

What a module's `api.lua` is written with. You call these when you are writing an api or a lib, not a gadget; [How a gadget asks](README.md#how-a-gadget-asks) is the path a gadget takes.

**`Modules.X`**

<sub>Type: `string`</sub>

A module by name, from [`modules/enums.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/enums.lua). Code never names a module by string.
```lua
local Modules = VFS.Include("modules/enums.lua").Modules
```

**`ModuleHandler.LoadPolicies(Modules.X)`**

<sub>Type: `Modules → { [category]: AssembledPipeline<C, T> }`</sub>

The module's assembled pipelines, keyed by data-case category, every contributor's stages applied. Read once at file scope.
```lua
local pipelines = ModuleHandler.LoadPolicies(Modules.Transport) ---@type TransportPipelines
```

**`ModuleHandler.Evaluate(pipeline, ctx, ...)`**

<sub>Type: `(AssembledPipeline<C, T>, C) → T | false`</sub>

Asks. Runs the stages in order under the contract's strategy and returns the result, or the refusal. The result is whatever `T` the contract declared: a boolean for transport's load, the `UnitPolicyResult` record for transfer's unit transfer. A refusal has the same shape, so the caller reads one set of fields either way.
```lua
-- modules/transfer/unit/synced.lua
---@type TransferPipelines
local pipelines = ModuleHandler.LoadPolicies(Modules.Transfer)
---@type UnitPolicyResult
local grant = ModuleHandler.Evaluate(pipelines.unit_transfer, ctx)
if grant.canShare then
	applyStun(unitID, grant.stunSeconds)
end
```

**`ModuleHandler.Enrich(facts, modOptions, ctx, ...)`**

<sub>Type: `(PolicyFacts<C>, modOptions, C) → { [fact]: V }`</sub>

Fills a contract's facts for one ask: the live providers answer, nil declines, the Default fills the rest.
```lua
-- modules/transfer/resource/tax.lua: whose rate this is, tech's or the modoption's, is the mode's business
local ctx = { teamId = teamId, opts = opts, springRepo = springRepo }
local terms = ModuleHandler.Enrich(Contract.TeamTerms, opts, ctx)
local rate = tonumber(terms[Contract.TeamTerms.TaxRate])
```

**`ModuleHandler.LoadActions(Modules.X)`**

<sub>Type: `Modules → { byName, list }`</sub>

The module's actions by name. `api.lua` fronts this: validate, then execute, and nothing reaches execute around it.
```lua
ModuleHandler.LoadActions(Modules.Transfer).byName.units
```

**`ModuleHandler.State(Modules.X)`**

<sub>Type: `Modules → table`</sub>

The module's one in-memory table per Lua state. Called only from the module's `state.lua`, which declares its class and returns it. see below.

**`Published.PerTeam(key, fields)`**

<sub>Type: `(string, { [field]: wireType }) → PublishedRecord`</sub>

A per-team record synced writes and either side reads: one team rules param, the fields declared once with their wire types (`String`, `Number`, `Boolean`, `List`). `Write` from synced serializes it onto the param and fires `Published.EVENT` when it changed since the last write, so a widget hears about a change instead of polling; an optional list of field names narrows what counts as a change. `Read` on either side gives the record back typed, or nil where nothing was published.
```lua
-- modules/transfer/unit/shared.lua
Shared.UnitFactor = Published.PerTeam("unit_transfer_factor", {
	sharingModes = Published.List,
	active = Published.Boolean,
})

-- synced, per team, on each refresh
Shared.UnitFactor.Write(Spring, teamID, { sharingModes = modes, active = active })

-- either side
local factor = Shared.UnitFactor.Read(Spring, teamID) -- { sharingModes = {...}, active = true } or nil
```

**`Actions.RegisterValidate(fn)`, `Actions.RegisterExecute(fn)`**

<sub>Type: `(request → bool, string?)` · `(request → result)`</sub>

In an action file: the pure precondition over the request, and the one effectful function. Validate must come first; execute is required.
```lua
Actions.RegisterValidate(function(request)
	if not request.grant.canShare then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	return true
end)

Actions.RegisterExecute(function(request)
	for _, unitID in ipairs(request.validation.validUnitIds) do
		Spring.TransferUnit(unitID, request.to, true)
	end
	return { success = true }
end)
```
<sub>Example: [`modules/transfer/actions/units.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/actions/units.lua)</sub>

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

