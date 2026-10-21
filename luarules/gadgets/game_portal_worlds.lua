-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal worlds",
		desc = "Manifest-driven isolated maps joined by commander loss",
		author = "Codex",
		license = "GPL v2 or later",
		layer = -50,
		enabled = true,
	}
end
local options = Spring.GetModOptions()
if not options.portal_worlds or options.portal_worlds == "off" then
	return false
end
if not gadgetHandler:IsSyncedCode() then
	local accelerated, done = false, false
	function gadget:Update()
		if not accelerated and Spring.GetGameFrame() > 0 then
			accelerated = true
			Spring.SendCommands("setspeed " .. (options.portal_worlds_speed or 1))
		end
		if not done and Spring.GetGameRulesParam("portal_done") == 1 then
			done = true
			Spring.SendCommands("quitforce")
		end
	end
	function gadget:GameOver()
		if tonumber(options.portal_worlds_end or 0) > 0 then
			Spring.SendCommands("quitforce")
		end
	end
	return
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
if not world then
	return false
end
if
	not (
		Engine.FeatureSupport
		and Engine.FeatureSupport.mapRegionViews
		and Engine.FeatureSupport.sensorRegions
		and Engine.FeatureSupport.mapDamageRegions
	)
then
	function gadget:GameFrame(f)
		if f == 1 then
			Spring.Echo(
				"Portal worlds requires engine map-region views, synced sensor regions and crater regions; disable the experimental portal option for normal BAR."
			)
			Spring.SetGameRulesParam("portal_worlds_unsupported_engine", 1)
			Spring.GameOver({})
		end
	end
	return
end
local regions, connections = world.regions, world.connections
local Region, TeamHome = world.Region, world.TeamHome
local endFrame = tonumber(options.portal_worlds_end) or 0
local PORTAL_RADIUS, APPROACH_RADIUS = 180, 80
local RAW_MOVE = CMD.MOVE
local PORTAL = GameCMD.PORTAL_TRAVEL
local home, cooldown, travelers, pendingLoss = {}, {}, {}, {}
---@type table<UnitID, {edge: integer, region: integer}>
local beacons = {}
local openEdges, lossOpened = {}, {}
---@type table<integer, table<integer, {x: number, y: number, z: number}>>
local mouths = {}
local damage, created = {}, {}
local transitMemberProviders = {}
local passages, blockedDamage, wallHits, blockedOrders = 0, 0, 0, 0
local function Log(s)
	if endFrame > 0 then
		Spring.Echo("[BAR_PORTALS] " .. s)
	end
end
local function Valid(id)
	return id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)
end
local mobileDefs, commanderDefs = {}, {}
for id, def in pairs(UnitDefs) do
	mobileDefs[id] = not def.isImmobile and def.speed > 0 and not def.customParams.decoration
	commanderDefs[id] = not not def.customParams.iscommander
end
local function IsOpen(edge)
	return openEdges[edge]
end
local function FreeSpot(def, x, z, region, exitMouth)
	local r = regions[region]
	for ring = 0, 36 do
		for j = 0, 15 do
			local tx = math.max(r.x0 + 24, math.min(r.x1 - 24, x + ring * 40 * math.cos(j * math.pi / 8)))
			local tz = math.max(r.z0 + 24, math.min(r.z1 - 24, z + ring * 40 * math.sin(j * math.pi / 8)))
			local y = Spring.GetGroundHeight(tx, tz)
			local clear = not exitMouth or (tx - exitMouth.x) ^ 2 + (tz - exitMouth.z) ^ 2 >= 240 ^ 2
			local safe = not r.surface or y > r.surface.height + 4
			if
				clear
				and safe
				and (UnitDefs[def].canFly or Spring.TestMoveOrder(def, tx, y, tz, 0, 0, 0, true, true, true))
			then
				return tx, y, tz
			end
		end
	end
end
local function PublishMouth(edge, region, m)
	local prefix = "portal_e" .. edge .. "_r" .. region
	Spring.SetGameRulesParam(prefix .. "_x", m.x)
	Spring.SetGameRulesParam(prefix .. "_z", m.z)
	-- Retain these diagnostic names for the first mouth in a region.
	if not Spring.GetGameRulesParam("portal_m" .. region .. "_x") then
		Spring.SetGameRulesParam("portal_m" .. region .. "_x", m.x)
		Spring.SetGameRulesParam("portal_m" .. region .. "_z", m.z)
	end
end
local function OpenPortal(team, frame, loss)
	local source = loss.region
	if not source or lossOpened[source] then
		return
	end
	local chosen
	-- Prefer the outgoing edge in the authored graph; fall back to a closed neighbour.
	for i, edge in ipairs(connections) do
		if edge[1] == source and not openEdges[i] then
			chosen = i
			break
		end
	end
	if not chosen then
		for i, edge in ipairs(connections) do
			if world.Other(edge, source) and not openEdges[i] then
				chosen = i
				break
			end
		end
	end
	lossOpened[source] = true
	if not chosen then
		return
	end
	local edge = connections[chosen]
	mouths[chosen] = {}
	for _, region in ipairs(edge) do
		local r = regions[region]
		local x, z = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
		if region == source and loss.x then
			x, z = loss.x, loss.z
		end
		-- Separate the central ends of several portals in the same map.
		if region ~= source then
			for _, existing in pairs(mouths) do
				if existing[region] then
					x = x + 360
				end
			end
		end
		local y = Spring.GetGroundHeight(x, z)
		if region ~= source then
			x, y, z = FreeSpot(UnitDefNames.armflea.id, x, z, region)
			assert(x and y and z, "No central portal site in " .. r.name)
		end
		local m = { x = x, y = y, z = z }
		mouths[chosen][region] = m
		PublishMouth(chosen, region, m)
		local id = Spring.CreateUnit("portal_gate", x, y, z, 0, Spring.GetGaiaTeamID())
		assert(id, "Could not create portal beacon")
		beacons[id] = { edge = chosen, region = region }
		home[id] = region
		Spring.SetUnitNeutral(id, true)
		Spring.SetUnitBlocking(id, false)
		Spring.SetUnitAlwaysVisible(id, true)
		Spring.SetUnitRulesParam(id, "portal_portal", chosen, { public = true })
		Spring.SetUnitRulesParam(id, "portal_region", region, { public = true })
		local destination = regions[world.Other(edge, region)].name
		Spring.SetUnitRulesParam(id, "portal_destination_name", destination, { public = true })
		Spring.SetUnitTooltip(id, "Portal to " .. destination .. " - Right click with mobile units to travel")
		Spring.SetUnitNoSelect(id, false)
		Spring.SetUnitHealth(id, 100000)
		Spring.SpawnCEG("portal-transit", x, y + 10, z, 0, 1, 0, 40)
	end
	openEdges[chosen] = true
	Spring.SetGameRulesParam("portal_e" .. chosen .. "_open", 1)
	Spring.SetGameRulesParam("portal_open", 1)
	Spring.SetGameRulesParam("portal_open_frame", frame)
	Spring.SetGameRulesParam("portal_loser", team)
	Log(
		"OPEN frame="
			.. frame
			.. " lostTeam="
			.. team
			.. " source="
			.. source
			.. " edge="
			.. chosen
			.. " to="
			.. world.Other(edge, source)
	)
end
local function Route(id, region, destination, manual, chosen, commandTag)
	if travelers[id] or not mobileDefs[Spring.GetUnitDefID(id)] then
		return
	end
	local edge, nextRegion = chosen, chosen and world.Other(connections[chosen], region)
	if not edge then
		edge, nextRegion = world.Route(region, destination, IsOpen)
	end
	if not edge or not openEdges[edge] or not nextRegion then
		return
	end
	local m = mouths[edge][region]
	Spring.SetUnitTarget(id, nil)
	travelers[id] = { region = region, destination = nextRegion, manual = manual, edge = edge, commandTag = commandTag }
	-- Fixed-wing defaults may finish outside the portal activation radius.
	Spring.GiveOrderToUnit(
		id,
		CMD.INSERT,
		{ 0, RAW_MOVE, CMD.OPT_INTERNAL, m.x, m.y, m.z, APPROACH_RADIUS },
		CMD.OPT_ALT
	)
	local current, _, tag = Spring.GetUnitCurrentCommand(id)
	-- A completed approach can expose the original request immediately,
	-- especially for fixed-wing aircraft. Never record that request as an
	-- approach tag: removing it after transit would delete the remaining route.
	if current == RAW_MOVE and tag ~= commandTag then
		travelers[id].moveTag = tag
	end
end
local unitTargets = {
	[CMD.ATTACK] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.RECLAIM] = true,
	[CMD.CAPTURE] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.MANUALFIRE] = true,
	[GameCMD.UNIT_SET_TARGET] = true,
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = true,
}
local travelCommands = { [CMD.MOVE] = true, [CMD.FIGHT] = true, [CMD.ATTACK] = true, [GameCMD.RAW_MOVE] = true }
local positionCommands = {}
for cmd in pairs(travelCommands) do
	positionCommands[cmd] = true
end
for cmd in pairs(unitTargets) do
	positionCommands[cmd] = true
end
for _, cmd in ipairs({
	CMD.PATROL,
	CMD.RESTORE,
	CMD.RESURRECT,
	CMD.UNLOAD_UNITS,
	CMD.UNLOAD_UNIT,
	GameCMD.UNIT_SET_TARGET_RECTANGLE,
	GameCMD.AREA_ATTACK_GROUND,
}) do
	positionCommands[cmd] = true
end
local function CommandRegion(cmd, params)
	if cmd == GameCMD.UNIT_SET_TARGET_RECTANGLE and #params >= 4 then
		local a, b = Region(params[1], params[2]), Region(params[3], params[4])
		return a == b and a or nil
	end
	if #params >= 3 and (cmd < 0 or positionCommands[cmd]) then
		return Region(params[1], params[3])
	end
	if #params == 1 then
		if (cmd == CMD.RECLAIM or cmd == CMD.RESURRECT) and params[1] >= Game.maxUnits then
			local x, _, z = Spring.GetFeaturePosition(params[1] - Game.maxUnits)
			return Region(x, z)
		end
		if unitTargets[cmd] and Valid(params[1]) then
			return home[params[1]]
		end
	end
end
function gadget:Initialize()
	gadgetHandler:RegisterCMDID(PORTAL)
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	assert(
		Game.mapSizeX == world.size[1] and Game.mapSizeZ == world.size[2],
		"Portal manifest and physical map disagree"
	)
	local sensorRegions = {}
	for i, r in ipairs(regions) do
		sensorRegions[i] = { r.x0, r.z0, r.x1, r.z1 }
	end
	assert(
		Spring.SetSensorRegions(sensorRegions),
		"Portal sensor regions must align to the engine sensor grid and be configured before simulation starts"
	)
	assert(
		Spring.SetMapDamageRegions(sensorRegions),
		"Portal crater regions must be configured before simulation starts"
	)
	Spring.SetGameRulesParam("portal_ai_version", 1)
	Spring.SetGameRulesParam("portal_ai_diagnostics", options.portal_worlds_test == "ai_match" and 1 or 0)
	Spring.SetGameRulesParam("portal_regions", #regions)
	Spring.SetGameRulesParam("portal_edges", #connections)
	Spring.SetGameRulesParam("portal_open", 0)
	for i, r in ipairs(regions) do
		for _, k in ipairs({ "x0", "z0", "x1", "z1" }) do
			Spring.SetGameRulesParam("portal_r" .. i .. "_" .. k, r[k])
		end
	end
	for i, edge in ipairs(connections) do
		Spring.SetGameRulesParam("portal_e" .. i .. "_open", 0)
		Spring.SetGameRulesParam("portal_e" .. i .. "_a", edge[1])
		Spring.SetGameRulesParam("portal_e" .. i .. "_b", edge[2])
	end
	-- Native AI reads topology and public elimination state, never hidden enemies.
	for _, entry in ipairs(world.teams) do
		Spring.SetGameRulesParam("portal_team" .. entry.team .. "_region", entry.region)
		Spring.SetGameRulesParam(
			"portal_team" .. entry.team .. "_alive",
			select(3, Spring.GetTeamInfo(entry.team, false)) and 0 or 1
		)
	end
	-- The generated API library omits the native hardness, tracks and name parameters.
	---@diagnostic disable-next-line: redundant-parameter
	Spring.SetTerrainTypeData(255, 0, 0, 0, 0, 1000000, false, "Cubicle barrier")
	-- Cubicle barriers: impassable terrain and build masks between authored regions.
	for x = 0, Game.mapSizeX - 8, 8 do
		for z = 0, Game.mapSizeZ - 8, 8 do
			if not Region(x + 4, z + 4) then
				Spring.SetMapSquareTerrainType(x, z, 255)
				if x % 16 == 0 and z % 16 == 0 then
					Spring.SetSquareBuildingMask(math.floor(x / 16), math.floor(z / 16), 0)
				end
			end
		end
	end
	GG.PortalWorlds = {
		RegisterTransitMembers = function(name, provider)
			transitMemberProviders[name] = provider
		end,
		world = world,
		home = home,
		openEdges = openEdges,
		mouths = mouths,
		beacons = beacons,
		Region = Region,
	}
	Log("READY regions=" .. #regions .. " spots=" .. tostring(GG.metalSpots and #GG.metalSpots))
end
function gadget:UnitCreated(id, def, team)
	created[team] = (created[team] or 0) + 1
	local x, _, z = Spring.GetUnitPosition(id)
	home[id] = Region(x, z)
end
function gadget:AllowCommand(id, def, team, cmd, params, opts)
	-- Inspect inserted orders too, before interpreting their target or queue flags.
	local actual, p = cmd, params
	if cmd == CMD.INSERT then
		if #params < 3 then
			return false
		end
		actual = params[2]
		p = {}
		for i = 4, #params do
			p[#p + 1] = params[i]
		end
	end
	if actual == PORTAL then
		local edge = tonumber(p[1])
		return mobileDefs[def]
				and home[id] ~= nil
				and (not p[2] or p[2] == home[id])
				and edge ~= nil
				and openEdges[edge]
				and world.Other(connections[edge], home[id]) ~= nil
			or false
	end
	---@type {edge: integer, region: integer}?
	local target
	if unitTargets[actual] and #p == 1 then
		target = beacons[p[1]]
	end
	if target then
		if
			(
				actual == CMD.ATTACK
				or actual == CMD.GUARD
				or actual == CMD.REPAIR
				or actual == CMD.RECLAIM
				or actual == CMD.CAPTURE
				or actual == CMD.LOAD_UNITS
			)
			and target.region == home[id]
			and mobileDefs[def]
		then
			if cmd == CMD.INSERT then
				Spring.GiveOrderToUnit(
					id,
					CMD.INSERT,
					{ params[1], PORTAL, params[3], target.edge, target.region },
					opts.coded or 0
				)
			else
				Spring.GiveOrderToUnit(id, PORTAL, { target.edge, target.region }, opts.coded or 0)
			end
		end
		return false -- Never leave an attack or set-target order aimed at a portal.
	end
	local destination = CommandRegion(actual, p)
	if destination and home[id] and destination ~= home[id] then
		if not travelCommands[actual] or not mobileDefs[def] or not world.Route(home[id], destination, IsOpen) then
			blockedOrders = blockedOrders + 1
			return false
		end
	end
	-- Coordinate orders into the void are never valid construction or weapon targets.
	if #p >= 3 and not destination and (actual < 0 or positionCommands[actual]) then
		return false
	end
	return true
end
---@return boolean used
---@return boolean finished
function gadget:CommandFallback(id, def, team, cmd)
	if cmd == PORTAL then
		return true, false
	end -- RouteOrders starts it when it reaches the queue front.
	return false, false
end
function gadget:TeamDied(team)
	Spring.SetGameRulesParam("portal_team" .. team .. "_alive", 0)
end
function gadget:UnitPreDamaged(id, def, team, dmg)
	if beacons[id] then
		return 0, 0
	end
	return dmg, 1
end
function gadget:UnitDamaged(id, def, team, dmg)
	damage[team] = (damage[team] or 0) + dmg
end
function gadget:UnitDestroyed(id, def, team)
	if commanderDefs[def] and not Spring.GetUnitRulesParam(id, "unit_evolved") then
		local x, _, z = Spring.GetUnitPosition(id)
		local region = Region(x, z) or home[id] or TeamHome(team)
		pendingLoss[team] = { due = Spring.GetGameFrame() + 30, x = x, z = z, region = region }
		Log("COM_DESTROYED frame=" .. Spring.GetGameFrame() .. " team=" .. team .. " region=" .. tostring(region))
	end
	travelers[id] = nil
	home[id] = nil
	cooldown[id] = nil
	beacons[id] = nil
end
local function RemoveApproachOrders(id, trip)
	local remove = {}
	if trip.moveTag then
		remove[#remove + 1] = trip.moveTag
	end
	if trip.manual and trip.commandTag then
		remove[#remove + 1] = trip.commandTag
	end
	for _, command in ipairs(Spring.GetUnitCommands(id, -1)) do
		local destination = CommandRegion(command.id, command.params)
		if command.tag ~= trip.moveTag and destination and destination == trip.region then
			remove[#remove + 1] = command.tag
		end
	end
	if #remove > 0 then
		Spring.GiveOrderToUnit(id, CMD.REMOVE, remove, 0)
	end
end
local function SetHome(id, region)
	home[id] = region
	Spring.GiveOrderToUnit(id, GameCMD.UNIT_CANCEL_TARGET, {}, CMD.OPT_INTERNAL)
	if GG.CancelAircraftPadReservation then
		GG.CancelAircraftPadReservation(id)
	end
	if GG.ClearUnitTarget then
		GG.ClearUnitTarget(id)
	end
	Spring.SetUnitRulesParam(id, "portal_region", region, { allied = true, inlos = true })
	for _, cargo in ipairs(Spring.GetUnitIsTransporting(id) or {}) do
		RemoveApproachOrders(cargo, { region = home[cargo] })
		Spring.SetUnitTarget(cargo, nil)
		SetHome(cargo, region)
	end
end
local function HasTravelOrder(id, trip)
	for _, command in ipairs(Spring.GetUnitCommands(id, -1)) do
		if command.tag == trip.commandTag then
			return true
		end
	end
	return false
end
local function StepTravelers(frame)
	for id, trip in pairs(travelers) do
		local x, y, z = Spring.GetUnitPosition(id)
		local defID = Spring.GetUnitDefID(id)
		local def = defID and UnitDefs[defID]
		if Valid(id) and def and x and y and z then
			local m = mouths[trip.edge][trip.region]
			local nearMouth = (x - m.x) ^ 2 + (z - m.z) ^ 2 < PORTAL_RADIUS ^ 2
			local _, _, tag = Spring.GetUnitCurrentCommand(id)
			if tag ~= (trip.moveTag or trip.commandTag) or (not trip.moveTag and not nearMouth) then
				travelers[id] = nil
				-- An inserted waypoint may pause travel without clearing its queue.
				-- Drop only our approach; route again when the request reaches front.
				if trip.moveTag then
					Spring.GiveOrderToUnit(id, CMD.REMOVE, { trip.moveTag }, 0)
				end
			elseif (frame % 10 == 0 or nearMouth) and not HasTravelOrder(id, trip) then
				-- Removing the original queued order must also cancel its internal
				-- approach. Check periodically en route and before every activation.
				travelers[id] = nil
				if trip.moveTag then
					Spring.GiveOrderToUnit(id, CMD.REMOVE, { trip.moveTag }, 0)
				end
			end
			if travelers[id] and not Spring.MoveCtrl.GetTag(id) and nearMouth and (cooldown[id] or 0) <= frame then
				local to = mouths[trip.edge][trip.destination]
				local r = regions[trip.destination]
				local vx, vz = (r.x0 + r.x1) / 2 - to.x, (r.z0 + r.z1) / 2 - to.z
				local length = math.sqrt(vx * vx + vz * vz)
				if length < 1 then
					vx, vz, length = 1, 0, 1
				end
				local dx, dy, dz = FreeSpot(
					Spring.GetUnitDefID(id),
					to.x + vx / length * 340,
					to.z + vz / length * 340,
					trip.destination,
					to
				)
				if dx and dy and dz then
					-- Native cargo moves with ForcedMove; independent followers need
					-- their pre-transit offsets, including MoveCtrl-driven nanoframes.
					local companions, providerNames = {}, {}
					for name in pairs(transitMemberProviders) do
						providerNames[#providerNames + 1] = name
					end
					table.sort(providerNames)
					for _, name in ipairs(providerNames) do
						for _, child in ipairs(transitMemberProviders[name](id) or {}) do
							local transporter = Valid(child) and Spring.GetUnitTransporter(child)
							if child ~= id and Valid(child) and (not transporter or transporter == id) then
								local cx, cy, cz = Spring.GetUnitPosition(child)
								companions[child] = { cx, cy, cz, attached = transporter ~= nil }
							end
						end
					end
					Spring.SpawnCEG("portal-transit", x, y + 10, z, 0, 1, 0, 30)
					if def.canFly then
						Spring.SetUnitPosition(id, dx, dy + math.max(100, def.wantedHeight or 100), dz)
					else
						Spring.SetUnitPosition(id, dx, dz)
					end
					SetHome(id, trip.destination)
					for child, pos in pairs(companions) do
						RemoveApproachOrders(child, { region = home[child] })
						local cx = math.max(r.x0 + 24, math.min(r.x1 - 24, dx + pos[1] - x))
						local cz = math.max(r.z0 + 24, math.min(r.z1 - 24, dz + pos[3] - z))
						local cy = dy + math.max(20, pos[2] - y)
						if not pos.attached then
							if Spring.MoveCtrl.GetTag(child) then
								Spring.MoveCtrl.SetPosition(child, cx, cy, cz)
							else
								Spring.SetUnitPosition(child, cx, cy, cz)
							end
						end
						if home[child] ~= trip.destination then
							SetHome(child, trip.destination)
						end
						Spring.SetUnitVelocity(child, 0, 0, 0)
						Spring.SetUnitTarget(child, nil)
					end
					Spring.SetUnitVelocity(id, 0, 0, 0)
					Spring.SetUnitTarget(id, nil)
					cooldown[id] = frame + 90
					RemoveApproachOrders(id, trip)
					Spring.GiveOrderToUnit(id, CMD.WAIT, {}, 0)
					Spring.GiveOrderToUnit(id, CMD.WAIT, {}, 0)
					Spring.SpawnCEG("portal-transit", dx, dy + 10, dz, 0, 1, 0, 30)
					passages = passages + 1
					Spring.SetGameRulesParam("portal_passages", passages)
					Log(
						"TRANSIT frame="
							.. frame
							.. " id="
							.. id
							.. " from="
							.. trip.region
							.. " to="
							.. trip.destination
							.. " edge="
							.. trip.edge
					)
					travelers[id] = nil
				end
			end
		else
			travelers[id] = nil
		end
	end
end
local function RouteOrders()
	for id in pairs(home) do
		if home[id] and not travelers[id] and mobileDefs[Spring.GetUnitDefID(id)] then
			local commands = Spring.GetUnitCommands(id, 1)
			local command = commands and commands[1]
			local params = command and command.params or {}
			if command and command.id == PORTAL then
				local edge = params[1]
				if
					openEdges[edge]
					and world.Other(connections[edge], home[id])
					and (not params[2] or params[2] == home[id])
				then
					Route(id, home[id], nil, true, edge, command.tag)
				else
					Spring.GiveOrderToUnit(id, CMD.REMOVE, { command.tag }, 0)
				end
			end
			local destination = command and travelCommands[command.id] and CommandRegion(command.id, params)
			if command and destination and destination ~= home[id] then
				Route(id, home[id], destination, false, nil, command.tag)
			end
		end
	end
end
function gadget:GameFrame(f)
	for team, loss in pairs(pendingLoss) do
		if f >= loss.due then
			local comm = false
			for _, id in ipairs(Spring.GetTeamUnits(team) or {}) do
				if Valid(id) and commanderDefs[Spring.GetUnitDefID(id)] then
					comm = true
					break
				end
			end
			if not comm then
				OpenPortal(team, f, loss)
			end
			pendingLoss[team] = nil
		end
	end
	if f % 10 == 0 then
		RouteOrders()
	end
	StepTravelers(f)
	if f % 30 == 0 then
		for _, pair in pairs(mouths) do
			for _, m in pairs(pair) do
				Spring.SpawnCEG("portal-idle", m.x, m.y + 12, m.z, 0, 1, 0, 20)
			end
		end
	end
	if f % 5 == 0 then
		for id, region in pairs(home) do
			if Valid(id) and not Spring.GetUnitTransporter(id) then
				local x, y, z = Spring.GetUnitPosition(id)
				local aircraft = UnitDefs[Spring.GetUnitDefID(id)].canFly
				local r = aircraft and world.objectBounds[region] or regions[region]
				-- Aircraft may use their half of the cubicle barriers to turn.
				if
					(aircraft and not world.ContainsObject(region, x, z)) or (not aircraft and Region(x, z) ~= region)
				then
					local tx = math.max(r.x0 + 24, math.min(r.x1 - 24, x))
					local tz = math.max(r.z0 + 24, math.min(r.z1 - 24, z))
					if UnitDefs[Spring.GetUnitDefID(id)].canFly then
						Spring.SetUnitPosition(id, tx, y, tz)
					else
						Spring.SetUnitPosition(id, tx, tz)
					end
					Spring.SetUnitVelocity(id, 0, 0, 0)
					wallHits = wallHits + 1
				end
			end
		end
	end
	if f % 30 == 0 then
		for id, region in pairs(home) do
			local r = regions[region]
			if r.surface and r.surface.damage and Valid(id) then
				local x, y, z = Spring.GetUnitPosition(id)
				if y < r.surface.height + 2 and not Spring.GetUnitTransporter(id) then
					Spring.AddUnitDamage(id, r.surface.damage)
				end
			end
		end
	end
	if endFrame > 0 and f % 1800 == 0 then
		for _, entry in ipairs(world.teams) do
			local t = entry.team
			local factories, here, away = 0, 0, 0
			for _, id in ipairs(Spring.GetTeamUnits(t) or {}) do
				local def = UnitDefs[Spring.GetUnitDefID(id)]
				if def == nil then
					error("Team unit has no definition")
				end

				if def.isFactory then
					factories = factories + 1
				end
				if def.customParams.iscommander and f <= 5400 then
					local x, _, z = Spring.GetUnitPosition(id)
					local cmd, _, _, cx, cy, cz = Spring.GetUnitCurrentCommand(id)
					Log(
						"COMMANDER team="
							.. t
							.. " position="
							.. x
							.. ","
							.. z
							.. " cmd="
							.. tostring(cmd)
							.. " target="
							.. tostring(cx)
							.. ","
							.. tostring(cz)
					)
				end
				if home[id] == entry.region then
					here = here + 1
				else
					away = away + 1
				end
			end
			Log(
				string.format(
					"TEAM frame=%d team=%d region=%d units=%d created=%d factories=%d here=%d away=%d damage=%.1f",
					f,
					t,
					entry.region,
					#Spring.GetTeamUnits(t),
					created[t] or 0,
					factories,
					here,
					away,
					damage[t] or 0
				)
			)
		end
		Log(
			string.format(
				"STATE frame=%d passages=%d wallHits=%d blockedOrders=%d",
				f,
				passages,
				wallHits,
				blockedOrders
			)
		)
	end
	if endFrame > 0 and f >= endFrame then
		Spring.SetGameRulesParam("portal_done", 1)
	end
end
function gadget:Shutdown()
	GG.PortalWorlds = nil
end
