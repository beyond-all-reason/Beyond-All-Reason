require("spec_helper")

local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/api_mission_input_lock.lua"

describe("luaui.Widgets.api_mission_input_lock", function()
	---@type string[]
	local calls

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new():LoadWidget(WIDGET_PATH)
		loaded.WG.playerInputLock = {
			Lock = function(...)
				assert.are.equal(0, select("#", ...))
				calls[#calls + 1] = "Lock"
			end,
			Unlock = function()
				calls[#calls + 1] = "Unlock"
			end,
		}
		return loaded
	end

	before_each(function()
		calls = {}
	end)

	it("locks and unlocks through the Player Input Lock", function()
		local env = loadWidget().env
		env.MissionLockPlayerInput()
		env.MissionUnlockPlayerInput()
		assert.are.same({ "Lock", "Unlock" }, calls)
	end)

	it("does nothing without the Player Input Lock", function()
		local loaded = loadWidget()
		loaded.WG.playerInputLock = nil
		loaded.env.MissionLockPlayerInput()
		loaded.env.MissionUnlockPlayerInput()
		assert.are.same({}, calls)
	end)

	it("removes its globals on shutdown", function()
		local loaded = loadWidget()
		loaded.env.widget:Shutdown()
		assert.is_nil(loaded.env.MissionLockPlayerInput)
		assert.is_nil(loaded.env.MissionUnlockPlayerInput)
	end)
end)
