local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local RegionsApi = require("modules/regions/api")

---@type RegionsContract
local Regions = Policies.Contract(Modules.Regions)

---@class (partial) RegionMap
---@field spots { x: number, z: number, worth: number|nil }[]|nil
---@field starts integer|nil how many starts the map has; a region is bound to one of them

---@class TransferRegionsCheckSetSteps: PolicySteps<RegionSetContext<MexRegion>, RegionSetContext<MexRegion>>
---@field MexesCovered "MexesCovered"
---@field BoundToAStart "BoundToAStart"

---@type TransferRegionsCheckSetSteps
local MexRegionsSet = {
	MexesCovered = "MexesCovered",
	BoundToAStart = "BoundToAStart",
}
Policy.Contributes(Regions.CheckSet, MexRegionsSet)

---@class TransferRegionsNamesSteps: PolicySteps<RegionNamesContext<MexRegion>, RegionNamesContext<MexRegion>>
---@field FromGroup "FromGroup"

---@type TransferRegionsNamesSteps
local MexRegionsNames = {
	FromGroup = "FromGroup",
}
Policy.Contributes(Regions.Names, MexRegionsNames)

---@class MexRegionDescription: RegionDescription
---@field team integer
---@field group string
---@field spots integer|nil
---@field worth number|nil

---@class TransferRegionsDescribeSteps: PolicySteps<RegionDescribeContext<MexRegion>, MexRegionDescription>
---@field MexRegion "MexRegion"

---@type TransferRegionsDescribeSteps
local MexRegionsDescribe = {
	MexRegion = "MexRegion",
}
Policy.Contributes(Regions.Describe, MexRegionsDescribe)

Policies.On(MexRegionsNames)
	.Apply(MexRegionsNames.FromGroup, function(ctx)
		for i, region in ipairs(ctx.regions) do
			local group = region.group
			if group ~= nil and group ~= "" then
				ctx.proposed[i] = tostring(group)
			end
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.MexRegion))

Policies.On(MexRegionsSet)
	.Apply(MexRegionsSet.BoundToAStart, function(ctx)
		local starts = ctx.map.starts
		if starts == nil then
			return
		end
		for i, region in ipairs(ctx.regions) do
			if region.team ~= nil and (region.team < 0 or region.team >= starts) then
				RegionsApi.ProblemWith(
					ctx,
					i,
					"bound to start " .. region.team .. "; the map's starts are 0 to " .. (starts - 1)
				)
			end
		end
	end)
	.Apply(MexRegionsSet.MexesCovered, function(ctx)
		local spots = ctx.map.spots
		if spots == nil then
			return
		end
		local uncovered, first = 0, nil
		for _, spot in ipairs(spots) do
			local covered = false
			for _, region in ipairs(ctx.regions) do
				covered = covered or (region.vertices ~= nil and RegionsApi.Contains(spot.x, spot.z, region.vertices))
			end
			if not covered then
				uncovered = uncovered + 1
				first = first or { x = spot.x, z = spot.z }
			end
		end
		if uncovered > 0 then
			RegionsApi.ProblemAt(
				ctx,
				uncovered .. " metal spot" .. (uncovered == 1 and "" or "s") .. " in no mex region",
				first
			)
		end
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.MexRegion))

Policies.On(MexRegionsDescribe)
	.Answer(MexRegionsDescribe.MexRegion, function(ctx)
		local region = ctx.region
		local description = { team = region.team, group = region.group }
		local spots = ctx.map.spots
		if spots and region.vertices then
			local count, worth = 0, 0.0
			for _, spot in ipairs(spots) do
				if RegionsApi.Contains(spot.x, spot.z, region.vertices) then
					count = count + 1
					worth = worth + (spot.worth or 0)
				end
			end
			-- a thousandth of the metal map's sum is what the game floats over a spot: a T1 mex's income
			description.spots, description.worth = count, worth / 1000
		end
		return description
	end)
	.When(RegionsApi.OfType(RegionsApi.Enums.Types.MexRegion))
	.Before(Regions.Describe.Nobody)

---@class (partial) TransferContract
local Contract = {}
Contract.MexRegionsSet = MexRegionsSet
Contract.MexRegionsNames = MexRegionsNames
Contract.MexRegionsDescribe = MexRegionsDescribe

return Contract
