-- Guards which widget directories the game reads a manifest from. VFS is faked below.

local WidgetManifests = require("modules/widgets/manifests")

local FOLDER = "LuaUI/Widgets/"
local RML_FOLDER = "LuaUI/RmlWidgets/"

local function manifest(id)
	return string.format('{ "id": %s, "display_name": "Example", "author": "someone" }', id)
end

local function dirsOf(files, folder)
	local dirs = {}
	local seen = {}

	for path in pairs(files) do
		local dir = path:match("^(.*/)[^/]+$")
		if dir and dir ~= folder and dir:sub(1, #folder) == folder and not seen[dir] then
			seen[dir] = true
			dirs[#dirs + 1] = dir
		end
	end

	return dirs
end

local function discover(files, folders, dirsByFolder)
	local realSubDirs, realFileExists, realLoadFile = VFS.SubDirs, VFS.FileExists, VFS.LoadFile

	VFS.SubDirs = function(folder)
		return dirsByFolder and dirsByFolder[folder] or dirsOf(files, folder)
	end
	VFS.FileExists = function(path)
		return files[path] ~= nil
	end
	VFS.LoadFile = function(path)
		return files[path]
	end

	local widgets, warnings = WidgetManifests.Discover(folders or FOLDER, VFS.RAW)

	VFS.SubDirs, VFS.FileExists, VFS.LoadFile = realSubDirs, realFileExists, realLoadFile

	return widgets, warnings
end

local function ids(widgets)
	local out = {}
	for i, widget in ipairs(widgets) do
		out[i] = widget.id
	end

	return out
end

local function assertOneWarningMentioning(warnings, text)
	assert.are.equal(1, #warnings)
	assert.truthy(warnings[1]:find(text, 1, true), "expected warning to mention " .. text .. ": " .. warnings[1])
end

describe("widget manifests", function()
	it("reads the id and directory of every manifest, in directory order, and nothing else", function()
		local widgets, warnings = discover({
			[FOLDER .. "unit_second/manifest.json"] = manifest('"unit_second"'),
			[FOLDER .. "gui_first/manifest.json"] = "\239\187\191" .. manifest('"gui_first"'),
			[FOLDER .. "gui_plain/gui_plain.lua"] = "",
			[FOLDER .. "plain_widget.lua"] = "",
		})

		assert.are.same({}, warnings)
		assert.are.same({ "gui_first", "unit_second" }, ids(widgets))
		assert.are.equal(FOLDER .. "gui_first/", widgets[1].dir)
		assert.are.equal("Example", widgets[1].manifest.display_name)
		assert.is_false(widgets[1].loaded)
	end)

	it("skips a manifest it cannot use, saying why", function()
		local widgets, warnings = discover({
			[FOLDER .. "gui_broken/manifest.json"] = "{",
			[FOLDER .. "gui_misnamed/manifest.json"] = manifest('"GuiMisnamed"'),
		})

		assert.are.same({}, widgets)
		assert.are.equal(2, #warnings)
		assert.truthy(table.concat(warnings, "\n"):find("gui_broken/manifest.json is not valid JSON", 1, true))
		assert.truthy(table.concat(warnings, "\n"):find("is not a valid widget id", 1, true))
	end)

	it("reads several folders as one set, the first directory keeping a repeated id", function()
		local widgets, warnings = discover({
			[FOLDER .. "gui_example/manifest.json"] = manifest('"gui_example"'),
			[RML_FOLDER .. "gui_other/manifest.json"] = manifest('"gui_other"'),
			[RML_FOLDER .. "gui_repeat/manifest.json"] = manifest('"gui_example"'),
		}, { FOLDER, RML_FOLDER }, {
			[FOLDER] = { FOLDER .. "gui_example" },
			[RML_FOLDER] = { RML_FOLDER .. "gui_other/", RML_FOLDER .. "gui_repeat/" },
		})

		assert.are.same({ "gui_example", "gui_other" }, ids(widgets))
		assert.are.equal(FOLDER .. "gui_example/", widgets[1].dir)
		assertOneWarningMentioning(warnings, "gui_repeat/manifest.json")
	end)
end)

describe("marking loaded widgets", function()
	it("flags the widgets a loaded file sits under, whatever its case, and says whether any moved", function()
		local widgets = {
			{ id = "gui_first", dir = FOLDER .. "gui_first/", manifest = {}, loaded = false },
			{ id = "gui_second", dir = FOLDER .. "gui_second/", manifest = {}, loaded = false },
			{ id = "gui_third", dir = FOLDER .. "gui_third/", manifest = {}, loaded = true },
		}
		local files = {
			"luaui/widgets/gui_first/gui_first.lua",
			FOLDER .. "gui_second_other/gui_second.lua",
			FOLDER .. "plain_widget.lua",
		}

		assert.is_true(WidgetManifests.MarkLoaded(widgets, files))
		assert.are.same({ true, false, false }, { widgets[1].loaded, widgets[2].loaded, widgets[3].loaded })
		assert.is_false(WidgetManifests.MarkLoaded(widgets, files))
	end)
end)

describe("widget id validation", function()
	it("accepts what the hub schema accepts and refuses the rest", function()
		for _, id in ipairs({ "gui_example", "cmd_a1_b2", "unit_x", "map_lower_snake_case" }) do
			assert.is_true(WidgetManifests.IsValidId(id), id)
		end
		for _, id in ipairs({
			"example",
			"Gui_Example",
			"gui_",
			"_gui",
			"gui__example",
			"gui-example",
			"gui_example ",
			"1gui_x",
			"",
			42,
			{},
		}) do
			assert.is_false(WidgetManifests.IsValidId(id), tostring(id))
		end

		assert.is_false(WidgetManifests.IsValidId(nil))
	end)
end)
