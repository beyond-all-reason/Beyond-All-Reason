-- What the store does when handed something it cannot use: a keymap it is about to overwrite,
-- a profiles file it cannot read, and a store claiming a name the game ships.

local Json = VFS.Include("common/luaUtilities/json.lua")

local STORE = "LuaUI/Config/keybind_profiles.json"
local KEYMAP = "uikeys.txt"

local function run(files, writes, body)
	local realOpen, realLoadFile = io.open, VFS.LoadFile
	local realGetConfig, realSetConfig = Spring.GetConfigString, Spring.SetConfigString
	local realGetKeyCode = Spring.GetKeyCode

	VFS.LoadFile = function(path)
		if files[path] ~= nil then
			return files[path] or nil
		end
		if writes[path] then
			return writes[path]
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

		-- So the backup naming sees the copies it has made rather than the real filesystem.
		if files[path] or writes[path] then
			return {
				read = function()
					return files[path] or writes[path]
				end,
				close = function() end,
			}
		end

		return nil
	end

	local ok, result = pcall(function()
		return body(function()
			return VFS.Include("luaui/Include/keybind_profiles.lua")
		end)
	end)

	io.open, VFS.LoadFile = realOpen, realLoadFile
	Spring.GetConfigString, Spring.SetConfigString = realGetConfig, realSetConfig
	Spring.GetKeyCode = realGetKeyCode

	assert(ok, tostring(result))

	return result
end

describe("keeping a copy of what is about to be overwritten", function()
	it("keeps the keymap on a migration", function()
		local writes = {}
		run({ [STORE] = false, [KEYMAP] = "bind sc_a attack" }, writes, function(include)
			return include().list()
		end)

		assert.are.equal("bind sc_a attack", writes[KEYMAP .. ".bak"])
	end)

	-- A caller failing the same way every time asks for the same copy every time.
	it("does not stack copies of a keymap that has not changed", function()
		local writes = {}
		run({ [STORE] = false, [KEYMAP] = "bind sc_a attack" }, writes, function(include)
			include().list()

			return include().list()
		end)

		assert.is_nil(writes[KEYMAP .. ".bak.2"])
	end)

	it("keeps a second copy once the keymap differs, never over the first", function()
		local writes = {}
		local files = { [STORE] = false, [KEYMAP] = "bind sc_a attack" }
		run(files, writes, function(include)
			include().list()
			files[KEYMAP] = "bind sc_b attack"

			return include().list()
		end)

		assert.are.equal("bind sc_a attack", writes[KEYMAP .. ".bak"])
		assert.are.equal("bind sc_b attack", writes[KEYMAP .. ".bak.2"])
	end)

	it("keeps a profiles file it cannot decode", function()
		local writes = {}
		run({ [STORE] = "{ this is not json", [KEYMAP] = false }, writes, function(include)
			return include().list()
		end)

		assert.are.equal("{ this is not json", writes[STORE .. ".bak"])
	end)
end)

describe("a store naming a profile the game ships", function()
	local function shadowed()
		return Json.encode({
			version = 2,
			active = "Grid",
			profiles = { { name = "Grid", binds = { { keyset = "sc_a", action = "probe_shadow" } } } },
		})
	end

	it("keeps the player's entry under a free name", function()
		local names = run({ [STORE] = shadowed(), [KEYMAP] = false }, {}, function(include)
			return include().list()
		end)

		assert.are.same({ "Grid 2" }, names)
	end)

	it("writes out what ships rather than what the store called Grid", function()
		local writes = {}
		run({ [STORE] = shadowed(), [KEYMAP] = false }, writes, function(include)
			return include().materialize("Grid")
		end)

		assert.is_nil(writes[KEYMAP]:find("probe_shadow", 1, true))
	end)
end)

describe("a store naming a profile the game ships, continued", function()
	local function shadowed(extra)
		local list = { { name = "Grid", binds = { { keyset = "sc_a", action = "probe_shadow" } } } }
		if extra then
			list[2] = { name = "Grid", binds = { { keyset = "sc_b", action = "probe_second" } } }
		end

		return Json.encode({ version = 2, active = "Grid", profiles = list })
	end

	-- A selection left pointing at the name would move the player onto stock bindings.
	it("moves the selection onto the profile it renamed", function()
		local active = run({ [STORE] = shadowed(), [KEYMAP] = false }, {}, function(include)
			return include().activeName()
		end)

		assert.are.equal("Grid 2", active)
	end)

	it("applies their binds rather than the shipped ones", function()
		local writes = {}
		run({ [STORE] = shadowed(), [KEYMAP] = false }, writes, function(include)
			local profiles = include()

			return profiles.materialize(profiles.activeName())
		end)

		assert.is_not_nil(writes[KEYMAP]:find("probe_shadow", 1, true))
	end)

	-- Freeing the name must not stop the next entry claiming it counting as a repeat.
	it("still drops a second entry under the same name", function()
		local names = run({ [STORE] = shadowed(true), [KEYMAP] = false }, {}, function(include)
			return include().list()
		end)

		assert.are.same({ "Grid 2" }, names)
	end)
end)

describe("a store that stays unreadable", function()
	it("is copied once, not once per read", function()
		local writes = {}
		run({ [STORE] = "{ this is not json", [KEYMAP] = false }, writes, function(include)
			local profiles = include()
			profiles.list()
			profiles.invalidate()
			profiles.list()
			profiles.invalidate()

			return profiles.list()
		end)

		local copies = 0
		for path in pairs(writes) do
			if path:find(STORE .. ".bak", 1, true) then
				copies = copies + 1
			end
		end

		assert.are.equal(1, copies)
	end)
end)
