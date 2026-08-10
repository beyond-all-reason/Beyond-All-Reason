require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.WeaponDefNames = {}
Spring.SpawnExplosion = function() end

local actions  = VFS.Include('luarules/mission_api/actions/spawn_explosion.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.spawn_explosion", function()

    before_each(function()
        Spring._explosionCalls = {}
        Spring.SpawnExplosion = function(x, y, z, dx, dy, dz, params)
            Spring._explosionCalls[#Spring._explosionCalls + 1] = {
                x=x, y=y, z=z, dx=dx, dy=dy, dz=dz, params=params
            }
        end
        _G.WeaponDefNames = {
            bomb = {
                id = 42,
                damages = { [0] = 500 },
                craterAreaOfEffect = 10,
                damageAreaOfEffect = 20,
                edgeEffectiveness  = 0.5,
                explosionSpeed     = 100,
                impactOnly         = false,
                noSelfDamage       = true,
            }
        }
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type          = 'SpawnExplosion',
            weaponDefName = 'WeaponDefName!',
            position      = 'Position!',
            direction     = 'Position',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("calls Spring.SpawnExplosion at the given position", function()
            action.actionFunction('bomb', { x = 10, y = 20, z = 30 }, nil)
            assert.are.equal(1, #Spring._explosionCalls)
            local c = Spring._explosionCalls[1]
            assert.are.equal(10, c.x)
            assert.are.equal(20, c.y)
            assert.are.equal(30, c.z)
        end)

        it("uses zero direction when direction is nil", function()
            action.actionFunction('bomb', { x = 0, y = 0, z = 0 }, nil)
            local c = Spring._explosionCalls[1]
            assert.are.equal(0, c.dx)
            assert.are.equal(0, c.dy)
            assert.are.equal(0, c.dz)
        end)

        it("uses the given direction", function()
            action.actionFunction('bomb', { x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 })
            local c = Spring._explosionCalls[1]
            assert.are.equal(1, c.dx)
            assert.are.equal(0, c.dy)
            assert.are.equal(0, c.dz)
        end)

        it("passes the weaponDef id in the params table", function()
            action.actionFunction('bomb', { x = 0, y = 0, z = 0 }, nil)
            assert.are.equal(42, Spring._explosionCalls[1].params.weaponDef)
        end)
    end)

end)
