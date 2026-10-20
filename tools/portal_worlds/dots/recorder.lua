-- SPDX-License-Identifier: GPL-2.0-or-later
-- Read-only all-team diagnostics. This is never a player view or AI input.
local exportPath = "tools/portal_worlds/dots/export.lua"
local export = VFS.FileExists(exportPath) and VFS.Include(exportPath) or {}
local options = Spring.GetModOptions()
if tostring(options.portal_record or "0") ~= "1" and not export.enabled then return false end
-- Live capture is for AI-only matches; human gameplay uses the ordinary mode.
-- Replay export is a separate full-state observer capture.
if not export.enabled then
	for _, player in ipairs(Spring.GetPlayerList()) do
		local _, _, spectator = Spring.GetPlayerInfo(player, false)
		if not spectator then return false end
	end
end
local endFrame = export.end_frame or tonumber(options.portal_record_end)
local tag = "portal-dots-row"

-- Keep explicit empty arrays and absent values stable in the portable schema.
local function Array(values) values.array = true; return values end
local function JSON(value)
	local kind = type(value)
	if kind == "number" then
		if value ~= value or math.abs(value) == math.huge then return "null" end
		if value % 1 == 0 then return string.format("%d", value) end
		return string.format("%.8g", value)
	elseif kind == "boolean" then return tostring(value)
	elseif kind == "string" then
		return '"' .. value:gsub('[%z\1-\31\\"]', function(c)
			local escapes = {['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
			return escapes[c] or string.format("\\u%04x", c:byte())
		end) .. '"'
	elseif kind ~= "table" then return "null" end
	local parts = {}
	if value.array then
		for i = 1, #value do parts[#parts+1] = JSON(value[i]) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}; for k in pairs(value) do keys[#keys+1] = k end; table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts+1] = JSON(tostring(k)) .. ":" .. JSON(value[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

if not gadgetHandler:IsSyncedCode() then
	local file, path, failed, accelerated
	function gadget:Update()
		if not accelerated and options.portal_record_speed and Spring.GetGameFrame() > 0 then
			accelerated = true
			Spring.SendCommands("setspeed " .. options.portal_record_speed)
		end
	end
	local function Receive(_, line)
		-- Full-state output is restricted to an actual all-team spectator/replay.
		local spectator, fullView = Spring.GetSpectatingState()
		if failed or not (spectator and fullView) then return end
		-- Team colours are a local presentation property, unavailable to synced Lua.
		line = line:gsub('"color":"team:(%d+)"', function(id)
			local r, g, b = Spring.GetTeamColor(tonumber(id))
			return '"color":' .. JSON(Array({r,g,b}))
		end)
		if not file then
			Spring.CreateDir("recordings")
			path = "recordings/portal-dots-" .. os.date("%Y%m%d-%H%M%S") .. ".jsonl"
			local stem, suffix = path, 0
			while true do
				local previous = io.open(path, "r")
				if not previous then break end
				previous:close(); suffix = suffix + 1; path = stem .. "." .. suffix
			end
			file = io.open(path, "w")
			if not file then failed = true; Spring.Echo("[PORTAL_DOTS] cannot open recording"); return end
			Spring.Echo("[PORTAL_DOTS] " .. path)
		end
		if not file:write(line, "\n") then failed = true; file:close(); file = nil; return end
		if line:find('"type":"end"', 1, true) then
			file:flush(); file:close(); file = nil; failed = true
			Spring.Echo("[PORTAL_DOTS] complete")
			if options.portal_record_quit == "1" then Spring.SendCommands("quitforce") end
		end
	end
	function gadget:Initialize() gadgetHandler:AddSyncAction(tag, Receive) end
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(tag)
		if file then file:flush(); file:close() end
	end
	return
end

local metadata = VFS.FileExists("mapconfig/portal_worlds.lua") and VFS.Include("mapconfig/portal_worlds.lua")
local regions = metadata and metadata.regions or {{name=Game.mapName,x0=0,z0=0,x1=Game.mapSizeX,z1=Game.mapSizeZ}}
local cadence = 15 -- half a simulation second; damage and projectile births retain exact frames
local samples, events, done, started, lastSample = 0, 0, false, false, -1
local births, lastRegion, opened = {}, {}, {}
local function Region(x, z)
	if not x or not z then return 0 end
	for i, r in ipairs(regions) do
		if x >= r.x0 and z >= r.z0 and x < r.x1 and z < r.z1 then return i end
	end
	return 0
end
local function Position(id)
	local x, y, z = Spring.GetUnitPosition(id or -1)
	return x or false, y or false, z or false
end
local function Send(row) SendToUnsynced(tag, JSON(row)) end
local function Event(kind, data)
	if done or not started then return end
	events = events + 1
	Send({type="event",frame=Spring.GetGameFrame(),kind=kind,data=data})
end
local function Header()
	local teams, defs, weapons, maps = Array({}), {}, {}, Array({})
	for _, id in ipairs(Spring.GetTeamList()) do
		teams[#teams+1] = {id=id,ally=select(6,Spring.GetTeamInfo(id,false)),color="team:" .. id,
			income_multiplier=select(7,Spring.GetTeamInfo(id,false)) or 1}
	end
	for id, d in pairs(UnitDefs) do
		defs[tostring(id)] = {name=d.name,title=d.humanName or d.name,speed=d.speed,
			air=d.canFly,builder=d.isBuilder,factory=d.isFactory,immobile=d.isImmobile,
			commander=not not (d.customParams.iscommander or d.customParams.commtype or d.customParams.level),armed=#d.weapons > 0}
	end
	for id, d in pairs(WeaponDefs) do weapons[tostring(id)] = {name=d.name,type=d.type,range=d.range} end
	for _, r in ipairs(regions) do maps[#maps+1] = {name=r.name,x0=r.x0,z0=r.z0,x1=r.x1,z1=r.z1} end
	Send({type="header",format="portal-dots",version=1,fps=30,sample_frames=cadence,
		scenario=options.portal_worlds_test or options.zk_duels_test or "none",
		game=Game.gameShortName or Game.modShortName or Game.gameName,map=Game.mapName,
		width=Game.mapSizeX,height=Game.mapSizeZ,regions=maps,teams=teams,unit_defs=defs,weapon_defs=weapons,
		columns={units=Array({"id","def","team","x","y","z","hp","max_hp","build","command","tag","p1","p2","p3","region","born"}),
			projectiles=Array({"id","def","owner","team","x","y","z","source","region"}),
			economy=Array({"team","metal","metal_income","energy","energy_income"})}})
	started = true
end
local function Snapshot(frame)
	if lastSample == frame then return end
	lastSample = frame
	local units, shots, economy, portals = Array({}), Array({}), Array({}), Array({})
	local ids = Spring.GetAllUnits(); table.sort(ids)
	for _, id in ipairs(ids) do
		local x, y, z = Position(id)
		if x then
			local hp, maximum, _, _, build = Spring.GetUnitHealth(id)
			local command, _, commandTag, p1, p2, p3 = Spring.GetUnitCurrentCommand(id)
			local region = Region(x,z)
			units[#units+1] = Array({id,Spring.GetUnitDefID(id),Spring.GetUnitTeam(id),x,y,z,
				hp or 0,maximum or 0,build or 0,command or 0,commandTag or false,p1 or false,p2 or false,p3 or false,region,births[id] or 0})
			if lastRegion[id] and region > 0 and lastRegion[id] > 0 and lastRegion[id] ~= region then
				Event("transit",{id=id,from=lastRegion[id],to=region,x=x,z=z})
			end
			lastRegion[id] = region
		end
	end
	for _, id in ipairs(Spring.GetAllProjectiles(false,true)) do
		local x, y, z = Spring.GetProjectilePosition(id)
		if x then
			local p = GG.PortalIsolation and GG.PortalIsolation.projectiles[id]
			-- Rejected/deferred-deletion shots are diagnostics, not live weapons.
			if not (p and p.deleted) then
				shots[#shots+1] = Array({id,Spring.GetProjectileDefID(id) or -1,Spring.GetProjectileOwnerID(id) or -1,
					Spring.GetProjectileTeamID(id) or -1,x,y,z,p and p.region or 0,Region(x,z)})
			end
		end
	end
	for _, team in ipairs(Spring.GetTeamList()) do
		local metal, _, _, mi = Spring.GetTeamResources(team,"metal")
		local energy, _, _, ei = Spring.GetTeamResources(team,"energy")
		economy[#economy+1] = Array({team,metal or 0,mi or 0,energy or 0,ei or 0})
	end
	local portal = GG.PortalWorlds
	if portal then
		for edge, mouths in pairs(portal.mouths) do
			for region, m in pairs(mouths) do portals[#portals+1] = {edge=edge,region=region,x=m.x,z=m.z} end
			if not opened[edge] then Event("portal_open",{edge=edge}); opened[edge]=true end
		end
	end
	Send({type="sample",frame=frame,units=units,projectiles=shots,economy=economy,portals=portals})
	samples = samples + 1
end
local function Finish(reason, winners)
	if done then return end
	if not started then Header() end
	Snapshot(Spring.GetGameFrame())
	Send({type="end",frame=Spring.GetGameFrame(),reason=reason,winners=Array(winners or {}),samples=samples,events=events})
	done = true
end
function gadget:Initialize()
	for id in pairs(WeaponDefs) do Script.SetWatchProjectile(id,true) end
end
function gadget:GameFrame(frame)
	if done then return end
	if not started then Header() end
	if frame % cadence == 0 then Snapshot(frame) end
	if endFrame and endFrame > 0 and frame >= endFrame then Finish(export.enabled and "replay-end" or "frame-limit") end
end
function gadget:UnitCreated(id) births[id] = Spring.GetGameFrame(); lastRegion[id] = nil end
function gadget:UnitDestroyed(id, def, team, attacker)
	local x, y, z = Position(id)
	Event("death",{id=id,def=def,team=team,attacker=attacker or -1,x=x,y=y,z=z,region=Region(x,z)})
	births[id], lastRegion[id] = nil, nil
end
function gadget:ProjectileCreated(id, owner, weapon)
	local x, y, z = Spring.GetProjectilePosition(id)
	local p = GG.PortalIsolation and GG.PortalIsolation.projectiles[id]
	if x and not (p and p.deleted) then
		Event("shot",{id=id,owner=owner or -1,weapon=weapon,x=x,y=y,z=z,source=p and p.region or Region(x,z)})
	end
end
function gadget:UnitDamaged(id, def, team, damage, paralyzer, weapon, projectile, attacker)
	if damage <= 0 then return end
	local x, y, z = Position(id)
	local ax, ay, az = Position(attacker)
	local p = projectile and GG.PortalIsolation and GG.PortalIsolation.projectiles[projectile]
	Event("damage",{id=id,team=team,attacker=attacker or -1,weapon=weapon or -1,projectile=projectile or -1,
		amount=damage,paralyzer=paralyzer,x=x,y=y,z=z,ax=ax,ay=ay,az=az,region=Region(x,z),
		source=p and p.region or Region(ax,az),source_kind=p and "projectile" or "attacker-position"})
end
function gadget:GameOver(winners) Finish("game-over",winners) end
