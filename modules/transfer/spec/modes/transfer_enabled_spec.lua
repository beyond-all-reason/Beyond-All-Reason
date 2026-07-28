---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("modules/context/enums.lua")
local H = Builders.Mode

local enabledMode = VFS.Include("modules/transfer/modes/enabled.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()
local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):WithAlliance(sender.id, receiver.id, true):WithTeamRulesParam(receiver.id, "numActivePlayers", 1):WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe("Transfer Enabled mode #policy", function()
	describe("with default settings (zero tax, zero thresholds)", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			metalResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL)
			energyResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY)
		end)

		it("should ALLOW sharing of both resources", function()
			assert.equal(true, metalResult.canShare)
			assert.equal(true, energyResult.canShare)
		end)

		it("should have zero tax rate", function()
			assert.equal(0, metalResult.taxRate)
			assert.equal(0, energyResult.taxRate)
		end)

		it("should have sendable equal to full sender budget (no tax overhead)", function()
			assert.equal(500, metalResult.amountSendable)
			assert.equal(500, energyResult.amountSendable)
		end)

		it("should have receivable equal to full receiver capacity", function()
			assert.equal(1000, metalResult.amountReceivable)
			assert.equal(1000, energyResult.amountReceivable)
		end)
	end)

	describe("when receiver is full", function()
		it("should NOT allow sharing", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(1000):WithEnergy(1000)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local metalResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL)
			local energyResult = H.buildModeResult(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY)

			assert.equal(false, metalResult.canShare)
			assert.equal(false, energyResult.canShare)
		end)
	end)

	describe("transfer action (untaxed)", function()
		it("should transfer with sent == received (no tax deducted)", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeTransfer(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL, 200)

			assert.is_true(result.success)
			assert.equal(200, result.received)
			assert.equal(200, result.sent)
		end)

		it("should transfer energy with sent == received", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(0):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeTransfer(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.ENERGY, 300)

			assert.is_true(result.success)
			assert.equal(300, result.received)
			assert.equal(300, result.sent)
		end)

		it("should not transfer when receiver is full", function()
			sender:WithMetal(500):WithEnergy(500)
			receiver:WithMetal(1000):WithEnergy(1000)
			receiver:WithMetalStorage(1000):WithEnergyStorage(1000)

			local result = H.buildModeTransfer(spring, enabledMode, sender, receiver, TransferEnums.ResourceType.METAL, 100)

			assert.equal(false, result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)
	end)
end)

describe("Enabled mode policy bundle", function()
	local ModeEnums = VFS.Include("modules/context/mode_enums.lua")

	it("keeps the enum key", function()
		assert.equal(ModeEnums.Modes.Enabled, enabledMode.key)
	end)

	it("serializes to the exact modOptions the literal preset declared", function()
		assert.same({
			[ModeEnums.ModOptions.UnitSharingMode] = { value = ModeEnums.UnitFilterCategory.All, locked = true },
			[ModeEnums.ModOptions.ResourceSharingEnabled] = { value = true, locked = true },
			[ModeEnums.ModOptions.TaxResourceSharingAmount] = { value = 0.0, locked = true, ui = "hidden" },
			[ModeEnums.ModOptions.AlliedAssistMode] = { value = ModeEnums.AlliedAssistMode.Enabled, locked = true },
			[ModeEnums.ModOptions.AlliedUnitReclaimMode] = { value = ModeEnums.AlliedUnitReclaimMode.Enabled, locked = true },
			[ModeEnums.ModOptions.TakeMode] = { value = ModeEnums.TakeMode.Enabled, locked = true },
		}, enabledMode.modOptions)
	end)
end)
