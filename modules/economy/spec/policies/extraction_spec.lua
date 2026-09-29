local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

describe("what extraction pays each team this tick", function()
	it("is what its extractors made, unless a mode answers otherwise", function()
		local Contract = ModuleHandler.Contract(Modules.Economy)
		local resolved = ModuleHandler.LoadEnrichers(Contract.Extraction)
		local made = { [1] = { metal = 3, energy = 0 } }
		local ctx = { teams = {}, seconds = 1, income = made }
		assert.is_true(rawequal(made, ModuleHandler.EnrichWith(resolved, {}, ctx)[Contract.Extraction.Income]))
	end)
end)
