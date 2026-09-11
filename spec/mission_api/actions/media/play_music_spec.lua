require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/media/play_music.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.play_music", function()

	before_each(function()
		GG["music"] = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "PlayMusic",
			soundfile = "String!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GG['music'].GadgetPlayMusicTrack with the given track and does not raise", function()
			local calls = {}
			GG["music"] = {
				GadgetPlayMusicTrack = function(file)
					calls[#calls + 1] = file
				end,
			}

			assert.has_no.errors(function()
				action.actionFunction("music/track.ogg")
			end)

			assert.are.equal(1, #calls)
			assert.are.equal("music/track.ogg", calls[1])
		end)

		it("raises naming the missing music API and the track", function()
			GG["music"] = nil

			local ok, err = pcall(action.actionFunction, "music/track.ogg")

			assert.is_false(ok)
			err = tostring(err)
			assert.is_truthy(err:find("Music API unavailable", 1, true), err)
			assert.is_truthy(err:find("music/track.ogg", 1, true), err)
		end)
	end)

end)
