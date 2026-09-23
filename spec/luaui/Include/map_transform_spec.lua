-- The shared math behind SCENE > Dimensions > MAP TRANSFORM. Every layer of a
-- map (terrain, masks, features, metal, start boxes) is moved through this one
-- object, so a sign error here silently tears a map apart in a way that only
-- shows up after a restart. The conventions it commits to are asserted here.

local MapTransform = VFS.Include("luaui/Include/map_transform.lua")

-- Deliberately non-square, so an axis swap cannot pass by accident.
local W, H = 6144, 8192

local function oriented(spec)
	local ow, oh = MapTransform.orientedSize(spec.rot or 0, W, H)
	return MapTransform.new(spec, W, H, ow, oh)
end

describe("map transform geometry", function()
	it("turns a quarter clockwise, as seen on the minimap", function()
		local T = MapTransform.new({ rot = 90 }, W, H, H, W)
		-- north-west corner -> north-east, and the old south edge becomes the
		-- new west edge
		local x, z = T:srcToDst(0, 0)
		assert.are.equal(H, x)
		assert.are.equal(0, z)
		x, z = T:srcToDst(0, H)
		assert.are.equal(0, x)
		assert.are.equal(0, z)
		x, z = T:srcToDst(W, 0)
		assert.are.equal(H, x)
		assert.are.equal(W, z)
	end)

	it("swaps the footprint on a quarter turn only", function()
		local ow, oh = MapTransform.orientedSize(90, W, H)
		assert.are.equal(H, ow)
		assert.are.equal(W, oh)
		ow, oh = MapTransform.orientedSize(180, W, H)
		assert.are.equal(W, ow)
		assert.are.equal(H, oh)
	end)

	it("reads back every position it wrote", function()
		local specs = {
			{ rot = 0 },
			{ rot = 90 },
			{ rot = 180 },
			{ rot = 270 },
			{ rot = 0, mirrorX = true },
			{ rot = 90, mirrorZ = true },
			{ rot = 270, mirrorX = true },
		}
		local points = { { 0, 0 }, { W, 0 }, { 0, H }, { W, H }, { 1234, 5678 } }
		for _, spec in ipairs(specs) do
			local T = oriented(spec)
			for _, p in ipairs(points) do
				local dx, dz = T:srcToDst(p[1], p[2])
				local sx, sz = T:dstToSrc(dx, dz)
				assert.is_true(math.abs(sx - p[1]) < 0.001)
				assert.is_true(math.abs(sz - p[2]) < 0.001)
			end
		end
	end)

	it("folds two mirrors into the half turn they are", function()
		local spec = MapTransform.canonical({ mirrorX = true, mirrorZ = true })
		assert.are.equal(180, spec.rot)
		assert.is_false(spec.mirrorX)
		assert.is_false(spec.mirrorZ)
		local both = MapTransform.new({ mirrorX = true, mirrorZ = true }, W, H, W, H)
		local half = MapTransform.new({ rot = 180 }, W, H, W, H)
		local ax, az = both:srcToDst(1000, 2000)
		local bx, bz = half:srcToDst(1000, 2000)
		assert.are.equal(bx, ax)
		assert.are.equal(bz, az)
	end)

	it("keeps screen-space flips honest on a turned map", function()
		-- mirror is applied BEFORE the rotation, so a horizontal flip of what
		-- the user sees is a mirror in Z once the map is on its side
		local upright = MapTransform.flipScreen({ rot = 0 }, "h")
		assert.is_true(upright.mirrorX)
		assert.is_false(upright.mirrorZ)
		local turned = MapTransform.flipScreen({ rot = 90 }, "h")
		assert.is_true(turned.mirrorZ)
		assert.is_false(turned.mirrorX)
		local twice = MapTransform.flipScreen(MapTransform.flipScreen({ rot = 90 }, "h"), "h")
		assert.is_false(twice.mirrorX)
		assert.is_false(twice.mirrorZ)
		assert.are.equal(90, twice.rot)
	end)
end)

describe("map transform orientations", function()
	it("turns headings with the map", function()
		-- engine heading: 0 = +z = south, 16384 = +x = east. Turning the map a
		-- quarter clockwise leaves a thing that faced south facing west.
		local T = MapTransform.new({ rot = 90 }, W, H, H, W)
		assert.are.equal(49152, T:heading(0))
		assert.are.equal(0, T:heading(16384))
	end)

	it("mirrors headings by silhouette", function()
		local mx = MapTransform.new({ mirrorX = true }, W, H, W, H)
		assert.are.equal(49152, mx:heading(16384)) -- east becomes west
		assert.are.equal(0, mx:heading(0)) -- south is on the mirror axis
		local mz = MapTransform.new({ mirrorZ = true }, W, H, W, H)
		assert.are.equal(32768, mz:heading(0)) -- south becomes north
		assert.are.equal(24576, mz:heading(8192)) -- south-east becomes north-east
	end)

	it("leaves tilt alone on a turn and flips only roll on a mirror", function()
		local turn = MapTransform.new({ rot = 90 }, W, H, H, W)
		local pitch, roll = turn:tilt(0.2, 0.3)
		assert.are.equal(0.2, pitch)
		assert.are.equal(0.3, roll)
		local mirror = MapTransform.new({ mirrorZ = true }, W, H, W, H)
		pitch, roll = mirror:tilt(0.2, 0.3)
		assert.are.equal(0.2, pitch)
		assert.are.equal(-0.3, roll)
	end)
end)

describe("map transform fitting", function()
	it("stretches onto the new canvas", function()
		local T = MapTransform.new({ fit = "stretch" }, 4096, 4096, 8192, 4096)
		local x, z = T:srcToDst(2048, 2048)
		assert.are.equal(4096, x)
		assert.are.equal(2048, z)
		local sx, sz = T:sizeScale()
		assert.are.equal(2, sx)
		assert.are.equal(1, sz)
	end)

	it("places the map by its anchor at true scale", function()
		local centred = MapTransform.new({ fit = "keep" }, 4096, 4096, 8192, 8192)
		local x, z = centred:srcToDst(0, 0)
		assert.are.equal(2048, x)
		assert.are.equal(2048, z)
		local corner = MapTransform.new({ fit = "keep", anchorX = -1, anchorZ = 1 }, 4096, 4096, 8192, 8192)
		x, z = corner:srcToDst(0, 0)
		assert.are.equal(0, x)
		assert.are.equal(4096, z)
		local sx, sz = centred:sizeScale()
		assert.are.equal(1, sx)
		assert.are.equal(1, sz)
	end)

	it("reports what a crop leaves behind", function()
		local crop = MapTransform.new({ fit = "keep" }, 8192, 8192, 4096, 4096)
		local _, _, insideCorner = crop:srcToDst(100, 100)
		assert.is_false(insideCorner)
		local _, _, insideCentre = crop:srcToDst(4096, 4096)
		assert.is_true(insideCentre)
	end)

	it("knows when there is nothing to do", function()
		assert.is_true(MapTransform.new({}, W, H, W, H):isIdentity())
		assert.is_false(MapTransform.new({ rot = 180 }, W, H, W, H):isIdentity())
		assert.is_false(MapTransform.new({}, W, H, W, H + 1024):isIdentity())
	end)
end)

describe("map expansion plan", function()
	it("doubles along the growth axis and anchors the map away from it", function()
		local plan, dstW, dstH = MapTransform.expandPlan("right", "mirror", W, H)
		assert.are.equal(W * 2, dstW)
		assert.are.equal(H, dstH)
		assert.are.equal(2, #plan)
		assert.are.equal(-1, plan[1].anchorX) -- the map keeps the west side
		assert.are.equal(1, plan[2].anchorX) -- the copy takes the new east side
		assert.is_true(plan[2].mirrorX)
		assert.is_false(plan[2].mirrorZ)
	end)

	it("mirrors across the seam and flips along it, per axis", function()
		-- growing down: across the seam is a Z mirror, along it is an X one
		local plan = MapTransform.expandPlan("down", "mirror", W, H)
		assert.is_true(plan[2].mirrorZ)
		assert.is_false(plan[2].mirrorX)
		plan = MapTransform.expandPlan("down", "flip", W, H)
		assert.is_true(plan[2].mirrorX)
		assert.is_false(plan[2].mirrorZ)
		-- and both is a half turn, which canonical() says out loud
		plan = MapTransform.expandPlan("down", "both", W, H)
		local spec = MapTransform.canonical(plan[2])
		assert.are.equal(180, spec.rot)
		assert.is_false(spec.mirrorX)
		assert.is_false(spec.mirrorZ)
	end)

	it("leaves no seam: the mirrored copy meets the map exactly", function()
		local plan, dstW, dstH = MapTransform.expandPlan("right", "mirror", W, H)
		local a = MapTransform.new(plan[1], W, H, dstW, dstH)
		local b = MapTransform.new(plan[2], W, H, dstW, dstH)
		-- the map's east edge is where both halves meet
		local ax, az = a:srcToDst(W, 1234)
		local bx, bz = b:srcToDst(W, 1234)
		assert.are.equal(ax, bx)
		assert.are.equal(az, bz)
		assert.are.equal(W, ax)
		-- and the copy's far corner is the new east edge
		local fx = b:srcToDst(0, 0)
		assert.are.equal(dstW, fx)
	end)

	it("plans one placement when the new half stays empty", function()
		local plan, dstW, dstH = MapTransform.expandPlan("up", nil, W, H)
		assert.are.equal(1, #plan)
		assert.are.equal(W, dstW)
		assert.are.equal(H * 2, dstH)
		assert.are.equal(1, plan[1].anchorZ) -- the map keeps the south side
	end)
end)

-- The WORLD PATTERN FRAME: the affine a turned map hands the tileset shader so
-- its world-anchored placement patterns (the stagger mask, the fbm fields, the
-- anti-tile warp) turn with it instead of staying locked to the world axes. A
-- sign error here leaves a map's paint right and everything between it re-rolled,
-- which is exactly the bug it was written for.
describe("world pattern frame", function()
	local function apply(f, x, z)
		return f[1] * x + f[2] * z + f[5], f[3] * x + f[4] * z + f[6]
	end

	local function frameOf(T)
		return { T:composeFrame(nil) }
	end

	it("reproduces dstToSrc exactly, for every turn and mirror", function()
		for _, rot in ipairs({ 0, 90, 180, 270 }) do
			for _, mir in ipairs({ { false, false }, { true, false }, { false, true } }) do
				local ow, oh = MapTransform.orientedSize(rot, W, H)
				local spec = { rot = rot, mirrorX = mir[1], mirrorZ = mir[2], fit = "keep" }
				local T = MapTransform.new(spec, W, H, ow, oh)
				local f = { T:affine() }
				for _, p in ipairs({ { 0, 0 }, { ow, oh }, { 731, 2049 }, { 3001, 17 } }) do
					local sx, sz = T:dstToSrc(p[1], p[2])
					local ax, az = apply(f, p[1], p[2])
					assert.are.equal(sx, ax)
					assert.are.equal(sz, az)
				end
			end
		end
	end)

	it("undoes the turn: a point of ground reads the pattern it was authored under", function()
		local T = MapTransform.new({ rot = 90, fit = "keep" }, W, H, H, W)
		local f = frameOf(T)
		for _, p in ipairs({ { 0, 0 }, { W, H }, { 100, 4000 }, { 2048, 2560 } }) do
			local dx, dz = T:srcToDst(p[1], p[2])
			local px, pz = apply(f, dx, dz)
			assert.are.equal(p[1], px)
			assert.are.equal(p[2], pz)
		end
	end)

	it("composes: a quarter turn twice is the half turn's frame", function()
		local a = MapTransform.new({ rot = 90, fit = "keep" }, W, H, H, W)
		local b = MapTransform.new({ rot = 90, fit = "keep" }, H, W, W, H)
		local twice = { b:composeFrame(frameOf(a)) }
		local half = { MapTransform.new({ rot = 180, fit = "keep" }, W, H, W, H):affine() }
		for i = 1, 6 do
			assert.are.equal(half[i], twice[i])
		end
	end)

	it("comes back to identity after four quarter turns, and says so", function()
		local f, w, h = nil, W, H
		for _ = 1, 4 do
			f = { MapTransform.new({ rot = 90, fit = "keep" }, w, h, h, w):composeFrame(f) }
			w, h = h, w
		end
		assert.is_true(MapTransform.isIdentityFrame(f[1], f[2], f[3], f[4], f[5], f[6]))
		assert.is_true(MapTransform.isIdentityFrame(nil))
		assert.is_false(MapTransform.isIdentityFrame(0, 1, -1, 0, 0, 0))
	end)

	it("carries a mirror, and a stretch scales the pattern with the map", function()
		local m = frameOf(MapTransform.new({ rot = 0, mirrorX = true, fit = "keep" }, W, H, W, H))
		assert.are.equal(-1, m[1] * m[4] - m[2] * m[3]) -- a reflection, not a turn
		assert.is_false(MapTransform.isIdentityFrame(m[1], m[2], m[3], m[4], m[5], m[6]))
		local s = frameOf(MapTransform.new({ rot = 0, fit = "stretch" }, W, H, W * 2, H * 2))
		assert.are.equal(0.5, s[1])
		assert.are.equal(0.5, s[4])
	end)

	it("leaves the kept half's patterns put when the map is doubled", function()
		local plan, dstW, dstH = MapTransform.expandPlan("right", "mirror", W, H)
		local f = frameOf(MapTransform.new(plan[1], W, H, dstW, dstH))
		assert.is_true(MapTransform.isIdentityFrame(f[1], f[2], f[3], f[4], f[5], f[6]))
	end)
end)
