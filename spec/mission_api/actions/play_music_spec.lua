require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

GG['music'] = nil  -- start with no music module

local actions  = VFS.Include('luarules/mission_api/actions/play_music.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.play_music", function()

    before_each(function()
        GG['music'] = nil
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type      = 'PlayMusic',
            soundfile = 'String!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls GG['music'].GadgetPlayMusicTrack when the music module is present", function()
            local calls = {}
            GG['music'] = {
                GadgetPlayMusicTrack = function(file) calls[#calls + 1] = file end,
            }
            action.actionFunction('music/track.ogg')
            assert.are.equal(1, #calls)
            assert.are.equal('music/track.ogg', calls[1])
        end)

        it("is a no-op when GG['music'] is nil", function()
            GG['music'] = nil
            -- must not error
            assert.has_no.errors(function()
                action.actionFunction('music/track.ogg')
            end)
        end)
    end)

end)
