local Builders = require("spec/builders/index")

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
        assert.is_true(spring.AreAlliedTeams(team1.id, team2.id))

        local teamUnits = spring.GetTeamUnits(team1.id)
        local unitCount = 0
        for _ in pairs(teamUnits) do unitCount = unitCount + 1 end
        assert.are.equal(1, unitCount)
    end)

    it("should integrate real unit definitions", function()
        local teamBuilder = Builders.Team.new():WithUnit("armacv")
        local spring = Builders.Spring.new()
            :WithRealUnitDefs()
            :WithTeam(teamBuilder)
            :Build()

        local teamUnits = spring.GetTeamUnits(teamBuilder.id)
        -- GetTeamUnits returns unitID -> unitDefId mapping
        local unitDefId = nil
        for _, defId in pairs(teamUnits) do
            unitDefId = defId
            break
        end
        assert.are.equal("armacv", unitDefId)

        -- Check that the built team has integrated unit data
        local builtTeam = spring._builtTeams[teamBuilder.id]
        local unitWrapper = nil
        for _, wrapper in pairs(builtTeam.units) do
            unitWrapper = wrapper
            break
        end
        assert.is_table(unitWrapper.unitDef)
        assert.are.equal("armacv", unitWrapper.name)
    end)
end)