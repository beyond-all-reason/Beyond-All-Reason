local Claims = require("modules/transfer/mex_splitting/claims")
local Holders = require("modules/transfer/mex_splitting/holders")
local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")
local TransferEnums = require("modules/transfer/enums")

---@type ConstructionContract
local ConstructionContract = Policies.Contract(Modules.Construction)

-- The deal: every mex region goes to a team seated at its start, and every spot in it is that team's to build on
--
---@class MexRegionsTeamStart
---@field teamID integer
---@field allyTeamID integer
---@field x number the team's start point: the centre of its start area
---@field z number

---@class MexRegionsDealContext
---@field regions MexRegion[]
---@field spots { x: number, z: number }[] the map's metal spots; a mex is attributed to the spot it mines
---@field teams MexRegionsTeamStart[] deal order

---@class MexRegionsDeal empty, with problems set, when no deal could be made
---@field regions table<string, integer> the team holding each region, by region id
---@field spots table<string, integer[]> the teams holding each metal spot, by spot key; a spot covered by two regions is held by both teams
---@field problems string[] why no deal was made; empty when one was

---@class TransferMexSplittingPolicy: PolicySteps<MexRegionsDealContext, MexRegionsDeal>
---@field LayoutChecksOut "LayoutChecksOut"
---@field SpotsKnown "SpotsKnown"
---@field NearestRoundRobin "NearestRoundRobin"

---@type TransferMexSplittingPolicy
local MexSplitting = {
	LayoutChecksOut = "LayoutChecksOut",
	SpotsKnown = "SpotsKnown",
	NearestRoundRobin = "NearestRoundRobin",
}
Policy.Single(MexSplitting)

---@param problems string[]
---@return MexRegionsDeal
local function noDeal(problems)
	return { regions = {}, spots = {}, problems = problems }
end

Policies.On(MexSplitting)
	.Refusal(function(ctx)
		local problems = RegionsApi.ProblemLines(RegionsApi.Enums.Types.MexRegion, ctx.regions, { spots = ctx.spots })
		if #problems == 0 and #ctx.spots == 0 then
			problems[1] = "the map has no metal spots to deal"
		end
		return noDeal(problems)
	end)
	.If(MexSplitting.LayoutChecksOut, function(ctx)
		return #RegionsApi.ProblemLines(RegionsApi.Enums.Types.MexRegion, ctx.regions, { spots = ctx.spots }) == 0
	end)
	.If(MexSplitting.SpotsKnown, function(ctx)
		return #ctx.spots > 0
	end)
	.Answer(MexSplitting.NearestRoundRobin, function(ctx)
		local teams = Claims.RankRegionsByDistance(ctx.teams, ctx.regions)
		local held = {} ---@type table<string, integer>
		Claims.RoundRobin(teams, held, Claims.OwnStart)
		Claims.RoundRobin(teams, held, Claims.EmptyStart(ctx.teams))
		local emptyHanded = Claims.EmptyHanded(ctx.teams, held)
		if #emptyHanded > 0 then
			local n = #emptyHanded
			return noDeal({
				n .. " team" .. (n == 1 and "" or "s") .. " would hold no mex region: the layout has too few",
			})
		end
		return { regions = held, spots = Claims.SpotHolders(ctx.regions, ctx.spots, held), problems = {} }
	end)

-- A team has left the match: the ally that has inherited the fewest regions takes its' regions; ties go to the nearest start
--
---@class MexRegionsHeirContext
---@field departing MexRegionsTeamStart
---@field heirs { teamID: integer, x: number, z: number, gifted: integer }[] the departing team's living allies in the deal; gifted is how many regions each has already inherited

---@class TransferMexSplittingHeirPolicy: PolicySteps<MexRegionsHeirContext, integer|false>
---@field FewestGiftedThenNearest "FewestGiftedThenNearest"

---@type TransferMexSplittingHeirPolicy
local MexSplittingHeir = {
	FewestGiftedThenNearest = "FewestGiftedThenNearest",
}
Policy.Single(MexSplittingHeir)

Policies.On(MexSplittingHeir).Answer(MexSplittingHeir.FewestGiftedThenNearest, function(ctx)
	local from = ctx.departing
	local best, bestGifted, bestDistance = nil, math.huge, math.huge
	for _, heir in ipairs(ctx.heirs) do
		local distance = RegionsApi.Geometry.Distance(from.x, from.z, heir.x, heir.z)
		if heir.gifted < bestGifted or (heir.gifted == bestGifted and distance < bestDistance) then
			best, bestGifted, bestDistance = heir.teamID, heir.gifted, distance
		end
	end
	return best
end)

-- Map assigned: a spot is held by whoever the deal gave its region to
--
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

---@class (partial) TransferContract
local Contract = {}
Contract.MexSplitting = MexSplitting
Contract.MexSplittingHeir = MexSplittingHeir

return Contract
