-- Guards how a widget's declared actions reach the keybind editor and the profile store.

local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local WidgetActions = require("luaui/Include/keybind_widget_actions")

local FOLDER = "LuaUI/Widgets/"

local function widgetEntry(id, actions, loaded)
	return {
		id = id,
		dir = FOLDER .. id .. "/",
		manifest = { id = id, display_name = "Example " .. id, keybindings = actions },
		loaded = loaded ~= false,
	}
end

local function entriesNamed(warnings)
	local named = {}
	for i, warning in ipairs(warnings) do
		named[i] = tonumber(warning:match("keybindings%[(%d+)%]"))
	end

	return named
end

describe("reading a widget's declared actions", function()
	it("reads the command the way the engine matches it and shapes defaults the way a profile binds them", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			{ action = "  Subgroup_Cycle Next ", defaultKeysets = { "tab", "sc_q" }, icon = "cycle.png" },
			{ action = "toggle", alwaysModifier = "any", defaultKeysets = { "tab", "Any+sc_q", "*+x" } },
			{ action = "pair", alwaysModifier = "shift", defaultKeysets = { "Shift+tab" } },
		}))

		assert.are.same({}, warnings)
		assert.are.same({
			{ action = "subgroup_cycle Next", icon = FOLDER .. "gui_example/cycle.png", keysets = { "tab", "sc_q" } },
			{ action = "toggle", alwaysModifier = "any", keysets = { "Any+tab", "Any+sc_q", "*+x" } },
			{ action = "pair", alwaysModifier = "shift", keysets = { "tab", "Shift+tab" } },
		}, actions)
	end)

	it("skips an entry it cannot read, naming each", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			"not an object",
			{ defaultKeysets = { "tab" } },
			{ action = "bad_modifier", alwaysModifier = "ctrl" },
			{ action = "load 1" },
			{ action = "LOAD 1" },
		}))

		assert.are.same({ { action = "load 1" } }, actions)
		assert.are.same({ 1, 2, 3, 5 }, entriesNamed(warnings))

		local notList, notListWarnings = WidgetActions.parse(widgetEntry("gui_example", "subgroup_cycle"))
		assert.are.same({}, notList)
		assert.are.equal(1, #notListWarnings)
	end)

	it("drops a default it cannot make but keeps the action", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			{ action = "one", defaultKeysets = "tab" },
			{ action = "two", alwaysModifier = "shift", defaultKeysets = { "tab", "sc_q" } },
			{ action = "three", defaultKeysets = { "not a keyset" } },
			{ action = "four", alwaysModifier = "shift", defaultKeysets = { "Any+tab" } },
		}))

		assert.are.equal(4, #actions)
		for _, action in ipairs(actions) do
			assert.is_nil(action.keysets, action.action)
		end
		assert.are.same({ 1, 2, 3, 4 }, entriesNamed(warnings))
	end)
end)

describe("what the loaded widgets contribute", function()
	it("gives each a category titled by its display name, an action two of them declare going to the first", function()
		local groups = WidgetActions.groups({
			widgetEntry("gui_first", { { action = "shared" }, { action = "mine", alwaysModifier = "any" } }),
			widgetEntry("gui_off", { { action = "hidden" } }, false),
			widgetEntry("gui_silent", nil),
			widgetEntry("gui_second", { { action = "shared" }, { action = "own" } }),
		})

		assert.are.same({
			{
				category = "widgets.gui_first",
				title = "Example gui_first",
				section = "widgets",
				items = { { action = "shared" }, { action = "mine", alwaysModifier = "any" } },
			},
			{
				category = "widgets.gui_second",
				title = "Example gui_second",
				section = "widgets",
				items = { { action = "own" } },
			},
		}, groups)
	end)

	it("lists their defaults action by action, the first widget's winning", function()
		local defaults = WidgetActions.defaults({
			widgetEntry("gui_first", {
				{ action = "bound", defaultKeysets = { "tab" } },
				{ action = "unbound" },
				{ action = "paired", alwaysModifier = "shift", defaultKeysets = { "sc_q" } },
			}),
			widgetEntry("gui_off", { { action = "hidden", defaultKeysets = { "x" } } }, false),
			widgetEntry("gui_second", {
				{ action = "bound", defaultKeysets = { "F1" } },
				{ action = "own", defaultKeysets = { "Alt+sc_o" } },
			}),
		})

		assert.are.same({
			{ action = "bound", keysets = { "tab" } },
			{ action = "paired", keysets = { "sc_q", "Shift+sc_q" } },
			{ action = "own", keysets = { "Alt+sc_o" } },
		}, defaults)
	end)

	it("keeps the actions of widgets that are off out of sight, less any a loaded one declares", function()
		local hidden = WidgetActions.hiddenActions({
			widgetEntry("gui_on", { { action = "shared" } }),
			widgetEntry("gui_off", { { action = "shared" }, { action = "off" } }, false),
			widgetEntry("gui_also_off", { { action = "off" }, { action = "other" } }, false),
		})

		assert.are.same({ "off", "other" }, hidden)
	end)
end)

describe("the manifests of the widgets installed", function()
	it("are read once and follow the widgets running, counting only a change in which are", function()
		local manifestPath = FOLDER .. "gui_example/manifest.json"
		local reads, revision, active = 0, 1, {}
		local realFileExists = VFS.FileExists

		local env = SpecEnv.new({
			VFS = {
				SubDirs = function(folder)
					return folder == FOLDER and { FOLDER .. "gui_example/" } or {}
				end,
				-- Faked only for the widget manifest; other paths (the module code itself, included
				-- via `require`) still need to resolve to real files on disk.
				FileExists = function(path, ...)
					return path == manifestPath or realFileExists(path, ...)
				end,
				LoadFile = function(path)
					reads = reads + 1

					return path == manifestPath and '{ "id": "gui_example", "display_name": "Example" }' or nil
				end,
			},
			WG = {},
			widgetHandler = {
				GetWidgetsRevision = function()
					return revision
				end,
				GetActiveWidgetFiles = function()
					return active
				end,
			},
		})
		local widgetActions = SpecEnv.include(env, "luaui/Include/keybind_widget_actions.lua")

		local function snapshot()
			local widgets, changes = widgetActions.manifests()
			local widget = widgets[1] or error("the manifest was not discovered")

			return { widget.loaded, changes }
		end

		local seen = { snapshot() }
		active, revision = { FOLDER .. "gui_example/gui_example.lua" }, 2
		seen[2] = snapshot()
		revision = 3
		seen[3] = snapshot()

		assert.are.same({ { false, 0 }, { true, 1 }, { true, 1 } }, seen)
		assert.are.equal(1, reads)
	end)
end)
