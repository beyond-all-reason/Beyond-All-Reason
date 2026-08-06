-- Guards the shared keybind data contract (common/configs/keybind_catalog.json and
-- keybind_defaults.json) against drift: structural conformance to the schemas, plus
-- referential integrity the schemas can't express (every catalog i18n key resolves
-- in the English source).
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

describe("shipped keybind profiles", function()
	local defaults = loadJson("common/configs/keybind_defaults.json")

	it("is an object with a non-empty profiles list", function()
		assert(type(defaults.profiles) == "table", "profiles must be a list")
		assert(#defaults.profiles > 0, "profiles must not be empty")
	end)

	it("gives every profile a unique name and a non-empty bind list", function()
		local seen = {}
		for _, profile in ipairs(defaults.profiles) do
			assert(type(profile.name) == "string" and profile.name ~= "", "profile missing name")
			assert(not seen[profile.name], "duplicate profile name: " .. tostring(profile.name))
			seen[profile.name] = true
			assert(type(profile.binds) == "table" and #profile.binds > 0,
				"profile has no binds: " .. profile.name)
		end
	end)

	it("gives every bind a keyset and an action", function()
		for _, profile in ipairs(defaults.profiles) do
			for i, bind in ipairs(profile.binds) do
				local where = profile.name .. " bind " .. i
				assert(type(bind.keyset) == "string" and bind.keyset ~= "", "no keyset: " .. where)
				assert(type(bind.action) == "string" and bind.action ~= "", "no action: " .. where)
			end
		end
	end)
end)

describe("keybind catalog", function()
	local catalog = loadJson("common/configs/keybind_catalog.json")

	it("is a non-empty, ordered list", function()
		assert(type(catalog) == "table", "catalog must be a list")
		assert(#catalog > 0, "catalog must not be empty")
	end)

	it("shapes every entry as a category or a hidden list", function()
		for _, group in ipairs(catalog) do
			local isCategory = group.category ~= nil and group.items ~= nil
			local isHidden = group.hidden ~= nil and group.category == nil and group.items == nil
			assert(isCategory or isHidden, "entry is neither a category nor a hidden list")
			if isHidden then
				assert(type(group.hidden) == "table", "hidden must be a list")
				for _, prefix in ipairs(group.hidden) do
					assert(type(prefix) == "string", "hidden entry must be a string prefix")
				end
			end
		end
	end)

	it("titles every category with a resolvable i18n key and has items", function()
		for _, group in ipairs(catalog) do
			if group.category then
				assert(type(group.category) == "string", "category missing title key")
				assert(i18nExists(group.category), "missing i18n for category: " .. group.category)
				assert(type(group.items) == "table", "category has no items: " .. group.category)
			end
		end
	end)

	it("shapes every item as exactly one recognized kind", function()
		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items or {}) do
				local editable = item.action ~= nil and item.label ~= nil and item.keyLabel == nil and item.prefix == nil
				local info = item.label ~= nil and item.keyLabel ~= nil and item.action == nil and item.prefix == nil
				-- prefix groups may carry an optional label (interpolated per action) and unit flag
				local prefix = item.prefix ~= nil and item.action == nil and item.keyLabel == nil
					and (item.unit == nil or type(item.unit) == "boolean")
				assert(editable or info or prefix, "unrecognized item shape under " .. tostring(group.category))
			end
		end
	end)

	it("resolves every label and keyLabel in the English localization", function()
		for _, group in ipairs(catalog) do
			for _, item in ipairs(group.items or {}) do
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
