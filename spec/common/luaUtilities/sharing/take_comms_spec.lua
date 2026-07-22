local TakeComms = VFS.Include("common/luaUtilities/sharing/take_comms.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

describe("TakeComms.GetPolicy", function()
	it("reads mode, delaySeconds and delayCategory from modoptions", function()
		local policy = TakeComms.GetPolicy({
			[ModeEnums.ModOptions.TakeMode] = ModeEnums.TakeMode.StunDelay,
			[ModeEnums.ModOptions.TakeDelaySeconds] = 15,
			[ModeEnums.ModOptions.TakeDelayCategory] = ModeEnums.UnitCategory.Combat,
		})
		assert.equal(ModeEnums.TakeMode.StunDelay, policy.mode)
		assert.equal(15, policy.delaySeconds)
		assert.equal(ModeEnums.UnitCategory.Combat, policy.delayCategory)
	end)

	it("defaults to enabled / 30s / resource when unset", function()
		local policy = TakeComms.GetPolicy({})
		assert.equal(ModeEnums.TakeMode.Enabled, policy.mode)
		assert.equal(30, policy.delaySeconds)
		assert.equal(ModeEnums.UnitCategory.Resource, policy.delayCategory)
	end)
end)
