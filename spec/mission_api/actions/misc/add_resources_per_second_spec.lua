require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

-- Mock the helper that the action delegates to
GG['MissionAPIActionHelper'] = {
    addMetalPerSecond  = function() end,
    addEnergyPerSecond = function() end,
}

local actions  = VFS.Include('luarules/mission_api/actions/resources/add_resources_per_second.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.add_resources_per_second", function()

    local metalCalls, energyCalls

    before_each(function()
        metalCalls  = {}
        energyCalls = {}
        GG['MissionAPIActionHelper'].addMetalPerSecond = function(teamID, amount)
            metalCalls[#metalCalls + 1] = { teamID = teamID, amount = amount }
        end
        GG['MissionAPIActionHelper'].addEnergyPerSecond = function(teamID, amount)
            energyCalls[#energyCalls + 1] = { teamID = teamID, amount = amount }
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type          = 'AddResourcesPerSecond',
            teamID        = 'TeamID!',
            metal         = 'Number',
            energy        = 'Number',
            requiresOneOf = { 'metal', 'energy' },
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls addMetalPerSecond with teamID and amount", function()
            action.actionFunction(1, 5, nil)
            assert.are.equal(1, #metalCalls)
            assert.are.equal(1, metalCalls[1].teamID)
            assert.are.equal(5, metalCalls[1].amount)
        end)

        it("skips addMetalPerSecond when metal is nil", function()
            action.actionFunction(1, nil, 10)
            assert.are.equal(0, #metalCalls)
        end)

        it("calls addEnergyPerSecond with teamID and amount", function()
            action.actionFunction(2, nil, 20)
            assert.are.equal(1, #energyCalls)
            assert.are.equal(2,  energyCalls[1].teamID)
            assert.are.equal(20, energyCalls[1].amount)
        end)

        it("skips addEnergyPerSecond when energy is nil", function()
            action.actionFunction(1, 5, nil)
            assert.are.equal(0, #energyCalls)
        end)

        it("calls both helpers when both values are provided", function()
            action.actionFunction(3, 7, 11)
            assert.are.equal(1, #metalCalls)
            assert.are.equal(1, #energyCalls)
        end)
    end)

end)
