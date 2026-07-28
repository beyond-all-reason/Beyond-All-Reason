local Economy = require("modules/economy/api")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

---@class TransferResourceRequest : TransferRequest
---@field resourceType ResourceName
---@field desiredAmount number
---@field policyResult ResourceTransferTerms

---@class ContextFactory
---@field create fun(springRepo: Spring): ContextFactory
---@field policy fun(senderTeamID: integer, receiverTeamID: integer): TransferContext
---@field request fun(senderTeamId: integer, receiverTeamId: integer, policyType: string): TransferRequest
---@field resourceTransfer fun(senderTeamId: integer, receiverTeamId: integer, resourceType: ResourceName, desiredAmount: number, policyResult: ResourceTransferTerms): TransferResourceRequest
local ContextFactory = {}

---@param springRepo Spring
---@param enrichers PolicyProvision[]|nil a test seam; the discovered enrichments when nil
---@return table Context factory with closures
function ContextFactory.create(springRepo, enrichers)
	local modOptions = springRepo.GetModOptions()
	local resourceCache = {}

	local function getResource(teamID, resourceType)
		local perTeam = resourceCache[teamID]
		if not perTeam then
			perTeam = {}
			resourceCache[teamID] = perTeam
		end
		local data = perTeam[resourceType]
		if not data then
			data = Economy.Resources.Snapshot(springRepo, teamID, resourceType)
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
	---@return TransferContext
	local function buildContext(senderTeamID, receiverTeamID, extensions)
		---@type TransferContract
		local Transfer = ModuleHandler.Contract(Modules.Transfer)
		---@type TransferTeamResources
		local senderResources = {
			metal = getResource(senderTeamID, TransferEnums.ResourceType.METAL),
			energy = getResource(senderTeamID, TransferEnums.ResourceType.ENERGY),
		}

		---@type TransferTeamResources
		local receiverResources = {
			metal = getResource(receiverTeamID, TransferEnums.ResourceType.METAL),
			energy = getResource(receiverTeamID, TransferEnums.ResourceType.ENERGY),
		}

		---@type TransferContext
		local ctx = {
			senderTeamId = senderTeamID,
			receiverTeamId = receiverTeamID,
			sender = senderResources,
			receiver = receiverResources,
			springRepo = springRepo,
			modOptions = modOptions,
			areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID) == true,
			isCheatingEnabled = springRepo.IsCheatingEnabled(),
		}

		local resolved = enrichers or ModuleHandler.LoadEnrichers(Transfer.TeamPairing)
		local live = nil
		if not enrichers then
			live = ModuleHandler.LiveModulesFor(modOptions)
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
	---@return TransferContext
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
	---@param policyResult ResourceTransferTerms
	---@return TransferResourceRequest
	local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
		local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer
			or TransferEnums.PolicyType.EnergyTransfer
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = policyType,
			resourceType = resourceType,
			desiredAmount = desiredAmount,
			policyResult = policyResult,
		}) --[[@as TransferResourceRequest]]
	end

	return {
		policy = policy,
		request = request,
		resourceTransfer = resourceTransfer,
		clearResourceCache = clearResourceCache,
	}
end

return ContextFactory
