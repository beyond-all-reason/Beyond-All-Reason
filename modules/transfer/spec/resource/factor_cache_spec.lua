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
