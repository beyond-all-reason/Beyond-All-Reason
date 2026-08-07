local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

local customizeMode = VFS.Include("modules/transfer/modes/customize.lua")

describe("Customize mode policy bundle", function()
	it("keeps the enum key and retains values", function()
		assert.equal(ModeEnums.Modes.Customize, customizeMode.key)
		assert.equal(true, customizeMode.retainValues)
	end)

	it("serializes to the exact modOptions the literal preset declared", function()
		assert.same({
			[ModeEnums.ModOptions.TechBlocking] = { value = false, locked = false },
			[ModeEnums.ModOptions.T2TechThreshold] = { value = 1, locked = false },
			[ModeEnums.ModOptions.T3TechThreshold] = { value = 1.5, locked = false },
			[ModeEnums.ModOptions.UnitSharingMode] = { value = ModeEnums.UnitFilterCategory.All, locked = false },
			[ModeEnums.ModOptions.UnitSharingModeAtT2] = { value = ModeEnums.UnitFilterCategory.None, locked = false },
			[ModeEnums.ModOptions.UnitSharingModeAtT3] = { value = ModeEnums.UnitFilterCategory.None, locked = false },
			[ModeEnums.ModOptions.UnitShareStunSeconds] = { value = 0, locked = false },
			[ModeEnums.ModOptions.UnitStunCategory] = { value = ModeEnums.UnitFilterCategory.Resource, locked = false },
			[ModeEnums.ModOptions.ConstructorBuildDelay] = { value = 0, locked = false },
			[ModeEnums.ModOptions.ResourceSharingEnabled] = { value = true, locked = false },
			[ModeEnums.ModOptions.TaxResourceSharingAmount] = { value = 0, locked = false },
			[ModeEnums.ModOptions.TaxResourceSharingAmountAtT2] = { value = -1, locked = false },
			[ModeEnums.ModOptions.TaxResourceSharingAmountAtT3] = { value = -1, locked = false },
			[ModeEnums.ModOptions.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Enabled, locked = false },
			[ModeEnums.ModOptions.AlliedUnitReclaimMode] = { value = ModeEnums.AlliedUnitReclaimMode.Enabled, locked = false },
			[ModeEnums.ModOptions.AllowPartialResurrection] = { value = ModeEnums.AllowPartialResurrection.Enabled, locked = false },
			[ModeEnums.ModOptions.TakeMode] = { value = ModeEnums.TakeMode.Enabled, locked = false },
			[ModeEnums.ModOptions.TakeDelaySeconds] = { value = 30, locked = false },
			[ModeEnums.ModOptions.TakeDelayCategory] = { value = ModeEnums.UnitCategory.Resource, locked = false },
		}, customizeMode.modOptions)
	end)
end)
