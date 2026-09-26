-- Exercise the real transform pump with in-memory files. Everything that needs
-- a GL context (the mask and diffuse blits) is simply absent from the fixture,
-- so those steps have nothing to do; what is under test is the part that can
-- lose a map quietly — the section rewrites, the staged manifest, and what is
-- handed to the restart.

local function fixture(files, mapSize)
	local f = { files = files or {}, dirs = {}, opened = nil }
	local function noop() end
	f.receipt = { done = false, ok = false }
	f.project = {
		save = function(slug, opts)
			f.savedSlug = slug
			f.savedOpts = opts
			-- the real save is a pump of its own; land it immediately
			f.receipt.done = true
			f.receipt.ok = true
			return true, f.receipt
		end,
		current = function()
			return f.originSlug
		end,
		openStaged = function(slug, opts)
			f.opened = { slug = slug, opts = opts }
			return true
		end,
		isBusy = function()
			return false
		end,
	}
	f.environment = setmetatable({
		widget = {},
		WG = { MapProject = f.project },
		gl = {},
		GL = {},
		BAR = { Utilities = {} },
		Game = {
			mapSizeX = (mapSize and mapSize[1]) or 4096,
			mapSizeZ = (mapSize and mapSize[2]) or 2048,
			metalMapSquareSize = 16,
		},
		Spring = {
			Echo = noop,
			CreateDir = function(path)
				f.dirs[path] = true
			end,
			IsReplay = function()
				return false
			end,
			GetMapOptions = function()
				return { blank_map_height = 120 }
			end,
			GetGroundExtremes = function()
				return 0, 100
			end,
		},
		VFS = {
			Include = function(path)
				assert(path == "luaui/Include/map_transform.lua")
				return VFS.Include("luaui/Include/map_transform.lua")
			end,
			DirList = function()
				return {}
			end,
			RAW = 1,
		},
		io = {
			open = function(path, mode)
				if not mode:find("w", 1, true) then
					if not f.files[path] then
						return nil
					end
					return {
						read = function()
							return f.files[path]
						end,
						close = noop,
					}
				end
				return {
					write = function(_, content)
						f.files[path] = content
						return true
					end,
					close = noop,
				}
			end,
		},
		os = { remove = noop, clock = os.clock, date = os.date, time = os.time },
	}, { __index = _G })
	VFS.Include("luaui/Widgets/cmd_map_transform.lua", f.environment)
	f.widget = f.environment.widget
	f.widget:Initialize()
	f.transform = f.environment.WG.MapTransform
	f.pump = function()
		for _ = 1, 200 do
			if not f.transform.isBusy() then
				return
			end
			f.widget:DrawScreenPost()
		end
		error("transform did not finish")
	end
	return f
end

local SRC = "MapProjects/_transform/source/"
local DST = "MapProjects/_transform/staged/"

local function manifest(sections)
	local list = {}
	for name in pairs(sections) do
		list[#list + 1] = string.format("\t\t%s = { file = %q },", name, name .. ".lua")
	end
	return 'return {\n\tkind = "bar-map-project",\n\tmap = { size_x = 8, size_z = 4 },\n\tsections = {\n'
		.. table.concat(list, "\n")
		.. "\n\t},\n}\n"
end

local function baseFiles(extra)
	local files = {
		[SRC .. "project.lua"] = manifest(extra or {}),
	}
	for name, body in pairs(extra or {}) do
		files[SRC .. name .. ".lua"] = body
	end
	return files
end

local function staged(f, name)
	local chunk = assert(loadstring(assert(f.files[DST .. name], name .. " was not written")))
	return chunk()
end

describe("map transform section rewrites", function()
	it("turns feature positions and headings with the map", function()
		local f = fixture(baseFiles({
			features = "return { unitlist = {}, buildinglist = {}, objectlist = {"
				.. '{ name = "treeA", x = 100, z = 200, rot = 0 },'
				.. '{ name = "treeB", x = 100, z = 200, rot = 0, pitch = 0.1, roll = 0.2, y = 50 },'
				.. "} }",
		}))
		-- a quarter turn of a 8x4 map onto a 4x8 canvas
		assert.is_true(f.transform.apply({ rot = 90 }, 4, 8))
		f.pump()
		local out = staged(f, "features.lua")
		assert.are.equal(2, #out.objectlist)
		local a = out.objectlist[1]
		-- (100, 200) on a 4096x2048 map -> (2048 - 200, 100)
		assert.are.equal(1848, a.x)
		assert.are.equal(100, a.z)
		assert.are.equal(49152, a.rot) -- facing south becomes facing west
		local b = out.objectlist[2]
		assert.are.equal(0.1, b.pitch) -- a turn leaves the lean alone
		assert.are.equal(0.2, b.roll)
		assert.are.equal(50, b.y)
	end)

	it("moves metal spots on the metal grid, not just in the world", function()
		local f = fixture(baseFiles({
			metal = "return { squareSize = 16, width = 256, height = 128, spots = {"
				.. "{ x = 24, z = 24, mx = 1, mz = 1, amount = 1.5 },"
				.. "} }",
		}))
		assert.is_true(f.transform.apply({ rot = 90 }, 4, 8))
		f.pump()
		local out = staged(f, "metal.lua")
		local spot = out.spots[1]
		-- the square's centre goes through the transform, then back to a square
		assert.are.equal(126, spot.mx)
		assert.are.equal(1, spot.mz)
		assert.are.equal(1.5, spot.amount)
		-- and the grid header describes the NEW metal map
		assert.are.equal(128, out.width)
		assert.are.equal(256, out.height)
	end)

	it("drops what falls off a cropped canvas and keeps the rest", function()
		local f = fixture(baseFiles({
			startpos = "return { { x = 100, z = 100, allyTeam = 0, teamSlot = 1 },"
				.. "{ x = 2048, z = 1024, allyTeam = 1, teamSlot = 1 } }",
		}))
		-- half the width, true scale, centred: the corner position is cut away
		assert.is_true(f.transform.apply({ fit = "keep" }, 4, 4))
		f.pump()
		local out = staged(f, "startpos.lua")
		assert.are.equal(1, #out)
		assert.are.equal(1024, out[1].x)
		assert.are.equal(1024, out[1].z)
	end)

	it("reverses start box winding on a mirror", function()
		local f = fixture(baseFiles({
			startboxes = 'return { { allyTeam = 0, kind = "polygon", anchors = {'
				.. "{ x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 } } } }",
		}))
		assert.is_true(f.transform.apply({ mirrorX = true }, 8, 4))
		f.pump()
		local out = staged(f, "startboxes.lua")
		local anchors = out[1].anchors
		assert.are.equal(3, #anchors)
		-- mirrored in x and walked the other way round
		assert.are.equal(3996, anchors[1].x)
		assert.are.equal(100, anchors[1].z)
		assert.are.equal(4096, anchors[3].x)
		assert.are.equal(0, anchors[3].z)
	end)
end)

describe("map transform staging", function()
	it("writes a staged manifest at the new size that opens as the origin project", function()
		local f = fixture(baseFiles({}))
		f.originSlug = "campaign/arena"
		assert.is_true(f.transform.apply({ rot = 90 }, 4, 8))
		f.pump()
		local m = staged(f, "project.lua")
		assert.are.equal(4, m.map.size_x)
		assert.are.equal(8, m.map.size_z)
		assert.are.equal("campaign/arena", m.transform_of)
		-- the capture is a scratch save: not the session's Save target
		assert.are.equal("_transform/source", f.savedSlug)
		assert.is_true(f.savedOpts.internal)
	end)

	it("hands the restart the transform the heightmap import has to replay", function()
		local f = fixture(baseFiles({}))
		assert.is_true(f.transform.apply({ rot = 270, mirrorX = true }, 4, 8))
		f.pump()
		assert.are.equal("_transform/staged", f.opened.slug)
		local x = f.opened.opts.transform
		assert.are.equal(1, #x.placements)
		assert.are.equal(270, x.placements[1].rot)
		assert.is_true(x.placements[1].mirrorX)
		assert.are.equal(8, x.src_x) -- the map it came from, in map units
		assert.are.equal(4, x.src_z)
	end)

	it("refuses a transform that changes nothing", function()
		local f = fixture(baseFiles({}))
		local ok = f.transform.apply({ rot = 0 }, 8, 4)
		assert.is_false(ok)
		assert.is_false(f.transform.isBusy())
	end)

	it("refuses a canvas the blank map generator cannot build", function()
		local f = fixture(baseFiles({}))
		assert.is_false(f.transform.apply({ rot = 90 }, 2, 8))
		assert.is_false(f.transform.apply({ rot = 90 }, 4, 64))
	end)
end)

describe("map expansion", function()
	it("doubles the map and lays a mirrored copy in the new half", function()
		local f = fixture(baseFiles({
			features = "return { unitlist = {}, buildinglist = {}, objectlist = {"
				.. '{ name = "treeA", x = 100, z = 200, rot = 16384 },'
				.. "} }",
		}))
		-- 8x4 units (4096x2048 elmos) grows east into 16x4
		assert.is_true(f.transform.expand("right", "mirror"))
		f.pump()
		local m = staged(f, "project.lua")
		assert.are.equal(16, m.map.size_x)
		assert.are.equal(4, m.map.size_z)
		local out = staged(f, "features.lua")
		assert.are.equal(2, #out.objectlist)
		-- the original keeps its place, anchored away from the growth
		assert.are.equal(100, out.objectlist[1].x)
		assert.are.equal(200, out.objectlist[1].z)
		assert.are.equal(16384, out.objectlist[1].rot)
		-- the copy is mirrored across the seam: 2*4096 - 100
		assert.are.equal(8092, out.objectlist[2].x)
		assert.are.equal(200, out.objectlist[2].z)
		assert.are.equal(49152, out.objectlist[2].rot) -- east becomes west
	end)

	it("leaves the new half empty when asked, and flattens it to the canvas base", function()
		local f = fixture(baseFiles({
			features = "return { unitlist = {}, buildinglist = {}, objectlist = {"
				.. '{ name = "treeA", x = 100, z = 200, rot = 0 },'
				.. "} }",
		}))
		assert.is_true(f.transform.expand("down"))
		f.pump()
		local m = staged(f, "project.lua")
		assert.are.equal(8, m.map.size_x)
		assert.are.equal(8, m.map.size_z)
		local out = staged(f, "features.lua")
		assert.are.equal(1, #out.objectlist) -- nothing duplicated
		local x = f.opened.opts.transform
		assert.are.equal(1, #x.placements)
		assert.are.equal(120, x.fill_height) -- blank_map_height from the session
	end)

	it("gives the duplicated start positions somewhere of their own to stand", function()
		local f = fixture(baseFiles({
			startpos = "return { { x = 100, z = 100, allyTeam = 0, teamSlot = 1 },"
				.. "{ x = 200, z = 200, allyTeam = 1, teamSlot = 1 } }",
		}))
		assert.is_true(f.transform.expand("right", "mirror"))
		f.pump()
		local out = staged(f, "startpos.lua")
		assert.are.equal(4, #out)
		assert.are.equal(0, out[1].allyTeam)
		assert.are.equal(1, out[2].allyTeam)
		-- the copies land past the highest ally team in the original
		assert.are.equal(2, out[3].allyTeam)
		assert.are.equal(3, out[4].allyTeam)
		assert.are.equal(8092, out[3].x)
	end)

	it("refuses to double past the blank map generator's limit", function()
		-- already 32 units wide, which is the generator's ceiling
		local f = fixture(baseFiles({}), { 16384, 2048 })
		assert.is_false(f.transform.expand("right", "mirror"))
		assert.is_false(f.transform.isBusy())
	end)
end)
