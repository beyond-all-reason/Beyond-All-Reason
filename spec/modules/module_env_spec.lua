local Derive = require("tools/engine_handles/derive")
local ModuleEnv = require("modules/module_env")
local ModuleHandler = require("modules/module_handler")
local handleOf = ModuleEnv.HandleOf
local engineSides = Derive.Sides

-- A module file runs in an environment of its own (modules/module_env.lua): the engine while it loads, the language
-- for its whole life, and nothing else. Spring comes through a proxy for the file's handle.

-- Serves module files from memory while fn runs, the way the game's VFS would.
---@param sources table<string, string> path -> Lua source
---@param fn fun(): any
---@return any
local function serving(sources, fn)
	local realInclude = VFS.Include
	VFS.Include = function(path, env)
		local source = sources[path]
		if source == nil then
			error("no fixture at " .. path)
		end
		local chunk = assert(loadstring(source, "=" .. path)) --[[@as fun(): any]]
		setfenv(chunk, env --[[@as table]])
		return chunk()
	end
	local ok, result = pcall(fn)
	VFS.Include = realInclude
	if not ok then
		error(result, 0)
	end
	return result
end

---@param name string a path under modules/
---@param source string
---@return fun(outer: table, injected: table|nil): any
local function fileNamed(name, source)
	return function(outer, injected)
		local path = "modules/" .. name
		return serving({ [path] = source }, function()
			return ModuleEnv.Include(path, outer, nil, injected)
		end)
	end
end

describe("the environment a module file runs in", function()
	local outer ---@type table the handle's environment the fixture files run over

	before_each(function()
		outer = {
			pairs = pairs,
			type = type,
			string = string,
			Spring = {
				GetGameFrame = function()
					return 7
				end,
				GetMouseState = function()
					return 1, 2
				end,
				CreateUnit = function() end,
			},
			Game = { mapSizeX = 4096 },
			GG = {},
		}
	end)

	it("hands the file the engine and the language while it loads", function()
		local returned = fileNamed(
			"fixture/api.lua",
			[[
			local Spring = Spring
			local size = Game.mapSizeX
			return { frame = function() return Spring.GetGameFrame() end, size = size, isTable = type(GG) == "table" }
		]]
		)(outer)
		assert.are.equal(7, returned.frame())
		assert.are.equal(4096, returned.size)
		assert.is_true(returned.isTable)
	end)

	it("after load, an engine global the file did not import is an error naming the import", function()
		local returned = fileNamed(
			"fixture/api.lua",
			[[
			return { size = function() return Game.mapSizeX end }
		]]
		)(outer)
		assert.error_matches(
			returned.size,
			"modules/fixture/api.lua reads Game after load; import it at the top of the file: local Game = Game",
			1,
			true
		)
	end)

	it("the language stays for the life of the file", function()
		local returned = fileNamed(
			"fixture/api.lua",
			[[
			return { kind = function(x) return type(x) .. string.rep("!", 1) end }
		]]
		)(outer)
		assert.are.equal("number!", returned.kind(1))
	end)

	it("a global module files are not offered is an error at any time", function()
		assert.error_matches(function()
			fileNamed("fixture/api.lua", [[ local h = gadgetHandler ]])(outer)
		end, "modules/fixture/api.lua reads global 'gadgetHandler', which module files are not offered", 1, true)
	end)

	it("a write to a global is an error", function()
		assert.error_matches(function()
			fileNamed("fixture/api.lua", [[ Leaked = 1 ]])(outer)
		end, "modules/fixture/api.lua writes global 'Leaked'; declare it local", 1, true)
	end)

	it("injected names are the file's for its whole life", function()
		local returned = fileNamed(
			"fixture/policies/x.lua",
			[[
			Policies.seen = true
			return { later = function() return Policies.seen end }
		]]
		)(outer, { Policies = {} })
		assert.is_true(returned.later())
	end)

	describe("Spring, by handle", function()
		it("a file that runs in any handle may call neither handle's own functions", function()
			local returned = fileNamed(
				"fixture/api.lua",
				[[
				local Spring = Spring
				return { frame = Spring.GetGameFrame, mouse = function() return Spring.GetMouseState() end, order = function() return Spring.CreateUnit() end }
			]]
			)(outer)
			assert.are.equal(7, returned.frame())
			assert.error_matches(
				returned.mouse,
				"modules/fixture/api.lua calls Spring.GetMouseState, which the engine offers in the unsynced handle only; this file runs in any handle",
				1,
				true
			)
			assert.error_matches(
				returned.order,
				"modules/fixture/api.lua calls Spring.CreateUnit, which the engine offers in the synced handle only; this file runs in any handle",
				1,
				true
			)
		end)

		it("api_synced.lua may call the synced handle's, not the unsynced handle's", function()
			local returned = fileNamed(
				"fixture/api_synced.lua",
				[[
				local Spring = Spring
				return { order = function() return Spring.CreateUnit() end, mouse = function() return Spring.GetMouseState() end }
			]]
			)(outer)
			assert.has_no.errors(returned.order)
			assert.error_matches(
				returned.mouse,
				"modules/fixture/api_synced.lua calls Spring.GetMouseState, which the engine offers in the unsynced handle only; this file runs in the synced handle",
				1,
				true
			)
		end)

		it("api_unsynced.lua the reverse", function()
			local returned = fileNamed(
				"fixture/api_unsynced.lua",
				[[
				local Spring = Spring
				return { order = function() return Spring.CreateUnit() end, mouse = function() return Spring.GetMouseState() end }
			]]
			)(outer)
			assert.has_no.errors(returned.mouse)
			assert.error_matches(
				returned.order,
				"modules/fixture/api_unsynced.lua calls Spring.CreateUnit, which the engine offers in the synced handle only; this file runs in the unsynced handle",
				1,
				true
			)
		end)
	end)

	it(
		"a file required from inside a module file reads the engine through the handle's environment, not the requiring file's",
		function()
			local sources = {
				["modules/fixture/api.lua"] = [[ return { load = function() local other = require("modules/fixture/lib/other"); return other end } ]],
				["modules/fixture/lib/other.lua"] = [[ return Game.mapSizeX ]],
			}
			-- what init.lua's shim does: the requiring file's env is the outer
			outer.require = function(path)
				return ModuleEnv.Include(path .. ".lua", getfenv(2))
			end
			local returned = serving(sources, function()
				return ModuleEnv.Include("modules/fixture/api.lua", outer)
			end)
			-- api.lua is sealed by now; other.lua still loads over the handle's environment
			assert.are.equal(4096, serving(sources, returned.load))
		end
	)

	describe("across the stack", function()
		-- A module file imports at the top every engine global it mentions, so its functions never reach for one after
		-- load. Checked on the text with comments and strings stripped: an engine name used as a bare word must have a
		-- `local <name>` declaration in the file. (Writes to globals are the environment's to refuse, at run time.)
		local ENGINE = {}
		for _, name in ipairs({
			"Spring",
			"VFS",
			"Script",
			"Game",
			"GG",
			"WG",
			"SYNCED",
			"UnitDefs",
			"UnitDefNames",
			"WeaponDefs",
			"WeaponDefNames",
			"FeatureDefs",
			"FeatureDefNames",
			"CMD",
			"CMDTYPE",
			"COB",
			"gl",
			"GL",
			"Engine",
			"Platform",
			"Json",
			"i18n",
			"tracy",
			"RmlUi",
			"BAR",
			"LOG",
			"SendToUnsynced",
			"loadstring",
			"os",
			"io",
			"include",
		}) do
			ENGINE[name] = true
		end
		-- units/, tests/ and scripts/ are a module's, but not module files: the defs loader, the test runner and the
		-- unit script framework run them in environments of their own
		local SKIP = {
			spec = true,
			gadgets = true,
			widgets = true,
			rml_widgets = true,
			scripts = true,
			units = true,
			tests = true,
			types = true,
		}

		---@param dir string
		---@return string[]
		local function moduleFiles(dir)
			local files = {}
			local handle = io.popen("find " .. dir .. " -name '*.lua' | sort") --[[@as any]]
			for path in handle:lines() do
				local skipped = false
				for part in path:gmatch("[^/]+") do
					skipped = skipped or SKIP[part] == true
				end
				if not skipped then
					files[#files + 1] = path
				end
			end
			handle:close()
			return files
		end

		---@param text string
		---@return string code the text without comments and string literals
		local function codeOnly(text)
			text = text:gsub("%-%-%[(=*)%[.-%]%1%]", " ")
			text = text:gsub("%-%-[^\n]*", " ")
			text = text:gsub("%[(=*)%[.-%]%1%]", '""')
			text = text:gsub('"[^"\n]*"', '""')
			text = text:gsub("'[^'\n]*'", "''")
			return text
		end

		---@param path string
		---@return string[] offences
		local function offences(path)
			local file = assert(io.open(path, "r"))
			local code = codeOnly(file:read("*a"))
			file:close()
			local declared = {}
			for name in code:gmatch("local%s+([%w_]+)%s*=") do
				declared[name] = true
			end
			for list in code:gmatch("local%s+([%w_][%w_,%s]*)=") do
				for name in list:gmatch("[%w_]+") do
					declared[name] = true
				end
			end
			local found = {}
			local mentioned = {}
			for at, name in code:gmatch("()([%a_][%w_]*)") do
				local before = at > 1 and code:sub(at - 1, at - 1) or ""
				local bare = not before:find("[%w_%.:]")
				if bare and ENGINE[name] and not declared[name] and not mentioned[name] then
					mentioned[name] = true
					found[#found + 1] = path
						.. " uses "
						.. name
						.. " without importing it: local "
						.. name
						.. " = "
						.. name
				end
			end
			return found
		end

		it("every module file imports at the top what it uses", function()
			ModuleHandler.ResetCaches()
			local all = {}
			for _, manifest in pairs(ModuleHandler.Register()) do
				for _, path in ipairs(moduleFiles(manifest.dir)) do
					for _, offence in ipairs(offences(path)) do
						all[#all + 1] = offence
					end
				end
			end
			table.sort(all)
			assert.are.same({}, all)
		end)
	end)

	---@param path string
	---@return string|nil
	local function read(path)
		local file = io.open(path, "r")
		if file == nil then
			return nil
		end
		local text = file:read("*a")
		file:close()
		return text
	end

	---@param dir string
	---@return string[]
	local function luaFilesUnder(dir)
		local files = {}
		local handle = io.popen(
			"find "
				.. dir
				.. " -name '*.lua' -not -path '*/spec/*' -not -path '*/units/*' -not -path '*/tests/*' | sort"
		) --[[@as any]]
		for line in handle:lines() do
			files[#files + 1] = line
		end
		handle:close()
		return files
	end

	---@param text string
	---@return string[] paths every module file the text requires or includes
	local function requiredModules(text)
		local paths = {}
		for path in text:gmatch('require%("(modules/[^"]+)"%)') do
			paths[#paths + 1] = path .. ".lua"
		end
		for path in text:gmatch('VFS%.Include%("(modules/[^"]+%.lua)"') do
			paths[#paths + 1] = path
		end
		return paths
	end

	describe("the handle a module file runs in", function()
		it("is read off the path", function()
			assert.is_nil(handleOf("modules/regions/api.lua"))
			assert.is_nil(handleOf("modules/regions/policies/check.lua"))
			assert.is_nil(handleOf("modules/transfer/unit/shared.lua"))
			assert.are.equal("synced", handleOf("modules/transport/api_synced.lua"))
			assert.are.equal("synced", handleOf("modules/transfer/unit/synced.lua"))
			assert.are.equal("both", handleOf("modules/transfer/gadgets/cmd_take.lua"))
			assert.are.equal("unsynced", handleOf("modules/transfer/api_unsynced.lua"))
			assert.are.equal("unsynced", handleOf("modules/transfer/unit/unsynced.lua"))
			assert.are.equal("unsynced", handleOf("modules/transfer/widgets/cmd_take.lua"))
			assert.are.equal("unsynced", handleOf("modules/game/rml_widgets/x/x.lua"))
			assert.is_nil(handleOf("luaui/Widgets/gui_pip.lua"), "not a module file")
		end)

		describe("across the stack", function()
			local files = {} ---@type { path: string, handle: LuaHandle|nil, text: string }[]

			setup(function()
				ModuleHandler.ResetCaches()
				for _, manifest in pairs(ModuleHandler.Register()) do
					for _, path in ipairs(luaFilesUnder(manifest.dir)) do
						files[#files + 1] = { path = path, handle = handleOf(path), text = assert(read(path)) }
					end
				end
				assert.is_true(#files > 0)
			end)

			it("code that runs in any handle requires nothing bound to one", function()
				local crossings = {}
				for _, file in ipairs(files) do
					if file.handle == nil then
						for _, required in ipairs(requiredModules(file.text)) do
							if handleOf(required) ~= nil then
								crossings[#crossings + 1] = file.path .. " requires " .. required
							end
						end
					end
				end
				assert.are.same({}, crossings)
			end)

			it("code bound to a handle requires nothing bound to the other", function()
				local crossings = {}
				for _, file in ipairs(files) do
					if file.handle == "synced" or file.handle == "unsynced" then
						for _, required in ipairs(requiredModules(file.text)) do
							local handle = handleOf(required)
							if handle ~= nil and handle ~= "both" and handle ~= file.handle then
								crossings[#crossings + 1] = file.path .. " requires " .. required
							end
						end
					end
				end
				assert.are.same({}, crossings)
			end)

			it("code that runs in any handle calls nothing the engine offers in one only", function()
				local syncedOnly, unsyncedOnly = engineSides()
				if syncedOnly == nil or unsyncedOnly == nil then
					pending("the recoil-lua-library listings are not checked out here", function() end)
					return
				end
				local calls = {}
				for _, file in ipairs(files) do
					if file.handle == nil then
						for name in file.text:gmatch("Spring%.([%w_]+)") do
							if syncedOnly[name] or unsyncedOnly[name] then
								calls[#calls + 1] = file.path .. " calls Spring." .. name
							end
						end
					end
				end
				assert.are.same({}, calls)
			end)

			it("code bound to a handle calls nothing the engine offers only in the other", function()
				local syncedOnly, unsyncedOnly = engineSides()
				if syncedOnly == nil or unsyncedOnly == nil then
					pending("the recoil-lua-library listings are not checked out here", function() end)
					return
				end
				local calls = {}
				for _, file in ipairs(files) do
					local forbidden = file.handle == "synced" and unsyncedOnly
						or file.handle == "unsynced" and syncedOnly
						or nil
					if forbidden then
						for name in file.text:gmatch("Spring%.([%w_]+)") do
							if forbidden[name] then
								calls[#calls + 1] = file.path .. " calls Spring." .. name
							end
						end
					end
				end
				assert.are.same({}, calls)
			end)
		end)
	end)
end)
