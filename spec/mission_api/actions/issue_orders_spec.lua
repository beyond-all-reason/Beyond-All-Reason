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

-- Mock Loadout
GG['MissionAPI'].Modules.Loadout = {
    ConvertOrdersTargetingNames = function(orders) return orders end,
}

local actions  = VFS.Include('luarules/mission_api/actions/issue_orders.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function clearTracking()
    for k in pairs(trackedUnitIDs) do trackedUnitIDs[k] = nil end
end

local function seedUnit(name, id)
    trackedUnitIDs[name]       = trackedUnitIDs[name] or {}
    trackedUnitIDs[name][id]   = true
end

describe("mission_api.actions.issue_orders", function()

    before_each(function()
        clearTracking()
        Spring._giveOrderCalls = {}
        Spring.GiveOrderArrayToUnitMap = function(unitMap, orders)
            Spring._giveOrderCalls[#Spring._giveOrderCalls + 1] = { unitMap = unitMap, orders = orders }
        end
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
            seedUnit('bots', 101)
            seedUnit('bots', 102)
            local orders = { { 10, {}, {} } }
            action.actionFunction('bots', orders)
            assert.are.equal(1, #Spring._giveOrderCalls)
            assert.are.same(trackedUnitIDs['bots'], Spring._giveOrderCalls[1].unitMap)
        end)

        it("passes the result of ConvertOrdersTargetingNames as the orders", function()
            seedUnit('scout', 5)
            local convertedOrders = { { 999, {}, {} } }
            GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames = function(orders)
                return convertedOrders
            end
            action.actionFunction('scout', {})
            assert.are.same(convertedOrders, Spring._giveOrderCalls[1].orders)
        end)
    end)

end)
