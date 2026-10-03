local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

---@param level integer
---@param opts table
---@return TechCoreLadder
local function ladder(level, opts)
	return ModuleHandler.Evaluate(
		ModuleHandler.Contract(Modules.Tech).TechCore,
		{ level = level, points = 5, modOptions = opts, t2Threshold = 10, t3Threshold = 20 }
	)
end

describe("the ladder a team stands on", function()
	local opts = {
		unit_sharing_mode = "none",
		unit_sharing_mode_at_t2 = "resource",
		tax_resource_sharing_amount = 0.5,
		tax_resource_sharing_amount_at_t3 = 0,
	}

	it("reads the tier's tax and unit sharing modes off the modoptions", function()
		local one = ladder(1, opts)
		assert.are.same({ "none" }, one.modes)
		assert.are.equal(0.5, one.taxRate)
		local two = ladder(2, opts)
		assert.are.same({ "resource" }, two.modes)
		assert.are.equal(0.5, two.taxRate, "the tier 2 tax is the base rate when none is set for it")
		assert.are.equal(0, ladder(3, opts).taxRate)
	end)

	it("says what the next tier unlocks, and at what threshold", function()
		local blocking = ladder(1, opts).blocking
		assert.are.equal(2, blocking.nextLevel)
		assert.are.equal(10, blocking.nextThreshold)
		assert.are.same({ unlockLevel = 2, unlockThreshold = 10, unlockValue = "resource" }, blocking.unitTransfer)
		assert.are.same({ unlockLevel = 3, unlockThreshold = 20, unlockValue = 0 }, blocking.metalTransfer)
		assert.is_nil(ladder(3, opts).blocking.unitTransfer, "nothing above tier 3")
	end)
end)
