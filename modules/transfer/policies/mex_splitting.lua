local Contract = VFS.Include("modules/transfer/contract.lua") ---@type TransferContract
local ConstructionContract = VFS.Include("modules/construction/contract.lua") ---@type ConstructionContract
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local RegionEnums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local RegionProblems = VFS.Include("modules/regions/lib/problems.lua") ---@type RegionProblems
local TransferEnums = VFS.Include("modules/transfer/enums.lua")
local Claims = VFS.Include("modules/transfer/mex_splitting/claims.lua") ---@type MexRegionsClaimsLib
local Holders = VFS.Include("modules/transfer/mex_splitting/holders.lua") ---@type MexRegionsHolders

---@param problems string[]
---@return MexRegionsDeal
local function noDeal(problems)
	return { regions = {}, spots = {}, problems = problems }
end

Policies.On(RegionsContract.Names).Apply(Contract.MexRegionsNames.FromGroup, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.MexRegion then
		return
	end
	for i, region in ipairs(ctx.regions) do
		---@cast region MexRegion
		local group = region.group
		if group ~= nil and group ~= "" then
			ctx.bases[i] = tostring(group)
		end
	end
end)

Policies.On(RegionsContract.CheckSet).Apply(Contract.MexRegionsSet.MexesCovered, function(ctx)
	local spots = (ctx.env --[[@as MexRegionEnv]]).spots
	if ctx.type.key ~= RegionEnums.Types.MexRegion or spots == nil then
		return
	end
	local uncovered, first = 0, nil
	for _, spot in ipairs(spots) do
		local covered = false
		for _, region in ipairs(ctx.regions) do
			covered = covered or (region.vertices ~= nil and Geometry.Contains(spot.x, spot.z, region.vertices))
		end
		if not covered then
			uncovered = uncovered + 1
			first = first or { x = spot.x, z = spot.z }
		end
	end
	if uncovered > 0 then
		RegionProblems.OfSet(
			ctx,
			uncovered .. " metal spot" .. (uncovered == 1 and "" or "s") .. " in no mex region",
			first
		)
	end
end)

Policies.On(RegionsContract.Describe).Apply(Contract.MexRegionsDescribe.MetalSpots, function(ctx)
	local spots = (ctx.env --[[@as MexRegionEnv]]).spots
	if not spots or not ctx.region.vertices then
		return
	end
	local count, worth = 0, 0.0
	for _, spot in ipairs(spots) do
		if Geometry.Contains(spot.x, spot.z, ctx.region.vertices) then
			count = count + 1
			worth = worth + (spot.worth or 0)
		end
	end
	ctx.lines[#ctx.lines + 1] = {
		"Metal spots",
		-- a thousandth of the metal map's sum is what the game floats over a spot: a T1 mex's income
		count .. (count > 0 and string.format(" (%.1f metal/s with T1 mexes)", worth / 1000) or ""),
	}
end)

Policies.On(Contract.MexSplitting)
	.Refusal(function(ctx)
		local problems = Claims.Problems(ctx.regions, ctx.spots)
		if #problems == 0 and #ctx.spots == 0 then
			problems[1] = "the map has no metal spots to deal"
		end
		return noDeal(problems)
	end)
	.If(Contract.MexSplitting.LayoutChecksOut, function(ctx)
		return #Claims.Problems(ctx.regions, ctx.spots) == 0
	end)
	.If(Contract.MexSplitting.SpotsKnown, function(ctx)
		return #ctx.spots > 0
	end)
	.Answer(Contract.MexSplitting.NearestRoundRobin, function(ctx)
		local views = Claims.Rank(ctx.teams, ctx.regions)
		local held = {} ---@type table<string, integer>

		---@param seated MexRegionsTeamView[] the teams taking turns
		---@param takes fun(region: MexRegion): boolean which regions are on the table
		local function goRound(seated, takes)
			---@param view MexRegionsTeamView
			---@return MexRegion|nil
			local function nearestFree(view)
				for _, ranked in ipairs(view.regions) do
					if held[ranked.region.id] == nil and takes(ranked.region) then
						return ranked.region
					end
				end
				return nil
			end

			---@return boolean
			local function round()
				local took = false
				for _, view in ipairs(seated) do
					local pick = nearestFree(view)
					if pick then
						held[pick.id] = view.team.teamID
						took = true
					end
				end
				return took
			end

			for _ = 1, #ctx.regions do
				if not round() then
					return
				end
			end
		end

		local seated = {} ---@type table<integer, MexRegionsTeamView[]>
		local ordinals = {} ---@type integer[]
		for _, view in ipairs(views) do
			local ordinal = view.team.allyTeam
			if seated[ordinal] == nil then
				seated[ordinal] = {}
				ordinals[#ordinals + 1] = ordinal
			end
			table.insert(seated[ordinal], view)
		end
		table.sort(ordinals)
		for _, ordinal in ipairs(ordinals) do
			goRound(seated[ordinal], function(region)
				return region.team == ordinal
			end)
		end
		goRound(views, function(region)
			return seated[region.team] == nil
		end)

		local holding = {} ---@type table<integer, boolean>
		for _, teamID in pairs(held) do
			holding[teamID] = true
		end
		local without = 0
		for _, team in ipairs(ctx.teams) do
			without = without + (holding[team.teamID] and 0 or 1)
		end
		if without > 0 then
			return noDeal({
				without
					.. " team"
					.. (without == 1 and "" or "s")
					.. " would hold no mex region: the layout has too few",
			})
		end

		local byRegion = Claims.SpotsIn(ctx.regions, ctx.spots)
		local spots = {} ---@type table<string, integer[]>
		for _, region in ipairs(ctx.regions) do
			local teamID = held[region.id]
			for _, key in ipairs(teamID and byRegion[region.id] or {}) do
				spots[key] = spots[key] or {}
				if not table.contains(spots[key], teamID) then
					table.insert(spots[key], teamID)
				end
			end
		end
		return { regions = held, spots = spots, problems = {} }
	end)

Policies.On(Contract.MexSplittingHeir).Answer(Contract.MexSplittingHeir.FewestGiftedThenNearest, function(ctx)
	local from = ctx.departing
	local best, bestGifted, bestDistance = nil, math.huge, math.huge
	for _, heir in ipairs(ctx.heirs) do
		local distance = Geometry.Distance(from.x, from.z, heir.x, heir.z)
		if heir.gifted < bestGifted or (heir.gifted == bestGifted and distance < bestDistance) then
			best, bestGifted, bestDistance = heir.teamID, heir.gifted, distance
		end
	end
	return best
end)

Policies.On(ConstructionContract.PlacementFacts)
	.Provide(ConstructionContract.PlacementFacts.SpotHolder, function(ctx, springRepo)
		if ctx.modOptions[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.MapAssigned then
			return nil
		end
		if ctx.spotX == nil or ctx.spotZ == nil then
			return nil
		end
		local engine = springRepo or Spring
		local holders = Holders.At(engine, ctx.spotX, ctx.spotZ)
		if #holders == 0 or table.contains(holders, ctx.builderTeam) then
			return nil
		end
		for _, teamID in ipairs(holders) do
			if engine.AreTeamsAllied and engine.AreTeamsAllied(ctx.builderTeam, teamID) then
				return teamID
			end
		end
		return holders[1]
	end)
