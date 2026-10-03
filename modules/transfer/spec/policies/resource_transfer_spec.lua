---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ContextFactoryModule = require("modules/transfer/context_factory")
local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

describe("sending an ally metal", function()
	local Contract = ModuleHandler.Contract(Modules.Transfer)
	local METAL = TransferEnums.ResourceType.METAL

	---@param opts table
	---@param activePlayers integer|nil
	local function repo(opts, activePlayers)
		return {
			GetModOptions = function()
				return opts
			end,
			GetTeamRulesParam = function(_, key)
				return key == "numActivePlayers" and activePlayers or nil
			end,
			GetGaiaTeamID = function()
				return 99
			end,
			GetTeamInfo = function()
				return "", true, false, false
			end,
		}
	end

	---@param fields table
	---@param rate number
	---@return ResourceTransferTerms
	local function terms(fields, rate)
		local ctx = {
			resourceType = METAL,
			taxRate = rate,
			senderTeamId = 1,
			receiverTeamId = 2,
			areAlliedTeams = true,
			isCheatingEnabled = false,
			springRepo = repo({}, 1),
			sender = { metal = { current = 1000, storage = 2000 }, energy = { current = 0, storage = 0 } },
			receiver = { metal = { current = 900, storage = 1000 }, energy = { current = 0, storage = 0 } },
		}
		for k, v in pairs(fields) do
			ctx[k] = v
		end
		return ModuleHandler.Evaluate(Contract.ResourceTransfer, ctx)
	end

	it("goes through taxed at the lobby's rate, and only as much as the receiver can hold", function()
		local granted = terms({}, 0.5)
		assert.is_true(granted.canShare)
		assert.are.equal(0.5, granted.taxRate)
		assert.are.equal(100, granted.amountSendable)
	end)

	it("is refused, on the same terms to read, when the teams are enemies or nobody is home", function()
		assert.is_false(terms({ areAlliedTeams = false }, 0).canShare)
		local refused = terms({ springRepo = repo({}, 0) }, 0)
		assert.is_false(refused.canShare)
		assert.are.equal(METAL, refused.resourceType)
		assert.is_true(terms({ springRepo = repo({}, 0), isCheatingEnabled = true }, 0).canShare)
	end)
end)
local ResourceTransfer, ResourceShared, SharedConfig
local function reloadTransfer()
	SharedConfig = require("modules/transfer/economy/shared_config")
	ResourceShared = require("modules/transfer/resource/shared")
	ResourceTransfer = require("modules/transfer/resource/synced")
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

describe("what the tax takes, and what the receiver's storage caps", function()
	local taxRate = 0.5

	describe("simple taxation", function()
		---@type ResourceTransferTerms
		local metalResult
		---@type ResourceTransferTerms
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
		---@type ResourceTransferTerms
		local metalResult
		---@type ResourceTransferTerms
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
		---@type ResourceTransferTerms
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
		---@type ResourceTransferTerms
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
		---@type ResourceTransferTerms
		local metalResult
		---@type ResourceTransferTerms
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
