require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].markerNames = {}

local actions  = VFS.Include('luarules/mission_api/actions/erase_marker.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.erase_marker", function()

    before_each(function()
        for k in pairs(GG['MissionAPI'].markerNames) do
            GG['MissionAPI'].markerNames[k] = nil
        end
        Spring._eraseCalls = {}
        Spring.MarkerErasePosition = function(x, y, z, ...)
            Spring._eraseCalls[#Spring._eraseCalls + 1] = { x = x, y = y, z = z }
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type = 'EraseMarker',
            name = 'String!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls MarkerErasePosition at the stored position", function()
            GG['MissionAPI'].markerNames['flag'] = { x = 5, y = 10, z = 15 }
            action.actionFunction('flag')
            assert.are.equal(1, #Spring._eraseCalls)
            assert.are.equal(5,  Spring._eraseCalls[1].x)
            assert.are.equal(10, Spring._eraseCalls[1].y)
            assert.are.equal(15, Spring._eraseCalls[1].z)
        end)

        it("removes the name from markerNames after erasing", function()
            GG['MissionAPI'].markerNames['flag'] = { x = 0, y = 0, z = 0 }
            action.actionFunction('flag')
            assert.is_nil(GG['MissionAPI'].markerNames['flag'])
        end)

        it("is a no-op when the name is not in markerNames (no MarkerErasePosition call)", function()
            action.actionFunction('unknownMarker')
            assert.are.equal(0, #Spring._eraseCalls)
        end)

        it("still removes the name even if position was nil", function()
            -- name key exists, but value is nil - this shouldn't normally happen, but guard anyway
            action.actionFunction('ghost')
            assert.is_nil(GG['MissionAPI'].markerNames['ghost'])
        end)
    end)

end)
