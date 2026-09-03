local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

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
	---@type AssembledPipeline<SpecCtx, boolean|string|table>
	local stages = { result = "single" }
	PolicyBuilder.Apply(
		stages,
		PolicyBuilder.Pipeline()
			.Unless("Submerged", function(ctx)
				return ctx.submerged
			end)
			.Unless("OutOfReach", function(ctx)
				return ctx.far
			end)
			.Select("Allowed", function()
				return true
			end)
			.Build(),
		"owner"
	)
	return stages
end

local function names(stages)
	local out = {}
	for i, stage in ipairs(stages) do
		out[i] = stage.name
	end
	return out
end

local run = ModuleHandler.Evaluate

describe("a pipeline's identity", function()
	it("names the module a contract belongs to", function()
		local Contract = PolicyBuilder.Contract("transport", {
			Load = PolicyBuilder.Single({ Submerged = "Submerged" }),
		})
		assert.are.equal("transport", PolicyBuilder.OwnerOf(Contract))
		assert.is_nil(PolicyBuilder.OwnerOf({}))
		assert.is_nil(PolicyBuilder.OwnerOf("transport"))
	end)

	it("carries owner, category and the declared result", function()
		local Contract = PolicyBuilder.Contract("transport", {
			Load = PolicyBuilder.Single({ Submerged = "Submerged" }),
			LoadedSpeed = PolicyBuilder.Product({ CommanderDrag = "CommanderDrag" }),
		})
		assert.are.same(
			{ owner = "transport", category = "load", result = "single" },
			PolicyBuilder.IdentityOf(Contract.Load)
		)
		assert.are.same(
			{ owner = "transport", category = "loaded_speed", result = "product" },
			PolicyBuilder.IdentityOf(Contract.LoadedSpeed)
		)
		assert.is_nil(PolicyBuilder.IdentityOf({}))
		assert.are.equal(Contract.Load, PolicyBuilder.Pipeline(Contract.Load).stages)
	end)

	it("requires every category to declare itself", function()
		assert.has_error(
			function()
				PolicyBuilder.Contract("transport", { Load = { Submerged = "Submerged" } })
			end,
			"PolicyBuilder.Contract: Load must declare itself: Single(...), Product(...), Fold(...), Contributes(...) or Facts(...)"
		)
	end)

	it("serializes a declaration's name to the key the runtime uses", function()
		assert.are.equal("unit_terms_notes", PolicyBuilder.KeyOf("UnitTermsNotes"))
		assert.are.equal("take", PolicyBuilder.KeyOf("Take"))
	end)
end)

describe("one chain for owners and contributors", function()
	it("a bare stage joins the end of the checks, never past the terminal", function()
		local stages = owner()
		PolicyBuilder.Apply(
			stages,
			PolicyBuilder.Pipeline()
				.Unless("NoTanks", function(ctx)
					return ctx.tank
				end)
				.Build(),
			"mod"
		)
		assert.are.same({ "Submerged", "OutOfReach", "NoTanks", "Allowed" }, names(stages))
		assert.is_false(run(stages, { tank = true }))
		assert.is_true(run(stages, {}))
	end)

	it("places a stage after or before a named stage", function()
		local stages = owner()
		local ops = PolicyBuilder.Pipeline()
			.Unless("A", function() end)
			.After("Submerged")
			.Unless("B", function() end)
			.Before("Allowed")
			.Build()
		PolicyBuilder.Apply(stages, ops, "mod")
		assert.are.same({ "Submerged", "A", "OutOfReach", "B", "Allowed" }, names(stages))
	end)

	it("replaces a stage in place, keeping its kind, the terminal included", function()
		local stages = owner()
		local ops = PolicyBuilder.Pipeline()
			.Replace("OutOfReach", function() end)
			.Replace("Allowed", function()
				return "maybe"
			end)
			.Build()
		PolicyBuilder.Apply(stages, ops, "mod")
		assert.are.same({ "Submerged", "OutOfReach", "Allowed" }, names(stages))
		assert.are.equal("select", stages[3].kind)
		assert.are.equal("maybe", run(stages, { far = true }))
	end)

	it("removes a stage", function()
		local stages = owner()
		PolicyBuilder.Apply(stages, PolicyBuilder.Pipeline().Remove("Submerged").Build(), "mod")
		assert.are.same({ "OutOfReach", "Allowed" }, names(stages))
		assert.is_true(run(stages, { submerged = true }))
	end)

	it("names are the contract: unknown or colliding names are load errors naming the file", function()
		assert.has_error(function()
			PolicyBuilder.Apply(owner(), PolicyBuilder.Pipeline().Replace("Ghost", function() end).Build(), "mod.lua")
		end, "mod.lua: no stage named Ghost to replace")
		assert.has_error(function()
			PolicyBuilder.Apply(
				owner(),
				PolicyBuilder.Pipeline().Unless("Submerged", function() end).Build(),
				"mod.lua"
			)
		end, "mod.lua: the pipeline already has a stage named Submerged")
		assert.has_error(function()
			PolicyBuilder.Pipeline().After("Submerged")
		end)
	end)
end)

describe("one chain for owners and contributors", function()
	it("If is the inclusive guard: it refuses when its condition does not hold", function()
		---@type AssembledPipeline<SpecCtx, boolean>
		local stages = { result = "single" }
		PolicyBuilder.Apply(
			stages,
			PolicyBuilder.Pipeline()
				.If("WithinReach", function(ctx)
					return ctx.reachable
				end)
				.Select("Allowed", function()
					return true
				end)
				.Build(),
			"owner"
		)
		assert.is_false(run(stages, {}))
		assert.is_true(run(stages, { reachable = true }))
	end)
end)

describe("facts", function()
	it("carries identity, and provisions are named or refused", function()
		local Contract = PolicyBuilder.Contract("transfer", {
			TeamPairing = PolicyBuilder.Facts({ TechBlocking = "techBlocking" }),
		})
		assert.are.same(
			{ owner = "transfer", category = "team_pairing", facts = true },
			PolicyBuilder.IdentityOf(Contract.TeamPairing)
		)
		local ops = PolicyBuilder.Enrichment(Contract.TeamPairing)
			.Provide(Contract.TeamPairing.TechBlocking, function(ctx)
				return { level = 2 }
			end)
			.Build()
		assert.are.same({ "techBlocking" }, ops[1].names)
	end)

	it("a provider may add a fact the contract did not declare, and never removes one", function()
		local Contract = PolicyBuilder.Contract("transfer", {
			TeamPairing = PolicyBuilder.Facts({ TaxRate = "taxRate" }),
		})
		local ops = PolicyBuilder.Enrichment(Contract.TeamPairing)
			.Provide("stunSeconds", function()
				return 30
			end)
			.Build()
		assert.are.same({ "stunSeconds" }, ops[1].names)
		-- the contract keeps its declared fact; there is no verb that takes one away
		assert.are.equal("taxRate", Contract.TeamPairing.TaxRate)
	end)

	it("one producer can fill several provisions, in order", function()
		local ops = PolicyBuilder.Enrichment()
			.Provide("a", "b", function()
				return 1, 2
			end)
			.Build()
		assert.are.same({ "a", "b" }, ops[1].names)
		assert.has_error(function()
			PolicyBuilder.Enrichment().Provide("a")
		end)
	end)
end)

describe("module shared state", function()
	it("is one table per module across include instances", function()
		local A = VFS.Include("modules/module_handler.lua")
		local B = VFS.Include("modules/module_handler.lua")
		A.Shared("probe").count = 3
		assert.are.equal(3, B.Shared("probe").count)
		assert.are_not.equal(A.Shared("probe"), A.Shared("other"))
	end)
end)

describe("the refusal", function()
	it("is false unless the pipeline declares its shape", function()
		local stages = owner()
		assert.is_false(run(stages, { submerged = true }))
		PolicyBuilder.Apply(
			stages,
			PolicyBuilder.Pipeline()
				.Refusal(function(ctx)
					return { allowed = false, deep = ctx.submerged }
				end)
				.Build(),
			"owner"
		)
		assert.are.same({ allowed = false, deep = true }, run(stages, { submerged = true }))
		assert.is_true(run(stages, {}))
	end)

	it("is declared once", function()
		local stages = owner()
		local shape = PolicyBuilder.Pipeline()
			.Refusal(function()
				return false
			end)
			.Build()
		PolicyBuilder.Apply(stages, shape, "owner")
		assert.has_error(function()
			PolicyBuilder.Apply(stages, shape, "mod.lua")
		end, "mod.lua: the pipeline already has a Refusal")
	end)
end)

describe("the declared result", function()
	it("single: ends with a Select", function()
		PolicyBuilder.Validate(owner(), "single", "transport.load")
		assert.has_error(function()
			local stages = owner()
			PolicyBuilder.Apply(stages, PolicyBuilder.Pipeline().Remove("Allowed").Build(), "mod")
			PolicyBuilder.Validate(stages, "single", "transport.load")
		end, "transport.load: a single-result pipeline ends with a Select; OutOfReach is a guard")
		assert.has_error(function()
			local stages = owner()
			PolicyBuilder.Apply(
				stages,
				PolicyBuilder.Pipeline().Unless("Late", function() end).After("Allowed").Build(),
				"mod"
			)
			PolicyBuilder.Validate(stages, "single", "transport.load")
		end, "transport.load: a single-result pipeline ends with a Select; Late is a guard")
	end)

	it("single: an early Select preempts — answering when it can, passing when it cannot", function()
		local stages = owner()
		PolicyBuilder.Apply(
			stages,
			PolicyBuilder.Pipeline()
				.Select("Scripted", function(ctx)
					return ctx.scripted
				end)
				.Before("Submerged")
				.Build(),
			"mod"
		)
		PolicyBuilder.Validate(stages, "single", "transport.load")
		assert.are.equal("override", run(stages, { scripted = "override", submerged = true }))
		assert.is_false(run(stages, { submerged = true }))
		assert.is_true(run(stages, {}))
	end)

	it("product: factors from every module multiply into one answer", function()
		---@type AssembledPipeline<SpecProductCtx, number>
		local pipeline = { result = "product" }
		PolicyBuilder.Apply(
			pipeline,
			PolicyBuilder.Pipeline()
				.Select("CommanderDrag", function(ctx)
					return ctx.carriesCommander and 0.5 or nil
				end)
				.Select("MudCrawl", function(ctx)
					return ctx.inMud and 0.25 or nil
				end)
				.Build(),
			"owner"
		)
		assert.are.equal(0.125, run(pipeline, { carriesCommander = true, inMud = true }))
		assert.are.equal(0.25, run(pipeline, { inMud = true }))
		assert.is_nil(run(pipeline, {}))
	end)

	it("product: every stage is a Select", function()
		local stages = {}
		PolicyBuilder.Apply(stages, PolicyBuilder.Pipeline().Select("CommanderDrag", function() end).Build(), "owner")
		PolicyBuilder.Validate(stages, "product", "transport.loaded_speed")
		assert.has_error(function()
			PolicyBuilder.Apply(stages, PolicyBuilder.Pipeline().Unless("NoMud", function() end).Build(), "mod")
			PolicyBuilder.Validate(stages, "product", "transport.loaded_speed")
		end, "transport.loaded_speed: a product pipeline multiplies Select results; NoMud is a guard")
	end)
end)

describe("the fold result", function()
	local function fold(ops, origin)
		---@type AssembledPipeline<table, table>
		local stages = { result = "fold" }
		PolicyBuilder.Apply(stages, ops, origin)
		return stages
	end

	it("hands one context through every Select, owner's first, and returns it", function()
		local stages = fold(
			PolicyBuilder.Pipeline()
				.Select("Base", function(ctx)
					ctx.def.mass = (ctx.def.mass or 0) + 1
				end)
				.Build(),
			"owner"
		)
		PolicyBuilder.Apply(
			stages,
			PolicyBuilder.Pipeline()
				.Select("Heavier", function(ctx)
					ctx.def.mass = ctx.def.mass * 10
				end)
				.Build(),
			"mod"
		)
		local ctx = { def = {} }
		assert.are.equal(ctx, ModuleHandler.Evaluate(stages, ctx))
		assert.are.equal(10, ctx.def.mass)
		assert.are.same({ "Base", "Heavier" }, names(stages))
	end)

	it("every stage is a Select: a fold has nothing to refuse", function()
		local stages = fold(
			PolicyBuilder.Pipeline()
				.Unless("Never", function()
					return false
				end)
				.Build(),
			"owner"
		)
		assert.has_error(function()
			PolicyBuilder.Validate(stages, "fold", "defs.unit_def")
		end, "defs.unit_def: a fold pipeline runs every Select over the context; Never is a guard")
	end)
end)

describe("a declared contribution", function()
	local function target()
		return PolicyBuilder.Contract("transport", {
			Load = PolicyBuilder.Single({ Submerged = "Submerged", Allowed = "Allowed" }),
			Facts = PolicyBuilder.Facts({ Reach = "reach" }),
		})
	end

	it("carries the target's identity and the contributor's own", function()
		local Contract = target()
		local mod = PolicyBuilder.Contract("mod", {
			Load = PolicyBuilder.Contributes(Contract.Load, { NoTanks = "NoTanks" }),
		})
		assert.are.same(
			{ owner = "mod", category = "load", contributes = PolicyBuilder.IdentityOf(Contract.Load) },
			PolicyBuilder.IdentityOf(mod.Load)
		)
		assert.are.equal("NoTanks", mod.Load.NoTanks)
	end)

	it("targets a pipeline, never a context", function()
		local Contract = target()
		assert.has_error(function()
			PolicyBuilder.Contributes({}, { A = "A" })
		end, "PolicyBuilder.Contributes(target, names): target must be a pipeline's stages")
		assert.has_error(function()
			PolicyBuilder.Contributes(Contract.Facts, { A = "A" })
		end, "PolicyBuilder.Contributes(target, names): target must be a pipeline's stages")
	end)

	it("is the only way to add a step: a name no contract declares is refused", function()
		local ops = PolicyBuilder.Pipeline()
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

	it("moving, replacing or removing a step needs no declaration: the name already exists", function()
		local ops = PolicyBuilder.Pipeline()
			.Replace("Submerged", function()
				return false
			end)
			.Remove("Allowed")
			.Build()
		assert.is_nil(ModuleHandler.UndeclaredStep(ops, {}))
	end)
end)

describe("a contract's facts", function()
	local function enrichment(module, ops)
		return { module = module, ops = ops, file = module .. "/policies/x.lua" }
	end
	local function defaults(...)
		local chain = PolicyBuilder.Enrichment()
		for _, name in ipairs({ ... }) do
			chain.Default(name, function()
				return "default:" .. name
			end)
		end
		return chain.Build()
	end
	local function provides(name, value)
		return PolicyBuilder.Enrichment()
			.Provide(name, function()
				return value
			end)
			.Build()
	end

	it("must every one be given a Default by the owner, so a slot is a promise", function()
		assert.has_error(
			function()
				ModuleHandler.ResolveProvisions("transfer.team_terms", "transfer", { "taxRate" }, {})
			end,
			"transfer.team_terms declares taxRate without a Default; transfer must say what the slot means when nobody provides it"
		)
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
			enabled = { key = "enabled", category = "transfer", module = "transfer", uses = {} },
			tech_core = { key = "tech_core", category = "transfer", module = "tech", uses = {} },
			customize = { key = "customize", category = "transfer", module = "transfer", uses = { "tech" } },
		},
		game = {
			standard = { key = "standard", category = "game", module = "modes", uses = {} },
		},
	}
	local alwaysLive = { economy = true, construction = true }

	it("is the preset's module, what it Uses, and every module that ships no presets", function()
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
			experiments = { other = { key = "other", category = "experiments", module = "other", uses = {} } },
		}
		assert.are.same({
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=customize",
			"taxRate is provided by both other/p.lua and tech/p.lua under experiments=other, game=standard, transfer=tech_core",
		}, ModuleHandler.IsolationConflicts(withOther, alwaysLive, { provider("other"), provider("tech") }))
	end)
end)
