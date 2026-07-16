local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local SharedConfig = VFS.Include("modules/sharing/config.lua")

--- Pure helpers shared by policy files (modules/sharing/policies/) and the
--- synced factor caches. No engine mutation.

local M = {}

---@param springRepo EngineSynced
---@param teamId integer
---@return boolean
function M.IsNonPlayerTeam(springRepo, teamId)
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

---@param springRepo EngineSynced
---@param teamId integer
---@return boolean
function M.TeamActive(springRepo, teamId)
	local n = springRepo.GetTeamRulesParam(teamId, "numActivePlayers")
	if n == nil then
		return true
	end
	return tonumber(n) ~= 0
end

---resolve a context's effective resource tax rate in [0,1] (sender tech tax, else base)
---@param ctx PolicyContext
---@return number
function M.ResolveEffectiveTaxRate(ctx)
	local taxRate = (ctx.taxRate or SharedConfig.getTaxConfig(ctx.springRepo)) --[[@as number]]
	return math.min(taxRate, 1)
end

---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param _springApi EngineSynced? unused; kept for call-site symmetry with the cached path
---@return ResourcePolicyResult
function M.CreateDenyPolicy(senderTeamId, receiverTeamId, resourceType, _springApi)
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


---combine sender + receiver factors into a ResourcePolicyResult (same math as CalcResourcePolicy)
---@param taxedSendable number sender factor
---@param taxRate number sender factor
---@param capacity number receiver factor
---@param senderTeamId integer
---@param receiverTeamId integer
---@param resourceType ResourceName
---@param result table? optional reusable result table
---@return ResourcePolicyResult
function M.CombineResourcePolicy(taxedSendable, taxRate, capacity, senderTeamId, receiverTeamId, resourceType, result)
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


---Effective sharing modes for a context (tech enrichment first, then modoption).
---@param ctx PolicyContext
---@param modOptions table
---@return string[]
function M.ResolveSharingModes(ctx, modOptions)
	return ctx.unitSharingModes or { modOptions.unit_sharing_mode or ModeEnums.UnitFilterCategory.None }
end

return M
