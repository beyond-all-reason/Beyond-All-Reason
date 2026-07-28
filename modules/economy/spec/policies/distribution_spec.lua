local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

describe("what redistribution costs a team", function()
	it("is nothing, unless a module taxes it", function()
		local Contract = ModuleHandler.Contract(Modules.Economy)
		local resolved = ModuleHandler.LoadEnrichers(Contract.Distribution)
		local facts = ModuleHandler.EnrichWith(resolved, {}, { teamId = 1 })
		assert.are.equal(0, facts[Contract.Distribution.TaxRate])
	end)

	it("a team's excess reaches its allies, unless a module says it shares nothing", function()
		local Contract = ModuleHandler.Contract(Modules.Economy)
		local resolved = ModuleHandler.LoadEnrichers(Contract.Distribution)
		local facts = ModuleHandler.EnrichWith(resolved, {}, { teamId = 1 })
		assert.is_true(facts[Contract.Distribution.Shares])
	end)
end)
