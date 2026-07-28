local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

describe("the take terms", function()
	it("are the modoptions' mode, delay and category", function()
		local terms = ModuleHandler.Evaluate(ModuleHandler.Contract(Modules.Transfer).Take, {
			modOptions = {
				[TransferEnums.ModOptions.TakeMode] = TransferEnums.TakeMode.Disabled,
				[TransferEnums.ModOptions.TakeDelaySeconds] = "45",
				[TransferEnums.ModOptions.TakeDelayCategory] = "all",
			},
		})
		assert.are.equal(TransferEnums.TakeMode.Disabled, terms.mode)
		assert.are.equal(45, terms.delaySeconds)
		assert.are.equal("all", terms.delayCategory)
	end)

	it("are enabled, thirty seconds and resource units when the modoptions say nothing", function()
		local terms = ModuleHandler.Evaluate(ModuleHandler.Contract(Modules.Transfer).Take, { modOptions = {} })
		assert.are.equal(TransferEnums.TakeMode.Enabled, terms.mode)
		assert.are.equal(30, terms.delaySeconds)
		assert.are.equal("resource", terms.delayCategory)
	end)
end)
