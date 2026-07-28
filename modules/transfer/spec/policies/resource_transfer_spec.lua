---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local ContextFactoryModule = VFS.Include("modules/transfer/context_factory.lua")
-- VFS.Include re-executes on every call, so resetting the spec's own shared_config leaves
-- the one inside synced.lua untouched; re-including the chain is the reset.
local ResourceTransfer, ResourceShared, SharedConfig
local function reloadTransfer()
	SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")
	ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
	ResourceTransfer = VFS.Include("modules/transfer/resource/synced.lua")
end
reloadTransfer()

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()

local function buildResourceResult(spring, taxRate, sender, receiver, resourceType)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return {
			tax_resource_sharing_amount = tostring(taxRate),
		}
	end
	reloadTransfer()
	local ctx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
	return ResourceTransfer.CalcResourcePolicy(ctx, resourceType)
end

local spring = Builders.Spring
	.new()
	:WithTeam(sender)
	:WithTeam(receiver)
	:WithAlliance(sender.id, receiver.id, true)
	:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
	:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe(TransferEnums.ModOptions.TaxResourceSharingAmount .. " #policy", function()
	local taxRate = 0.5

	describe("simple taxation", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithEnergy(500):WithMetal(500)
			receiver:WithEnergy(0):WithMetal(0)

			spring:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, taxRate)

			metalResult = buildResourceResult(spring, taxRate, sender, receiver, TransferEnums.ResourceType.METAL)
			energyResult = buildResourceResult(spring, taxRate, sender, receiver, TransferEnums.ResourceType.ENERGY)
		end)

		it("should ALLOW sharing of both METAL and ENERGY", function()
			assert.equal(metalResult.canShare, true)
			assert.equal(energyResult.canShare, true)
		end)

		it("should cap amount sendable (in receivable units) and account for tax overhead", function()
			assert.equal(250, metalResult.amountSendable)
			assert.equal(250, energyResult.amountSendable)
		end)

		it("should cap the amount receivable by the receivers storage capacity", function()
			assert.equal(1000, metalResult.amountReceivable)
			assert.equal(1000, energyResult.amountReceivable)
		end)

		it("should expose the tax rate", function()
			assert.equal(taxRate, metalResult.taxRate)
			assert.equal(taxRate, energyResult.taxRate)
		end)
	end)

	describe("when receiver is full", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithEnergy(500):WithMetal(500)
			receiver:WithEnergy(1000):WithMetal(1000)

			metalResult = buildResourceResult(spring, taxRate, sender, receiver, TransferEnums.ResourceType.METAL)
			energyResult = buildResourceResult(spring, taxRate, sender, receiver, TransferEnums.ResourceType.ENERGY)
		end)

		it("should NOT allow sharing when receiver is full", function()
			assert.equal(metalResult.canShare, false)
			assert.equal(energyResult.canShare, false)
		end)

		it("should set amount sendable to 0", function()
			assert.equal(0, metalResult.amountSendable)
			assert.equal(0, energyResult.amountSendable)
		end)
	end)

	describe("when receiver capacity is below the taxed sendable amount", function()
		it("should cap amount sendable to the receiver capacity", function()
			sender:WithMetal(1000)
			receiver:WithMetal(980)
			local metalResult = buildResourceResult(spring, taxRate, sender, receiver, TransferEnums.ResourceType.METAL)
			assert.equal(metalResult.amountSendable, 20)
		end)
	end)

	describe("rate = 0.7, receiver capacity 300, sender 1000", function()
		---@type ResourcePolicyResult
		local energyResult
		local testTaxRate = 0.7

		before_each(function()
			spring:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
			sender:WithEnergy(1000)
			receiver:WithEnergyStorage(1000):WithEnergy(700)

			energyResult = buildResourceResult(spring, testTaxRate, sender, receiver, TransferEnums.ResourceType.ENERGY)
		end)

		it("should have amountReceivable set to receiver capacity and amountSendable == 300", function()
			assert.equal(300, energyResult.amountReceivable)
			assert.equal(300, energyResult.amountSendable)
		end)
	end)

	describe("sender 1000, rate = 0.7, receiver capacity 300", function()
		---@type ResourcePolicyResult
		local energyResult
		local testTaxRate = 0.7

		before_each(function()
			spring:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
			sender:WithEnergy(1000)
			receiver:WithEnergyStorage(1000):WithEnergy(700)

			energyResult = buildResourceResult(spring, testTaxRate, sender, receiver, TransferEnums.ResourceType.ENERGY)
		end)

		it("should enable sharing", function()
			assert.equal(true, energyResult.canShare)
		end)

		it("should have a receivable amount set to the receiver's capacity and amountSendable == 300", function()
			assert.equal(300, energyResult.amountReceivable)
			assert.equal(300, energyResult.amountSendable)
		end)
	end)

	describe("when taxation is disabled", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			spring:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, 0)
			receiver:WithEnergyStorage(1000):WithEnergy(0)
			receiver:WithMetalStorage(1000):WithMetal(0)
		end)

		it("should not tax metal transfers", function()
			sender:WithMetal(100)
			metalResult = buildResourceResult(spring, 0, sender, receiver, TransferEnums.ResourceType.METAL)
			assert.equal(1000, metalResult.amountReceivable)
			assert.equal(100, metalResult.amountSendable)

			sender:WithMetal(500)
			metalResult = buildResourceResult(spring, 0, sender, receiver, TransferEnums.ResourceType.METAL)
			assert.equal(1000, metalResult.amountReceivable)
			assert.equal(500, metalResult.amountSendable)
		end)

		it("should not tax energy transfers", function()
			sender:WithEnergy(100)
			energyResult = buildResourceResult(spring, 0, sender, receiver, TransferEnums.ResourceType.ENERGY)
			assert.equal(1000, energyResult.amountReceivable)
			assert.equal(100, energyResult.amountSendable)

			sender:WithEnergy(500)
			energyResult = buildResourceResult(spring, 0, sender, receiver, TransferEnums.ResourceType.ENERGY)
			assert.equal(1000, energyResult.amountReceivable)
			assert.equal(500, energyResult.amountSendable)
		end)
	end)
end)
