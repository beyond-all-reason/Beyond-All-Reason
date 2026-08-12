require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

local actions  = VFS.Include('luarules/mission_api/actions/issue_orders.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

describe("mission_api.actions.issue_orders", function()

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type     = 'IssueOrders',
            unitName = 'UnitName!',
            orders   = 'Orders!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked unit name", function()
            action.actionFunction('unknownUnit', {})
            assert.are.equal(0, #Spring._giveOrderCalls)
        end)

        it("calls GiveOrderArrayToUnitMap with the tracked unit map and converted orders", function()
            seedUnits('bots', 101, 102)
            local orders = { { 10, {}, {} } }
            action.actionFunction('bots', orders)
            assert.are.equal(1, #Spring._giveOrderCalls)
            assert.are.same(missionApi.trackedUnitIDs['bots'], Spring._giveOrderCalls[1].unitMap)
        end)

        it("passes the result of ConvertOrdersTargetingNames as the orders", function()
            local convertedOrders = { { 999, {}, {} } }
            Builders.MissionApi.new()
                :WithTrackedUnit('scout', 5)
                :WithModule('Loadout', {
                    ConvertOrdersTargetingNames = function() return convertedOrders end,
                })
                :Install()
            action.actionFunction('scout', {})
            assert.are.same(convertedOrders, Spring._giveOrderCalls[1].orders)
        end)
    end)

end)
