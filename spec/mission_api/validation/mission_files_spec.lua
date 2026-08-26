---
--- Validates the test mission files.
---

local V = require("mission_api.validation.validation_spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

local missionDirectory = 'singleplayer/mission-api-tests/'

--- validation_test.lua is deliberately full of errors, so it is checked separately.
local invalidMission = 'validation_test.lua'

--- Def name lookups accept any name because the real UnitDefs are not available here;
local function mockDefNames()
	local anyDefName = setmetatable({}, { __index = function() return { id = 1 } end })
	_G.UnitDefNames    = anyDefName
	_G.FeatureDefNames = anyDefName
	_G.WeaponDefNames  = anyDefName
end

--- The engine CMD table maps both ways: name -> id and id -> name.
local function mockCommands()
	_G.CMD = {}
	for index, name in ipairs({
		'STOP', 'MOVE', 'PATROL', 'FIGHT', 'ATTACK', 'AREA_ATTACK', 'GUARD', 'RECLAIM',
		'REPAIR', 'RESTORE', 'RESURRECT', 'CAPTURE', 'DGUN', 'SELFD', 'CLOAK', 'ONOFF',
		'FIRE_STATE', 'MOVE_STATE', 'LOAD_UNITS', 'UNLOAD_UNITS', 'INTERNAL',
	}) do
		_G.CMD[name]  = index
		_G.CMD[index] = name
	end
	-- The ANY/BUILD qualifiers used by the Command parameter type, per common/constants.lua.
	_G.CMD.ANY   = "a"
	_G.CMD.a     = "ANY"
	_G.CMD.BUILD = "b"
	_G.CMD.b     = "BUILD"
	_G.GameCMD = { AREA_ATTACK_GROUND = 100, [100] = 'AREA_ATTACK_GROUND' }
end

-- Sound file validation reads the .wav header through these, which spec_helper does not mock.
VFS.LoadFile = VFS.LoadFile or function(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local data = file:read("*a")
	file:close()
	return data
end
VFS.UnpackU16 = VFS.UnpackU16 or function(bytes)
	local b1, b2 = bytes:byte(1, 2)
	return b1 + b2 * 256
end
VFS.UnpackU32 = VFS.UnpackU32 or function(bytes)
	local b1, b2, b3, b4 = bytes:byte(1, 4)
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function getMissionFileNames()
	local handle = io.popen("ls " .. missionDirectory)
	local fileNames = {}
	for fileName in handle:lines() do
		if fileName:match('%.lua$') then
			fileNames[#fileNames + 1] = fileName
		end
	end
	handle:close()
	return fileNames
end

local function validateMissionFile(fileName)
	-- Mission files read the definitions from GG when they are included.
	Builders.MissionApi.new()
		:WithActionDefinitions(V.definitions.ActionDefinitions)
		:WithTriggerDefinitions(V.definitions.TriggerDefinitions)
		:Install()

	return V.validate(VFS.Include(missionDirectory .. fileName))
end

describe("mission_api mission files", function()
	local fileNames = getMissionFileNames()

	before_each(function()
		V.mockEngineGlobals()
		mockDefNames()
		mockCommands()
		Spring.GetAllyTeamList = function() return { 0, 1 } end
	end)

	it("finds the mission files", function()
		assert.is_true(#fileNames > 0)
		assert.is_true(table.contains(fileNames, invalidMission))
	end)

	for _, fileName in ipairs(fileNames) do
		if fileName ~= invalidMission then
			it(fileName .. " passes validation", function()
				V.assertValid(validateMissionFile(fileName))
			end)
		end
	end

	it(invalidMission .. " fails validation, since it exercises the error cases", function()
		local result = validateMissionFile(invalidMission)

		assert.is_false(result.ok)
		assert.is_true(#result.errors > 0)
		assert.is_true(#result.warnings > 0)

		-- An unexpected error means validation aborted early instead of reporting.
		V.assertNoMessageContaining(result, "Validation failed unexpectedly")
	end)
end)
