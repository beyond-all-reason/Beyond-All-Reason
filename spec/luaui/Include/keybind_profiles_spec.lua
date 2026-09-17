-- Guards the one-time migration of a player's own uikeys.txt, which is the only thing that
-- still resolves a keyload. The bind files it can name are gone from the tree, so what they
-- bound has to come from common/configs; a keyload that resolves to nothing costs the player
-- every binding it held, silently.
--
-- Nothing here reaches disk: the store and the keymap the migration writes are both discarded.

local Json = VFS.Include("common/luaUtilities/json.lua")

local function readFile(path)
	local file = assert(io.open(path, "r"), "cannot open " .. path)
	local contents = file:read("*a")
	file:close()

	return contents
end

local function loadJson(path)
	return Json.decode(readFile(path))
end

-- The profile the migration makes of a bind file the player wrote themselves.
local function migrate(uikeys)
	local realOpen, realLoadFile = io.open, VFS.LoadFile
	local realGetConfig, realSetConfig = Spring.GetConfigString, Spring.SetConfigString
	local realGetKeyCode = Spring.GetKeyCode

	VFS.LoadFile = function(path)
		if path == "uikeys.txt" then
			return uikeys
		end

		local file = realOpen(path, "rb")
		if not file then
			return nil
		end

		local contents = file:read("*a")
		file:close()

		return contents
	end
	Spring.GetConfigString = function(_, default)
		return default
	end
	Spring.SetConfigString = function() end
	Spring.GetKeyCode = function()
		return 1
	end
	io.open = function(path, mode)
		if mode == "w" then
			return { write = function() end, close = function() end }
		end

		return realOpen(path, mode)
	end

	local ok, result = pcall(function()
		local profiles = VFS.Include("luaui/Include/keybind_profiles.lua")
		profiles.load()

		return profiles.get(profiles.list()[1])
	end)

	io.open, VFS.LoadFile = realOpen, realLoadFile
	Spring.GetConfigString, Spring.SetConfigString = realGetConfig, realSetConfig
	Spring.GetKeyCode = realGetKeyCode

	assert(ok, tostring(result))

	return result
end

local function shippedProfile(defaults, name)
	for _, profile in ipairs(defaults.profiles) do
		if profile.name == name then
			return profile
		end
	end

	error("no shipped profile named " .. name)
end

local function boundActions(profile)
	local actions = {}
	for _, bind in ipairs(profile.binds) do
		actions[bind.action:match("^%S+")] = true
	end

	return actions
end

describe("migrating a keyload of a bind file the game no longer ships", function()
	local retired = loadJson("common/configs/keybind_retired_includes.json")
	local defaults = loadJson("common/configs/keybind_defaults.json")

	it("keeps what an include the presets pulled in bound", function()
		local profile = migrate(table.concat({
			"keyload luaui/configs/hotkeys/chat_and_ui_keys.txt",
			"keyload luaui/configs/hotkeys/gridmenu_keys.txt",
			"bind Any+f12 screenshot",
		}, "\n"))

		local expected = #retired["luaui/configs/hotkeys/chat_and_ui_keys.txt"]
			+ #retired["luaui/configs/hotkeys/gridmenu_keys.txt"]
			+ 1
		assert.are.equal(expected, #profile.binds)

		local actions = boundActions(profile)
		assert.is_true(actions.quitmenu)
		assert.is_true(actions.gridmenu_key)
		assert.is_true(actions.screenshot)
	end)

	it("keeps what a preset bound, now that it is a profile", function()
		local profile = migrate(table.concat({
			"keyload luaui/configs/hotkeys/grid_keys.txt",
			"bind Any+f12 screenshot",
		}, "\n"))

		assert.are.equal(#shippedProfile(defaults, "Grid").binds + 1, #profile.binds)
	end)

	it("keeps the player's own bindings when a keyload resolves to nothing", function()
		local profile = migrate(table.concat({
			"keyload luaui/configs/hotkeys/never_shipped_keys.txt",
			"bind Any+f12 screenshot",
		}, "\n"))

		assert.are.equal(1, #profile.binds)
	end)
end)
