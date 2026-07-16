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
		local team = Builders.Team.new():WithMetal(500):WithUnit("armcom"):WithUnit("corcom"):Build()

		---@diagnostic disable-next-line: undefined-field
		assert.are.equal(500, team.metal.current)
		local unitCount = 0
		for _ in pairs(team.units) do
			unitCount = unitCount + 1
		end
		assert.are.equal(2, unitCount)
	end)

	describe("Spring list functions return number[] not objects", function()
		it("GetTeamList returns an array of team ID numbers, not objects", function()
			local team1 = Builders.Team.new():WithID(5)
			local team2 = Builders.Team.new():WithID(7)

			local spring = Builders.EngineSynced.new():WithTeam(team1):WithTeam(team2):Build()

			local teamList = spring.GetTeamList()

			for _, value in ipairs(teamList) do
				assert.is_number(value, "GetTeamList should return team IDs as numbers, not objects")
			end

			local foundIds = {}
			for _, teamId in ipairs(teamList) do
				foundIds[teamId] = true
			end
			assert.is_true(foundIds[5], "Team ID 5 should be in the list")
			assert.is_true(foundIds[7], "Team ID 7 should be in the list")
		end)

		it("GetPlayerList returns an array of player ID numbers, not objects", function()
			local team1 = Builders.Team.new():WithID(1):WithPlayer(100):WithPlayer(101)

			local spring = Builders.EngineSynced.new():WithTeam(team1):Build()

			local playerList = spring.GetPlayerList(1)

			for _, value in ipairs(playerList) do
				assert.is_number(value, "GetPlayerList should return player IDs as numbers, not objects")
			end

			local foundIds = {}
			for _, playerId in ipairs(playerList) do
				foundIds[playerId] = true
			end
			assert.is_true(foundIds[100], "Player ID 100 should be in the list")
			assert.is_true(foundIds[101], "Player ID 101 should be in the list")
		end)

		it("snapshot teams are keyed by teamId, not stored in .id field", function()
			local team1 = Builders.Team.new():WithID(3)
			local team2 = Builders.Team.new():WithID(8)

			local spring = Builders.EngineSynced.new():WithTeam(team1):WithTeam(team2):Build()

			local builtTeams = spring._builtTeams
			assert.is_not_nil(builtTeams[3], "Team should be accessible by ID as key")
			assert.is_not_nil(builtTeams[8], "Team should be accessible by ID as key")

			for teamId, team in pairs(builtTeams) do
				assert.is_number(teamId, "Table key should be the numeric team ID")
				assert.is_table(team, "Table value should be the team data")
				assert.is_table(team.metal, "Team should have metal resource data")
			end
		end)
	end)
end)
