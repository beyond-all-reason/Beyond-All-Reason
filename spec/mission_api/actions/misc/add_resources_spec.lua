require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local actions  = VFS.Include('luarules/mission_api/actions/resources/add_resources.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.add_resources", function()

    before_each(function()
        _G.Spring = Builders.Spring.new():Build()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type          = 'AddResources',
            teamID        = 'TeamID!',
            metal         = 'Number',
            energy        = 'Number',
            requiresOneOf = { 'metal', 'energy' },
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls AddTeamResource for positive metal", function()
            action.actionFunction(1, 200, nil)
            assert.are.equal(1, #Spring.calls.addTeamResource)
            assert.are.equal(1,       Spring.calls.addTeamResource[1].teamID)
            assert.are.equal('metal', Spring.calls.addTeamResource[1].resource)
            assert.are.equal(200,     Spring.calls.addTeamResource[1].amount)
        end)

        it("calls UseTeamResource for negative metal", function()
            action.actionFunction(1, -100, nil)
            assert.are.equal(1, #Spring.calls.useTeamResource)
            assert.are.equal(1,       Spring.calls.useTeamResource[1].teamID)
            assert.are.equal('metal', Spring.calls.useTeamResource[1].resource)
            assert.are.equal(100,     Spring.calls.useTeamResource[1].amount)
        end)

        it("skips metal when metal is nil", function()
            action.actionFunction(1, nil, 50)
            -- energy is added, but no metal call should be for 'metal' resource
            local metalAdded = false
            for _, c in ipairs(Spring.calls.addTeamResource) do
                if c.resource == 'metal' then metalAdded = true end
            end
            assert.is_false(metalAdded)
            -- energy was added
            assert.are.equal(1, #Spring.calls.addTeamResource)
            assert.are.equal('energy', Spring.calls.addTeamResource[1].resource)
        end)

        it("calls AddTeamResource for positive energy", function()
            action.actionFunction(2, nil, 500)
            assert.are.equal(1, #Spring.calls.addTeamResource)
            assert.are.equal(2,        Spring.calls.addTeamResource[1].teamID)
            assert.are.equal('energy', Spring.calls.addTeamResource[1].resource)
            assert.are.equal(500,      Spring.calls.addTeamResource[1].amount)
        end)

        it("calls UseTeamResource for negative energy", function()
            action.actionFunction(2, nil, -300)
            assert.are.equal(1, #Spring.calls.useTeamResource)
            assert.are.equal(2,        Spring.calls.useTeamResource[1].teamID)
            assert.are.equal('energy', Spring.calls.useTeamResource[1].resource)
            assert.are.equal(300,      Spring.calls.useTeamResource[1].amount)
        end)

        it("adds both metal and energy when both are positive", function()
            action.actionFunction(0, 100, 200)
            assert.are.equal(2, #Spring.calls.addTeamResource)
        end)

        it("does nothing for zero metal", function()
            action.actionFunction(0, 0, nil)
            assert.are.equal(0, #Spring.calls.addTeamResource)
            assert.are.equal(0, #Spring.calls.useTeamResource)
        end)

        it("does nothing for zero energy", function()
            action.actionFunction(0, nil, 0)
            assert.are.equal(0, #Spring.calls.addTeamResource)
            assert.are.equal(0, #Spring.calls.useTeamResource)
        end)
    end)

end)
