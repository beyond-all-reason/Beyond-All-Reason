local TransferEnums = VFS.Include("modules/sharing/enums.lua")
local PolicyShared = VFS.Include("modules/sharing/serialization.lua")
local Comms = VFS.Include("modules/sharing/resource/comms.lua")

local Shared = Comms

local FieldTypes = PolicyShared.FieldTypes

-- Schema for the GUI's flattened per-player policy packing (gui_advplayerlist/policy.lua).
Shared.ResourcePolicyFields = {
	resourceType = FieldTypes.string,
	canShare = FieldTypes.boolean,
	amountSendable = FieldTypes.number,
	amountReceivable = FieldTypes.number,
	taxedPortion = FieldTypes.number,
	taxRate = FieldTypes.number,
}

-- one factor record per (team, resource), O(teams); policy_evaluation.CalcResourcePolicyCached rebuilds any pair on read
Shared.ResourceFactorFields = {
	taxedSendable = FieldTypes.number,
	taxRate = FieldTypes.number,
	capacity = FieldTypes.number,
	isNonPlayer = FieldTypes.boolean,
	active = FieldTypes.boolean,
}

---Rules-param key for a team's resource factor record (owner team = the rules-param team).
---@param resourceType ResourceName
---@return string
function Shared.MakeFactorKey(resourceType)
	local policyType = resourceType == TransferEnums.ResourceType.METAL and TransferEnums.PolicyType.MetalTransfer or TransferEnums.PolicyType.EnergyTransfer
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

return Shared
