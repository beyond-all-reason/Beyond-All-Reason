-- Guards the shared keybind data contract (common/configs/keybind_catalog.json and
-- keybind_presets.json) against drift: structural conformance to the schemas, plus
-- referential integrity the schemas can't express (preset files exist on disk, every
-- catalog i18n key resolves in the English source).
--
-- Reads the JSON directly rather than through the Lua adapters, because the adapters
-- use VFS.LoadFile, which the test harness does not mock.

local Json = VFS.Include("common/luaUtilities/json.lua")

local function loadJson(path)
	local f = assert(io.open(path, "r"), "cannot open " .. path)
	local content = f:read("*a")
	f:close()
	return Json.decode(content)
end

-- Walk a dotted i18n key ("ui.keybinds.chat.send") through the English source.
local i18n = loadJson("language/en/interface.json")
local function i18nExists(dottedKey)
	local node = i18n
	for part in dottedKey:gmatch("[^.]+") do
		if type(node) ~= "table" then return false end
		node = node[part]
	end
	return node ~= nil
end

describe("keybind preset registry", function()
	local registry = loadJson("common/configs/keybind_presets.json")

	it("is an object with a non-empty presets list", function()
		assert(type(registry.presets) == "table", "presets must be a list")
		assert(#registry.presets > 0, "presets must not be empty")
	end)

	it("gives every preset a name and an existing bind file", function()
		for _, preset in ipairs(registry.presets) do
			assert(type(preset.name) == "string", "preset missing name")
			assert(type(preset.file) == "string", "preset missing file: " .. tostring(preset.name))
			-- uikeys.txt (Custom) is created on demand, so only shipped files must exist
			if preset.file ~= "uikeys.txt" then
				assert(VFS.FileExists(preset.file), "preset file missing: " .. preset.file)
			end
		end
	end)

	it("maps the Custom preset to uikeys.txt", function()
		local custom
		for _, preset in ipairs(registry.presets) do
			if preset.name == "Custom" then custom = preset end
		end
		assert(custom, "no Custom preset")
		assert(custom.file == "uikeys.txt", "Custom must map to uikeys.txt")
	end)
end)

describe("keybind catalog", function()
	local catalog = loadJson("common/configs/keybind_catalog.json")

	it("is a non-empty, ordered list of categories", function()
		assert(type(catalog) == "table", "catalog must be a list")
		assert(#catalog > 0, "catalog must not be empty")
	end)

	it("titles every category with a resolvable i18n key and has items", function()
		for _, group in ipairs(catalog) do
			assert(type(group.category) == "string", "category missing title key")
			assert(i18nExists(group.category), "missing i18n for category: " .. group.category)
			assert(type(group.items) == "table", "category has no items: " .. group.category)
		end
	end)

	it("shapes every item as exactly one recognized kind", function()
		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items) do
				local editable = item.action ~= nil and item.label ~= nil and item.keyLabel == nil and item.prefix == nil
				local info = item.label ~= nil and item.keyLabel ~= nil and item.action == nil and item.prefix == nil
				local prefix = item.prefix ~= nil and item.action == nil and item.label == nil and item.keyLabel == nil
				assert(editable or info or prefix, "unrecognized item shape under " .. group.category)
			end
		end
	end)

	it("resolves every label and keyLabel in the English localization", function()
		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items) do
				if item.label then
					assert(i18nExists(item.label), "missing i18n for label: " .. item.label)
				end
				if item.keyLabel then
					assert(i18nExists(item.keyLabel), "missing i18n for keyLabel: " .. item.keyLabel)
				end
			end
		end
	end)
end)
