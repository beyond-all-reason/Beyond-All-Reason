-- Read model for the in-game keybind editor.
-- Source of truth is Spring.GetKeyBindings(); we normalize each binding, group
-- by action, and build a keyset->actions index used for conflict detection.

local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- Synonymous key names that should read the same however they were bound
-- (e.g. the file keysym "enter" vs the scancode-based "return" from capture).
local keyNameAlias = { enter = "return" }

local function displayKeyset(raw, layout)
	local mods, key = raw:match("^(.-)([^+]*)$")
	if key and keyNameAlias[key:lower()] then
		raw = mods .. keyNameAlias[key:lower()]
	end

	return keyConfig.sanitizeKey(raw, layout):gsub("%+", " + ")
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
}
