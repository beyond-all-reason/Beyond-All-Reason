local Liveness = VFS.Include("modules/matchflow/lib/liveness.lua")

-- A controllable fake match: two allyteams, one human team each, by default.
-- Every spec builds a world, drives the machine, and observes effects
-- (KillTeam / DestroyUnit / wipeoutAllyTeam) plus the Infos() view.
--
-- These specs encode game_end.lua's CURRENT behavior, hacks included; if one
-- fails after a refactor, the refactor changed behavior.

local GAIA_TEAM = 99
local GAIA_ALLY = 9

local function newWorld(opts)
	opts = opts or {}
	local world = {
		players = {},   -- playerID -> {active, spectator, teamID, allyTeamID}
		teams = {},     -- teamID -> {leader, isAI, luaAI, allyTeamID, units}
		allyTeams = {}, -- allyTeamID -> teamID[]
		killed = {},
		destroyed = {},
		wipedOut = {},
	}

	local function addTeam(teamID, allyTeamID, teamOpts)
		teamOpts = teamOpts or {}
		world.teams[teamID] = {
			leader = teamOpts.leader ~= nil and teamOpts.leader or 0,
			isAI = teamOpts.isAI or false,
			aiHost = teamOpts.aiHost,
			luaAI = teamOpts.luaAI or "",
			allyTeamID = allyTeamID,
			units = teamOpts.units or {},
		}
		world.allyTeams[allyTeamID] = world.allyTeams[allyTeamID] or {}
		table.insert(world.allyTeams[allyTeamID], teamID)
	end

	local function addPlayer(playerID, teamID)
		world.players[playerID] = {
			active = true,
			spectator = false,
			teamID = teamID,
			allyTeamID = world.teams[teamID].allyTeamID,
		}
	end

	world.addTeam = addTeam
	world.addPlayer = addPlayer

	world.spring = {
		GetPlayerList = function(teamID)
			local list = {}
			for playerID, player in pairs(world.players) do
				if teamID == nil or player.teamID == teamID then
					list[#list + 1] = playerID
				end
			end
			table.sort(list)
			return list
		end,
		GetPlayerInfo = function(playerID)
			local player = world.players[playerID]
			return "player" .. playerID, player.active, player.spectator, player.teamID, player.allyTeamID
		end,
		GetTeamList = function(allyTeamID)
			if allyTeamID == nil then
				local all = {}
				for teamID in pairs(world.teams) do
					all[#all + 1] = teamID
				end
				table.sort(all)
				return all
			end
			return world.allyTeams[allyTeamID] or {}
		end,
		GetTeamInfo = function(teamID)
			local team = world.teams[teamID]
			return teamID, team.leader, 0, team.isAI, "", team.allyTeamID
		end,
		GetTeamUnitCount = function(teamID)
			return #world.teams[teamID].units
		end,
		GetTeamUnits = function(teamID)
			return world.teams[teamID].units
		end,
		GetUnitDefID = function(unitID)
			return world.unitDefOf and world.unitDefOf[unitID] or 1
		end,
		GetAIInfo = function(teamID)
			return nil, nil, world.teams[teamID].aiHost
		end,
		GetTeamLuaAI = function(teamID)
			return world.teams[teamID].luaAI
		end,
		KillTeam = function(teamID)
			world.killed[#world.killed + 1] = teamID
		end,
		DestroyUnit = function(unitID)
			world.destroyed[#world.destroyed + 1] = unitID
		end,
	}

	world.config = {
		gaiaTeamID = GAIA_TEAM,
		gaiaAllyTeamID = GAIA_ALLY,
		isFFA = opts.isFFA or false,
		playerQuitIsDead = opts.playerQuitIsDead ~= false,
		earlyDropGrace = 30 * 60,
		killGraceFrames = 30 * (opts.isFFA and 20 or 12),
		ignoredTeams = opts.ignoredTeams or { [GAIA_TEAM] = true },
		unitDecoration = opts.unitDecoration or {},
	}

	world.start = function()
		local liveness = Liveness.New({
			spring = world.spring,
			config = world.config,
			wipeoutAllyTeam = function(allyTeamID)
				world.wipedOut[#world.wipedOut + 1] = allyTeamID
			end,
		})
		local allyList = {}
		for allyTeamID in pairs(world.allyTeams) do
			allyList[#allyList + 1] = allyTeamID
		end
		table.sort(allyList)
		liveness.InitTeams(allyList)
		world.liveness = liveness
		return liveness
	end

	return world
end

local function standardWorld(opts)
	local world = newWorld(opts)
	world.addTeam(0, 0)
	world.addTeam(1, 1)
	world.addPlayer(10, 0)
	world.addPlayer(11, 1)
	return world
end

describe("matchflow liveness", function()
	describe("initialization", function()
		it("counts starting units per team and allyteam", function()
			local world = newWorld()
			world.addTeam(0, 0, { units = { 101, 102 } })
			world.addTeam(1, 0, { units = { 103 } })
			world.addTeam(2, 1, { units = {} })
			world.addPlayer(10, 0)
			world.addPlayer(11, 1)
			world.addPlayer(12, 2)
			local liveness = world.start()

			local infos = liveness.Infos()
			assert.are.equal(3, infos[0].unitCount)
			assert.are.equal(2, infos[0].teams[0].unitCount)
			assert.are.equal(1, infos[0].teams[1].unitCount)
			assert.are.equal(0, infos[1].unitCount)
		end)

		it("counts starting decoration units", function()
			local world = newWorld({ unitDecoration = { [7] = true } })
			world.unitDefOf = { [101] = 7, [102] = 1 }
			world.addTeam(0, 0, { units = { 101, 102 } })
			world.addTeam(1, 1)
			world.addPlayer(10, 0)
			world.addPlayer(11, 1)
			local liveness = world.start()
			assert.are.equal(1, liveness.Infos()[0].unitDecorationCount)
		end)

		it("marks an empty allyteam dead from the start", function()
			local world = standardWorld()
			world.allyTeams[2] = {}
			local liveness = world.start()
			assert.is_true(liveness.Infos()[2].dead)
		end)

		it("marks a Lua-AI team controlled and AI", function()
			local world = newWorld()
			world.addTeam(0, 0)
			world.addTeam(1, 1, { luaAI = "BARb" })
			world.addPlayer(10, 0)
			local liveness = world.start()
			assert.is_true(liveness.Infos()[1].teams[1].isAI)
			assert.is_true(liveness.Infos()[1].teams[1].isControlled)
		end)
	end)

	describe("resignation (all players spectate)", function()
		it("kills the team immediately on its next check", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.CheckAllPlayers(100)
			assert.are.same({}, world.killed)

			world.players[11].spectator = true
			liveness.CheckAllPlayers(200)
			assert.are.same({ 1 }, world.killed)
		end)

		it("never resigns an AI team", function()
			local world = newWorld()
			world.addTeam(0, 0)
			world.addTeam(1, 1, { isAI = true, aiHost = 11 })
			world.addPlayer(10, 0)
			world.addPlayer(11, 1)
			local liveness = world.start()
			world.players[11].spectator = true
			liveness.CheckAllPlayers(200)
			assert.are.same({}, world.killed)
		end)
	end)

	describe("leaderless grace period", function()
		it("queues the kill for gameSpeed*12 frames (non-FFA), then kills", function()
			local world = standardWorld()
			local liveness = world.start()

			-- player drops: still has a leader slot? no — leader gone too
			world.players[11].active = false
			world.teams[1].leader = -1
			liveness.CheckAllPlayers(100)
			assert.are.same({}, world.killed)

			liveness.CheckAllPlayers(100 + 30 * 12 - 1)
			assert.are.same({}, world.killed)
			liveness.CheckAllPlayers(100 + 30 * 12)
			assert.are.same({ 1 }, world.killed)
		end)

		it("cancels the queued kill when the leader returns", function()
			local world = standardWorld()
			local liveness = world.start()
			world.players[11].active = false
			world.teams[1].leader = -1
			liveness.CheckAllPlayers(100)

			world.players[11].active = true
			world.teams[1].leader = 11
			liveness.CheckAllPlayers(150)

			liveness.CheckAllPlayers(100 + 30 * 12)
			assert.are.same({}, world.killed)
		end)
	end)

	describe("the savegame active-flag hack", function()
		it("keeps a team controlled for 60 frames after the player goes inactive", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.CheckAllPlayers(100) -- records isControlling = 100

			world.players[11].active = false
			liveness.CheckAllPlayers(159) -- 100 > 159-60: still controlled
			assert.is_true(liveness.Infos()[1].teams[1].isControlled)

			liveness.CheckAllPlayers(161) -- 100 <= 161-60: no longer controlled
			assert.is_false(liveness.Infos()[1].teams[1].isControlled)
		end)
	end)

	describe("allyteam death", function()
		it("wipes out an allyteam when its only team dies", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.TeamDied(1, 500)
			assert.are.same({ 1 }, world.wipedOut)
			assert.is_true(liveness.Infos()[1].dead)
		end)

		it("does not evaluate death at frame 0", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.TeamDied(1, 0)
			assert.are.same({}, world.wipedOut)
			assert.is_false(liveness.Infos()[1].dead)
		end)

		it("declares an uncontrolled allyteam dead when playerQuitIsDead", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.CheckAllPlayers(100)
			world.players[11].active = false
			liveness.CheckAllPlayers(300) -- past the 60-frame window
			assert.are.same({ 1 }, world.wipedOut)
		end)

		it("keeps an uncontrolled allyteam alive when playerQuitIsDead is off (1v1 rejoin)", function()
			local world = standardWorld({ playerQuitIsDead = false })
			local liveness = world.start()
			liveness.CheckAllPlayers(100)
			world.players[11].active = false
			liveness.CheckAllPlayers(300)
			assert.are.same({}, world.wipedOut)
		end)

		it("reclaims units instead of wiping out on FFA early drop", function()
			local world = newWorld({ isFFA = true })
			world.addTeam(0, 0)
			world.addTeam(1, 1, { units = { 201, 202 } })
			world.addTeam(2, 2)
			world.addPlayer(10, 0)
			world.addPlayer(11, 1)
			world.addPlayer(12, 2)
			local liveness = world.start()
			liveness.TeamDied(1, 100) -- inside earlyDropGrace (30*60)
			assert.are.same({ 201, 202 }, world.destroyed)
			assert.are.same({}, world.wipedOut)
			assert.is_true(liveness.Infos()[1].dead)
		end)
	end)

	describe("unit counting", function()
		it("tracks created and destroyed units", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.UnitCreated(1, 0)
			liveness.UnitCreated(1, 0)
			liveness.UnitDestroyed(1, 0)
			assert.are.equal(1, liveness.Infos()[0].unitCount)
		end)

		it("ignores configured teams (gaia, Raptors/Scavengers)", function()
			local world = standardWorld()
			local liveness = world.start()
			liveness.UnitCreated(1, GAIA_TEAM)
			assert.are.equal(0, liveness.Infos()[0].unitCount)
			assert.are.equal(0, liveness.Infos()[1].unitCount)
		end)

		it("kills every team in an allyteam left with only decorations", function()
			local world = newWorld({ unitDecoration = { [7] = true } })
			world.addTeam(0, 0)
			world.addTeam(1, 1)
			world.addPlayer(10, 0)
			world.addPlayer(11, 1)
			local liveness = world.start()

			liveness.UnitCreated(1, 1) -- a real unit
			liveness.UnitCreated(7, 1) -- a decoration
			liveness.UnitDestroyed(1, 1) -- real unit dies -> only decoration left
			assert.are.same({ 1 }, world.killed)
		end)
	end)
end)
