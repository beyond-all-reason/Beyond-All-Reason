require("spec_helper")

describe("mission_api.cutscenes", function()
	local cutscenes, calls, onVideoFinished, savedLog

	before_each(function()
		-- Included per test: the module counts the videos playing.
		cutscenes = VFS.Include("luarules/mission_api/cutscenes.lua")
		calls = {}
		onVideoFinished = nil
		GG.GamePause = {
			Pause = function(source)
				calls[#calls + 1] = "Pause " .. source
			end,
			Unpause = function(source)
				calls[#calls + 1] = "Unpause " .. source
			end,
		}
		GG.VideoPlayback = {
			-- Replacing a video finishes the replaced one, as api_video_playback.lua does.
			Play = function(videoFile, onFinished)
				local replaced = onVideoFinished
				calls[#calls + 1] = "Play " .. videoFile
				onVideoFinished = onFinished
				if replaced then
					replaced()
				end
			end,
		}
		savedLog = Spring.Log
		Spring.Log = function(_, level, message)
			calls[#calls + 1] = { level = level, message = message }
		end
		GG["MissionAPI"] = {
			Cutscenes = {
				intro = { videoFile = "videos/intro.webm" },
				outro = { videoFile = "videos/outro.webm" },
				landing = { script = "landingParty" },
			},
		}
	end)

	after_each(function()
		GG.GamePause = nil
		GG.VideoPlayback = nil
		GG["MissionAPI"] = nil
		Spring.Log = savedLog
	end)

	describe("StartCutscene", function()
		it("pauses the game, then plays a cutscene video", function()
			cutscenes.StartCutscene("intro")
			assert.are.same({ "Pause cutscene", "Play videos/intro.webm" }, calls)
		end)

		it("unpauses the game when the video ends", function()
			cutscenes.StartCutscene("intro")
			onVideoFinished()
			assert.are.same({ "Pause cutscene", "Play videos/intro.webm", "Unpause cutscene" }, calls)
		end)

		it("keeps the game paused until a video that replaced another one ends", function()
			cutscenes.StartCutscene("intro")
			cutscenes.StartCutscene("outro")
			assert.are.same(
				{ "Pause cutscene", "Play videos/intro.webm", "Pause cutscene", "Play videos/outro.webm" },
				calls
			)

			onVideoFinished()
			assert.are.equal("Unpause cutscene", calls[#calls])
		end)

		it("raises before pausing when video playback is unavailable", function()
			GG.VideoPlayback = nil

			local ok, err = pcall(cutscenes.StartCutscene, "intro")

			assert.is_false(ok)
			assert.is_truthy(tostring(err):find("Video playback unavailable", 1, true))
			assert.are.same({}, calls)
		end)

		it("does not pause the game or play a video for a scripted cutscene", function()
			cutscenes.StartCutscene("landing")
			assert.are.same({
				{
					level = LOG.WARNING,
					message = "[Mission API] Scripted control is not implemented, skipping: landingParty",
				},
			}, calls)
		end)
	end)
end)
