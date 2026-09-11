local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Published = VFS.Include("modules/published.lua")
local Comms = VFS.Include("modules/transfer/resource/comms.lua")
local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")

local Shared = Comms

local factorFields = {
	taxedSendable = Published.Number,
	taxRate = Published.Number,
	capacity = Published.Number,
	isNonPlayer = Published.Boolean,
	active = Published.Boolean,
}

local factors = {
	[TransferEnums.ResourceType.METAL] = Published.PerTeam(
		TransferEnums.PolicyType.MetalTransfer .. "_factor",
		factorFields
	),
	[TransferEnums.ResourceType.ENERGY] = Published.PerTeam(
		TransferEnums.PolicyType.EnergyTransfer .. "_factor",
		factorFields
	),
}

---@param resourceType ResourceName
---@return PublishedRecord
function Shared.ResourceFactor(resourceType)
	return factors[resourceType] or factors[TransferEnums.ResourceType.ENERGY]
end

---@param resourceType ResourceName
---@param springRepo Spring
---@param teamId integer
---@return boolean
function Shared.IsNonPlayerTeam(springRepo, teamId)
	if teamId == springRepo.GetGaiaTeamID() then
		return true
	end
	local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
	if isAiTeam then
		return true
	end
	local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
	return luaAI ~= nil and luaAI ~= ""
end

---@param resourceType ResourceName
---@return string the team rules param the resource's record lives on
function Shared.MakeFactorKey(resourceType)
	return Shared.ResourceFactor(resourceType).key
end

---@param taxedSendable number sender factor
---@param taxRate number sender factor
---@param capacity number receiver factor
---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param result table? optional reusable result table
---@return ResourcePolicyResult
function Shared.CombineResourcePolicy(
	taxedSendable,
	taxRate,
	capacity,
	senderTeamId,
	receiverTeamId,
	resourceType,
	result
)
	result = result or {}
	local taxedPortion = math.min(taxedSendable, capacity)
	local amountSendable = taxedPortion
	result.senderTeamId = senderTeamId
	result.receiverTeamId = receiverTeamId
	result.canShare = capacity > 0 and amountSendable > 0
	result.amountSendable = amountSendable
	result.amountReceivable = capacity
	result.taxedPortion = taxedPortion
	result.taxRate = taxRate
	result.resourceType = resourceType
	return result
end

---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param springApi Spring?
---@return ResourcePolicyResult
function Shared.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, springApi)
	---@type ResourcePolicyResult
	local result = {
		senderTeamId = senderTeamId,
		receiverTeamId = receiverTeamId,
		canShare = false,
		amountSendable = 0,
		amountReceivable = 0,
		taxedPortion = 0,
		taxRate = 0,
		resourceType = resourceType,
	}
	return result
end

---@param policyResult ResourcePolicyResult
---@param desired number
---@return number received, number sent
function Shared.CalculateSenderTaxedAmount(policyResult, desired)
	if desired <= 0 then
		return 0, 0
	end
	local r = policyResult.taxRate
	if r >= 1.0 then
		return 0, 0
	end
	local sent = desired / (1 - r)
	return desired, sent
end

---@param spring Spring
---@param teamId integer
---@param resourceType ResourceName
---@return table|nil factor record, or nil if not cached
local function readFactor(spring, teamId, resourceType)
	return Shared.ResourceFactor(resourceType).Read(spring, teamId)
end

---@param senderId integer
---@param receiverId integer
---@param resourceType ResourceName
---@param springApi Spring?
---@return ResourcePolicyResult
function Shared.GetCachedPolicyResult(senderId, receiverId, resourceType, springApi)
	local spring = springApi or Spring
	if not SharedConfig.isResourceSharingEnabled(spring) then
		return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
	end

	local senderFactor = readFactor(spring, senderId, resourceType)
	local receiverFactor = readFactor(spring, receiverId, resourceType)
	if not senderFactor or not receiverFactor then
		return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
	end

	if not spring.IsCheatingEnabled() then
		if not spring.AreTeamsAllied(senderId, receiverId) and not senderFactor.isNonPlayer then
			return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
		end
		if not receiverFactor.active then
			return Shared.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
		end
	end

	return Shared.CombineResourcePolicy(
		senderFactor.taxedSendable,
		senderFactor.taxRate,
		receiverFactor.capacity,
		senderId,
		receiverId,
		resourceType
	)
end

return Shared
