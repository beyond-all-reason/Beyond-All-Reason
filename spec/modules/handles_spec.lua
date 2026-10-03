local ModuleHandler = require("modules/module_handler")

-- Which Lua handle a module file runs in, as modules/module_handler.lua states it above LAYOUT: api.lua and the rest
-- run in any, api_synced.lua with any synced.lua behind it in the synced handle, api_unsynced.lua with
-- widgets/, rml_widgets/ and any unsynced.lua in the unsynced one; a gadget runs in both, and says itself which half
-- is which. This holds every module to that. The engine's own split comes from the recoil-lua-library's generated
-- listings, one file per handle.
local ENGINE_DIR = "recoil-lua-library/library/generated/rts/Lua/"
local SYNCED_HANDLES = { "LuaSyncedCtrl.cpp.lua", "LuaSyncedMoveCtrl.cpp.lua" }
local UNSYNCED_HANDLES = { "LuaUnsyncedCtrl.cpp.lua", "LuaUnsyncedRead.cpp.lua" }
-- Listed under one handle in the library, offered on both by the engine.
local ON_BOTH = { SendMessageToPlayer = true, SendLuaUIMsg = true }

---@alias LuaHandle "synced"|"unsynced"|"both" both: a gadget, with a half for each

---@param path string a file path under modules/
---@return LuaHandle|nil handle nil for code that runs in any
local function handleOf(path)
	local rest = path:match("^modules/[^/]+/(.*)$")
	if rest == nil then
		return nil
	end
	local base = rest:match("([^/]+)$")
	if rest:find("^gadgets/") then
		return "both"
	end
	if base == "api_synced.lua" or base == "synced.lua" then
		return "synced"
	end
	if base == "api_unsynced.lua" or base == "unsynced.lua" or rest:find("^widgets/") or rest:find("^rml_widgets/") then
		return "unsynced"
	end
	return nil
end

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
	local handle = io.popen("find " .. dir .. " -name '*.lua' -not -path '*/spec/*' | sort") --[[@as any]]
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

---@param files string[]
---@return table<string, boolean>|nil names nil when a listing is not checked out
local function engineFunctions(files)
	local names = {}
	for _, file in ipairs(files) do
		local text = read(ENGINE_DIR .. file)
		if text == nil then
			return nil
		end
		for name in text:gmatch("\nfunction Spring%.([%w_]+)") do
			names[name] = true
		end
	end
	return names
end

-- The functions the engine offers in one handle only: listed under that handle's files and under nothing else.
---@return table<string, boolean>|nil syncedOnly
---@return table<string, boolean>|nil unsyncedOnly
local function engineSides()
	local synced, unsynced = engineFunctions(SYNCED_HANDLES), engineFunctions(UNSYNCED_HANDLES)
	if synced == nil or unsynced == nil then
		return nil, nil
	end
	local elsewhere = {}
	local handle = io.popen("ls " .. ENGINE_DIR .. " 2>/dev/null") --[[@as any]]
	for file in handle:lines() do
		local isSide = false
		for _, named in ipairs(SYNCED_HANDLES) do
			isSide = isSide or named == file
		end
		for _, named in ipairs(UNSYNCED_HANDLES) do
			isSide = isSide or named == file
		end
		if not isSide then
			for name in pairs(engineFunctions({ file }) or {}) do
				elsewhere[name] = true
			end
		end
	end
	handle:close()
	local syncedOnly, unsyncedOnly = {}, {}
	for name in pairs(synced) do
		syncedOnly[name] = not unsynced[name] and not elsewhere[name] and not ON_BOTH[name] or nil
	end
	for name in pairs(unsynced) do
		unsyncedOnly[name] = not synced[name] and not elsewhere[name] and not ON_BOTH[name] or nil
	end
	return syncedOnly, unsyncedOnly
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
