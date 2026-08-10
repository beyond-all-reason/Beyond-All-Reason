require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Modules.Objectives = { ChangeStage = function() end }

local actions  = VFS.Include('luarules/mission_api/actions/change_stage.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.change_stage", function()

    local changeStageCalls

    before_each(function()
        changeStageCalls = {}
        GG['MissionAPI'].Modules.Objectives.ChangeStage = function(stageID)
            changeStageCalls[#changeStageCalls + 1] = stageID
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type    = 'ChangeStage',
            stageID = 'StageID!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Objectives.ChangeStage with the given stageID", function()
            action.actionFunction('stage2')
            assert.are.equal(1, #changeStageCalls)
            assert.are.equal('stage2', changeStageCalls[1])
        end)

        it("passes the stageID unchanged", function()
            action.actionFunction('finalStage')
            assert.are.equal('finalStage', changeStageCalls[1])
        end)
    end)

end)
