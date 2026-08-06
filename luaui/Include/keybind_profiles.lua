-- Store for user keybind profiles, persisted to LuaUI/Config/keybind_profiles.json.
--
-- Profiles are whole snapshots, never deltas: keyreload clears the keymap before it
-- loads, so a profile always defines every binding it wants. Snapshots come from
-- Spring.GetKeyBindings rather than from parsing uikeys.txt, so nothing here has to
-- understand the bind-file grammar; only the emitter writes it, and only in the one
-- shape the engine round-trips.

local PROFILES_PATH = "LuaUI/Config/keybind_profiles.json"
local DEFAULTS_PATH = "common/configs/keybind_defaults.json"
local ACTIVE_FILE = "uikeys.txt"
local STORE_VERSION = 1

-- The shipped profiles a player can select but not edit; editing forks a copy. They
-- carry binds rather than a file path so every surface reads one shape, and applying
-- one takes the same path as applying a player's own profile.
local builtins = {}
do
	local ok, decoded = pcall(Json.decode, VFS.LoadFile(DEFAULTS_PATH))
	if ok and type(decoded) == "table" and type(decoded.profiles) == "table" then
		builtins = decoded.profiles
	else
		Spring.Echo("[keybind_profiles] could not load " .. DEFAULTS_PATH .. "; no built-in profiles")
	end
end

-- Only for upgrades: the preset a player was on is recorded as a bind-file path.
local legacyPresetNames = {
	["luaui/configs/hotkeys/grid_keys.txt"] = "Grid",
	["luaui/configs/hotkeys/grid_keys_60pct.txt"] = "Grid (60% Keyboard)",
}

local store

local function emptyStore()
	return { version = STORE_VERSION, active = nil, profiles = {} }
end

local function indexOf(name)
	for i, p in ipairs(store.profiles) do
		if p.name == name then
			return i
		end
	end

	return nil
end

local M = { builtins = builtins, activeFile = ACTIVE_FILE }

function M.isBuiltin(name)
	for _, b in ipairs(builtins) do
		if b.name == name then
			return b
		end
	end

	return nil
end

-- Every binding currently live, in the order the engine reports them.
function M.snapshotLive()
	local binds = {}
	for _, b in ipairs(Spring.GetKeyBindings() or {}) do
		local action = b.command
		if b.extra and b.extra ~= "" then
			action = action .. " " .. b.extra
		end
		binds[#binds + 1] = { keyset = b.boundWith, action = action }
	end

	return binds
end

-- uikeys.txt only needs the bind lines; keyreload clears and sets fakemeta itself.
local function toBindFile(profile)
	local out = {}
	if profile.fakeMeta then
		out[#out + 1] = "fakemeta " .. profile.fakeMeta
	end
	for _, b in ipairs(profile.binds or {}) do
		out[#out + 1] = "bind " .. b.keyset .. " " .. b.action
	end

	return table.concat(out, "\n") .. "\n"
end

-- The engine has no Lua getter for the fakemeta key, so migration is the only
-- chance to carry a non-default one over from the file the player already had.
local function readFakeMeta(text)
	if not text then
		return nil
	end
	local value = text:match("\n%s*fakemeta%s*([^\n]*)")
	if not value then
		return nil
	end

	return (value:gsub("//.*", ""):gsub("%s+$", ""))
end

function M.uniqueName(base)
	if not indexOf(base) and not M.isBuiltin(base) then
		return base
	end

	local n = 2
	while indexOf(base .. " " .. n) or M.isBuiltin(base .. " " .. n) do
		n = n + 1
	end

	return base .. " " .. n
end

function M.save()
	local file = io.open(PROFILES_PATH, "w")
	if not file then
		Spring.Echo("[keybind_profiles] could not open " .. PROFILES_PATH .. " for writing")
		return false
	end

	local encoded = Json.encode(store)
	if not encoded then
		file:close()
		Spring.Echo("[keybind_profiles] could not encode " .. PROFILES_PATH)
		return false
	end

	file:write(encoded)
	file:close()

	return true
end

-- Players upgrading from the old preset picker keep what they had: whatever is live
-- becomes a profile, so removing Legacy does not silently reset anyone.
local function migrate()
	store = emptyStore()

	-- Already on a preset that survives the change; it stays selectable as a builtin.
	local survivor = legacyPresetNames[Spring.GetConfigString("KeybindingFile", "")]
	if survivor then
		store.active = survivor
		M.save()
		return
	end

	local binds = M.snapshotLive()
	if #binds == 0 then
		return
	end

	store.profiles[1] = {
		name = "Custom",
		binds = binds,
		fakeMeta = readFakeMeta(VFS.LoadFile(ACTIVE_FILE)),
	}
	store.active = "Custom"
	M.save()
end

function M.load()
	if store then
		return store
	end

	local content = VFS.LoadFile(PROFILES_PATH)
	if not content then
		migrate()
		return store
	end

	-- Json.decode raises on malformed input, so a corrupt file must not take LuaUI down.
	local ok, decoded = pcall(Json.decode, content)
	if not ok or type(decoded) ~= "table" or type(decoded.profiles) ~= "table" then
		Spring.Echo("[keybind_profiles] could not decode " .. PROFILES_PATH .. "; starting empty")
		store = emptyStore()
		return store
	end

	store = decoded
	store.version = store.version or STORE_VERSION
	-- A hand-edited file can repeat a name; keep the first so lookups stay unambiguous.
	local seen, kept = {}, {}
	for _, p in ipairs(store.profiles) do
		if type(p) == "table" and type(p.name) == "string" and not seen[p.name] then
			seen[p.name] = true
			p.binds = type(p.binds) == "table" and p.binds or {}
			kept[#kept + 1] = p
		end
	end
	store.profiles = kept

	return store
end

function M.list()
	M.load()
	local names = {}
	for _, p in ipairs(store.profiles) do
		names[#names + 1] = p.name
	end

	return names
end

function M.get(name)
	M.load()
	local i = indexOf(name)

	return i and store.profiles[i] or nil
end

function M.getActive()
	M.load()

	return store.active
end

function M.setActive(name)
	M.load()
	store.active = name

	return M.save()
end

function M.create(name, binds, fakeMeta)
	M.load()
	name = M.uniqueName(name)
	store.profiles[#store.profiles + 1] = { name = name, binds = binds or M.snapshotLive(), fakeMeta = fakeMeta }
	store.active = name
	M.save()

	return name
end

function M.rename(oldName, newName)
	M.load()
	local i = indexOf(oldName)
	if not i or newName == oldName then
		return oldName
	end

	newName = M.uniqueName(newName)
	store.profiles[i].name = newName
	if store.active == oldName then
		store.active = newName
	end
	M.save()

	return newName
end

function M.copy(name, newName)
	local src = M.get(name)
	if not src then
		return nil
	end

	local binds = {}
	for i, b in ipairs(src.binds) do
		binds[i] = { keyset = b.keyset, action = b.action }
	end

	return M.create(newName or (name .. " copy"), binds, src.fakeMeta)
end

function M.delete(name)
	M.load()
	local i = indexOf(name)
	if not i then
		return false
	end

	table.remove(store.profiles, i)
	if store.active == name then
		store.active = store.profiles[1] and store.profiles[1].name or nil
	end

	return M.save()
end

-- Write a profile out where the engine can keyreload it, and return that path.
function M.materialize(name)
	local profile = M.get(name) or M.isBuiltin(name)
	if not profile then
		return nil
	end

	local file = io.open(ACTIVE_FILE, "w")
	if not file then
		Spring.Echo("[keybind_profiles] could not open " .. ACTIVE_FILE .. " for writing")
		return nil
	end

	file:write(toBindFile(profile))
	file:close()

	return ACTIVE_FILE
end

M.toBindFile = toBindFile

return M
