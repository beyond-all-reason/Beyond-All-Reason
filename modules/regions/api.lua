local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Enums = require("modules/regions/enums")
local Geometry = require("modules/regions/lib/geometry")
local Hull = require("modules/regions/lib/hull")
local Layout = require("modules/regions/lib/layout")
local Names = require("modules/regions/lib/names")
local Problems = require("modules/regions/lib/problems")
local Repository = require("modules/repository")
local Types = require("modules/regions/types")
local state = require("modules/regions/state")

---@class RegionsApi
---@field Overlaps fun(a: { x: number, z: number }[], b: { x: number, z: number }[]): boolean
---@field Contains fun(x: number, z: number, vertices: { x: number, z: number }[]): boolean
---@field ProblemLine fun(problem: RegionProblem): string
---@field OfType fun(key: RegionTypeKey): fun(ctx: any): boolean the precondition for a step that is one type's: the context is about that type
---@field Shape fun(region: Region): RegionShape
---@field ProblemLines fun(typeKey: RegionTypeKey, regions: Region[], map: RegionMap|nil): string[]
---@field ProblemWith fun(ctx: RegionSetContext<Region>, index: integer, message: string)
---@field ProblemAt fun(ctx: RegionSetContext<Region>, message: string, at: { x: number, z: number }|nil)
---@field Enums RegionEnums
---@field Geometry RegionGeometry
---@field Hull RegionHull
---@field GeometryOf fun(vertices: { x: number, z: number }[]): RegionGeometryKey|nil
---@field EncodeLayout fun(layout: table): string|nil
---@field DecodeLayout fun(raw: string): table|nil
local Api = {}

---@param kind RegionType
---@param regions Region[]
---@return { name: string, derived: boolean }[]
local function namesOf(kind, regions)
	---@type RegionsContract
	local Regions = ModuleHandler.Contract(Modules.Regions)
	---@type RegionNamesContext<Region>
	local ctx = { type = kind, regions = regions, proposed = {} }
	ModuleHandler.Evaluate(Regions.Names, ctx)
	return Names.Of(regions, ctx.proposed)
end

---@return RegionTypeKey[] order
---@return table<string, RegionType> byKey
function Api.Types()
	return Types.order, Types.byKey
end

-- A region that is not the repository's: the match's start for an ally team, a region read from a layout. Its
-- identity is the caller's to give.
---@param typeKey RegionTypeKey
---@param fields table its id, and whatever else it carries
---@return Region
function Api.New(typeKey, fields)
	assert(type(fields) == "table" and type(fields.id) == "string", "Regions.New: a region has an id")
	fields.type = typeKey
	fields.vertices = fields.vertices or {}
	return fields --[[@as Region]]
end

---@param typeKey RegionTypeKey
---@param region Region
---@param siblings Region[]|nil
---@param fieldsOnly boolean|nil
---@return RegionProblem[]
function Api.Check(typeKey, region, siblings, fieldsOnly)
	---@type RegionsContract
	local Regions = ModuleHandler.Contract(Modules.Regions)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { { message = "unknown region type " .. tostring(typeKey) } }
	end
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
	---@type RegionCheckContext<Region>
	local ctx = {
		type = kind,
		region = region,
		siblings = siblings or {},
		names = names,
		fieldsOnly = fieldsOnly,
		problems = {},
	}
	ModuleHandler.Evaluate(Regions.Check, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[]
---@param map RegionMap|nil
---@return RegionProblem[]
function Api.CheckSet(typeKey, regions, map)
	---@type RegionsContract
	local Regions = ModuleHandler.Contract(Modules.Regions)
	local kind = Types.byKey[typeKey]
	if not kind then
		return { { message = "unknown region type " .. tostring(typeKey) } }
	end
	local names = {} ---@type string[]
	for i, named in ipairs(namesOf(kind, regions)) do
		names[i] = named.name
	end
	---@type RegionSetContext<Region>
	local ctx = { type = kind, regions = regions, names = names, map = map or {}, problems = {} }
	ModuleHandler.Evaluate(Regions.CheckSet, ctx)
	return ctx.problems
end

---@param typeKey RegionTypeKey
---@param regions Region[]
---@return { name: string, derived: boolean }[]
function Api.Names(typeKey, regions)
	local kind = Types.byKey[typeKey]
	if not kind then
		return {}
	end
	return namesOf(kind, regions)
end

---@param regions Region[]
---@param mapSizeX number
---@param mapSizeZ number
---@return table
function Api.ExportLayout(regions, mapSizeX, mapSizeZ)
	return Layout.Export(regions, Types.byKey, mapSizeX, mapSizeZ)
end

---@param layout table
---@param typeKey RegionTypeKey
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string|nil reason
function Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ)
	local kind = Types.byKey[typeKey]
	if not kind then
		return nil, "unknown region type " .. tostring(typeKey)
	end
	return Layout.Parse(layout, kind, mapSizeX, mapSizeZ)
end

-- The repository: the regions of this Lua state that checked out, in order, each a copy that is regions' own. What
-- is offered is any table that says its type and carries a region's data; what is held is a Region.

---@param points { x: number, z: number, strength: number|nil }[]|nil
---@return { x: number, z: number, strength: number|nil }[]|nil
local function copyOf(points)
	if type(points) ~= "table" then
		return nil
	end
	local out = {}
	for i, p in ipairs(points) do
		out[i] = { x = p.x, z = p.z, strength = p.strength }
	end
	return out
end

---@class RegionRefusal
---@field candidate table what was offered
---@field problems RegionProblem[]

---@param message string
---@return RegionProblem[]
local function problem(message)
	return { { message = message } }
end

-- What a candidate becomes on entry: regions' own copy of what its type declares, once it checks out beside the
-- regions it would stand with. Its identity is not among what it declares: that is given, never taken.
---@param kind RegionType
---@param candidate table
---@param beside Region[] the regions held, less the one it would replace
---@return Region|nil region
---@return RegionProblem[]|nil problems
local function admit(kind, candidate, beside)
	local region = {
		type = kind.key,
		kind = candidate.kind,
		vertices = copyOf(candidate.vertices) or {},
		controls = copyOf(candidate.controls),
	}
	---@cast region Region its id is given after, on entry
	if region.kind == "spline" and region.controls ~= nil then
		region.vertices = Layout.Tessellate(region.controls)
	end
	for _, field in ipairs(kind.fields) do
		local value = candidate[field.key]
		if value == "" then
			value = nil
		end
		if field.kind == "points" then
			value = copyOf(value)
		elseif field.kind == "integer" and type(value) == "string" then
			value = tonumber(value) or value
		end
		region[field.key] = value
	end
	local siblings = {} ---@type Region[]
	for _, other in ipairs(beside) do
		if other.type == kind.key then
			siblings[#siblings + 1] = other
		end
	end
	local problems = Api.Check(kind.key, region, siblings)
	if #problems > 0 then
		return nil, problems
	end
	return region, nil
end

---@return Repository<Region>
local function repository()
	local regions = state.regions
	if regions == nil then
		---@type Repository<Region>
		regions = Repository.New()
		state.regions = regions
	end
	return regions
end

---@param typeKey RegionTypeKey|nil
---@return (fun(region: Region): boolean)|nil
local function ofType(typeKey)
	if typeKey == nil then
		return nil
	end
	return function(region)
		return region.type == typeKey
	end
end

-- A new region, checked beside those held, under the id the repository gives it.
---@param candidate table any table that says its type and carries a region's data; an id it carries is not taken
---@return Region|nil region
---@return RegionProblem[]|nil problems
function Api.Create(candidate)
	local kind = Types.byKey[candidate.type]
	if not kind then
		return nil, problem("unknown region type " .. tostring(candidate.type))
	end
	local region, problems = admit(kind, candidate, repository().All())
	if region == nil then
		return nil, problems
	end
	return repository().Create(region), nil
end

-- The region under an id, replaced whole by what is offered, checked beside the rest; or left as it was.
---@param id string
---@param candidate table the region's data; its id and type are the held region's
---@return Region|nil region
---@return RegionProblem[]|nil problems
function Api.Update(id, candidate)
	local held = repository().Get(id)
	if held == nil then
		return nil, problem("no region with id " .. tostring(id))
	end
	local beside = repository().All(function(other)
		return other.id ~= id
	end)
	local region, problems = admit(Types.byKey[held.type], candidate, beside)
	if region == nil then
		return nil, problems
	end
	region.id = id
	return repository().Update(region), nil
end

---@param id string
---@return Region|nil
function Api.Delete(id)
	return repository().Delete(id)
end

---@param id string
---@return Region|nil
function Api.Get(id)
	return repository().Get(id)
end

-- What was saved, read back: the repository holds these, each under the id it was saved with. Each is checked beside
-- those of the set admitted ahead of it; what does not check out, or brings no id or one already taken, is refused.
---@param candidates table[]
---@return Region[] loaded
---@return RegionRefusal[] refused
function Api.Load(candidates)
	local loaded, refused = {}, {} ---@type Region[], RegionRefusal[]
	local taken = {} ---@type table<string, boolean>
	for _, candidate in ipairs(candidates) do
		local kind = Types.byKey[candidate.type]
		local region, problems
		if type(candidate.id) ~= "string" then
			problems = problem("a saved region has an id")
		elseif taken[candidate.id] then
			problems = problem("a region with id " .. candidate.id .. " is already loaded")
		elseif not kind then
			problems = problem("unknown region type " .. tostring(candidate.type))
		else
			region, problems = admit(kind, candidate, loaded)
		end
		if region == nil then
			refused[#refused + 1] = { candidate = candidate, problems = problems or {} }
		else
			region.id = candidate.id
			taken[candidate.id] = true
			loaded[#loaded + 1] = region
		end
	end
	return repository().Load(loaded), refused
end

---@param typeKey RegionTypeKey|nil
---@return Region[]
function Api.All(typeKey)
	return repository().All(ofType(typeKey))
end

---@param typeKey RegionTypeKey|nil
---@return Region[]
function Api.Clear(typeKey)
	return repository().Clear(ofType(typeKey))
end

---@return integer
function Api.Revision()
	return repository().Revision()
end

---@param typeKey RegionTypeKey
---@param map RegionMap|nil
---@return RegionProblem[]
function Api.Problems(typeKey, map)
	return Api.CheckSet(typeKey, Api.All(typeKey), map)
end

---@param typeKey RegionTypeKey
---@return table<string, string>
function Api.NamesById(typeKey)
	local regions = Api.All(typeKey)
	local out = {}
	for i, named in ipairs(Api.Names(typeKey, regions)) do
		local region = regions[i]
		if region and region.id then
			out[region.id] = named.name
		end
	end
	return out
end

---@param typeKey RegionTypeKey
---@return table<string, any[]>
function Api.Suggestions(typeKey)
	local kind = Types.byKey[typeKey]
	local out = {}
	for _, field in ipairs(kind and kind.fields or {}) do
		if field.suggest then
			local seen, values = {}, {}
			for _, region in ipairs(Api.All(typeKey)) do
				local value = region[field.key]
				if value ~= nil and not seen[value] then
					seen[value] = true
					values[#values + 1] = value
				end
			end
			table.sort(values)
			out[field.key] = values
		end
	end
	return out
end

-- The layout is the one serialized form; a file holding one is `return <layout>` as Lua.

---@param layout table
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]
function Api.ParseAllLayout(layout, mapSizeX, mapSizeZ)
	local out = {}
	for _, typeKey in ipairs(Types.order) do
		if type(layout) == "table" and type(layout.regions) == "table" and layout.regions[typeKey] then
			for _, region in ipairs(Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ) or {}) do
				out[#out + 1] = region
			end
		end
	end
	return out
end

---@param regions Region[]
---@param mapSizeX number
---@param mapSizeZ number
---@param header string|nil
---@return string
function Api.SerializeLayout(regions, mapSizeX, mapSizeZ, header)
	return Layout.Serialize(Api.ExportLayout(regions, mapSizeX, mapSizeZ), Types.order, Types.byKey, header)
end

---@param path string
---@param mapSizeX number
---@param mapSizeZ number
---@param header string|nil
---@return boolean ok
---@return string|nil reason
function Api.SaveLayoutFile(path, mapSizeX, mapSizeZ, header)
	local file = io.open(path, "w")
	if not file then
		return false, "could not write " .. path
	end
	file:write(Api.SerializeLayout(Api.All(), mapSizeX, mapSizeZ, header))
	file:close()
	return true, nil
end

---@param path string
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions what the repository now holds
---@return string|nil reason
---@return RegionRefusal[]|nil refused what the file held that did not check out
function Api.LoadLayoutFile(path, mapSizeX, mapSizeZ)
	if not VFS.FileExists(path, VFS.RAW_FIRST) then
		return nil, "no file at " .. path
	end
	local ok, layout = pcall(VFS.Include, path, nil, VFS.RAW_FIRST)
	if not ok then
		return nil, tostring(layout)
	end
	if type(layout) ~= "table" or type(layout.regions) ~= "table" then
		return nil, path .. " does not return a layout: { regions = { <type> = { ... } } }"
	end
	local created, refused = Api.Load(Api.ParseAllLayout(layout, mapSizeX, mapSizeZ))
	return created, nil, refused
end

Api.Tessellate = Layout.Tessellate

---@class RegionShape
---@field area number
---@field centre { x: number, z: number }

---@param region Region
---@return RegionShape
function Api.Shape(region)
	local x, z = Geometry.Centroid(region.vertices)
	return { area = Geometry.Area(region.vertices), centre = { x = x, z = z } }
end

---@param region Region
---@param map RegionMap|nil
---@return RegionDescription|nil
function Api.Describe(region, map)
	---@type RegionsContract
	local Regions = ModuleHandler.Contract(Modules.Regions)
	local kind = Types.byKey[region.type]
	if not kind then
		return nil
	end
	---@type RegionDescribeContext<Region>
	local ctx = { type = kind, region = region, map = map or {} }
	return ModuleHandler.Evaluate(Regions.Describe, ctx) or nil
end

Api.Enums = { Geometry = Enums.Geometry, Types = Types.keys }
Api.Geometry = Geometry
Api.Hull = Hull
Api.Overlaps = Geometry.Overlaps
Api.Contains = Geometry.Contains
Api.GeometryOf = Geometry.Of
Api.ProblemLine = Problems.Line

---@param key RegionTypeKey
---@return fun(ctx: any): boolean the precondition a step that is one type's is When'd with: the context is about that type
function Api.OfType(key)
	return function(ctx)
		return ctx.type.key == key
	end
end

---@param typeKey RegionTypeKey
---@param regions Region[]
---@param map RegionMap|nil
---@return string[]
function Api.ProblemLines(typeKey, regions, map)
	local lines = {} ---@type string[]
	for i, problem in ipairs(Api.CheckSet(typeKey, regions, map)) do
		lines[i] = Problems.Line(problem)
	end
	return lines
end
Api.ProblemWith = Problems.OfRegion
Api.ProblemAt = Problems.OfSet

Api.EncodeLayout = Layout.Encode
Api.DecodeLayout = Layout.Decode

return Api
