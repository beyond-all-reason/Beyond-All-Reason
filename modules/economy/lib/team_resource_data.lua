---@class EconomyResource
---@field resourceType ResourceName
---@field current number Engine-owned snapshot; read-only to Lua
---@field storage number Engine-owned snapshot; read-only to Lua
---@field pull number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field income number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field expense number? Engine-owned snapshot; read-only to Lua; absent on solver snapshots
---@field shareSlider number Engine stores, Lua interprets
---@field sent number
---@field received number
---@field excess number Overflow pool to redistribute (solver input); last tick's wasted amount in GetTeamResourceData

---@class EconomyTeamResources
---@field allyTeam integer
---@field isDead boolean
---@field metal EconomyResource? absent when the snapshot skipped the resource (solver guards on it)
---@field energy EconomyResource? absent when the snapshot skipped the resource (solver guards on it)
---@field [ResourceName] EconomyResource? dynamic lookup form of the metal/energy fields

local TeamResourceData = {}

---@param springRepo Spring
---@param teamID integer
---@param resourceType ResourceName
---@return EconomyResource
function TeamResourceData.Get(springRepo, teamID, resourceType)
	local current, storage, pull, income, expense, shareSlider, sent, received =
		springRepo.GetTeamResources(teamID, resourceType)
	return {
		resourceType = resourceType,
		current = current or 0,
		storage = storage or 0,
		pull = pull or 0,
		income = income or 0,
		expense = expense or 0,
		shareSlider = shareSlider or 0,
		sent = sent or 0,
		received = received or 0,
		excess = 0,
	}
end

return TeamResourceData
