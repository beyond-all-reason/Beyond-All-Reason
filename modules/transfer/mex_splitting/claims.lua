local Regions = require("modules/regions/api")
local Shared = require("modules/transfer/mex_splitting/shared")

---@class MexRegionsClaimsLib
local Claims = {}

---@class MexRegionsRanked
---@field region MexRegion
---@field distance number

---@class MexRegionsTeamView
---@field team MexRegionsTeamStart
---@field regions MexRegionsRanked[]

---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsTeamView[]
function Claims.RankRegionsByDistance(teams, regions)
	local centres = {} ---@type table<MexRegion, { x: number, z: number }>
	for _, region in ipairs(regions) do
		local x, z = Regions.Geometry.Centroid(region.vertices)
		centres[region] = { x = x, z = z }
	end
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local centre = centres[region]
			ranked[j] = { region = region, distance = Regions.Geometry.Distance(centre.x, centre.z, team.x, team.z) }
		end
		table.sort(ranked, function(a, b)
			if a.distance ~= b.distance then
				return a.distance < b.distance
			end
			return a.region.id < b.region.id
		end)
		views[i] = { team = team, regions = ranked }
	end
	return views
end

---A region bound to the start this team sits at
---@param view MexRegionsTeamView
---@param region MexRegion
---@return boolean
function Claims.OwnStart(view, region)
	return region.team == view.team.allyTeamID
end

---A region bound to a start nobody sits at
---@param teams MexRegionsTeamStart[]
---@return fun(view: MexRegionsTeamView, region: MexRegion): boolean
function Claims.EmptyStart(teams)
	local seated = {} ---@type table<integer, boolean>
	for _, team in ipairs(teams) do
		seated[team.allyTeamID] = true
	end
	return function(_, region)
		return not seated[region.team]
	end
end

---Deals round the teams until nobody can take: each team in turn takes the nearest region still free that it may take.
---@param teams MexRegionsTeamView[]
---@param held table<string, integer> region id -> team; written
---@param mayTake fun(view: MexRegionsTeamView, region: MexRegion): boolean
function Claims.RoundRobin(teams, held, mayTake)
	local function take(view)
		for _, ranked in ipairs(view.regions) do
			if held[ranked.region.id] == nil and mayTake(view, ranked.region) then
				held[ranked.region.id] = view.team.teamID
				return true
			end
		end
		return false
	end
	local took = true
	while took do
		took = false
		for _, view in ipairs(teams) do
			took = take(view) or took
		end
	end
end

---@param teams MexRegionsTeamStart[]
---@param held table<string, integer>
---@return MexRegionsTeamStart[] the teams holding no region
function Claims.EmptyHanded(teams, held)
	local holding = {} ---@type table<integer, boolean>
	for _, teamID in pairs(held) do
		holding[teamID] = true
	end
	local out = {}
	for _, team in ipairs(teams) do
		if not holding[team.teamID] then
			out[#out + 1] = team
		end
	end
	return out
end

---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@param held table<string, integer>
---@return table<string, integer[]> the teams holding each spot, by spot key; a spot two regions cover is held by both
function Claims.SpotHolders(regions, spots, held)
	local byRegion = Claims.SpotsIn(regions, spots)
	local holders = {} ---@type table<string, integer[]>
	for _, region in ipairs(regions) do
		local teamID = held[region.id]
		for _, key in ipairs(teamID and byRegion[region.id] or {}) do
			holders[key] = holders[key] or {}
			if not table.contains(holders[key], teamID) then
				table.insert(holders[key], teamID)
			end
		end
	end
	return holders
end

---The keys of the spots inside each region, by region id.
---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@return table<string, string[]>
function Claims.SpotsIn(regions, spots)
	local byRegion = {} ---@type table<string, string[]>
	for _, spot in ipairs(spots) do
		for _, region in ipairs(regions) do
			if Regions.Contains(spot.x, spot.z, region.vertices) then
				byRegion[region.id] = byRegion[region.id] or {}
				table.insert(byRegion[region.id], Shared.SpotKey(spot.x, spot.z))
			end
		end
	end
	return byRegion
end

---@param regions MexRegion[]
---@param holders table<string, integer>
---@return table<integer, string[]|nil>
function Claims.Holdings(regions, holders)
	local holdings = {} ---@type table<integer, string[]|nil>
	for _, region in ipairs(regions) do
		local teamID = holders[region.id]
		if teamID ~= nil then
			holdings[teamID] = holdings[teamID] or {}
			table.insert(holdings[teamID], region.id)
		end
	end
	return holdings
end

return Claims
