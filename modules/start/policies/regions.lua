local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

-- Start regions describe what makes them special at run-time
--
---@class StartDescription: RegionDescription
---@field team integer
---@field positions { x: number, z: number }[]

local RegionsDescribe = Policy.Contributes(Regions.Describe, { Start = "Start" })

Policies.On(RegionsDescribe)
	.Answer(RegionsDescribe.Start, function(ctx)
		---@cast ctx RegionDescribeContext<StartRegion>
		return { team = ctx.region.team, positions = ctx.region.positions or {} }
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))

-- Start regions are named by team, if present
--   (if a map maker hasn't defined the start region.name via terraformer e.g. "canyon", "carry", etc.)
--
local RegionsNames = Policy.Contributes(Regions.Names, { FromTeam = "FromTeam" })

Policies.On(RegionsNames)
	.Apply(RegionsNames.FromTeam, function(ctx)
		---@cast ctx RegionNamesContext<StartRegion>
		for i, region in ipairs(ctx.regions) do
			if region.team ~= nil then
				ctx.proposed[i] = tostring(region.team)
			end
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))

-- Start regions do not overlap (validation enforced by the map editor)
--
local RegionsSet = Policy.Contributes(Regions.CheckSet, { AreasDisjoint = "AreasDisjoint" })

Policies.On(RegionsSet)
	.Apply(RegionsSet.AreasDisjoint, function(ctx)
		local label = ctx.type.label:lower()
		for i, a in ipairs(ctx.regions) do
			for j, b in ipairs(ctx.regions) do
				if i ~= j and #a.vertices >= 3 and #b.vertices >= 3 and RegionsApi.Overlaps(a.vertices, b.vertices) then
					RegionsApi.ProblemWith(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
				end
			end
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.Start))

return { RegionsNames = RegionsNames, RegionsSet = RegionsSet, RegionsDescribe = RegionsDescribe }
