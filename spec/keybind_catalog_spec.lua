-- Guards the shared keybind data contract (common/configs/keybind_catalog.json and
-- keybind_defaults.json) against drift. Structure is checked against the shipped
-- schemas, so CI enforces the same rules other surfaces read; the rest is referential
-- integrity a schema cannot express - names unique across both profile lists, action
-- commands in the case the engine will match.
--
-- Reads the JSON directly rather than through the Lua adapters, because the adapters
-- use VFS.LoadFile, which the test harness does not mock.

local Json = VFS.Include("common/luaUtilities/json.lua")
local JsonSchema = VFS.Include("spec/json_schema.lua")

local function loadJson(path)
	local f = assert(io.open(path, "r"), "cannot open " .. path)
	local content = f:read("*a")
	f:close()
	return Json.decode(content)
end

local function conformsTo(schemaPath, documentPath)
	local problems = JsonSchema.validate(loadJson(schemaPath), loadJson(documentPath))
	assert(
		#problems == 0,
		documentPath .. " does not match " .. schemaPath .. ":\n  " .. table.concat(problems, "\n  ")
	)
end

describe("shipped keybind profiles", function()
	local defaults = loadJson("common/configs/keybind_defaults.json")

	it("matches its schema", function()
		conformsTo("common/configs/keybind_defaults.schema.json", "common/configs/keybind_defaults.json")
	end)

	-- The picker lists these by name, and a duplicate would make one unreachable.
	it("names every profile uniquely", function()
		local seen = {}
		for _, profile in ipairs(defaults.profiles) do
			assert(not seen[profile.name], "duplicate profile name: " .. tostring(profile.name))
			seen[profile.name] = true
		end
	end)
end)

describe("keybind catalog", function()
	local catalog = loadJson("common/configs/keybind_catalog.json")

	it("matches its schema", function()
		conformsTo("common/configs/keybind_catalog.schema.json", "common/configs/keybind_catalog.json")
	end)

	-- Action::Action lowercases the command before Spring.GetKeyBindings ever sees it, so
	-- a capitalised id here silently matches nothing and the row renders with no keys.
	-- Only the command is lowered; its arguments keep their case.

	-- The editor cannot capture a bare modifier as a key, so an action bound only that way
	-- is not editable at all and is hidden rather than listed: shown, its remove chip would
	-- strip a binding the player could never put back. An action bound both ways stays
	-- listed - hiding a real key to protect a modifier would be the worse trade.
	it("hides every purely modifier-only action", function()
		local defaults = loadJson("common/configs/keybind_defaults.json")
		local modifiers = { alt = true, ctrl = true, shift = true, meta = true, any = true }
		local function isModifierOnly(keyset)
			local parts = 0
			for part in keyset:gmatch("[^+]+") do
				if not modifiers[part:lower()] then
					return false
				end
				parts = parts + 1
			end
			return parts > 0
		end

		local kinds = {}
		for _, profile in ipairs(defaults.profiles) do
			for _, bind in ipairs(profile.binds) do
				local seen = kinds[bind.action] or {}
				seen[isModifierOnly(bind.keyset)] = true
				kinds[bind.action] = seen
			end
		end

		local hidden = {}
		for _, group in ipairs(catalog) do
			for _, action in ipairs(group.hidden or {}) do
				hidden[action] = true
			end
		end

		for action, seen in pairs(kinds) do
			if seen[true] and not seen[false] then
				assert(
					hidden[action],
					"action is bound only to modifiers but is not hidden, so "
						.. "the editor would offer an edit it cannot undo: "
						.. action
				)
			end
		end

		local listed = {}
		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items or {}) do
				if item.action then
					listed[item.action] = true
				end
			end
		end
		for action in pairs(hidden) do
			assert(not listed[action], "action is both hidden and listed: " .. action)
		end
	end)
	-- The engine lower-cases a command when it parses the bind line, so anything reading the
	-- live keymap sees lower case and a capitalised id in either file matches nothing. Args
	-- are left alone: the selection language is case-sensitive.
	it("writes every action command in lower case", function()
		local function check(id, where)
			local command = id:match("^%S+") or id
			assert(command == command:lower(), where .. " command is not lower case: " .. id)
		end

		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items or {}) do
				local id = item.action or item.prefix
				if id then
					check(id, "catalog action")
				end
			end
			for _, id in ipairs(group.hidden or {}) do
				check(id, "hidden action")
			end
		end

		local defaults = loadJson("common/configs/keybind_defaults.json")
		for _, profile in ipairs(defaults.profiles) do
			for _, bind in ipairs(profile.binds) do
				check(bind.action, "profile bind")
			end
		end
	end)
end)
