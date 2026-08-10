require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

local actions  = VFS.Include('luarules/mission_api/actions/draw_lines.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.draw_lines", function()

    before_each(function()
        Spring._lineCalls = {}
        Spring.MarkerAddLine = function(x1, y1, z1, x2, y2, z2, ...)
            Spring._lineCalls[#Spring._lineCalls + 1] = { x1=x1, y1=y1, z1=z1, x2=x2, y2=y2, z2=z2 }
        end
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type      = 'DrawLines',
            positions = 'Positions!',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("draws a single line between two positions", function()
            local positions = {
                { x = 0, y = 10, z = 0 },
                { x = 5, y = 10, z = 5 },
            }
            action.actionFunction(positions)
            assert.are.equal(1, #Spring._lineCalls)
            local l = Spring._lineCalls[1]
            assert.are.equal(0, l.x1)
            assert.are.equal(5, l.x2)
            assert.are.equal(5, l.z2)
        end)

        it("draws N-1 lines for N positions", function()
            local positions = {
                { x = 0, y = 0, z = 0 },
                { x = 1, y = 0, z = 0 },
                { x = 2, y = 0, z = 0 },
                { x = 3, y = 0, z = 0 },
            }
            action.actionFunction(positions)
            assert.are.equal(3, #Spring._lineCalls)
        end)

        it("connects consecutive positions in order", function()
            local positions = {
                { x = 10, y = 0, z = 10 },
                { x = 20, y = 0, z = 20 },
                { x = 30, y = 0, z = 30 },
            }
            action.actionFunction(positions)
            assert.are.equal(10, Spring._lineCalls[1].x1)
            assert.are.equal(20, Spring._lineCalls[1].x2)
            assert.are.equal(20, Spring._lineCalls[2].x1)
            assert.are.equal(30, Spring._lineCalls[2].x2)
        end)

        it("draws no lines for a single position", function()
            action.actionFunction({ { x = 0, y = 0, z = 0 } })
            assert.are.equal(0, #Spring._lineCalls)
        end)
    end)

end)
