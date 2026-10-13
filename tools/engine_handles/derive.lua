-- Which Spring functions the engine offers in one Lua handle only, read off the recoil-lua-library's generated
-- listings: one file per engine source file, so LuaSyncedCtrl.cpp.lua lists what the synced handle gets and
-- LuaUnsyncedCtrl.cpp.lua / LuaUnsyncedRead.cpp.lua what the unsynced one gets. A function listed under one of
-- those and under nothing else is that handle's alone. This is the derivation behind modules/engine_handles.lua
-- (tools/engine_handles/generate.lua writes it) and spec/modules/module_env_spec.lua checks the stack against it, and
-- behind types/SpringHandles.lua, the engine as a type per handle, which the same generator writes.
--
-- Plain Lua over io; it runs outside the game.
local ENGINE_DIR = "recoil-lua-library/library/generated/rts/Lua/"
local SYNCED_FILES = { "LuaSyncedCtrl.cpp.lua", "LuaSyncedMoveCtrl.cpp.lua" }
local UNSYNCED_FILES = { "LuaUnsyncedCtrl.cpp.lua", "LuaUnsyncedRead.cpp.lua" }
-- Listed under one handle in the library, offered on both by the engine.
local ON_BOTH = { SendMessageToPlayer = true, SendLuaUIMsg = true }

---@class EngineHandlesDerive
local Derive = {}

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

---@param files string[]
---@return table<string, boolean>|nil names nil when a listing is not checked out
local function functionsIn(files)
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

---@return string[]
local function listingFiles()
	local files = {}
	local handle = io.popen("ls " .. ENGINE_DIR .. " 2>/dev/null") --[[@as any]]
	for file in handle:lines() do
		files[#files + 1] = file
	end
	handle:close()
	return files
end

---@param set table<string, boolean>
---@return string[] sorted
function Derive.Sorted(set)
	local names = {}
	for name in pairs(set) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- The functions the engine offers in one handle only.
---@return table<string, boolean>|nil syncedOnly nil when the listings are not checked out
---@return table<string, boolean>|nil unsyncedOnly
function Derive.Sides()
	local synced, unsynced = functionsIn(SYNCED_FILES), functionsIn(UNSYNCED_FILES)
	if synced == nil or unsynced == nil then
		return nil, nil
	end
	local isHandleFile = {}
	for _, file in ipairs(SYNCED_FILES) do
		isHandleFile[file] = true
	end
	for _, file in ipairs(UNSYNCED_FILES) do
		isHandleFile[file] = true
	end
	local elsewhere = {}
	for _, file in ipairs(listingFiles()) do
		if not isHandleFile[file] then
			for name in pairs(functionsIn({ file }) or {}) do
				elsewhere[name] = true
			end
		end
	end
	local syncedOnly, unsyncedOnly = {}, {}
	for name in pairs(synced) do
		syncedOnly[name] = not unsynced[name] and not elsewhere[name] and not ON_BOTH[name] or nil
	end
	for name in pairs(unsynced) do
		unsyncedOnly[name] = not synced[name] and not elsewhere[name] and not ON_BOTH[name] or nil
	end
	return syncedOnly, unsyncedOnly
end

-- types/SpringHandles.lua: the engine as a type per Lua handle. SpringBoth is what a file that runs in any handle may
-- hold: every function both handles offer, copied from the listings with its annotations so the signatures are the
-- library's, and every one-handle function typed as a marker that cannot be called. SpringSynced and SpringUnsynced
-- extend it with their own handle's functions, so a synced file holds a SpringSynced and the checker refuses an
-- unsynced-only call where modules/module_env.lua refuses it at run time. Nothing here is named Spring: the library
-- declares that global as a plain table, and a class by that name resolves unreliably beside it.
---@class EngineHandlesFunction
---@field name string
---@field args string the parameter list as the listing writes it
---@field annotations string[] the listing's ---@ lines for it

-- Every Spring function in the listings, with its annotations, by name; the first listing wins a duplicate.
---@return table<string, EngineHandlesFunction>|nil nil when the listings are not checked out
local function functionsWithAnnotations()
	local byName = {}
	local files = listingFiles()
	if #files == 0 then
		return nil
	end
	table.sort(files)
	for _, file in ipairs(files) do
		local text = read(ENGINE_DIR .. file)
		if text == nil then
			return nil
		end
		local annotations = {}
		for line in (text .. "\n"):gmatch("([^\n]*)\n") do
			line = line:gsub("\r$", "")
			local name, args = line:match("^function Spring%.([%w_]+)%((.*)%) end$")
			if name then
				if byName[name] == nil then
					byName[name] = { name = name, args = args, annotations = annotations }
				end
				annotations = {}
			elseif line:sub(1, 4) == "---@" then
				annotations[#annotations + 1] = line
			elseif line:sub(1, 3) ~= "---" then
				annotations = {}
			end
		end
	end
	return byName
end

---@param lines string[]
---@param class string
---@param functions table<string, EngineHandlesFunction>
---@param included fun(name: string): boolean which functions this class carries as statements
local function renderFunctions(lines, class, functions, included)
	for _, name in ipairs(Derive.Sorted(functions)) do
		if included(name) then
			local fn = functions[name]
			for _, annotation in ipairs(fn.annotations) do
				lines[#lines + 1] = annotation
			end
			lines[#lines + 1] = "function " .. class .. "." .. name .. "(" .. fn.args .. ") end"
			lines[#lines + 1] = ""
		end
	end
end

---@param syncedOnly table<string, boolean>
---@param unsyncedOnly table<string, boolean>
---@return string|nil the file's text; nil when the listings are not checked out
function Derive.RenderTypes(syncedOnly, unsyncedOnly)
	local functions = functionsWithAnnotations()
	if functions == nil then
		return nil
	end
	local lines = {
		"---@meta SpringHandles",
		"-- GENERATED by tools/engine_handles/generate.lua from recoil-lua-library/library/generated/rts/Lua/; do not edit.",
		"-- The engine as a type per Lua handle. SpringBoth is what a file that runs in any handle may hold: every function",
		"-- both handles offer, with the library's own signature, and nothing else. SpringSynced and SpringUnsynced extend it",
		"-- with their own handle's functions, and type the other handle's as a marker that cannot be called, so the checker",
		"-- refuses an unsynced-only call in a synced file where modules/module_env.lua refuses it at run time.",
		"",
		"---@class SpringSyncedOnly a function the engine offers in the synced handle alone; not callable from the unsynced one",
		"---@class SpringUnsyncedOnly a function the engine offers in the unsynced handle alone; not callable from the synced one",
		"",
		"---@class SpringBoth the engine as a file that runs in any handle holds it: what both handles offer, and nothing else",
	}
	lines[#lines + 1] = "SpringBoth = {}"
	lines[#lines + 1] = ""
	renderFunctions(lines, "SpringBoth", functions, function(name)
		return not syncedOnly[name] and not unsyncedOnly[name]
	end)
	lines[#lines + 1] = "---@class SpringSynced : SpringBoth the engine in the synced handle"
	for _, name in ipairs(Derive.Sorted(unsyncedOnly)) do
		lines[#lines + 1] = "---@field " .. name .. " SpringUnsyncedOnly"
	end
	lines[#lines + 1] = "SpringSynced = {}"
	lines[#lines + 1] = ""
	renderFunctions(lines, "SpringSynced", functions, function(name)
		return syncedOnly[name] == true
	end)
	lines[#lines + 1] = "---@class SpringUnsynced : SpringBoth the engine in the unsynced handle"
	for _, name in ipairs(Derive.Sorted(syncedOnly)) do
		lines[#lines + 1] = "---@field " .. name .. " SpringSyncedOnly"
	end
	lines[#lines + 1] = "SpringUnsynced = {}"
	lines[#lines + 1] = ""
	renderFunctions(lines, "SpringUnsynced", functions, function(name)
		return unsyncedOnly[name] == true
	end)
	return table.concat(lines, "\n")
end

return Derive
