require("spec_helper")

local SpringSyncedBuilder = VFS.Include('spec/builders/spring_synced_builder.lua')
local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/unit_selectable.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function seedUnits(name, ...)
    local builder = Builders.MissionApi.new()
    for _, unitID in ipairs({ ... }) do
        builder:WithTrackedUnit(name, unitID)
    end
    builder:Install()
end

---@return table<number, boolean> unitID -> noSelect flag it was called with
local function noSelectByUnit()
    local byUnit = {}
    for _, call in ipairs(Spring.calls.setUnitNoSelect) do
        byUnit[call.unitID] = call.noSelect
    end
    return byUnit
end

describe("mission_api.actions.unit_selectable", function()

    before_each(function()
        Builders.MissionApi.new():Install()
        _G.Spring = SpringSyncedBuilder.new():Build()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type       = 'UnitSelectable',
            unitName   = 'UnitName!',
            selectable = 'Boolean!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op for an untracked unit name", function()
            action.actionFunction('unknownUnit', true)

            assert.are.equal(0, #Spring.calls.setUnitNoSelect)
        end)

        it("clears noSelect for every tracked unit when selectable is true", function()
            seedUnits('bots', 101, 102)

            action.actionFunction('bots', true)

            assert.are.equal(2, #Spring.calls.setUnitNoSelect)
            assert.are.same({ [101] = false, [102] = false }, noSelectByUnit())
        end)

        it("sets noSelect for every tracked unit when selectable is false", function()
            seedUnits('bots', 101, 102)

            action.actionFunction('bots', false)

            assert.are.equal(2, #Spring.calls.setUnitNoSelect)
            assert.are.same({ [101] = true, [102] = true }, noSelectByUnit())
        end)

        it("passes a unit ID rather than the tracked-ID table", function()
            seedUnits('scout', 5)

            action.actionFunction('scout', true)

            assert.are.equal(1, #Spring.calls.setUnitNoSelect)
            assert.are.equal(5, Spring.calls.setUnitNoSelect[1].unitID)
        end)

        it("only affects units tracked under the given name", function()
            Builders.MissionApi.new()
                :WithTrackedUnit('bots', 101)
                :WithTrackedUnit('tanks', 202)
                :Install()

            action.actionFunction('bots', false)

            assert.are.equal(1, #Spring.calls.setUnitNoSelect)
            assert.are.equal(101, Spring.calls.setUnitNoSelect[1].unitID)
        end)
    end)

end)
