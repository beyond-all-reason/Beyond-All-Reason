require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/destroy_features.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

---Track the given `name -> featureID` pairs, and mark those IDs valid.
local function seedFeatures(name, ...)
    local missionApi = Builders.MissionApi.new()
    local spring = SpringSyncedBuilder.new()
    for _, featureID in ipairs({ ... }) do
        missionApi:WithTrackedFeature(name, featureID)
        spring:WithValidFeature(featureID)
    end
    missionApi:Install()
    _G.Spring = spring:Build()
    return Spring.calls.destroyFeature
end

describe("mission_api.actions.destroy_features", function()

    local destroyFeatureCalls

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
        destroyFeatureCalls = Spring.calls.destroyFeature
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'DestroyFeatures',
            featureName = 'FeatureName!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked feature name", function()
            action.actionFunction('unknown')
            assert.are.equal(0, #destroyFeatureCalls)
        end)

        it("destroys valid tracked features", function()
            destroyFeatureCalls = seedFeatures('rock', 10, 11)
            action.actionFunction('rock')
            assert.are.equal(2, #destroyFeatureCalls)
        end)

        it("skips invalid feature IDs", function()
            -- tracked, but never marked valid
            Builders.MissionApi.new():WithTrackedFeature('rock', 10):Install()
            _G.Spring = SpringSyncedBuilder.new():Build()

            action.actionFunction('rock')

            assert.are.equal(0, #Spring.calls.destroyFeature)
        end)

        it("only destroys features matching the given name", function()
            Builders.MissionApi.new()
                :WithTrackedFeature('rock', 10)
                :WithTrackedFeature('tree', 20)
                :Install()
            _G.Spring = SpringSyncedBuilder.new()
                :WithValidFeature(10)
                :WithValidFeature(20)
                :Build()

            action.actionFunction('rock')

            assert.are.equal(1, #Spring.calls.destroyFeature)
            assert.are.equal(10, Spring.calls.destroyFeature[1])
        end)
    end)

end)
