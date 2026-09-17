local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Problems = VFS.Include("modules/regions/lib/problems.lua") ---@type RegionProblems

---@param ctx RegionCheckContext
---@param region Region
---@param field RegionField
---@return any the field's value; for the name, what the region is called even when it carries none
local function valueOf(ctx, region, field)
	if field.key == "name" then
		return ctx.names[region]
	end
	return region[field.key]
end

Policies.On(Contract.Check)
	.Apply(Contract.Check.Shape, function(ctx)
		if ctx.fieldsOnly then
			return
		end
		local vertices = ctx.region.vertices or {}
		local shape = Geometry.Of(vertices)
		if shape == nil then
			ctx.problems[#ctx.problems + 1] = #vertices == 2 and "two vertices make neither a point nor a polygon"
				or "a region is a point or a polygon"
			return
		end
		local allowed = false
		for _, g in ipairs(ctx.type.geometries) do
			allowed = allowed or g == shape
		end
		if not allowed then
			ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " cannot be a " .. shape
		end
	end)
	.Apply(Contract.Check.Fields, function(ctx)
		for _, field in ipairs(ctx.type.fields) do
			local value = valueOf(ctx, ctx.region, field)
			local missing = value == nil or value == ""
			if field.required and missing then
				ctx.problems[#ctx.problems + 1] = "a " .. ctx.type.label:lower() .. " needs a " .. field.label:lower()
			elseif not missing and field.kind == "integer" and type(value) ~= "number" then
				ctx.problems[#ctx.problems + 1] = field.label .. " must be a number"
			end
			if field.unique and not missing then
				local scope = type(field.unique) == "string" and field.unique or nil
				for _, other in ipairs(ctx.siblings) do
					if
						other ~= ctx.region
						and valueOf(ctx, other, field) == value
						and (scope == nil or other[scope] == ctx.region[scope])
					then
						ctx.problems[#ctx.problems + 1] = "a "
							.. ctx.type.label:lower()
							.. " with "
							.. field.label:lower()
							.. " "
							.. tostring(value)
							.. " already exists"
						break
					end
				end
			end
		end
	end)

Policies.On(Contract.Names).Apply(Contract.Names.Label, function(ctx)
	local label = ctx.type.label:lower():gsub(" ", "_")
	for i in ipairs(ctx.regions) do
		ctx.bases[i] = label
	end
end)

Policies.On(Contract.CheckSet).Apply(Contract.CheckSet.Each, function(ctx)
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	local names = {} ---@type table<Region, string>
	for i, region in ipairs(ctx.regions) do
		names[region] = ctx.names[i]
	end
	for i, region in ipairs(ctx.regions) do
		---@type RegionCheckContext
		local one = { type = ctx.type, region = region, siblings = ctx.regions, names = names, problems = {} }
		ModuleHandler.Evaluate(pipelines.check, one)
		for _, problem in ipairs(one.problems) do
			Problems.OfRegion(ctx, i, problem)
		end
	end
end)

Policies.On(Contract.Facts)
	.Default(Contract.Facts.Area, function(ctx)
		return ctx.region.vertices and Geometry.Area(ctx.region.vertices) or 0
	end)
	.Default(Contract.Facts.Centre, function(ctx)
		local x, z = Geometry.Centroid(ctx.region.vertices or {})
		return { x = x, z = z }
	end)
	.Default(Contract.Facts.MetalSpots, function(ctx)
		if not ctx.spots or not ctx.region.vertices then
			return nil
		end
		local count, worth = 0, 0.0
		for _, spot in ipairs(ctx.spots) do
			if Geometry.Contains(spot.x, spot.z, ctx.region.vertices) then
				count = count + 1
				worth = worth + (spot.worth or 0)
			end
		end
		return { count = count, worth = worth }
	end)
	.Default(Contract.Facts.NearestStart, function(ctx)
		if not ctx.starts or #ctx.starts == 0 then
			return nil
		end
		local cx, cz = Geometry.Centroid(ctx.region.vertices or {})
		local best, bestD = ctx.starts[1], math.huge
		for _, start in ipairs(ctx.starts) do
			local d = Geometry.Distance(cx, cz, start.x, start.z)
			if d < bestD then
				best, bestD = start, d
			end
		end
		if not best then
			return nil
		end
		return { allyTeam = best.allyTeam, distance = bestD }
	end)
