-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal AI full match observer",
		desc = "Observe unassisted AI games, commander deaths and portal travel",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 10001,
		enabled = true,
	}
end
local options = Spring.GetModOptions()
if options.portal_worlds_test ~= "ai_match" then
	return false
end
if not gadgetHandler:IsSyncedCode() then
	local accelerated = false
	function gadget:Update()
		if not accelerated and Spring.GetGameFrame() > 0 then
			accelerated = true
			Spring.SendCommands("setspeed " .. (options.portal_worlds_speed or 1))
		end
		if Spring.GetGameRulesParam("portal_ai_match_done") == 1 then
			Spring.SendCommands("quitforce")
		end
	end
	function gadget:GameOver()
		Spring.SendCommands("quitforce")
	end
	return
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
local teams, home = {}, {}
local lastDamage, deadCommanders, seenRegions, visited = {}, {}, {}, {}
local created, combatDamage, kills = {}, {}, {}
local transitions, foreignKills, losses, openings = 0, 0, 0, 0
local finished, previousOpen = false, {}
local endFrame = tonumber(options.portal_worlds_end) or 108000
local function Log(kind, data)
	data.frame = Spring.GetGameFrame()
	data.event = kind
	Spring.Echo("[BAR_AI_MATCH] " .. Json.encode(data))
end
local function Region(id)
	local x, _, z = Spring.GetUnitPosition(id)
	return world and world.Region(x, z), x, z
end
local function Snapshot()
	local state = {}
	for _, team in ipairs(teams) do
		local list = Spring.GetTeamUnits(team) or {}
		local unitRegions, commands, commanders = {}, {}, {}
		local factories, combat, aircraft = 0, 0, 0
		for _, id in ipairs(list) do
			local def = UnitDefs[Spring.GetUnitDefID(id)]
			if def == nil then
				error("Team unit has no definition")
			end

			local region, x, z = Region(id)
			if region then
				unitRegions[region] = (unitRegions[region] or 0) + 1
			end
			local command = Spring.GetUnitCurrentCommand(id)
			local key = tostring(command or "idle")
			commands[key] = (commands[key] or 0) + 1
			if def.isFactory then
				factories = factories + 1
			end
			if def.canFly then
				aircraft = aircraft + 1
			end
			if not def.isBuilder and not def.isImmobile and #def.weapons > 0 then
				combat = combat + 1
			end
			if def.customParams.iscommander then
				commanders[#commanders + 1] = { id = id, x = x, z = z, region = region }
			end
		end
		state[#state + 1] = {
			team = team,
			dead = select(3, Spring.GetTeamInfo(team, false)),
			home = home[team],
			units = #list,
			created = created[team] or 0,
			factories = factories,
			combat = combat,
			regions = unitRegions,
			commands = commands,
			incomeMultiplier = select(7, Spring.GetTeamInfo(team, false)),
			commanders = commanders,
			aircraft = aircraft,
			visited = visited[team],
			damage = combatDamage[team] or 0,
			kills = kills[team] or 0,
		}
	end
	return state
end
local function Finish(outcome, winners)
	if finished then
		return
	end
	finished = true
	Log("result", {
		outcome = outcome,
		winners = winners or {},
		transitions = transitions,
		commanderDeaths = losses,
		portalOpenings = openings,
		foreignCommanderKills = foreignKills,
		teams = Snapshot(),
	})
	Spring.SetGameRulesParam("portal_ai_match_done", 1)
end
function gadget:Initialize()
	local gaia = Spring.GetGaiaTeamID()
	for _, team in ipairs(Spring.GetTeamList() or {}) do
		if team ~= gaia then
			teams[#teams + 1] = team
			home[team] = world and world.TeamHome(team)
			visited[team] = {}
		end
	end
	Log("setup", {
		teams = teams,
		regions = world and #world.regions or 1,
		limit = endFrame,
		scriptedOrders = false,
		teamsState = Snapshot(),
	})
end
function gadget:UnitCreated(id, def, team)
	created[team] = (created[team] or 0) + 1
end
function gadget:UnitDamaged(id, def, team, damage, paralyzer, weapon, projectile, attacker, attackerDef, attackerTeam)
	if damage > 0 and not paralyzer then
		if attackerTeam then
			combatDamage[attackerTeam] = (combatDamage[attackerTeam] or 0) + damage
		end
		if UnitDefs[def].customParams.iscommander then
			lastDamage[id] =
				{ attacker = attacker, team = attackerTeam, weapon = weapon, frame = Spring.GetGameFrame() }
		end
	end
end
function gadget:UnitDestroyed(id, def, team, attacker, attackerDef, attackerTeam, weapon)
	if attackerTeam and attackerTeam ~= team then
		kills[attackerTeam] = (kills[attackerTeam] or 0) + 1
	end
	if UnitDefs[def].customParams.iscommander and not Spring.GetUnitRulesParam(id, "unit_evolved") then
		local region, x, z = Region(id)
		local last = lastDamage[id] or {}
		attackerTeam = attackerTeam or last.team
		losses = losses + 1
		if attackerTeam and home[attackerTeam] and region ~= home[attackerTeam] then
			foreignKills = foreignKills + 1
		end
		deadCommanders[#deadCommanders + 1] = { team = team, region = region, x = x, z = z, checked = false }
		Log("commander_destroyed", {
			id = id,
			team = team,
			region = region,
			x = x,
			z = z,
			attacker = attacker or last.attacker,
			attackerTeam = attackerTeam,
			weapon = weapon or last.weapon,
			lastDamageFrame = last.frame,
		})
	end
	lastDamage[id], seenRegions[id] = nil, nil
end
function gadget:TeamDied(team)
	Log("team_eliminated", { team = team, home = home[team] })
end
function gadget:GameOver(winners)
	Finish("game_over", winners)
end
function gadget:GameFrame(frame)
	if finished then
		return
	end
	if world and frame % 30 == 0 then
		for edge, connection in ipairs(world.connections) do
			if not previousOpen[edge] and Spring.GetGameRulesParam("portal_e" .. edge .. "_open") == 1 then
				previousOpen[edge] = true
				openings = openings + 1
				local mouths = {}
				for _, region in ipairs(connection) do
					local prefix = "portal_e" .. edge .. "_r" .. region
					mouths[#mouths + 1] = {
						region = region,
						x = Spring.GetGameRulesParam(prefix .. "_x"),
						z = Spring.GetGameRulesParam(prefix .. "_z"),
					}
				end
				Log("portal_opened", { edge = edge, mouths = mouths })
			end
		end
		for _, loss in ipairs(deadCommanders) do
			if not loss.checked then
				for edge, connection in ipairs(world.connections) do
					local mouths = GG.PortalWorlds and GG.PortalWorlds.mouths[edge]
					local mouth = mouths and mouths[loss.region]
					if mouth and (mouth.x - loss.x) ^ 2 + (mouth.z - loss.z) ^ 2 < 1 then
						loss.checked = true
						Log("death_portal_verified", { team = loss.team, edge = edge, region = loss.region })
					end
				end
			end
		end
		for _, team in ipairs(teams) do
			for _, id in ipairs(Spring.GetTeamUnits(team) or {}) do
				local region = Region(id)
				if seenRegions[id] and region and seenRegions[id] ~= region then
					transitions = transitions + 1
					Log("physical_transit", {
						id = id,
						team = team,
						from = seenRegions[id],
						to = region,
						unit = UnitDefs[Spring.GetUnitDefID(id)].name,
					})
				end
				seenRegions[id] = region
				if region then
					visited[team][region] = true
				end
			end
		end
	end
	if frame % 1800 == 0 then
		Log("snapshot", { teams = Snapshot(), transitions = transitions })
	end
	if endFrame > 0 and frame >= endFrame then
		Finish("frame_limit")
	end
end
