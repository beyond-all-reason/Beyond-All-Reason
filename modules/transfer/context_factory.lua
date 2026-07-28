local TransferEnums = VFS.Include("modules/context/enums.lua")
local TeamResourceData = VFS.Include("modules/context/team_resource_data.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class ContextFactory
---@field create fun(springRepo: Spring): ContextFactory
---@field policy fun(senderTeamID: integer, receiverTeamID: integer): TransferPolicyContext
---@field action fun(senderTeamId: integer, receiverTeamId: integer, policyType: string): PolicyActionContext
---@field resourceTransfer fun(senderTeamId: integer, receiverTeamId: integer, resourceType: ResourceName, desiredAmount: number, policyResult: ResourcePolicyResult): ResourceTransferContext
---@field unitTransfer fun(senderTeamId: integer, receiverTeamId: integer, unitIds: integer[], given: boolean, policyResult: UnitPolicyResult, unitValidationResult: UnitValidationResult): UnitTransferContext
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

		for _, provision in ipairs(enrichers or ModuleHandler.LoadEnrichers("transfer", "team_pairing")) do
			local results = { provision.evaluate(ctx, springRepo, senderTeamID, receiverTeamID) }
			for i, field in ipairs(provision.names) do
				ctx[field] = results[i]
			end
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
		local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer
			or TransferEnums.PolicyType.EnergyTransfer
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
