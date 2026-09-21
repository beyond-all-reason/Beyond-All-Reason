-- Store for user keybind profiles, persisted to LuaUI/Config/keybind_profiles.json.
--
-- Profiles are whole snapshots, never deltas: keyreload clears the keymap before it loads.
-- Migration is the exception, and reads the subset of the bind-file grammar that changes what
-- ends up bound. Everything after it goes through Spring.GetKeyBindings.

local Json = Json or VFS.Include("common/luaUtilities/json.lua")
local keybindConfig = VFS.Include("luaui/Include/keybind_config.lua")
local keybindModel = VFS.Include("luaui/Include/keybind_model.lua")

local PROFILES_PATH = "LuaUI/Config/keybind_profiles.json"
local DEFAULTS_PATH = "common/configs/keybind_defaults.json"
local RETIRED_INCLUDES_PATH = "common/configs/keybind_retired_includes.json"
local ACTIVE_FILE = "uikeys.txt"
local BACKUP_SUFFIX = ".bak"
local STORE_VERSION = 2
-- A profile name is an id inside the keymaps too, so a rename or delete has to follow it there.
local SWITCH_COMMAND = "keybindprofile"

-- Shipped profiles carry binds rather than a file path, so every surface reads one shape.
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

-- Only for upgrades: the preset a player was on is recorded as a bind-file path.
local presetFiles = {
	["luaui/configs/hotkeys/grid_keys.txt"] = "Grid",
	["luaui/configs/hotkeys/grid_keys_60pct.txt"] = "Grid (60% Keyboard)",
	["luaui/configs/hotkeys/legacy_keys.txt"] = "Legacy",
	["luaui/configs/hotkeys/legacy_keys_60pct.txt"] = "Legacy (60% Keyboard)",
}

---@type table
local store

-- Set while reading a store written before profiles named a meta key.
local storePredatesMeta = false
-- Set when another surface may have written the store since this one read it.
local stale = false

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

-- The action a key is bound to in order to switch to this profile.
function M.switchAction(name)
	return SWITCH_COMMAND .. " " .. name
end

-- Hands back the list and whether anything moved, so a caller can leave an untouched profile be.
function M.retargetSwitchBinds(binds, oldName, newName)
	local from = M.switchAction(oldName)
	local out, moved = {}, false
	for _, bind in ipairs(binds or {}) do
		if bind.action ~= from then
			out[#out + 1] = bind
		else
			moved = true
			if newName then
				out[#out + 1] = { keyset = bind.keyset, action = M.switchAction(newName) }
			end
		end
	end

	return out, moved
end

local function retargetStore(oldName, newName)
	for _, p in ipairs(store.profiles) do
		local binds, moved = M.retargetSwitchBinds(p.binds, oldName, newName)
		if moved then
			p.binds = binds
		end
	end
end

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

-- Two actions on one key are tried in bind order, so file order settles which one wins.
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

-- The engine drops everything from "//", so this costs nothing on load.
local GENERATED_PREFIX = "// keybind editor profile: "
local GENERATED_PATTERN = "^" .. (GENERATED_PREFIX:gsub("(%W)", "%%%1")) .. "([^\r\n]*)"

local function generatedName(text)
	if not text then
		return nil
	end

	local name = text:match(GENERATED_PATTERN)

	return (name ~= nil and name ~= "") and name or nil
end

-- Loading a keymap leaves the meta key alone, so a file naming none runs under the engine own.
local ENGINE_FAKE_META = "space"

-- A meta key the engine will take, nil for anything else. It accepts "none", which clears the
-- key, and refuses scancodes outright.
local function validFakeMeta(value)
	if type(value) ~= "string" or value == "" or value:find("%s") then
		return nil
	end

	if value == "none" or (Spring.GetKeyCode(value) or 0) > 0 then
		return value
	end

	return nil
end

-- Naming nothing asks for the engine key; "none" asks for no meta key at all.
local function resolveFakeMeta(value)
	return validFakeMeta(value) or ENGINE_FAKE_META
end

-- Shipped profiles never reach the store, so this is the only place their meta key is checked.
for _, b in ipairs(builtins) do
	b.fakeMeta = resolveFakeMeta(b.fakeMeta)
end

-- A whole keymap: keyreload clears the bindings before it loads, but not the meta key.
local function toBindFile(profile)
	local out = { GENERATED_PREFIX .. tostring(profile.name) }
	out[#out + 1] = "fakemeta " .. resolveFakeMeta(profile.fakeMeta)
	-- The store is writable by the player and by other surfaces, so a malformed entry reaches here.
	local binds, dropped = {}, 0
	for _, b in ipairs(profile.binds or {}) do
		if
			type(b) == "table"
			and type(b.keyset) == "string"
			and type(b.action) == "string"
			and b.keyset ~= ""
			and b.action ~= ""
		then
			binds[#binds + 1] = b
		else
			dropped = dropped + 1
		end
	end
	if dropped > 0 then
		Spring.Echo(
			"[keybind_profiles] skipped " .. dropped .. " malformed binding(s) in profile " .. tostring(profile.name)
		)
	end

	for _, b in ipairs(byPriority(binds)) do
		out[#out + 1] = "bind " .. b.keyset .. " " .. b.action
	end

	return table.concat(out, "\n") .. "\n"
end

-- Only for upgrades: what a bind file we stopped shipping used to bind, for a keyload that
-- still names it. Read on the first one that needs it rather than at include time, since
-- nothing but a migration gets here.
---@type table
local retiredIncludes
local function retiredBinds(path)
	local preset = presetFiles[path]
	local profile = preset and M.isBuiltin(preset)
	if profile then
		return profile.binds
	end

	if not retiredIncludes then
		retiredIncludes = keybindConfig.load(RETIRED_INCLUDES_PATH) or {}
	end

	return retiredIncludes[path]
end

-- The engine lowercases an action's command word, so a file naming it in any other case
-- still targets the same action.
local function commandOf(action)
	return (action:match("^%S+") or ""):lower()
end

local function actionKey(action)
	local command, args = action:match("^(%S+)(.*)$")

	return command and (command:lower() .. args) or action
end

-- The engine cannot parse a comma chain as an unbind target, so a directive naming one hits
-- nothing.
local function unbindTarget(keyset)
	if keyset:find(",", 1, true) then
		return nil
	end

	return keybindModel.canonicalKeyset(keyset)
end

-- A chain is stored under its last tap, which is the keyset an unbind has to name.
local function chainEnd(keyset)
	local taps = keybindModel.splitChain(keyset)

	return keybindModel.canonicalKeyset(taps[#taps] or keyset)
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

	-- A file may name a key the engine has none for, and every keyset after that point uses the
	-- name. The engine refuses to redefine one, so there is a single definition per name.
	local keySyms = {}
	local function resolveKeySyms(keyset)
		if not next(keySyms) then
			return keyset
		end

		local out = {}
		for element in (keyset .. ","):gmatch("([^,]*),") do
			local mods, key = element:match("^(.-)([^+]+)$")
			local named = key and keySyms[key:lower()]
			out[#out + 1] = named and (mods .. named) or element
		end

		return table.concat(out, ",")
	end

	-- Applied to what the file has bound so far rather than issued as commands. Matched on the
	-- command word, never its args.
	local function drop(match)
		for i = #binds, 1, -1 do
			if match(binds[i]) then
				table.remove(binds, i)
			end
		end
	end

	for line in text:gmatch(breaks) do
		-- Everything from "//" is a comment to the engine.
		line = line:gsub("//.*", ""):gsub("%s+$", "")
		local keyset, action = line:match("^%s*bind%s+(%S+)%s+(.-)%s*$")
		if keyset and action ~= "" then
			binds[#binds + 1] = { keyset = resolveKeySyms(keyset), action = action }
		elseif line:match("^%s*unbindall%s*$") then
			binds = {}
		elseif line:match("^%s*unbindaction%s+%S") then
			local command = line:match("^%s*unbindaction%s+(%S+)"):lower()
			drop(function(b)
				return commandOf(b.action) == command
			end)
		elseif line:match("^%s*unbindkeyset%s+%S") then
			local target = unbindTarget(line:match("^%s*unbindkeyset%s+(%S+)"))
			if target then
				drop(function(b)
					return chainEnd(b.keyset) == target
				end)
			end
		elseif line:match("^%s*unbind%s+%S") then
			local target, command = line:match("^%s*unbind%s+(%S+)%s+(%S+)")
			target = target and unbindTarget(target)
			if target then
				command = command:lower()
				drop(function(b)
					return chainEnd(b.keyset) == target and commandOf(b.action) == command
				end)
			end
		elseif line:match("^%s*keysym%s+%S+%s+%S") then
			local name, code = line:match("^%s*keysym%s+(%S+)%s+(%S+)")
			if not keySyms[name:lower()] then
				keySyms[name:lower()] = code
			end
		else
			-- Depth-capped rather than cycle-tracked.
			local included = line:match("^%s*keyload%s+(%S+)")
			if included and depth < 8 then
				local text = VFS.LoadFile(included)
				if text then
					for _, b in ipairs(readBindFile(text, depth + 1) or {}) do
						binds[#binds + 1] = b
					end
				else
					-- These stopped being files, so a keyload naming one has nothing to read.
					local retired = retiredBinds(included)
					if retired then
						for _, b in ipairs(retired) do
							binds[#binds + 1] = { keyset = b.keyset, action = b.action }
						end
					else
						Spring.Echo(
							"[keybind_profiles] Error: keyload could not read "
								.. included
								.. "; any bindings it held are missing from the migrated profile"
						)
					end
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
	-- Horizontal whitespace only: %s would match the line break and swallow the next line as the
	-- value. Leading newline so the directive is still found on line one.
	local value = ("\n" .. text):match("\n[ \t]*fakemeta[ \t]*([^\n]*)")
	if not value then
		return nil
	end

	value = value:gsub("//.*", ""):gsub("%s+$", "")

	return value ~= "" and value or nil
end

local function fakeMetaOf(text)
	return resolveFakeMeta(readFakeMeta(text))
end

-- Both sides of a comparison go through the reader, so comments, line endings and any later
-- change to how we emit cannot read as an edit the player made.
local function keymapOf(text)
	local binds = readBindFile(text)
	if not binds then
		return nil
	end

	local parts = {}
	for i = 1, #binds do
		parts[i] = binds[i].keyset .. " " .. binds[i].action
	end

	return table.concat(parts, "\n"), fakeMetaOf(text)
end

-- Taken over the bindings rather than the bytes, so changing how we emit does not make every
-- player file read as edited. djb2 with the length alongside it.
local function stampOf(text)
	local binds, meta = keymapOf(text)
	if not binds then
		return nil
	end

	local subject = binds .. "\n" .. tostring(meta)
	local h = 5381
	for i = 1, #subject do
		h = (h * 33 + subject:byte(i)) % 4294967296
	end

	return #subject .. ":" .. string.format("%08x", h)
end

-- The one migration just made of the player own file counts, which keeps the launch they
-- arrive on from forking a second copy.
local function matchesKnownProfile(text)
	local theirBinds, theirMeta = keymapOf(text)
	if not theirBinds then
		return nil
	end

	-- Before profiles named a meta key every file we wrote said "fakemeta none", so one differing
	-- only there is still ours.
	local function holds(profile)
		local ourBinds, ourMeta = keymapOf(toBindFile(profile))
		if ourBinds ~= theirBinds then
			return false
		end

		return ourMeta == theirMeta or (storePredatesMeta and theirMeta == "none")
	end

	-- Runs on every game load, so try the profile the file names before scanning them all.
	local claimed = generatedName(text)
	local i = claimed and indexOf(claimed)
	local stamped = (i and store.profiles[i]) or (claimed and M.isBuiltin(claimed))
	if stamped and holds(stamped) then
		return stamped.name
	end

	for _, p in ipairs(store.profiles) do
		if holds(p) then
			return p.name
		end
	end
	for _, b in ipairs(builtins) do
		if holds(b) then
			return b.name
		end
	end

	return nil
end

local function freeName(base, taken)
	if not taken(base) then
		return base
	end

	local n = 2
	while taken(base .. " " .. n) do
		n = n + 1
	end

	return base .. " " .. n
end

-- A name no existing profile holds, for copies.
function M.uniqueName(base)
	M.load()

	return freeName(base, function(name)
		return indexOf(name) or M.isBuiltin(name)
	end)
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

-- VFS.FileExists searches the game archives too, and a copy can only go in the write dir.
local function fileExists(path)
	local file = io.open(path, "r")
	if not file then
		return false
	end

	file:close()

	return true
end

-- The first copy is the keymap the player had before any of this existed.
local function backupFile(path, text)
	text = text or VFS.LoadFile(path)
	if not text then
		return nil
	end

	local target = path .. BACKUP_SUFFIX
	local n, last = 1, nil
	while fileExists(target) do
		last = target
		n = n + 1
		target = path .. BACKUP_SUFFIX .. "." .. n
	end

	-- A caller failing the same way every time asks for the same copy every time.
	if last and VFS.LoadFile(last) == text then
		return last
	end

	local file = io.open(target, "w")
	if not file then
		Spring.Echo("[keybind_profiles] Error: could not write " .. target .. "; continuing without a copy of " .. path)

		return nil
	end

	file:write(text)
	file:close()
	Spring.Echo("[keybind_profiles] kept a copy of " .. path .. " as " .. target)

	return target
end

-- Players upgrading from the old preset picker keep what they had, so dropping the
-- preset list does not silently reset anyone.
local function migrate()
	backupFile(ACTIVE_FILE)
	store = emptyStore()

	-- Every preset still ships, so a player on one only needs it selected.
	local configured = Spring.GetConfigString("KeybindingFile", "")
	local preset = presetFiles[configured]

	-- Whichever file actually held their bindings: the one they pointed the engine at when that is
	-- not a preset we still ship, otherwise uikeys.txt.
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
			store.profiles[1] = { name = name, binds = own, fakeMeta = fakeMetaOf(ownText) }
			store.active = preset or name
		else
			store.active = preset
		end
	end

	if not M.save() then
		Spring.Echo(
			"[keybind_profiles] Error: could not write " .. PROFILES_PATH .. "; this will migrate again next launch"
		)
	end

	-- A keyload naming a retired preset resolves here and to nothing engine-side, so hand it the
	-- store rather than the file the store came from.
	local active = M.getActive()
	local file = active and M.materialize(active)
	if file then
		Spring.SetConfigString("KeybindingFile", file)
	end
end

-- Each VFS.Include of this module gets a store of its own, so a surface that made no change
-- has no way of knowing another one did.
function M.invalidate()
	stale = true
end

-- Reads the store once, migrating an older layout on the way in.
function M.load()
	if store and not stale then
		return store
	end
	stale = false

	local content = VFS.LoadFile(PROFILES_PATH)
	if not content then
		-- Migration is for a player who never had a store, not one whose file went missing mid-session:
		-- re-running it would snapshot the live keymap as a new profile on every reload.
		if store then
			return store
		end

		migrate()
		return store
	end

	-- Json.decode raises on malformed input, so a corrupt file must not take LuaUI down.
	local ok, decoded = pcall(Json.decode, content)
	if not ok or type(decoded) ~= "table" or type(decoded.profiles) ~= "table" then
		Spring.Echo("[keybind_profiles] could not decode " .. PROFILES_PATH .. "; starting empty")
		backupFile(PROFILES_PATH, content)
		store = emptyStore()
		return store
	end

	store = decoded
	storePredatesMeta = (tonumber(store.version) or 1) < 2
	store.version = STORE_VERSION
	-- A hand-edited file can repeat a name; keep the first so lookups stay unambiguous.
	local seen, kept, changed = {}, {}, false
	for _, p in ipairs(store.profiles) do
		if type(p) == "table" and type(p.name) == "string" and not seen[p.name] then
			p.binds = type(p.binds) == "table" and p.binds or {}
			-- A shipped profile is not the store to define.
			if M.isBuiltin(p.name) then
				local taken = p.name
				local renamed = freeName(taken, function(name)
					return seen[name] or M.isBuiltin(name)
				end)
				Spring.Echo(
					"[keybind_profiles] "
						.. PROFILES_PATH
						.. " names a profile "
						.. taken
						.. ", which ships with the game; kept as "
						.. renamed
				)
				p.binds = M.retargetSwitchBinds(p.binds, taken, renamed)
				p.name = renamed
				-- Otherwise the name goes back to what ships and the player lands on stock bindings.
				if store.active == taken then
					store.active = renamed
				end
				seen[taken] = true
				changed = true
			end
			seen[p.name] = true
			-- Said here rather than on the way out, where the emitter runs once per profile per
			-- comparison and would repeat it all session.
			if p.fakeMeta and not validFakeMeta(p.fakeMeta) then
				Spring.Echo(
					"[keybind_profiles] profile "
						.. p.name
						.. " names meta key "
						.. tostring(p.fakeMeta)
						.. ", which the engine has none of; falling back to "
						.. ENGINE_FAKE_META
				)
			end
			p.fakeMeta = resolveFakeMeta(p.fakeMeta)
			-- Only a name that still ships means anything, so a profile without a usable one is given the
			-- closest and that is written back.
			if not M.baseIsUsable(p.basedOn, store.profiles) then
				p.basedOn = M.inferBase(p)
				changed = changed or p.basedOn ~= nil
			end
			kept[#kept + 1] = p
		end
	end
	store.profiles = kept
	if changed or storePredatesMeta then
		M.save()
	end

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

-- Whichever file the engine is pointed at: a hand-set KeybindingFile is the same player doing
-- the same thing somewhere else.
function M.adoptEditedKeymap()
	M.load()

	local configured = Spring.GetConfigString("KeybindingFile", ACTIVE_FILE)
	local text = VFS.LoadFile(configured ~= "" and configured or ACTIVE_FILE)
	if not text then
		return nil
	end

	-- Ours, and untouched since we wrote it, so the store is the authority on what should load.
	if store.written and store.written.stamp == stampOf(text) then
		local name = M.activeName()
		if name then
			M.materialize(name)
		end

		return nil
	end

	-- Matching the whole keymap is the older, weaker test - it cannot tell a profile that changed
	-- from a file that did - but it still says this is nobody edit.
	local matched = matchesKnownProfile(text)
	if matched then
		M.materialize(matched)

		return nil
	end

	local binds = readBindFile(text)
	if not binds or #binds == 0 then
		return nil
	end

	local previous = store.active
	local name = nextCopyName(M.activeName() or "Custom")
	store.profiles[#store.profiles + 1] = { name = name, binds = binds, fakeMeta = fakeMetaOf(text) }
	store.active = name
	if not M.save() then
		table.remove(store.profiles)
		store.active = previous
		Spring.Echo(
			"[keybind_profiles] Error: could not write "
				.. PROFILES_PATH
				.. "; the edited "
				.. ACTIVE_FILE
				.. " was left alone rather than kept as a profile"
		)

		return nil
	end

	return name
end

local function keysetsByAction(binds)
	local out = {}
	for _, b in ipairs(binds or {}) do
		local key = actionKey(b.action)
		local set = out[key]
		if not set then
			set = {}
			out[key] = set
		end
		set[keybindModel.canonicalKeyset(b.keyset)] = true
	end

	return out
end

local function sameKeysets(ours, theirs)
	if not theirs then
		return false
	end

	for keyset in pairs(ours) do
		if not theirs[keyset] then
			return false
		end
	end
	for keyset in pairs(theirs) do
		if not ours[keyset] then
			return false
		end
	end

	return true
end

-- The shipped profile a player's profile is closest to, standing in for an origin it never
-- recorded: a fork of Grid differs from Grid on a handful of actions and from Legacy on a
-- hundred.
function M.inferBase(profile)
	local ownSets = keysetsByAction(profile.binds)

	local best, bestDiff
	for _, builtin in ipairs(builtins) do
		local theirSets = keysetsByAction(builtin.binds)

		local diff = 0
		for action, set in pairs(ownSets) do
			if not sameKeysets(set, theirSets[action]) then
				diff = diff + 1
			end
		end
		for action in pairs(theirSets) do
			if not ownSets[action] then
				diff = diff + 1
			end
		end

		if not bestDiff or diff < bestDiff then
			best, bestDiff = builtin, diff
		end
	end

	return best and best.name or nil
end

-- The one value of `basedOn` that is not a profile name: the player chose to compare with none.
local NO_BASE = "none"

-- A later entry in the list given counts, so a profile may name one declared after it.
function M.baseIsUsable(basedOn, profiles)
	if type(basedOn) ~= "string" then
		return false
	end
	if basedOn == NO_BASE or M.isBuiltin(basedOn) then
		return true
	end
	for _, p in ipairs(profiles or {}) do
		if type(p) == "table" and p.name == basedOn then
			return true
		end
	end

	return false
end

-- What an editor compares against to say which keys the player changed.
function M.baseOf(name)
	local builtin = M.isBuiltin(name)
	if builtin then
		return builtin
	end

	local own = M.get(name)
	if not own or type(own.basedOn) ~= "string" or own.basedOn == NO_BASE or own.basedOn == name then
		return nil
	end

	return M.isBuiltin(own.basedOn) or M.get(own.basedOn) or nil
end

-- False when either name is unknown.
function M.setBase(name, baseName)
	M.load()
	local i = indexOf(name)
	if not i then
		return false
	end
	if baseName ~= nil and (baseName == name or not (M.isBuiltin(baseName) or indexOf(baseName))) then
		return false
	end
	store.profiles[i].basedOn = baseName or NO_BASE

	return M.save()
end

-- Without selecting it: whether it becomes the live one depends on the keymap reaching disk.
function M.create(name, binds, fakeMeta, basedOn)
	M.load()
	name = M.uniqueName(name)
	local profile = { name = name, binds = binds, fakeMeta = resolveFakeMeta(fakeMeta) }
	profile.basedOn = (basedOn and (M.isBuiltin(basedOn) or indexOf(basedOn))) and basedOn or M.inferBase(profile)
	store.profiles[#store.profiles + 1] = profile
	if not M.save() then
		Spring.Echo(
			"[keybind_profiles] Error: could not write "
				.. PROFILES_PATH
				.. "; profile "
				.. name
				.. " will be gone next launch"
		)
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
	-- Whatever was compared with it follows the name.
	for _, p in ipairs(store.profiles) do
		if p.basedOn == oldName then
			p.basedOn = newName
		end
	end
	retargetStore(oldName, newName)
	if not M.save() then
		Spring.Echo(
			"[keybind_profiles] Error: could not write "
				.. PROFILES_PATH
				.. "; the rename to "
				.. newName
				.. " will be gone next launch"
		)
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
	-- A profile compared with the one gone falls back to the closest shipped one, as a
	-- profile with no recorded origin does.
	for _, p in ipairs(store.profiles) do
		if p.basedOn == name then
			p.basedOn = M.inferBase(p)
		end
	end
	retargetStore(name, nil)

	return M.save()
end

-- A profile as text a player can paste anywhere: the same bind-file form the engine loads,
-- headed by the profile's name, so what is shared is what would be applied.
function M.exportText(profile)
	return toBindFile(profile)
end

-- Every line of bind-file text with what the reader makes of it, for showing a player what an
-- import will take before it does.
function M.classifyBindFile(text)
	local lines, binds, errors = {}, 0, 0
	if type(text) ~= "string" then
		return lines, binds, errors
	end

	for raw in (text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("([^\n]*)\n") do
		local line = raw:gsub("//.*", ""):gsub("%s+$", "")
		local kind
		if line:match("^%s*$") then
			kind = "comment"
		elseif line:match("^%s*bind%s+%S+%s+%S") then
			kind = "bind"
			binds = binds + 1
		elseif
			line:match("^%s*unbindall%s*$")
			or line:match("^%s*unbindaction%s+%S")
			or line:match("^%s*unbindkeyset%s+%S")
			or line:match("^%s*unbind%s+%S+%s+%S")
			or line:match("^%s*keysym%s+%S+%s+%S")
			or line:match("^%s*keyload%s+%S")
			or line:match("^%s*fakemeta")
		then
			kind = "directive"
		else
			kind = "error"
			errors = errors + 1
		end
		lines[#lines + 1] = { text = raw, kind = kind }
	end

	-- The split above leaves one empty line after a trailing newline, which is no line.
	if #lines > 0 and lines[#lines].text == "" then
		lines[#lines] = nil
	end

	return lines, binds, errors
end

-- The reverse: bind-file text, however it was produced, as binds plus the fakemeta key and
-- the profile name our own output is stamped with. nil binds when the text holds none.
function M.parseBindFile(text)
	if type(text) ~= "string" or text == "" then
		return nil
	end

	local binds = readBindFile(text)
	if not binds or #binds == 0 then
		return nil
	end

	return binds, fakeMetaOf(text), generatedName(text)
end

-- Write a profile out where the engine can keyreload it, and return that path.
function M.materialize(name)
	M.load()

	local profile = M.isBuiltin(name) or M.get(name)
	if not profile then
		return nil
	end

	local file = io.open(ACTIVE_FILE, "w")
	if not file then
		Spring.Echo("[keybind_profiles] could not open " .. ACTIVE_FILE .. " for writing")
		return nil
	end

	local text = toBindFile(profile)
	file:write(text)
	file:close()

	-- What the keymap held the last time it was ours. A file still holding this has not been
	-- edited since, so the profile behind it can be rewritten over the top; one that does not
	-- is the player's own work and is kept.
	store.written = { name = name, stamp = stampOf(text) }
	M.save()

	return ACTIVE_FILE
end

return M
