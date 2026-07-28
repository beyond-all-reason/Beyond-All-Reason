local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local TeamResourceData = VFS.Include("modules/economy/lib/team_resource_data.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract

---@class ContextFactory
---@field create fun(springRepo: Spring): ContextFactory
---@field policy fun(senderTeamID: integer, receiverTeamID: integer): TransferPolicyContext
---@field request fun(senderTeamId: integer, receiverTeamId: integer, policyType: string): TransferRequest
---@field resourceTransfer fun(senderTeamId: integer, receiverTeamId: integer, resourceType: ResourceName, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferRequest
local ContextFactory = {}

---@param springRepo Spring
---@param enrichers PolicyProvision[]|nil a test seam; the discovered enrichments when nil
---@return table Context factory with closures
function ContextFactory.create(springRepo, enrichers)
	-- memoized so a refresh pass reads each team once, not once per pair
	local resourceCache = {}

	local function getResource(teamID, resourceType)
		local perTeam = resourceCache[teamID]
		if not perTeam then
			perTeam = {}
			resourceCache[teamID] = perTeam
		end
		local data = perTeam[resourceType]
		if not data then
			data = TeamResourceData.Get(springRepo, teamID, resourceType)
			perTeam[resourceType] = data
		end
		return data
	end

	local function clearResourceCache()
		resourceCache = {}
	end

	---@param senderTeamID integer
	---@param receiverTeamID integer
	---@param extensions? table
	---@return TransferPolicyContext
	local function buildContext(senderTeamID, receiverTeamID, extensions)
		---@type TeamResources
		local senderResources = {
			metal = getResource(senderTeamID, TransferEnums.ResourceType.METAL),
			energy = getResource(senderTeamID, TransferEnums.ResourceType.ENERGY),
		}

		---@type TeamResources
		local receiverResources = {
			metal = getResource(receiverTeamID, TransferEnums.ResourceType.METAL),
			energy = getResource(receiverTeamID, TransferEnums.ResourceType.ENERGY),
		}

		---@type TransferPolicyContext
		local ctx = {
			senderTeamId = senderTeamID,
			receiverTeamId = receiverTeamID,
			sender = senderResources,
			receiver = receiverResources,
			springRepo = springRepo,
			areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID) == true,
			isCheatingEnabled = springRepo.IsCheatingEnabled(),
		}

		-- the live providers under the game's modes answer; the Defaults fill the rest
		local resolved = enrichers or ModuleHandler.LoadEnrichers(Contract.TeamPairing)
		local live = nil -- an injected list is the test seam: every entry live
		if not enrichers then
			live = ModuleHandler.LiveModulesFor(springRepo.GetModOptions())
		end
		for field, value in
			pairs(ModuleHandler.EnrichWith(resolved, live, ctx, springRepo, senderTeamID, receiverTeamID))
		do
			ctx[field] = value
		end

		if extensions then
			for k, v in pairs(extensions) do
				ctx[k] = v
			end
		end

		return ctx
	end

	---@param senderTeamID integer
	---@param receiverTeamID integer
	---@param commandType? string
	---@return TransferPolicyContext
	local function policy(senderTeamID, receiverTeamID, commandType)
		return buildContext(senderTeamID, receiverTeamID, {
			commandType = commandType,
		})
	end

	---@param policyType string
	---@param senderTeamId integer
	---@param receiverTeamId integer
	---@return TransferRequest
	local function request(senderTeamId, receiverTeamId, policyType)
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = policyType,
		}) --[[@as TransferRequest]]
	end

	---@param senderTeamId integer
	---@param receiverTeamId integer
	---@param resourceType ResourceName
	---@param desiredAmount number
	---@param policyResult ResourcePolicyResult
	---@return ResourceTransferRequest
	local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
		local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer
			or TransferEnums.PolicyType.EnergyTransfer
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = policyType,
			resourceType = resourceType,
			desiredAmount = desiredAmount,
			policyResult = policyResult,
		}) --[[@as ResourceTransferRequest]]
	end

	return {
		policy = policy,
		request = request,
		resourceTransfer = resourceTransfer,
		clearResourceCache = clearResourceCache,
	}
end

return ContextFactory
