local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Contract = VFS.Include("modules/regions/contract.lua") ---@type RegionsContract
local Types = VFS.Include("modules/regions/types.lua")
local Geometry = VFS.Include("modules/regions/lib/geometry.lua") ---@type RegionGeometry
local Names = VFS.Include("modules/regions/lib/names.lua") ---@type RegionNames
local Layout = VFS.Include("modules/regions/lib/layout.lua") ---@type RegionLayout
local Problems = VFS.Include("modules/regions/lib/problems.lua") ---@type RegionProblems
local Store = VFS.Include("modules/regions/lib/store.lua") ---@type RegionStore
local EditorFile = VFS.Include("modules/regions/lib/editor_file.lua") ---@type RegionEditorFile

---@class RegionsApi the regions module's public surface: the type registry, the store, the checks, the names, the descriptions, the layout codec and the editor's file
---@field Overlaps fun(a: { x: number, z: number }[], b: { x: number, z: number }[]): boolean
---@field Contains fun(x: number, z: number, vertices: { x: number, z: number }[]): boolean
---@field ProblemLine fun(problem: RegionProblem): string the message, prefixed with the region's name when it concerns one
---@field GeometryOf fun(vertices: { x: number, z: number }[]): RegionGeometryKey|nil the geometry kind implied by the vertex count
---@field EncodeLayout fun(layout: table): string|nil the layout in the modoption's string form
---@field DecodeLayout fun(raw: string): table|nil
---@field LayoutFromStartboxArrangement fun(arrangement: table|nil): table|nil SHIM: converts one arrangement from the old startbox mod options into a region layout
local Api = {}

---@param kind RegionType
---@param regions Region[]
---@return { name: string, derived: boolean }[] by index
local function namesOf(kind, regions)
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	---@type RegionNamesContext
	local ctx = { type = kind, regions = regions, bases = {} }
	ModuleHandler.Evaluate(pipelines.names, ctx)
	return Names.Of(regions, ctx.bases)
end

---@return RegionTypeKey[] order
---@return table<string, RegionType> byKey
function Api.Types()
	return Types.order, Types.byKey
end

---@return string twelve hex digits
local function mintId()
	return string.format("%06x%06x", math.random(0, 0xffffff), math.random(0, 0xffffff))
end

---@param typeKey RegionTypeKey
---@param fields table|nil the region's fields and shape; adopted, not copied. An id already on it is kept (a region read back from a file)
---@return Region
function Api.Create(typeKey, fields)
	local region = fields or {} ---@type Region
	region.type = typeKey
	region.id = region.id or mintId()
	region.tags = region.tags or {}
	return region
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
---@param env table|nil caller-supplied map data for the type owner's set rules; see RegionSetContext.env
---@return RegionProblem[] problems each about one region or about the set as a whole
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
---@param regions Region[] every region of the type; derived names are numbered against siblings
---@return { name: string, derived: boolean }[] display name per region, by index
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
---@return string|nil reason why the layout could not be parsed
function Api.ParseLayout(layout, typeKey, mapSizeX, mapSizeZ)
	local kind = Types.byKey[typeKey]
	if not kind then
		return nil, "unknown region type " .. tostring(typeKey)
	end
	local regions, reason = Layout.Parse(layout, kind, mapSizeX, mapSizeZ)
	for _, region in ipairs(regions or {}) do
		Api.Create(typeKey, region) -- every region the api hands out has an id; a layout without them (the startbox shim's) gets them here
	end
	return regions, reason
end

-- The store: the regions of this Lua state, in one insertion-ordered list keyed by id.
-- The editor puts, edits and removes; the game loads a layout into it and reads.

---@return RegionStore
local function store()
	local state = ModuleHandler.State(Modules.Regions)
	state.store = state.store or Store.New()
	return state.store
end

---@param region Region its type set; an id is given when it has none. Already stored: kept in place. New: appended, or ahead of beforeId
---@param beforeId string|nil
---@return Region
function Api.Put(region, beforeId)
	Api.Create(region.type, region)
	return Store.Put(store(), region, beforeId)
end

---@param id string
---@return Region|nil removed
function Api.Remove(id)
	return Store.Remove(store(), id)
end

---@param id string
---@return Region|nil
function Api.Get(id)
	return store().byId[id]
end

---@param typeKey RegionTypeKey|nil every type when nil
---@return Region[] in insertion order; a new table
function Api.All(typeKey)
	return Store.All(store(), typeKey)
end

---@param typeKey RegionTypeKey|nil every type when nil
---@return Region[] removed
function Api.Clear(typeKey)
	return Store.Clear(store(), typeKey)
end

---@return integer bumped on every change to the store
function Api.Revision()
	return store().revision
end

---@param id string
---@param key string a field the region's type declares
---@param value any "" and nil clear the field; an integer field takes a number or a numeric string
---@return boolean ok
---@return string|nil reason
function Api.Set(id, key, value)
	local region = store().byId[id]
	local kind = region and Types.byKey[region.type]
	if not kind then
		return false, "no such region"
	end
	local declared = nil
	for _, field in ipairs(kind.fields) do
		if field.key == key then
			declared = field
		end
	end
	if not declared then
		return false, "a " .. kind.label:lower() .. " has no " .. tostring(key)
	end
	if value == "" then
		value = nil
	end
	if value ~= nil and declared.kind == "integer" then
		value = tonumber(value)
		if value == nil then
			return false, declared.label .. " must be a number"
		end
	end
	region[key] = value
	store().revision = store().revision + 1
	return true, nil
end

---@param id string
---@param tag string trimmed; empty adds nothing
---@return boolean added
function Api.Tag(id, tag)
	local region = store().byId[id]
	tag = tag and tag:match("^%s*(.-)%s*$") or ""
	if not region or tag == "" then
		return false
	end
	region.tags = region.tags or {}
	for _, existing in ipairs(region.tags) do
		if existing == tag then
			return false
		end
	end
	region.tags[#region.tags + 1] = tag
	store().revision = store().revision + 1
	return true
end

---@param id string
---@param index integer
---@return boolean removed
function Api.Untag(id, index)
	local region = store().byId[id]
	if region and region.tags and region.tags[index] then
		table.remove(region.tags, index)
		store().revision = store().revision + 1
		return true
	end
	return false
end

---@param typeKey RegionTypeKey
---@param env table|nil see RegionSetContext.env
---@return RegionProblem[] the set check over every stored region of the type
function Api.Problems(typeKey, env)
	return Api.CheckSet(typeKey, Api.All(typeKey), env)
end

---@param typeKey RegionTypeKey
---@return table<string, string> display name by region id, over every stored region of the type
function Api.NamesById(typeKey)
	local regions = Api.All(typeKey)
	local out = {}
	for i, named in ipairs(Api.Names(typeKey, regions)) do
		out[regions[i].id] = named.name
	end
	return out
end

---@param typeKey RegionTypeKey
---@return table<string, any[]> for each field that offers suggestions, the distinct values stored regions of the type carry, sorted
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

-- The editor's file: every stored region, with the anchors it was drawn with.

---@param mapName string
---@return string lua source
function Api.SerializeEditorFile(mapName)
	return EditorFile.Serialize(Api.All(), Types.byKey, mapName)
end

---@param data table what the editor file returned when included
---@return Region[] regions ready for Put; the file's ids kept
---@return string|nil reason when the data is not an editor file
function Api.ReadEditorFile(data)
	local regions, reason = EditorFile.Read(data, Types.byKey)
	for _, region in ipairs(regions) do
		Api.Create(region.type, region)
	end
	return regions, reason
end

---@param path string
---@param mapName string
---@return boolean ok
---@return string|nil reason
function Api.SaveEditorFile(path, mapName)
	local file = io.open(path, "w")
	if not file then
		return false, "could not write " .. path
	end
	file:write(Api.SerializeEditorFile(mapName))
	file:close()
	return true, nil
end

---@param path string
---@return Region[]|nil regions put into the store, replacing what was there; nil when there is no such file
---@return string|nil reason
function Api.LoadEditorFile(path)
	if not VFS.FileExists(path, VFS.RAW_FIRST) then
		return nil, "no file at " .. path
	end
	local ok, data = pcall(VFS.Include, path, nil, VFS.RAW_FIRST)
	if not ok then
		return nil, tostring(data)
	end
	local regions, reason = Api.ReadEditorFile(data)
	if reason then
		return nil, reason
	end
	Api.Clear()
	for _, region in ipairs(regions) do
		Api.Put(region)
	end
	return regions, nil
end

Api.TessellateControls = EditorFile.Tessellate

---@param region Region
---@param env table|nil caller-supplied map data for the type owner's lines; see RegionDescribeContext.env
---@return { [1]: string, [2]: string }[] lines { label, value } pairs: the shape's lines first, then the type owner's
function Api.Describe(region, env)
	local kind = Types.byKey[region.type]
	if not kind then
		return {}
	end
	local pipelines = ModuleHandler.LoadPolicies(Modules.Regions) ---@type RegionsPipelines
	---@type RegionDescribeContext
	local ctx = { type = kind, region = region, env = env or {}, lines = {} }
	ModuleHandler.Evaluate(pipelines.describe, ctx)
	return ctx.lines
end

Api.Overlaps = Geometry.Overlaps
Api.Contains = Geometry.Contains
Api.GeometryOf = Geometry.Of
Api.ProblemLine = Problems.Line

Api.EncodeLayout = Layout.Encode
Api.DecodeLayout = Layout.Decode
Api.LayoutFromStartboxArrangement = Layout.FromStartboxArrangement -- SHIM, see lib/layout.lua

return Api
