require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/units/selfdestruct_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

describe("mission_api.actions.selfdestruct_units", function()

    local destroyCalls

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = Builders.Spring.new():Build()
        destroyCalls = Spring.calls.destroyUnit
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type     = 'SelfDestructUnits',
            unitName = 'UnitName!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked unit name", function()
            action.actionFunction('ghost')

            assert.are.equal(0, #destroyCalls)
        end)

        it("triggers the self-destruct explosion and leaves a wreck", function()
            seedUnits('bot', 2)

            action.actionFunction('bot')

            assert.are.equal(1, #destroyCalls)
            assert.are.equal(2, destroyCalls[1].unitID)
            assert.is_true(destroyCalls[1].selfd)
            assert.is_false(destroyCalls[1].reclaimed)
        end)

        it("self-destructs every unit tracked under the name", function()
            seedUnits('squad', 1, 2, 3)

            action.actionFunction('squad')

            assert.are.equal(3, #destroyCalls)
        end)

        it("skips dead units", function()
            seedUnits('dead', 5)
            Spring.GetUnitIsDead = function(unitID) return true end

            action.actionFunction('dead')

            assert.are.equal(0, #destroyCalls)
        end)

        it("only affects units tracked under the given name", function()
            Builders.MissionApi.new()
                :WithTrackedUnit('bots', 1)
                :WithTrackedUnit('tanks', 2)
                :Install()

            action.actionFunction('bots')

            assert.are.equal(1, #destroyCalls)
            assert.are.equal(1, destroyCalls[1].unitID)
        end)
    end)

end)
