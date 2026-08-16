local Builders = VFS.Include("spec/builders/index.lua")

describe("SpringSyncedBuilder", function()
    it("should build spring mocks with teams", function()
        local team1 = Builders.Team.new():WithUnit("armcom")
        local team2 = Builders.Team.new():WithUnit("corcom"):AI()
        local spring = Builders.Spring.new()
            :WithTeam(team1)
            :WithTeam(team2)
            :WithAlliance(team1.id, team2.id, true)
            :Build()

        assert.is_table(spring)

        assert.is_true(spring.AreTeamsAllied(team1.id, team2.id))

        local teamUnits = spring.GetTeamUnits(team1.id)
        assert.is_not_nil(teamUnits)
        ---@cast teamUnits number[]
        assert.are.equal(1, #teamUnits)
    end)

    it("should integrate real unit definitions", function()
        local teamBuilder = Builders.Team.new():WithUnit("armacv")
        local spring = Builders.Spring.new()
            :WithRealUnitDefs()
            :WithTeam(teamBuilder)
            :Build()

        local teamUnits = spring.GetTeamUnits(teamBuilder.id)
        assert.is_not_nil(teamUnits)
        ---@cast teamUnits number[]
        assert.are.equal(1, #teamUnits)
        local unitId = teamUnits[1]
        local unitDefId = spring.GetUnitDefID(unitId)
        assert.are.equal("armacv", unitDefId)

        local unitDef = spring.GetUnitDefs()[unitDefId]
        assert.are.equal(unitDef.customparams.techlevel, 2)
    end)

    describe("resource calls", function()
        it("records AddTeamResource calls and updates team stores", function()
            local team = Builders.Team.new():WithMetal(1000):WithEnergy(1000)
            local spring = Builders.Spring.new():WithTeam(team):Build()

            spring.AddTeamResource(team.id, "metal", 200)
            spring.AddTeamResource(team.id, "energy", 500)

            assert.are.equal(2, #spring.calls.addTeamResource)
            assert.are.equal(team.id,  spring.calls.addTeamResource[1].teamID)
            assert.are.equal("metal",  spring.calls.addTeamResource[1].resource)
            assert.are.equal(200,      spring.calls.addTeamResource[1].amount)
            assert.are.equal("energy", spring.calls.addTeamResource[2].resource)
            assert.are.equal(500,      spring.calls.addTeamResource[2].amount)

            assert.are.equal(1200, spring.builtTeams[team.id].metal.current)
            assert.are.equal(1500, spring.builtTeams[team.id].energy.current)
        end)

        it("records UseTeamResource calls and subtracts from team stores", function()
            local team = Builders.Team.new():WithMetal(1000):WithEnergy(1000)
            local spring = Builders.Spring.new():WithTeam(team):Build()

            spring.UseTeamResource(team.id, "metal", 100)
            spring.UseTeamResource(team.id, "energy", 300)

            assert.are.equal(2, #spring.calls.useTeamResource)
            assert.are.equal(team.id,  spring.calls.useTeamResource[1].teamID)
            assert.are.equal("metal",  spring.calls.useTeamResource[1].resource)
            assert.are.equal(100,      spring.calls.useTeamResource[1].amount)
            assert.are.equal("energy", spring.calls.useTeamResource[2].resource)
            assert.are.equal(300,      spring.calls.useTeamResource[2].amount)

            assert.are.equal(900, spring.builtTeams[team.id].metal.current)
            assert.are.equal(700, spring.builtTeams[team.id].energy.current)
        end)

        it("keeps add and use call lists independent", function()
            local team = Builders.Team.new()
            local spring = Builders.Spring.new():WithTeam(team):Build()

            spring.AddTeamResource(team.id, "metal", 10)

            assert.are.equal(1, #spring.calls.addTeamResource)
            assert.are.equal(0, #spring.calls.useTeamResource)
        end)

        it("records calls for teams that were never registered", function()
            local spring = Builders.Spring.new():Build()

            spring.AddTeamResource(42, "metal", 10)
            spring.UseTeamResource(42, "energy", 20)

            assert.are.equal(1, #spring.calls.addTeamResource)
            assert.are.equal(42, spring.calls.addTeamResource[1].teamID)
            assert.are.equal(1, #spring.calls.useTeamResource)
            assert.are.equal(42, spring.calls.useTeamResource[1].teamID)
        end)

        it("clears tracked calls via clearResourceCalls", function()
            local spring = Builders.Spring.new():Build()
            spring.AddTeamResource(0, "metal", 10)
            spring.UseTeamResource(0, "metal", 5)

            spring.clearResourceCalls()

            assert.are.equal(0, #spring.calls.addTeamResource)
            assert.are.equal(0, #spring.calls.useTeamResource)
        end)

        it("returns success and the amount", function()
            local spring = Builders.Spring.new():Build()

            local okAdd, addedAmount = spring.AddTeamResource(0, "metal", 25)
            local okUse, usedAmount  = spring.UseTeamResource(0, "metal", 15)

            assert.is_true(okAdd)
            assert.are.equal(25, addedAmount)
            assert.is_true(okUse)
            assert.are.equal(15, usedAmount)
        end)

        it("gives each built mock its own call tracking tables", function()
            local springA = Builders.Spring.new():Build()
            local springB = Builders.Spring.new():Build()

            springA.AddTeamResource(0, "metal", 10)

            assert.are.equal(1, #springA.calls.addTeamResource)
            assert.are.equal(0, #springB.calls.addTeamResource)
        end)
    end)

    describe("recorded calls", function()
        it("records MarkerAddPoint calls", function()
            local spring = Builders.Spring.new():Build()

            spring.MarkerAddPoint(10, 20, 30, "hello", false)

            assert.are.equal(1, #spring.calls.markerAddPoint)
            assert.are.equal(10,      spring.calls.markerAddPoint[1].x)
            assert.are.equal(20,      spring.calls.markerAddPoint[1].y)
            assert.are.equal(30,      spring.calls.markerAddPoint[1].z)
            assert.are.equal("hello", spring.calls.markerAddPoint[1].label)
            assert.is_false(spring.calls.markerAddPoint[1].local_)
        end)

        it("records MarkerAddLine calls", function()
            local spring = Builders.Spring.new():Build()

            spring.MarkerAddLine(0, 1, 2, 3, 4, 5)

            assert.are.equal(1, #spring.calls.markerAddLine)
            local line = spring.calls.markerAddLine[1]
            assert.are.equal(0, line.x1)
            assert.are.equal(1, line.y1)
            assert.are.equal(2, line.z1)
            assert.are.equal(3, line.x2)
            assert.are.equal(4, line.y2)
            assert.are.equal(5, line.z2)
        end)

        it("records GameOver calls with the raw winners list", function()
            local spring = Builders.Spring.new():Build()

            spring.GameOver({ 0, 2 })

            assert.are.equal(1, #spring.calls.gameOver)
            assert.are.same({ 0, 2 }, spring.calls.gameOver[1])
        end)

        it("records SpawnExplosion calls including params", function()
            local spring = Builders.Spring.new():Build()

            spring.SpawnExplosion(1, 2, 3, 0, 1, 0, { weaponDef = 42 })

            assert.are.equal(1, #spring.calls.spawnExplosion)
            local explosion = spring.calls.spawnExplosion[1]
            assert.are.equal(1, explosion.x)
            assert.are.equal(1, explosion.dy)
            assert.are.equal(42, explosion.params.weaponDef)
        end)

        it("records GiveOrderArrayToUnitMap calls", function()
            local spring = Builders.Spring.new():Build()
            local unitMap = { [10] = true }
            local orders  = { { 20, {}, {} } }

            spring.GiveOrderArrayToUnitMap(unitMap, orders)

            assert.are.equal(1, #spring.calls.giveOrderArrayToUnitMap)
            assert.are.same(unitMap, spring.calls.giveOrderArrayToUnitMap[1].unitMap)
            assert.are.same(orders,  spring.calls.giveOrderArrayToUnitMap[1].orders)
        end)

        it("records TransferUnit calls even when the unit is unknown", function()
            local spring = Builders.Spring.new():Build()

            spring.TransferUnit(99, 5, true)

            assert.are.equal(1, #spring.calls.transferUnit)
            assert.are.equal(99,  spring.calls.transferUnit[1].unitID)
            assert.are.equal(5,   spring.calls.transferUnit[1].newTeam)
            assert.is_true(spring.calls.transferUnit[1].given)
        end)

        it("records SetUnitNoSelect calls per unit", function()
            local spring = Builders.Spring.new():Build()

            spring.SetUnitNoSelect(101, true)
            spring.SetUnitNoSelect(102, false)

            assert.are.equal(2, #spring.calls.setUnitNoSelect)
            assert.are.equal(101, spring.calls.setUnitNoSelect[1].unitID)
            assert.is_true(spring.calls.setUnitNoSelect[1].noSelect)
            assert.are.equal(102, spring.calls.setUnitNoSelect[2].unitID)
            assert.is_false(spring.calls.setUnitNoSelect[2].noSelect)
        end)

        it("records MarkerErasePosition calls", function()
            local spring = Builders.Spring.new():Build()

            spring.MarkerErasePosition(5, 10, 15)

            assert.are.equal(1, #spring.calls.markerErasePosition)
            assert.are.equal(5,  spring.calls.markerErasePosition[1].x)
            assert.are.equal(10, spring.calls.markerErasePosition[1].y)
            assert.are.equal(15, spring.calls.markerErasePosition[1].z)
        end)

        it("records SendCommands calls as raw command strings", function()
            local spring = Builders.Spring.new():Build()

            spring.SendCommands('clearmapmarks')

            assert.are.same({ 'clearmapmarks' }, spring.calls.sendCommands)
        end)

        it("records DestroyFeature calls as raw feature ids", function()
            local spring = Builders.Spring.new():Build()

            spring.DestroyFeature(10)
            spring.DestroyFeature(11)

            assert.are.same({ 10, 11 }, spring.calls.destroyFeature)
        end)

        it("records DestroyUnit calls with their flags", function()
            local spring = Builders.Spring.new():Build()

            spring.DestroyUnit(7, true, false)

            assert.are.equal(1, #spring.calls.destroyUnit)
            assert.are.equal(7, spring.calls.destroyUnit[1].unitID)
            assert.is_true(spring.calls.destroyUnit[1].selfd)
            assert.is_false(spring.calls.destroyUnit[1].reclaimed)
        end)
    end)

    describe("feature and unit state", function()
        it("reports only features registered via WithValidFeature", function()
            local spring = Builders.Spring.new():WithValidFeature(10):Build()

            assert.is_true(spring.ValidFeatureID(10))
            assert.is_false(spring.ValidFeatureID(11))
        end)

        it("treats units as alive by default", function()
            local spring = Builders.Spring.new():Build()

            assert.is_false(spring.GetUnitIsDead(123))
        end)

        it("derives GetAllyTeamList from registered teams", function()
            local team1 = Builders.Team.new():WithAllyTeam(0)
            local team2 = Builders.Team.new():WithAllyTeam(1)
            local team3 = Builders.Team.new():WithAllyTeam(1) -- duplicate ally team
            local spring = Builders.Spring.new()
                :WithTeam(team1)
                :WithTeam(team2)
                :WithTeam(team3)
                :Build()

            assert.are.same({ 0, 1 }, spring.GetAllyTeamList())
        end)

        it("resolves GetUnitAllyTeam from the owning team", function()
            local unitID
            local team = Builders.Team.new()
                :WithAllyTeam(3)
                :WithUnit("armcom", function(id) unitID = id end)
            local spring = Builders.Spring.new():WithTeam(team):Build()

            assert.are.equal(3, spring.GetUnitAllyTeam(unitID))
            assert.is_nil(spring.GetUnitAllyTeam(123456))
        end)

        it("clears every tracked call list via clearCalls", function()
            local spring = Builders.Spring.new():Build()

            spring.AddTeamResource(0, "metal", 1)
            spring.UseTeamResource(0, "metal", 1)
            spring.MarkerAddPoint(0, 0, 0, "l", false)
            spring.MarkerAddLine(0, 0, 0, 1, 1, 1)
            spring.GameOver({ 0 })
            spring.SpawnExplosion(0, 0, 0, 0, 0, 0, {})
            spring.GiveOrderArrayToUnitMap({}, {})
            spring.TransferUnit(1, 2, false)
            spring.SetUnitNoSelect(1, true)
            spring.MarkerErasePosition(0, 0, 0)
            spring.SendCommands('clearmapmarks')
            spring.DestroyFeature(1)
            spring.DestroyUnit(1, false, false)

            spring.clearCalls()

            assert.are.equal(0, #spring.calls.addTeamResource)
            assert.are.equal(0, #spring.calls.useTeamResource)
            assert.are.equal(0, #spring.calls.markerAddPoint)
            assert.are.equal(0, #spring.calls.markerAddLine)
            assert.are.equal(0, #spring.calls.gameOver)
            assert.are.equal(0, #spring.calls.spawnExplosion)
            assert.are.equal(0, #spring.calls.giveOrderArrayToUnitMap)
            assert.are.equal(0, #spring.calls.transferUnit)
            assert.are.equal(0, #spring.calls.setUnitNoSelect)
            assert.are.equal(0, #spring.calls.markerErasePosition)
            assert.are.equal(0, #spring.calls.sendCommands)
            assert.are.equal(0, #spring.calls.destroyFeature)
            assert.are.equal(0, #spring.calls.destroyUnit)
        end)
    end)
end)
