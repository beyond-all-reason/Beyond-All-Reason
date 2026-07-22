local TransferEnums = VFS.Include("common/luaUtilities/sharing/transfer_enums.lua")
local TeamResourceData = VFS.Include("common/luaUtilities/sharing/team_resource_data.lua")

---@alias PolicyContextEnricher fun(ctx: PolicyContext, springRepo: EngineSynced, senderTeamID: integer, receiverTeamID: integer)

---@class ContextFactory
---@field create fun(springRepo: EngineSynced): ContextFactory
---@field registerPolicyContextEnricher fun(fn: PolicyContextEnricher)
---@field policy fun(senderTeamID: integer, receiverTeamID: integer): PolicyContext
---@field action fun(senderTeamId: integer, receiverTeamId: integer, policyType: string): PolicyActionContext
---@field resourceTransfer fun(senderTeamId: integer, receiverTeamId: integer, resourceType: ResourceName, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field unitTransfer fun(senderTeamId: integer, receiverTeamId: integer, unitIds: integer[], given: boolean, policyResult: UnitPolicyResult, unitValidationResult: UnitValidationResult): UnitTransferContext
local ContextFactory = {}

-- shared via GG because VFS.Include re-runs per call; a module-local list would split registrar and consumer into separate registries
GG = GG or {}
GG.policyContextEnrichers = GG.policyContextEnrichers or {}
---@type PolicyContextEnricher[]
local enrichers = GG.policyContextEnrichers

---@param fn PolicyContextEnricher
function ContextFactory.registerPolicyContextEnricher(fn)
	enrichers[#enrichers + 1] = fn
end

function ContextFactory.getEnrichers()
	local copy = {}
	for i = 1, #enrichers do
		copy[i] = enrichers[i]
	end
	return copy
end

-- mutate in place so the shared reference (and create()'s closures) stay valid
function ContextFactory.setEnrichers(list)
	for i = #enrichers, 1, -1 do
		enrichers[i] = nil
	end
	if list then
		for i = 1, #list do
			enrichers[i] = list[i]
		end
	end
end

---@param springRepo EngineSynced
---@return table Context factory with closures
function ContextFactory.create(springRepo)
	-- per-snapshot resource memo so a refresh pass reads each team once, not once per pair; caller clears it at pass start
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
	---@return PolicyContext
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

		---@type PolicyContext
		local ctx = {
			senderTeamId = senderTeamID,
			receiverTeamId = receiverTeamID,
			sender = senderResources,
			receiver = receiverResources,
			springRepo = springRepo,
			areAlliedTeams = springRepo.AreTeamsAllied(senderTeamID, receiverTeamID) == true,
			isCheatingEnabled = springRepo.IsCheatingEnabled(),
			ext = {},
		}

		for _, enricher in ipairs(enrichers) do
			enricher(ctx, springRepo, senderTeamID, receiverTeamID)
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
	---@return PolicyContext
	local function policy(senderTeamID, receiverTeamID, commandType)
		return buildContext(senderTeamID, receiverTeamID, {
			commandType = commandType,
		})
	end

	---@param policyType string
	---@param senderTeamId integer
	---@param receiverTeamId integer
	---@return PolicyActionContext
	local function policyAction(senderTeamId, receiverTeamId, policyType)
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = policyType,
		}) --[[@as PolicyActionContext]]
	end

	---@param senderTeamId integer
	---@param receiverTeamId integer
	---@param resourceType ResourceName
	---@param desiredAmount number
	---@param policyResult ResourcePolicyResult
	---@return ResourceTransferContext
	local function resourceTransfer(senderTeamId, receiverTeamId, resourceType, desiredAmount, policyResult)
		local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer or TransferEnums.PolicyType.EnergyTransfer
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = policyType,
			resourceType = resourceType,
			desiredAmount = desiredAmount,
			policyResult = policyResult,
		}) --[[@as ResourceTransferContext]]
	end

	---@param senderTeamId integer
	---@param receiverTeamId integer
	---@param unitIds integer[]
	---@param given boolean?
	---@param policyResult UnitPolicyResult
	---@param validationResult UnitValidationResult
	---@return UnitTransferContext
	local function unitTransfer(senderTeamId, receiverTeamId, unitIds, given, policyResult, validationResult)
		return buildContext(senderTeamId, receiverTeamId, {
			policyType = TransferEnums.PolicyType.UnitTransfer,
			unitIds = unitIds,
			given = given,
			policyResult = policyResult,
			validationResult = validationResult,
		}) --[[@as UnitTransferContext]]
	end

	return {
		policy = policy,
		action = policyAction,
		resourceTransfer = resourceTransfer,
		unitTransfer = unitTransfer,
		clearResourceCache = clearResourceCache,
	}
end

return ContextFactory
