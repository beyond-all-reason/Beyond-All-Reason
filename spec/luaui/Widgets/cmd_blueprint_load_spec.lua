-- cmd_blueprint's blueprints.json load and save paths.
--
-- Names are always written empty by the game (createBlueprint sets name = ""),
-- so every non-empty name in a real blueprints.json got there by hand or by
-- being pasted from someone else. The file is a user-authored input and these
-- specs cover what the loader does with the malformed ones users produce.
--
-- The two paths are locals called from Initialize and Shutdown, so the widget is
-- loaded into a sandbox with its own io/os/VFS and both are driven directly. The
-- point of most of these cases is the pairing: a file we could not read in full
-- is the player's only copy of what is in it, so the load has to report and the
-- save has to refuse.
---@diagnostic disable: undefined-field, redundant-parameter

local WIDGET_PATH = "luaui/Widgets/cmd_blueprint.lua"
local DOCTOR_PATH = "luaui/Include/blueprints/json_doctor.lua"
local BLUEPRINT_PATH = "LuaUI/Config/blueprints.json"
local PENDING_PATH = BLUEPRINT_PATH .. ".pending"
local BACKUP_PATH = BLUEPRINT_PATH .. ".backup"

local Json = VFS.Include("common/luaUtilities/json.lua")

-- Two buildings is enough: one that resolves and one that does not.
local UNIT_DEFS = {
	[10] = { name = "armmex", isBuilding = true, xsize = 4, zsize = 4, customParams = {}, buildOptions = {} },
	[11] = { name = "armsolar", isBuilding = true, xsize = 4, zsize = 4, customParams = {}, buildOptions = {} },
}

---Renders an i18n call as key plus sorted parameters, so the specs assert on keys
---rather than on wording that is expected to change.
local function fakeI18N(key, params)
	if not params then
		return key
	end
	local parts = {}
	for name, value in pairs(params) do
		parts[#parts + 1] = name .. "=" .. tostring(value)
	end
	table.sort(parts)
	return key .. "|" .. table.concat(parts, ",")
end

---Load cmd_blueprint into a sandbox with a one-file disk, then run Initialize.
---@param content string|nil the blueprints file's contents, or nil for no file
---@param options table|nil unreadable: the file exists but cannot be read
---@return table
local function loadWith(content, options)
	options = options or {}

	local env = setmetatable({}, { __index = _G })

	-- Paths map to contents; false marks a file that exists but will not read.
	local disk = {}
	if options.unreadable then
		disk[BLUEPRINT_PATH] = false
	elseif content ~= nil then
		disk[BLUEPRINT_PATH] = content
	end

	local echoes = {}
	local writes = {}
	local unitDefNames = {}
	for defID, def in pairs(UNIT_DEFS) do
		unitDefNames[def.name] = { id = defID }
	end

	---@diagnostic disable-next-line: missing-fields
	env.widget = {}
	env.Json = Json
	env.UnitDefs = UNIT_DEFS
	env.UnitDefNames = unitDefNames
	env.BAR = setmetatable({ I18N = fakeI18N }, { __index = _G.BAR })
	env.GameCMD = setmetatable({}, {
		__index = function()
			return 40000
		end,
	})
	env.CMDTYPE = setmetatable({}, {
		__index = function()
			return 1
		end,
	})
	env.Platform = { isHeadless = true, gl = false }
	env.widgetHandler = {
		RemoveWidget = function() end,
		actionHandler = {
			AddAction = function() end,
			RemoveAction = function() end,
		},
	}

	env.Spring = setmetatable({
		Echo = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring((select(i, ...)))
			end
			table.insert(echoes, table.concat(parts, " "))
		end,
		GetModOptions = function()
			return {}
		end,
		GetSelectedUnits = function()
			return {}
		end,
		GetLocalTeamID = function()
			return 0
		end,
		GetUnitDefID = function()
			return nil
		end,
		GetViewGeometry = function()
			return 1920, 1080, 0, 0
		end,
		GetConfigString = function(_, fallback)
			return fallback
		end,
		GetSelectionBox = function()
			return nil
		end,
	}, { __index = _G.Spring })

	env.VFS = setmetatable({
		LoadFile = function(path)
			local stored = disk[path]
			if stored == false then
				return nil
			end
			return stored
		end,
		FileExists = function(path)
			return disk[path] ~= nil
		end,
		Include = function(path, ...)
			-- Reads the live keybindings, which the sandbox has none of.
			if path == "luaui/Include/action_hotkeys.lua" then
				return {}
			end
			-- The doctor is the code under test here, not a dependency to stub.
			-- Running it in this environment is also what the engine does: an
			-- include with no environment of its own inherits its caller's.
			if path == DOCTOR_PATH then
				local doctor = assert(loadfile(DOCTOR_PATH))
				setfenv(doctor, env)
				return doctor()
			end
			return _G.VFS.Include(path, ...)
		end,
	}, { __index = _G.VFS })

	env.io = setmetatable({
		open = function(path, mode)
			if mode ~= "w" or options.openFails then
				return nil
			end
			local buffer = {}
			return {
				write = function(_, text)
					if options.writeFails then
						return nil
					end
					buffer[#buffer + 1] = text
					return true
				end,
				close = function()
					disk[path] = table.concat(buffer)
					table.insert(writes, path)
					return true
				end,
			}
		end,
	}, { __index = _G.io })

	env.os = setmetatable({
		remove = function(path)
			if disk[path] == nil then
				return nil
			end
			disk[path] = nil
			return true
		end,
		rename = function(from, to)
			if disk[from] == nil then
				return nil
			end
			disk[to] = disk[from]
			disk[from] = nil
			return true
		end,
	}, { __index = _G.os })

	-- Mirrors api_blueprint.createBlueprintFromSerialized: no validation beyond
	-- "has a units table", unit names resolved through UnitDefNames, unresolved
	-- names kept as originalName with a nil unitDefID.
	env.WG = {
		api_blueprint = {
			createBlueprintFromSerialized = function(serialized)
				if not serialized or not serialized.units then
					return nil
				end
				local result = table.copy(serialized)
				result.units = {}
				for _, unit in ipairs(serialized.units) do
					local named = unitDefNames[unit.unitName]
					table.insert(result.units, {
						blueprintUnitID = 1,
						position = unit.position,
						facing = unit.facing,
						unitDefID = named and named.id,
						originalName = unit.unitName,
					})
				end
				if #result.units == 0 then
					return nil
				end
				return result
			end,
			getBlueprintDimensions = function()
				return 0, 0
			end,
			getBuildingDimensions = function()
				return 4, 4
			end,
			setActiveBlueprint = function() end,
			setBlueprintPositions = function() end,
		},
	}

	local chunk = assert(loadfile(WIDGET_PATH))
	setfenv(chunk, env)
	chunk()

	local ok, err = pcall(env.widget.Initialize, env.widget)

	local result = {
		env = env,
		disk = disk,
		writes = writes,
		echoes = echoes,
		ok = ok,
		err = ok and nil or tostring(err),
	}

	function result.shutdown()
		assert(pcall(env.widget.Shutdown, env.widget))
		return result
	end

	function result.saved()
		return Json.decode(disk[BLUEPRINT_PATH]).savedBlueprints
	end

	return result
end

local function blueprintEntry(name, unitName)
	return {
		name = name,
		spacing = 0,
		facing = 0,
		ordered = true,
		units = { { unitName = unitName, facing = 0, position = { 0, 0, 0 } } },
	}
end

local function fileWith(...)
	return Json.encode({ savedBlueprints = { ... } })
end

local function echoMatching(result, text)
	for _, line in ipairs(result.echoes) do
		if line:find(text, 1, true) then
			return line
		end
	end
	return nil
end

describe("cmd_blueprint blueprints.json", function()
	describe("files it reads", function()
		it("loads a well-formed file without comment", function()
			local result = loadWith(fileWith(blueprintEntry("", "armmex"), blueprintEntry("", "armsolar")))

			assert.is_true(result.ok, result.err)
			assert.are.same({}, result.echoes)
		end)

		it("says nothing when there is no file yet", function()
			local result = loadWith(nil)

			assert.is_true(result.ok, result.err)
			assert.are.same({}, result.echoes)
		end)

		it("says nothing when the old file is empty", function()
			local result = loadWith("   \n")

			assert.is_true(result.ok, result.err)
			assert.are.same({}, result.echoes)
		end)

		it("names a blueprint whose units all fail to resolve, and keeps it", function()
			local result = loadWith(fileWith(blueprintEntry("junk", "notaunit")))

			assert.is_true(result.ok, result.err)
			assert.is_not_nil(echoMatching(result, "ui.blueprint.entry_kept|name=junk"))
		end)

		it("names an entry that is not a blueprint at all, and keeps it", function()
			local result = loadWith([[{"savedBlueprints":[1,2]}]])

			assert.is_true(result.ok, result.err)
			assert.is_not_nil(echoMatching(result, "ui.blueprint.entry_kept|name=#1"))
			assert.are.same({ 1, 2 }, result.shutdown().saved())
		end)

		it("closes a gap left by a null, keeping what is past it", function()
			local result = loadWith('{"savedBlueprints":[{"name":"a","units":[]},null,{"name":"c","units":[]}]}')

			assert.is_true(result.ok, result.err)

			local saved = result.shutdown().saved()

			assert.are.equal(2, #saved)
			assert.are.equal("a", saved[1].name)
			assert.are.equal("c", saved[2].name)
		end)

		it("keeps blueprints in the order the file had them", function()
			local result = loadWith(
				fileWith(
					blueprintEntry("first", "armmex"),
					blueprintEntry("second", "armsolar"),
					blueprintEntry("third", "armmex")
				)
			)

			local saved = result.shutdown().saved()

			assert.are.equal("first", saved[1].name)
			assert.are.equal("second", saved[2].name)
			assert.are.equal("third", saved[3].name)
		end)

		it("accepts a null at the end of the list, which holds nothing", function()
			local result = loadWith('{"savedBlueprints":[{"name":"a","units":[]},null]}')

			assert.is_true(result.ok, result.err)
			assert.are.equal(1, #result.shutdown().saved())
		end)

		it("keeps an escaped forward slash in a name (regression, #8666)", function()
			local result = loadWith([[{"savedBlueprints":[{"name":"eco\/lab","units":[]}]}]])

			assert.is_true(result.ok, result.err)
			assert.is_not_nil(echoMatching(result, "ui.blueprint.entry_kept|name=eco/lab"))
		end)

		it("reads back a name it wrote itself", function()
			-- encodeString used to escape only " \ \n \t, so a control character
			-- went out raw and produced a file the decoder had no token for.
			local encoded = Json.encode({ savedBlueprints = { blueprintEntry("two\rlines", "armmex") } })

			assert.is_nil(encoded:find("\r", 1, true))
			assert.is_true(loadWith(encoded).ok)
		end)
	end)

	-- Reading nothing out of a file that holds something used to be followed by
	-- saving that nothing back over it. Every case here has to survive shutdown.
	describe("files it cannot read", function()
		local function assertRefusesToSave(content, key, options)
			local result = loadWith(content, options)
			local before = result.disk[BLUEPRINT_PATH]

			assert.is_true(result.ok, result.err)
			assert.is_not_nil(echoMatching(result, key))

			result.shutdown()

			assert.are.same({}, result.writes)
			assert.are.equal(before, result.disk[BLUEPRINT_PATH])
			assert.is_nil(result.disk[PENDING_PATH])
			assert.is_not_nil(echoMatching(result, "ui.blueprint.save_failed"))

			return result
		end

		it("reports a file that exists but will not read", function()
			assertRefusesToSave(nil, "ui.blueprint.file_damaged", { unreadable = true })
		end)

		it("reports a file truncated mid-write", function()
			local full = fileWith(blueprintEntry("", "armmex"))
			assertRefusesToSave(full:sub(1, #full - 20), "ui.blueprint.file_damaged")
		end)

		it("reports a UTF-8 BOM", function()
			assertRefusesToSave("\239\187\191" .. fileWith(blueprintEntry("", "armmex")), "ui.blueprint.file_damaged")
		end)

		it("reports curly quotes from a chat client", function()
			assertRefusesToSave("{\226\128\156savedBlueprints\226\128\157:[]}", "ui.blueprint.file_damaged")
		end)

		it("reports a // comment, though /* */ is accepted", function()
			assertRefusesToSave('{\n// mine\n"savedBlueprints":[]}', "ui.blueprint.file_damaged")
			assert.is_true(loadWith('{/* mine */"savedBlueprints":[]}').ok)
		end)

		it("reports a comma dropped between two blueprints", function()
			assertRefusesToSave(
				[[{"savedBlueprints":[{"name":"a","units":[]} {"name":"b","units":[]}]}]],
				"ui.blueprint.file_damaged"
			)
		end)

		it("reports a malformed \\u escape", function()
			assertRefusesToSave([[{"savedBlueprints":[{"name":"\u00zz","units":[]}]}]], "ui.blueprint.file_damaged")
		end)

		it("reports savedBlueprints as an object rather than a list", function()
			-- ipairs walks none of it, so this used to load zero blueprints in
			-- silence and then write that zero back.
			assertRefusesToSave([[{"savedBlueprints":{"first":{"name":"a","units":[]}}}]], "ui.blueprint.file_damaged")
		end)

		it("reports a document that is not an object", function()
			assertRefusesToSave("[1,2,3]", "ui.blueprint.file_damaged")
		end)

		it("names the file it is leaving alone", function()
			local result = loadWith("{")

			assert.is_not_nil(echoMatching(result, "ui.blueprint.file_damaged|file=" .. BLUEPRINT_PATH))
		end)
	end)

	describe("saving", function()
		it("writes through a pending file and keeps the previous one as a backup", function()
			local original = fileWith(blueprintEntry("", "armmex"))
			local result = loadWith(original).shutdown()

			assert.are.equal(original, result.disk[BACKUP_PATH])
			assert.is_nil(result.disk[PENDING_PATH])
			assert.are.equal(1, #result.saved())
		end)

		it("creates the file when there was none", function()
			local result = loadWith(nil).shutdown()

			assert.are.same({}, result.saved())
			assert.is_nil(result.disk[BACKUP_PATH])
		end)

		it("leaves the previous file alone when the write fails", function()
			local original = fileWith(blueprintEntry("", "armmex"))
			local result = loadWith(original, { writeFails = true }).shutdown()

			assert.are.equal(original, result.disk[BLUEPRINT_PATH])
			assert.is_nil(result.disk[PENDING_PATH])
			assert.is_not_nil(echoMatching(result, "ui.blueprint.save_failed"))
		end)

		it("leaves the previous file alone when it cannot be opened for writing", function()
			local original = fileWith(blueprintEntry("", "armmex"))
			local result = loadWith(original, { openFails = true }).shutdown()

			assert.are.equal(original, result.disk[BLUEPRINT_PATH])
			assert.is_not_nil(echoMatching(result, "ui.blueprint.save_failed"))
		end)

		it("writes blueprints it could not use back unchanged", function()
			local result = loadWith(fileWith(blueprintEntry("junk", "notaunit"))).shutdown()
			local saved = result.saved()

			assert.are.equal(1, #saved)
			assert.are.equal("junk", saved[1].name)
			assert.are.equal("notaunit", saved[1].units[1].unitName)
		end)
	end)

	describe("the strings it prints", function()
		it("has an English entry for every key the widget uses", function()
			local file = assert(io.open("language/en/interface.json", "r"))
			local interface = Json.decode(file:read("*a"))
			file:close()
			local blueprint = interface.ui.blueprint

			for _, key in ipairs({ "section", "entry_kept", "file_damaged", "save_failed" }) do
				assert.is_string(blueprint[key], key)
			end
		end)
	end)
end)
