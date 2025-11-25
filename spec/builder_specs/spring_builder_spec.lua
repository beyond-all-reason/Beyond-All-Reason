local Builders = VFS.Include("spec/builders/index.lua")

describe("SpringBuilder", function()
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
end)