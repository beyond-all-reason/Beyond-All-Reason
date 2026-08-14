require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/erase_marker.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.erase_marker", function()

    local missionApi, eraseCalls

    before_each(function()
        missionApi = Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
        eraseCalls = Spring.calls.markerErasePosition
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type = 'EraseMarker',
            name = 'String!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls MarkerErasePosition at the stored position", function()
            missionApi.markerNames['flag'] = { x = 5, y = 10, z = 15 }
            action.actionFunction('flag')
            assert.are.equal(1, #eraseCalls)
            assert.are.equal(5,  eraseCalls[1].x)
            assert.are.equal(10, eraseCalls[1].y)
            assert.are.equal(15, eraseCalls[1].z)
        end)

        it("removes the name from markerNames after erasing", function()
            missionApi.markerNames['flag'] = { x = 0, y = 0, z = 0 }
            action.actionFunction('flag')
            assert.is_nil(missionApi.markerNames['flag'])
        end)

        it("is a no-op when the name is not in markerNames (no MarkerErasePosition call)", function()
            action.actionFunction('unknownMarker')
            assert.are.equal(0, #eraseCalls)
        end)

        it("still removes the name even if position was nil", function()
            -- name key exists, but value is nil - this shouldn't normally happen, but guard anyway
            action.actionFunction('ghost')
            assert.is_nil(missionApi.markerNames['ghost'])
        end)
    end)

end)
