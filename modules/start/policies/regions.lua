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

Policies.On(RegionsContract.Describe).Apply(Contract.RegionsDescribe.NearestStart, function(ctx)
	local starts = (ctx.env --[[@as StartRegionEnv]]).starts
	if not starts or #starts == 0 then
		return
	end
	local vertices = ctx.region.vertices or {}
	for _, start in ipairs(starts) do
		if Geometry.Contains(start.x, start.z, vertices) then
			ctx.lines[#ctx.lines + 1] = { "Start", string.format("ally team %d starts inside", start.allyTeam) }
			return
		end
	end
	local cx, cz = Geometry.Centroid(vertices)
	local best, bestD = starts[1], math.huge
	for _, start in ipairs(starts) do
		local d = Geometry.Distance(cx, cz, start.x, start.z)
		if d < bestD then
			best, bestD = start, d
		end
	end
	ctx.lines[#ctx.lines + 1] =
		{ "Nearest start", string.format("ally team %d, %.0f elmos from the centre", best.allyTeam, bestD) }
end)
