--- Policy helpers that keep gui_advplayerslist.lua under the Lua local closure cap
local TransferEnums = VFS.Include("common/luaUtilities/sharing/transfer_enums.lua")
local UnitShared = VFS.Include("common/luaUtilities/sharing/unit_transfer_shared.lua")
local ResourceShared = VFS.Include("common/luaUtilities/sharing/resource_transfer_shared.lua")

local METAL_POLICY_PREFIX = "metal_"
local ENERGY_POLICY_PREFIX = "energy_"
local UNIT_POLICY_PREFIX = "unit_"

-- reusable scratch tables; fields are dynamically (re)packed per call, so keep them open maps
local metalPlayerScratch = {} ---@type table<string, any>
local energyPlayerScratch = {} ---@type table<string, any>
local unitPlayerScratch = {} ---@type table<string, any>

local PolicyHelpers = {}

---@param player table
---@param resourceType string
---@param senderTeamId integer
---@return ResourcePolicyResult policyResult, string pascalResourceType
function PolicyHelpers.GetPlayerResourcePolicy(player, resourceType, senderTeamId)
	local policyType = resourceType == "metal" and TransferEnums.PolicyType.MetalTransfer or TransferEnums.PolicyType.EnergyTransfer
	local policyResult = PolicyHelpers.UnpackPolicyResult(policyType, player, senderTeamId, player.team)
	local pascalResourceType = resourceType == TransferEnums.ResourceType.METAL and "Metal" or "Energy"
	return policyResult --[[@as ResourcePolicyResult]], pascalResourceType
end

---@param playerData table
---@param myTeamID integer
---@param playerTeamID integer
function PolicyHelpers.PackAllPoliciesForPlayer(playerData, myTeamID, playerTeamID)
	PolicyHelpers.PackMetalPolicyResult(playerTeamID, myTeamID, playerData)
	PolicyHelpers.PackEnergyPolicyResult(playerTeamID, myTeamID, playerData)
	PolicyHelpers.PackUnitPolicyResult(playerTeamID, myTeamID, playerData)
end

---@param playerData table
---@param myTeamID integer
---@param team integer
---@return table, table, table
function PolicyHelpers.UnpackAllPolicies(playerData, myTeamID, team)
	local metalPolicy = PolicyHelpers.UnpackPolicyResult(TransferEnums.PolicyType.MetalTransfer, playerData, myTeamID, team)
	local energyPolicy = PolicyHelpers.UnpackPolicyResult(TransferEnums.PolicyType.EnergyTransfer, playerData, myTeamID, team)
	local unitPolicy = PolicyHelpers.UnpackUnitPolicyResult(playerData, myTeamID, team)
	return metalPolicy, energyPolicy, unitPolicy
end

---@param policyType string TransferEnums.PolicyType
---@param playerData table
---@param senderTeamId integer
---@param receiverTeamId integer
---@return ResourcePolicyResult|UnitPolicyResult
function PolicyHelpers.UnpackPolicyResult(policyType, playerData, senderTeamId, receiverTeamId)
	local fields, prefix, scratch
	if policyType == TransferEnums.PolicyType.MetalTransfer then
		fields = ResourceShared.ResourcePolicyFields
		prefix = METAL_POLICY_PREFIX
		scratch = metalPlayerScratch
	elseif policyType == TransferEnums.PolicyType.EnergyTransfer then
		fields = ResourceShared.ResourcePolicyFields
		prefix = ENERGY_POLICY_PREFIX
		scratch = energyPlayerScratch
	elseif policyType == TransferEnums.PolicyType.UnitTransfer then
		fields = UnitShared.UnitPolicyFields
		prefix = UNIT_POLICY_PREFIX
		scratch = unitPlayerScratch
	else
		error("Invalid transfer category: " .. policyType)
	end

	scratch.senderTeamId = senderTeamId
	scratch.receiverTeamId = receiverTeamId

	for field, _ in pairs(fields) do
		scratch[field] = playerData[prefix .. field]
	end
	return scratch --[[@as ResourcePolicyResult|UnitPolicyResult]]
end

---@param playerData table
---@param senderTeamId integer
---@param receiverTeamId integer
---@return UnitPolicyResult
function PolicyHelpers.UnpackUnitPolicyResult(playerData, senderTeamId, receiverTeamId)
	return PolicyHelpers.UnpackPolicyResult(TransferEnums.PolicyType.UnitTransfer, playerData, senderTeamId, receiverTeamId) --[[@as UnitPolicyResult]]
end

---@param policyType string TransferEnums.PolicyType
---@param policy table
---@param playerData table
function PolicyHelpers.PackPolicyResult(policyType, policy, playerData)
	local fields, prefix
	if policyType == TransferEnums.PolicyType.MetalTransfer then
		fields = ResourceShared.ResourcePolicyFields
		prefix = METAL_POLICY_PREFIX
	elseif policyType == TransferEnums.PolicyType.EnergyTransfer then
		fields = ResourceShared.ResourcePolicyFields
		prefix = ENERGY_POLICY_PREFIX
	elseif policyType == TransferEnums.PolicyType.UnitTransfer then
		fields = UnitShared.UnitPolicyFields
		prefix = UNIT_POLICY_PREFIX
	else
		error("Invalid transfer category: " .. policyType)
	end
	for field, _ in pairs(fields) do
		playerData[prefix .. field] = policy[field]
	end
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackMetalPolicyResult(team, myTeamID, player)
	local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, TransferEnums.ResourceType.METAL)
	PolicyHelpers.PackPolicyResult(TransferEnums.PolicyType.MetalTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackEnergyPolicyResult(team, myTeamID, player)
	local policyResult = ResourceShared.GetCachedPolicyResult(myTeamID, team, TransferEnums.ResourceType.ENERGY)
	PolicyHelpers.PackPolicyResult(TransferEnums.PolicyType.EnergyTransfer, policyResult, player)
end

---@param team number
---@param myTeamID number
---@param player table
function PolicyHelpers.PackUnitPolicyResult(team, myTeamID, player)
	local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, team, Spring)
	PolicyHelpers.PackPolicyResult(TransferEnums.PolicyType.UnitTransfer, policyResult, player)
end

local packByDomain = {
	[TransferEnums.PolicyType.UnitTransfer] = PolicyHelpers.PackUnitPolicyResult,
	[TransferEnums.PolicyType.MetalTransfer] = PolicyHelpers.PackMetalPolicyResult,
	[TransferEnums.PolicyType.EnergyTransfer] = PolicyHelpers.PackEnergyPolicyResult,
}

---Re-pack policy for rows affected by a SharePolicyChanged event: all rows if we changed, else just the changed team's row.
---@param player table all player rows
---@param myTeamID number
---@param changedTeamID number team whose policy changed
---@param domain PolicyType TransferEnums.PolicyType value that changed
function PolicyHelpers.RepackPolicy(player, myTeamID, changedTeamID, domain)
	local packFn = packByDomain[domain]
	if not packFn then
		return
	end

	for _, playerData in pairs(player) do
		if playerData.team and playerData.team ~= myTeamID then
			if changedTeamID == myTeamID or playerData.team == changedTeamID then
				packFn(playerData.team, myTeamID, playerData)
			end
		end
	end
end

return PolicyHelpers
