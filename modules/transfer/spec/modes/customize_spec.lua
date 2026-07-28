local ConstructionEnums = require("modules/construction/enums")
local TransferEnums = require("modules/transfer/enums")

local customizeMode = require("modules/transfer/modes/customize")

---@param enums table<string, string>
---@param options table<string, ModOptionConfig>
---@return table<string, ModOptionConfig> the options whose keys the enums name
local function ownedBy(enums, options)
	local own = {}
	for _, key in pairs(enums) do
		own[key] = options[key]
	end
	return own
end

describe("Customize mode policy bundle", function()
	it("keeps the enum key and retains values", function()
		assert.equal(TransferEnums.Modes.Customize, customizeMode.key)
		assert.equal(true, customizeMode.retainValues)
	end)

	it("serializes its own dials and construction's to the values the literal preset declared", function()
		local options = customizeMode.modOptions
		assert.same({
			[TransferEnums.ModOptions.UnitSharingMode] = {
				value = ConstructionEnums.UnitFilterCategory.All,
				locked = false,
			},
			[TransferEnums.ModOptions.UnitShareStunSeconds] = { value = 0, locked = false },
			[TransferEnums.ModOptions.UnitStunCategory] = {
				value = ConstructionEnums.UnitFilterCategory.Resource,
				locked = false,
			},
			[TransferEnums.ModOptions.ResourceSharingEnabled] = { value = true, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmount] = { value = 0, locked = false },
			[TransferEnums.ModOptions.TakeMode] = { value = TransferEnums.TakeMode.Enabled, locked = false },
			[TransferEnums.ModOptions.TakeDelaySeconds] = { value = 30, locked = false },
			[TransferEnums.ModOptions.TakeDelayCategory] = {
				value = ConstructionEnums.UnitCategory.Resource,
				locked = false,
			},
		}, ownedBy(TransferEnums.ModOptions, options))
		assert.same({
			[ConstructionEnums.ModOptions.ConstructorBuildDelay] = { value = 0, locked = false },
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
		}, ownedBy(ConstructionEnums.ModOptions, options))
	end)

	it("exposes every other module's dials on the axis, open", function()
		for key, option in pairs(customizeMode.modOptions) do
			assert.is_false(option.locked, key .. " is locked")
		end
	end)
end)
