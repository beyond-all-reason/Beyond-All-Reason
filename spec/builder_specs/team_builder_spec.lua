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

    -- COMMON MISCONCEPTION: Spring.GetTeamList() and GetPlayerList() return objects with .id fields
    -- REALITY: Both return number[] - plain arrays of IDs. To get details, call GetTeamInfo(teamID)
    -- or GetPlayerInfo(playerID) with the ID from the list.
    --
    -- Similarly, ProcessEconomy receives table<teamId, TeamData> where the KEY is the team ID,
    -- not an .id field on the TeamData object. Never write `team.id or key` - the key IS the ID.
    --
    -- Correct pattern (from engine's game_end.lua):
    --   for _, teamID in ipairs(Spring.GetTeamList()) do
    --       local _, leader, isDead = Spring.GetTeamInfo(teamID)
    --       ...
    --   end
    describe("Spring list functions return number[] not objects", function()
        it("GetTeamList returns an array of team ID numbers, not objects", function()
            local team1 = Builders.Team.new():WithID(5)
            local team2 = Builders.Team.new():WithID(7)

            local spring = Builders.Spring.new()
                :WithTeam(team1)
                :WithTeam(team2)
                :Build()

            local teamList = spring.GetTeamList()

            -- GetTeamList returns number[], NOT {id: number, ...}[]
            for _, value in ipairs(teamList) do
                assert.is_number(value, "GetTeamList should return team IDs as numbers, not objects")
            end

            -- Verify the actual team IDs are in the list
            local foundIds = {}
            for _, teamId in ipairs(teamList) do
                foundIds[teamId] = true
            end
            assert.is_true(foundIds[5], "Team ID 5 should be in the list")
            assert.is_true(foundIds[7], "Team ID 7 should be in the list")
        end)

        it("GetPlayerList returns an array of player ID numbers, not objects", function()
            local team1 = Builders.Team.new():WithID(1):WithPlayer(100):WithPlayer(101)

            local spring = Builders.Spring.new()
                :WithTeam(team1)
                :Build()

            local playerList = spring.GetPlayerList(1)

            -- GetPlayerList returns number[], NOT {id: number, ...}[]
            for _, value in ipairs(playerList) do
                assert.is_number(value, "GetPlayerList should return player IDs as numbers, not objects")
            end

            -- Verify the actual player IDs are in the list
            local foundIds = {}
            for _, playerId in ipairs(playerList) do
                foundIds[playerId] = true
            end
            assert.is_true(foundIds[100], "Player ID 100 should be in the list")
            assert.is_true(foundIds[101], "Player ID 101 should be in the list")
        end)

        it("ProcessEconomy teams are keyed by teamId, not stored in .id field", function()
            -- The key IS the team ID. There is no .id field on TeamResourceData.
            -- This mirrors how the engine provides data to ProcessEconomy.
            local team1 = Builders.Team.new():WithID(3)
            local team2 = Builders.Team.new():WithID(8)

            local spring = Builders.Spring.new()
                :WithTeam(team1)
                :WithTeam(team2)
                :Build()

            -- Access teams via their ID as the key
            local builtTeams = spring._builtTeams
            assert.is_not_nil(builtTeams[3], "Team should be accessible by ID as key")
            assert.is_not_nil(builtTeams[8], "Team should be accessible by ID as key")

            -- The pattern `for teamId, team in pairs(teams)` gives you the ID as the key
            for teamId, team in pairs(builtTeams) do
                assert.is_number(teamId, "Table key should be the numeric team ID")
                assert.is_table(team, "Table value should be the team data")
                assert.is_table(team.metal, "Team should have metal resource data")
            end
        end)
    end)
end)
