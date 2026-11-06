local MapExport = require("common/map_export")

-- An in-memory file system: the export only touches files through the adapter.
---@return table fs
local function memoryFs(files)
	local fs = { files = files, dirs = {} }
	function fs.read(path)
		return fs.files[path]
	end
	function fs.write(path, data)
		fs.files[path] = data
		return true
	end
	function fs.exists(path)
		return fs.files[path] ~= nil
	end
	function fs.mkdir(path)
		fs.dirs[path] = true
	end
	return fs
end

---@return table fs
local function project(extra)
	local files = {
		["p/project.lua"] = [[return {
	kind = "bar-map-project",
	format_version = 1,
	name = "Test Map",
	map = {
		size_x = 4, size_z = 4,
		base_color = { 110, 130, 90 },
		extractor_radius = 80,
		height_range = { min = -50, max = 400 },
		skybox = "sky.dds",
	},
	sections = {
		heightmap = { file = "heightmap.png" },
		minimap = { file = "minimap.png" },
		environment = { file = "environment.lua" },
		startpos = { file = "startpos.lua" },
		features = { file = "features.lua" },
		tileset = { file = "tileset.lua" },
		surface = { file = "surface.png", meta = "surface.lua" },
		lights = { file = "lights.lua" },
		decals = { file = "decals.lua" },
		weather = { file = "weather.lua" },
		metal = { file = "metal.lua" },
		units = { file = "units.lua" },
	},
}]],
		["p/heightmap.png"] = "HEIGHT",
		["p/minimap.png"] = "MINI",
		["p/surface.png"] = "SURF",
		["p/surface.lua"] = 'return { biome = "osemo", slot1 = "a" }',
		["p/environment.lua"] = [[return {
	sunDir = { 0.4, 0.5, -0.7 },
	sunIntensity = 0.8,
	groundAmbientColor = { 0.5, 0.5, 0.5 },
	fogColor = { 0.7, 0.7, 0.8, 0 },
	skybox = "Terraform Brush/SkyBoxes/sky.dds",
	splatTexScales = { 0.02, 0.02, 0.02, 0.02 },
	voidWater = true,
	water = { shoreWaves = false, repeatX = 2 },
	waterColors_absorb = { 0.1, 0.2, 0.3 },
	heightFog = { enabled = true, density = 0.2, fowLayer = true },
	blockout = { { def = "ring_1", yaw = 10, scale = 2 } },
}]],
		["p/startpos.lua"] = [[local startPositions = {
  [1] = { x = 900, z = 100, allyTeam = 1, teamSlot = 1 },
  [2] = { x = 100, z = 900, allyTeam = 0, teamSlot = 1 },
}
return startPositions]],
		["p/features.lua"] = [[local setcfg = {
	unitlist = {},
	buildinglist = {},
	objectlist = {
		{ name = "tree_a", x = 10, z = 20, rot = 0 },
		{ name = "rock_b", x = 30, z = 40, rot = 100, pitch = 5, roll = 0, y = -3, scale = 1.5 },
	},
}
return setcfg]],
		["p/tileset.lua"] = 'return { biome = "osemo", knobs = { exposure = 1.5 } }',
		["p/lights.lua"] = 'return { version = 1, mapName = "Editor Flat", lights = { { type = "point", pos = { 1, 2, 3 } } } }',
		["p/decals.lua"] = 'return { { tex = "crater_a", x = 1, z = 2, sx = 64, sz = 64, rot = 0 } }',
		["p/weather.lua"] = 'return { version = 1, spawners = { { x = 1, z = 2, cegs = { "mist" } } } }',
		["p/metal.lua"] = [[return { squareSize = 16, width = 128, height = 128, spots = {
	{ x = 8, z = 8, mx = 0, mz = 0, amount = 5.100 },
	{ x = 24, z = 8, mx = 1, mz = 0, amount = 2.040 },
} }]],
		["p/units.lua"] = "return {}",
		["Terraform Brush/SkyBoxes/sky.dds"] = "SKY",
	}
	for k, v in pairs(extra or {}) do
		files[k] = v
	end
	return memoryFs(files)
end

---@return table report
local function run(fs, opts)
	opts = opts or {}
	opts.project, opts.out, opts.io = "p", "o", fs
	return MapExport.run(opts)
end

local function archiveTable(fs, rel)
	local text = assert(fs.files["o/archive/" .. rel], "not written: " .. rel)
	return assert(MapExport.loadTable(text, rel))
end

describe("map_export", function()
	describe("serialize", function()
		it("round-trips through loadTable with sorted keys", function()
			local value = { b = 1, a = { 1, 2.5, "x" }, ["not ok"] = true, [0] = { z = -3 } }
			local text = MapExport.serialize(value)
			local back = assert(MapExport.loadTable("return " .. text))
			assert.are.same(value, back)
			assert.are.equal(text, MapExport.serialize(back))
			assert.is_truthy(text:find("a = ", 1, true) < text:find("b = ", 1, true))
		end)
	end)

	describe("carryKeys", function()
		local live = "-- header\nreturn {\n\tversion = 1,\n\tfogStart = 0.5,\n}\n"
		it("adds only the keys the file lacks, and the result loads", function()
			local carried = { version = 9, fogStart = 0.1, heightFog = { brightness = 1, color = { 0.4, 0.5 } } }
			local text = MapExport.carryKeys(live, carried)
			local back = assert(MapExport.loadTable(text))
			assert.are.equal(1, back.version)
			assert.are.equal(0.5, back.fogStart)
			assert.are.same(carried.heightFog, back.heightFog)
			assert.is_truthy(text:find("^%-%- header"))
		end)
		it("leaves the file alone when nothing is missing", function()
			assert.are.equal(live, MapExport.carryKeys(live, { version = 2 }))
			assert.are.equal(live, MapExport.carryKeys(live, nil))
		end)
	end)

	describe("loadTable", function()
		it("gives the file no globals", function()
			local t, err = MapExport.loadTable("os.exit(1) return {}")
			assert.is_nil(t)
			assert.is_truthy(err)
		end)
	end)

	describe("run", function()
		---@type table
		local fs
		---@type table
		local report
		before_each(function()
			fs = project()
			report = run(fs, { name = "Test Map", version = "1.2" })
		end)

		it("succeeds and names the archive after the map and version", function()
			assert.is_true(report.ok)
			assert.are.equal("Test Map 1.2", report.name)
			assert.are.equal("test_map_1_2", report.fileBase)
			local mapinfo = archiveTable(fs, "mapinfo.lua")
			-- version inside the name: the engine then keeps the name as is (a "CM12" + "1" safe form)
			assert.are.equal("Test Map 1.2", mapinfo.name)
			assert.are.equal("1.2", mapinfo.version)
			assert.are.equal("maps/test_map_1_2.smf", mapinfo.mapfile)
			assert.are.equal(80, mapinfo.extractorradius)
			assert.are.same({ minheight = -50, maxheight = 400 }, mapinfo.smf)
		end)

		it("writes the environment into mapinfo", function()
			local mapinfo = archiveTable(fs, "mapinfo.lua")
			assert.are.same({ 0.4, 0.5, -0.7, 0.8 }, mapinfo.lighting.sundir)
			assert.are.same({ 0.7, 0.7, 0.8, 0 }, mapinfo.atmosphere.fogcolor)
			assert.are.equal("sky.dds", mapinfo.atmosphere.skybox)
			assert.are.equal("SKY", fs.files["o/archive/maps/sky.dds"])
			assert.is_true(mapinfo.voidwater)
			assert.are.same({ 0.1, 0.2, 0.3 }, mapinfo.water.absorb)
			assert.are.equal(2, mapinfo.water.repeatx)
			assert.are.same({ enabled = true, density = 0.2, fowlayer = true }, mapinfo.custom.atmosphere.heightfog)
		end)

		it("orders start positions by ally team, from team 0", function()
			local mapinfo = archiveTable(fs, "mapinfo.lua")
			assert.are.same({ x = 100, z = 900 }, mapinfo.teams[0].startpos)
			assert.are.same({ x = 900, z = 100 }, mapinfo.teams[1].startpos)
		end)

		it("keeps the feature transform fields", function()
			local set = archiveTable(fs, "mapconfig/featureplacer/set.lua")
			assert.are.equal(2, #set.objectlist)
			assert.are.same(
				{ name = "rock_b", x = 30, z = 40, rot = 100, pitch = 5, roll = 0, y = -3, scale = 1.5 },
				set.objectlist[2]
			)
			assert.are.same({ "rock_b", "tree_a" }, report.references.features)
		end)

		it("marks the tileset section as the renderer switch and carries the surface", function()
			local ts = archiveTable(fs, "mapconfig/tileset/tileset.lua")
			assert.are.equal("tileset", ts.renderer)
			assert.are.equal(MapExport.TILESET_FORMAT_VERSION, ts.format_version)
			assert.are.equal(1.5, ts.knobs.exposure)
			assert.are.equal("mapconfig/tileset/surface.png", ts.surface)
			assert.are.equal("SURF", fs.files["o/archive/mapconfig/tileset/surface.png"])
			assert.are.equal("a", ts.surface_slots.slot1)
		end)

		it("writes lights, decals, weather and blockout as their own files", function()
			local lights = archiveTable(fs, "mapconfig/lights.lua")
			assert.is_nil(lights.mapName)
			assert.are.equal(1, #lights.lights)
			assert.are.equal("crater_a", archiveTable(fs, "mapconfig/decals.lua")[1].tex)
			assert.are.same({ "mist" }, archiveTable(fs, "mapconfig/weather.lua").spawners[1].cegs)
			assert.are.same(
				{ { def = "ring_1", yaw = 10, scale = 2 } },
				archiveTable(fs, "mapconfig/blockout.lua").layers
			)
			assert.are.same({ "mist" }, report.references.CEGs)
		end)

		it("hands height, minimap and metal to the binary step", function()
			assert.are.equal("HEIGHT", fs.files["o/compile/heightmap.png"])
			assert.are.equal("MINI", fs.files["o/compile/minimap.png"])
			local json = fs.files["o/compile/compile.json"]
			-- a session with maxMetal 0.02: the amounts are 255 and 102 steps of it
			assert.is_truthy(json:find('"max_metal": 0.02', 1, true))
			assert.is_truthy(json:find("[0, 0, 255]", 1, true))
			assert.is_truthy(json:find("[1, 0, 102]", 1, true))
			assert.are.equal(0.02, archiveTable(fs, "mapinfo.lua").maxmetal)
		end)

		it("leaves units and the binary inputs out of the archive", function()
			assert.is_truthy(report.sections.units:find("mission", 1, true))
			for _, rel in ipairs(report.written) do
				assert.is_falsy(rel:find("heightmap", 1, true))
			end
		end)

		it("is byte-identical on a second run", function()
			local again = project()
			run(again, { name = "Test Map", version = "1.2" })
			for path, data in pairs(fs.files) do
				if path:sub(1, 2) == "o/" then
					assert.are.equal(data, again.files[path], path)
				end
			end
		end)
	end)

	it("fails without a manifest", function()
		local report = run(memoryFs({}))
		assert.is_false(report.ok)
		assert.is_truthy(report.errors[1]:find("project.lua", 1, true))
	end)

	it("ships the ramp image from the ramp library, or reports it missing", function()
		local tileset = 'return { biome = "osemo", ramp = "dusk.png" }'
		local fs = project({ ["p/tileset.lua"] = tileset, ["lib/Ramps/dusk.png"] = "RAMP" })
		run(fs, { assetDirs = { "lib/Ramps" } })
		local ts = archiveTable(fs, "mapconfig/tileset/tileset.lua")
		assert.are.equal("mapconfig/tileset/ramps/dusk.png", ts.ramp)
		assert.are.equal("RAMP", fs.files["o/archive/mapconfig/tileset/ramps/dusk.png"])

		fs = project({ ["p/tileset.lua"] = tileset })
		local report = run(fs)
		assert.are.equal("dusk.png", archiveTable(fs, "mapconfig/tileset/tileset.lua").ramp)
		assert.is_truthy(report.missing[1]:find("ramp image dusk.png", 1, true))
	end)

	it("reports a skybox it cannot find", function()
		local fs = project({ ["Terraform Brush/SkyBoxes/sky.dds"] = false })
		fs.files["Terraform Brush/SkyBoxes/sky.dds"] = nil
		local report = run(fs)
		assert.is_true(report.ok)
		assert.is_truthy(report.missing[1]:find("skybox", 1, true))
	end)
end)
