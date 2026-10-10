-- Which Spring functions the engine offers in one Lua handle only, read off the recoil-lua-library's generated
-- listings: one file per engine source file, so LuaSyncedCtrl.cpp.lua lists what the synced handle gets and
-- LuaUnsyncedCtrl.cpp.lua / LuaUnsyncedRead.cpp.lua what the unsynced one gets. A function listed under one of
-- those and under nothing else is that handle's alone. This is the derivation behind modules/engine_handles.lua
-- (tools/engine_handles/generate.lua writes it) and spec/modules/module_env_spec.lua checks the stack against it.
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

return Derive
