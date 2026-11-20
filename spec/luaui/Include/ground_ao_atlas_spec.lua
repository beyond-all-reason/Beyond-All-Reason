-- Isolated GL/VFS boundaries: these specs also run with plain Lua 5.1.
local MODULE = "luaui/Include/GroundAOAtlas.lua"
local DIRECTORY = "unittextures/decals"
local OLD = DIRECTORY .. "/old_4_6_aoplane.dds"
local NEW = DIRECTORY .. "/new_unit_8_10_aoplane.png"

local function equal(expected, actual)
	assert(expected == actual, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function equalUV(expected, actual)
	assert(actual, "missing UV coordinates")
	for i = 1, 4 do
		assert(math.abs(expected[i] - actual[i]) < 0.000001, "UV mismatch at " .. i)
	end
end

local function loadIn(path, env)
	return setfenv(assert(loadfile(path)), env)()
end

local function fixture(options)
	options = options or {}
	local calls = { created = 0, added = {}, deleted = {}, queries = 0, warnings = {} }
	local env = setmetatable({ GL = {}, Spring = {}, VFS = {}, gl = {} }, { __index = _G })
	env.Spring.Echo = function(message)
		calls.warnings[#calls.warnings + 1] = message
	end
	env.Spring.GetConfigInt = function(name, default)
		return options[name] or default
	end
	env.VFS.DirList = function(directory, pattern, mode, recursive)
		equal(options.directory or DIRECTORY, directory)
		equal("*.png", pattern)
		assert(recursive)
		local copy = {}
		for i, path in ipairs(options.files or {}) do
			copy[i] = path
		end
		return copy
	end
	env.VFS.FileExists = function(path)
		return (options.exists or {})[path]
	end
	env.gl.TextureInfo = function(path)
		if (options.invalid or {})[path] then
			return nil
		end
		return { xsize = 128, ysize = 64 }
	end
	env.gl.CreateTextureAtlas = function(x, y, allocator)
		calls.created = calls.created + 1
		calls.maxX, calls.maxY, calls.allocator = x, y, allocator
		if options.createError then
			error("creation failed")
		end
		return "*test"
	end
	env.gl.AddAtlasTexture = function(atlas, path, key)
		equal("*test", atlas)
		if (options.addErrors or {})[path] then
			error("invalid PNG")
		end
		calls.added[#calls.added + 1] = { path = path, key = key }
	end
	env.gl.FinalizeTextureAtlas = function()
		calls.finalized = true
		if options.finalizeError then
			error("upload failed")
		end
		return not options.full
	end
	env.gl.GetAtlasTexture = function(atlas, key)
		assert(calls.finalized, "UVs queried before finalization")
		calls.queries = calls.queries + 1
		if options.queryError then
			error("unknown image")
		end
		return 0.1, 0.4, 0.2, 0.8, 0
	end
	env.gl.DeleteTextureAtlas = function(atlas)
		calls.deleted[#calls.deleted + 1] = atlas
	end
	if options.noAPI then
		env.gl.AddAtlasTexture = nil
	end
	local api = loadIn(MODULE, env)
	local manifest = options.manifest or { atlasimage = "baked.dds", [OLD] = { 0.1, 0.2, 0.3, 0.4, 128, 64 } }
	local definitions = options.definitions
		or {
			[1] = { name = "old", modelname = "Units/old.s3o" },
			[2] = { name = "new", modelname = "Units/NEW_UNIT.glb" },
		}
	local function create()
		return api.Create(manifest, options.directory or DIRECTORY, definitions, options.kind or "unit")
	end
	return create, calls, api, env, manifest, definitions
end

describe("ground AO atlas", function()
	it("parses right-anchored rectangular sizes without truncating model names", function()
		local _, _, api = fixture()
		local model, x, z = api.ParseFilename("unittextures\\decals\\ARM_2_DEAD_10.5_12_aoplane.PNG")
		equal("arm_2_dead", model)
		equal(10.5, x)
		equal(12, z)
		for _, path in ipairs({
			"foo_0_2_aoplane.png",
			"foo_-1_2_aoplane.png",
			"foo_nan_2_aoplane.png",
			"foo_1e309_2_aoplane.png",
			"foo_aoplane.png",
		}) do
			local _, invalidX, invalidZ = api.ParseFilename(path)
			assert(invalidX == nil and invalidZ == nil, path)
		end
	end)

	it("copies/flips prebuilt UVs once without allocating or mutating the manifest", function()
		local create, calls, _, _, manifest = fixture()
		for _ = 1, 2 do
			local atlas = create()
			equalUV({ 0.1, 0.2, 0.7, 0.6 }, atlas.plates[1].uv)
			equal(64, atlas.plates[1].sizeX)
			equal(96, atlas.plates[1].sizeZ)
			equal(0, atlas.plates[1].atlasIndex)
			atlas:Delete()
		end
		equal(0, calls.created)
		equalUV({ 0.1, 0.2, 0.3, 0.4 }, manifest[OLD])
	end)

	it("packs only selected missing PNGs and keeps their runtime UV orientation", function()
		local create, calls = fixture({ files = { NEW, DIRECTORY .. "/unused_2_2_aoplane.png" } })
		local atlas = create()
		equal(1, calls.created)
		equal(1, #calls.added)
		equal(NEW, calls.added[1].path)
		equal(0, calls.allocator)
		equal(128, atlas.plates[2].sizeX)
		equal(160, atlas.plates[2].sizeZ)
		equal(1, atlas.plates[2].atlasIndex)
		equalUV({ 0.1, 0.4, 0.2, 0.8 }, atlas.plates[2].uv)
		atlas:Delete()
		atlas:Delete()
		equal(1, #calls.deleted)
	end)

	it("deduplicates PNGs represented by a prebuilt extension-equivalent entry", function()
		local create, calls = fixture({ files = { (OLD:gsub("dds$", "png")) } })
		local atlas = create()
		equal(0, atlas.plates[1].atlasIndex)
		equal(0, calls.created)
	end)

	it("stops packing a PNG once a later manifest contains it", function()
		local create, calls = fixture({
			files = { NEW },
			manifest = {
				atlasimage = "baked.dds",
				[NEW] = { 0, 0.25, 0.5, 0.75 },
			},
		})
		local atlas = create()
		equal(0, atlas.plates[2].atlasIndex)
		equal(0, calls.created)
	end)

	it("honors explicit texture, dimension and zero-alpha overrides", function()
		local create = fixture({
			files = { NEW },
			definitions = {
				[1] = {
					modelname = "old.s3o",
					customParams = {
						buildinggrounddecaltype = "DECALS/NEW_UNIT_8_10_AOPLANE.PNG",
						buildinggrounddecalsizex = "3",
						buildinggrounddecalalpha = "0",
					},
				},
			},
		})
		local plate = create().plates[1]
		equal(1, plate.atlasIndex)
		equal(48, plate.sizeX)
		equal(160, plate.sizeZ)
		equal(0, plate.alpha)
	end)

	it("does not replace an unresolved explicit texture with an automatic match", function()
		local create, calls = fixture({
			definitions = {
				[1] = {
					name = "missing_unit",
					modelname = "old.s3o",
					customParams = { buildinggrounddecaltype = "decals/missing.png" },
				},
			},
		})
		assert(create().plates[1] == nil)
		equal(1, #calls.warnings)
		equal(
			"Ground AO (unit): cannot resolve decals/missing.png referenced by unitDef missing_unit",
			calls.warnings[1]
		)
	end)

	it("includes the featureDef name in unresolved texture warnings", function()
		local create, calls = fixture({
			kind = "feature",
			definitions = {
				[1] = {
					name = "missing_feature",
					modelname = "old.s3o",
					customParams = { decalinfo_texfile = "decals/missing.png" },
				},
			},
		})
		assert(create().plates[1] == nil)
		equal(1, #calls.warnings)
		equal(
			"Ground AO (feature): cannot resolve decals/missing.png referenced by featureDef missing_feature",
			calls.warnings[1]
		)
	end)

	it("honors boolean, numeric and string unit opt-outs", function()
		for _, value in ipairs({ false, 0, "0", "false", " FALSE " }) do
			local create, calls = fixture({
				files = { NEW },
				definitions = {
					[1] = { modelname = "new_unit.s3o", customParams = { usebuildinggrounddecal = value } },
				},
			})
			assert(create().plates[1] == nil)
			equal(0, calls.created)
		end
	end)

	it("borrows only unambiguous legacy sizes for units without custom parameters", function()
		local path = DIRECTORY .. "/legacy_aoplane.dds"
		local options = {
			manifest = { [path] = { 0, 1, 0, 1 } },
			definitions = {
				[1] = {
					customParams = {
						buildinggrounddecaltype = "decals/legacy_aoplane.dds",
						buildinggrounddecalsizex = "5",
						buildinggrounddecalsizey = "7",
					},
				},
				[2] = { modelname = "legacy.s3o" },
			},
		}
		local create = fixture(options)
		local atlas = create()
		equal(80, atlas.plates[2].sizeX)
		equal(112, atlas.plates[2].sizeZ)
		options.definitions[3] = {
			customParams = {
				buildinggrounddecaltype = "decals/legacy_aoplane.dds",
				buildinggrounddecalsizex = "6",
				buildinggrounddecalsizey = "7",
			},
		}
		create = fixture(options)
		atlas = create()
		assert(atlas.plates[1] and atlas.plates[3])
		assert(atlas.plates[2] == nil)
	end)

	it("retains configured rendering for every shipped prebuilt unit image", function()
		local manifest = assert(loadfile("unittextures/decals/unitaoplates_atlas.lua"))()
		local definitions, expected = {}, {}
		for path, uv in pairs(manifest) do
			if type(uv) == "table" then
				local id = #definitions + 1
				definitions[id] = {
					customParams = {
						usebuildinggrounddecal = "1",
						buildinggrounddecaltype = path,
						buildinggrounddecalsizex = "5",
						buildinggrounddecalsizey = "7",
						buildinggrounddecalalpha = "0.8",
					},
				}
				expected[id] = uv
			end
		end
		assert(#definitions > 0, "expected the shipped unit corpus")
		local create, calls = fixture({ manifest = manifest, definitions = definitions })
		local plates = create().plates
		for id, uv in ipairs(expected) do
			local plate = assert(plates[id])
			equal(80, plate.sizeX)
			equal(112, plate.sizeZ)
			equal(0.8, plate.alpha)
			equal(0, plate.atlasIndex)
			equalUV({ uv[1], uv[2], 1 - uv[3], 1 - uv[4] }, plate.uv)
		end
		equal(0, calls.created)
		equal(0, #calls.warnings)
	end)

	it("packs a shared runtime image once for multiple definitions", function()
		local create, calls = fixture({
			files = { NEW },
			definitions = {
				[1] = { modelname = "new_unit.s3o" },
				[2] = { name = "new_unit", modelname = "shared.glb" },
			},
		})
		local atlas = create()
		assert(atlas.plates[1] and atlas.plates[2])
		equal(1, #calls.added)
		equal(1, calls.queries)
	end)

	it("rejects ambiguous automatic model matches instead of depending on file order", function()
		local create, calls = fixture({ files = { NEW, DIRECTORY .. "/new_unit_9_11_aoplane.png" } })
		local atlas = create()
		assert(atlas.plates[2] == nil)
		assert(atlas.plates[1])
		equal(0, calls.created)
		equal(1, #calls.warnings)
	end)

	it("resolves features of any type and retains heap and explicit rock aliases", function()
		local dir = "unittextures/decals_features"
		local create = fixture({
			kind = "feature",
			directory = dir,
			manifest = {
				[dir .. "/arm1X1A_2_2_aoplane.dds"] = { 0, 1, 0, 1 },
				[dir .. "/rocks30_def_01_aoplane.tga"] = { 0, 1, 0, 1 },
			},
			files = { dir .. "/tree_4_8_aoplane.png" },
			definitions = {
				[1] = { name = "foo_heap", modelname = "Units/arm1x1a.s3o" },
				[2] = { modelname = "tree.glb" },
				[3] = {
					modelname = "rocks30_desert_01.s3o",
					customParams = {
						decalinfo_texfile = "rocks30_def_01_aoplane.tga",
						decalinfo_sizex = "3",
						decalinfo_alpha = "0.9",
					},
				},
			},
		})
		local plates = create().plates
		equal(32, plates[1].sizeX)
		equal(128, plates[2].sizeZ)
		equal(1, plates[2].atlasIndex)
		equal(48, plates[3].sizeX)
		equal(80, plates[3].sizeZ) -- legacy explicit feature default
		equal(0.9, plates[3].alpha)
	end)

	it("retains every size-bearing entry in the shipped feature manifest", function()
		local manifest = assert(loadfile("unittextures/decals_features/featureaoplates_atlas.lua"))()
		local _, _, api = fixture()
		local definitions, expected = {}, {}
		for path, uv in pairs(manifest) do
			if type(uv) == "table" then
				local model, x, z = api.ParseFilename(path)
				if x and z then
					local id = #definitions + 1
					definitions[id] = { modelname = "Units/" .. model .. ".s3o" }
					expected[id] = { x = x, z = z, uv = uv, path = path }
				end
			end
		end
		assert(#definitions > 0, "expected the shipped heap/wreck corpus")
		local create, calls = fixture({ kind = "feature", manifest = manifest, definitions = definitions })
		local plates = create().plates
		for id, entry in ipairs(expected) do
			local plate = assert(plates[id], entry.path)
			equal(entry.x * 16, plate.sizeX)
			equal(entry.z * 16, plate.sizeZ)
			equalUV({ entry.uv[1], entry.uv[2], 1 - entry.uv[3], 1 - entry.uv[4] }, plate.uv)
		end
		equal(0, calls.created)
		equal(0, #calls.warnings)
	end)

	it("gives explicit feature parameters precedence over wreck inference", function()
		local create = fixture({
			kind = "feature",
			definitions = {
				[1] = {
					modelname = "something_dead.s3o",
					customParams = { decalinfo_texfile = OLD, decalinfo_sizez = "3" },
				},
			},
		})
		equal(48, create().plates[1].sizeZ)
	end)

	it("discovers explicitly referenced PNGs outside the plate directories", function()
		local path = "custom/plate.png"
		local create, calls = fixture({
			exists = { [path] = true },
			definitions = {
				[1] = {
					customParams = {
						buildinggrounddecaltype = path,
						buildinggrounddecalsizex = "2",
						buildinggrounddecalsizey = "3",
					},
				},
			},
		})
		equal(1, create().plates[1].atlasIndex)
		equal(path, calls.added[1].path)
	end)

	it("uses the internal name when the model has no match", function()
		local create =
			fixture({ files = { NEW }, definitions = { [1] = { name = "new_unit", modelname = "shared.glb" } } })
		equal(128, create().plates[1].sizeX)
	end)

	it("retains baked coverage when the atlas API is unavailable", function()
		local create, calls = fixture({ files = { NEW }, noAPI = true })
		local atlas = create()
		assert(atlas.plates[1] and not atlas.plates[2])
		equal(0, calls.created)
	end)

	it("discards failed finalizations without querying UVs", function()
		for _, failure in ipairs({ "full", "finalizeError" }) do
			local options = { files = { NEW }, [failure] = true }
			local create, calls = fixture(options)
			local atlas = create()
			assert(atlas.plates[1] and not atlas.plates[2])
			assert(atlas.runtimeTexture == nil)
			equal(0, calls.queries)
			equal(1, #calls.deleted)
			atlas:Delete()
			equal(1, #calls.deleted)
		end
	end)

	it("rejects bad images and creation errors without losing baked plates", function()
		for _, options in ipairs({ { invalid = { [NEW] = true } }, { createError = true }, { queryError = true } }) do
			options.files = { NEW }
			local create = fixture(options)
			local atlas = create()
			assert(atlas.plates[1] and not atlas.plates[2])
			atlas:Delete()
		end
	end)

	it("continues packing valid images when another image cannot be added", function()
		local bad = DIRECTORY .. "/bad_2_2_aoplane.png"
		local create, calls = fixture({
			files = { NEW, bad },
			addErrors = { [bad] = true },
			definitions = {
				[1] = { modelname = "new_unit.glb" },
				[2] = { modelname = "bad.s3o" },
			},
		})
		local atlas = create()
		assert(atlas.plates[1] and not atlas.plates[2])
		equal(1, calls.queries)
	end)

	it("destroys an atlas with no successfully added images", function()
		local create, calls = fixture({ files = { NEW }, addErrors = { [NEW] = true } })
		local atlas = create()
		assert(atlas.runtimeTexture == nil and atlas.plates[2] == nil)
		assert(not calls.finalized)
		equal(1, #calls.deleted)
	end)

	it("respects configured and GPU atlas size limits", function()
		local create, calls, _, env =
			fixture({ files = { NEW }, MaxTextureAtlasSizeX = 1024, MaxTextureAtlasSizeY = 2048 })
		env.gl.GetNumber = function()
			return 512
		end
		create()
		equal(512, calls.maxX)
		equal(512, calls.maxY)
	end)
end)

-- Load the actual widgets with a stub primitive renderer, checking their VBO
-- records, sampler bindings, lifecycle callbacks, and atlas ownership together.
describe("ground AO widget integration", function()
	for _, kind in ipairs({ "unit", "feature" }) do
		local widgetKind = kind
		it("cleans up the " .. kind .. " atlas if shader initialization fails", function()
			local _, calls, api, env, manifest, definitions = fixture({ files = { NEW } })
			env.widget = {}
			local removed = false
			env.widgetHandler = {
				AddAction = function() end,
				RemoveAction = function() end,
				RemoveWidget = function()
					removed = true
				end,
			}
			env.gl.InstanceVBOTable = {}
			env.gl.CreateShader = function() end
			env.UnitDefs, env.FeatureDefs = definitions, definitions
			env.Spring.GetSpectatingState = function()
				return false, false
			end
			env.Spring.GetLocalAllyTeamID = function()
				return 1
			end
			env.require = function()
				return manifest
			end
			env.VFS.Include = function(path)
				if path:find("GroundAOAtlas", 1, true) then
					return {
						Create = function()
							return api.Create(manifest, DIRECTORY, definitions, widgetKind)
						end,
					}
				end
				return {
					shaderConfig = {},
					InitDrawPrimitiveAtUnit = function()
						return nil
					end,
				}
			end
			local suffix = widgetKind == "feature" and "_features" or ""
			loadIn("luaui/Widgets/gui_ground_ao_plates" .. suffix .. "_gl4.lua", env)
			env.widget:Initialize()
			assert(removed)
			equal(1, #calls.deleted)
			env.widget:Shutdown()
			equal(1, #calls.deleted)
		end)

		it("renders mixed baked/runtime " .. kind .. " instances in one draw", function()
			local create, calls, api, env, manifest, definitions = fixture({ files = { NEW } })
			local instances, bound, draws = {}, {}, {}
			local vbo = { usedElements = 0, instanceIDtoIndex = {} }
			vbo.VAO = {
				DrawArrays = function(_, mode, count)
					draws[#draws + 1] = { count = count, baked = bound[0], runtime = bound[1] }
				end,
			}
			local function push(_, data, id)
				if not instances[id] then
					vbo.usedElements = vbo.usedElements + 1
				end
				instances[id] = {}
				for i, value in ipairs(data) do
					instances[id][i] = value
				end
				vbo.instanceIDtoIndex[id] = true
			end
			local function pop(_, id)
				instances[id], vbo.instanceIDtoIndex[id] = nil, nil
				vbo.usedElements = vbo.usedElements - 1
			end
			env.gl.InstanceVBOTable = {
				pushElementInstance = push,
				popElementInstance = pop,
				clearInstanceTable = function()
					instances = {}
					vbo.instanceIDtoIndex = {}
					vbo.usedElements = 0
				end,
				uploadAllElements = function() end,
			}
			env.gl.CreateShader = function() end
			env.gl.Texture = function(unit, texture)
				bound[unit] = texture
			end
			for _, name in ipairs({ "Culling", "DepthTest", "DepthMask" }) do
				env.gl[name] = function() end
			end
			env.GL = { BACK = 1, LEQUAL = 2, POINTS = 3, ALWAYS = 4 }
			env.Spring.GetGameFrame = function()
				return 42
			end
			env.Spring.GetSpectatingState = function()
				return false, false
			end
			env.Spring.GetLocalAllyTeamID = function()
				return 1
			end
			env.Spring.GetAllFeatures = function()
				return { 101, 102 }
			end
			env.Spring.GetFeatureDefID = function(id)
				return id - 100
			end
			env.Spring.GetUnitDefID = function(id)
				return id - 100
			end
			env.widget = {}
			env.widgetHandler = {
				AddAction = function() end,
				RemoveAction = function() end,
				RemoveWidget = function()
					error("unexpected removal")
				end,
			}
			env.WG = { unittrackerapi = { visibleUnits = { [101] = 1, [102] = 2 } } }
			env.UnitDefs, env.FeatureDefs = definitions, definitions
			env.require = function()
				return manifest
			end
			local config
			env.VFS.Include = function(path)
				if path:find("GroundAOAtlas", 1, true) then
					-- Use the same fixture directory for both widget types.
					return {
						Create = function(_, _, defs, actualKind)
							equal(widgetKind, actualKind)
							return api.Create(manifest, DIRECTORY, defs, actualKind)
						end,
					}
				end
				return {
					shaderConfig = {},
					InitDrawPrimitiveAtUnit = function(shaderConfig)
						config = shaderConfig
						return vbo,
							{
								Activate = function() end,
								Deactivate = function() end,
								SetUniform = function() end,
								Finalize = function() end,
							}
					end,
				}
			end
			local suffix = widgetKind == "feature" and "_features" or ""
			loadIn("luaui/Widgets/gui_ground_ao_plates" .. suffix .. "_gl4.lua", env)
			local widget = env.widget
			widget:Initialize()
			equal(1, config.USE_SECONDARY_TEXTURE)
			equal(0, instances[101][8])
			equal(1, instances[102][8])
			equal(160, instances[102][1])
			equal(128, instances[102][2])
			equal(42, instances[102][7])
			equal(widgetKind == "feature" and 0.66 or 1, instances[102][9])
			equalUV({ 0.4, 0.1, 0.2, 0.8 }, { unpack(instances[102], 11, 14) })
			widget:DrawWorldPreUnit()
			equal(1, #draws)
			equal(2, draws[1].count)
			equal("baked.dds", draws[1].baked)
			equal("*test", draws[1].runtime)
			equal(false, bound[1])
			if widgetKind == "feature" then
				widget:FeatureDestroyed(101)
				widget:FeatureCreated(101)
			else
				widget:VisibleUnitRemoved(101)
				widget:VisibleUnitAdded(101, 1)
			end
			equal(0, instances[101][8])
			equal(1, instances[102][8])
			widget:Shutdown()
			equal(1, #calls.deleted)
		end)
	end
end)
