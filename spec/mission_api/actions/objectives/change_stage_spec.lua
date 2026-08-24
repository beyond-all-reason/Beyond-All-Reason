require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/objectives/change_stage.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.change_stage", function()

    local changeStageCalls

    before_each(function()
        local missionApi = Builders.MissionApi.new():Install()
        changeStageCalls = missionApi.calls.changeStage
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
            assert.are.equal('stage2', changeStageCalls[1].stageID)
        end)

        it("passes the stageID unchanged", function()
            action.actionFunction('finalStage')
            assert.are.equal('finalStage', changeStageCalls[1].stageID)
        end)
    end)

end)
