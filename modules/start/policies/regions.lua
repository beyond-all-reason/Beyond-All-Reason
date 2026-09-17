local Contract = VFS.Include("modules/start/contract.lua") ---@type StartContract
local RegionsContract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local RegionEnums = VFS.Include("modules/regions/enums.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Problems = VFS.Include("modules/regions/lib/problems.lua") ---@type RegionProblems

Policies.On(RegionsContract.Names).Apply(Contract.RegionsNames.FromTeam, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.Start then
		return
	end
	for i, region in ipairs(ctx.regions) do
		---@cast region StartRegion
		if region.team ~= nil then
			ctx.bases[i] = tostring(region.team)
		end
	end
end)

Policies.On(RegionsContract.CheckSet).Apply(Contract.RegionsSet.AreasDisjoint, function(ctx)
	if ctx.type.key ~= RegionEnums.Types.Start then
		return
	end
	local label = ctx.type.label:lower()
	for i, a in ipairs(ctx.regions) do
		for j, b in ipairs(ctx.regions) do
			if i ~= j and a.vertices and b.vertices and Geometry.Overlaps(a.vertices, b.vertices) then
				Problems.OfRegion(ctx, i, "overlaps " .. label .. " " .. ctx.names[j])
			end
		end
	end
end)
