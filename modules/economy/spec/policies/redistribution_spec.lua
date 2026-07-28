local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

describe("a tick's results, before they are published", function()
	it("go out as they are, unless a module folds its own transfers in", function()
		local Contract = ModuleHandler.Contract(Modules.Economy)
		local resolved = ModuleHandler.LoadEnrichers(Contract.Redistribution)
		local results = { { teamId = 1, resourceType = "metal", sent = 3, received = 0 } }
		local facts = ModuleHandler.EnrichWith(resolved, {}, { results = results })
		assert.is_true(rawequal(results, facts[Contract.Redistribution.Results]))
	end)
end)
