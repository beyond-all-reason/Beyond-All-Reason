require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/spawn_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

describe("mission_api.actions.spawn_units", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'SpawnUnits',
            unitLoadout = 'UnitLoadout!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Loadout.SpawnUnitLoadout with the given loadout", function()
            local loadout = { { unitDefName = 'armcom', x = 0, z = 0, teamName = 'alpha' } }
            action.actionFunction(loadout)
            assert.are.equal(1, #missionApi._spawnUnitCalls)
            assert.are.same(loadout, missionApi._spawnUnitCalls[1].loadout)
        end)
    end)

end)
