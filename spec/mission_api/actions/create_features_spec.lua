require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
GG['MissionAPI'].Modules.Loadout = { SpawnFeatureLoadout = function() end }

local actions  = VFS.Include('luarules/mission_api/actions/create_features.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.create_features", function()

    local spawnCalls

    before_each(function()
        spawnCalls = {}
        GG['MissionAPI'].Modules.Loadout.SpawnFeatureLoadout = function(loadout)
            spawnCalls[#spawnCalls + 1] = loadout
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type           = 'CreateFeatures',
            featureLoadout = 'FeatureLoadout!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Loadout.SpawnFeatureLoadout with the given loadout", function()
            local loadout = { { featureDefName = 'rock', x = 0, z = 0 } }
            action.actionFunction(loadout)
            assert.are.equal(1, #spawnCalls)
            assert.are.same(loadout, spawnCalls[1])
        end)
    end)

end)
