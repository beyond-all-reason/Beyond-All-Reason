-- Guards what a hub widget adds to the game's strings. VFS is faked below.

local WidgetLocalizations = require("modules/i18n/widget_localizations")

local FOLDER = "LuaUI/Widgets/"

local function widgetEntry(id, displayName)
	return { id = id, dir = FOLDER .. id .. "/", manifest = { id = id, display_name = displayName }, loaded = true }
end

local function read(widgets, files)
	local realFileExists, realLoadFile = VFS.FileExists, VFS.LoadFile

	VFS.FileExists = function(path)
		return files[path] ~= nil
	end
	VFS.LoadFile = function(path)
		return files[path]
	end

	local byId, warnings = WidgetLocalizations.Read(widgets, VFS.RAW)

	VFS.FileExists, VFS.LoadFile = realFileExists, realLoadFile

	return byId, warnings
end

local function assertOneWarningMentioning(warnings, text)
	assert.are.equal(1, #warnings)
	assert.truthy(warnings[1]:find(text, 1, true), "expected warning to mention " .. text .. ": " .. warnings[1])
end

describe("widget localizations", function()
	it("falls back to the display name, which the widget's own strings override", function()
		local byId, warnings = read({
			widgetEntry("gui_named", "Named"),
			widgetEntry("gui_example", "Example"),
			widgetEntry("gui_silent", nil),
		}, {
			[FOLDER .. "gui_example/localizations.json"] = '{ "en": { "displayName": "Better", "menu": { "open": "Open" } }, "de": { "label": "Beispiel" } }',
		})

		assert.are.same({}, warnings)
		assert.are.same({
			gui_named = { en = { displayName = "Named" } },
			gui_example = { en = { displayName = "Better", menu = { open = "Open" } }, de = { label = "Beispiel" } },
		}, byId)
	end)

	it("drops a localizations.json that is not valid JSON but keeps the display name", function()
		local byId, warnings = read({ widgetEntry("gui_example", "Example") }, {
			[FOLDER .. "gui_example/localizations.json"] = "{",
		})

		assert.are.same({ gui_example = { en = { displayName = "Example" } } }, byId)
		assertOneWarningMentioning(warnings, "localizations.json is not valid JSON")
	end)

	it("drops what i18n cannot hold, naming each", function()
		local byId, warnings = read({ widgetEntry("gui_example", nil) }, {
			[FOLDER .. "gui_example/localizations.json"] = '{ "fr": "Exemple", "en": { "title": "Example", "title.short": "Ex", "count": 3, "blank": "", "": "empty key", "list": ["a", "b"], "nested": { "ok": "Yes", "flag": true } } }',
		})

		assert.are.same({ gui_example = { en = { title = "Example", nested = { ok = "Yes" } } } }, byId)
		assert.are.equal(8, #warnings)
	end)
end)
