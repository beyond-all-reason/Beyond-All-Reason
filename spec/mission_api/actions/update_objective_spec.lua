require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/update_objective.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

local function resetObjective(id, data)
    Builders.MissionApi.new():WithObjective(id, data):Install()
end

describe("mission_api.actions.update_objective", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'UpdateObjective',
            objectiveID = 'ObjectiveID!',
            completed   = 'Boolean',
            textKey     = 'String',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op when the objective is already completed", function()
            resetObjective('obj1', { completed = true, progress = 0 })
            action.actionFunction('obj1', nil, nil)
            assert.are.equal(0, #missionApi.calls.tryAdvanceStage)
            assert.are.equal(0, #missionApi.calls.echoObjectiveUpdate)
        end)

        it("sets completed=true when completed parameter is true", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', true, nil)
            assert.is_true(missionApi.Objectives['obj1'].completed)
        end)

        it("sets completed=false when completed parameter is false", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', false, nil)
            assert.is_false(missionApi.Objectives['obj1'].completed)
        end)

        it("updates the textKey when provided", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', nil, 'ui.objective.updated')
            assert.are.equal('ui.objective.updated', missionApi.Objectives['obj1'].textKey)
        end)

        it("increments progress when no completed or textKey is given", function()
            resetObjective('obj1', { completed = false, progress = 2, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.are.equal(3, missionApi.Objectives['obj1'].progress)
        end)

        it("sets completed when progress reaches amount", function()
            resetObjective('obj1', { completed = false, progress = 4, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.is_true(missionApi.Objectives['obj1'].completed)
        end)

        it("does not set completed when progress is below amount", function()
            resetObjective('obj1', { completed = false, progress = 1, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.is_false(missionApi.Objectives['obj1'].completed)
        end)

        it("sets completed when amount is nil (progress-less objective)", function()
            resetObjective('obj1', { completed = false, amount = nil })
            action.actionFunction('obj1', nil, nil)
            assert.is_true(missionApi.Objectives['obj1'].completed)
        end)

        it("calls TryAdvanceStage with the objective", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', true, nil)
            assert.are.equal(1, #missionApi.calls.tryAdvanceStage)
        end)

        it("calls EchoObjectiveUpdate with the objectiveID and objective", function()
            resetObjective('obj2', { completed = false })
            action.actionFunction('obj2', true, nil)
            assert.are.equal(1, #missionApi.calls.echoObjectiveUpdate)
            assert.are.equal('obj2', missionApi.calls.echoObjectiveUpdate[1].objectiveID)
        end)
    end)

end)
