local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a builder helping another's unit along", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	it("lets anyone help their own, and allies help when the mode is on", function()
		assert.is_true(
			decide(
				Contract.Assist,
				{ allied = false, targetComplete = false, targetIsBuilder = true, assistEnabled = false }
			)
		)
		assert.is_true(
			decide(
				Contract.Assist,
				{ allied = true, targetComplete = false, targetIsBuilder = true, assistEnabled = true }
			)
		)
	end)

	it("with the mode off, an ally may not help an unfinished unit or any builder", function()
		assert.is_false(
			decide(
				Contract.Assist,
				{ allied = true, targetComplete = false, targetIsBuilder = false, assistEnabled = false }
			)
		)
		assert.is_false(
			decide(
				Contract.Assist,
				{ allied = true, targetComplete = true, targetIsBuilder = true, assistEnabled = false }
			)
		)
		assert.is_true(
			decide(
				Contract.Assist,
				{ allied = true, targetComplete = true, targetIsBuilder = false, assistEnabled = false }
			)
		)
	end)
end)
