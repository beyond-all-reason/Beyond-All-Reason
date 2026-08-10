require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].markerNames = {}

local actions  = VFS.Include('luarules/mission_api/actions/add_marker.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.add_marker", function()

    before_each(function()
        -- reset shared state and Spring spy
        for k in pairs(GG['MissionAPI'].markerNames) do
            GG['MissionAPI'].markerNames[k] = nil
        end
        Spring._markerCalls = {}
        Spring.MarkerAddPoint = function(x, y, z, label, local_)
            Spring._markerCalls[#Spring._markerCalls + 1] = { x = x, y = y, z = z, label = label, local_ = local_ }
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type     = 'AddMarker',
            position = 'Position!',
            label    = 'String',
            name     = 'String',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Spring.MarkerAddPoint with the given position and label", function()
            action.actionFunction({ x = 10, y = 20, z = 30 }, 'hello', nil)
            assert.are.equal(1, #Spring._markerCalls)
            assert.are.equal(10,      Spring._markerCalls[1].x)
            assert.are.equal(20,      Spring._markerCalls[1].y)
            assert.are.equal(30,      Spring._markerCalls[1].z)
            assert.are.equal('hello', Spring._markerCalls[1].label)
        end)

        it("stores the position in markerNames when a name is given", function()
            local pos = { x = 1, y = 2, z = 3 }
            action.actionFunction(pos, 'label', 'myMarker')
            assert.are.same(pos, GG['MissionAPI'].markerNames['myMarker'])
        end)

        it("does not store anything in markerNames when name is nil", function()
            action.actionFunction({ x = 0, y = 0, z = 0 }, 'label', nil)
            assert.are.same({}, GG['MissionAPI'].markerNames)
        end)

        it("passes false as the local flag to MarkerAddPoint", function()
            action.actionFunction({ x = 0, y = 0, z = 0 }, nil, nil)
            assert.is_false(Spring._markerCalls[1].local_)
        end)
    end)

end)
