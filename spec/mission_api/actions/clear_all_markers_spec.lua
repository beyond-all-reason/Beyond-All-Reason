require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].markerNames = {}

Spring.SendCommands = Spring.SendCommands or function() end

local actions  = VFS.Include('luarules/mission_api/actions/clear_all_markers.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.clear_all_markers", function()

    before_each(function()
        -- seed some markers
        GG['MissionAPI'].markerNames['a'] = { x = 1, y = 0, z = 1 }
        GG['MissionAPI'].markerNames['b'] = { x = 2, y = 0, z = 2 }

        Spring._sendCommandsCalls = {}
        Spring.SendCommands = function(cmd)
            Spring._sendCommandsCalls[#Spring._sendCommandsCalls + 1] = cmd
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({ type = 'ClearAllMarkers' }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("resets markerNames to an empty table", function()
            action.actionFunction()
            assert.are.same({}, GG['MissionAPI'].markerNames)
        end)

        it("calls Spring.SendCommands('clearmapmarks')", function()
            action.actionFunction()
            assert.are.equal(1, #Spring._sendCommandsCalls)
            assert.are.equal('clearmapmarks', Spring._sendCommandsCalls[1])
        end)
    end)

end)
