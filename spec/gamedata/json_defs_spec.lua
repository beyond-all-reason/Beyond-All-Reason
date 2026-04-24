describe('JSON definition file loading', function()

    local json

    setup(function()
        json = VFS.Include('common/luaUtilities/json.lua')
    end)

    -- Helper: read a JSON file and decode it
    local function loadJsonFile(path)
        local f = io.open(path, 'r')
        assert.is_truthy(f, 'Could not open ' .. path)
        local content = f:read('*a')
        f:close()
        return json.decode(content)
    end

    describe('json_loader module', function()
        local jsonLoader

        setup(function()
            jsonLoader = VFS.Include('gamedata/json_loader.lua')
        end)

        it('should return a table with loadJsonDefs function', function()
            assert.is_table(jsonLoader)
            assert.is_function(jsonLoader.loadJsonDefs)
        end)
    end)

    describe('unit def parity: armck', function()
        local defs

        setup(function()
            defs = loadJsonFile('units/ArmBots/armck.json')
        end)

        it('should contain the armck definition', function()
            assert.is_table(defs)
            assert.is_table(defs.armck)
        end)

        it('should have correct scalar properties', function()
            local u = defs.armck
            assert.are.equal(130, u.builddistance)
            assert.is_true(u.builder)
            assert.are.equal('ARMCK.DDS', u.buildpic)
            assert.are.equal(3450, u.buildtime)
            assert.are.equal(690, u.health)
            assert.are.equal(110, u.metalcost)
            assert.are.equal(1600, u.energycost)
            assert.are.equal(36, u.speed)
            assert.are.equal('BOT2', u.movementclass)
            assert.are.equal('Units/ARMCK.s3o', u.objectname)
        end)

        it('should have buildoptions as an array', function()
            local bo = defs.armck.buildoptions
            assert.is_table(bo)
            assert.are.equal(30, #bo)
            assert.are.equal('armsolar', bo[1])
            assert.are.equal('armsy', bo[30])
        end)

        it('should have customparams as a table', function()
            local cp = defs.armck.customparams
            assert.is_table(cp)
            assert.are.equal('Kaiser', cp.model_author)
            assert.are.equal('ArmBots', cp.subfolder)
            assert.are.equal('builder', cp.unitgroup)
        end)

        it('should have featuredefs with dead and heap', function()
            local fd = defs.armck.featuredefs
            assert.is_table(fd)
            assert.is_table(fd.dead)
            assert.is_table(fd.heap)
            assert.are.equal(424, fd.dead.damage)
            assert.are.equal(66, fd.dead.metal)
            assert.are.equal(262, fd.heap.damage)
        end)

        it('should have sounds with arrays', function()
            local s = defs.armck.sounds
            assert.is_table(s)
            assert.are.equal('nanlath1', s.build)
            assert.are.equal('cancel2', s.canceldestruct)
            assert.is_table(s.count)
            assert.are.equal(6, #s.count)
            assert.are.equal('count6', s.count[1])
            assert.are.equal('count1', s.count[6])
        end)
    end)

    describe('unit def parity: corraid', function()
        local defs

        setup(function()
            defs = loadJsonFile('units/CorVehicles/corraid.json')
        end)

        it('should contain the corraid definition', function()
            assert.is_table(defs)
            assert.is_table(defs.corraid)
        end)

        it('should have correct scalar properties', function()
            local u = defs.corraid
            assert.are.equal(1970, u.health)
            assert.are.equal(235, u.metalcost)
            assert.are.equal(72.9, u.speed)
            assert.are.equal('TANK3', u.movementclass)
            assert.is_true(u.leavetracks)
        end)

        it('should have inline weapondefs', function()
            local wd = defs.corraid.weapondefs
            assert.is_table(wd)
            assert.is_table(wd.arm_lightcannon)
            assert.are.equal('LightCannon', wd.arm_lightcannon.name)
            assert.are.equal(350, wd.arm_lightcannon.range)
            assert.are.equal(97, wd.arm_lightcannon.damage.default)
        end)

        it('should have weapons as an array', function()
            local w = defs.corraid.weapons
            assert.is_table(w)
            assert.are.equal(1, #w)
            assert.are.equal('ARM_LIGHTCANNON', w[1].def)
        end)

        it('should have sfxtypes with explosiongenerators array', function()
            local sfx = defs.corraid.sfxtypes
            assert.is_table(sfx)
            assert.is_table(sfx.explosiongenerators)
            assert.are.equal(1, #sfx.explosiongenerators)
            assert.are.equal('custom:barrelshot-small', sfx.explosiongenerators[1])
        end)
    end)

    describe('weapon def parity: noweapon', function()
        local defs

        setup(function()
            defs = loadJsonFile('weapons/noweapon.json')
        end)

        it('should contain the noweapon definition', function()
            assert.is_table(defs)
            assert.is_table(defs.noweapon)
            assert.are.equal(0, defs.noweapon.range)
            assert.are.equal(0, defs.noweapon.damage.default)
        end)
    end)

    describe('weapon def parity: mine_light', function()
        local defs

        setup(function()
            defs = loadJsonFile('weapons/mine_light.json')
        end)

        it('should contain the mine_light definition', function()
            assert.is_table(defs)
            assert.is_table(defs.mine_light)
        end)

        it('should have correct weapon properties', function()
            local w = defs.mine_light
            assert.are.equal(200, w.areaofeffect)
            assert.are.equal('LightMine', w.name)
            assert.are.equal(480, w.range)
            assert.are.equal(250, w.weaponvelocity)
        end)

        it('should have damage table with armor classes', function()
            local d = defs.mine_light.damage
            assert.is_table(d)
            assert.are.equal(445, d.default)
            assert.are.equal(1, d.mines)
        end)
    end)

    describe('feature def parity: xmascomwreck', function()
        local defs

        setup(function()
            defs = loadJsonFile('features/xmascomwreck.json')
        end)

        it('should contain both definitions', function()
            assert.is_table(defs)
            assert.is_table(defs.xmascomwreck)
            assert.is_table(defs.heap)
        end)

        it('should have correct xmascomwreck properties', function()
            local x = defs.xmascomwreck
            assert.is_true(x.blocking)
            assert.are.equal(10000, x.damage)
            assert.are.equal('Xmas Commander Wreckage', x.description)
            assert.are.equal(1250, x.metal)
            assert.are.equal('gingerbread.s3o', x.object)
        end)

        it('should have correct heap properties', function()
            local h = defs.heap
            assert.is_false(h.blocking)
            assert.are.equal(5000, h.damage)
            assert.are.equal(500, h.metal)
            assert.are.equal(0, h.resurrectable)
        end)
    end)
end)
