require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local actions  = VFS.Include('luarules/mission_api/actions/game/victory.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.victory", function()

    before_each(function()
        _G.Spring = Builders.Spring.new():Build()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'Victory',
            allyTeamIDs = 'AllyTeamIDs!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Spring.GameOver with the given allyTeamIDs", function()
            action.actionFunction({ 0 })
            assert.are.equal(1, #Spring.calls.gameOver)
            assert.are.same({ 0 }, Spring.calls.gameOver[1])
        end)

        it("passes multiple winning ally teams", function()
            action.actionFunction({ 0, 2 })
            assert.are.equal(2, #Spring.calls.gameOver[1])
        end)

        it("passes an empty list when no winners are provided", function()
            action.actionFunction({})
            assert.are.equal(0, #Spring.calls.gameOver[1])
        end)
    end)

end)
