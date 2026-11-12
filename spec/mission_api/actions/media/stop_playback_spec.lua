local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")

MissionApiBuilder.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/media/stop_playback.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.stop_playback", function()

	local missionApi

	before_each(function()
		missionApi = MissionApiBuilder.new():Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "StopPlayback",
			soundfile = "SoundFile!",
		}, summarizeSchema(action))
	end)

	it("calls Sounds.StopSound", function()
		action.actionFunction("sounds/bang.wav")
		assert.are.same({ { soundfile = "sounds/bang.wav" } }, missionApi.calls.stopSound)
	end)

end)
