local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Shared = VFS.Include("modules/transfer/mex_splitting/shared.lua") ---@type MexRegionsShared

---@class MexRegionsClaimsLib the pure steps of the deal, so the policy reads as the rule and the spec can check each step
local Claims = {}

---@class MexRegionsRanked one region as a team sees it
---@field region MexRegion
---@field distance number elmos from where the team starts to the region's centre

---@class MexRegionsTeamView a team and the regions ranked from where it starts
---@field team MexRegionsTeamStart
---@field regions MexRegionsRanked[] nearest first

---@param regions MexRegion[]
---@param spots { x: number, z: number }[] the map's metal spots, for the rule that every one is covered
---@return string[] problems # what the regions module's set check finds wrong with the layout
function Claims.Problems(regions, spots)
	local lines = {} ---@type string[]
	for i, problem in ipairs(Regions.CheckSet(Enums.Types.MexRegion, regions, { spots = spots })) do
		lines[i] = Regions.ProblemLine(problem)
	end
	return lines
end

---@param teams MexRegionsTeamStart[]
---@param regions MexRegion[]
---@return MexRegionsTeamView[] views # in the teams' order
function Claims.Rank(teams, regions)
	local centres = {} ---@type table<MexRegion, { x: number, z: number }>
	for _, region in ipairs(regions) do
		local x, z = Geometry.Centroid(region.vertices)
		centres[region] = { x = x, z = z }
	end
	local views = {} ---@type MexRegionsTeamView[]
	for i, team in ipairs(teams) do
		local ranked = {} ---@type MexRegionsRanked[]
		for j, region in ipairs(regions) do
			local centre = centres[region]
			ranked[j] = { region = region, distance = Geometry.Distance(centre.x, centre.z, team.x, team.z) }
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

---The keys of the spots inside each region, by region id.
---@param regions MexRegion[]
---@param spots { x: number, z: number }[]
---@return table<string, string[]>
function Claims.SpotsIn(regions, spots)
	local byRegion = {} ---@type table<string, string[]>
	for _, spot in ipairs(spots) do
		for _, region in ipairs(regions) do
			if Geometry.Contains(spot.x, spot.z, region.vertices) then
				byRegion[region.id] = byRegion[region.id] or {}
				table.insert(byRegion[region.id], Shared.SpotKey(spot.x, spot.z))
			end
		end
	end
	return byRegion
end

---@param regions MexRegion[]
---@param holders table<string, integer> the team holding each region, by region id
---@return table<integer, string[]|nil> holdings # the ids of each team's regions in layout order, by team
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
