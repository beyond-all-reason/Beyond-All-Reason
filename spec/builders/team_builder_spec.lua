local Builders = VFS.Include("spec/builders/index.lua")

describe("TeamBuilder", function()
    it("should create teams with unique IDs", function()
        local team1 = Builders.Team.new()
        local team2 = Builders.Team.new()
        assert.is_number(team1.id)
        assert.is_number(team2.id)
        assert.are_not.equal(team1.id, team2.id)
    end)

    it("should build teams with units", function()
        local team = Builders.Team.new()
            :WithMetal(500)
            :WithUnit("armcom")
            :WithUnit("corcom")
            :Build()

        ---@diagnostic disable-next-line: undefined-field
        assert.are.equal(500, team.metal.current)
        local unitCount = 0
        for _ in pairs(team.units) do unitCount = unitCount + 1 end
        assert.are.equal(2, unitCount)
    end)
end)
