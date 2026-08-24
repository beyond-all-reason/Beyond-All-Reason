require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/media/play_sound.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

describe("mission_api.actions.play_sound", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type      = 'PlaySound',
            soundfile = 'SoundFile!',
            volume    = 'Number',
            position  = 'Position',
            enqueue   = 'Boolean',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Sounds.PlaySound when enqueue is nil", function()
            action.actionFunction('sounds/bang.wav', 1.0, nil, nil)
            assert.are.equal(1, #missionApi.calls.playSound)
            assert.are.equal(0, #missionApi.calls.enqueueSound)
            assert.are.equal('sounds/bang.wav', missionApi.calls.playSound[1].soundfile)
        end)

        it("calls Sounds.PlaySound when enqueue is false", function()
            action.actionFunction('sounds/bang.wav', 1.0, nil, false)
            assert.are.equal(1, #missionApi.calls.playSound)
            assert.are.equal(0, #missionApi.calls.enqueueSound)
        end)

        it("calls Sounds.EnqueueSound when enqueue is true", function()
            action.actionFunction('sounds/bang.wav', 1.0, nil, true)
            assert.are.equal(0, #missionApi.calls.playSound)
            assert.are.equal(1, #missionApi.calls.enqueueSound)
            assert.are.equal('sounds/bang.wav', missionApi.calls.enqueueSound[1].soundfile)
        end)

        it("passes volume and position to PlaySound", function()
            local pos = { x = 1, y = 2, z = 3 }
            action.actionFunction('sounds/x.wav', 0.5, pos, false)
            assert.are.equal(0.5, missionApi.calls.playSound[1].volume)
            assert.are.same(pos, missionApi.calls.playSound[1].position)
        end)
    end)

end)
