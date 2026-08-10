require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local actions  = VFS.Include('luarules/mission_api/actions/custom.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.custom", function()

    it("declares its type and parameters", function()
        assert.are.same({
            type         = 'Custom',
            ['function'] = 'Function!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls the provided function", function()
            local called = false
            action.actionFunction(function() called = true end)
            assert.is_true(called)
        end)

        it("calls the function with no additional arguments", function()
            local args = nil
            action.actionFunction(function(...) args = { ... } end)
            assert.are.same({}, args)
        end)
    end)

end)
