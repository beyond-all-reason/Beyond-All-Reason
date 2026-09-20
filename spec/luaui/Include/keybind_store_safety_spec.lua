-- What the store does when it is handed something it cannot use: a keymap it is about to
-- overwrite, a profiles file it cannot read, and a store claiming a name the game ships.
--
-- Nothing here reaches disk. Every write the module makes is captured instead, and a read
-- only sees what the test put there or what an earlier write produced.

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

		-- Reads answer for what the test staged and for anything already written, so the
		-- backup naming sees the copies it has made rather than the real filesystem.
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
	it("keeps the keymap on a migration, and never over an earlier copy", function()
		local writes = {}
		run({ [STORE] = false, [KEYMAP] = "bind sc_a attack\n" }, writes, function(include)
			include().list()
			local first = writes[KEYMAP .. ".bak"]
			include().list()

			return first
		end)

		assert.are.equal("bind sc_a attack\n", writes[KEYMAP .. ".bak"])
		assert.is_not_nil(writes[KEYMAP .. ".bak.2"])
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
