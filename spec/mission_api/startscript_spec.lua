require("spec_helper")
require("mission_api.spec_helper")

local startscript = VFS.Include("luarules/mission_api/startscript.lua")
local base64 = VFS.Include("common/luaUtilities/base64.lua")

-- The client writes missionoptions as JSON, compressed with zlib, then base64url encoded.
local function encodeMissionOptions(json)
	return base64.Encode(VFS.ZlibCompress(json))
end

local function sortedIDs(byID)
	local ids = table.keys(byID)
	table.sort(ids)
	return ids
end

-- Return shapes follow Spring.GetTeamInfo and Spring.GetAllyTeamInfo in rts/Lua/LuaSyncedRead.cpp.
local function withStartScript(script)
	Spring.GetModOptions = function()
		return script.modOptions
	end
	Spring.GetTeamList = function()
		return sortedIDs(script.teams)
	end
	Spring.GetTeamInfo = function(teamID, getTeamKeys)
		local team = script.teams[teamID]
		return teamID, 0, false, false, "armada", team.allyTeam, 1, getTeamKeys and team.keys or nil
	end
	Spring.GetAllyTeamList = function()
		return sortedIDs(script.allyTeams)
	end
	Spring.GetAllyTeamInfo = function(allyTeamID)
		return script.allyTeams[allyTeamID].keys
	end
end

describe("mission_api.startscript", function()
	local saved, logged

	before_each(function()
		saved = {
			GetModOptions = Spring.GetModOptions,
			GetTeamList = Spring.GetTeamList,
			GetTeamInfo = Spring.GetTeamInfo,
			GetAllyTeamList = Spring.GetAllyTeamList,
			GetAllyTeamInfo = Spring.GetAllyTeamInfo,
			Log = Spring.Log,
		}
		logged = {}
		Spring.Log = function(_, level, message)
			logged[#logged + 1] = { level = level, message = message }
		end
	end)

	after_each(function()
		for name, fn in pairs(saved) do
			Spring[name] = fn
		end
	end)

	describe("Read", function()
		it("reads the entry point, options and variables from missionoptions", function()
			withStartScript({
				modOptions = {
					missionoptions = encodeMissionOptions(
						[[{"entryPoint":"missions/landfall/mission.lua","options":{"fogOfWar":true},"variables":{"totalKills":123,"foundPortal":true}}]]
					),
				},
				teams = { [0] = { allyTeam = 0, keys = { name = "player" } } },
				allyTeams = { [0] = { keys = { name = "goodies" } } },
			})

			local startScript = startscript.Read()

			assert.are.equal("missions/landfall/mission.lua", startScript.entryPoint)
			assert.are.same({ fogOfWar = true }, startScript.options)
			assert.are.same({ totalKills = 123, foundPortal = true }, startScript.variables)
			assert.are.same({ "foundPortal", "totalKills" }, startScript.persistentVariables)
		end)

		it("gives empty options and variables when missionoptions has none", function()
			withStartScript({
				modOptions = { missionoptions = encodeMissionOptions([[{"entryPoint":"mission.lua"}]]) },
				teams = { [0] = { allyTeam = 0, keys = { name = "player" } } },
				allyTeams = { [0] = { keys = { name = "goodies" } } },
			})

			local startScript = startscript.Read()

			assert.are.same({}, startScript.options)
			assert.are.same({}, startScript.variables)
			assert.are.same({}, startScript.persistentVariables)
		end)

		it("maps team and allyteam names to IDs and back, skipping sections without a name", function()
			withStartScript({
				modOptions = { missionoptions = encodeMissionOptions([[{"entryPoint":"mission.lua"}]]) },
				teams = {
					[0] = { allyTeam = 0, keys = { name = "player" } },
					[1] = { allyTeam = 0, keys = { name = "ally1" } },
					[2] = { allyTeam = 1, keys = { name = "mainEnemy" } },
					[3] = { allyTeam = 2, keys = {} },
				},
				allyTeams = {
					[0] = { keys = { name = "goodies" } },
					[1] = { keys = { name = "enemies" } },
					[2] = { keys = {} },
				},
			})

			local startScript = startscript.Read()

			assert.are.same({ [0] = "player", [1] = "ally1", [2] = "mainEnemy" }, startScript.teamNames)
			assert.are.same({
				[0] = "player",
				[1] = "ally1",
				[2] = "mainEnemy",
				player = 0,
				ally1 = 1,
				mainEnemy = 2,
			}, startScript.teams)
			assert.are.same({ [0] = "goodies", [1] = "enemies" }, startScript.allyTeamNames)
			assert.are.same({ [0] = "goodies", [1] = "enemies", goodies = 0, enemies = 1 }, startScript.allyTeams)
		end)

		it("records each allyteam's dummy team and leaves it out of the names", function()
			withStartScript({
				modOptions = { missionoptions = encodeMissionOptions([[{"entryPoint":"mission.lua"}]]) },
				teams = {
					[0] = { allyTeam = 0, keys = { name = "player" } },
					[1] = { allyTeam = 0, keys = { dummy = "1" } },
					[2] = { allyTeam = 1, keys = { name = "mainEnemy" } },
					[3] = { allyTeam = 1, keys = { dummy = "true" } },
				},
				allyTeams = {
					[0] = { keys = { name = "goodies" } },
					[1] = { keys = { name = "enemies" } },
				},
			})

			local startScript = startscript.Read()

			assert.are.same({ [0] = 1, [1] = 3 }, startScript.dummyTeams)
			assert.are.same({ [0] = "player", [2] = "mainEnemy" }, startScript.teamNames)
		end)

		it("returns nil without logging when there is no missionoptions", function()
			withStartScript({
				modOptions = {},
				teams = { [0] = { allyTeam = 0, keys = {} } },
				allyTeams = { [0] = { keys = {} } },
			})

			assert.is_nil(startscript.Read())
			assert.are.same({}, logged)
		end)

		it("returns nil when missionoptions has no entry point", function()
			withStartScript({
				modOptions = { missionoptions = encodeMissionOptions([[{"disableFactionPicker":true}]]) },
				teams = { [0] = { allyTeam = 0, keys = {} } },
				allyTeams = { [0] = { keys = {} } },
			})

			assert.is_nil(startscript.Read())
		end)

		it("logs an error and returns nil when missionoptions does not decode", function()
			withStartScript({
				modOptions = { missionoptions = "not a payload" },
				teams = { [0] = { allyTeam = 0, keys = {} } },
				allyTeams = { [0] = { keys = {} } },
			})

			assert.is_nil(startscript.Read())
			assert.is_true(table.any(logged, function(entry)
				return entry.level == LOG.ERROR and entry.message == "[Mission API] Could not decode missionoptions"
			end))
		end)
	end)
end)
