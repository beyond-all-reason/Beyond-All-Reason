local ShareStats = require("modules/economy/lib/share_stats")
local TeamResourceData = require("modules/economy/lib/team_resource_data")

---@param springRepo Spring
---@param teamID integer
---@param resource ResourceName
---@param sent number|nil
---@param received number|nil
---@return number|nil sent
---@return number|nil received
local function overlaySharing(springRepo, teamID, resource, sent, received)
	local s = ShareStats.Read(springRepo, teamID, resource)
	return s.sentRecent or sent, s.receivedRecent or received
end

---@class EconomyResourcesApi a team's resources as the economy sees them: the engine's numbers, with what redistribution sent and received laid over
local Resources = {
	---@param springRepo Spring
	---@param teamID integer
	---@param resource ResourceName
	---@return EconomyResource the engine's snapshot alone
	Snapshot = function(springRepo, teamID, resource)
		return TeamResourceData.Get(springRepo, teamID, resource)
	end,

	---@param springRepo Spring
	---@param teamID integer
	---@param resource ResourceName
	Data = function(springRepo, teamID, resource)
		local d = TeamResourceData.Get(springRepo, teamID, resource)
		d.sent, d.received = overlaySharing(springRepo, teamID, resource, d.sent, d.received)
		return d
	end,

	---@param springRepo Spring
	---@param teamID integer
	---@param resource ResourceName
	---@return number|nil current
	---@return number|nil storage
	---@return number|nil pull
	---@return number|nil income
	---@return number|nil expense
	---@return number|nil share
	---@return number|nil sent what redistribution sent lately, laid over the engine's figure
	---@return number|nil received
	Get = function(springRepo, teamID, resource)
		local cur, stor, pull, inc, exp, share, sent, received = springRepo.GetTeamResources(teamID, resource)
		sent, received = overlaySharing(springRepo, teamID, resource, sent, received)
		return cur, stor, pull, inc, exp, share, sent, received
	end,

	---@param springRepo Spring
	---@param teamID integer
	---@param resource ResourceName
	---@param amount number
	Add = function(springRepo, teamID, resource, amount)
		local current = springRepo.GetTeamResources(teamID, resource) or 0
		return springRepo.SetTeamResource(teamID, resource, current + amount)
	end,
}

---@class EconomyApi
return {
	Resources = Resources,
}
