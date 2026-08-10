require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Objectives = {}
GG['MissionAPI'].Modules.Objectives = {
    TryAdvanceStage   = function() end,
    EchoObjectiveUpdate = function() end,
}

local actions  = VFS.Include('luarules/mission_api/actions/update_objective.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function resetObjective(id, data)
    GG['MissionAPI'].Objectives[id] = data
end

describe("mission_api.actions.update_objective", function()

    local tryAdvanceCalls, echoCalls

    before_each(function()
        tryAdvanceCalls = {}
        echoCalls       = {}
        GG['MissionAPI'].Modules.Objectives.TryAdvanceStage = function(obj)
            tryAdvanceCalls[#tryAdvanceCalls + 1] = obj
        end
        GG['MissionAPI'].Modules.Objectives.EchoObjectiveUpdate = function(id, obj)
            echoCalls[#echoCalls + 1] = { id = id, obj = obj }
        end
        GG['MissionAPI'].Objectives = {}
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
            assert.are.equal(0, #tryAdvanceCalls)
            assert.are.equal(0, #echoCalls)
        end)

        it("sets completed=true when completed parameter is true", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', true, nil)
            assert.is_true(GG['MissionAPI'].Objectives['obj1'].completed)
        end)

        it("sets completed=false when completed parameter is false", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', false, nil)
            assert.is_false(GG['MissionAPI'].Objectives['obj1'].completed)
        end)

        it("updates the textKey when provided", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', nil, 'ui.objective.updated')
            assert.are.equal('ui.objective.updated', GG['MissionAPI'].Objectives['obj1'].textKey)
        end)

        it("increments progress when no completed or textKey is given", function()
            resetObjective('obj1', { completed = false, progress = 2, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.are.equal(3, GG['MissionAPI'].Objectives['obj1'].progress)
        end)

        it("sets completed when progress reaches amount", function()
            resetObjective('obj1', { completed = false, progress = 4, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.is_true(GG['MissionAPI'].Objectives['obj1'].completed)
        end)

        it("does not set completed when progress is below amount", function()
            resetObjective('obj1', { completed = false, progress = 1, amount = 5 })
            action.actionFunction('obj1', nil, nil)
            assert.is_false(GG['MissionAPI'].Objectives['obj1'].completed)
        end)

        it("sets completed when amount is nil (progress-less objective)", function()
            resetObjective('obj1', { completed = false, amount = nil })
            action.actionFunction('obj1', nil, nil)
            assert.is_true(GG['MissionAPI'].Objectives['obj1'].completed)
        end)

        it("calls TryAdvanceStage with the objective", function()
            resetObjective('obj1', { completed = false })
            action.actionFunction('obj1', true, nil)
            assert.are.equal(1, #tryAdvanceCalls)
        end)

        it("calls EchoObjectiveUpdate with the objectiveID and objective", function()
            resetObjective('obj2', { completed = false })
            action.actionFunction('obj2', true, nil)
            assert.are.equal(1, #echoCalls)
            assert.are.equal('obj2', echoCalls[1].id)
        end)
    end)

end)
