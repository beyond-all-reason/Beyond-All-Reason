local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Enums = VFS.Include("modules/sharing/enums.lua")
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local Config = VFS.Include("modules/sharing/config.lua")
local Helpers = VFS.Include("modules/sharing/helpers.lua")
local ResourceShared = VFS.Include("modules/sharing/resource/shared.lua")
local UnitShared = VFS.Include("modules/sharing/unit/shared.lua")

local PolicyCategory = Enums.PolicyCategory

--- The module's policy runtime: live pipeline evaluation
--- (modules/sharing/policies/<category>.lua) plus the cached-factor rebuilds.
--- Both decision paths live in this one file so their gates stay in sync.
--- Pipelines load lazily and once per Lua state.

local M = {}

local pipelines ---@type table<string, PolicyDescriptor[]>|nil

---@param category string
---@return PolicyDescriptor[]
local function pipeline(category)
	if not pipelines then
		pipelines = ModuleHandler.LoadPolicies("sharing")
	end
	local found = pipelines[category]
	if not found then
		error(string.format("sharing: no policy pipeline %q (expected modules/sharing/policies/%s.lua)", category, category))
	end
	return found
end

---@param ctx PolicyContext
---@param resourceType ResourceName
---@return ResourcePolicyResult
function M.CalcResourcePolicy(ctx, resourceType)
	return ModuleHandler.Evaluate(pipeline(PolicyCategory.Resource), ctx, resourceType) --[[@as ResourcePolicyResult]]
end

---Build per-pair policy (expose) from context
---@param ctx PolicyContext
---@return UnitPolicyResult
function M.GetUnitPolicy(ctx)
	return ModuleHandler.Evaluate(pipeline(PolicyCategory.Unit), ctx) --[[@as UnitPolicyResult]]
end

---@param spring EngineSynced
---@param teamId integer
---@param resourceType ResourceName
---@return table|nil factor record, or nil if not cached
local function readFactor(spring, teamId, resourceType)
	local serialized = spring.GetTeamRulesParam(teamId, ResourceShared.MakeFactorKey(resourceType))
	if serialized == nil then
		return nil
	end
	return ResourceShared.DeserializeResourceFactor(serialized)
end

---Cached counterpart of CalcResourcePolicy: rebuild a (sender,receiver) pair
---from the per-team factor cache + live gates. The factor-field gates mirror
---the pipeline gates in policies/resource.lua — kept here so live and cached
---paths are reviewed together; absent factors deny.
---@param senderId integer
---@param receiverId integer
---@param resourceType ResourceName
---@param springApi EngineSynced?
---@return ResourcePolicyResult
function M.CalcResourcePolicyCached(senderId, receiverId, resourceType, springApi)
	local spring = springApi or (Spring --[[@as EngineSynced]])
	if not Config.isResourceSharingEnabled(spring) then
		return Helpers.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
	end

	local senderFactor = readFactor(spring, senderId, resourceType)
	local receiverFactor = readFactor(spring, receiverId, resourceType)
	if not senderFactor or not receiverFactor then
		return Helpers.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
	end

	if not spring.IsCheatingEnabled() then
		if not spring.AreTeamsAllied(senderId, receiverId) and not senderFactor.isNonPlayer then
			return Helpers.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
		end
		if not receiverFactor.active then
			return Helpers.CreateDenyPolicy(senderId, receiverId, resourceType, spring)
		end
	end

	return Helpers.CombineResourcePolicy(senderFactor.taxedSendable, senderFactor.taxRate, receiverFactor.capacity, senderId, receiverId, resourceType)
end

---Cached counterpart of GetUnitPolicy: rebuild a pair's UnitPolicyResult from
---the per-team unit factors; mirrors policies/unit.lua's gate. Pre-cache
---fallback uses global mode + alliance only (legacy behaviour).
function M.GetUnitPolicyCached(senderTeamId, receiverTeamId, springApi)
	local spring = springApi or Spring
	local modOptions = spring.GetModOptions()
	local stunSeconds = tonumber(modOptions[ModeEnums.ModOptions.UnitShareStunSeconds]) or 0
	local stunCategory = modOptions[ModeEnums.ModOptions.UnitStunCategory] or ModeEnums.UnitFilterCategory.Resource
	local buildDelaySeconds = tonumber(modOptions[ModeEnums.ModOptions.ConstructorBuildDelay]) or 0

	local areAllied = (spring.AreTeamsAllied and spring.AreTeamsAllied(senderTeamId, receiverTeamId)) == true

	local factorKey = UnitShared.MakeFactorKey()
	local senderSerialized = spring.GetTeamRulesParam(senderTeamId, factorKey)
	local receiverSerialized = spring.GetTeamRulesParam(receiverTeamId, factorKey)

	if senderSerialized == nil or receiverSerialized == nil then
		-- Pre-cache fallback: global mode + alliance only (matches legacy behaviour).
		local category = modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None
		---@type UnitPolicyResult
		return {
			senderTeamId = senderTeamId,
			receiverTeamId = receiverTeamId,
			canShare = areAllied and category ~= ModeEnums.UnitFilterCategory.None,
			sharingModes = { category },
			stunSeconds = stunSeconds,
			stunCategory = stunCategory,
			buildDelaySeconds = buildDelaySeconds,
		}
	end

	local senderFactor = UnitShared.DeserializeUnitFactor(senderSerialized)
	local receiverFactor = UnitShared.DeserializeUnitFactor(receiverSerialized)
	local modes = senderFactor.sharingModes
	local modeNotNone = not (#modes == 1 and modes[1] == ModeEnums.UnitFilterCategory.None)

	local canShare = areAllied and modeNotNone
	if canShare and not (spring.IsCheatingEnabled and spring.IsCheatingEnabled()) then
		if not receiverFactor.active then
			canShare = false
		end
	end

	---@type UnitPolicyResult
	return {
		senderTeamId = senderTeamId,
		receiverTeamId = receiverTeamId,
		canShare = canShare,
		sharingModes = modes,
		stunSeconds = stunSeconds,
		stunCategory = stunCategory,
		buildDelaySeconds = buildDelaySeconds,
	}
end

return M
