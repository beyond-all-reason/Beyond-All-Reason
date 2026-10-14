local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function decide(policy, ctx)
	return ModuleHandler.Evaluate(policy, ctx)
end

describe("a wreck that was partly reclaimed", function()
	local Contract = ModuleHandler.Contract(Modules.Construction)

	it("a partly reclaimed wreck resurrects only when the mode allows", function()
		assert.is_true(decide(Contract.Resurrect, { partialAllowed = true }))
		assert.is_false(decide(Contract.Resurrect, { partialAllowed = false }))
	end)
end)
