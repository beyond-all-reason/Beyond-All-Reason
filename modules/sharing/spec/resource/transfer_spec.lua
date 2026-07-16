---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local ContextFactoryModule = VFS.Include("modules/sharing/context_factory.lua")
local PolicyEvaluation = VFS.Include("modules/sharing/policy_evaluation.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ResourceTransferAction = ModuleHandler.LoadActions("sharing").byName.resource_transfer
local ResourceShared = VFS.Include("modules/sharing/resource/shared.lua")
local SharedConfig = VFS.Include("modules/sharing/config.lua")

local sender = Builders.Team:new():Human()
local receiver = Builders.Team:new():Human()

local function buildResourceResult(spring, taxRate, sender, receiver, resourceType)
	local springApi = spring:Build()
	springApi.GetModOptions = function()
		return {
			tax_resource_sharing_amount = tostring(taxRate),
		}
	end
	SharedConfig.resetCache()
	local ctx = ContextFactoryModule.create(springApi).policy(sender.id, receiver.id)
	return PolicyEvaluation.CalcResourcePolicy(ctx, resourceType)
end

local spring = Builders
	.Spring
	.new()
	:WithTeam(sender)
	:WithTeam(receiver)
	:WithAlliance(sender.id, receiver.id, true)
	-- set in-game by cmd_idle_players.lua
	:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
	:WithTeamRulesParam(sender.id, "numActivePlayers", 1)

describe(ModeEnums.ModOptions.TaxResourceSharingAmount .. " #policy", function()
	local taxRate = 0.5

	describe("simple taxation", function()
		---@type ResourcePolicyResult
		local metalResult
		---@type ResourcePolicyResult
		local energyResult

		before_each(function()
			sender:WithEnergy(500):WithMetal(500)
			receiver:WithEnergy(0):WithMetal(0)

			spring:WithModOption(ModeEnums.ModOptions.TaxResourceSharingAmount, taxRate)

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
			spring:WithModOption(ModeEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
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
			spring:WithModOption(ModeEnums.ModOptions.TaxResourceSharingAmount, testTaxRate)
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
			spring:WithModOption(ModeEnums.ModOptions.TaxResourceSharingAmount, 0)
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

describe("ResourceTransfer #action", function()
	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()
	local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):Build()

	describe("basic resource transfer", function()
		it("should transfer metal without overhead when the tax rate is zero", function()
			---@type ResourceTransferContext
			local ctx = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				resourceType = TransferEnums.ResourceType.METAL,
				desiredAmount = 100,
				isCheatingEnabled = false,
				springRepo = spring,
				areAlliedTeams = true,
				ext = {},
				sender = {
					metal = {
						resourceType = "metal",
						excess = 0,
						current = 1000,
						storage = 1000,
						pull = 0,
						income = 0,
						expense = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
					energy = {
						resourceType = "energy",
						excess = 0,
						current = 1000,
						storage = 1000,
						pull = 0,
						income = 0,
						expense = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
				},
				receiver = {
					metal = {
						resourceType = "metal",
						excess = 0,
						current = 500,
						storage = 1000,
						pull = 0,
						income = 0,
						expense = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
					energy = {
						resourceType = "energy",
						excess = 0,
						current = 500,
						storage = 1000,
						pull = 0,
						income = 0,
						expense = 0,
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
				},
				policyResult = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0,
					taxedPortion = 500,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransferAction.execute(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
		end)

		it("debits the sender and credits the receiver in engine team state", function()
			local s = Builders.Team:new():Human():WithMetal(1000):WithMetalStorage(1000)
			local r = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000)
			local spr = Builders.Spring.new():WithTeam(s):WithTeam(r):Build()

			---@type ResourceTransferContext
			local ctx = {
				senderTeamId = s.id,
				receiverTeamId = r.id,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				resourceType = TransferEnums.ResourceType.METAL,
				desiredAmount = 100,
				isCheatingEnabled = false,
				springRepo = spr,
				areAlliedTeams = true,
				ext = {},
				sender = {
					metal = { resourceType = "metal", excess = 0, current = 1000, storage = 1000, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 1000, storage = 1000, shareSlider = 0, sent = 0, received = 0 },
				},
				receiver = {
					metal = { resourceType = "metal", excess = 0, current = 500, storage = 1000, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 500, storage = 1000, shareSlider = 0, sent = 0, received = 0 },
				},
				policyResult = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0,
					taxedPortion = 100,
					senderTeamId = s.id,
					receiverTeamId = r.id,
				},
			}

			local result = ResourceTransferAction.execute(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
			assert.equal(900, (spr.GetTeamResources(s.id, TransferEnums.ResourceType.METAL)))
			assert.equal(600, (spr.GetTeamResources(r.id, TransferEnums.ResourceType.METAL)))
		end)

		it("should apply tax overhead to the sender cost", function()
			---@type ResourceTransferContext
			local ctx = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				resourceType = TransferEnums.ResourceType.METAL,
				desiredAmount = 200,
				isCheatingEnabled = false,
				springRepo = spring,
				areAlliedTeams = true,
				ext = {},
				sender = {
					metal = { resourceType = "metal", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
				receiver = {
					metal = { resourceType = "metal", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
				policyResult = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0.3,
					taxedPortion = 500,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransferAction.execute(ctx)

			assert.is_true(result.success)
			-- sent = 200/0.7 = 285.71
			assert.is_near(285.71, result.sent, 0.1)
			assert.is_near(200, result.received, 0.1)
		end)

		it("should handle 100% tax rate", function()
			---@type ResourceTransferContext
			local ctx = {
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				resourceType = TransferEnums.ResourceType.METAL,
				desiredAmount = 200,
				isCheatingEnabled = false,
				springRepo = spring,
				areAlliedTeams = true,
				ext = {},
				sender = {
					metal = { resourceType = "metal", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
				receiver = {
					metal = { resourceType = "metal", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
				policyResult = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 1.0,
					taxedPortion = 500,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransferAction.execute(ctx)

			assert.is_true(result.success)
			-- nothing is sendable at 100% tax (infinite cost)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)

		it("should limit transfer to amountSendable", function()
			--- @type ResourceTransferContext
			local ctx = {
				desiredAmount = 300,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				isCheatingEnabled = false,
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				resourceType = TransferEnums.ResourceType.METAL,
				ext = {},
				policyResult = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 300,
					amountReceivable = 9999,
					taxRate = 0.2,
					taxedPortion = 300,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
				springRepo = spring,
				areAlliedTeams = true,
				sender = {
					metal = { resourceType = "metal", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 1000, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
				receiver = {
					metal = { resourceType = "metal", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
					energy = { resourceType = "energy", excess = 0, current = 500, storage = 1000, pull = 0, income = 0, expense = 0, shareSlider = 0, sent = 0, received = 0 },
				},
			}

			local result = ResourceTransferAction.execute(ctx)

			assert.is_true(result.success)
			-- sent = 300/0.8 = 375
			assert.is_near(375, result.sent, 0.1)
			assert.is_near(300, result.received, 0.1)
		end)
	end)

	describe("CalculateSenderTaxedAmount helper", function()
		it("caps by amountSendable and amountReceivable and computes sender cost", function()
			local policyResult = {
				resourceType = TransferEnums.ResourceType.ENERGY,
				amountSendable = 820,
				amountReceivable = 1000,
				taxRate = 0.3,
			}

			local desired = 820
			local desiredCapped = math.min(desired, policyResult.amountSendable, policyResult.amountReceivable)
			local received, sent = ResourceShared.CalculateSenderTaxedAmount(policyResult, desiredCapped)
			-- cost = 820/0.7 = 1171.43
			assert.is_near(1171.43, sent, 0.01)
			assert.equal(820, received)
		end)

		it("caps desired by amountReceivable when it is lower", function()
			local policyResult = {
				resourceType = TransferEnums.ResourceType.ENERGY,
				amountSendable = 500,
				amountReceivable = 300,
				taxRate = 0.7,
			}
			local desiredCapped = math.min(999, policyResult.amountSendable, policyResult.amountReceivable)
			local received, sent = ResourceShared.CalculateSenderTaxedAmount(policyResult, desiredCapped)
			assert.equal(300, received)
			assert.is_near(1000, sent, 0.01) -- 300/(1-0.7)
		end)
	end)
end)

describe("Resource comms #comms", function()
	describe("DecideCommunicationCase", function()
		it("should return OnSelf when sender equals receiver", function()
			local policy = { senderTeamId = 1, receiverTeamId = 1, canShare = true, taxRate = 0.3 }
			assert.equal(TransferEnums.ResourceCommunicationCase.OnSelf, ResourceShared.DecideCommunicationCase(policy))
		end)

		it("should return OnTaxFree when tax rate is zero", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0 }
			assert.equal(TransferEnums.ResourceCommunicationCase.OnTaxFree, ResourceShared.DecideCommunicationCase(policy))
		end)

		it("should return OnTaxed when taxed", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0.3 }
			assert.equal(TransferEnums.ResourceCommunicationCase.OnTaxed, ResourceShared.DecideCommunicationCase(policy))
		end)

		it("should return OnDisabled when canShare is false", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = false, taxRate = 0 }
			assert.equal(TransferEnums.ResourceCommunicationCase.OnDisabled, ResourceShared.DecideCommunicationCase(policy))
		end)
	end)

	describe("FormatNumberForUI", function()
		it("should floor numbers to whole values", function()
			assert.equal("285", ResourceShared.FormatNumberForUI(285.71))
			assert.equal("100", ResourceShared.FormatNumberForUI(100.99))
			assert.equal("0", ResourceShared.FormatNumberForUI(0.5))
		end)

		it("should pass through non-number values", function()
			assert.equal("hello", ResourceShared.FormatNumberForUI("hello"))
		end)
	end)
end)
