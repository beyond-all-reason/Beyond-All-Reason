local base64 = VFS.Include("common/luaUtilities/base64.lua")

local missionOptions = VFS.Include("luaui/Include/mission_options.lua")

local modOptions = {}
local previousGetModOptions

local function setMissionOptions(json)
	modOptions.missionoptions = json and base64.Encode(VFS.ZlibCompress(json)) or nil
end

describe("mission options", function()
	before_each(function()
		previousGetModOptions = Spring.GetModOptions
		Spring.GetModOptions = function()
			return modOptions
		end
	end)

	after_each(function()
		Spring.GetModOptions = previousGetModOptions
		modOptions = {}
	end)

	describe("IsStartUnitSpawnDisabled", function()
		it("is true when the mission disables the spawn", function()
			setMissionOptions([[{"disableInitialCommanderSpawn":true}]])

			assert.is_true(missionOptions.IsStartUnitSpawnDisabled())
		end)

		it("is true when the mission places units itself", function()
			setMissionOptions([[{"unitloadout":[{"name":"armcom","x":1,"z":1}]}]])

			assert.is_true(missionOptions.IsStartUnitSpawnDisabled())
		end)

		it("is false for an empty loadout", function()
			setMissionOptions([[{"unitloadout":[]}]])

			assert.is_false(missionOptions.IsStartUnitSpawnDisabled())
		end)

		it("is false without the modoption", function()
			assert.is_false(missionOptions.IsStartUnitSpawnDisabled())
			modOptions.missionoptions = ""
			assert.is_false(missionOptions.IsStartUnitSpawnDisabled())
		end)

		it("is false for a payload that does not decode", function()
			modOptions.missionoptions = "not a payload"

			assert.is_false(missionOptions.IsStartUnitSpawnDisabled())
		end)
	end)

	describe("IsFactionPickerDisabled", function()
		it("is true when the mission fixes the faction", function()
			setMissionOptions([[{"disableFactionPicker":true}]])

			assert.is_true(missionOptions.IsFactionPickerDisabled())
		end)

		it("is false for an unrelated payload", function()
			setMissionOptions([[{"disableInitialCommanderSpawn":true}]])

			assert.is_false(missionOptions.IsFactionPickerDisabled())
		end)

		it("is false without the modoption", function()
			assert.is_false(missionOptions.IsFactionPickerDisabled())
		end)
	end)
end)
