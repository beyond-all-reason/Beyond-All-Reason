local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local PolicyEvents = VFS.Include("modules/transfer/lib/policy_events.lua")
local Comms = VFS.Include("modules/transfer/resource/comms.lua")
local Shared = VFS.Include("modules/transfer/resource/shared.lua")

local ResourceType = TransferEnums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local Gadgets = {
	SendTransferChatMessages = Comms.SendTransferChatMessages,
}

---@param ctx ResourceTransferRequest
---@return ResourceTransferResult
function Gadgets.ResourceTransfer(ctx)
	local policyResult = ctx.policyResult
	local desiredAmount = ctx.desiredAmount
	if (not policyResult or not policyResult.canShare) or (not desiredAmount or desiredAmount <= 0) then
		---@type ResourceTransferResult
		return {
			success = false,
			sent = 0,
			received = 0,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			policyResult = policyResult,
		}
	end

	local received, sent = Shared.CalculateSenderTaxedAmount(policyResult, desiredAmount)

	local springRepo = ctx.springRepo
	local resourceType = policyResult.resourceType
	-- deduct via SetTeamResource; AddTeamResource clamps its amount to >= 0
	local senderCurrent = springRepo.GetTeamResources(ctx.senderTeamId, resourceType) or 0
	springRepo.SetTeamResource(ctx.senderTeamId, resourceType, math.max(0, senderCurrent - sent))
	springRepo.AddTeamResource(ctx.receiverTeamId, resourceType, received)

	---@type ResourceTransferResult
	local result = {
		success = true,
		sent = sent,
		received = received,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		policyResult = policyResult,
	}

	return result
end

local policyResultPool = {} ---@type table<ResourceName, ResourcePolicyResult>

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return number
local function resolveEffectiveRate(ctx, resourceType)
	local perResource = ctx.taxRates and ctx.taxRates[resourceType]
	local taxRate = (perResource or ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)) --[[@as number]]
	return math.min(taxRate, 1)
end

---@param ctx TransferPolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function Gadgets.CalcResourcePolicy(ctx, resourceType)
	-- runs per resource per tick; the pool is why it does not allocate
	local result = policyResultPool[resourceType]
	if not result then
		result = {} --[[@as ResourcePolicyResult]]
		policyResultPool[resourceType] = result
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Transfer) ---@type TransferPipelines
	local pipeline = pipelines.resource_transfer
	return ModuleHandler.Evaluate(pipeline, ctx, resourceType, resolveEffectiveRate(ctx, resourceType), result)
end

---@param springRepo Spring
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---@param springRepo Spring
---@param teamId integer
---@param resourceType ResourceName
---@param ctx TransferPolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
	local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
	local effectiveRate = resolveEffectiveRate(ctx, resourceType)
	local isNonPlayer = Shared.IsNonPlayerTeam(springRepo, teamId)
	local active = teamActive(springRepo, teamId)
	local factor = {
		taxedSendable = math.max(0, data.current) * (1 - effectiveRate),
		taxRate = effectiveRate,
		capacity = data.storage - data.current,
		isNonPlayer = isNonPlayer,
		active = active,
	}
	springRepo.SetTeamRulesParam(teamId, Shared.MakeFactorKey(resourceType), Shared.SerializeResourceFactor(factor))
	-- Policy fields only; live amounts (taxedSendable/capacity) would fire every economy tick.
	local signature = string.format("%s|%s|%s", tostring(effectiveRate), tostring(active), tostring(isNonPlayer))
	local category = (resourceType == METAL) and TransferEnums.PolicyType.MetalTransfer
		or TransferEnums.PolicyType.EnergyTransfer
	PolicyEvents.NotifyIfChanged(teamId, category, signature)
end

---@param springRepo Spring
---@param frame number
---@param lastUpdate number
---@param updateRate number
---@param contextFactory table
---@return number lastUpdate New last update frame
function Gadgets.UpdatePolicyCache(springRepo, frame, lastUpdate, updateRate, contextFactory)
	if frame < lastUpdate + updateRate then
		return lastUpdate
	end

	contextFactory.clearResourceCache()

	local allTeams = springRepo.GetTeamList()
	for _, teamId in ipairs(allTeams) do
		local ctx = contextFactory.policy(teamId, teamId)
		Gadgets.CacheTeamFactor(springRepo, teamId, METAL, ctx)
		Gadgets.CacheTeamFactor(springRepo, teamId, ENERGY, ctx)
	end

	return frame
end

return Gadgets
