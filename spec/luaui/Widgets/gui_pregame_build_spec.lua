local function fixture()
	local f = { shift = true, position = { 200, 0, 0 }, left = false, start = { 0, 0, 0 }, actions = {} }
	local function noop() end
	local env = setmetatable({
		widget = {},
		math = setmetatable({
			distance2d = function(x, z, x2, z2)
				return math.sqrt((x - x2) ^ 2 + (z - z2) ^ 2)
			end,
		}, { __index = math }),
		WG = { resource_spot_finder = { isMetalMap = true } },
		Game = {},
		CMD = { MOVE = 10 },
		LOG = { INFO = 1 },
		UnitDefs = {
			[1] = { buildOptions = { 2, 3 }, xsize = 2, zsize = 2 },
			[2] = { extractsMetal = 0, xsize = 2, zsize = 2, modCategories = {} },
			[3] = { extractsMetal = 1, xsize = 2, zsize = 2, modCategories = {} },
		},
		require = function()
			return {
				IsStartUnitSpawnDisabled = function()
					return false
				end,
			}
		end,
		widgetHandler = {
			AddAction = function(_, name, fn, _, kind)
				f.actions[name .. kind] = fn
			end,
			RegisterGlobal = noop,
		},
		Spring = {
			GetGameFrame = function()
				return f.frame or 0
			end,
			GetLocalTeamID = function()
				return 0
			end,
			GetSpectatingState = function()
				return false
			end,
			GetTeamRulesParam = function()
				return f.startDef or 1
			end,
			GetTeamStartPosition = function()
				return unpack(f.start)
			end,
			GetModKeyState = function()
				return false, false, f.meta, f.shift
			end,
			GetMouseState = function()
				return 0, 0, f.left
			end,
			TraceScreenRay = function()
				return "ground", f.position
			end,
			GetGroundHeight = function()
				return 0
			end,
			GetBuildFacing = function()
				return 0
			end,
			Pos2BuildPos = function(_, x, y, z)
				return x, y, z
			end,
			TestBuildOrder = function()
				return f.blocked and 0 or 1
			end,
			GetMapDrawMode = function()
				return "normal"
			end,
			IsGUIHidden = function()
				return false
			end,
			Log = noop,
			SendCommands = noop,
		},
	}, { __index = _G })
	local chunk = assert(loadfile("luaui/Widgets/gui_pregame_build.lua"))
	setfenv(chunk, env)()
	f.widget = env.widget
	f.widget:Initialize()
	f.api = env.WG["pregame-build"]
	f.api.setPreGamestartDefID(2)
	f.api.setBuildQueue({ { 2, 100, 0, 0, 0 }, { 2, 300, 0, 0, 0 } })
	function f:modifier(kind, release)
		local fn = self.actions["commandinsert" .. (release and "r" or "p")]
		if fn then
			fn(nil, nil, { kind or "prepend_between" })
		end
	end
	function f:click(x, immediate)
		self.position = { x, 0, 0 }
		if immediate then
			self.api.setPreGamestartDefID(3)
		end
		self.left = true
		self.widget:MousePress(0, 0, 1)
		self.widget:Update(1)
		self.left = false
		self.widget:Update(1)
	end
	function f:expect(xs)
		local queue = self.api.getBuildQueue()
		assert(#queue == #xs, "unexpected queue length")
		for i, x in ipairs(xs) do
			assert(queue[i][2] == x, "unexpected position at queue index " .. i .. ": " .. queue[i][2])
		end
	end
	function f:quickMex()
		self.api.setPreGamestartDefID(nil)
		env.WG.resource_spot_finder.isMetalMap = false
		self.spot = { x = 200, y = 0, z = 0 }
		env.WG.resource_spot_finder.GetClosestMexSpot = function()
			return self.spot
		end
		env.WG.resource_spot_builder = {
			SpotHasExtractorQueued = function()
				return self.occupied
			end,
			PreviewExtractorCommand = function(_, def, spot)
				if self.noPlacement or self.unbuildable == def then
					return
				end
				return { def, spot.x, spot.y, spot.z, 0 }
			end,
		}
		env.UnitDefs[4] = { buildOptions = { 5 }, xsize = 2, zsize = 2 }
		env.UnitDefs[5] = { extractsMetal = 1, xsize = 2, zsize = 2, modCategories = {} }
		self.env = env
	end
	return f
end

describe("pregame command insertion", function()
	it("inserts a Shift build between existing commands", function()
		local f = fixture()
		f:modifier()
		f:click(200)
		f:expect({ 100, 200, 300 })
	end)

	it("inserts a dragged row into the route", function()
		local f = fixture()
		f:modifier()
		f.left = true
		f.widget:MousePress(0, 0, 1)
		f.position = { 232, 0, 0 }
		f.widget:Update(1)
		f.left = false
		f.widget:Update(1)
		f:expect({ 100, 200, 216, 232, 300 })
	end)

	it("handles an empty queue", function()
		local f = fixture()
		f.api.setBuildQueue({})
		f:modifier()
		f:click(200)
		f:expect({ 200 })
	end)

	it("uses the start position and can insert at either end", function()
		local f = fixture()
		f:modifier()
		f:click(56)
		f:click(408)
		f:expect({ 56, 100, 300, 408 })
	end)

	it("appends ordinary Shift builds after the modifier is released", function()
		local f = fixture()
		f:modifier()
		f:modifier(nil, true)
		f:click(200)
		f:expect({ 100, 300, 200 })
	end)

	it("inserts immediate extractor builds", function()
		local f = fixture()
		f:modifier()
		f:click(200, true)
		f:expect({ 100, 200, 300 })
	end)

	it("inserts move waypoints", function()
		local f = fixture()
		f:modifier()
		f.api.setPreGamestartDefID(nil)
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 200, 300 })
	end)

	it("prepends without Shift", function()
		local f = fixture()
		f.shift = false
		f:modifier()
		f:click(200)
		f:expect({ 200, 100, 300 })
	end)

	it("preserves ordered prepend mode", function()
		local f = fixture()
		f:modifier("prepend_queue")
		f:click(200)
		f:click(248)
		f:expect({ 200, 248, 100, 300 })
	end)

	it("still cancels overlapping builds", function()
		local f = fixture()
		f:modifier()
		f:click(100)
		f:expect({ 300 })
	end)

	it("rejects blocked placements", function()
		local f = fixture()
		f:modifier()
		f.blocked = true
		f:click(200)
		f:expect({ 100, 300 })
	end)

	it("appends safely before a start position is selected", function()
		local f = fixture()
		f.start = { -100, 0, -100 }
		f:modifier()
		f:click(200)
		f:expect({ 100, 300, 200 })
	end)
end)

describe("pregame right-click mex", function()
	it("builds without selecting a blueprint and replaces the queue without Shift", function()
		local f = fixture()
		f:quickMex()
		f.shift = false
		assert(f.widget:MousePress(0, 0, 3))
		f:expect({ 200 })
		assert(f.api.getBuildQueue()[1][1] == 3)
		assert(f.api.getPreGameDefID() == nil)
	end)
	it("appends with Shift and supports command insertion", function()
		local f = fixture()
		f:quickMex()
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300, 200 })
		assert(f.api.getBuildQueue()[3][1] == 3)
		f.api.setBuildQueue({ { 2, 100, 0, 0, 0 }, { 2, 300, 0, 0, 0 } })
		f:modifier()
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 200, 300 })
		assert(f.api.getBuildQueue()[2][1] == 3)
	end)
	it("uses the current faction even before the next draw", function()
		local f = fixture()
		f:quickMex()
		f.startDef = 4
		f.widget:MousePress(0, 0, 3)
		assert(f.api.getBuildQueue()[3][1] == 5)
	end)
	it("cancels an active blueprint instead of building a mex", function()
		local f = fixture()
		f:quickMex()
		f.api.setPreGamestartDefID(2)
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300 })
		assert(f.api.getPreGameDefID() == nil)
	end)
	it("keeps Shift-right-click movement away from spots", function()
		local f = fixture()
		f:quickMex()
		f.position = { 500, 0, 0 }
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300, 500 })
		assert(f.api.getBuildQueue()[3][1] == -10)
	end)
	it("does not replace existing builds at a blocked or already queued spot", function()
		for _, reason in ipairs({ "blocked", "occupied", "noPlacement", "overlap", "spawn" }) do
			local f = fixture()
			f:quickMex()
			f.shift = false
			f[reason] = true
			if reason == "overlap" then
				f.spot.x = 100
				f.position[1] = 100
			end
			if reason == "spawn" then
				f.start = { 200, 0, 0 }
			end
			f.widget:MousePress(0, 0, 3)
			f:expect({ 100, 300 })
		end
	end)
	it("does not build on metal maps or without a buildable mex", function()
		local f = fixture()
		f:quickMex()
		f.shift = false
		f.env.WG.resource_spot_finder.isMetalMap = true
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300 })
		f.env.WG.resource_spot_finder.isMetalMap = false
		f.env.UnitDefs[1].buildOptions = { 2 }
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300 })
	end)
	it("chooses a buildable water mex when the land mex cannot be placed", function()
		local f = fixture()
		f:quickMex()
		f.env.UnitDefs[1].buildOptions = { 3, 5 }
		f.unbuildable = 3
		f.widget:MousePress(0, 0, 3)
		assert(f.api.getBuildQueue()[3][1] == 5)
	end)
	it("does not quick-build after game start or without a start unit", function()
		local f = fixture()
		f:quickMex()
		f.shift = false
		f.frame = 1
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300 })
		f.frame = 0
		f.startDef = 999
		f.widget:MousePress(0, 0, 3)
		f:expect({ 100, 300 })
	end)
	it("prepends a right-click mex with the insert modifier without Shift", function()
		local f = fixture()
		f:quickMex()
		f.shift = false
		f:modifier()
		f.widget:MousePress(0, 0, 3)
		f:expect({ 200, 100, 300 })
		assert(f.api.getBuildQueue()[1][1] == 3)
	end)
end)
