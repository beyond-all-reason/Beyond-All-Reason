-- Guards the one-time migration of a player's own uikeys.txt, which is the only thing that
-- still resolves a keyload. The bind files it can name are gone from the tree, so what they
-- bound has to come from common/configs; a keyload that resolves to nothing costs the player
-- every binding it held, silently.
--
-- Also guards the binds that switch between profiles, which name their profile and so have
-- to be moved when one is renamed and dropped when one is deleted. Every surface owes that,
-- so it is the module's rule rather than the editor's.
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

-- The module with its shipped profiles read in. Included rather than required so each call
-- gets a store of its own, and only the reader is stubbed: nothing here has a store on disk.
local function includeProfiles()
	local realLoadFile, realGetKeyCode = VFS.LoadFile, Spring.GetKeyCode
	VFS.LoadFile = function(path)
		local file = io.open(path, "rb")
		if not file then
			return nil
		end

		local contents = file:read("*a")
		file:close()

		return contents
	end
	Spring.GetKeyCode = function()
		return 1
	end

	local ok, result = pcall(VFS.Include, "luaui/Include/keybind_profiles.lua")
	VFS.LoadFile, Spring.GetKeyCode = realLoadFile, realGetKeyCode
	assert(ok, tostring(result))

	return result
end

describe("the binds that switch between profiles", function()
	it("names the profile the key switches to", function()
		assert.are.equal("keybindprofile Grid", includeProfiles().switchAction("Grid"))
	end)

	it("follows a rename", function()
		local profiles = includeProfiles()
		local out, moved = profiles.retargetSwitchBinds({
			{ keyset = "Ctrl+1", action = profiles.switchAction("Mine") },
			{ keyset = "Ctrl+2", action = "screenshot" },
		}, "Mine", "Yours")

		assert.is_true(moved)
		assert.are.same({
			{ keyset = "Ctrl+1", action = "keybindprofile Yours" },
			{ keyset = "Ctrl+2", action = "screenshot" },
		}, out)
	end)

	it("goes with a delete", function()
		local profiles = includeProfiles()
		local out, moved = profiles.retargetSwitchBinds({
			{ keyset = "Ctrl+1", action = profiles.switchAction("Mine") },
			{ keyset = "Ctrl+2", action = "screenshot" },
		}, "Mine", nil)

		assert.is_true(moved)
		assert.are.same({ { keyset = "Ctrl+2", action = "screenshot" } }, out)
	end)

	it("leaves a keymap that switches to nothing of that name alone", function()
		local profiles = includeProfiles()
		local binds = { { keyset = "Ctrl+2", action = "screenshot" } }
		local out, moved = profiles.retargetSwitchBinds(binds, "Mine", "Yours")

		assert.is_false(moved)
		assert.are.same(binds, out)
	end)
end)

-- What a player wrote in their own uikeys.txt, read the way the engine would have read it.
-- The reader resolves a keyload itself, so the file stub has to outlast the include.
local function parse(text)
	local profiles = includeProfiles()
	local realLoadFile = VFS.LoadFile
	VFS.LoadFile = function(path)
		local file = io.open(path, "rb")
		if not file then
			return nil
		end

		local contents = file:read("*a")
		file:close()

		return contents
	end

	local ok, binds = pcall(profiles.parseBindFile, text)
	VFS.LoadFile = realLoadFile
	assert(ok, tostring(binds))

	return binds or {}
end

local function keysetsFor(binds, action)
	local out = {}
	for _, b in ipairs(binds) do
		if b.action == action then
			out[#out + 1] = b.keyset
		end
	end

	return out
end

local GRID = "unbindall\nkeyload luaui/configs/hotkeys/grid_keys.txt\n"

describe("unbinding a keyset a player named their own way", function()
	-- CKeySet::Parse promotes a modifier named on its own to Any+, so this is the keyset the
	-- profiles bind movereset and moverotate to. Matched as the text it was written as, it was
	-- neither, and both survived into the profile the migration made.
	it("takes a bare modifier as the Any+ keyset the engine reads it as", function()
		local binds = parse(GRID .. "unbindkeyset alt\n")

		assert.are.same({}, keysetsFor(binds, "moverotate"))
		assert.are.same({}, keysetsFor(binds, "movereset"))
	end)

	it("takes the modifiers in whatever order they were written", function()
		local binds = parse("unbindall\nbind Ctrl+Alt+sc_x attack\nunbindkeyset Alt+Ctrl+sc_x\n")

		assert.are.same({}, keysetsFor(binds, "attack"))
	end)

	it("names one action on the keyset without taking the others with it", function()
		local binds = parse(GRID .. "unbind alt moverotate\n")

		assert.are.same({}, keysetsFor(binds, "moverotate"))
		assert.are.same({ "Any+alt" }, keysetsFor(binds, "movereset"))
	end)

	-- A scancode and a keycode are different keys off qwerty, so they stay different keysets.
	it("leaves a scancode alone when a keycode of the same letter is named", function()
		local binds = parse("unbindall\nbind sc_a attack\nunbindkeyset a\n")

		assert.are.same({ "sc_a" }, keysetsFor(binds, "attack"))
	end)
end)

describe("unbinding an action a file spells in a different case", function()
	-- The engine lowercases a command word as it parses the bind, so the two spellings are one
	-- action to it. The shipped presets moved HideInterface to hideinterface at some point, and
	-- a file written either side of that still means to unbind the same thing.
	it("matches whatever case the action was bound under", function()
		local binds = parse("bind sc_a HideInterface\nunbindaction hideinterface\n")

		assert.are.same({}, keysetsFor(binds, "HideInterface"))
	end)

	it("does the same for the unbind that names a keyset", function()
		local binds = parse("bind sc_a HideInterface\nunbind sc_a hideinterface\n")

		assert.are.same({}, keysetsFor(binds, "HideInterface"))
	end)
end)

describe("unbinding a keychain", function()
	-- The engine stores a chain under its last tap, so that is the keyset an unbind names.
	it("drops a chain named by its last tap", function()
		local binds = parse("bind sc_l,sc_l,sc_l probe_chain\nunbindkeyset sc_l\n")

		assert.are.same({}, keysetsFor(binds, "probe_chain"))
	end)

	it("drops it for the unbind that also names the command", function()
		local binds = parse("bind sc_l,sc_l,sc_l probe_chain\nunbind sc_l probe_chain\n")

		assert.are.same({}, keysetsFor(binds, "probe_chain"))
	end)

	-- CKeySet::Parse rejects the commas, so the directive names no keyset and takes nothing.
	it("drops nothing for a directive naming the whole chain", function()
		local binds = parse("bind sc_l,sc_l,sc_l probe_chain\nunbindkeyset sc_l,sc_l,sc_l\n")

		assert.are.same({ "sc_l,sc_l,sc_l" }, keysetsFor(binds, "probe_chain"))
	end)
end)

describe("inferring which shipped profile a keymap came from", function()
	-- The engine lowercases a command word as it parses a bind, and the shipped data has moved
	-- between spellings, so a profile carrying the older one is still that profile.
	it("is not thrown by the case an action was written in", function()
		local profiles = includeProfiles()
		local grid = assert(profiles.isBuiltin("Grid"))
		local capitalised = {}
		for i, b in ipairs(grid.binds) do
			capitalised[i] = { keyset = b.keyset, action = (b.action:gsub("^%l", string.upper)) }
		end

		assert.are.equal("Grid", profiles.inferBase({ binds = capitalised }))
	end)
end)
