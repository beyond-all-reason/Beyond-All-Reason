local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Types = VFS.Include("modules/regions/types.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Names = VFS.Include("modules/regions/lib/names.lua") ---@type RegionNames
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local Problems = VFS.Include("modules/regions/lib/problems.lua") ---@type RegionProblems

---@class RegionsApi what the game's files and the other modules call: the registry, the rules, the names and the layout codec
---@field Overlaps fun(a: { x: number, z: number }[], b: { x: number, z: number }[]): boolean
---@field Contains fun(x: number, z: number, vertices: { x: number, z: number }[]): boolean
---@field ProblemLine fun(problem: RegionProblem): string the message, led by the region's name when it is about one
---@field GeometryOf fun(vertices: { x: number, z: number }[]): RegionGeometryKey|nil what a region is drawn as, from its vertices alone
---@field EncodeLayout fun(layout: table): string|nil the layout as the modoption carries it
---@field DecodeLayout fun(raw: string): table|nil
---@field LayoutFromStartboxArrangement fun(arrangement: table|nil): table|nil SHIM: one arrangement of the old startbox mod options, as a region layout
local Api = {}

---@param kind RegionType
---@param regions Region[]
---@return { name: string, derived: boolean }[] by index
local function namesOf(kind, regions)
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	---@type RegionNamesContext
	local ctx = { type = kind, regions = regions, bases = {} }
	ModuleHandler.Evaluate(pipelines.names, ctx)
	return Names.Of(kind, regions, ctx.bases)
end

---@return RegionTypeKey[] order
---@return table<string, RegionType> byKey
function Api.Types()
	return Types.order, Types.byKey
end

---@param typeKey RegionTypeKey
---@param region Region
---@param siblings Region[]|nil the other regions of the type
---@param fieldsOnly boolean|nil
---@return string[] problems
function Api.Check(typeKey, region, siblings, fieldsOnly)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { "unknown region type " .. tostring(typeKey) }
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	local all = { region }
	for _, other in ipairs(siblings or {}) do
		if other ~= region then
			all[#all + 1] = other
		end
	end
	local names = {} ---@type table<Region, string>
	for i, named in ipairs(namesOf(kind, all)) do
		names[all[i]] = named.name
	end
	---@type RegionCheckContext
	local ctx = {
		type = kind,
		region = region,
		siblings = siblings or {},
		names = names,
		fieldsOnly = fieldsOnly,
		problems = {},
	}
	ModuleHandler.Evaluate(pipelines.check, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[] every region of the type
---@param env RegionEnv|nil what the map knows, for the rules that judge the set against it
---@return RegionProblem[] problems each about one region, by index, or about the set as a whole
function Api.CheckSet(typeKey, regions, env)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { { message = "unknown region type " .. tostring(typeKey) } }
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	local names = {} ---@type string[]
	for i, named in ipairs(namesOf(kind, regions)) do
		names[i] = named.name
	end
	---@type RegionSetContext
	local ctx = { type = kind, regions = regions, names = names, env = env or {}, problems = {} }
	ModuleHandler.Evaluate(pipelines.check_set, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[] every region of the type, since a derived name counts its siblings
---@return { name: string, derived: boolean }[] what each region is called, by index
function Api.Names(typeKey, regions)
	local kind = Types.byKey[typeKey]
	if not kind then
		return {}
	end
	return namesOf(kind, regions)
end

---@param regions Region[] of any types
---@param mapSizeX number
---@param mapSizeZ number
---@return table layout every type's regions under its key, in the startbox 0..200 space
function Api.ExportLayout(regions, mapSizeX, mapSizeZ)
	return Layout.Export(regions, Types.byKey, mapSizeX, mapSizeZ)
end

---@param layout table
---@param typeKey RegionTypeKey the type whose regions to read
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string|nil reason why not
function Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ)
	local kind = Types.byKey[typeKey]
	if not kind then
		return nil, "unknown region type " .. tostring(typeKey)
	end
	return Layout.Parse(layout, kind, mapSizeX, mapSizeZ)
end

---@param region Region
---@param env { spots: table[]|nil, starts: table[]|nil, modOptions: table|nil }
---@return table<string, any> facts by the contract's keys
function Api.Facts(region, env)
	env = env or {}
	---@type RegionFactsContext
	local ctx = { region = region, spots = env.spots, starts = env.starts }
	return ModuleHandler.Enrich(Contract.Facts, env.modOptions or {}, ctx)
end

---@param facts table<string, any>
---@return { [1]: string, [2]: string }[]
function Api.FactLines(facts)
	local lines = {}
	local area = facts[Contract.Facts.Area]
	if area and area > 0 then
		lines[#lines + 1] = { "Area", string.format("%.0f x %.0f elmos equivalent", math.sqrt(area), math.sqrt(area)) }
	end
	local centre = facts[Contract.Facts.Centre]
	if centre then
		lines[#lines + 1] = { "Centre", string.format("%d, %d", centre.x, centre.z) }
	end
	local spots = facts[Contract.Facts.MetalSpots]
	if spots then
		lines[#lines + 1] = {
			"Metal spots",
			spots.count .. (spots.count > 0 and string.format(" (%.1f worth)", spots.worth) or ""),
		}
	end
	local nearest = facts[Contract.Facts.NearestStart]
	if nearest then
		lines[#lines + 1] =
			{ "Nearest start", string.format("ally team %d, %.0f elmos", nearest.allyTeam, nearest.distance) }
	end
	return lines
end

Api.Overlaps = Geometry.Overlaps
Api.Contains = Geometry.Contains
Api.GeometryOf = Geometry.Of
Api.ProblemLine = Problems.Line

Api.EncodeLayout = Layout.Encode
Api.DecodeLayout = Layout.Decode
Api.LayoutFromStartboxArrangement = Layout.FromStartboxArrangement -- SHIM, see lib/layout.lua

return Api
