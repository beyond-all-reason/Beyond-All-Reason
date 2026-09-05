---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ConstructionEnums = VFS.Include("modules/construction/enums.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local H = VFS.Include("modules/transfer/spec/support/mode_test_helpers.lua")

local techCoreMode = VFS.Include("modules/tech/modes/tech_core.lua")

-- Derive expected tax from the preset so value tweaks don't break the spec.
local baseTax = techCoreMode.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmount].value
local taxAtT2 = techCoreMode.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT2].value
local taxAtT3 = techCoreMode.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT3].value
local SENDER_POOL = 500

local function techCoreEnricher(techLevel, modeConfig)
	local baseTax = modeConfig.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmount].value
	local taxAtT2 = modeConfig.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT2]
		and modeConfig.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT2].value
	local taxAtT3 = modeConfig.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT3]
		and modeConfig.modOptions[TransferEnums.ModOptions.TaxResourceSharingAmountAtT3].value

	return {
		{
			names = { "techBlocking", "taxRate" },
			evaluate = function()
				local effectiveTax = baseTax
				if techLevel >= 3 and taxAtT3 then
					effectiveTax = taxAtT3
				elseif techLevel >= 2 and taxAtT2 then
					effectiveTax = taxAtT2
				end
				return {
					level = techLevel,
					points = techLevel - 1,
					t2Threshold = modeConfig.modOptions[TransferEnums.ModOptions.T2TechThreshold].value,
					t3Threshold = modeConfig.modOptions[TransferEnums.ModOptions.T3TechThreshold].value,
				},
					effectiveTax
			end,
		},
	}
end

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring
	.new()
	:WithTeam(sender)
	:WithTeam(receiver)
	:WithAlliance(sender.id, receiver.id, true)
	:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
	:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Tech Core mode #policy", function()
	describe("at T1 (base tax rate)", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			metalResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				techCoreEnricher(1, techCoreMode)
			)
			energyResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.ENERGY,
				techCoreEnricher(1, techCoreMode)
			)
		end)

		it("should ALLOW sharing", function()
			assert.equal(true, metalResult.canShare)
			assert.equal(true, energyResult.canShare)
		end)

		it("should use the base tax rate", function()
			assert.equal(baseTax, metalResult.taxRate)
			assert.equal(baseTax, energyResult.taxRate)
		end)

		it("should compute sendable amount with the base tax", function()
			assert.equal(SENDER_POOL * (1 - baseTax), metalResult.amountSendable)
			assert.equal(SENDER_POOL * (1 - baseTax), energyResult.amountSendable)
		end)

		it("should attach techBlocking context at level 1", function()
			assert.is_not_nil(metalResult.techBlocking)
			assert.equal(1, assert(metalResult.techBlocking).level)
		end)
	end)

	describe("at T2 (reduced tax rate)", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			metalResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				techCoreEnricher(2, techCoreMode)
			)
			energyResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.ENERGY,
				techCoreEnricher(2, techCoreMode)
			)
		end)

		it("should ALLOW sharing", function()
			assert.equal(true, metalResult.canShare)
			assert.equal(true, energyResult.canShare)
		end)

		it("should use the T2 tax rate", function()
			assert.equal(taxAtT2, metalResult.taxRate)
			assert.equal(taxAtT2, energyResult.taxRate)
		end)

		it("should compute more sendable resources than T1", function()
			assert.equal(SENDER_POOL * (1 - taxAtT2), metalResult.amountSendable)
			assert.equal(SENDER_POOL * (1 - taxAtT2), energyResult.amountSendable)
		end)

		it("should attach techBlocking context at level 2", function()
			assert.is_not_nil(metalResult.techBlocking)
			assert.equal(2, assert(metalResult.techBlocking).level)
		end)
	end)

	describe("at T3 (lowest tax rate)", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			metalResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				techCoreEnricher(3, techCoreMode)
			)
			energyResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.ENERGY,
				techCoreEnricher(3, techCoreMode)
			)
		end)

		it("should ALLOW sharing", function()
			assert.equal(true, metalResult.canShare)
			assert.equal(true, energyResult.canShare)
		end)

		it("should use the T3 tax rate", function()
			assert.equal(taxAtT3, metalResult.taxRate)
			assert.equal(taxAtT3, energyResult.taxRate)
		end)

		it("should compute most sendable resources at T3", function()
			assert.equal(SENDER_POOL * (1 - taxAtT3), metalResult.amountSendable)
			assert.equal(SENDER_POOL * (1 - taxAtT3), energyResult.amountSendable)
		end)

		it("should attach techBlocking context at level 3", function()
			assert.is_not_nil(metalResult.techBlocking)
			assert.equal(3, assert(metalResult.techBlocking).level)
		end)
	end)

	describe("tax progression across tech levels", function()
		it("should have decreasing tax rates from T1 to T3", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local t1 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(1, techCoreMode)
				)
			)
			local t2 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(2, techCoreMode)
				)
			)
			local t3 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(3, techCoreMode)
				)
			)

			assert.is_true(t1.taxRate > t2.taxRate)
			assert.is_true(t2.taxRate > t3.taxRate)
		end)

		it("should increase sendable amount as tech level increases", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local t1 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(1, techCoreMode)
				)
			)
			local t2 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(2, techCoreMode)
				)
			)
			local t3 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(3, techCoreMode)
				)
			)

			assert.is_true(t1.amountSendable < t2.amountSendable)
			assert.is_true(t2.amountSendable < t3.amountSendable)
		end)
	end)

	describe("without enricher (fallback behavior)", function()
		it("should fall back to base mod option tax rate when no enricher is registered", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeResult(spring, techCoreMode, sender, receiver, TransferEnums.ResourceType.METAL)

			assert.equal(baseTax, result.taxRate)
			assert.is_nil(result.techBlocking)
		end)
	end)

	describe("when receiver is full at T3", function()
		it("should NOT allow sharing despite low tax rate", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(1000):WithEnergy(1000)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local metalResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				techCoreEnricher(3, techCoreMode)
			)
			local energyResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.ENERGY,
				techCoreEnricher(3, techCoreMode)
			)

			assert.equal(false, metalResult.canShare)
			assert.equal(false, energyResult.canShare)
		end)
	end)

	describe("techBlocking extension data", function()
		it("should expose correct thresholds and points at each level", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local t1 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(1, techCoreMode)
				)
			)
			assert.equal(1, t1.techBlocking.level)
			assert.equal(0, t1.techBlocking.points)
			assert.equal(1, t1.techBlocking.t2Threshold)
			assert.equal(1.5, t1.techBlocking.t3Threshold)

			local t2 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(2, techCoreMode)
				)
			)
			assert.equal(2, t2.techBlocking.level)
			assert.equal(1, t2.techBlocking.points)

			local t3 = H.snapshotResult(
				H.buildModeResult(
					spring,
					techCoreMode,
					sender,
					receiver,
					TransferEnums.ResourceType.METAL,
					techCoreEnricher(3, techCoreMode)
				)
			)
			assert.equal(3, t3.techBlocking.level)
			assert.equal(2, t3.techBlocking.points)
		end)
	end)

	describe("when sender is empty at any tech level", function()
		it("should NOT allow sharing at T2", function()
			sender:WithMetal(0):WithEnergy(0)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local metalResult = H.buildModeResult(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				techCoreEnricher(2, techCoreMode)
			)

			assert.equal(false, metalResult.canShare)
		end)
	end)

	describe("transfer action at different tech levels", function()
		it("should cost less to send at T3 than T1 for the same received amount", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local t1Result = H.buildModeTransfer(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				100,
				techCoreEnricher(1, techCoreMode)
			)

			sender:WithMetal(500)
			receiver:WithMetal(0)

			local t3Result = H.buildModeTransfer(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				100,
				techCoreEnricher(3, techCoreMode)
			)

			assert.is_true(t1Result.success)
			assert.is_true(t3Result.success)
			assert.equal(100, t1Result.received)
			assert.equal(100, t3Result.received)
			assert.is_true(t1Result.sent > t3Result.sent)
		end)

		it("should transfer with T2 tax rate", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeTransfer(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				100,
				techCoreEnricher(2, techCoreMode)
			)

			assert.is_true(result.success)
			assert.equal(100, result.received)
			assert.is_near(100 / (1 - taxAtT2), result.sent, 0.1)
		end)

		it("should not transfer when receiver is full at T3", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(1000):WithEnergy(1000)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeTransfer(
				spring,
				techCoreMode,
				sender,
				receiver,
				TransferEnums.ResourceType.METAL,
				100,
				techCoreEnricher(3, techCoreMode)
			)

			assert.equal(false, result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)
	end)
end)

describe("Tech Core mode policy bundle", function()
	it("keeps the enum key", function()
		assert.equal(TransferEnums.Modes.TechCore, techCoreMode.key)
	end)

	it("serializes to the exact modOptions the literal preset declared", function()
		assert.same({
			[TransferEnums.ModOptions.TechBlocking] = { value = true, locked = true },
			[TransferEnums.ModOptions.T2TechThreshold] = { value = 1, locked = false },
			[TransferEnums.ModOptions.T3TechThreshold] = { value = 1.5, locked = false },
			[TransferEnums.ModOptions.UnitSharingMode] = {
				value = ConstructionEnums.UnitFilterCategory.None,
				locked = true,
			},
			[TransferEnums.ModOptions.UnitSharingModeAtT2] = {
				value = ConstructionEnums.UnitFilterCategory.Constructors,
				locked = true,
			},
			[TransferEnums.ModOptions.UnitSharingModeAtT3] = {
				value = ConstructionEnums.UnitFilterCategory.None,
				locked = true,
			},
			[TransferEnums.ModOptions.ResourceSharingEnabled] = { value = true, locked = true },
			[TransferEnums.ModOptions.TaxResourceSharingAmount] = { value = 0.6, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmountAtT2] = { value = 0.5, locked = false },
			[TransferEnums.ModOptions.TaxResourceSharingAmountAtT3] = { value = 0.4, locked = false },
			[ConstructionEnums.ModOptions.AlliedAssistMode] = {
				value = ConstructionEnums.AlliedAssistMode.Enabled,
				locked = true,
			},
			[ConstructionEnums.ModOptions.AlliedUnitReclaimMode] = {
				value = ConstructionEnums.AlliedUnitReclaimMode.Enabled,
				locked = true,
			},
			[ConstructionEnums.ModOptions.AllowPartialResurrection] = {
				value = ConstructionEnums.AllowPartialResurrection.Disabled,
				locked = true,
			},
			[TransferEnums.ModOptions.TakeMode] = { value = TransferEnums.TakeMode.TakeDelay, locked = true },
			[TransferEnums.ModOptions.TakeDelaySeconds] = { value = 60, locked = false },
			[TransferEnums.ModOptions.TakeDelayCategory] = {
				value = ConstructionEnums.UnitCategory.Resource,
				locked = true,
			},
		}, techCoreMode.modOptions)
	end)
end)
