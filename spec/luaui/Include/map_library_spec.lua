local Client = VFS.Include("luaui/Include/map_library.lua")

local function fixture()
	local state = {
		time = 100,
		busy = false,
		writes = 0,
		downloads = 0,
		reads = {},
		files = {
			status = {
				version = 1,
				session = "session",
				heartbeat = 100,
				remote = "repo",
				branch = "main",
				allow_push = true,
			},
			catalog = {
				version = 1,
				remote = "repo",
				branch = "main",
				revision = "abc",
				projects = {},
				stages = { "Design" },
			},
		},
	}
	state.options = {
		readJson = function(name)
			state.reads[name] = (state.reads[name] or 0) + 1
			return state.files[name]
		end,
		writeJson = function(name, value)
			state.writes = state.writes + 1
			state.files[name] = value
			return true
		end,
		now = function()
			return state.time
		end,
		isProjectBusy = function()
			return state.busy
		end,
		validateSlug = function(value)
			return type(value) == "string" and value:match("^[A-Za-z0-9_/-]+$") and not value:find("..", 1, true)
		end,
		downloaded = function(value)
			state.downloads = state.downloads + 1
			state.downloadedSlug = value
		end,
	}
	state.client = Client.new(state.options)
	return state
end

describe("map library queue", function()
	it("checks the confirmed destination after refreshing status, without writing on mismatch", function()
		for _, field in ipairs({ "session", "remote", "branch" }) do
			local state = fixture()
			local expected = { session = "session", remote = "repo", branch = "main" }
			state.files.status[field] = "changed"
			local ok, reason = state.client.request("publish", "arena", "Design", expected)
			assert(not ok and reason == "destination_changed" and state.writes == 0)
		end
		local state = fixture()
		assert(
			state.client.request(
				"publish",
				"arena",
				"Design",
				{ session = "session", remote = "repo", branch = "main" }
			)
		)
		assert(state.writes == 1)
	end)

	it("writes only a fixed versioned request, never commands or credentials", function()
		local state = fixture()
		local ok = state.client.request("publish", "arena", "Design")
		assert(ok)
		local request = state.files.request
		assert(request.version == 1 and request.operation == "publish")
		assert(request.source == "arena" and request.stage == "Design")
		assert(request.session == "session" and request.revision == "abc")
		assert(request.id:match("^[a-f0-9]+$") and #request.id == 24)
		assert(request.command == nil and request.token == nil and request.remote == nil)
	end)

	it("generates distinct request IDs with Recoil float32 random bounds across reloads", function()
		local function engineInteger(value)
			if value ~= 0 then
				local exponent = math.floor(math.log(math.abs(value)) / math.log(2))
				local step = 2 ^ (exponent - 23)
				value = math.floor(value / step + 0.5) * step
			end
			-- Recoil stores lua_Number as float before luaL_checkint converts it.
			if value >= 2147483648 then
				return -2147483648
			end
			return value
		end
		local samples = { 0, 1 - 2 ^ -24, 0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875, 0.0625, 0.5625, 0.3125 }
		local draws = 0
		local environment = setmetatable({
			math = setmetatable({
				random = function(lower, upper)
					if lower == nil then
						-- The module warms the generator with argument-less draws
						-- at load; those are floats and never become an id.
						return 0.5
					end
					lower, upper = engineInteger(lower), engineInteger(upper)
					assert(lower <= upper, "[spring_lua_unsynced_rand(lower, upper)] empty interval")
					draws = draws + 1
					return math.floor(samples[draws] * (upper - lower + 1)) + lower
				end,
			}, { __index = math }),
		}, { __index = _G })
		local state = fixture()
		local seen = {}
		for _, operation in ipairs({ "pull", "publish", "download" }) do
			local runtimeClient = VFS.Include("luaui/Include/map_library.lua", environment).new(state.options)
			local ok, requestID = runtimeClient.request(operation, "arena", "Design")
			assert(ok and requestID == state.files.request.id)
			assert(#requestID == 24 and requestID:match("^[a-f0-9]+$") and not seen[requestID])
			if operation == "pull" then
				assert(requestID == "0000ffff8000400000000064")
			end
			seen[requestID] = true
			state.files.request = nil
		end
		assert(draws == 12 and state.writes == 3)
	end)

	it("blocks duplicate requests both before acknowledgement and across Lua reload", function()
		local state = fixture()
		assert(state.client.request("pull"))
		assert(not state.client.request("pull"))
		local reloaded = Client.new(state.options)
		assert(reloaded.isBusy())
		assert(not reloaded.request("pull"))
		assert(state.writes == 1)
	end)

	it("refuses transfers during a project save or load", function()
		local state = fixture()
		state.busy = true
		local ok, reason = state.client.request("publish", "arena", "Design")
		assert(not ok and reason == "busy" and state.writes == 0)
	end)

	it("stale heartbeat disables sync without blocking local saves forever", function()
		local state = fixture()
		state.time = 120
		state.files.status.busy = true
		state.client.update(1)
		assert(not state.client.isBusy())
		local ok, reason = state.client.request("pull")
		assert(not ok and reason == "offline")
	end)

	it("read-only helper never receives a publish request", function()
		local state = fixture()
		state.files.status.allow_push = false
		local ok, reason = state.client.request("publish", "arena", "Design")
		assert(not ok and reason == "read_only" and state.writes == 0)
		assert(state.client.request("pull"))
	end)

	it("rejects unsupported operations, paths and pipeline folders", function()
		local state = fixture()
		assert(not state.client.request("shell", "git push"))
		assert(not state.client.request("publish", "../secret", "Design"))
		assert(not state.client.request("publish", "arena", "Unknown"))
		assert(state.writes == 0)
	end)

	it("does not read the unchanged catalog on every poll or frame", function()
		local state = fixture()
		local reads = state.reads.catalog
		for _ = 1, 10 do
			state.client.update(0.1)
		end
		state.client.update(1)
		assert(state.reads.catalog == reads)
	end)

	it("registers a completed download exactly once without restarting the game", function()
		local state = fixture()
		state.files.status.code = "downloaded"
		state.files.status.request_id = "done"
		state.files.status.local_slug = "arena--abc"
		state.client.update(1)
		state.client.update(1)
		assert(state.downloads == 1 and state.downloadedSlug == "arena--abc")
	end)

	it("rejects a cached catalog from another repository", function()
		local state = fixture()
		state.files.status.remote = "other-repo"
		state.files.status.session = "other-session"
		state.client.update(1)
		assert(state.client.catalog.revision == nil and #state.client.catalog.projects == 0)
	end)

	it("keeps requests blocked until helper removes its acknowledged queue file", function()
		local state = fixture()
		assert(state.client.request("pull"))
		state.files.status.request_id = state.files.request.id
		state.files.status.code = "pulled"
		state.files.status.busy = false
		assert(not state.client.request("pull"))
		state.files.request = nil
		assert(state.client.request("pull"))
	end)
end)
