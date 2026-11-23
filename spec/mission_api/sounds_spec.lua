local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

describe("mission_api.sounds.StopSound", function()

	---@type table, table
	local sounds, missionApi
	---@type string[], string[]
	local played, stopped

	before_each(function()
		played, stopped = {}, {}
		env.Spring.PlaySoundFile = function(soundfile)
			played[#played + 1] = soundfile
		end
		env.Spring.StopSoundByFilename = function(soundfile)
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

	it("stops the sample and leaves the queue alone", function()
		sounds.StopSound("sounds/voice.wav")

		assert.are.same({ "sounds/voice.wav" }, stopped)
		assert.are.equal(3, #missionApi.soundQueue)
	end)

	it("lets the next queued sound start when the playing one is stopped", function()
		sounds.ProcessSoundQueue(0)

		sounds.StopSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(1)

		assert.are.same({ "sounds/voice.wav", "sounds/other.wav" }, played)
	end)

	it("does nothing on an engine without StopSoundByFilename", function()
		env.Spring.StopSoundByFilename = nil
		sounds.ProcessSoundQueue(0)

		sounds.StopSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(1)

		assert.are.equal(2, #missionApi.soundQueue)
		assert.are.same({ "sounds/voice.wav" }, played)
	end)

	it("forgets the playing sound once it is stopped or over", function()
		sounds.ProcessSoundQueue(0)
		sounds.StopSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(1)
		sounds.StopSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(2)
		assert.are.same({ "sounds/voice.wav", "sounds/other.wav" }, played)

		sounds.ProcessSoundQueue(1000)
		sounds.EnqueueSound("sounds/voice.wav")
		sounds.ProcessSoundQueue(1001)
		sounds.EnqueueSound("sounds/voice.wav")
		sounds.StopSound("sounds/other.wav")
		sounds.ProcessSoundQueue(1002)
		assert.are.equal(3, #played)
	end)

	it("keeps the queue waiting when another sound is stopped", function()
		sounds.ProcessSoundQueue(0)

		sounds.StopSound("sounds/other.wav")
		sounds.ProcessSoundQueue(1)

		assert.are.same({ "sounds/voice.wav" }, played)
	end)

end)
