-- Isolated engine boundaries; also runnable with plain Lua 5.1 describe/it shims.
local ROOT = "luaui/images/decals_gl4"
local OLD = ROOT .. "/groundScars/old_a.tga"
local NEW = ROOT .. "/nested/new_a.png"
local NEW_NORMAL = ROOT .. "/nested/new_n.png"

local function equal(expected, actual)
	assert(expected == actual, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function near(expected, actual)
	assert(math.abs(expected - actual) < 0.000001, "expected " .. expected .. ", got " .. tostring(actual))
end

local function loadIn(path, env)
	return setfenv(assert(loadfile(path)), env)()
end

local function fixture(options)
	options = options or {}
	local calls = { created = {}, added = {}, deleted = {}, warnings = {}, vbos = {}, draws = {}, bound = {} }
	local env = setmetatable({ Spring = {}, VFS = {}, gl = {}, GL = {}, widget = {}, WG = {} }, { __index = _G })
	env.Spring.Echo = function(message)
		calls.warnings[#calls.warnings + 1] = message
	end
	env.Spring.GetConfigInt = function(name, default)
		return options[name] or default
	end
	env.VFS.DirList = function(directory, pattern, _, recursive)
		equal(ROOT, directory)
		equal("*.png", pattern)
		assert(recursive)
		return options.files or { NEW_NORMAL, NEW }
	end
	env.gl.TextureInfo = function(path)
		if options.invalid == path then
			return nil
		end
		return { xsize = 128, ysize = 64 }
	end
	env.gl.CreateTextureAtlas = function(x, y, allocator)
		local index = #calls.created + 1
		if options.createError == index then
			error("creation failed")
		end
		calls.created[index] = { x, y, allocator }
		return "*runtime" .. index
	end
	env.gl.AddAtlasTexture = function(atlas, path, key)
		if options.addError == path then
			error("addition failed")
		end
		calls.added[#calls.added + 1] = { atlas = atlas, path = path, key = key }
	end
	env.gl.FinalizeTextureAtlas = function(atlas)
		return atlas ~= options.finalizeError
	end
	env.gl.GetAtlasTexture = function()
		if options.queryError then
			error("query failed")
		end
		return unpack(options.uv or { 0.1, 0.4, 0.2, 0.8 })
	end
	env.gl.DeleteTextureAtlas = function(atlas)
		calls.deleted[#calls.deleted + 1] = atlas
	end
	if options.noAPI then
		env.gl.AddAtlasTexture = nil
	end
	local diffuse = options.diffuse or { width = 1024, height = 1024, [OLD] = { 0.1, 0.2, 0.3, 0.4, 128, 64 } }
	local normal = options.normal or { [OLD:gsub("_a%.", "_n.")] = { 0.1, 0.2, 0.3, 0.4 } }
	local api = loadIn("luaui/Include/DecalAtlas.lua", env)
	local function create()
		return api.Create(diffuse, normal, ROOT)
	end
	return create, calls, env, diffuse, normal
end

describe("paired decal atlases", function()
	it("copies baked padding and orientation without mutating cached manifests", function()
		local create, calls, _, diffuse = fixture({ files = {} })
		for _ = 1, 2 do
			local atlas = create()
			local image = assert(atlas:Get(OLD:upper():gsub("/", "\\")))
			equal(0, image.atlasIndex)
			near(0.1 + 0.001953125, image.uv[1])
			near(0.7 - 0.0009765625, image.uv[3])
			atlas:Delete()
		end
		near(0.1, diffuse[OLD][1])
		near(0.3, diffuse[OLD][3])
		equal(0, #calls.created)
	end)

	it("discovers nested pairs and inserts both channels in identical sorted order", function()
		local other = ROOT .. "/footprints/new_a.png"
		local create, calls = fixture({
			files = {
				NEW_NORMAL,
				NEW,
				other:gsub("_a%.", "_n."),
				other,
				ROOT .. "/nested/new_h.png",
				ROOT .. "/nested/new_ORM.png",
			},
		})
		local atlas = create()
		equal(2, #calls.created)
		equal(0, calls.created[1][3])
		equal(4, #calls.added)
		equal(other, calls.added[1].path)
		equal(other:gsub("_a%.", "_n."), calls.added[2].path)
		equal(NEW, calls.added[3].path)
		equal(NEW_NORMAL, calls.added[4].path)
		equal(calls.added[1].key, calls.added[2].key)
		equal(calls.added[3].key, calls.added[4].key)
		equal(2, atlas.runtimeCount)
		equal(1, atlas:Get(NEW).atlasIndex)
		near(0.5, (atlas:Get(NEW).uv[3] + atlas:Get(NEW).uv[4]) / 2)
		atlas:Delete()
		atlas:Delete()
		equal(2, #calls.deleted)
	end)

	it("uses baked extension equivalents and stops packing after an offline rebuild", function()
		local bakedPNG = OLD:gsub("tga$", "png")
		local create, calls = fixture({ files = { bakedPNG, (bakedPNG:gsub("_a%.", "_n.")) } })
		equal(0, create():Get(bakedPNG).atlasIndex)
		equal(0, #calls.created)
		create, calls = fixture({
			diffuse = { width = 1024, height = 1024, [NEW] = { 0, 1, 0, 1, 128, 64 } },
			normal = { [NEW_NORMAL] = { 0, 1, 0, 1 } },
		})
		equal(0, create():Get(NEW).atlasIndex)
		equal(0, #calls.created)
	end)

	it("reverses runtime Y inside its own rectangle, without reflecting atlas rows", function()
		local create = fixture({ uv = { 0.1, 0.4, 0.2, 0.4 } })
		local image = assert(create():Get(NEW))
		near(0.4 - 0.2 * 8 / 512, image.uv[3])
		near(0.2 + 0.2 * 8 / 512, image.uv[4])
		assert(image.uv[3] < 0.4 and image.uv[4] > 0.2)
	end)

	it("keeps full-path identities distinct and skips incomplete or invalid pairs", function()
		for _, options in ipairs({ { files = { NEW } }, { invalid = NEW_NORMAL }, { noAPI = true } }) do
			local create, calls = fixture(options)
			local atlas = create()
			assert(atlas:Get(OLD) and not atlas:Get(NEW))
			equal(0, #calls.created)
			assert(#calls.warnings > 0)
		end
	end)

	it("destroys both atlases on partial creation, insertion, finalization or query failure", function()
		for _, options in ipairs({
			{ createError = 2 },
			{ addError = NEW_NORMAL },
			{ finalizeError = "*runtime1" },
			{ finalizeError = "*runtime2" },
			{ queryError = true },
		}) do
			local create, calls = fixture(options)
			local atlas = create()
			assert(atlas:Get(OLD) and not atlas:Get(NEW))
			assert(not atlas.runtimeAlbedo and not atlas.runtimeNormal)
			equal(#calls.created, #calls.deleted)
			equal(0, atlas.runtimeCount)
			atlas:Delete()
			equal(#calls.created, #calls.deleted)
		end
	end)

	it("clamps matching atlas limits to the GPU limit", function()
		local create, calls, env = fixture({ MaxTextureAtlasSizeX = 1024, MaxTextureAtlasSizeY = 2048 })
		env.gl.GetNumber = function()
			return 512
		end
		create()
		for _, dimensions in ipairs(calls.created) do
			equal(512, dimensions[1])
			equal(512, dimensions[2])
		end
	end)

	it("retains all shipped baked pairs without allocating runtime atlases", function()
		local diffuse = assert(loadfile(ROOT .. "/decalsgl4_atlas_diffuse.lua"))()
		local normal = assert(loadfile(ROOT .. "/decalsgl4_atlas_normal.lua"))()
		local create, calls = fixture({ diffuse = diffuse, normal = normal, files = {} })
		local atlas = create()
		local count = 0
		for path, uv in pairs(diffuse) do
			if type(uv) == "table" then
				assert(atlas:Get(path), path)
				count = count + 1
			end
		end
		assert(count > 0)
		equal(0, #calls.created)
	end)
end)

local function widgetFixture(options, saved)
	options = options or {}
	local _, calls, env, diffuse, normal = fixture(options)
	local function noop() end
	env.math = setmetatable({
		round = function(n, places)
			local factor = 10 ^ places
			return math.floor(n * factor + 0.5) / factor
		end,
	}, { __index = math })
	env.Platform = {}
	env.Game = { mapSizeX = 4096, mapSizeZ = 4096 }
	env.Script = {
		IsEngineMinVersion = function()
			return true
		end,
	}
	env.WeaponDefs = { [0] = { customParams = { nodecal = true } } }
	env.UnitDefNames = options.footprint and { raptor_land_swarmer_basic_t1_v1 = { id = 1 } } or {}
	env.Spring.GetGameFrame = function()
		return options.frame or 100
	end
	env.Spring.GetGroundHeight = function()
		return 10
	end
	env.Spring.GetModOptions = function()
		return {}
	end
	env.Spring.ValidUnitID = function()
		return true
	end
	env.Spring.GetUnitIsDead = function()
		return false
	end
	env.require = function(path)
		return path:find("diffuse", 1, true) and diffuse or normal
	end
	env.VFS.Include = function(path)
		if path == "mapinfo.lua" then
			return {}
		end
		return loadIn(path, env)
	end
	env.widgetHandler = {
		AddAction = noop,
		RemoveAction = noop,
		RegisterGlobal = noop,
		DeregisterGlobal = noop,
		RemoveWidget = function()
			calls.removed = true
		end,
	}
	local vao = {
		AttachVertexBuffer = noop,
		DrawArrays = function(_, _, count)
			calls.draws[#calls.draws + 1] = { count = count, albedo = calls.bound[7], normal = calls.bound[8] }
		end,
		DrawElements = function(_, _, _, _, count)
			calls.draws[#calls.draws + 1] = { count = count, albedo = calls.bound[7], normal = calls.bound[8] }
		end,
	}
	local function make(layout)
		local step = 0
		for _, attribute in ipairs(layout) do
			step = step + attribute.size
		end
		local vbo = {
			layout = layout,
			instanceStep = step,
			usedElements = 0,
			instanceData = {},
			instanceIDtoIndex = {},
			indextoInstanceID = {},
			instanceVBO = {},
			VAO = vao,
			Delete = function(self)
				self.deleted = true
			end,
		}
		calls.vbos[#calls.vbos + 1] = vbo
		return vbo
	end
	local function push(vbo, row, id)
		equal(vbo.instanceStep, #row)
		local index = vbo.instanceIDtoIndex[id]
		if not index then
			index = vbo.usedElements + 1
			vbo.usedElements = index
			vbo.instanceIDtoIndex[id], vbo.indextoInstanceID[index] = index, id
		end
		for i, value in ipairs(row) do
			vbo.instanceData[(index - 1) * vbo.instanceStep + i] = value
		end
		vbo.dirty = true
	end
	local function pop(vbo, id)
		local index = vbo.instanceIDtoIndex[id]
		local last = vbo.usedElements
		local lastID = vbo.indextoInstanceID[last]
		for field = 1, vbo.instanceStep do
			vbo.instanceData[(index - 1) * vbo.instanceStep + field] =
				vbo.instanceData[(last - 1) * vbo.instanceStep + field]
		end
		vbo.instanceIDtoIndex[lastID] = index
		vbo.indextoInstanceID[index] = lastID
		vbo.instanceIDtoIndex[id], vbo.indextoInstanceID[last] = nil, nil
		vbo.usedElements = last - 1
	end
	env.gl.InstanceVBOTable = {
		makeInstanceVBOTable = make,
		pushElementInstance = push,
		popElementInstance = pop,
		clearInstanceTable = function(vbo)
			vbo.usedElements, vbo.instanceIDtoIndex, vbo.indextoInstanceID = 0, {}, {}
		end,
		uploadAllElements = function(vbo)
			calls.uploads = (calls.uploads or 0) + 1
			vbo.dirty = false
		end,
		uploadElementRange = noop,
		compactInstanceVBO = noop,
		fillVAOSlots = function()
			return vao
		end,
		makePlaneVBO = function()
			return {}, 4
		end,
		makePlaneIndexVBO = function()
			return {}, 6
		end,
		makeVAOandAttach = function()
			return vao
		end,
	}
	env.gl.LuaShader = {
		isGeometryShaderSupported = options.geo ~= false,
		CheckShaderUpdates = function(config)
			calls.shaderConfig = config.shaderConfig
			if options.shaderError then
				return nil
			end
			return { Activate = noop, Deactivate = noop, SetUniform = noop, Finalize = noop }
		end,
	}
	env.gl.GetVAO = function()
		return vao
	end
	env.gl.Texture = function(unit, texture)
		calls.bound[unit] = texture
	end
	for _, name in ipairs({ "Culling", "DepthTest", "DepthMask", "Blending" }) do
		env.gl[name] = noop
	end
	loadIn("luaui/Widgets/gfx_decals_gl4.lua", env)
	if saved then
		env.widget:SetConfigData(saved)
	end
	env.widget:Initialize()
	return env.WG.decalsgl4, calls, env
end

describe("incremental decal widget", function()
	for _, geo in ipairs({ true, false }) do
		it(
			"renders mixed decals at every size and exports only baked instances (GS=" .. tostring(geo) .. ")",
			function()
				local api, calls, env = widgetFixture({ geo = geo })
				equal(1, calls.shaderConfig.USE_RUNTIME_ATLASES)
				local bakedIDs = {}
				for i, size in ipairs({ 50, 600, 1200 }) do
					bakedIDs[i] = api.AddDecalGL4(OLD, 1000, 1000, 0, size, size, 0, 1, 1, 0.001, 1)
					api.AddDecalGL4(NEW, 1000, 1000, 0, size, size, 0, 1, 1, 0.001, 1)
					equal(2, calls.vbos[i].usedElements)
					equal(0, calls.vbos[i].instanceData[21])
					equal(1, calls.vbos[i].instanceData[42])
				end
				env.widget:DrawPreDecals()
				equal(3, #calls.draws)
				for _, draw in ipairs(calls.draws) do
					equal(2, draw.count)
					equal("*runtime1", draw.albedo)
					equal("*runtime2", draw.normal)
				end
				equal(false, calls.bound[7])
				equal(false, calls.bound[8])
				local exported = api.GetVBOData()
				for i, vbo in ipairs(exported) do
					equal(1, vbo.usedElements)
					equal(bakedIDs[i], vbo.indextoInstanceID[1])
					equal(0, vbo.instanceData[21])
				end
				local uploads = calls.uploads
				api.GetVBOData()
				equal(uploads, calls.uploads)
				local active = api.RebuildActiveDecalData()
				assert(active[bakedIDs[1]] and not active[bakedIDs[1] + 1])
				api.RemoveDecalGL4(bakedIDs[1])
				equal(0, api.GetVBOData()[1].usedElements)
				env.widget:Shutdown()
				equal(2, #calls.deleted)
				assert(calls.vbos[4].deleted and not env.WG.decalsgl4)
			end
		)
	end

	it("uses original buffers without runtime images and rejects unresolved textures", function()
		local api, calls, env = widgetFixture({ files = {} })
		api.AddDecalGL4(OLD, 1000, 1000, 0, 50, 50, 0, 1, 1, 0.001, 1)
		assert(api.AddDecalGL4(NEW, 1000, 1000, 0, 50, 50) == nil)
		equal(calls.vbos[1], api.GetVBOData()[1])
		equal(3, #calls.vbos)
		env.widget:Shutdown()
	end)

	it("re-resolves saved textures after repacking and tolerates missing runtime content", function()
		local api, _, env = widgetFixture()
		api.AddDecalGL4(NEW, 1000, 1000, 0, 50, 50, 0, 1, 1, 0.001, 1)
		local saved = env.widget:GetConfigData()
		equal(3, saved.savedDecalsFormat)
		equal(NEW, saved.savedDecalTextures[1].texture)
		env.widget:Shutdown()
		local _, calls, restored = widgetFixture({ uv = { 0.5, 0.7, 0.1, 0.3 } }, saved)
		equal(1, calls.vbos[1].usedElements)
		near(0.5 + 0.2 * 8 / 512, calls.vbos[1].instanceData[5])
		equal(1, calls.vbos[1].instanceData[21])
		restored.widget:Shutdown()
		local _, missing, without = widgetFixture({ files = {} }, saved)
		equal(0, missing.vbos[1].usedElements)
		without.widget:Shutdown()
	end)

	it("restores legacy UV-only saves as baked decals", function()
		local api, calls, env = widgetFixture({}, {
			savedDecals = {
				{ 50, 50, 0, 1, 0.1, 0.2, 0.3, 0.4, 1, 0.001, 1000, 1000, 100 },
			},
			saveFrame = 100,
		})
		equal(1, calls.vbos[1].usedElements)
		equal(0, calls.vbos[1].instanceData[21])
		equal(calls.vbos[1], api.GetVBOData()[1])
		env.widget:Shutdown()
	end)

	it("caches runtime footprint flips and preserves them across reloads", function()
		local albedo = ROOT .. "/footprints/f_raptor_a.png"
		local api, calls, env = widgetFixture({ footprint = true, files = { albedo, (albedo:gsub("_a%.", "_n.")) } })
		env.widget:UnitScriptDecalBatch({ 1, 1, 1, 1000, 1000, 0, 1, 1, 2, 1100, 1000, 0 }, 12)
		equal(2, calls.vbos[1].usedElements)
		near(calls.vbos[1].instanceData[7], calls.vbos[1].instanceData[29])
		near(calls.vbos[1].instanceData[8], calls.vbos[1].instanceData[28])
		equal(0, api.GetVBOData()[1].usedElements)
		local saved = env.widget:GetConfigData()
		env.widget:Shutdown()
		local _, restored, restoredEnv = widgetFixture(
			{ footprint = true, files = { albedo, (albedo:gsub("_a%.", "_n.")) }, uv = { 0.5, 0.7, 0.1, 0.3 } },
			saved
		)
		equal(2, restored.vbos[1].usedElements)
		near(restored.vbos[1].instanceData[7], restored.vbos[1].instanceData[29])
		restoredEnv.widget:Shutdown()
	end)

	it("deletes the atlas pair when shader initialization fails", function()
		local _, calls, env = widgetFixture({ shaderError = true })
		assert(calls.removed)
		equal(2, #calls.deleted)
		env.widget:Shutdown()
		equal(2, #calls.deleted)
	end)

	it("keeps runtime texture identities until expired VBO entries are compacted", function()
		local options = { frame = 100 }
		local api, _, env = widgetFixture(options)
		local _, lifetime = api.AddDecalGL4(NEW, 1000, 1000, 0, 50, 50, 0, 1, 1, 0.001, 1)
		options.frame = 100 + lifetime
		env.widget:GameFrame(options.frame)
		local saved = env.widget:GetConfigData()
		assert(saved.savedDecalTextures[1], "a fractional remaining alpha must not lose its texture identity")
		equal(NEW, saved.savedDecalTextures[1].texture)
		env.widget:Shutdown()
	end)
end)
