local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a def a team wants to build", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	it("construction itself refuses nobody; a tier gate is another module's guard", function()
		assert.is_true(
			decide(Contract.Creation, { unitDefID = 1, teamID = 0, tier = nil, unitDef = { isFactory = true } })
		)
	end)

	it("has no tier unless a module provides one", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.CreationFacts)
		local facts = ModuleHandler.EnrichWith(resolved, {}, { teamID = 0 })
		assert.is_nil(facts[Contract.CreationFacts.Tier])
	end)
end)
