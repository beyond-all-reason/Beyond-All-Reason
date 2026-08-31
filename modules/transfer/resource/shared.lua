local TransferEnums = VFS.Include("modules/context/enums.lua")
local PolicyShared = VFS.Include("modules/context/serialization.lua")
local Comms = VFS.Include("modules/transfer/resource/comms.lua")
local SharedConfig = VFS.Include("modules/transfer/economy/shared_config.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes

Shared.ResourcePolicyFields = {
	resourceType = FieldTypes.string,
	canShare = FieldTypes.boolean,
	amountSendable = FieldTypes.number,
	amountReceivable = FieldTypes.number,
	taxedPortion = FieldTypes.number,
	taxRate = FieldTypes.number,
}

Shared.ResourceFactorFields = {
	taxedSendable = FieldTypes.number,
	taxRate = FieldTypes.number,
	capacity = FieldTypes.number,
	isNonPlayer = FieldTypes.boolean,
	active = FieldTypes.boolean,
}

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
	-- Spring.GetTeamLuaAI returns "" (not nil) for teams without a LuaAI, so guard both.
	local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
	return luaAI ~= nil and luaAI ~= ""
end

---@return string
function Shared.MakeFactorKey(resourceType)
	local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer
		or TransferEnums.PolicyType.EnergyTransfer
	return policyType .. "_factor"
end

---@param factor table
---@return string
function Shared.SerializeResourceFactor(factor)
	return PolicyShared.Serialize(Shared.ResourceFactorFields, factor)
end

---@param serialized string
---@return table
function Shared.DeserializeResourceFactor(serialized)
	return PolicyShared.Deserialize(Shared.ResourceFactorFields, serialized)
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
		-- 100% tax means the resource cannot be sent (infinite cost)
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
	local serialized = spring.GetTeamRulesParam(teamId, Shared.MakeFactorKey(resourceType))
	if serialized == nil then
		return nil
	end
	return Shared.DeserializeResourceFactor(serialized)
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
