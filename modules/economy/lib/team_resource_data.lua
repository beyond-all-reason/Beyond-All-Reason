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

---@param springRepo SpringBoth
---@param teamID integer
---@param resourceType ResourceName
---@param into EconomyResource|nil the record to write this moment's numbers into, so a reader that asks every frame allocates nothing; a new one when nil
---@return EconomyResource
function TeamResourceData.Get(springRepo, teamID, resourceType, into)
	local current, storage, pull, income, expense, shareSlider, sent, received =
		springRepo.GetTeamResources(teamID, resourceType)
	local data = into or {} --[[@as EconomyResource]]
	data.resourceType = resourceType
	data.current = current or 0
	data.storage = storage or 0
	data.pull = pull or 0
	data.income = income or 0
	data.expense = expense or 0
	data.shareSlider = shareSlider or 0
	data.sent = sent or 0
	data.received = received or 0
	data.excess = 0
	return data
end

return TeamResourceData
