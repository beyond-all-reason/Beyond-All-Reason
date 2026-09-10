# Modules

**A module** is a directory that answers questions for one concern, like "may this team hand that unit to this one."

**It decides with policies.**

* A **[policy](#how-a-decision-flows)** is a file under `policies/` holding the pipelines a module builds, each opened with `Policies.On(...)`.
* A **[pipeline](#why-this-is-easier-for-every-layer)** is one rule: a pure function that answers one question, written as an ordered list of stages, each of which can refuse, pass, or answer. Pipeline in the middleware sense: a request passes through handlers in order, and any handler may stop it.
* A **[context](#what-flows-through-it)** is the plain table of facts the gadget hands the pipeline when it asks: who, where, what the engine and the modoptions say.
* A **[contract](REFERENCE.md#in-contractlua)** names every stage and every fact, and the shape going in and coming out, so another module or a mod can say "put my stage after this one" or "replace that one."

**It acts through [actions](#what-flows-through-it).** An action is the only effectful code in a module: a pure validate over a request, then one execute.

**It ships modes.** A mode is a preset of modoptions: which dials are set, locked, or hidden.

**It keeps what it must remember in [`state.lua`](REFERENCE.md#in-a-gadget-widget-or-lib)**, once per Lua state, and nowhere else.

**[REFERENCE.md](REFERENCE.md)** is the vocabulary: one entry per term, why it exists, and the smallest real example.

## If you have written a gadget

You already do all of this. Here is what each thing is called now.

| You do this today | In a module |
|---|---|
| An `Allow*` callin with a stack of `if`s | A pipeline. The api gathers the context and asks it. |
| An `if` that returns false | A guard: `Unless` refuses on true, `If` refuses on false. |
| The branch that returns true | An Answer. The first one that returns wins. |
| `return false` | The Refusal, one shape declared once by the owner. |
| A modoption read inside the rule | A fact with a Default. |
| Another gadget reaching into yours through `GG` | A fact it provides, or a stage it contributes, from its own directory. |
| A copy of the rule in a widget, for the tooltip | The same result, read back. One rule. |
| `GG.Foo = function` cross calls | `api.lua`, typed at the call site. |
| Upvalue tables in a gadget | `state.lua`, one table per module. |
| `Spring.TransferUnit` inside the callin | An action: validate, then execute. |
| `if modOptions.x == ...` scattered across gadgets | A mode preset. |
| An edit in `alldefs_post.lua` | A stage on defs' unit def fold. |

## The modules

Each module owns one concern:

| Module | Owns | Requires |
|---|---|---|
| `defs` | Def post-processing as a pipeline every unit and weapon def pass, and where a module adds its own stage. | the runtime |
| `game` | Which game this is: the game axis, one selector, the presets, the export the lobby reads. | the runtime |
| `transport` | Who may load and unload what, and how fast a loaded transport flies. The first module with real rules; the air transport rework builds on it. | defs |
| `construction` | What may be built, and by whom: assist, reclaim, resurrect, build delay, geo and mex upgrades. | the runtime |
| `economy` | How a shared pool is distributed. | the runtime |
| `transfer` | What may pass between allied teams: units, resources, take, and the tax on what flows. | construction, economy |
| `tech` | The keystones that raise a team's tier, and the tier as a fact construction and transfer read. Tech Core is its preset. | transfer, construction |
| `combat` | Damage, targeting and protection as a lifetime. | proposed |
| `placement` | Where a thing may legally stand, answered once. | proposed |
| `matchflow` | How and when a game ends. | proposed |

Modules land one at a time, each with its own contract, policies and specs; a proposed module is a concern with a name and no code yet.

## How a decision flows

A module answers questions. "May this team hand that unit to this one?" is one. The rule that answers it is a pipeline: a list of stages, run in order, where each stage can refuse, pass the question on, or answer it. No stage is the rule. The list is.

The contract is the module saying that out loud. It names each question the module answers, names every stage in the order they run, and says what goes in and what comes out. It is not the rules; it is the table of contents for them. That is what lets another module, or a mod, say "put my stage after that one" or "replace this one" without reading or touching the file the rules live in, and it is what lets the loader [refuse a wiring mistake at load](#what-the-loader-refuses), by name, rather than let it become a silent no in game.

So a module is two files: a contract that names the question, and a policy that answers it. We'll walk the policy first, because it is the part you read as a rule, and then the contract that makes it explicit.

The module's api gathers facts and asks. The pipeline decides. The module's actions act. Here is transfer asking whether one team may hand a unit to another, trimmed from `context_factory.lua`:

```lua
local ctx = {
	senderTeamId = senderTeamID,
	receiverTeamId = receiverTeamID,
	springRepo = springRepo,
	areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID) == true,
	isCheatingEnabled = springRepo.IsCheatingEnabled(),
}
return ModuleHandler.Evaluate(pipelines.unit_transfer, ctx)
```

### The policy

The real file, trimmed to one pipeline and three stages.

```lua
-- modules/transfer/policies/unit_transfer.lua
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local unitTransfer = Contract.UnitTransfer

---@param ctx TransferPolicyContext
---@param canShare boolean
---@return UnitPolicyResult
local function terms(ctx, canShare)
	return {
		canShare = canShare,
		stunSeconds = tonumber(ctx.springRepo.GetModOptions().unit_share_stun_seconds) or 0,
	}
end

Policies.On(unitTransfer)
	.Refusal(function(ctx)
		return terms(ctx, false)
	end)
	.If(unitTransfer.Allied, function(ctx)
		return ctx.areAlliedTeams
	end)
	.Unless(unitTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return tonumber(numActivePlayers) == 0
	end)
	.Answer(unitTransfer.TransferTerms, function(ctx)
		return terms(ctx, true)
	end)
```

Line by line.

```lua
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local unitTransfer = Contract.UnitTransfer
```

The policy reads the stage names from the contract; it cannot invent one. Including it runs no rules, which is why a gadget, a widget, a spec and a mod can all include it.

```lua
local function terms(ctx, canShare)
```

A plain local function. Both the yes and the no below are built by it, so a refusal is the same shape as a grant with `canShare` flipped.

```lua
Policies.On(unitTransfer)
```

Start a new decision pipeline. Explicitly name what that's about: transferring a unit. That lets other modules add their own rules to this decision if they want to. `Policies` is not included from anywhere: the loader sets it for the duration of this file, then takes it away.

```lua
	.Refusal(function(ctx)
		return terms(ctx, false)
	end)
```

What a no looks like. Declared once, by the owner. Every guard below that refuses hands back this, and so does falling off the end with nobody having said yes. Without it a no is `false`, which is fine for a boolean pipeline and useless for a table one.

```lua
	.If(unitTransfer.Allied, function(ctx)
		return ctx.areAlliedTeams
	end)
```

A **guard**. It reads the context and returns a boolean. `If` refuses on false, so if our teams are allied, this one moves on to the next stage. Guards cannot say "yes" for our pipeline.

`unitTransfer.Allied` is our stage name: `Allied`, in this case. Remember that is done so that someone else can contribute their own stage `.Before` it, `.Replace` it.

```lua
	.Unless(unitTransfer.ReceiverHasNoPlayers, function(ctx)
		if ctx.isCheatingEnabled then
			return false
		end
		local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
		return tonumber(numActivePlayers) == 0
	end)
```

Same shape, a few more lines. Order is precedence: this only runs if `Allied` passed.

```lua
	.Answer(unitTransfer.TransferTerms, function(ctx)
		return terms(ctx, true)
	end)
```

**Answer** is the only kind of stage that can say yes. It returns the result, the same shape the Refusal returns. Return nil instead and it passes, and the next Answer gets a go. Run out of Answers and nothing said yes, which is a no.

### Why this is easier for every layer

A Single pipeline is a function from a context to a result, `C → T`, built out of stages that are each a smaller function. What makes it a pipeline and not a list of functions is the rule for what happens *between* the stages: a guard that refuses stops everything and hands back the Refusal; an Answer that returns nil hands on; an Answer that returns a value stops everything and hands that back. That rule lives in `Evaluate`, once. No stage checks what the previous stage said. No stage knows whether it is first, last, or the only one.

That is the whole of what a monad is, TLDR: a type, plus one rule for chaining functions over it, so the functions themselves never do the chaining. Here the type is "maybe a `T`" and the rule is "first value wins, a refusal on the way stops it". You do not need the word. You need what it buys:

- The gadget asks and gets a `T`. Never nil, never "check if it's false and then go find out why". The Refusal gave the no a shape.
- The action reads its grant as a `T`. Same table, no second ask.
- The widget draws a `T`. Same table, so the tooltip and the rule cannot disagree.
- The spec passes a context literal and asserts on a `T`. No engine, no gadget, no globals.
- A mod adds one stage and never touches control flow, because there is no control flow in the stages to touch.

Every layer sees one shape going in and one shape coming out, and the only place the "what if it refused" question is answered is the one line that declares what a refusal is.

### The contract

Everything the policy just used by name, declared.

```lua
-- modules/transfer/contract.lua
local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

---@class TransferPolicyContext
---@field senderTeamId integer
---@field receiverTeamId integer
---@field springRepo Spring
---@field areAlliedTeams boolean
---@field isCheatingEnabled boolean

---@class UnitPolicyResult
---@field canShare boolean
---@field stunSeconds number

---@class TransferUnitTransferStages: PolicyStages<TransferPolicyContext, UnitPolicyResult>
local UnitTransfer = {
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	TransferTerms = "TransferTerms",
}

---@class TransferContract
---@field UnitTransfer TransferUnitTransferStages

return PolicyBuilder.Contract(Modules.Transfer, {
	UnitTransfer = PolicyBuilder.Single(UnitTransfer),
})
```

Same again, line by line.

```lua
---@class TransferPolicyContext
---@class UnitPolicyResult
```

The two types every pipeline has, written `<C, T>` everywhere else in this doc. `C` is what the gadget gathered up top. `T` is what `terms` built. `T` is a table here, not a boolean, because the gadget that stuns the unit and the widget that explains the stun in a tooltip both need the seconds, and they need them on a refusal too.

```lua
local UnitTransfer = {
	Allied = "Allied",
	ReceiverHasNoPlayers = "ReceiverHasNoPlayers",
	TransferTerms = "TransferTerms",
}
```

The three names the policy hung its stages on. A stage added under a name not in this table is refused at load. A name in this table that never lands on the pipeline is refused at load too. The contract is a promise in both directions, and it is the only thing a mod needs to read to put its own stage `.Before` yours.

```lua
return PolicyBuilder.Contract(Modules.Transfer, {
	UnitTransfer = PolicyBuilder.Single(UnitTransfer),
})
```

A contract belongs to a module. Name the owner with the enum, not a string, so a typo is a load error and not a module that silently never loads. Single means one question, one answer: the first stage that answers ends it. The real contract has three pipelines and four facts tables in this list; the shape is the same for each.

A module small enough to fit in one file can hand the policy to `Contract` as a third argument instead of a `policies/` directory; `defs` does, and it is the only one that should.

### What flows through it

**The context** is the `C` the contract declared: the one table the api gathers for this ask, read from the engine or cached on a cadence. It is the pipeline's only input, which is the purity the section above leans on: a spec hands in a table literal, and a widget reads the same fields the gadget acted on.

**Order is precedence.** A guard can only refuse, so "yes, regardless of the rest" is a matter of placement, not a verb. An Answer above `Allied` that grants when cheating is enabled reads: cheaters share with anyone; everyone else must be allied and sharing with a live team. As boolean logic, `cheating or (allied and receiverHasPlayers)`.

**The result** is the `T`: the seam between deciding and doing, and always a plain table, because the gadget that acts, the event it sends and the widget that draws all read the same one. Time rides on it too: the stun is seconds on the result, and the gadget counts the frames.

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

### A mod

A mod, or another module, changes a decision by aiming the same builder at the owner's contract. This is the whole of a mod that stops tanks being transported. Transport's own file is untouched:

```lua
-- modules/notanks/contract.lua: the stage this mod adds, named where others can find it
local Transport = VFS.Include("modules/transport/contract.lua")

return PolicyBuilder.Contract(Modules.NoTanks, {
	Load = PolicyBuilder.Contributes(Transport.Load, { TanksStayOnTheGround = "TanksStayOnTheGround" }),
})
```

```lua
-- modules/notanks/policies/load.lua
local Transport = VFS.Include("modules/transport/contract.lua")
local Contract = VFS.Include("modules/notanks/contract.lua")

Policies.On(Transport.Load).Unless(Contract.Load.TanksStayOnTheGround, function(ctx)
	local moveDef = ctx.passengerDef and ctx.passengerDef.moveDef
	return moveDef ~= nil and moveDef.name:lower():find("^tank") ~= nil
end)
```

The owner's stages run first, other modules' follow in module-name order, and a new stage joins just before the answer unless `.Before` or `.After` says otherwise. Guards compose with AND: anyone can add one, and adding can only tighten. Loosening a rule you do not own touches that rule, by name: `Remove` it, `Replace` it, or exempt from all of them with an Answer above. That asymmetry is deliberate. Tightening is safe to let anyone do blind; loosening is not.

### A fact

Where an owner expects loosening, it puts the knob on the context as a fact, so nobody has to `Replace` anything. Transfer declares the facts others may fill, and Tech Core, a module up the chain, fills one:

```lua
-- transfer's contract
TeamPairing = PolicyBuilder.Facts({ TechBlocking = "techBlocking", TaxRate = "taxRate" }),
```

```lua
-- tech's policy file
Policies.On(Contract.TeamPairing).Provide(Contract.TeamPairing.TaxRate, function(ctx, springRepo, senderTeamID)
	return tieredRate(ctx, springRepo, senderTeamID)
end)
```

```lua
-- transfer's own default: what the fact means when no live module fills it
Policies.On(Contract.TeamPairing).Default(Contract.TeamPairing.TaxRate, function(_, springRepo)
	return modOptionTax(springRepo.GetModOptions())
end)
```

Two modules may both provide the same fact. The owner declares the fact and its type, and must declare a `Default`, so a mod _may_ provide one and never has to.

Modes say which module's provider is live. The loader refuses a preset combination that would leave two live for one fact; that is in the list below.

| React nerds | Everyone else |
|---|---|
| A fact is a derived value with a default, and the mode picks the selector. | Facts are _computed_. They are not variables, not storage, and not configuration, though a Default often reads one. Each ask hands them a context and gets back a value of the type the owner declared. |

### What the loader refuses

Everything that can go wrong in wiring is a load error that names the file:

- a directory under `modules/` with no `manifest.lua`, or a manifest whose name does not match its directory
- a stage added under a name no contract declares
- a name in a contract that never lands on the pipeline, the owner's or a contributor's
- two modules adding the same stage name
- a Single pipeline that does not end in an Answer
- a declared fact with no Default from its owner
- a preset combination that leaves two providers live for one fact
- a policy or action file that returns a value, which the include shim would cache and the registration would be lost

There is no registry to add yourself to and no global to poke. Contracts, policies, defaults and presets are all read from files, so the lobby, the synced game and the widgets see the same set.

### How a gadget asks

A gadget does not ask a pipeline. It calls the module's `api.lua`, which gathers the context, asks, and runs the action. The pipeline runs once, in synced. Transfer's unit controller, the two places it touches the module:

```lua
-- modules/transfer/gadgets/game_unit_transfer_controller.lua
local TransferApi = VFS.Include("modules/transfer/api.lua")

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	return TransferApi.MayTransfer(unitID, fromTeamID, toTeamID, capture)
end

function gadget:RecvLuaMsg(msg, playerID)
	local params = LuaRulesMsg.ParseUnitTransfer(msg)
	local _, _, _, senderTeamID = Spring.GetPlayerInfo(playerID, false)
	TransferApi.Units(params.unitIDs, params.targetTeamID, senderTeamID)
end
```

The api is where the gathering lives. `Units` builds the request, and one `perform` runs validate then execute for every action the module has:

```lua
-- modules/transfer/api.lua
local function perform(name, request)
	local action = ModuleHandler.LoadActions(Modules.Transfer).byName[name]
	local allowed, reason = action.validate(request)
	if not allowed then
		Spring.Log("transfer", LOG.WARNING, "transfer." .. name .. " refused: " .. reason)
		return nil
	end
	return action.execute(request)
end

Units = function(unitIDs, toTeamID, fromTeamID)
	-- the api gathers; the action only reads its request
	local grant = UnitShared.GetCachedPolicyResult(fromTeamID, toTeamID, Spring)
	return perform("units", {
		from = fromTeamID,
		to = toTeamID,
		unitIDs = unitIDs,
		grant = grant,
		validation = UnitShared.ValidateUnits(grant, unitIDs, Spring),
	})
end
```
<sub>Example: [`modules/transfer/api.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/api.lua) · [`modules/transfer/gadgets/game_unit_transfer_controller.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/gadgets/game_unit_transfer_controller.lua)</sub>

A widget never asks either. It has no synced state to gather from, so the synced side publishes the result and the widget reads it back. The runtime's `Published.PerTeam` is that hop: declare the record's fields once, `Write` it from synced and it lands on a team rules param with one change event, `Read` it back typed on either side. Transfer ships a second door, `unsynced.lua`, that reads its records back and sends requests as a `LuaRulesMsg` for the synced controller to re-validate.

```lua
-- what a widget includes
local Transfer = VFS.Include("modules/transfer/unsynced.lua")

local terms = Transfer.Units.GetCachedPolicyResult(myTeamID, theirTeamID) -- read back, same UnitPolicyResult shape
Transfer.Units.ShareUnits(theirTeamID) -- the player's selection, as a message
```

`ShareUnits` is the whole request path, in three hops:

1. The widget side reads `Spring.GetSelectedUnits()`, packs the IDs with the target team, and sends them as a `LuaRulesMsg`.
2. The synced controller's `RecvLuaMsg` unpacks them, resolves the sender's team from the player, and calls `TransferApi.Units`.
3. The api gathers the grant and the validation, runs the action's validate, then execute. Nothing the widget sent is trusted before that.

<sub>Example: [`modules/transfer/unsynced.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/unsynced.lua) · [`modules/published.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/module-policies/modules/published.lua) · [`modules/transfer/gadgets/game_share_policy_forwarding.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/gadgets/game_share_policy_forwarding.lua)</sub>

## The layout

A module is one directory under `modules/`. The loader knows these files and folders and nothing else. Every entry is optional except the manifest.

**`manifest.lua`**

The manifest. Names the module (it must match the directory) and lists what it requires. No manifest, no module: any other directory under `modules/` is ignored. A `requires` entry that names no discovered module refuses the module, and whatever required it, with an error naming both.
```lua
return { name = "transport", description = "What a carrier may pick up, and how it flies loaded", requires = { "defs" } } -- [1]
```
<sub>[1] [`modules/transport/manifest.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/transport/manifest.lua)</sub>

**`contract.lua`**

The one file to read to know what a module decides, which of those decisions others may change, and which facts it takes from them. Declares each pipeline's stage names, how its stages combine, and the context it reads. See [In contract.lua](REFERENCE.md#in-contractlua).
<sub>Example: [`modules/transfer/contract.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/contract.lua)</sub>

**`policies/`**

The rules. Each file builds pipelines against a contract, its own or another module's, with `Policies.On(...)`. Any file here is found; there is nothing to register. A module whose whole policy is a few lines may carry it inline in `contract.lua` instead, as a third argument the loader runs the same way.
<sub>Example: [`modules/transport/policies/transport.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/transport/policies/transport.lua)</sub>

**`actions/`**

The only effectful code. One file per action, registering a pure `validate` and one `execute`. A pipeline decides, an action does.
<sub>Example: [`modules/transfer/actions/units.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transfer/modules/transfer/actions/units.lua)</sub>

**`state.lua`**

What the module keeps in memory, declared once as a class and anchored once per Lua state. A file-level table that is written after load lives here, never in a `local`: `VFS.Include` is uncached, so a local is one copy per includer. See [In a gadget, widget or lib](REFERENCE.md#in-a-gadget-widget-or-lib).
<sub>Example: [`modules/defs/state.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/defs/modules/defs/state.lua)</sub>

**`api.lua`**

What other modules and the game's own files call. Included directly, `VFS.Include("modules/defs/api.lua") ---@type DefsApi`, so it is typed at the call site.
```lua
local Defs = VFS.Include("modules/defs/api.lua") ---@type DefsApi
Defs.PrebakeUnitDefs() -- [1], called from [2]
```
<sub>[1] [`modules/defs/api.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/defs/modules/defs/api.lua) · [2] [`gamedata/unitdefs_post.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/defs/gamedata/unitdefs_post.lua)</sub>

**`lib/`**

The module's own helpers. Ordinary include paths, no loader involvement.

<sub>Example: [`modules/defs/lib/base.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/defs/modules/defs/lib/base.lua)</sub>

**`enums.lua`**

The module's names as values, so nothing refers to them by string. [`modules/enums.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/enums.lua) at the root is the enum of modules themselves.
```lua
Modules.Defs -- [1]
TransportEnums.ModOptions.CommanderTransportSlow -- [2]
```
<sub>[1] [`modules/enums.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/enums.lua) · [2] [`modules/transport/enums.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/transport/enums.lua)</sub>

**`modes/`**

Presets, one file each, written in the mode grammar. A preset makes the module that ships it live.
<sub>Example: [`modules/game/modes/ffa.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/game/modules/game/modes/ffa.lua)</sub>

**`mode_verbs.lua`**

The verbs this module adds to another module's mode grammar, each a `ModeBuilder.Verb(parse, write)`: how a preset writes the claim, and the modoptions it becomes. The loader hands them to the axis's grammar, so a preset claims this module's options in this module's words.
<sub>Example: [`modules/transport/mode_verbs.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/transport/mode_verbs.lua)</sub>

**`modoptions.lua`**

The module's fragment of the game's options. The root `modoptions.lua` appends every module's fragment, so a module that ships options needs no change to the root file.
<sub>Example: [`modules/game/modoptions.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/game/modules/game/modoptions.lua)</sub>

**`gadgets/`, `widgets/`, `rml_widgets/`, `scripts/`**

The game's own kinds of file, loaded the way the game already loads their loose equivalents. Gadgets and widgets are added to the handler's list; unit scripts join the script loader's registry under their `modules/` path.
<sub>Example: [`modules/transport/gadgets/transport_rules.lua`](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/transport/modules/transport/gadgets/transport_rules.lua)</sub>

Every file under `modules/` is loaded by the game's own handlers, in the same Lua state as the loose file it stands beside, with the same VFS mode. Synced code sees the archive only.

## What to keep

- A module is an opinionated directory that encapsulates game behavior.
- A policy is a file that contains many decisions, each one a pipeline.
- A pipeline is one statement chain of stages, each a guard or an Answer, with one Refusal saying what a no looks like. On a Product the stages are Factors; on a Fold, Applies. On a Product the stages are Factors; on a Fold, Applies. On a Product the stages are Factors; on a Fold, Applies.
- Read a pipeline top to bottom, and place your stage where the precedence says. No stage is the rule; the chain is.
- A guard can only refuse, and only an Answer can answer. Loosening touches the rule by name; tightening never does.
- Facts inform a decision and are filled before it runs; an Answer makes the decision. The mode decides whose fact is live.
- The contract is the map: every stage and every fact is a name there, and every wiring mistake is a load error that points at it.
- A gadget is the engine's callin and nothing more: it hands the ids to the api, which gathers, asks and acts. State a module must keep lives in `state.lua`, once per Lua state.
