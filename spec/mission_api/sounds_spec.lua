local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

describe("mission_api.sounds.StopSound", function()

	local sounds, missionApi
	local played, stopped

	before_each(function()
		played, stopped = {}, {}
		env.Spring.PlaySoundFile = function(soundfile)
			played[#played + 1] = soundfile
		end
		env.Spring.StopSoundFile = function(soundfile)
			stopped[#stopped + 1] = soundfile
		end
		env.Spring.SendLuaUIMsg = function() end

		sounds = MissionSpecEnv.include(env, "luarules/mission_api/sounds.lua")
		missionApi =
			MissionApiBuilder.new():WithSoundFile("sounds/voice.wav", 4):WithSoundFile("sounds/other.wav", 2):Install()

		sounds.EnqueueSound("sounds/voice.wav")
		sounds.EnqueueSound("sounds/other.wav")
		sounds.EnqueueSound("sounds/voice.wav")
	end)

	it("stops the sample and drops the queued entries of that file only", function()
		sounds.StopSound("sounds/voice.wav")

		assert.are.same({ "sounds/voice.wav" }, stopped)
		assert.are.equal(1, #missionApi.soundQueue)
		assert.are.equal("sounds/other.wav", missionApi.soundQueue[1].soundfile)
	end)

	it("lets the next queued sound start when the playing one is stopped", function()
		sounds.ProcessSoundQueue(0)

		sounds.StopSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(1)

		assert.are.same({ "sounds/voice.wav", "sounds/other.wav" }, played)
	end)

	it("keeps the queue waiting when another sound is stopped", function()
		sounds.ProcessSoundQueue(0)

		sounds.StopSound("sounds/other.wav")
		sounds.ProcessSoundQueue(1)

		assert.are.same({ "sounds/voice.wav" }, played)
	end)

end)
