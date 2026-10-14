---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")
local TransferEnums = require("modules/transfer/enums")
local ResourceTransfer, ResourceShared
local function reloadTransfer()
	ResourceShared = require("modules/transfer/resource/shared")
	ResourceTransfer = require("modules/transfer/resource/synced")
end
reloadTransfer()

describe("ResourceTransfer #action", function()
	local sender = Builders.Team:new():Human()
	local receiver = Builders.Team:new():Human()
	local spring = Builders.Spring.new():WithTeam(sender):WithTeam(receiver):Build()

	describe("basic resource transfer", function()
		it("should transfer metal without overhead when the tax rate is zero", function()
			---@type TransferResourceRequest
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
				terms = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransfer.Transfer(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
		end)

		it("debits the sender and credits the receiver in engine team state", function()
			local s = Builders.Team:new():Human():WithMetal(1000):WithMetalStorage(1000)
			local r = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000)
			local spr = Builders.Spring.new():WithTeam(s):WithTeam(r):Build()

			---@type TransferResourceRequest
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
				terms = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0,
					senderTeamId = s.id,
					receiverTeamId = r.id,
				},
			}

			local result = ResourceTransfer.Transfer(ctx)

			assert.is_true(result.success)
			assert.equal(100, result.sent)
			assert.equal(100, result.received)
			assert.equal(900, (spr.GetTeamResources(s.id, TransferEnums.ResourceType.METAL)))
			assert.equal(600, (spr.GetTeamResources(r.id, TransferEnums.ResourceType.METAL)))
		end)

		it("should apply tax overhead to the sender cost", function()
			---@type TransferResourceRequest
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
				terms = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 0.3,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransfer.Transfer(ctx)

			assert.is_true(result.success)
			assert.is_near(285.71, result.sent, 0.1)
			assert.is_near(200, result.received, 0.1)
		end)

		it("should handle 100% tax rate", function()
			---@type TransferResourceRequest
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
				terms = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 500,
					amountReceivable = 500,
					taxRate = 1.0,
					senderTeamId = sender.id,
					receiverTeamId = receiver.id,
				},
			}

			local result = ResourceTransfer.Transfer(ctx)

			assert.is_true(result.success)
			assert.equal(0, result.sent)
			assert.equal(0, result.received)
		end)

		it("should limit transfer to amountSendable", function()
			local ctx = {
				desiredAmount = 300,
				policyType = TransferEnums.PolicyType.MetalTransfer,
				isCheatingEnabled = false,
				senderTeamId = sender.id,
				receiverTeamId = receiver.id,
				resourceType = TransferEnums.ResourceType.METAL,
				ext = {},
				terms = {
					canShare = true,
					resourceType = TransferEnums.ResourceType.METAL,
					amountSendable = 300,
					amountReceivable = 9999,
					taxRate = 0.2,
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

			local result = ResourceTransfer.Transfer(ctx)

			assert.is_true(result.success)
			assert.is_near(375, result.sent, 0.1)
			assert.is_near(300, result.received, 0.1)
		end)
	end)

	describe("CalculateSenderTaxedAmount helper", function()
		it("caps by amountSendable and amountReceivable and computes sender cost", function()
			local terms = {
				resourceType = TransferEnums.ResourceType.ENERGY,
				amountSendable = 820,
				amountReceivable = 1000,
				taxRate = 0.3,
			}

			local desired = 820
			local desiredCapped = math.min(desired, terms.amountSendable, terms.amountReceivable)
			local received, sent = ResourceShared.CalculateSenderTaxedAmount(terms, desiredCapped)
			assert.is_near(1171.43, sent, 0.01)
			assert.equal(820, received)
		end)

		it("caps desired by amountReceivable when it is lower", function()
			local terms = {
				resourceType = TransferEnums.ResourceType.ENERGY,
				amountSendable = 500,
				amountReceivable = 300,
				taxRate = 0.7,
			}
			local desiredCapped = math.min(999, terms.amountSendable, terms.amountReceivable)
			local received, sent = ResourceShared.CalculateSenderTaxedAmount(terms, desiredCapped)
			assert.equal(300, received)
			assert.is_near(1000, sent, 0.01)
		end)
	end)
end)

local METAL = TransferEnums.ResourceType.METAL

-- The terms are one evaluation of the policy, on whichever handle asks: the gates are the policy's, the amounts this
-- moment's, the rate the pairing's.
describe("the terms, evaluated where they are asked #policy", function()
	local sender, receiver, enemy ---@type TeamBuilder, TeamBuilder, TeamBuilder
	local spring ---@type SpringSyncedBuilder

	before_each(function()
		reloadTransfer()
		sender = Builders.Team:new():Human():WithMetal(500):WithMetalStorage(1000):WithEnergy(500)
		receiver = Builders.Team:new():Human():WithMetal(0):WithMetalStorage(1000):WithEnergy(0)
		enemy = Builders.Team:new():Human():WithMetal(0):WithMetalStorage(1000):WithEnergy(0)
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

	---@param a integer
	---@param b integer
	---@param api table? a built mock; a fresh build when nil
	---@return ResourceTransferTerms
	local function termsFor(a, b, api)
		return ResourceShared.Terms(a, b, METAL, api or spring:Build())
	end

	it("allows an allied pair, with this moment's cap", function()
		local terms = termsFor(sender.id, receiver.id)
		assert.is_true(terms.canShare)
		assert.equal(500, terms.amountSendable)
		assert.equal(1000, terms.amountReceivable)
		assert.equal(sender.id, terms.senderTeamId)
		assert.equal(receiver.id, terms.receiverTeamId)
		assert.equal(METAL, terms.resourceType)
	end)

	it("refuses a cross-alliance pair", function()
		assert.is_false(termsFor(sender.id, enemy.id).canShare)
	end)

	it("refuses when the receiver has no active players", function()
		spring:WithTeamRulesParam(receiver.id, "numActivePlayers", 0)
		assert.is_false(termsFor(sender.id, receiver.id).canShare)
	end)

	it("allows a cross-alliance pair when cheating is enabled", function()
		local api = spring:Build()
		api.IsCheatingEnabled = function()
			return true
		end
		assert.is_true(termsFor(sender.id, enemy.id, api).canShare)
	end)

	it("refuses every pair when resource sharing is disabled", function()
		spring:WithModOption(TransferEnums.ModOptions.ResourceSharingEnabled, false)
		assert.is_false(termsFor(sender.id, receiver.id).canShare)
	end)

	it("reads the frame's balances: the same frame answers the same, the next frame reads again", function()
		local api = spring:Build()
		local frame = 10
		api.GetGameFrame = function()
			return frame
		end
		local first = termsFor(sender.id, receiver.id, api)
		assert.equal(500, first.amountSendable)
		api.SetTeamResource(sender.id, METAL, 100)
		assert.equal(first, termsFor(sender.id, receiver.id, api), "the frame's answer is kept")
		frame = 11
		assert.equal(100, termsFor(sender.id, receiver.id, api).amountSendable)
	end)

	it("taxes at the pairing's rate", function()
		spring:WithModOption(TransferEnums.ModOptions.TaxResourceSharingAmount, 0.5)
		local terms = termsFor(sender.id, receiver.id)
		assert.equal(0.5, terms.taxRate)
		assert.equal(250, terms.amountSendable)
	end)
end)
