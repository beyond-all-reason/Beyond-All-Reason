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
	it("carries owner, category and the declared result", function()
		local Stages = PolicyBuilder.Stages("transport", {
			load = PolicyBuilder.Single({ Submerged = "Submerged" }),
			loaded_speed = PolicyBuilder.Product({ CommanderDrag = "CommanderDrag" }),
		})
		assert.are.same(
			{ owner = "transport", category = "load", result = "single" },
			PolicyBuilder.IdentityOf(Stages.load)
		)
		assert.are.same(
			{ owner = "transport", category = "loaded_speed", result = "product" },
			PolicyBuilder.IdentityOf(Stages.loaded_speed)
		)
		assert.is_nil(PolicyBuilder.IdentityOf({}))
		assert.are.equal(Stages.load, PolicyBuilder.Pipeline(Stages.load).stages)
	end)

	it("requires every category to declare itself", function()
		assert.has_error(function()
			PolicyBuilder.Stages("transport", { load = { Submerged = "Submerged" } })
		end, "PolicyBuilder.Stages: load must declare itself: Single(...), Product(...) or Context(...)")
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

describe("a context token", function()
	it("carries identity, and provisions are named or refused", function()
		local Stages = PolicyBuilder.Stages("transfer", {
			team_pairing = PolicyBuilder.Context({ TechBlocking = "techBlocking" }),
		})
		assert.are.same(
			{ owner = "transfer", category = "team_pairing", context = true },
			PolicyBuilder.IdentityOf(Stages.team_pairing)
		)
		local ops = PolicyBuilder.Enrichment(Stages.team_pairing)
			.Provide(Stages.team_pairing.TechBlocking, function(ctx)
				return { level = 2 }
			end)
			.Build()
		assert.are.same({ "techBlocking" }, ops[1].names)
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
