local ConstructionEnums = require("modules/construction/enums")
local TakeComms = require("modules/transfer/take/comms")
local TransferEnums = require("modules/transfer/enums")

describe("TakeComms.GetPolicy", function()
	it("reads mode, delaySeconds and delayCategory from modoptions", function()
		local policy = TakeComms.GetPolicy({
			[TransferEnums.ModOptions.TakeMode] = TransferEnums.TakeMode.StunDelay,
			[TransferEnums.ModOptions.TakeDelaySeconds] = 15,
			[TransferEnums.ModOptions.TakeDelayCategory] = ConstructionEnums.UnitCategory.Combat,
		})
		assert.equal(TransferEnums.TakeMode.StunDelay, policy.mode)
		assert.equal(15, policy.delaySeconds)
		assert.equal(ConstructionEnums.UnitCategory.Combat, policy.delayCategory)
	end)

	it("defaults to enabled / 30s / resource when unset", function()
		local policy = TakeComms.GetPolicy({})
		assert.equal(TransferEnums.TakeMode.Enabled, policy.mode)
		assert.equal(30, policy.delaySeconds)
		assert.equal(ConstructionEnums.UnitCategory.Resource, policy.delayCategory)
	end)
end)
