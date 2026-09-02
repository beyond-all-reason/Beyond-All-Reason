local ModuleHandler = VFS.Include("modules/module_handler.lua")

local pipelines = ModuleHandler.LoadPolicies("tech") ---@type TechPipelines

describe("tech unlock", function()
	it("a def opens at its tier and stays open above it", function()
		assert.is_false(
			ModuleHandler.Evaluate(pipelines.unlock, { unitDefID = 1, teamID = 0, level = 1, requiredLevel = 2 })
		)
		assert.is_true(
			ModuleHandler.Evaluate(pipelines.unlock, { unitDefID = 1, teamID = 0, level = 2, requiredLevel = 2 })
		)
		assert.is_true(
			ModuleHandler.Evaluate(pipelines.unlock, { unitDefID = 1, teamID = 0, level = 3, requiredLevel = 2 })
		)
	end)
end)
