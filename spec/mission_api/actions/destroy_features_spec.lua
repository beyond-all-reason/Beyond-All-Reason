require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

-- Use a local table that we control directly for tracked IDs.
-- Mock Tracking so the action does not depend on the real module's upvalues.
local trackedFeatureIDs = {}
GG['MissionAPI'].trackedFeatureIDs = trackedFeatureIDs
GG['MissionAPI'].Modules.Tracking  = {
    IsFeatureNameUntracked = function(name) return trackedFeatureIDs[name] == nil end,
}

local actions  = VFS.Include('luarules/mission_api/actions/destroy_features.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function clearTracking()
    for k in pairs(trackedFeatureIDs) do trackedFeatureIDs[k] = nil end
end

local function seedFeature(name, id)
    trackedFeatureIDs[name]     = trackedFeatureIDs[name] or {}
    trackedFeatureIDs[name][id] = true
end

describe("mission_api.actions.destroy_features", function()

    before_each(function()
        clearTracking()
        Spring._destroyFeatureCalls = {}
        Spring.ValidFeatureID = function(id)
            return Spring._validFeatureIDs and Spring._validFeatureIDs[id] or false
        end
        Spring.DestroyFeature = function(id)
            Spring._destroyFeatureCalls[#Spring._destroyFeatureCalls + 1] = id
        end
        Spring._validFeatureIDs = {}
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
            assert.are.equal(0, #Spring._destroyFeatureCalls)
        end)

        it("destroys valid tracked features", function()
            seedFeature('rock', 10)
            seedFeature('rock', 11)
            Spring._validFeatureIDs = { [10] = true, [11] = true }
            action.actionFunction('rock')
            assert.are.equal(2, #Spring._destroyFeatureCalls)
        end)

        it("skips invalid feature IDs", function()
            seedFeature('rock', 10)
            Spring._validFeatureIDs = {}  -- 10 is not valid
            action.actionFunction('rock')
            assert.are.equal(0, #Spring._destroyFeatureCalls)
        end)

        it("only destroys features matching the given name", function()
            seedFeature('rock', 10)
            seedFeature('tree', 20)
            Spring._validFeatureIDs = { [10] = true, [20] = true }
            action.actionFunction('rock')
            assert.are.equal(1, #Spring._destroyFeatureCalls)
            assert.are.equal(10, Spring._destroyFeatureCalls[1])
        end)
    end)

end)
