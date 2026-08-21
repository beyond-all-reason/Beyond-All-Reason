-- Read model for the in-game keybind editor.
-- Source of truth is Spring.GetKeyBindings(); we normalize each binding and group
-- by action.

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- Synonymous key names that should read the same however they were bound
-- (e.g. the file keysym "enter" vs the scancode-based "return" from capture).
local keyNameAlias = { enter = "return" }

-- Keychain separator (U+2192) shown between taps, since the engine's "," collides with a bound comma key.
local chainSep = " \226\134\146 "

-- One engine keyset element as the player's keyboard layout would label it.
-- The Any+ qualifier is not shown: it is fixed per action rather than chosen, so there is
-- nothing on that key for a player to change. sanitizeKey is what drops it.
local function displayElement(raw, layout)
	local mods, key = raw:match("^(.-)([^+]*)$")
	if key and keyNameAlias[key:lower()] then
		raw = mods .. keyNameAlias[key:lower()]
	end

	return (keyConfig.sanitizeKey(raw, layout):gsub("%+", " + "))
end

-- Split a chain on separator commas. A comma is the bound key rather than a separator
-- when nothing has been read yet (","), straight after a modifier ("Alt+,") or after "sc_".
local function splitChain(raw)
	local elems = {}
	local cur = ""
	for i = 1, #raw do
		local c = raw:sub(i, i)
		if c == "," and cur ~= "" and cur:sub(-1) ~= "+" and cur:sub(-3) ~= "sc_" then
			if cur ~= "" then
				elems[#elems + 1] = cur
			end
			cur = ""
		else
			cur = cur .. c
		end
	end
	if cur ~= "" then
		elems[#elems + 1] = cur
	end

	return elems
end

-- Whether two keysets are the same binding, which is a different question from whether
-- they print the same. Any+ and a bare modifier set resolve differently when the engine
-- picks an action, and scancodes and keycodes are separate maps that land on different
-- physical keys off qwerty, so both distinctions survive here. Only spellings of one key
-- fold. Display is no use for this: it drops exactly the qualifiers that decide priority.
local canonicalMods = { "any", "alt", "ctrl", "meta", "shift" }
local modToken = {
	["any+"] = "any",
	["*+"] = "any",
	["alt+"] = "alt",
	["ctrl+"] = "ctrl",
	["meta+"] = "meta",
	["shift+"] = "shift",
}

local function canonicalElement(raw)
	local rest, held = raw, {}
	local stripped = true
	while stripped do
		stripped = false
		for token, name in pairs(modToken) do
			if rest:sub(1, #token):lower() == token then
				held[name] = true
				rest = rest:sub(#token + 1)
				stripped = true
			end
		end
	end

	local key = rest:lower()
	local scan = key:sub(1, 3) == "sc_"
	if scan then
		key = key:sub(4)
	end
	key = keyNameAlias[key] or key

	local out = {}
	for _, name in ipairs(canonicalMods) do
		if held[name] then
			out[#out + 1] = name
		end
	end
	out[#out + 1] = (scan and "sc:" or "kc:") .. key

	return table.concat(out, "+")
end

-- A whole keyset, joining a chain with the arrow separator.
local function displayKeyset(raw, layout)
	if not raw:find(",", 1, true) then
		return displayElement(raw, layout)
	end

	local parts = splitChain(raw)
	for i = 1, #parts do
		parts[i] = displayElement(parts[i], layout)
	end

	return table.concat(parts, chainSep)
end

local function canonicalKeyset(raw)
	local parts = splitChain(raw)
	for i = 1, #parts do
		parts[i] = canonicalElement(parts[i])
	end

	return table.concat(parts, ",")
end

-- A bound action is identified by the full command string passed to /bind:
-- command plus its space-separated args (.extra) - exactly what bind/unbind
-- expect. This includes "chain", whose .extra is the sequence; dropping it would
-- collapse every chain into one id and lose the sequence on rebind.
local function actionId(b)
	if b.extra and b.extra ~= "" then
		return b.command .. " " .. b.extra
	end

	return b.command
end

-- Snapshot of every bound action, with both raw and display forms of its keysets.
local function build()
	local layout = Spring.GetConfigString("KeyboardLayout", "qwerty")
	local bindings = Spring.GetKeyBindings() or {}

	local byAction = {}
	local order = {}
	local binds = {}

	for _, b in ipairs(bindings) do
		local id = actionId(b)
		local raw = b.boundWith
		binds[#binds + 1] = { keyset = raw, action = id }

		local entry = byAction[id]
		if not entry then
			entry = { action = id, command = b.command, keysets = {} }
			byAction[id] = entry
			order[#order + 1] = id
		end
		entry.keysets[#entry.keysets + 1] = { raw = raw, display = displayKeyset(raw, layout) }
	end

	table.sort(order)

	local actions = {}
	for i = 1, #order do
		actions[i] = byAction[order[i]]
	end

	return { actions = actions, layout = layout, binds = binds }
end

return {
	build = build,
	displayKeyset = displayKeyset,
	canonicalKeyset = canonicalKeyset,
	splitChain = splitChain,
	chainSep = chainSep,
}
