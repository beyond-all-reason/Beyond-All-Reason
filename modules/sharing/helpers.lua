local SharedConfig = VFS.Include("modules/sharing/economy/shared_config.lua")

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

return M
