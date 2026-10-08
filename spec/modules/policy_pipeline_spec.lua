local ModuleHandler = require("modules/module_handler")
local Policy = require("modules/policy")

local function names(steps)
	local out = {}
	for i, step in ipairs(steps) do
		out[i] = step.name
	end
	return out
end

---@generic T: table
---@param owner string
---@param members T
---@return T
local function declared(owner, members)
	Policy.Declare(owner, members, "spec")
	return members
end

describe("a policy's identity", function()
	it("requires every category to declare itself", function()
		assert.has_error(function()
			declared("transport", { Load = { Submerged = "Submerged" } })
		end, "spec: Load must declare itself: Fold(...) or Contributes(...)")
	end)

	it("serializes a declaration's name to the key the runtime uses", function()
		assert.are.equal("unit_terms_notes", Policy.KeyOf("UnitTermsNotes"))
		assert.are.equal("take", Policy.KeyOf("Take"))
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
end)
