-- Read model for the in-game keybind editor.
-- Source of truth is Spring.GetKeyBindings(); we normalize each binding, group
-- by action, and build a keyset->actions index used for conflict detection.

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- Synonymous key names that should read the same however they were bound
-- (e.g. the file keysym "enter" vs the scancode-based "return" from capture).
local keyNameAlias = { enter = "return" }

-- Keychain separator (U+2192) shown between taps, since the engine's "," collides with a bound comma key.
local chainSep = " \226\134\146 "

local function displayElement(raw, layout)
	-- Pull the Any+ qualifier out before sanitizeKey (which drops it) so it stays
	-- visible and Any+X reads differently from a plain X.
	local anyPrefix = ""
	raw = raw:gsub("[Aa][Nn][Yy]%+", function() anyPrefix = "Any + "; return "" end)
	raw = raw:gsub("%*%+", function() anyPrefix = "Any + "; return "" end)

	local mods, key = raw:match("^(.-)([^+]*)$")
	if key and keyNameAlias[key:lower()] then
		raw = mods .. keyNameAlias[key:lower()]
	end

	return anyPrefix .. keyConfig.sanitizeKey(raw, layout):gsub("%+", " + ")
end

-- Split a chain on separator commas; a comma doesn't split mid-token after "sc_" (the comma key).
local function splitChain(raw)
	local elems = {}
	local cur = ""
	for i = 1, #raw do
		local c = raw:sub(i, i)
		if c == "," and cur:sub(-3) ~= "sc_" then
			if cur ~= "" then elems[#elems + 1] = cur end
			cur = ""
		else
			cur = cur .. c
		end
	end
	if cur ~= "" then elems[#elems + 1] = cur end

	return elems
end

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

local function build()
	local layout = Spring.GetConfigString("KeyboardLayout", "qwerty")
	local bindings = Spring.GetKeyBindings() or {}

	local byAction = {}
	local order = {}

	for _, b in ipairs(bindings) do
		local id = actionId(b)
		local raw = b.boundWith

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

	return { actions = actions, layout = layout }
end

return {
	build = build,
	displayKeyset = displayKeyset,
	splitChain = splitChain,
	chainSep = chainSep,
}
