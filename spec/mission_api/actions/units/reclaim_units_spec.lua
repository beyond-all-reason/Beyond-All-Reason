require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

_G.UnitDefs = {}

local actions  = VFS.Include('luarules/mission_api/actions/units/reclaim_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

describe("mission_api.actions.reclaim_units", function()

    local destroyCalls, addResourceCalls

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = Builders.Spring.new():Build()
        -- These units are tracked by the Mission API, not registered as team
        -- units on the mock, so the team/def lookups have to be pinned here.
        Spring.GetUnitTeam  = function(unitID) return 0 end
        Spring.GetUnitDefID = function(unitID) return 7 end
        _G.UnitDefs = { [7] = { metalCost = 150, energyCost = 900 } }
        destroyCalls     = Spring.calls.destroyUnit
        addResourceCalls = Spring.calls.addTeamResource
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type          = 'ReclaimUnits',
            unitName      = 'UnitName!',
            reclaimerTeam = 'TeamID',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked unit name", function()
            action.actionFunction('ghost', 0)

            assert.are.equal(0, #destroyCalls)
            assert.are.equal(0, #addResourceCalls)
        end)

        it("grants the unit's metalCost to the given reclaimerTeam", function()
            seedUnits('miner', 10)

            action.actionFunction('miner', 1)

            assert.are.equal(1, #addResourceCalls)
            assert.are.equal(1,       addResourceCalls[1].teamID)
            assert.are.equal('metal', addResourceCalls[1].resource)
            assert.are.equal(150,     addResourceCalls[1].amount)
        end)

        it("grants metal only, never energy", function()
            seedUnits('miner', 10)

            action.actionFunction('miner', 1)

            for _, call in ipairs(addResourceCalls) do
                assert.are.equal('metal', call.resource)
            end
        end)

        it("falls back to the unit's own team when no reclaimerTeam is given", function()
            seedUnits('mine', 20)
            Spring.GetUnitTeam = function(unitID) return 3 end

            action.actionFunction('mine', nil)

            assert.are.equal(1, #addResourceCalls)
            assert.are.equal(3, addResourceCalls[1].teamID)
        end)

        it("removes the unit silently, with no wreck", function()
            seedUnits('reclaim', 30)

            action.actionFunction('reclaim', 0)

            assert.are.equal(1, #destroyCalls)
            assert.are.equal(30, destroyCalls[1].unitID)
            assert.is_false(destroyCalls[1].selfd)
            assert.is_true(destroyCalls[1].reclaimed)
        end)

        it("reclaims every unit tracked under the name", function()
            seedUnits('squad', 1, 2, 3)

            action.actionFunction('squad', 0)

            assert.are.equal(3, #destroyCalls)
            assert.are.equal(3, #addResourceCalls)
        end)

        it("skips dead units", function()
            seedUnits('dead', 5)
            Spring.GetUnitIsDead = function(unitID) return true end

            action.actionFunction('dead', 0)

            assert.are.equal(0, #destroyCalls)
            assert.are.equal(0, #addResourceCalls)
        end)

        it("only affects units tracked under the given name", function()
            Builders.MissionApi.new()
                :WithTrackedUnit('miners', 1)
                :WithTrackedUnit('tanks', 2)
                :Install()

            action.actionFunction('miners', 0)

            assert.are.equal(1, #destroyCalls)
            assert.are.equal(1, destroyCalls[1].unitID)
        end)

        -- Carried over from the pre-split remove_units.lua: reclaimerTeam is
        -- assigned inside the loop, so the first unit's owner is reused for the
        -- rest instead of each unit crediting its own team. Asserting only that
        -- the teams match keeps this independent of pairs() ordering.
        it("credits every unit to one team when reclaimerTeam is omitted", function()
            seedUnits('mixed', 1, 2)
            Spring.GetUnitTeam = function(unitID) return unitID end

            action.actionFunction('mixed', nil)

            assert.are.equal(2, #addResourceCalls)
            assert.are.equal(addResourceCalls[1].teamID, addResourceCalls[2].teamID)
        end)
    end)

end)
