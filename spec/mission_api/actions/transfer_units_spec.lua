require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

local actions  = VFS.Include('luarules/mission_api/actions/transfer_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

describe("mission_api.actions.transfer_units", function()

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
        -- No teams are registered on the mock, so pin ally teams explicitly.
        Spring.GetUnitAllyTeam   = function(id)     return 0 end
        Spring.GetTeamAllyTeamID = function(teamID) return 1 end  -- different ally team by default
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type     = 'TransferUnits',
            unitName = 'UnitName!',
            newTeam  = 'TeamID!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked unit name", function()
            action.actionFunction('ghost', 1)
            assert.are.equal(0, #Spring._transferCalls)
        end)

        it("calls Spring.TransferUnit for each tracked unit", function()
            seedUnits('bots', 10, 11)
            action.actionFunction('bots', 2)
            assert.are.equal(2, #Spring._transferCalls)
        end)

        it("passes given=true when the unit is already on the same ally team", function()
            seedUnits('scout', 5)
            Spring.GetUnitAllyTeam   = function(id)     return 1 end
            Spring.GetTeamAllyTeamID = function(teamID) return 1 end
            action.actionFunction('scout', 2)
            assert.is_true(Spring._transferCalls[1].given)
        end)

        it("passes given=false when the unit is on a different ally team", function()
            seedUnits('enemy', 6)
            Spring.GetUnitAllyTeam   = function(id)     return 0 end
            Spring.GetTeamAllyTeamID = function(teamID) return 1 end
            action.actionFunction('enemy', 3)
            assert.is_false(Spring._transferCalls[1].given)
        end)

        it("transfers to the correct newTeam", function()
            seedUnits('unit', 7)
            action.actionFunction('unit', 5)
            assert.are.equal(5, Spring._transferCalls[1].newTeam)
        end)
    end)

end)
