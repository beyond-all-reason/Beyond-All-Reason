local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local SharedHelpers = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local Widgets = {
	CalculateSenderTaxedAmount = SharedHelpers.CalculateSenderTaxedAmount,
	CommunicationCase = SharedEnums.ResourceCommunicationCase,
	DecideCommunicationCase = SharedHelpers.DecideCommunicationCase,
	GetCachedPolicyResult = SharedHelpers.GetCachedPolicyResult,
	GetCumulativeParam = SharedHelpers.GetCumulativeParam,
	GetCumulativeSent = SharedHelpers.GetCumulativeSent,
	ResourceTypes = SharedEnums.ResourceTypes,
}
Widgets.__index = Widgets

---This and its sibling hydrate existing tables with a policyResult so we don't thrash GC
---@param out ResourcePolicyResult
---@param playerData table
---@param prefix string
---@return ResourcePolicyResult
function Widgets.UnpackPolicyResult(out, playerData, prefix, senderTeamId, receiverTeamId)
	out.senderTeamId = senderTeamId
	out.receiverTeamId = receiverTeamId
	for field, _ in pairs(SharedHelpers.ResourcePolicyFields) do
		out[field] = playerData[prefix .. field]
	end
	return out
end

---@param policy ResourcePolicyResult
---@param player table
---@param prefix string
function Widgets.PackResourcePolicyResult(policy, player, prefix)
	for field, _ in pairs(SharedHelpers.ResourcePolicyFields) do
		player[prefix .. field] = policy[field]
	end
end

return Widgets
