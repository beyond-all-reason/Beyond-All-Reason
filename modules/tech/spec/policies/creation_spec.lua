local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

local function lab(tier)
	return { isFactory = true, customParams = { techlevel = tostring(tier) } }
end

describe("a lab a team wants to build", function()
	local function may(unitDef, tier)
		return ModuleHandler.Evaluate(
			ModuleHandler.Contract(Modules.Construction).Creation,
			{ unitDefID = 1, teamID = 0, tier = tier, unitDef = unitDef }
		)
	end

	it("a lab opens at its tier and stays open above it", function()
		assert.is_false(may(lab(2), 1))
		assert.is_true(may(lab(2), 2))
		assert.is_true(may(lab(2), 3))
	end)

	it("gates labs only, never the units they build", function()
		assert.is_true(may({ isFactory = false, customParams = { techlevel = "3" } }, 1))
	end)

	it("gates nothing when no tier system is live", function()
		assert.is_true(may(lab(3), nil))
	end)
end)
