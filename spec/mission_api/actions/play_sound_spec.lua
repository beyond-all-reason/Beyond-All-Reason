require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Modules.Sounds = {
    PlaySound    = function() end,
    EnqueueSound = function() end,
}

local actions  = VFS.Include('luarules/mission_api/actions/play_sound.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.play_sound", function()

    local playCalls, enqueueCalls

    before_each(function()
        playCalls    = {}
        enqueueCalls = {}
        GG['MissionAPI'].Modules.Sounds.PlaySound = function(file, volume, pos)
            playCalls[#playCalls + 1] = { file = file, volume = volume, pos = pos }
        end
        GG['MissionAPI'].Modules.Sounds.EnqueueSound = function(file, volume, pos)
            enqueueCalls[#enqueueCalls + 1] = { file = file, volume = volume, pos = pos }
        end
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
            assert.are.equal(1, #playCalls)
            assert.are.equal(0, #enqueueCalls)
            assert.are.equal('sounds/bang.wav', playCalls[1].file)
        end)

        it("calls Sounds.PlaySound when enqueue is false", function()
            action.actionFunction('sounds/bang.wav', 1.0, nil, false)
            assert.are.equal(1, #playCalls)
            assert.are.equal(0, #enqueueCalls)
        end)

        it("calls Sounds.EnqueueSound when enqueue is true", function()
            action.actionFunction('sounds/bang.wav', 1.0, nil, true)
            assert.are.equal(0, #playCalls)
            assert.are.equal(1, #enqueueCalls)
            assert.are.equal('sounds/bang.wav', enqueueCalls[1].file)
        end)

        it("passes volume and position to PlaySound", function()
            local pos = { x = 1, y = 2, z = 3 }
            action.actionFunction('sounds/x.wav', 0.5, pos, false)
            assert.are.equal(0.5, playCalls[1].volume)
            assert.are.same(pos, playCalls[1].pos)
        end)
    end)

end)
