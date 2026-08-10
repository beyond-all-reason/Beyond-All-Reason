require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local actions  = VFS.Include('luarules/mission_api/actions/send_message.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.send_message", function()

    it("declares its type and parameters", function()
        assert.are.same({
            type    = 'SendMessage',
            message = 'String!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is Spring.Echo", function()
            assert.are.equal(Spring.Echo, action.actionFunction)
        end)

        it("can be called without error", function()
            assert.has_no.errors(function()
                action.actionFunction('hello mission')
            end)
        end)
    end)

end)
