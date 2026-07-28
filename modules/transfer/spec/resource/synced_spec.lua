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

describe("ResourceTransfer #action", function()
	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()
	local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):Build()

	describe("basic resource transfer", function()
		it("should transfer metal without overhead when the tax rate is zero", function()
			---@type ResourceTransferRequest
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

			local result = ResourceTransfer.ResourceTransfer(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
		end)

		it("debits the sender and credits the receiver in engine team state", function()
			local s = Builders.Team:new():Human():WithMetal(1000):WithMetalStorage(1000)
			local r = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000)
			local spr = Builders.Spring.new():WithTeam(s):WithTeam(r):Build()

			---@type ResourceTransferRequest
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
					metal = {
						resourceType = "metal",
						excess = 0,
						current = 1000,
						storage = 1000,
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
					energy = {
						resourceType = "energy",
						excess = 0,
						current = 1000,
						storage = 1000,
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
						shareSlider = 0,
						sent = 0,
						received = 0,
					},
					energy = {
						resourceType = "energy",
						excess = 0,
						current = 500,
						storage = 1000,
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
					taxedPortion = 100,
					senderTeamId = s.id,
					receiverTeamId = r.id,
				},
			}

			local result = ResourceTransfer.ResourceTransfer(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
			assert.equal(900, (spr.GetTeamResources(s.id, TransferEnums.ResourceType.METAL)))
			assert.equal(600, (spr.GetTeamResources(r.id, TransferEnums.ResourceType.METAL)))
		end)

		it("should apply tax overhead to the sender cost", function()
			---@type ResourceTransferRequest
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
					taxRate = 0.3,
					taxedPortion = 500,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransfer.ResourceTransfer(ctx)

			assert.is_true(result.success)
			assert.is_near(285.71, result.sent, 0.1)
			assert.is_near(200, result.received, 0.1)
		end)

		it("should handle 100% tax rate", function()
			---@type ResourceTransferRequest
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
					taxRate = 1.0,
					taxedPortion = 500,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransfer.ResourceTransfer(ctx)

			assert.is_true(result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)

		it("should limit transfer to amountSendable", function()
			--- @type ResourceTransferRequest
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
			}

			local result = ResourceTransfer.ResourceTransfer(ctx)

			assert.is_true(result.success)
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
			assert.is_near(1000, sent, 0.01)
		end)
	end)
end)

-- The per-team factor cache the controller refreshes and the transfer reads.
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

local METAL = TransferEnums.ResourceType.METAL

describe("resource policy cache (per-team factors) #policy", function()
	local sender, receiver, enemy ---@type TeamBuilder, TeamBuilder, TeamBuilder
	local spring ---@type SpringSyncedBuilder

	before_each(function()
		reloadTransfer()
		sender = Builders.Team:new():Human():WithMetal(500):WithEnergy(500)
		receiver = Builders.Team:new():Human():WithMetal(0):WithEnergy(0)
		enemy = Builders.Team:new():Human():WithMetal(0):WithEnergy(0)
		spring = Builders.Spring
			.new()
			:WithTeam(sender)
			:WithTeam(receiver)
			:WithTeam(enemy)
			:WithAlliance(sender.id, receiver.id, true)
			:WithAlliance(receiver.id, sender.id, true)
			:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, 0)
			:WithTeamRulesParam(sender.id, "numActivePlayers", 1)
			:WithTeamRulesParam(receiver.id, "numActivePlayers", 1)
			:WithTeamRulesParam(enemy.id, "numActivePlayers", 1)
	end)

	local function populate()
		local springApi = spring:Build()
		local contextFactory = ContextFactoryModule.create(springApi)
		ResourceTransfer.UpdatePolicyCache(springApi, 1000, -1000, 30, contextFactory)
		return springApi, contextFactory
	end

	it("reconstructs an allied pair identically to a direct CalcResourcePolicy", function()
		local springApi, contextFactory = populate()
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, METAL, springApi)
		local direct = ResourceTransfer.CalcResourcePolicy(contextFactory.policy(sender.id, receiver.id), METAL)
		assert.equal(direct.canShare, cached.canShare)
		assert.equal(direct.amountSendable, cached.amountSendable)
		assert.equal(direct.amountReceivable, cached.amountReceivable)
		assert.equal(direct.taxedPortion, cached.taxedPortion)
		assert.equal(direct.taxRate, cached.taxRate)
	end)

	it("stores per-team factor records, not per-pair entries", function()
		local springApi = populate()
		local metalKey = ResourceShared.MakeFactorKey(METAL)
		assert.is_not_nil(springApi.GetTeamRulesParam(sender.id, metalKey))
		assert.is_not_nil(springApi.GetTeamRulesParam(receiver.id, metalKey))
		assert.is_not_nil(springApi.GetTeamRulesParam(enemy.id, metalKey))
	end)

	it("denies a cross-alliance pair via the live gate (no cached deny entry)", function()
		local springApi = populate()
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, enemy.id, METAL, springApi)
		assert.equal(false, cached.canShare)
	end)

	it("denies when the receiver has no active players", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		local springApi = populate()
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, METAL, springApi)
		assert.equal(false, cached.canShare)
	end)

	it("allows a cross-alliance pair when cheating is enabled", function()
		local springApi = populate()
		springApi.IsCheatingEnabled = function()
			return true
		end
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, enemy.id, METAL, springApi)
		assert.equal(true, cached.canShare)
	end)

	it("denies when factors are absent (cache not yet populated)", function()
		local springApi = spring:Build()
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, METAL, springApi)
		assert.equal(false, cached.canShare)
	end)

	it("denies every pair when resource sharing is disabled", function()
		spring:WithModOption(TransferEnums.ModOptions.ResourceSharingEnabled, false)
		local springApi = populate()
		local cached = ResourceShared.GetCachedPolicyResult(sender.id, receiver.id, METAL, springApi)
		assert.equal(false, cached.canShare)
	end)
end)
