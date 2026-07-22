local SharedConfig = VFS.Include("modules/sharing/economy/shared_config.lua")
local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local Comms = VFS.Include("modules/sharing/resource/comms.lua")
local Shared = VFS.Include("modules/sharing/resource/shared.lua")
local WaterfillSolver = VFS.Include("modules/sharing/economy/waterfill_solver.lua")
local PolicyEvents = VFS.Include("modules/sharing/policy_events.lua")

local ResourceType = TransferEnums.ResourceType
local METAL = ResourceType.METAL
local ENERGY = ResourceType.ENERGY

local Gadgets = {
	SendTransferChatMessages = Comms.SendTransferChatMessages,
}

local function isNonPlayerTeam(springRepo, teamId)
	if teamId == springRepo.GetGaiaTeamID() then
		return true
	end
	local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
	if isAiTeam then
		return true
	end
	-- Spring.GetTeamLuaAI returns "" (not nil) for teams without a LuaAI, so guard both.
	local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
	return luaAI ~= nil and luaAI ~= ""
end

-- Encapsulate legacy AllowResourceTransfer gate rules
---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult|nil
local function TryDenyPolicy(ctx, resourceType)
	if not SharedConfig.isResourceSharingEnabled(ctx.springRepo) then
		return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
	end

	if ctx.isCheatingEnabled then
		return nil
	end

	if not ctx.areAlliedTeams and not isNonPlayerTeam(ctx.springRepo, ctx.senderTeamId) then
		return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
	end

	local numActivePlayers = ctx.springRepo.GetTeamRulesParam(ctx.receiverTeamId, "numActivePlayers")
	if numActivePlayers ~= nil and tonumber(numActivePlayers) == 0 then
		return Shared.CreateDenyPolicy(ctx.senderTeamId, ctx.receiverTeamId, resourceType, ctx.springRepo)
	end
	return nil
end

--- Execute a resource transfer using received-unit desiredAmount capped by policy limits
---@param ctx ResourceTransferContext
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

---resolve a context's effective resource tax rate in [0,1] (sender tech tax, else base)
---@param ctx PolicyContext
---@return number
local function resolveEffectiveRate(ctx)
	local taxRate = (ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)) --[[@as number]]
	return math.min(taxRate, 1)
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function Gadgets.CalcResourcePolicy(ctx, resourceType)
	local rejected = TryDenyPolicy(ctx, resourceType)
	if rejected then
		return rejected
	end

	local effectiveRate = resolveEffectiveRate(ctx)

	local senderData, receiverData
	if resourceType == METAL then
		senderData = ctx.sender.metal
		receiverData = ctx.receiver.metal
	else
		senderData = ctx.sender.energy
		receiverData = ctx.receiver.energy
	end

	local taxedSendable = math.max(0, senderData.current) * (1 - effectiveRate)
	local capacity = receiverData.storage - receiverData.current

	local result = policyResultPool[resourceType]
	if not result then
		result = {} --[[@as ResourcePolicyResult]] -- filled by CombineResourcePolicy below
		policyResultPool[resourceType] = result
	end

	Shared.CombineResourcePolicy(taxedSendable, effectiveRate, capacity, ctx.senderTeamId, ctx.receiverTeamId, resourceType, result)
	result.techBlocking = ctx.ext and ctx.ext.techBlocking or nil

	return result
end

---@param springRepo EngineSynced
---@param teamId integer
---@return boolean
local function teamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---Compute and cache one team's resource factor record for a single resource.
---@param springRepo EngineSynced
---@param teamId integer
---@param resourceType ResourceName
---@param ctx PolicyContext self-context (sender==receiver==teamId) so the enricher resolves the team's tax
function Gadgets.CacheTeamFactor(springRepo, teamId, resourceType, ctx)
	local data = (resourceType == METAL) and ctx.sender.metal or ctx.sender.energy
	local effectiveRate = resolveEffectiveRate(ctx)
	local isNonPlayer = isNonPlayerTeam(springRepo, teamId)
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
	local category = (resourceType == METAL) and TransferEnums.PolicyType.MetalTransfer or TransferEnums.PolicyType.EnergyTransfer
	PolicyEvents.NotifyIfChanged(teamId, category, signature)
end

---refresh the per-team resource factor cache (O(teams), factors are independent); pairs reconstructed on read
---@param springRepo EngineSynced
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

---@param springRepo EngineSynced
---@param teamsList TeamResourceData[]
function Gadgets.WaterfillSolve(springRepo, teamsList)
	return WaterfillSolver.Solve(springRepo, teamsList)
end

return Gadgets
