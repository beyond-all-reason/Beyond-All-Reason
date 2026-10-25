local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a builder reclaiming, or guarding a reclaimer", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	it("with the mode off, allies may neither reclaim each other nor guard a reclaimer", function()
		assert.is_false(
			decide(
				Contract.Reclaim,
				{ allied = true, command = "reclaim", targetCanReclaim = false, reclaimEnabled = false }
			)
		)
		assert.is_false(
			decide(
				Contract.Reclaim,
				{ allied = true, command = "guard", targetCanReclaim = true, reclaimEnabled = false }
			)
		)
		assert.is_true(
			decide(
				Contract.Reclaim,
				{ allied = true, command = "guard", targetCanReclaim = false, reclaimEnabled = false }
			)
		)
		assert.is_true(
			decide(
				Contract.Reclaim,
				{ allied = true, command = "reclaim", targetCanReclaim = false, reclaimEnabled = true }
			)
		)
	end)
end)
