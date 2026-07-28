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

describe("Resource comms #comms", function()
	describe("DecideCommunicationCase", function()
		it("should return OnSelf when sender equals receiver", function()
			local policy = { senderTeamId = 1, receiverTeamId = 1, canShare = true, taxRate = 0.3 }
			assert.equal(TransferEnums.ResourceCommunicationCase.OnSelf, ResourceShared.DecideCommunicationCase(policy))
		end)

		it("should return OnTaxFree when tax rate is zero", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0 }
			assert.equal(
				TransferEnums.ResourceCommunicationCase.OnTaxFree,
				ResourceShared.DecideCommunicationCase(policy)
			)
		end)

		it("should return OnTaxed when taxed", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = true, taxRate = 0.3 }
			assert.equal(
				TransferEnums.ResourceCommunicationCase.OnTaxed,
				ResourceShared.DecideCommunicationCase(policy)
			)
		end)

		it("should return OnDisabled when canShare is false", function()
			local policy = { senderTeamId = 1, receiverTeamId = 2, canShare = false, taxRate = 0 }
			assert.equal(
				TransferEnums.ResourceCommunicationCase.OnDisabled,
				ResourceShared.DecideCommunicationCase(policy)
			)
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
