-- Guards how a widget's declared actions reach the keybind editor and the profile store.

local WidgetActions = require("luaui/Include/keybind_widget_actions")

local FOLDER = "LuaUI/Widgets/"
local KEYS = "widgets.gui_example."

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
	it("keeps every key under the widget and shapes defaults the way a profile binds them", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			{
				action = "  Subgroup_Cycle Next ",
				label = "actions.cycle",
				description = "actions.cycleDescription",
				defaultKeysets = { "tab", "sc_q" },
				icon = "cycle.png",
			},
			{
				action = "toggle",
				label = "actions.toggle",
				alwaysModifier = "any",
				defaultKeysets = { "tab", "Any+sc_q", "*+x" },
			},
			{ action = "pair", label = "actions.pair", alwaysModifier = "shift", defaultKeysets = { "Shift+tab" } },
		}))

		assert.are.same({}, warnings)
		assert.are.same({
			{
				action = "subgroup_cycle Next",
				label = KEYS .. "actions.cycle",
				description = KEYS .. "actions.cycleDescription",
				icon = FOLDER .. "gui_example/cycle.png",
				keysets = { "tab", "sc_q" },
			},
			{
				action = "toggle",
				label = KEYS .. "actions.toggle",
				alwaysModifier = "any",
				keysets = { "Any+tab", "Any+sc_q", "*+x" },
			},
			{
				action = "pair",
				label = KEYS .. "actions.pair",
				alwaysModifier = "shift",
				keysets = { "tab", "Shift+tab" },
			},
		}, actions)
	end)

	it("skips an entry it cannot read, naming each", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			"not an object",
			{ label = "actions.noAction" },
			{ action = "no_label" },
			{ action = "bad_modifier", label = "actions.bad", alwaysModifier = "ctrl" },
			{ action = "load 1", label = "actions.one" },
			{ action = "LOAD 1", label = "actions.again" },
		}))

		assert.are.same({ { action = "load 1", label = KEYS .. "actions.one" } }, actions)
		assert.are.same({ 1, 2, 3, 4, 6 }, entriesNamed(warnings))

		local notList, notListWarnings = WidgetActions.parse(widgetEntry("gui_example", "subgroup_cycle"))
		assert.are.same({}, notList)
		assert.are.equal(1, #notListWarnings)
	end)

	it("drops a default it cannot make but keeps the action", function()
		local actions, warnings = WidgetActions.parse(widgetEntry("gui_example", {
			{ action = "one", label = "a.one", defaultKeysets = "tab" },
			{ action = "two", label = "a.two", alwaysModifier = "shift", defaultKeysets = { "tab", "sc_q" } },
			{ action = "three", label = "a.three", defaultKeysets = { "not a keyset" } },
			{ action = "four", label = "a.four", alwaysModifier = "shift", defaultKeysets = { "Any+tab" } },
		}))

		assert.are.equal(4, #actions)
		for _, action in ipairs(actions) do
			assert.is_nil(action.keysets, action.action)
		end
		assert.are.same({ 1, 2, 3, 4 }, entriesNamed(warnings))
	end)
end)

describe("what the loaded widgets contribute", function()
	it("gives each its own category, an action two of them declare going to the first", function()
		local groups = WidgetActions.groups({
			widgetEntry("gui_first", {
				{ action = "shared", label = "actions.mine" },
				{ action = "mine", label = "actions.other", alwaysModifier = "any" },
			}),
			widgetEntry("gui_off", { { action = "hidden", label = "actions.hidden" } }, false),
			widgetEntry("gui_silent", nil),
			widgetEntry("gui_second", {
				{ action = "shared", label = "actions.theirs" },
				{ action = "own", label = "actions.own" },
			}),
		})

		assert.are.same({
			{
				category = "widgets.gui_first.displayName",
				section = "widgets",
				items = {
					{ action = "shared", label = "widgets.gui_first.actions.mine" },
					{ action = "mine", label = "widgets.gui_first.actions.other", alwaysModifier = "any" },
				},
			},
			{
				category = "widgets.gui_second.displayName",
				section = "widgets",
				items = { { action = "own", label = "widgets.gui_second.actions.own" } },
			},
		}, groups)
	end)

	it("lists their defaults action by action, the first widget's winning", function()
		local defaults = WidgetActions.defaults({
			widgetEntry("gui_first", {
				{ action = "bound", label = "a.bound", defaultKeysets = { "tab" } },
				{ action = "unbound", label = "a.unbound" },
				{ action = "paired", label = "a.paired", alwaysModifier = "shift", defaultKeysets = { "sc_q" } },
			}),
			widgetEntry("gui_off", { { action = "hidden", label = "a.hidden", defaultKeysets = { "x" } } }, false),
			widgetEntry("gui_second", {
				{ action = "bound", label = "a.bound", defaultKeysets = { "F1" } },
				{ action = "own", label = "a.own", defaultKeysets = { "Alt+sc_o" } },
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
			widgetEntry("gui_on", { { action = "shared", label = "a.shared" } }),
			widgetEntry(
				"gui_off",
				{ { action = "shared", label = "a.shared" }, { action = "off", label = "a.off" } },
				false
			),
			widgetEntry(
				"gui_also_off",
				{ { action = "off", label = "a.off" }, { action = "other", label = "a.other" } },
				false
			),
		})

		assert.are.same({ "off", "other" }, hidden)
	end)
end)

describe("the manifests of the widgets installed", function()
	it("are read once and follow the widgets running, counting only a change in which are", function()
		local manifestPath = FOLDER .. "gui_example/manifest.json"
		local reads, revision, active = 0, 1, {}
		local realWG, realHandler = rawget(_G, "WG"), rawget(_G, "widgetHandler")
		local realBAR = rawget(_G, "BAR")
		local realSubDirs, realFileExists, realLoadFile = VFS.SubDirs, VFS.FileExists, VFS.LoadFile
		VFS.SubDirs = function(folder)
			return folder == FOLDER and { FOLDER .. "gui_example/" } or {}
		end
		VFS.FileExists = function(path)
			return path == manifestPath
		end
		VFS.LoadFile = function(path)
			reads = reads + 1

			return path == manifestPath and '{ "id": "gui_example", "display_name": "Example" }' or nil
		end
		rawset(_G, "WG", {})
		rawset(_G, "BAR", { I18N = { loadWidgetLocalizations = function() end } })
		rawset(_G, "widgetHandler", {
			GetWidgetsRevision = function()
				return revision
			end,
			GetActiveWidgetFiles = function()
				return active
			end,
		})

		local function snapshot()
			local widgets, changes = WidgetActions.manifests()
			local widget = widgets[1] or error("the manifest was not discovered")

			return { widget.loaded, changes }
		end
		local ok, result = pcall(function()
			local seen = { snapshot() }
			active, revision = { FOLDER .. "gui_example/gui_example.lua" }, 2
			seen[2] = snapshot()
			revision = 3
			seen[3] = snapshot()

			return seen
		end)

		VFS.SubDirs, VFS.FileExists, VFS.LoadFile = realSubDirs, realFileExists, realLoadFile
		rawset(_G, "WG", realWG)
		rawset(_G, "widgetHandler", realHandler)
		rawset(_G, "BAR", realBAR)

		assert(ok, tostring(result))
		assert.are.same({ { false, 0 }, { true, 1 }, { true, 1 } }, result)
		assert.are.equal(1, reads)
	end)
end)
