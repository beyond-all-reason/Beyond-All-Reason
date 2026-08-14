require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

_G.UnitDefs = {}

local allActions   = VFS.Include('luarules/mission_api/actions/remove_units.lua')
local destroyAction    = allActions[1]
local selfDestructAction = allActions[2]
local reclaimAction    = allActions[3]
local despawnAction    = allActions[4]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

describe("mission_api.actions.remove_units", function()

    local destroyCalls, addResourceCalls

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
        -- These units are tracked by the Mission API, not registered as team
        -- units on the mock, so the team/def lookups have to be pinned here.
        Spring.GetUnitTeam  = function(id) return 0 end
        Spring.GetUnitDefID = function(id) return nil end
        destroyCalls     = Spring.calls.destroyUnit
        addResourceCalls = Spring.calls.addTeamResource
        _G.UnitDefs = {}
    end)

    it("declares its types and parameters", function()
        assert.are.same({
            type     = 'DestroyUnits',
            unitName = 'UnitName!',
        }, summarizeSchema(destroyAction))

        assert.are.same({
            type     = 'SelfDestructUnits',
            unitName = 'UnitName!',
        }, summarizeSchema(selfDestructAction))

        assert.are.same({
            type          = 'ReclaimUnits',
            unitName      = 'UnitName!',
            reclaimerTeam = 'TeamID',
        }, summarizeSchema(reclaimAction))

        assert.are.same({
            type     = 'DespawnUnits',
            unitName = 'UnitName!',
        }, summarizeSchema(despawnAction))
    end)

    describe("DestroyUnits actionFunction", function()
        it("is a no-op for an untracked name", function()
            destroyAction.actionFunction('ghost')
            assert.are.equal(0, #destroyCalls)
        end)

        it("calls DestroyUnit(id, false, false)", function()
            seedUnits('tank', 1)
            destroyAction.actionFunction('tank')
            assert.are.equal(1, #destroyCalls)
            assert.are.equal(1,     destroyCalls[1].unitID)
            assert.is_false(destroyCalls[1].selfDestruct)
            assert.is_false(destroyCalls[1].despawn)
        end)

        it("skips dead units", function()
            seedUnits('dead', 5)
            Spring.GetUnitIsDead = function(id) return true end
            destroyAction.actionFunction('dead')
            assert.are.equal(0, #destroyCalls)
        end)
    end)

    describe("SelfDestructUnits actionFunction", function()
        it("calls DestroyUnit(id, true, false)", function()
            seedUnits('bot', 2)
            selfDestructAction.actionFunction('bot')
            assert.are.equal(1, #destroyCalls)
            assert.is_true(destroyCalls[1].selfDestruct)
            assert.is_false(destroyCalls[1].despawn)
        end)
    end)

    describe("DespawnUnits actionFunction", function()
        it("calls DestroyUnit(id, false, true)", function()
            seedUnits('ghost', 3)
            despawnAction.actionFunction('ghost')
            assert.are.equal(1, #destroyCalls)
            assert.is_false(destroyCalls[1].selfDestruct)
            assert.is_true(destroyCalls[1].despawn)
        end)
    end)

    describe("ReclaimUnits actionFunction", function()
        it("adds metal from the unit's metalCost to the reclaimerTeam", function()
            seedUnits('miner', 10)
            _G.UnitDefs = { [7] = { metalCost = 150 } }
            Spring.GetUnitDefID = function(id) return 7 end
            reclaimAction.actionFunction('miner', 1)
            assert.are.equal(1, #addResourceCalls)
            assert.are.equal(1,       addResourceCalls[1].teamID)
            assert.are.equal('metal', addResourceCalls[1].resource)
            assert.are.equal(150,     addResourceCalls[1].amount)
        end)

        it("falls back to unit's own team when no reclaimerTeam is given", function()
            seedUnits('mine', 20)
            _G.UnitDefs = { [8] = { metalCost = 100 } }
            Spring.GetUnitDefID = function(id) return 8 end
            Spring.GetUnitTeam  = function(id) return 3 end
            reclaimAction.actionFunction('mine', nil)
            assert.are.equal(3, addResourceCalls[1].teamID)
        end)

        it("calls DestroyUnit(id, false, true)", function()
            seedUnits('reclaim', 30)
            Spring.GetUnitDefID = function(id) return nil end
            reclaimAction.actionFunction('reclaim', 0)
            assert.are.equal(1, #destroyCalls)
            assert.is_false(destroyCalls[1].selfDestruct)
            assert.is_true(destroyCalls[1].despawn)
        end)

        it("is a no-op for an untracked name", function()
            reclaimAction.actionFunction('ghost', 0)
            assert.are.equal(0, #addResourceCalls)
            assert.are.equal(0, #destroyCalls)
        end)
    end)

end)
