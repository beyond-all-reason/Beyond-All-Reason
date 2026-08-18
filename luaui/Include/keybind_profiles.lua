-- Store for user keybind profiles, persisted to LuaUI/Config/keybind_profiles.json.
--
-- Profiles are whole snapshots, never deltas: keyreload clears the keymap before it loads,
-- so a profile always defines every binding it wants. The emitter writes them in the one
-- shape the engine round-trips.
--
-- Migration is the exception: a player's own file has to be read as written, so the reader
-- below understands the subset of the bind-file grammar that changes what ends up bound -
-- bind, the three unbinds, keyload and fakemeta. Everything after migration goes through
-- Spring.GetKeyBindings instead.

local Json = Json or VFS.Include('common/luaUtilities/json.lua')
local keybindConfig = VFS.Include("luaui/Include/keybind_config.lua")

local PROFILES_PATH = "LuaUI/Config/keybind_profiles.json"
local DEFAULTS_PATH = "common/configs/keybind_defaults.json"
local ACTIVE_FILE = "uikeys.txt"
local BACKUP_FILE = "uikeys.txt.bak"
local STORE_VERSION = 1

-- The shipped profiles a player can select but not edit; editing forks a copy. They
-- carry binds rather than a file path so every surface reads one shape, and applying
-- one takes the same path as applying a player's own profile.
local builtins = {}
local emitPriority = {}
do
	local decoded = keybindConfig.load(DEFAULTS_PATH)
	if decoded and type(decoded.profiles) == "table" then
		builtins = decoded.profiles
		if type(decoded.priority) == "table" then
			emitPriority = decoded.priority
		end
	else
		Spring.Echo("[keybind_profiles] Error: " .. DEFAULTS_PATH .. " has no profiles; none shipped")
	end
end

-- Only for upgrades: the preset a player was on is recorded as a bind-file path. Maps
-- each of those paths to the profile that now covers it.
local presetFiles = {
	["luaui/configs/hotkeys/grid_keys.txt"] = "Grid",
	["luaui/configs/hotkeys/grid_keys_60pct.txt"] = "Grid (60% Keyboard)",
	["luaui/configs/hotkeys/legacy_keys.txt"] = "Legacy",
	["luaui/configs/hotkeys/legacy_keys_60pct.txt"] = "Legacy (60% Keyboard)",
}

local store

-- Shape a fresh store file takes.
local function emptyStore()
	return { version = STORE_VERSION, active = nil, profiles = {} }
end

-- Position of one of the player's own profiles, nil when the name is not theirs.
local function indexOf(name)
	for i, p in ipairs(store.profiles) do
		if p.name == name then
			return i
		end
	end

	return nil
end

local M = { builtins = builtins, activeFile = ACTIVE_FILE }

-- The shipped profile of that name, nil when the player owns it instead.
function M.isBuiltin(name)
	for _, b in ipairs(builtins) do
		if b.name == name then
			return b
		end
	end

	return nil
end

-- Where an action sits in the shipped priority list, last for anything unlisted.
local function priorityRank(action)
	for i = 1, #emitPriority do
		local prefix = emitPriority[i]
		if action:sub(1, #prefix) == prefix then
			return i
		end
	end

	return #emitPriority + 1
end

-- Two actions on one key are tried in the order they were bound, so file order is what
-- settles which one wins. Sorting by declared priority keeps that decision with the
-- action instead of with whoever edited last. Equal ranks hold their existing order, so
-- only the listed actions move.
local function byPriority(binds)
	local ordered = {}
	for i = 1, #binds do
		ordered[i] = { bind = binds[i], rank = priorityRank(binds[i].action), pos = i }
	end

	table.sort(ordered, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end

		return a.pos < b.pos
	end)

	local out = {}
	for i = 1, #ordered do
		out[i] = ordered[i].bind
	end

	return out
end

-- Stamped into every file we write so migration can tell our own output from a file the
-- player wrote, and recover which profile was live when the store holding it is gone.
-- The engine drops everything from "//" to end of line, so it costs nothing on load.
local GENERATED_PREFIX = "// keybind editor profile: "
local GENERATED_PATTERN = "^" .. (GENERATED_PREFIX:gsub("(%W)", "%%%1")) .. "([^\r\n]*)"

local function generatedName(text)
	if not text then
		return nil
	end

	local name = text:match(GENERATED_PATTERN)

	return (name ~= nil and name ~= "") and name or nil
end

-- uikeys.txt only needs the bind lines; keyreload clears and sets fakemeta itself.
local function toBindFile(profile)
	local out = { GENERATED_PREFIX .. tostring(profile.name) }
	-- One token only: anything longer emits a fakemeta directive the engine cannot parse.
	if profile.fakeMeta and profile.fakeMeta ~= "" and not profile.fakeMeta:find("%s") then
		out[#out + 1] = "fakemeta " .. profile.fakeMeta
	end
	-- The store is writable by the player and by other surfaces, so a malformed entry is
	-- reachable here. Dropping one costs a keybind; letting it through takes the whole
	-- hotkey loader down with it.
	local binds, dropped = {}, 0
	for _, b in ipairs(profile.binds or {}) do
		if type(b) == "table" and type(b.keyset) == "string" and type(b.action) == "string"
			and b.keyset ~= "" and b.action ~= "" then
			binds[#binds + 1] = b
		else
			dropped = dropped + 1
		end
	end
	if dropped > 0 then
		Spring.Echo("[keybind_profiles] skipped " .. dropped .. " malformed binding(s) in profile "
			.. tostring(profile.name))
	end

	for _, b in ipairs(byPriority(binds)) do
		out[#out + 1] = "bind " .. b.keyset .. " " .. b.action
	end

	return table.concat(out, "\n") .. "\n"
end

-- The engine has no Lua getter for the fakemeta key, so migration is the only
-- chance to carry a non-default one over from the file the player already had.
-- Reads the bind lines back out of a keybind file. Needed for the player's own
-- uikeys.txt at migration time: the live keymap is whichever preset they had selected,
-- so it cannot stand in for what their own file holds.
local function readBindFile(text, depth)
	if not text then
		return nil
	end

	depth = depth or 1
	local breaks = "[^" .. string.char(13, 10) .. "]+"
	local binds = {}

	-- Applied to what has been collected so far rather than issued as commands, so an unbind
	-- means "drop what this file has bound up to here". Matched on the command word, never
	-- its args: "unbindaction factory_preset" takes every "factory_preset load N" with it.
	local function drop(match)
		for i = #binds, 1, -1 do
			if match(binds[i]) then
				table.remove(binds, i)
			end
		end
	end

	for line in text:gmatch(breaks) do
		-- Everything from "//" is a comment to the engine, so it is gone before anything reads
		-- the line as a directive.
		line = line:gsub("//.*", ""):gsub("%s+$", "")
		local keyset, action = line:match("^%s*bind%s+(%S+)%s+(.-)%s*$")
		if keyset and action ~= "" then
			binds[#binds + 1] = { keyset = keyset, action = action }
		elseif line:match("^%s*unbindall%s*$") then
			binds = {}
		elseif line:match("^%s*unbindaction%s+%S") then
			local command = line:match("^%s*unbindaction%s+(%S+)")
			drop(function(b) return b.action:match("^%S+") == command end)
		elseif line:match("^%s*unbindkeyset%s+%S") then
			local target = line:match("^%s*unbindkeyset%s+(%S+)"):lower()
			drop(function(b) return b.keyset:lower() == target end)
		elseif line:match("^%s*unbind%s+%S") then
			local target, command = line:match("^%s*unbind%s+(%S+)%s+(%S+)")
			if target then
				target = target:lower()
				drop(function(b) return b.keyset:lower() == target and b.action:match("^%S+") == command end)
			end
		else
			-- A player's file can pull in others the same way the shipped presets did, and
			-- those bindings are just as much theirs. Depth-capped rather than cycle-tracked.
			local included = line:match("^%s*keyload%s+(%S+)")
			if included and depth < 8 then
				local text = VFS.LoadFile(included)
				if text then
					for _, b in ipairs(readBindFile(text, depth + 1) or {}) do
						binds[#binds + 1] = b
					end
				else
					Spring.Echo("[keybind_profiles] Error: keyload could not read " .. included
						.. "; any bindings it held are missing from the migrated profile")
				end
			end
		end
	end

	return binds
end

local function readFakeMeta(text)
	if not text then
		return nil
	end
	-- Horizontal whitespace only: %s would match the line break and swallow the
	-- next line as the value when fakemeta is present but unset.
	-- Leading newline so the directive is still found on the first line, which is where
	-- toBindFile puts it.
	local value = ("\n" .. text):match("\n[ \t]*fakemeta[ \t]*([^\n]*)")
	if not value then
		return nil
	end

	value = value:gsub("//.*", ""):gsub("%s+$", "")

	return value ~= "" and value or nil
end

-- What a bind file binds, as one comparable string. Both sides of a comparison go through
-- the reader, so comments, line endings and any later change to how we emit cannot read as
-- an edit the player made.
local function keymapOf(text)
	local binds = readBindFile(text)
	if not binds then
		return nil
	end

	local parts = {}
	for i = 1, #binds do
		parts[i] = binds[i].keyset .. " " .. binds[i].action
	end

	return table.concat(parts, "\n") .. "\nfakemeta " .. tostring(readFakeMeta(text))
end

-- Whether some profile already holds this keymap. The one migration just made of the
-- player's own file counts, which is what keeps the launch they arrive on from forking a
-- second copy of what it has only now imported.
local function matchesKnownProfile(text)
	local theirs = keymapOf(text)
	if not theirs then
		return false
	end

	-- Nearly always our own output for the profile it names, and this runs on every game
	-- load, so try that one before reading out every profile there is. Keeps the usual path
	-- off the full scan however many the player has accumulated.
	local claimed = generatedName(text)
	local i = claimed and indexOf(claimed)
	local stamped = (i and store.profiles[i]) or (claimed and M.isBuiltin(claimed))
	if stamped and keymapOf(toBindFile(stamped)) == theirs then
		return true
	end

	for _, p in ipairs(store.profiles) do
		if keymapOf(toBindFile(p)) == theirs then
			return true
		end
	end
	for _, b in ipairs(builtins) do
		if keymapOf(toBindFile(b)) == theirs then
			return true
		end
	end

	return false
end

-- A name no existing profile holds, for copies.
function M.uniqueName(base)
	M.load()
	if not indexOf(base) and not M.isBuiltin(base) then
		return base
	end

	local n = 2
	while indexOf(base .. " " .. n) or M.isBuiltin(base .. " " .. n) do
		n = n + 1
	end

	return base .. " " .. n
end

-- The next free "<name> (n)". A name already carrying one counts up from it, anything else
-- starts at 2. Kept distinct from uniqueName's suffix so a copy the player never asked for
-- reads as one rather than as another profile they made.
local function nextCopyName(name)
	local stem, n = name:match("^(.-) %((%d+)%)$")
	n = tonumber(n) or 1
	stem = stem or name

	repeat
		n = n + 1
	until not indexOf(stem .. " (" .. n .. ")") and not M.isBuiltin(stem .. " (" .. n .. ")")

	return stem .. " (" .. n .. ")"
end

-- Writes the store back to disk.
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

-- Players upgrading from the old preset picker keep what they had, so dropping the
-- preset list does not silently reset anyone.
-- The player's file as it was before any of this touched it. Written once and never again,
-- including on a later migration, so the copy is always the original rather than our own
-- output. Nothing reads it back: it exists for a human with a broken keymap.
local function backupActiveFile()
	local existing = io.open(BACKUP_FILE, "r")
	if existing then
		existing:close()

		return
	end

	local text = VFS.LoadFile(ACTIVE_FILE)
	if not text then
		return
	end

	local file = io.open(BACKUP_FILE, "w")
	if not file then
		Spring.Echo("[keybind_profiles] Error: could not write " .. BACKUP_FILE
			.. "; continuing without a copy of the original keymap")

		return
	end

	file:write(text)
	file:close()
	Spring.Echo("[keybind_profiles] kept the original " .. ACTIVE_FILE .. " as " .. BACKUP_FILE)
end

local function migrate()
	backupActiveFile()
	store = emptyStore()

	-- Every preset still ships, so a player on one only needs it selected; there is nothing
	-- of theirs to carry across.
	local configured = Spring.GetConfigString("KeybindingFile", "")
	local preset = presetFiles[configured]

	-- Whichever file actually held their bindings: the one they pointed the engine at when
	-- that is not a preset we still ship, otherwise the uikeys.txt a preset leaves unloaded.
	-- The player's own file is a profile in its own right, whatever else they had going on.
	local ownPath = (not preset and configured ~= "") and configured or ACTIVE_FILE
	local ownText = VFS.LoadFile(ownPath)
	local written = generatedName(ownText)

	if written and M.isBuiltin(written) then
		-- Our own copy of a shipped profile. Select it rather than importing a duplicate.
		store.active = written
	else
		local own = readBindFile(ownText)
		if own and #own > 0 then
			local name = written or "Custom"
			store.profiles[1] = { name = name, binds = own, fakeMeta = readFakeMeta(ownText) }
			store.active = preset or name
		else
			store.active = preset
		end
	end

	M.save()
end

-- Reads the store once, migrating an older layout on the way in.
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
			if type(p.fakeMeta) ~= "string" or p.fakeMeta == "" or p.fakeMeta:find("%s") then
				p.fakeMeta = nil
			end
			kept[#kept + 1] = p
		end
	end
	store.profiles = kept

	return store
end

-- Names of the player's own profiles, in store order.
function M.list()
	M.load()
	local names = {}
	for _, p in ipairs(store.profiles) do
		names[#names + 1] = p.name
	end

	return names
end

-- One of the player's own profiles by name.
function M.get(name)
	M.load()
	local i = indexOf(name)

	return i and store.profiles[i] or nil
end

-- The selected profile, shipped or the player's own.
function M.getActive()
	M.load()

	return store.active
end

-- The selection, or the first shipped profile when it is missing or stale.
function M.activeName()
	local active = M.getActive()
	if active and (M.get(active) or M.isBuiltin(active)) then
		return active
	end

	return builtins[1] and builtins[1].name or nil
end

-- Records the selection; the store owns this, not the engine config.
function M.setActive(name)
	M.load()
	store.active = name

	return M.save()
end

-- A keymap the player edited themselves, kept as a profile instead of overwritten the next
-- time one is applied. Whichever file the engine is pointed at, since a hand-set
-- KeybindingFile is the same player doing the same thing somewhere else.
function M.adoptEditedKeymap()
	M.load()

	local configured = Spring.GetConfigString("KeybindingFile", ACTIVE_FILE)
	local text = VFS.LoadFile(configured ~= "" and configured or ACTIVE_FILE)
	if not text then
		return nil
	end

	if matchesKnownProfile(text) then
		return nil
	end

	local binds = readBindFile(text)
	if not binds or #binds == 0 then
		return nil
	end

	local previous = store.active
	local name = nextCopyName(M.activeName() or "Custom")
	store.profiles[#store.profiles + 1] = { name = name, binds = binds, fakeMeta = readFakeMeta(text) }
	store.active = name
	if not M.save() then
		table.remove(store.profiles)
		store.active = previous
		Spring.Echo("[keybind_profiles] Error: could not write " .. PROFILES_PATH
			.. "; the edited " .. ACTIVE_FILE .. " was left alone rather than kept as a profile")

		return nil
	end

	return name
end

-- Adds a profile of the player's own, without selecting it: whether it becomes the live one
-- depends on the keymap reaching disk, which only the caller finds out. Selecting it up front
-- would leave the picker naming a profile the engine never loaded when that write fails.
function M.create(name, binds, fakeMeta)
	M.load()
	name = M.uniqueName(name)
	store.profiles[#store.profiles + 1] = { name = name, binds = binds, fakeMeta = fakeMeta }
	if not M.save() then
		Spring.Echo("[keybind_profiles] Error: could not write " .. PROFILES_PATH
			.. "; profile " .. name .. " will be gone next launch")
	end

	return name
end

-- Renames one of the player's own, following the selection if it moves.
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
	if not M.save() then
		Spring.Echo("[keybind_profiles] Error: could not write " .. PROFILES_PATH
			.. "; the rename to " .. newName .. " will be gone next launch")
	end

	return newName
end

-- Removes one of the player's own.
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

return M
