require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Modules.Loadout = { SpawnUnitLoadout = function() end }

local actions  = VFS.Include('luarules/mission_api/actions/spawn_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.spawn_units", function()

    local spawnCalls

    before_each(function()
        spawnCalls = {}
        GG['MissionAPI'].Modules.Loadout.SpawnUnitLoadout = function(loadout)
            spawnCalls[#spawnCalls + 1] = loadout
        end
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
            assert.are.equal(1, #spawnCalls)
            assert.are.same(loadout, spawnCalls[1])
        end)
    end)

end)
