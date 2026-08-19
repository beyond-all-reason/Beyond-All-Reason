require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Triggers = {}

local disableActions = VFS.Include('luarules/mission_api/actions/misc/disable_trigger.lua')
local enableActions  = VFS.Include('luarules/mission_api/actions/misc/enable_trigger.lua')
local disableAction  = disableActions[1]
local enableAction   = enableActions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.disable_trigger", function()

    before_each(function()
        GG['MissionAPI'].Triggers['t1'] = { settings = { active = true } }
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type      = 'DisableTrigger',
            triggerID = 'TriggerID!',
        }, summarizeSchema(disableAction))
    end)

    describe("actionFunction", function()
        it("sets trigger active to false", function()
            disableAction.actionFunction('t1')
            assert.is_false(GG['MissionAPI'].Triggers['t1'].settings.active)
        end)
    end)

end)

describe("mission_api.actions.enable_trigger", function()

    before_each(function()
        GG['MissionAPI'].Triggers['t2'] = { settings = { active = false } }
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type      = 'EnableTrigger',
            triggerID = 'TriggerID!',
        }, summarizeSchema(enableAction))
    end)

    describe("actionFunction", function()
        it("sets trigger active to true", function()
            enableAction.actionFunction('t2')
            assert.is_true(GG['MissionAPI'].Triggers['t2'].settings.active)
        end)
    end)

end)
