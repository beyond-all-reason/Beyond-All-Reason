local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("PolicyBuilder", function()
	describe("Pipeline", function()
		local function denyAll(ctx)
			return { canShare = false }
		end
		local function computeOk(ctx)
			return { canShare = true }
		end

		it("emits descriptors in declaration order (category stamping is the loader's job)", function()
			local stages = PolicyBuilder.Pipeline()
				:Gate("First", denyAll)
				:Gate("Second", denyAll)
				:Compute("Last", computeOk)
				:Build()
			assert.are.same({ "First", "Second", "Last" }, { stages[1].name, stages[2].name, stages[3].name })
			assert.is_nil(stages[2].category)
		end)

		it("composes with ModuleHandler.Evaluate (gate pass vs stop)", function()
			local stages = PolicyBuilder.Pipeline()
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
				PolicyBuilder.Pipeline():Gate("g", denyAll):Build()
			end)
			assert.has_error(function()
				PolicyBuilder.Pipeline():Compute("c", computeOk):Gate("g", denyAll)
			end)
			assert.has_error(function()
				PolicyBuilder.Pipeline():Compute("c", computeOk):Compute("c2", computeOk)
			end)
		end)
	end)
end)
