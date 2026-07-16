local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("PolicyBuilder", function()
	local function denyResult(ctx)
		return { canShare = false, senderTeamId = ctx.senderTeamId, receiverTeamId = ctx.receiverTeamId }
	end

	---A hand-written descriptor with the same semantics as the built one.
	local handWritten = {
		name = "NoEnemySharing",
		category = "metal_transfer",
		evaluate = function(ctx)
			if ctx.areAlliedTeams ~= false then
				return nil
			end
			return denyResult(ctx)
		end,
	}

	local built = PolicyBuilder.new("NoEnemySharing")
		:Category("metal_transfer")
		:Enemy()
		:Deny(denyResult)
		:Build()

	local enemyCtx = { areAlliedTeams = false, senderTeamId = 1, receiverTeamId = 2 }
	local alliedCtx = { areAlliedTeams = true, senderTeamId = 1, receiverTeamId = 2 }

	it("emits a descriptor with name and category", function()
		assert.are.equal(handWritten.name, built.name)
		assert.are.equal(handWritten.category, built.category)
		assert.are.equal("function", type(built.evaluate))
	end)

	it("matches the hand-written descriptor when predicates hold", function()
		assert.are.same(handWritten.evaluate(enemyCtx), built.evaluate(enemyCtx))
	end)

	it("matches the hand-written descriptor when predicates fail (nil = pass)", function()
		assert.is_nil(built.evaluate(alliedCtx))
		assert.are.same(handWritten.evaluate(alliedCtx), built.evaluate(alliedCtx))
	end)

	it("requires a terminal before Build", function()
		assert.has_error(function()
			PolicyBuilder.new("Incomplete"):Category("metal_transfer"):Build()
		end)
	end)

	it("composes with ModuleHandler.Evaluate first-result-wins", function()
		local compute = {
			name = "Compute",
			evaluate = function(ctx)
				return { canShare = true }
			end,
		}
		local denied = ModuleHandler.Evaluate({ built, compute }, enemyCtx)
		assert.is_false(denied.canShare)
		local allowed = ModuleHandler.Evaluate({ built, compute }, alliedCtx)
		assert.is_true(allowed.canShare)
	end)
	describe("Pipeline", function()
		local function denyAll(ctx)
			return { canShare = false }
		end
		local function computeOk(ctx)
			return { canShare = true }
		end

		it("emits descriptors in declaration order with the category stamped", function()
			local stages = PolicyBuilder.Pipeline("resource")
				:Gate("First", denyAll)
				:Gate("Second", denyAll)
				:Compute("Last", computeOk)
				:Build()
			assert.are.same({ "First", "Second", "Last" }, { stages[1].name, stages[2].name, stages[3].name })
			assert.are.equal("resource", stages[2].category)
		end)

		it("composes with ModuleHandler.Evaluate (gate pass vs stop)", function()
			local stages = PolicyBuilder.Pipeline("resource")
				:Gate("MaybeDeny", function(ctx)
					if ctx.blocked then
						return { canShare = false }
					end
					return nil
				end)
				:Compute("Compute", computeOk)
				:Build()
			assert.is_false(ModuleHandler.Evaluate(stages, { blocked = true }).canShare)
			assert.is_true(ModuleHandler.Evaluate(stages, { blocked = false }).canShare)
		end)

		it("enforces exactly one terminal Compute, last", function()
			assert.has_error(function()
				PolicyBuilder.Pipeline("x"):Gate("g", denyAll):Build()
			end)
			assert.has_error(function()
				PolicyBuilder.Pipeline("x"):Compute("c", computeOk):Gate("g", denyAll)
			end)
			assert.has_error(function()
				PolicyBuilder.Pipeline("x"):Compute("c", computeOk):Compute("c2", computeOk)
			end)
		end)
	end)
end)
