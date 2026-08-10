require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

-- Mock tracking and provide trackedUnitIDs directly.
local trackedUnitIDs = {}
GG['MissionAPI'].trackedUnitIDs   = trackedUnitIDs
GG['MissionAPI'].Modules.Tracking = {
    IsUnitNameUntracked = function(name) return trackedUnitIDs[name] == nil end,
}

_G.UnitDefs = {}
Spring.GetUnitIsDead  = function(id) return false end
Spring.GetUnitTeam    = function(id) return 0     end
Spring.GetUnitDefID   = function(id) return nil   end
Spring.AddTeamResource = function()  end
Spring.DestroyUnit    = function()   end

local allActions   = VFS.Include('luarules/mission_api/actions/remove_units.lua')
local destroyAction    = allActions[1]
local selfDestructAction = allActions[2]
local reclaimAction    = allActions[3]
local despawnAction    = allActions[4]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function clearTracking()
    for k in pairs(trackedUnitIDs) do trackedUnitIDs[k] = nil end
end

local function seedUnit(name, id)
    trackedUnitIDs[name]       = trackedUnitIDs[name] or {}
    trackedUnitIDs[name][id]   = true
end

describe("mission_api.actions.remove_units", function()

    before_each(function()
        clearTracking()
        Spring._destroyCalls   = {}
        Spring._addResCalls    = {}
        Spring.GetUnitIsDead   = function(id) return false end
        Spring.GetUnitTeam     = function(id) return 0     end
        Spring.GetUnitDefID    = function(id) return nil   end
        Spring.AddTeamResource = function(teamID, resource, amount)
            Spring._addResCalls[#Spring._addResCalls + 1] = { teamID=teamID, resource=resource, amount=amount }
        end
        Spring.DestroyUnit = function(id, selfDestruct, despawn)
            Spring._destroyCalls[#Spring._destroyCalls + 1] = { id=id, selfDestruct=selfDestruct, despawn=despawn }
        end
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
            assert.are.equal(0, #Spring._destroyCalls)
        end)

        it("calls DestroyUnit(id, false, false)", function()
            seedUnit('tank', 1)
            destroyAction.actionFunction('tank')
            assert.are.equal(1, #Spring._destroyCalls)
            assert.are.equal(1,     Spring._destroyCalls[1].id)
            assert.is_false(Spring._destroyCalls[1].selfDestruct)
            assert.is_false(Spring._destroyCalls[1].despawn)
        end)

        it("skips dead units", function()
            seedUnit('dead', 5)
            Spring.GetUnitIsDead = function(id) return true end
            destroyAction.actionFunction('dead')
            assert.are.equal(0, #Spring._destroyCalls)
        end)
    end)

    describe("SelfDestructUnits actionFunction", function()
        it("calls DestroyUnit(id, true, false)", function()
            seedUnit('bot', 2)
            selfDestructAction.actionFunction('bot')
            assert.are.equal(1, #Spring._destroyCalls)
            assert.is_true(Spring._destroyCalls[1].selfDestruct)
            assert.is_false(Spring._destroyCalls[1].despawn)
        end)
    end)

    describe("DespawnUnits actionFunction", function()
        it("calls DestroyUnit(id, false, true)", function()
            seedUnit('ghost', 3)
            despawnAction.actionFunction('ghost')
            assert.are.equal(1, #Spring._destroyCalls)
            assert.is_false(Spring._destroyCalls[1].selfDestruct)
            assert.is_true(Spring._destroyCalls[1].despawn)
        end)
    end)

    describe("ReclaimUnits actionFunction", function()
        it("adds metal from the unit's metalCost to the reclaimerTeam", function()
            seedUnit('miner', 10)
            _G.UnitDefs = { [7] = { metalCost = 150 } }
            Spring.GetUnitDefID = function(id) return 7 end
            reclaimAction.actionFunction('miner', 1)
            assert.are.equal(1, #Spring._addResCalls)
            assert.are.equal(1,       Spring._addResCalls[1].teamID)
            assert.are.equal('metal', Spring._addResCalls[1].resource)
            assert.are.equal(150,     Spring._addResCalls[1].amount)
        end)

        it("falls back to unit's own team when no reclaimerTeam is given", function()
            seedUnit('mine', 20)
            _G.UnitDefs = { [8] = { metalCost = 100 } }
            Spring.GetUnitDefID = function(id) return 8 end
            Spring.GetUnitTeam  = function(id) return 3 end
            reclaimAction.actionFunction('mine', nil)
            assert.are.equal(3, Spring._addResCalls[1].teamID)
        end)

        it("calls DestroyUnit(id, false, true)", function()
            seedUnit('reclaim', 30)
            Spring.GetUnitDefID = function(id) return nil end
            reclaimAction.actionFunction('reclaim', 0)
            assert.are.equal(1, #Spring._destroyCalls)
            assert.is_false(Spring._destroyCalls[1].selfDestruct)
            assert.is_true(Spring._destroyCalls[1].despawn)
        end)

        it("is a no-op for an untracked name", function()
            reclaimAction.actionFunction('ghost', 0)
            assert.are.equal(0, #Spring._addResCalls)
            assert.are.equal(0, #Spring._destroyCalls)
        end)
    end)

end)
