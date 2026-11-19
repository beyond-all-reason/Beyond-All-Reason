-- CINEMATIC CAM's maths: flying, looking, the glide, the floor, dolly, orbit, lens, views.

local Cam = VFS.Include("luaui/Include/cinematic_cam.lua")

local function flat()
	return 100
end

local function level(x, z)
	return { x = x or 1000, y = 400, z = z or 1000, rx = math.pi / 2, ry = 0, fov = 45 }
end

local function near(expected, actual, tolerance)
	assert.is_true(math.abs(expected - actual) <= tolerance, expected .. " ~ " .. actual)
end

local function run(state, input, frames, ground)
	for _ = 1, frames do
		Cam.step(state, input, 1 / 60, ground or flat)
	end
	return state.pose
end

describe("cinematic cam", function()
	before_each(function()
		Cam.setBounds(nil)
	end)

	it("forward flies flat along the view, right to its right, up up", function()
		local state = Cam.new({ x = 1000, y = 400, z = 1000, rx = math.pi * 0.75, ry = 0, fov = 45 })
		local pose = run(state, { forward = 1 }, 120)
		assert.is_true(pose.z < 1000)
		near(1000, pose.x, 0.01)
		near(400, pose.y, 0.01)
		state = Cam.new(level())
		pose = run(state, { right = 1 }, 120)
		assert.is_true(pose.x > 1000)
		state = Cam.new(level())
		pose = run(state, { up = 1 }, 120)
		assert.is_true(pose.y > 400)
	end)

	it("flies faster the higher it is, Shift x4, Ctrl x0.25", function()
		local low, high = Cam.new(level()), Cam.new(level())
		high.pose.y, high.target.y = 2400, 2400
		run(low, {}, 1)
		run(high, {}, 1)
		assert.is_true(Cam.flySpeed(high) > 3 * Cam.flySpeed(low))
		near(4 * Cam.flySpeed(low), Cam.flySpeed(low, true), 0.01)
		near(0.25 * Cam.flySpeed(low), Cam.flySpeed(low, false, true), 0.01)
	end)

	it("looking turns and tilts, never past straight up or down", function()
		local state = Cam.new(level())
		run(state, { lookX = 100 }, 1)
		assert.is_true(state.target.ry > 0)
		run(state, { lookY = 100000 }, 1)
		near(Cam.MAX_RX, state.target.rx, 1e-6)
		run(state, { lookY = -100000 }, 1)
		near(Cam.MIN_RX, state.target.rx, 1e-6)
	end)

	it("glides to its target and settles, the yaw the short way round", function()
		local state = Cam.new(level())
		state.pose.ry, state.target.ry = 3, -3
		run(state, {}, 1)
		assert.is_true(state.pose.ry > 3)
		run(state, {}, 180)
		assert.is_true(Cam.settled(state))
	end)

	it("the eye never goes under the floor", function()
		local state = Cam.new(level())
		local pose = run(state, { up = -1 }, 600)
		near(100 + Cam.FLOOR, pose.y, 0.01)
	end)

	it("the wheel dollies toward the pivot and back", function()
		local state = Cam.new({ x = 1000, y = 1100, z = 1000, rx = math.pi * 0.75, ry = 0, fov = 45 })
		local pivot = Cam.pivot(state, flat)
		local before = state.pivotDistance
		Cam.dolly(state, 1, flat)
		near(before * Cam.DOLLY_STEP, state.pivotDistance, 0.01)
		local after = Cam.pivot(state, flat)
		near(pivot.x, after.x, 0.5)
		near(pivot.z, after.z, 0.5)
		Cam.dolly(state, -1, flat)
		near(before, state.pivotDistance, 0.01)
	end)

	it("a middle-drag orbits the pivot at its distance, looking at it", function()
		local state = Cam.new({ x = 1000, y = 1100, z = 2000, rx = math.pi * 0.75, ry = 0, fov = 45 })
		local pivot = Cam.pivot(state, flat)
		local distance = state.pivotDistance
		Cam.orbit(state, pivot, 200, 0, flat)
		local t = state.target
		local now = math.sqrt((t.x - pivot.x) ^ 2 + (t.y - pivot.y) ^ 2 + (t.z - pivot.z) ^ 2)
		near(distance, now, 0.5)
		assert.is_true(math.abs(t.x - 1000) > 50)
		local hit = Cam.aimPoint(t, flat)
		near(pivot.x, hit.x, 1)
		near(pivot.z, hit.z, 1)
	end)

	it("the lens narrows and widens within its range", function()
		local state = Cam.new(level())
		Cam.lens(state, 1)
		assert.are.equal(40, state.target.fov)
		Cam.lens(state, 100)
		assert.are.equal(Cam.MIN_FOV, state.target.fov)
		Cam.lens(state, -100)
		assert.are.equal(Cam.MAX_FOV, state.target.fov)
	end)

	it("HOLD HEIGHT keeps the height over the ground across a hill", function()
		local function hill(x)
			return x > 1500 and 300 or 100
		end
		local state = Cam.new(level())
		state.pose.ry, state.target.ry = math.pi / 2, math.pi / 2
		Cam.setHold(state, true, hill)
		run(state, { forward = 1 }, 600, hill)
		assert.is_true(state.target.x > 1500)
		near(300 + 300, state.target.y, 0.01)
	end)

	it("levels the pitch to the nearest 5 degrees", function()
		local state = Cam.new(level())
		state.target.rx = math.pi / 2 + math.rad(33)
		Cam.level(state)
		near(35, math.deg(state.target.rx - math.pi / 2), 1e-6)
	end)

	it("a saved view flies there; a snap lands at once", function()
		local state = Cam.new(level())
		local view = Cam.viewOf({ x = 3000, y = 900, z = 500, rx = 2, ry = 1, fov = 30 })
		Cam.jump(state, view)
		assert.are.equal(3000, state.target.x)
		assert.are.equal(1000, state.pose.x)
		Cam.jump(state, view, true)
		assert.are.equal(3000, state.pose.x)
		assert.are.equal(30, state.pose.fov)
	end)

	it("HOME is over the map's middle, and only with a map known", function()
		local state = Cam.new(level())
		assert.is_false(Cam.home(state, flat))
		Cam.setBounds(8000, 4000)
		assert.is_true(Cam.home(state, flat))
		assert.are.equal(4000, state.target.x)
		local hit = Cam.aimPoint(state.target, flat)
		near(2000, hit.z, 1)
	end)

	it("GUIDES: the 16:9 frame fits the screen, its thirds inside it", function()
		local g = Cam.guides(1000, 1000, 0, 0)
		assert.are.same({ 0, 218.75, 1000, 781.25 }, g.frame)
		assert.are.equal(4, #g.lines)
	end)

	it("each key scheme flies on its own keys, WASD for an unknown name", function()
		local scheme, name = Cam.keyScheme("nope")
		assert.are.equal("wasd", name)
		assert.are.same({ forward = 1, right = -1 }, Cam.keyMoves(scheme, { [26] = true, [4] = true }))
		assert.are.same({ forward = 0 }, Cam.keyMoves(scheme, { [26] = true, [22] = true }))
		local arrows = Cam.keyScheme("arrows")
		assert.are.same({ up = 1 }, Cam.keyMoves(arrows, { [75] = true, [26] = true }))
	end)
end)
