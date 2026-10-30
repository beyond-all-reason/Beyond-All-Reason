-- Guards how widget defaults reach a profile. Nothing here reaches disk; writes are captured.

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local Json = require("common/luaUtilities/json")

local STORE = "LuaUI/Config/keybind_profiles.json"
local KEYMAP = "uikeys.txt"

local MANIFESTS = {
	{
		id = "gui_example",
		dir = "LuaUI/Widgets/gui_example/",
		loaded = true,
		manifest = {
			id = "gui_example",
			display_name = "Example",
			keybindings = {
				{ action = "example_toggle", label = "actions.toggle", defaultKeysets = { "sc_f13" } },
				{ action = "example_taken", label = "actions.toggle", defaultKeysets = { "esc" } },
			},
		},
	},
	{
		id = "gui_second",
		dir = "LuaUI/Widgets/gui_second/",
		loaded = true,
		manifest = {
			id = "gui_second",
			display_name = "Second",
			keybindings = {
				{ action = "second_toggle", label = "actions.toggle", defaultKeysets = { "sc_f13" } },
			},
		},
	},
}

local function run(files, writes, body, manifests)
	local realOpen = io.open

	local env = SpecEnv.new({
		VFS = {
			LoadFile = function(path)
				if files[path] ~= nil then
					return files[path]
				end

				local file = realOpen(path, "rb")
				if not file then
					return nil
				end

				local contents = file:read("*a")
				file:close()

				return contents
			end,
		},
		Spring = {
			GetConfigString = function(_, default)
				return default
			end,
			SetConfigString = function() end,
			GetKeyCode = function()
				return 1
			end,
		},
		io = {
			open = function(path, mode)
				if mode == "w" then
					writes[path] = ""

					return {
						write = function(_, text)
							writes[path] = writes[path] .. text
						end,
						close = function() end,
					}
				end

				return realOpen(path, mode)
			end,
		},
		WG = { widgetManifests = { widgets = manifests or MANIFESTS, revision = 0, changes = 0 } },
		widgetHandler = {
			GetWidgetsRevision = function()
				return 0
			end,
		},
	})

	return body(SpecEnv.include(env, "luaui/Include/keybind_profiles.lua"))
end

local function bindLines(text)
	local lines = {}
	for line in text:gmatch("[^\r\n]+") do
		if line:sub(1, 5) == "bind " then
			lines[#lines + 1] = line
		end
	end

	return lines
end

local function holds(lines, wanted)
	for _, line in ipairs(lines) do
		if line == wanted then
			return true
		end
	end

	return false
end

local function storedProfile(writes, name)
	for _, profile in ipairs(Json.decode(writes[STORE]).profiles) do
		if profile.name == name then
			return profile
		end
	end

	return nil
end

local function ownStore(profile)
	return Json.encode({ version = 2, active = profile.name, profiles = { profile } })
end

local function materialized(storeText, name, manifests)
	local writes = {}
	run({ [STORE] = storeText, [KEYMAP] = false }, writes, function(profiles)
		profiles.materialize(name)

		return {}
	end, manifests)

	return writes
end

describe("widget defaults on a shipped profile", function()
	it("are written out whatever else holds the key, after what the profile has there", function()
		local writes = materialized('{"version":2,"active":"Grid","profiles":[]}', "Grid")

		local lines = bindLines(writes[KEYMAP])
		assert.is_true(holds(lines, "bind sc_f13 example_toggle"))
		assert.is_true(holds(lines, "bind esc example_taken"))
		assert.is_true(holds(lines, "bind sc_f13 second_toggle"))
		local widgetAt, ownAt
		for i, line in ipairs(lines) do
			if line == "bind esc example_taken" then
				widgetAt = i
			elseif ownAt == nil and line:find("^bind esc ") then
				ownAt = i
			end
		end
		assert.is_true(ownAt < widgetAt)
		assert.are.same({}, Json.decode(writes[STORE]).profiles)
	end)
end)

describe("widget defaults on a player's profile", function()
	it("are written into it once and recorded as met", function()
		local writes =
			materialized(ownStore({ name = "Mine", binds = { { keyset = "esc", action = "quitmessage" } } }), "Mine")

		assert.is_true(holds(bindLines(writes[KEYMAP]), "bind sc_f13 example_toggle"))
		local mine = storedProfile(writes, "Mine")
		assert.are.same({
			{ keyset = "esc", action = "quitmessage" },
			{ keyset = "sc_f13", action = "example_toggle" },
			{ keyset = "esc", action = "example_taken" },
			{ keyset = "sc_f13", action = "second_toggle" },
		}, mine.binds)
		assert.are.same({ "example_toggle", "example_taken", "second_toggle" }, mine.seeded)
	end)

	it("do not come back once the player has removed one", function()
		local writes = materialized(
			ownStore({
				name = "Mine",
				binds = { { keyset = "esc", action = "quitmessage" } },
				seeded = { "example_toggle", "example_taken", "second_toggle" },
			}),
			"Mine"
		)

		assert.is_false(holds(bindLines(writes[KEYMAP]), "bind sc_f13 example_toggle"))
		assert.are.same({ { keyset = "esc", action = "quitmessage" } }, storedProfile(writes, "Mine").binds)
	end)

	it("read the profile's binds the way the engine does, stepping over malformed ones", function()
		local writes = materialized(
			ownStore({
				name = "Mine",
				basedOn = "Grid",
				binds = { { keyset = "x", action = "EXAMPLE_TOGGLE" }, { keyset = "a" }, "not a binding" },
			}),
			"Mine"
		)

		local lines = bindLines(writes[KEYMAP])
		assert.is_false(holds(lines, "bind sc_f13 example_toggle"))
		assert.is_true(holds(lines, "bind esc example_taken"))
	end)

	it("count as met by a profile made from a keymap", function()
		local writes = {}
		run({ [STORE] = '{"version":2,"active":"Grid","profiles":[]}', [KEYMAP] = false }, writes, function(profiles)
			profiles.create("Fresh", { { keyset = "esc", action = "quitmessage" } }, nil, "Grid")

			return {}
		end)

		local fresh = storedProfile(writes, "Fresh")
		assert.are.same({ { keyset = "esc", action = "quitmessage" } }, fresh.binds)
		assert.are.same({ "example_toggle", "example_taken", "second_toggle" }, fresh.seeded)
	end)
end)

describe("widget defaults made for one layout", function()
	local SMALL = "Grid (60% Keyboard)"
	local SHIPPED_STORE = '{"version":2,"active":"Grid","profiles":[]}'
	local LAYOUT_MANIFESTS = {
		{
			id = "gui_layout",
			dir = "LuaUI/Widgets/gui_layout/",
			loaded = true,
			manifest = {
				id = "gui_layout",
				keybindings = {
					{
						action = "layout_toggle",
						label = "actions.toggle",
						defaultKeysets = { "sc_f13" },
						profileKeysets = { grid60 = { "sc_f14" } },
					},
					{ action = "layout_only", label = "actions.only", profileKeysets = { grid60 = { "sc_f15" } } },
				},
			},
		},
	}

	it("go on top of the shared ones for that shipped profile only", function()
		local small = bindLines(materialized(SHIPPED_STORE, SMALL, LAYOUT_MANIFESTS)[KEYMAP])
		local grid = bindLines(materialized(SHIPPED_STORE, "Grid", LAYOUT_MANIFESTS)[KEYMAP])

		assert.is_true(holds(small, "bind sc_f13 layout_toggle"))
		assert.is_true(holds(small, "bind sc_f14 layout_toggle"))
		assert.is_true(holds(small, "bind sc_f15 layout_only"))
		assert.is_true(holds(grid, "bind sc_f13 layout_toggle"))
		assert.is_false(holds(grid, "bind sc_f14 layout_toggle"))
		assert.is_false(holds(grid, "bind sc_f15 layout_only"))
	end)

	it("follow a player's profile back to the shipped one it was made from", function()
		local writes = materialized(
			Json.encode({
				version = 2,
				active = "Mine",
				profiles = {
					{ name = "Base", basedOn = SMALL, binds = {} },
					{ name = "Mine", basedOn = "Base", binds = {} },
				},
			}),
			"Mine",
			LAYOUT_MANIFESTS
		)

		assert.are.same({
			{ keyset = "sc_f13", action = "layout_toggle" },
			{ keyset = "sc_f14", action = "layout_toggle" },
			{ keyset = "sc_f15", action = "layout_only" },
		}, storedProfile(writes, "Mine").binds)
		assert.are.same({ "layout_toggle", "layout_only" }, storedProfile(writes, "Mine").seeded)
	end)

	it("stay with the layout a profile was made from when the player compares it with another", function()
		local manifests = {
			{
				id = "gui_layout",
				dir = "LuaUI/Widgets/gui_layout/",
				loaded = true,
				manifest = {
					id = "gui_layout",
					keybindings = {
						{ action = "layout_load", label = "actions.load", profileKeysets = { grid = { "sc_f16" } } },
					},
				},
			},
		}
		local writes = {}
		local store = Json.encode({ version = 2, active = "Mine", profiles = { { name = "Mine", basedOn = SMALL, binds = {} } } })
		run({ [STORE] = store, [KEYMAP] = false }, writes, function(profiles)
			profiles.materialize("Mine")
			profiles.setBase("Mine", "Grid")
			profiles.materialize("Mine")

			return {}
		end, manifests)

		assert.is_false(holds(bindLines(writes[KEYMAP]), "bind sc_f16 layout_load"))
		assert.are.same({}, storedProfile(writes, "Mine").binds)
	end)
end)

describe("widget defaults on a keymap edited by hand", function()
	local SHIPPED_STORE = '{"version":2,"active":"Grid","profiles":[]}'

	local function adoptEdited(edit)
		local files, writes = { [STORE] = SHIPPED_STORE, [KEYMAP] = false }, {}
		local name = run(files, writes, function(profiles)
			profiles.materialize("Grid")
			files[KEYMAP] = edit(writes[KEYMAP])
			local adopted = profiles.adoptEditedKeymap()
			profiles.materialize(adopted)

			return adopted
		end)

		return writes, name
	end

	it("keeps out a default the player deleted from a file the game wrote", function()
		local writes, name = adoptEdited(function(text)
			return (text:gsub("bind sc_f13 example_toggle\n", ""))
		end)

		assert.is_false(holds(bindLines(writes[KEYMAP]), "bind sc_f13 example_toggle"))
		assert.are.same({ "example_toggle", "example_taken", "second_toggle" }, storedProfile(writes, name).seeded)
	end)

	it("offers every default to a file the game never wrote", function()
		local writes = adoptEdited(function()
			return "bind esc quitmessage\n"
		end)

		assert.is_true(holds(bindLines(writes[KEYMAP]), "bind sc_f13 example_toggle"))
	end)
end)
