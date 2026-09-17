
local Published = VFS.Include("modules/published.lua")

---@class MexRegionsShared
local Shared = {}

---@class MexHoldingsRecord one team's share of the deal
---@field regions string[] the ids of the regions the team holds
---@field spots string[] the metal spots inside those regions, as "<x>x<z>" keys; a mex is judged by the spot it mines

---@param x number
---@param z number
---@return string
function Shared.SpotKey(x, z)
	return math.floor(x + 0.5) .. "x" .. math.floor(z + 0.5)
end

Shared.Holdings = Published.PerTeam("mex_holdings", {
	regions = Published.List,
	spots = Published.List,
})

local cache = { signature = nil, byKey = {} }
---@param springRepo Spring
---@param teamIDs integer[]
---@return table<string, integer[]> the teams holding each metal spot, by spot key; only teams the reader may see
function Shared.HoldersBySpot(springRepo, teamIDs)
	local parts = {}
	for i, teamID in ipairs(teamIDs) do
		parts[i] = tostring(springRepo.GetTeamRulesParam(teamID, Shared.Holdings.key) or "")
	end
	local signature = table.concat(parts, "|")
	if cache.signature == signature then
		return cache.byKey
	end
	local byKey = {} ---@type table<string, integer[]>
	for _, teamID in ipairs(teamIDs) do
		local record = Shared.Holdings.Read(springRepo, teamID) ---@type MexHoldingsRecord|nil
		if record and record.spots then
			for _, key in ipairs(record.spots) do
				byKey[key] = byKey[key] or {}
				table.insert(byKey[key], teamID)
			end
		end
	end
	cache.signature = signature
	cache.byKey = byKey
	return byKey
end

return Shared
