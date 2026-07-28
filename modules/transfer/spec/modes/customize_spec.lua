local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

local customizeMode = VFS.Include("modules/transfer/modes/customize.lua")

describe("Customize mode policy bundle", function()
	it("keeps the enum key and retains values", function()
		assert.equal(TransferEnums.Modes.Customize, customizeMode.key)
		assert.equal(true, customizeMode.retainValues)
	end)

	it("serializes to the exact modOptions the literal preset declared", function()
		assert.same({
			[TransferEnums.ModOptions.TechBlocking] = { value = false, locked = false },
			[TransferEnums.ModOptions.T2TechThreshold] = { value = 1, locked = false },
			[TransferEnums.ModOptions.T3TechThreshold] = { value = 1.5, locked = false },
			[TransferEnums.ModOptions.UnitSharingMode] = {
				value = ConstructionEnums.UnitFilterCategory.All,
				locked = false,
			},
			[TransferEnums.ModOptions.UnitSharingModeAtT2] = {
				value = ConstructionEnums.UnitFilterCategory.None,
				locked = false,
			},
			[TransferEnums.ModOptions.UnitSharingModeAtT3] = {
				value = ConstructionEnums.UnitFilterCategory.None,
				locked = false,
			},
			[TransferEnums.ModOptions.UnitShareStunSeconds] = { value = 0, locked = false },
			[TransferEnums.ModOptions.UnitStunCategory] = {
				value = ConstructionEnums.UnitFilterCategory.Resource,
				locked = false,
			},
			[ConstructionEnums.ModOptions.ConstructorBuildDelay] = { value = 0, locked = false },
			[TransferEnums.ModOptions.ResourceSharingEnabled] = { value = true, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmount] = { value = 0, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmountAtT2] = { value = -1, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmountAtT3] = { value = -1, locked = false },
			[ConstructionEnums.ModOptions.AlliedAssistMode] = {
				value = ConstructionEnums.AlliedAssistMode.Enabled,
				locked = false,
			},
			[ConstructionEnums.ModOptions.AlliedUnitReclaimMode] = {
				value = ConstructionEnums.AlliedUnitReclaimMode.Enabled,
				locked = false,
			},
			[ConstructionEnums.ModOptions.AllowPartialResurrection] = {
				value = ConstructionEnums.AllowPartialResurrection.Enabled,
				locked = false,
			},
			[TransferEnums.ModOptions.TakeMode] = { value = TransferEnums.TakeMode.Enabled, locked = false },
			[TransferEnums.ModOptions.TakeDelaySeconds] = { value = 30, locked = false },
			[TransferEnums.ModOptions.TakeDelayCategory] = {
				value = ConstructionEnums.UnitCategory.Resource,
				locked = false,
			},
		}, customizeMode.modOptions)
	end)
end)
