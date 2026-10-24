-- Which Spring functions and which globals the engine offers in one Lua handle only, read off the engine's library
-- per handle under types/recoil/generated/: synced.lua holds what the synced handle registers alone, unsynced.lua
-- what the unsynced handle does, shared.lua what both do. Those files are RecoilEngine PR #2799's rts/Lua/handles
-- output, vendored byte for byte (types/recoil/README.md says how). This derivation is behind
-- modules/engine_handles.lua (tools/engine_handles/generate.lua writes it), which modules/module_env.lua enforces at
-- run time and spec/modules/module_env_spec.lua checks the stack against.
--
-- Plain Lua over io; it runs outside the game.
local TYPES_DIR = "types/recoil/generated/"

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

---@param file string the handle's file
---@param pattern string with one capture, the name
---@return table<string, boolean>|nil names nil when the file is not there
local function namesOf(file, pattern)
	local text = read(TYPES_DIR .. file)
	if text == nil then
		return nil
	end
	local names = {}
	for name in text:gmatch(pattern) do
		names[name] = true
	end
	return names
end

-- Each handle's file declares its functions on `local Spring`, the handle's class.
local FUNCTION = "\nfunction Spring%.([%w_]+)"
-- Its tables and enums are assigned at the top level; `local Spring = {}` starts with `local` and does not match.
local GLOBAL = "\n([%a_][%w_]*) = "

-- The names in `these` that are not in `those`.
---@param these table<string, boolean>
---@param those table<string, boolean>
---@return table<string, boolean>
local function only(these, those)
	local names = {}
	for name in pairs(these) do
		if not those[name] then
			names[name] = true
		end
	end
	return names
end

---@param set table<string, any>
---@return string[] sorted
function Derive.Sorted(set)
	local names = {}
	for name in pairs(set) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- The functions the engine offers in one handle alone. A function both handles offer is in shared.lua, or, when
-- each handle documents its own (the GiveOrder family), in both handle files; either way it is in neither list.
---@return table<string, boolean>|nil syncedOnly
---@return table<string, boolean>|nil unsyncedOnly
function Derive.Sides()
	local synced = namesOf("synced.lua", FUNCTION)
	local unsynced = namesOf("unsynced.lua", FUNCTION)
	if synced == nil or unsynced == nil then
		return nil, nil
	end
	return only(synced, unsynced), only(unsynced, synced)
end

-- The globals (constants tables, enums, the gl surface) the engine registers in one handle alone.
---@return table<string, boolean>|nil syncedOnly
---@return table<string, boolean>|nil unsyncedOnly
function Derive.Globals()
	local synced = namesOf("synced.lua", GLOBAL)
	local unsynced = namesOf("unsynced.lua", GLOBAL)
	if synced == nil or unsynced == nil then
		return nil, nil
	end
	return only(synced, unsynced), only(unsynced, synced)
end

return Derive
