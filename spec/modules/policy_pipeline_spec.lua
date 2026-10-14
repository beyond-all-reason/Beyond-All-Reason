local ModuleHandler = require("modules/module_handler")
local Policy = require("modules/policy")

---@class SpecCtx
---@field submerged boolean|nil
---@field far boolean|nil
---@field tank boolean|nil
---@field scripted string|nil
---@field reachable boolean|nil

---@class SpecProductCtx
---@field carriesCommander boolean|nil
---@field inMud boolean|nil

local function owner()
	---@type AssembledPolicy<SpecCtx, boolean|string|table>
	local steps = { result = "single" }
	Policy.Assemble(
		steps,
		Policy.Chain()
			.Unless("Submerged", function(ctx)
				return ctx.submerged
			end)
			.Unless("OutOfReach", function(ctx)
				return ctx.far
			end)
			.Answer("Allowed", function()
				return true
			end)
			.Build(),
		"owner"
	)
	return steps
end

local function names(steps)
	local out = {}
	for i, step in ipairs(steps) do
		out[i] = step.name
	end
	return out
end

local run = ModuleHandler.Evaluate

---@generic T: table
---@param owner string
---@param members T
---@return T
local function declared(owner, members)
	Policy.Declare(owner, members, "spec")
	return members
end

describe("a policy's identity", function()
	it("carries owner, category and the declared result", function()
		local Contract = declared("transport", {
			Load = Policy.Single({ Submerged = "Submerged" }),
			LoadedSpeed = Policy.Product({ CommanderDrag = "CommanderDrag" }),
		})
		assert.are.same({ owner = "transport", category = "load", result = "single" }, Policy.IdentityOf(Contract.Load))
		assert.are.same(
			{ owner = "transport", category = "loaded_speed", result = "product" },
			Policy.IdentityOf(Contract.LoadedSpeed)
		)
		assert.is_nil(Policy.IdentityOf({}))
		assert.are.equal(Contract.Load, Policy.Chain(Contract.Load).steps)
	end)

	it("requires every category to declare itself", function()
		assert.has_error(function()
			declared("transport", { Load = { Submerged = "Submerged" } })
		end, "spec: Load must declare itself: Single(...), Product(...), Fold(...), Contributes(...) or Facts(...)")
	end)

	it("serializes a declaration's name to the key the runtime uses", function()
		assert.are.equal("unit_terms_notes", Policy.KeyOf("UnitTermsNotes"))
		assert.are.equal("take", Policy.KeyOf("Take"))
	end)
end)

describe("one chain for owners and contributors", function()
	it("a bare step joins the end of the checks, never past the terminal", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Unless("NoTanks", function(ctx)
					return ctx.tank
				end)
				.Build(),
			"mod"
		)
		assert.are.same({ "Submerged", "OutOfReach", "NoTanks", "Allowed" }, names(steps))
		assert.is_false(run(steps, { tank = true }))
		assert.is_true(run(steps, {}))
	end)

	it("a contributor's bare Answer lands before the owner's terminal too: only the owner has the last word", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Scripted", function(ctx)
					return ctx.scripted
				end)
				.Build(),
			"mod",
			true
		)
		assert.are.same({ "Submerged", "OutOfReach", "Scripted", "Allowed" }, names(steps))
		assert.are.equal("override", run(steps, { scripted = "override" }))
		assert.is_true(run(steps, {}))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Last", function()
					return "last"
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ "Submerged", "OutOfReach", "Scripted", "Allowed", "Last" }, names(steps))
	end)

	it("names are the contract: unknown or colliding names are load errors naming the file", function()
		assert.has_error(function()
			Policy.Assemble(owner(), Policy.Chain().Unless("Submerged", function() end).Build(), "mod.lua")
		end, "mod.lua: the policy already has a step named Submerged")
	end)
end)

describe("one chain for owners and contributors", function()
	it("If is the inclusive guard: it refuses when its condition does not hold", function()
		---@type AssembledPolicy<SpecCtx, boolean>
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.If("WithinReach", function(ctx)
					return ctx.reachable
				end)
				.Answer("Allowed", function()
					return true
				end)
				.Build(),
			"owner"
		)
		assert.is_false(run(steps, {}))
		assert.is_true(run(steps, { reachable = true }))
	end)
end)

describe("facts", function()
	it("carries identity, and provisions are named or refused", function()
		local Contract = declared("transfer", {
			TeamPairing = Policy.Facts({ Weather = "weather" }),
		})
		assert.are.same(
			{ owner = "transfer", category = "team_pairing", facts = true },
			Policy.IdentityOf(Contract.TeamPairing)
		)
		local ops = Policy.Enrichment(Contract.TeamPairing)
			.Provide(Contract.TeamPairing.Weather, function(ctx)
				return { level = 2 }
			end)
			.Build()
		assert.are.same({ "weather" }, ops[1].names)
	end)

	it("a provider may add a fact the contract did not declare, and never removes one", function()
		local Contract = declared("transfer", {
			TeamPairing = Policy.Facts({ TaxRate = "taxRate" }),
		})
		local ops = Policy.Enrichment(Contract.TeamPairing)
			.Provide("stunSeconds", function()
				return 30
			end)
			.Build()
		assert.are.same({ "stunSeconds" }, ops[1].names)
		assert.are.equal("taxRate", Contract.TeamPairing.TaxRate)
	end)

	it("one producer can fill several provisions, in order", function()
		local ops = Policy.Enrichment()
			.Provide("a", "b", function()
				return 1, 2
			end)
			.Build()
		assert.are.same({ "a", "b" }, ops[1].names)
		assert.has_error(function()
			Policy.Enrichment().Provide("a")
		end)
	end)
end)

describe("module state", function()
	it("is one table per module across include instances", function()
		local A = require("modules/module_handler")
		local B = require("modules/module_handler")
		A.State("probe").count = 3
		assert.are.equal(3, B.State("probe").count)
		assert.are_not.equal(A.State("probe"), A.State("other"))
	end)
end)

describe("the refusal", function()
	it("is what every Answer declining becomes: nothing said yes is a no", function()
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Stunned", function(ctx)
					if ctx.stunned then
						return true
					end
				end)
				.Build(),
			"owner"
		)
		assert.is_true(run(steps, { stunned = true }))
		assert.is_false(run(steps, {}))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Refusal(function()
					return { allowed = false, reason = "nobody said yes" }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, reason = "nobody said yes" }, run(steps, {}))
	end)

	it("a Product with no factor is a broken owner, and says so", function()
		local steps = { result = "product" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Factor("Base", function(ctx)
					return ctx.speed
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(3, run(steps, { speed = 3 }))
		assert.has_error(function()
			run(steps, {})
		end)
	end)

	it("is false unless the policy declares its shape", function()
		local steps = owner()
		assert.is_false(run(steps, { submerged = true }))
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Refusal(function(ctx)
					return { allowed = false, deep = ctx.submerged }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, deep = true }, run(steps, { submerged = true }))
		assert.is_true(run(steps, {}))
	end)

	it("is declared once", function()
		local steps = owner()
		local shape = Policy.Chain()
			.Refusal(function()
				return false
			end)
			.Build()
		Policy.Assemble(steps, shape, "owner")
		assert.has_error(function()
			Policy.Assemble(steps, shape, "mod.lua")
		end, "mod.lua: the policy already has a Refusal")
	end)
end)

describe("the declared result", function()
	it("single: ends with an Answer", function()
		Policy.Validate(owner(), "single", "transport.load")
		assert.has_error(function()
			local steps = { result = "single" }
			Policy.Assemble(
				steps,
				Policy.Chain().Unless("Submerged", function() end).Unless("OutOfReach", function() end).Build(),
				"mod"
			)
			Policy.Validate(steps, "single", "transport.load")
		end, "transport.load: a single-result policy ends with an Answer; OutOfReach is a guard")
	end)

	it("single: an early Answer preempts the owner's, and only after the owner's guards", function()
		local steps = owner()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Scripted", function(ctx)
					return ctx.scripted
				end)
				.Build(),
			"mod",
			true
		)
		Policy.Validate(steps, "single", "transport.load")
		assert.are.same({ "Submerged", "OutOfReach", "Scripted", "Allowed" }, names(steps))
		assert.are.equal("override", run(steps, { scripted = "override" }))
		assert.is_false(run(steps, { scripted = "override", submerged = true }))
		assert.is_true(run(steps, {}))
	end)

	it("product: factors from every module multiply into one answer", function()
		---@type AssembledPolicy<SpecProductCtx, number>
		local policy = { result = "product" }
		Policy.Assemble(
			policy,
			Policy.Chain()
				.Factor("CommanderDrag", function(ctx)
					return ctx.carriesCommander and 0.5 or nil
				end)
				.Factor("MudCrawl", function(ctx)
					return ctx.inMud and 0.25 or nil
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(0.125, run(policy, { carriesCommander = true, inMud = true }))
		assert.are.equal(0.25, run(policy, { inMud = true }))
		assert.has_error(function()
			run(policy, {})
		end)
	end)

	it("product: every step is a Factor", function()
		local steps = {}
		Policy.Assemble(steps, Policy.Chain().Factor("CommanderDrag", function() end).Build(), "owner")
		Policy.Validate(steps, "product", "transport.loaded_speed")
		assert.has_error(function()
			Policy.Assemble(steps, Policy.Chain().Unless("NoMud", function() end).Build(), "mod")
			Policy.Validate(steps, "product", "transport.loaded_speed")
		end, "transport.loaded_speed: a product policy multiplies Factor results; NoMud is a guard")
	end)
end)

describe("the fold result", function()
	local function fold(ops, origin)
		---@type AssembledPolicy<table, table>
		local steps = { result = "fold" }
		Policy.Assemble(steps, ops, origin)
		return steps
	end

	it("hands one context through every Apply, owner's first, and returns it", function()
		local steps = fold(
			Policy.Chain()
				.Apply("Base", function(ctx)
					ctx.def.mass = (ctx.def.mass or 0) + 1
				end)
				.Build(),
			"owner"
		)
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Apply("Heavier", function(ctx)
					ctx.def.mass = ctx.def.mass * 10
				end)
				.Build(),
			"mod"
		)
		local ctx = { def = {} }
		assert.are.equal(ctx, ModuleHandler.Evaluate(steps, ctx))
		assert.are.equal(10, ctx.def.mass)
		assert.are.same({ "Base", "Heavier" }, names(steps))
	end)

	it("every step is an Apply: a fold has nothing to refuse", function()
		local steps = fold(
			Policy.Chain()
				.Unless("Never", function()
					return false
				end)
				.Build(),
			"owner"
		)
		assert.has_error(function()
			Policy.Validate(steps, "fold", "defs.unit_def")
		end, "defs.unit_def: a fold policy runs every Apply over the context; Never is a guard")
	end)
end)

describe("a declared contribution", function()
	local function target()
		return declared("transport", {
			Load = Policy.Single({ Submerged = "Submerged", Allowed = "Allowed" }),
			Facts = Policy.Facts({ Reach = "reach" }),
		})
	end

	it("carries the target's identity and the contributor's own", function()
		local Contract = target()
		local mod = declared("mod", {
			Load = Policy.Contributes(Contract.Load, { NoTanks = "NoTanks" }),
		})
		assert.are.same(
			{ owner = "mod", category = "load", contributes = Policy.IdentityOf(Contract.Load) },
			Policy.IdentityOf(mod.Load)
		)
		assert.are.equal("NoTanks", mod.Load.NoTanks)
	end)

	it("targets a policy, never a context", function()
		local Contract = target()
		assert.has_error(function()
			Policy.Contributes({}, { A = "A" })
		end, "Policy.Contributes(target, names): target must be a policy's steps")
		assert.has_error(function()
			Policy.Contributes(Contract.Facts, { A = "A" })
		end, "Policy.Contributes(target, names): target must be a policy's steps")
	end)

	it("is the only way to add a step: a name no contract declares is refused", function()
		local ops = Policy.Chain()
			.Unless("NoTanks", function()
				return true
			end)
			.Build()
		assert.is_nil(ModuleHandler.UndeclaredStep(ops, { NoTanks = true }))
		assert.are.equal("NoTanks", ModuleHandler.UndeclaredStep(ops, {}))
	end)

	it("holds the owner and a contributor to their contracts alike: a declared name must land", function()
		local landed = { Submerged = true, Allowed = true }
		assert.is_nil(ModuleHandler.UnbuiltStage({ Submerged = "Submerged", Allowed = "Allowed" }, landed))
		assert.are.equal(
			"WithinReach",
			ModuleHandler.UnbuiltStage({ Submerged = "Submerged", WithinReach = "WithinReach" }, landed)
		)
		assert.are.equal("NoTanks", ModuleHandler.UnbuiltStage({ "NoTanks" }, landed))
	end)

	it("shaping the refusal needs no declaration: it adds no step", function()
		assert.is_nil(ModuleHandler.UndeclaredStep(Policy.Chain().Refusal(function() end).Build(), {}))
	end)
end)

describe("a contract's facts", function()
	local function enrichment(module, ops)
		return { module = module, ops = ops, file = module .. "/policies/x.lua" }
	end
	local function defaults(...)
		local chain = Policy.Enrichment()
		for _, name in ipairs({ ... }) do
			chain.Default(name, function()
				return "default:" .. name
			end)
		end
		return chain.Build()
	end
	local function provides(name, value)
		return Policy.Enrichment()
			.Provide(name, function()
				return value
			end)
			.Build()
	end

	it("a slot nobody Defaults or provides is the context's field of its name", function()
		local resolved = ModuleHandler.ResolveProvisions("transfer.team_terms", "transfer", { "taxRate" }, {})
		assert.are.equal(0.3, ModuleHandler.EnrichWith(resolved, {}, { taxRate = 0.3 }).taxRate)
		assert.is_nil(ModuleHandler.EnrichWith(resolved, {}, {}).taxRate)
		assert.has_error(function()
			ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, { enrichment("tech", defaults("taxRate")) })
		end, "tech/policies/x.lua: only transfer may Default taxRate on k")
		assert.has_error(function()
			ModuleHandler.ResolveProvisions(
				"k",
				"transfer",
				{ "taxRate" },
				{ enrichment("transfer", defaults("other", "taxRate")) }
			)
		end, "transfer/policies/x.lua: k declares no slot named other to Default")
	end)

	it("may be provided by any number of modules; the mode decides who is live", function()
		local resolved = ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, {
			enrichment("transfer", defaults("taxRate")),
			enrichment("tech", provides("taxRate", 0.5)),
			enrichment("other", provides("taxRate", 0.9)),
		})
		assert.are.equal(2, #resolved.providers)
		assert.are.equal("default:taxRate", ModuleHandler.EnrichWith(resolved, { transfer = true }, {}).taxRate)
		assert.are.equal(0.5, ModuleHandler.EnrichWith(resolved, { tech = true }, {}).taxRate)
		assert.are.equal(0.9, ModuleHandler.EnrichWith(resolved, { other = true }, {}).taxRate)
		assert.has_error(
			function()
				ModuleHandler.EnrichWith(resolved, { tech = true, other = true }, {})
			end,
			"taxRate answered by both tech/policies/x.lua and other/policies/x.lua in one ask: the mode leaves both live"
		)
	end)

	it("a provider that answers nil declines, and the Default steps in", function()
		local resolved = ModuleHandler.ResolveProvisions("k", "transfer", { "taxRate" }, {
			enrichment("transfer", defaults("taxRate")),
			enrichment("tech", provides("taxRate", nil)),
		})
		assert.are.equal("default:taxRate", ModuleHandler.EnrichWith(resolved, { tech = true }, {}).taxRate)
	end)
end)

describe("what a mode makes live", function()
	local byCategory = {
		transfer = {
			enabled = { key = "enabled", category = "transfer", module = "transfer", modules = { "transfer" } },
			tech_core = { key = "tech_core", category = "transfer", module = "tech", modules = { "tech" } },
			customize = {
				key = "customize",
				category = "transfer",
				module = "transfer",
				modules = { "tech", "transfer" },
			},
		},
		game = {
			standard = { key = "standard", category = "game", module = "modes", modules = { "modes" } },
		},
	}
	local alwaysLive = { economy = true, construction = true }

	it("is what the picked presets make live, and every module that ships no presets", function()
		assert.are.same(
			{ economy = true, construction = true, transfer = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "enabled", game = "standard" })
		)
		assert.are.same(
			{ economy = true, construction = true, tech = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "tech_core", game = "standard" })
		)
		assert.are.same(
			{ economy = true, construction = true, transfer = true, tech = true, modes = true },
			ModuleHandler.LiveModules(byCategory, alwaysLive, { transfer = "customize", game = "standard" })
		)
	end)

	it("is walked, every combination, to prove no preset leaves two providers live for one slot", function()
		local function provider(module)
			return {
				op = { names = { "taxRate" }, evaluate = function() end },
				module = module,
				file = module .. "/p.lua",
			}
		end
		assert.are.same(
			{},
			ModuleHandler.IsolationConflicts(byCategory, alwaysLive, { provider("tech"), provider("other") })
		)
		local withOther = {
			transfer = byCategory.transfer,
			game = byCategory.game,
			experiments = {
				other = { key = "other", category = "experiments", module = "other", modules = { "other" } },
			},
		}
		assert.are.same({
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=customize",
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=tech_core",
		}, ModuleHandler.IsolationConflicts(withOther, alwaysLive, { provider("other"), provider("tech") }))
	end)

	it("a step When'd on a condition steps aside when it does not hold: an Answer passes, a guard holds", function()
		local steps = Policy.Single({ Bar = "Bar", Quick = "Quick", Slow = "Slow" })
		Policy.Declare("t", { Steps = steps })
		local ops = Policy.Chain(steps)
			.Unless(steps.Bar, function()
				return true
			end)
			.When(function(ctx)
				return ctx.barred
			end)
			.Answer(steps.Quick, function()
				return "quick"
			end)
			.When(function(ctx)
				return ctx.hurry
			end)
			.Answer(steps.Slow, function()
				return "slow"
			end)
			.Build()
		local policy = { result = "single" }
		Policy.Assemble(policy, ops, "t")
		assert.are.equal("slow", run(policy, {}))
		assert.are.equal("quick", run(policy, { hurry = true }))
		assert.are.equal(false, run(policy, { barred = true, hurry = true }))
	end)
end)

describe("the answer's shape", function()
	-- The owner declares the fields its T carries; Evaluate holds every Answer to them, so a contributor's answer is the
	-- owner's shape at runtime and not only in an annotation the checker reads.
	local function record()
		---@type AssembledPolicy<SpecCtx, table>
		local steps = { result = "single", shape = { "canShare", "amount" } }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Terms", function()
					return { canShare = true, amount = 1 }
				end)
				.Build(),
			"owner.lua"
		)
		return steps
	end

	it("is declared on Single by reading the record's fields, and carried by the identity", function()
		local Contract = declared("transfer", {
			Terms = Policy.Single({ Rate = "Rate" }, function(t)
				return t.canShare, t.amount, t.canShare
			end),
		})
		assert.are.same({ "canShare", "amount" }, Policy.IdentityOf(Contract.Terms).shape, "in order, each once")
		assert.is_nil(Policy.IdentityOf(declared("transfer", { Bare = Policy.Single({ Rate = "Rate" }) }).Bare).shape)
		assert.has_error(function()
			Policy.Single({ Rate = "Rate" }, function() end)
		end, "Policy.Single(steps, shape): the shape read no field off its record")
	end)

	it("holds every Answer to it, a contributor's included, naming the file and the step", function()
		assert.are.same({ canShare = true, amount = 1 }, run(record(), {}))
		local steps = record()
		Policy.Assemble(
			steps,
			Policy.Chain()
				.Answer("Early", function()
					return { canShare = true }
				end)
				.Build(),
			"mod.lua",
			true
		)
		assert.has_error(function()
			run(steps, {})
		end, "mod.lua: Early answered without amount; the owner's shape requires it")
		local owner_ = { result = "single", shape = { "canShare" } }
		Policy.Assemble(
			owner_,
			Policy.Chain()
				.Answer("Yes", function()
					return true
				end)
				.Build(),
			"owner.lua"
		)
		assert.has_error(function()
			run(owner_, {})
		end, "owner.lua: Yes answered a boolean; the owner's shape is a record")
	end)

	it("a nil answer passes: it answered nothing, and the next step speaks", function()
		local steps = record()
		Policy.Assemble(steps, Policy.Chain().Answer("Quiet", function() end).Build(), "mod.lua", true)
		assert.are.same({ canShare = true, amount = 1 }, run(steps, {}))
	end)

	it("without a declared shape, an answer is whatever the owner's T says it is", function()
		assert.is_true(run(owner(), {}))
	end)
end)

describe("a policy asked by key", function()
	---@class SpecAskedCtx
	---@field id integer
	---@field balance number
	---@field formed integer how many times the form ran on this table

	---@param spring table
	---@return AssembledPolicy<SpecAskedCtx, table|false>
	local function asked(spring)
		---@type AssembledPolicy<SpecAskedCtx, table|false>
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.FormContext(function(ctx, engine, id)
					ctx.id = id
					ctx.balance = (engine --[[@as table]]).balances[id] or 0
					ctx.formed = (ctx.formed or 0) + 1
				end)
				.Unless("Broke", function(ctx)
					return ctx.balance <= 0
				end)
				.Answer("Terms", function(ctx)
					return { id = ctx.id, sendable = ctx.balance, formed = ctx.formed }
				end)
				.Build(),
			"owner"
		)
		return steps
	end

	local function engine()
		local frame = 1
		return {
			balances = { [1] = 100, [2] = 0 },
			GetGameFrame = function()
				return frame
			end,
			advance = function()
				frame = frame + 1
			end,
		}
	end

	it("forms the context and evaluates on the frame's first ask, and looks the answer up after", function()
		local spring = engine()
		local policy = asked(spring)
		local first = ModuleHandler.Ask(policy, spring, 1)
		assert.are.equal(100, first.sendable)
		spring.balances[1] = 40
		assert.are.equal(first, ModuleHandler.Ask(policy, spring, 1), "the same frame answers the same record")
		spring.advance()
		local second = ModuleHandler.Ask(policy, spring, 1)
		assert.are.equal(40, second.sendable)
		assert.are.equal(2, second.formed, "the next frame formed into the same context table")
	end)

	it("keeps one context per key, and the refusal is an answer too", function()
		local spring = engine()
		local policy = asked(spring)
		assert.are.equal(100, ModuleHandler.Ask(policy, spring, 1).sendable)
		assert.is_false(ModuleHandler.Ask(policy, spring, 2))
		assert.is_false(ModuleHandler.Ask(policy, spring, 2), "a refusal is kept for the frame like any answer")
	end)

	it("Forget drops the frame's answer for a key, so the next ask forms again", function()
		local spring = engine()
		local policy = asked(spring)
		ModuleHandler.Ask(policy, spring, 1)
		spring.balances[1] = 10
		ModuleHandler.Forget(policy, spring, 1)
		assert.are.equal(10, ModuleHandler.Ask(policy, spring, 1).sendable)
		ModuleHandler.Forget(policy, spring, 9)
	end)

	it("a form with no key is one context per engine, formed once a frame", function()
		local spring = engine()
		---@type AssembledPolicy<table, table>
		local steps = { result = "single" }
		Policy.Assemble(
			steps,
			Policy.Chain()
				.FormContext(function(ctx)
					ctx.formed = (ctx.formed or 0) + 1
				end)
				.Answer("Count", function(ctx)
					return { formed = ctx.formed }
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(1, ModuleHandler.Ask(steps, spring).formed)
		assert.are.equal(1, ModuleHandler.Ask(steps, spring).formed)
		spring.advance()
		assert.are.equal(2, ModuleHandler.Ask(steps, spring).formed, "formed into the same table")
	end)

	it("stores per engine: two stand-ins never share an answer", function()
		local a, b = engine(), engine()
		b.balances[1] = 7
		local policy = asked(a)
		assert.are.equal(100, ModuleHandler.Ask(policy, a, 1).sendable)
		assert.are.equal(7, ModuleHandler.Ask(policy, b, 1).sendable)
	end)

	it("needs a FormContext, and the key the form's parameters name", function()
		local spring = engine()
		assert.has_error(function()
			ModuleHandler.Ask(owner(), spring, 1)
		end, "?: the owner declared no FormContext; a policy is Asked by key only with one")
		-- the key's length is read off the form where the runtime reports parameter counts (the game's LuaJIT does;
		-- PUC Lua 5.1, which runs these specs, does not): there a wrong ask is refused by name, elsewhere it is trusted
		assert.is_nil(Policy.KeyArity(function(...) end), "a vararg form names no key; the ask is trusted")
		if Policy.KeyArity(function(_, _, _) end) ~= nil then
			assert.are.equal(0, Policy.KeyArity(function(_, _) end))
			assert.has_error(function()
				ModuleHandler.Ask(asked(spring), spring)
			end, "?: asked with 0 key arguments; its FormContext takes 1")
			assert.has_error(function()
				ModuleHandler.Ask(asked(spring), spring, 1, 2)
			end, "?: asked with 2 key arguments; its FormContext takes 1")
		else
			assert.is_false(ModuleHandler.Ask(asked(spring), spring), "trusted: a missing key forms as nil and refuses")
		end
	end)

	it("is declared once", function()
		local steps = { result = "single" }
		assert.has_error(function()
			Policy.Assemble(
				steps,
				Policy.Chain()
					.FormContext(function(ctx, _, id)
						ctx.id = id
					end)
					.FormContext(function(ctx, _, id)
						ctx.id = id
					end)
					.Build(),
				"owner"
			)
		end, "owner: the policy already has a FormContext")
	end)
end)
