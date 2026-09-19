-- Reconciling the keymap on disk with the profiles behind it. Either side can move between
-- sessions: a game update changes a shipped profile, or a tool changes the player's own store.
-- Neither is an edit the player made to uikeys.txt, and only that last one may fork.
--
-- Nothing here reaches disk. Every write the module makes is captured instead.

local Json = VFS.Include("common/luaUtilities/json.lua")

local STORE = "LuaUI/Config/keybind_profiles.json"
local KEYMAP = "uikeys.txt"

-- Runs `body` with the module included against `files`, the engine stubbed, and every write
-- collected into `writes` by path. The stubs stay up for the whole body: emitting a profile
-- asks the engine to resolve its meta key, and adopting one reads the keymap back.
local function run(files, writes, body)
	local realOpen, realLoadFile = io.open, VFS.LoadFile
	local realGetConfig, realSetConfig = Spring.GetConfigString, Spring.SetConfigString
	local realGetKeyCode = Spring.GetKeyCode

	VFS.LoadFile = function(path)
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
			writes[path] = ""

			return {
				write = function(_, text)
					writes[path] = writes[path] .. text
				end,
				close = function() end,
			}
		end

		return realOpen(path, mode)
	end

	-- The body hands back one table: pcall keeps only the first result, and a nil answer among
	-- several would not survive being packed either.
	local ok, result = pcall(function()
		return body(VFS.Include("luaui/Include/keybind_profiles.lua"))
	end)

	io.open, VFS.LoadFile = realOpen, realLoadFile
	Spring.GetConfigString, Spring.SetConfigString = realGetConfig, realSetConfig
	Spring.GetKeyCode = realGetKeyCode

	assert(ok, tostring(result))

	return result
end

-- A player who has run the game once on the profile named: the store records what was written
-- and uikeys.txt holds it. Hands back both, as the next launch would find them.
local function afterFirstRun(name)
	local writes = {}
	run(
		{ [STORE] = '{"version":2,"active":"' .. name .. '","profiles":[]}', [KEYMAP] = false },
		writes,
		function(profiles)
			return { path = profiles.materialize(name) }
		end
	)

	return { store = assert(writes[STORE], "no store written"), keymap = assert(writes[KEYMAP], "no keymap written") }
end

-- What the next launch does with that pair, with `change` free to move either side first.
local function nextRun(disk, change)
	local writes = {}
	local result = run({ [STORE] = disk.store, [KEYMAP] = disk.keymap }, writes, function(profiles)
		if change then
			change(profiles)
		end

		return { adopted = profiles.adoptEditedKeymap(), active = profiles.activeName() }
	end)
	result.keymap = writes[KEYMAP]
	result.store = writes[STORE] or disk.store

	return result
end

describe("reconciling the keymap with the profiles behind it", function()
	it("carries a changed shipped profile onto a player sitting on it", function()
		local result = nextRun(afterFirstRun("Grid"), function(profiles)
			-- The shipped side gains an action, the way a game update adding one would.
			local grid = assert(profiles.isBuiltin("Grid"))
			grid.binds[#grid.binds + 1] = { keyset = "Ctrl+Alt+Shift+k", action = "somethingnew" }
		end)

		assert.is_nil(result.adopted)
		assert.are.equal("Grid", result.active)
		assert.is_truthy(result.keymap and result.keymap:find("somethingnew", 1, true))
	end)

	it("carries a store changed outside the game onto an untouched keymap", function()
		local disk = afterFirstRun("Grid")
		local store = Json.decode(disk.store)
		store.profiles[#store.profiles + 1] = {
			name = "Mine",
			binds = { { keyset = "Ctrl+Alt+Shift+m", action = "theirtoolwrotethis" } },
		}
		store.active = "Mine"
		disk.store = Json.encode(store)

		local result = nextRun(disk)

		assert.is_nil(result.adopted)
		assert.are.equal("Mine", result.active)
		assert.is_truthy(result.keymap and result.keymap:find("theirtoolwrotethis", 1, true))
	end)

	-- The stamp is of the file we emit. A player who points KeybindingFile somewhere else is
	-- read from that file instead, so the stamp never matches and the whole-keymap test is all
	-- that stands between them and a fresh copy of their keymap every single launch.
	it("forks a keymap it does not recognise only once", function()
		local disk = afterFirstRun("Grid")
		disk.keymap = disk.keymap .. "\nbind Ctrl+Alt+Shift+j theirownbinding"

		local first = nextRun(disk)
		assert.is_not_nil(first.adopted)

		-- Their file is untouched by that, and the fork now holds what it says.
		local second = nextRun({ store = first.store, keymap = disk.keymap })

		assert.is_nil(second.adopted)
		assert.are.equal(first.adopted, second.active)
	end)

	it("keeps a keymap the player edited themselves", function()
		local disk = afterFirstRun("Grid")
		disk.keymap = disk.keymap .. "\nbind Ctrl+Alt+Shift+j theirownbinding"

		local result = nextRun(disk)

		assert.is_not_nil(result.adopted)
		assert.are.equal(result.adopted, result.active)
	end)
end)
