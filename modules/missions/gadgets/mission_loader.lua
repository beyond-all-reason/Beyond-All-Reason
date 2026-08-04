local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission Loader",
		desc = "Loads mission trigger files (/luarules mission <name>) into the trigger engine and evaluates them on a cadence",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local LOG_TAG = "mission_loader"

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ChatGuard = VFS.Include("modules/missions/lib/chat_guard.lua")
local TriggerEngine = VFS.Include("modules/missions/lib/trigger_engine.lua")
local DSL = VFS.Include("modules/missions/lib/dsl.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")
local Roster = VFS.Include("modules/missions/lib/roster.lua")
local Objectives = VFS.Include("modules/missions/lib/objectives.lua")
local Placement = VFS.Include("modules/placement/api.lua")

local MISSIONS_DIR = "modules/missions/"
local EVALUATE_PERIOD = 15 -- frames

local engine = TriggerEngine.New()
local activeMission = nil ---@type string|nil

-- The roster registry: units spawned from units.lua. Destroyed/spotted state
-- is LATCHED into rulesparams by the forwarders below — engine-serialized, readable unsynced.
local namedUnits = {} ---@type table<string, integer> name -> unitID
local unitNames = {} ---@type table<integer, string> unitID -> name
local groupUnits = {} ---@type table<string, integer[]>
local spawnedUnits = {} ---@type integer[] everything the roster spawned, for reload cleanup
-- Protections THIS mission holds, by unit: combat's guard is a refcount, so
-- every arm that fires Protect again leans another count on it — the mission
-- must unwind its own on a fresh run or the hub stays invulnerable forever.
local protectCounts = {} ---@type table<integer, integer>

local function persistProtectLedger()
	local parts = {}
	for unitID, count in pairs(protectCounts) do
		parts[#parts + 1] = unitID .. ":" .. count
	end
	Spring.SetGameRulesParam("mission_protect_ledger", table.concat(parts, ","))
end
local silencedUnits = {} ---@type table<integer, boolean> spawned Neutral: holding fire until handed over

--- The engine's view of the world. Built once; frame is updated per tick.
---@type MissionContext
local ctx = {
	frame = 0,
	GetUnitDefCount = function(teamID, unitDefName)
		local unitDef = UnitDefNames[unitDefName]
		if unitDef == nil then
			return 0
		end
		-- GetTeamUnitDefCount includes nanoframes; Has() means finished units,
		-- so filter out anything still being built.
		local count = 0
		for _, unitID in ipairs(Spring.GetTeamUnitsByDefs(teamID, unitDef.id)) do
			if not Spring.GetUnitIsBeingBuilt(unitID) then
				count = count + 1
			end
		end
		return count
	end,
	IsObjectiveComplete = function(name)
		return Spring.GetGameRulesParam("objective_" .. name) == 1
	end,
	IsUnitDestroyed = function(name)
		return Spring.GetGameRulesParam("mission_unit_dead_" .. name) == 1
	end,
	IsUnitSpotted = function(name, allyTeamID)
		if Spring.GetGameRulesParam("mission_unit_spotted_" .. name .. "_" .. allyTeamID) == 1 then
			return true
		end
		-- The latch only catches the LOS edge. Vision granted with no edge to
		-- catch (/globallos mid-game) still answers yes, and latches so the
		-- answer survives the unit dying.
		local unitID = namedUnits[name]
		if unitID ~= nil and Spring.IsUnitInLos(unitID, allyTeamID) then
			Spring.SetGameRulesParam("mission_unit_spotted_" .. name .. "_" .. allyTeamID, 1)
			return true
		end
		return false
	end,
	---@param fiat boolean|nil skip the mode's say (Transfer.Give)
	TransferGroup = function(groupName, teamID, fiat)
		local units = groupUnits[groupName]
		if units == nil then
			Spring.Log(LOG_TAG, LOG.WARNING, "Transfer.Units: no roster group named " .. groupName)
			return
		end
		-- Policy is decided per giving team, so a group whose units were
		-- spawned for different teams asks once per owner.
		local byOwner = {}
		for _, unitID in ipairs(units) do
			if Spring.ValidUnitID(unitID) then
				local owner = Spring.GetUnitTeam(unitID)
				if owner ~= nil and owner ~= teamID then
					byOwner[owner] = byOwner[owner] or {}
					local batch = byOwner[owner]
					batch[#batch + 1] = unitID
				end
			end
		end
		-- Through the module that owns transfer, never Spring.TransferUnit
		-- here: one pipeline validates, prices and announces every handover,
		-- and the active mode's .Allow(Transfer.Units) is what opens it.
		--
		-- The engine clears the neutral flag as part of the transfer, so
		-- nothing here has to: measured, neutral=true team=2 going in,
		-- neutral=false team=0 coming out.
		--
		-- Hold fire is NOT cleared, and must be. A base that has changed hands
		-- is expected to defend its new owner, and an inherited outpost that
		-- sits out the waves it exists to survive is worse than one that never
		-- arrived.
		local Transfer = ModuleHandler.Get("transfer")
		for owner, batch in pairs(byOwner) do
			if fiat then
				Transfer.Give(batch, teamID)
			else
				Transfer.Units(batch, teamID, owner)
			end
		end
		for _, unitID in ipairs(units) do
			if silencedUnits[unitID] and Spring.ValidUnitID(unitID) then
				Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 2 }, 0)
				silencedUnits[unitID] = nil
			end
		end
	end,
	Protect = function(name)
		local unitID = namedUnits[name]
		if unitID == nil or not Spring.ValidUnitID(unitID) then
			Spring.Log(LOG_TAG, LOG.WARNING, "Combat.Protect: no living roster unit named " .. name)
			return
		end
		ModuleHandler.Get("combat").Protect(unitID)
		protectCounts[unitID] = (protectCounts[unitID] or 0) + 1
		persistProtectLedger()
	end,
	Unprotect = function(name)
		local unitID = namedUnits[name]
		if unitID ~= nil and Spring.ValidUnitID(unitID) then
			-- Only release what this mission holds: an unmatched Unprotect
			-- would eat someone else's guard.
			if (protectCounts[unitID] or 0) > 0 then
				ModuleHandler.Get("combat").Unprotect(unitID)
				protectCounts[unitID] = protectCounts[unitID] - 1
				if protectCounts[unitID] == 0 then
					protectCounts[unitID] = nil
				end
				persistProtectLedger()
			end
		end
	end,
	---Wave pressure, through the module that owns it. The mission names a
	---PACK; the flavor module turns that into a spec and the waves module
	---runs it — the same director a multiplayer game gets, at a different
	---intensity and with no bot on the field.
	---@param request table what Waves.Begin composed
	StartWaves = function(request)
		local flavor = ModuleHandler.Get(request.module)
		if flavor == nil or flavor.Start == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "Waves.Begin: module " .. tostring(request.module) .. " cannot start waves")
			return
		end
		flavor.Start(request)
	end,
	StopWaves = function(pack)
		ModuleHandler.Get("waves").Stop(pack)
	end,
	SetWaveIntensity = function(pack, intensity)
		ModuleHandler.Get("waves").SetIntensity(pack, intensity)
	end,
	SurgeWaves = function(pack)
		ModuleHandler.Get("waves").Surge(pack)
	end,
	WaveStatus = function(pack)
		return ModuleHandler.Get("waves").Status(pack)
	end,
}

---Demo rule: Team.Player is the first human team (lowest non-Gaia teamID with no Lua AI, not AI-hosted).
---@return MissionTeam|nil
local function resolvePlayerTeam()
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaiaTeamID then
			local _, _, _, isAiTeam, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if not isAiTeam and (Spring.GetTeamLuaAI(teamID) or "") == "" then
				return Verbs.MakeTeam(teamID, allyTeamID)
			end
		end
	end
	return nil
end

---Complete() is LAZY: builds an effect for Do, not run immediately. State
---lives in rulesparams (savegame-safe); writes have no callin, so Complete() emits "mission.objective_changed" for IsComplete()'s declared input.
---@param name string
---@return MissionObjective
local function Objective(name)
	return {
		Complete = function()
			return {
				execute = function()
					-- Idempotent: an objective with several ways to complete
					-- (OR disjuncts) completes once, whichever way fires later.
					if Spring.GetGameRulesParam("objective_" .. name) == 1 then
						return
					end
					Spring.SetGameRulesParam("objective_" .. name, 1)
					-- Completing implies revealing: the tracker must never owe
					-- the player a checkmark on a line it refused to draw.
					Spring.SetGameRulesParam("objective_revealed_" .. name, 1)
					Spring.Echo("[" .. LOG_TAG .. "] objective complete: " .. name)
					engine.OnEvent("mission.objective_changed")
				end,
			}
		end,
		-- Reveal is presentation state, not progress: it marks the objective
		-- relevant so the tracker widget draws it. Same objective_ prefix as
		-- Complete, so a fresh load sweeps both piles together.
		Reveal = function()
			return {
				execute = function()
					Spring.SetGameRulesParam("objective_revealed_" .. name, 1)
				end,
			}
		end,
		IsComplete = function()
			return {
				inputs = { "mission.objective_changed" },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsObjectiveComplete(name)
				end,
			}
		end,
	}
end

-- Engine callins the bus can forward; only callins some registered trigger
-- watches get hooked (don't-hook-what-you-don't-use), automatically per mission.
local FORWARDABLE_CALLINS = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken", "UnitEnteredLos" }

-- Most callins forward as bare bus events; these also latch roster-unit
-- state first — conditions read "has been", not "is right now".
local forwarders = {
	UnitDestroyed = function(_, unitID, _, _, attackerID, _, attackerTeam)
		local name = unitNames[unitID]
		if name ~= nil then
			Spring.SetGameRulesParam("mission_unit_dead_" .. name, 1)
			-- A named unit is story: its death is always worth a line, with
			-- enough attribution to tell a kill from a scripted despawn.
			Spring.Log(
				LOG_TAG,
				LOG.INFO,
				"roster unit destroyed: "
					.. name
					.. (
						attackerTeam ~= nil and (" (attacker team " .. tostring(attackerTeam) .. ")")
						or " (no attacker)"
					)
			)
		end
		engine.OnEvent("UnitDestroyed")
	end,
	UnitEnteredLos = function(_, unitID, _, allyTeam)
		local name = unitNames[unitID]
		if name ~= nil then
			Spring.SetGameRulesParam("mission_unit_spotted_" .. name .. "_" .. allyTeam, 1)
		end
		engine.OnEvent("UnitEnteredLos")
	end,
}

---(Re)hook engine callins to match the engine's watched-input set. Called
---after every mission (re)load, when the watch set may have changed.
local function syncWatchedCallins()
	local watched = engine.WatchedInputs()
	for _, name in ipairs(FORWARDABLE_CALLINS) do
		if watched[name] and gadget[name] == nil then
			gadget[name] = forwarders[name] or function()
				engine.OnEvent(name)
			end
			gadgetHandler:UpdateCallIn(name)
		elseif not watched[name] and gadget[name] ~= nil then
			gadget[name] = nil
			gadgetHandler:UpdateCallIn(name)
		end
	end
end

---Load the sandbox contributions of every module the missions manifest
---requires: modules/<name>/mission_dsl.lua returns a per-file factory. The
---requires list IS the whitelist of what mission files may say.
---@return MissionDslContribution[]
local function loadContributions()
	local contributions = {}
	local manifest = ModuleHandler.Discover().missions
	for _, name in ipairs(manifest.requires) do
		local path = "modules/" .. name .. "/mission_dsl.lua"
		if VFS.FileExists(path) then
			contributions[#contributions + 1] = VFS.Include(path)
		elseif VFS.FileExists("modules/" .. name .. "/types/dsl.lua") then
			-- The module publishes vocabulary but the runtime half is not visible.
			-- Usually a new file the engine has not rescanned: say so here, or the
			-- author sees a nil global in their trigger file and nothing else.
			Spring.Log(
				LOG_TAG,
				LOG.ERROR,
				name
					.. " declares mission vocabulary but "
					.. path
					.. " was not found; a mission using it will fail on a nil global (restart if it is a new file)"
			)
		end
	end
	return contributions
end

---The "enemy" roster role: the first non-Gaia team that is not the player's.
---@param playerTeamID integer
---@return integer|nil
local function resolveEnemyTeam(playerTeamID)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaiaTeamID and teamID ~= playerTeamID then
			return teamID
		end
	end
	return nil
end

---Destroy everything a previous arm spawned and reset the registry. The
---in-memory ledger dies with a /luarules reload, so the sweep also reads the
---persisted copy — otherwise a re-arm after a reload spawns the roster twice
---and the orphans keep shooting.
local function despawnRoster()
	-- Release every protection this mission holds before the field clears:
	-- combat's refcount survives a mission reload, so an unwound arm must
	-- give back exactly what it took or the next arm stacks on top.
	for unitID, count in pairs(protectCounts) do
		if Spring.ValidUnitID(unitID) then
			local combat = ModuleHandler.Get("combat")
			for _ = 1, count do
				combat.Unprotect(unitID)
			end
		end
	end
	protectCounts = {}
	persistProtectLedger()
	for _, unitID in ipairs(spawnedUnits) do
		if Spring.ValidUnitID(unitID) then
			Spring.DestroyUnit(unitID, false, true)
		end
	end
	local persisted = Spring.GetGameRulesParam("mission_spawned_units")
	if type(persisted) == "string" and persisted ~= "" then
		for idText in persisted:gmatch("[^,]+") do
			local unitID = tonumber(idText)
			if unitID ~= nil and Spring.ValidUnitID(unitID) then
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end
	Spring.SetGameRulesParam("mission_spawned_units", "")
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^mission_group_") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
	namedUnits, unitNames, groupUnits, spawnedUnits = {}, {}, {}, {}
	silencedUnits = {}
end

---A preserving reload keeps the field exactly as it stands: no despawn, no
---respawn — the locals rebind to the living units the previous arm left,
---from the bindings and ledgers it persisted. Dead stays dead (the latches
---already say so); silence re-derives from neutrality.
---@param entries table[]
local function rebindRoster(entries)
	namedUnits, unitNames, groupUnits, spawnedUnits = {}, {}, {}, {}
	silencedUnits = {}
	protectCounts = {}
	local heldLedger = Spring.GetGameRulesParam("mission_protect_ledger")
	if type(heldLedger) == "string" then
		for unitText, countText in heldLedger:gmatch("(%d+):(%d+)") do
			local unitID, count = tonumber(unitText), tonumber(countText)
			if unitID ~= nil and count ~= nil and Spring.ValidUnitID(unitID) then
				protectCounts[unitID] = count
			end
		end
	end
	local persisted = Spring.GetGameRulesParam("mission_spawned_units")
	if type(persisted) == "string" then
		for idText in persisted:gmatch("[^,]+") do
			local unitID = tonumber(idText)
			if unitID ~= nil and Spring.ValidUnitID(unitID) then
				spawnedUnits[#spawnedUnits + 1] = unitID
				if Spring.GetUnitNeutral ~= nil and Spring.GetUnitNeutral(unitID) then
					silencedUnits[unitID] = true
				end
			end
		end
	end
	for _, entry in ipairs(entries) do
		if entry.name ~= nil then
			local unitID = Spring.GetGameRulesParam("mission_unit_" .. entry.name)
			if type(unitID) == "number" and Spring.ValidUnitID(unitID) then
				namedUnits[entry.name] = unitID
				unitNames[unitID] = entry.name
			end
		end
	end
	for name in pairs(Spring.GetGameRulesParams()) do
		local group = name:match("^mission_group_(.+)$")
		if group ~= nil then
			groupUnits[group] = {}
			for idText in tostring(Spring.GetGameRulesParam(name) or ""):gmatch("[^,]+") do
				local unitID = tonumber(idText)
				if unitID ~= nil and Spring.ValidUnitID(unitID) then
					groupUnits[group][#groupUnits[group] + 1] = unitID
				end
			end
		end
	end
	return true
end

-- Which trigger ids have been published as fired. Derived, not progress: the
-- engine's own state is the truth, this only avoids re-writing a param that
-- has not changed.
local publishedFired = {} ---@type table<string, boolean>

---Publish what has FIRED, so an editor can shade a trigger it has watched
---happen. Deliberately not "is the condition true": a once-trigger stays
---fired after its condition goes false, and an editor shading off the live
---condition would flicker back to unfired.
local function publishFired()
	for id in pairs(engine.GetState().fired) do
		if not publishedFired[id] then
			publishedFired[id] = true
			Spring.SetGameRulesParam("mission_trigger_fired_" .. id, 1)
		end
	end
end

---Erase the fired pile. Progress clears with the triggers, so a reload is a
---fresh run and the editor stops showing last run's progression.
local function resetFired()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^mission_trigger_fired_") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
	publishedFired = {}
end

---Erase the objective progress pile. The loader owns the objective_ prefix;
---progress clears with the triggers, so a reload is a fresh run and a
---completed objective cannot re-fire victory on the next cadence.
local function resetObjectives()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^objective_") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
end

---Publish the tracker's board: display order, titles, foreshadow flags —
---all under the objective_ prefix, so presentation sweeps with progress and
---the widget derives the whole board from rulesparams with no manifest of
---its own.
---@param declarations MissionObjectiveDeclarationEntry[]|nil nil when the mission has no objectives.lua
local function publishObjectives(declarations)
	if declarations == nil then
		return
	end
	local order = {}
	for _, decl in ipairs(declarations) do
		order[#order + 1] = decl.id
		Spring.SetGameRulesParam("objective_title_" .. decl.id, decl.title)
		Spring.SetGameRulesParam("objective_foreshadow_" .. decl.id, decl.foreshadow and 1 or nil)
	end
	Spring.SetGameRulesParam("objective_display_order", table.concat(order, ","))
	-- Opening lines are revealed by arming itself: every line with no
	-- declared moment and no completable predecessor (marked when the
	-- cadence triggers were derived).
	for _, decl in ipairs(declarations) do
		if decl.revealAtArm then
			Spring.SetGameRulesParam("objective_revealed_" .. decl.id, 1)
		end
	end
end

---VFS.Include wraps a Lua error in engine bookkeeping — the include mode, the
---pcall depth, the environment flag — and buries the one line an author needs
---in the middle of it. A mission file that names a unit wrong should read as a
---mission problem, not as a VFS problem, so this unwraps it:
---
---  [LuaVFS::Include(synced=true)][pcall] file=<path> error=2 (<msg>) ptop=2 ...
---
---becomes `<mission-relative path>: <msg>`. Anything that does not match the
---wrapper is passed through untouched — a surprise is better read raw than
---mangled by a pattern that did not expect it.
---@param err any
---@return string
local function readableLoadError(err)
	local text = tostring(err)
	-- Anchored on both ends of the wrapper so a message containing its own
	-- parentheses (they usually do — `Named(...)`) still comes out whole.
	local inner = text:match("error=%-?%d+ %((.*)%) ptop=")
	if inner == nil then
		return text
	end
	local path = text:match("file=(%S+)")
	-- The chunk name and line point into the DSL, where the CHECK lives. The
	-- mistake is in the mission file, which the message already names.
	inner = inner:gsub('^%[string "[^"]*"%]:%d+: ', "")
	if path ~= nil then
		return (path:gsub("^" .. MISSIONS_DIR, "")) .. ": " .. inner
	end
	return inner
end

---Load units.lua through its sandbox (Spawn chains; the sandbox IS the API
---surface). Parses before trigger files load, so Unit/Units references validate against declared names at load.
---@param missionName string
---@return MissionRosterEntry[]|nil entries nil on a load error; {} when the mission has no roster
local function parseRoster(missionName)
	local rosterPath = MISSIONS_DIR .. missionName .. "/units.lua"
	if not VFS.FileExists(rosterPath) then
		return {}
	end
	local ok, entries = pcall(function()
		local file = Roster.ForFile(missionName .. "/units.lua")
		VFS.Include(rosterPath, {
			Spawn = file.Spawn,
			Claim = file.Claim,
			UnitDef = Verbs.UnitDef,
		})
		return file.Finalize()
	end)
	if not ok then
		Spring.Log(LOG_TAG, LOG.ERROR, readableLoadError(entries))
		return nil
	end
	return entries
end

---Spawn parsed roster entries. Runs AFTER syncWatchedCallins so spawn-time
---callins (a unit born inside LOS) reach the latches; any failed spawn fails the load.
---@param entries MissionRosterEntry[]
---@param playerTeam MissionTeam
---@return boolean ok
---The unit a Claim entry should bind to, if the team already has one. Picks
---the lowest unit id so two clients of the same game agree: GetTeamUnits order
---is not promised, and a mission that bound a different unit per client would
---desync the moment a trigger asked about it.
---@param teamID integer
---@param defName string
---@return integer|nil
local function existingUnitOf(teamID, defName)
	local wanted = UnitDefNames[defName]
	if wanted == nil then
		return nil
	end
	local found = nil
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
		if Spring.GetUnitDefID(unitID) == wanted.id and (found == nil or unitID < found) then
			found = unitID
		end
	end
	return found
end

local function spawnRoster(entries, playerTeam)
	despawnRoster()
	local teamFor = {
		player = playerTeam.teamID,
		gaia = Spring.GetGaiaTeamID(),
		enemy = resolveEnemyTeam(playerTeam.teamID),
	}
	local allyTeams = Spring.GetAllyTeamList()
	for _, entry in ipairs(entries) do
		local teamID = teamFor[entry.team]
		if teamID == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, 'roster needs an "' .. entry.team .. '" team but none exists')
			despawnRoster()
			return false
		end
		-- CreateUnit RAISES on an unknown def name; nil is the unit limit.
		if UnitDefNames[entry.def] == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "roster unit " .. entry.def .. ": no such unit def")
			despawnRoster()
			return false
		end
		-- A claim takes what is already standing; only an empty seat is built
		-- for. Ownership follows: the mission cleans up what it created and
		-- leaves alone what it borrowed.
		local unitID = entry.claim and existingUnitOf(teamID, entry.def) or nil
		local claimed = unitID ~= nil
		if unitID == nil then
			local wantX, wantZ = entry.fx * Game.mapSizeX, entry.fz * Game.mapSizeZ
			-- Positions are map fractions so a roster plays on any map, which
			-- means the author cannot know what is at that point on THIS one.
			-- Ask placement for the nearest spot the unit can actually stand
			-- on: an exact hit costs one test and moves nothing, and a fraction
			-- that lands on a cliff, off the edge, or inside something else
			-- gets nudged rather than spawning a unit nobody can use.
			--
			-- Surface is deliberately unconstrained: a roster may want a ship.
			local def = UnitDefNames[entry.def]
			local footprint = math.max(def.xsize or 8, def.zsize or 8) * 4
			local x, y, z, why = Placement.NearestValid(wantX, wantZ, {
				radius = footprint * 6,
				footprint = footprint,
				surface = "any",
			})
			if x == nil then
				Spring.Log(
					LOG_TAG,
					LOG.ERROR,
					"no room for roster unit "
						.. entry.def
						.. " near ("
						.. math.floor(wantX)
						.. ","
						.. math.floor(wantZ)
						.. "): "
						.. tostring(why)
				)
				despawnRoster()
				return false
			end
			unitID = Spring.CreateUnit(entry.def, x, y, z, 0, teamID)
			if unitID == nil then
				Spring.Log(LOG_TAG, LOG.ERROR, "could not spawn roster unit " .. entry.def .. " (unit limit)")
				despawnRoster()
				return false
			end
		end
		if not claimed then
			spawnedUnits[#spawnedUnits + 1] = unitID
		end
		-- Only ever applied to what the mission placed. A claimed unit belongs
		-- to a team that is presumably using it.
		if entry.neutral and not claimed then
			-- Neutral stops the unit being SHOT AT automatically. It does not
			-- stop it shooting, which is the half that matters for a derelict
			-- the player is sent to walk up to. Hold fire is what silences it,
			-- and it is the pairing ai_ruins uses for the same reason.
			Spring.SetUnitNeutral(unitID, true)
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
			silencedUnits[unitID] = true
		end
		if entry.name ~= nil then
			namedUnits[entry.name] = unitID
			unitNames[unitID] = entry.name
			-- Publish the binding and reset latches a previous arm (or its
			-- despawn above) may have set.
			Spring.SetGameRulesParam("mission_unit_" .. entry.name, unitID)
			Spring.SetGameRulesParam("mission_unit_dead_" .. entry.name, 0)
			-- Seed spotted from what each allyteam can see RIGHT NOW, not 0:
			-- UnitEnteredLos is an edge, and a unit that spawns already visible
			-- never crosses it. /globallos and a spawn inside friendly vision
			-- both land here, and the latch would otherwise never be set.
			for _, allyTeamID in ipairs(allyTeams) do
				local visible = Spring.IsUnitInLos(unitID, allyTeamID)
				Spring.SetGameRulesParam("mission_unit_spotted_" .. entry.name .. "_" .. allyTeamID, visible and 1 or 0)
			end
		end
		if entry.group ~= nil then
			groupUnits[entry.group] = groupUnits[entry.group] or {}
			local group = groupUnits[entry.group]
			group[#group + 1] = unitID
		end
	end
	return true
end

---Load (or reload) a mission: the sandbox IS the API surface. One
---transaction — the incoming mission arms into a staging engine that is
---swapped in whole, so a file that fails to parse leaves the running mission
---untouched and nothing of the outgoing one survives a reload or a switch.
---@param missionName string
---@return boolean loaded
---@param missionName string
---@param preserve boolean|nil keep progress and the field: the editor nudging
---a number mid-run is not a request to start over. Only meaningful when the
---same mission re-arms; a switch is always a fresh run.
local function loadMission(missionName, preserve)
	preserve = preserve == true
		and (activeMission == missionName or Spring.GetGameRulesParam("mission_name") == missionName)
	local triggersDir = MISSIONS_DIR .. missionName .. "/triggers/"
	local files = VFS.DirList(triggersDir, "*.lua")
	if #files == 0 then
		Spring.Log(LOG_TAG, LOG.ERROR, "no trigger files under " .. triggersDir)
		return false
	end
	table.sort(files)

	local playerTeam = resolvePlayerTeam()
	if playerTeam == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "no human team found for Team.Player")
		return false
	end

	-- The manifest names the story's factions. The lobby is the enforcement
	-- point (it sets sides before the game exists); this is the backstop that
	-- says WHY the beats look wrong when someone arrives as the wrong side.
	local manifestPath = MISSIONS_DIR .. missionName .. "/mission.lua"
	if VFS.FileExists(manifestPath) then
		local ok, manifest = pcall(VFS.Include, manifestPath)
		if ok and type(manifest) == "table" and type(manifest.sides) == "table" then
			local want = VFS.Include("modules/missions/lib/sides.lua").Resolve(manifest.sides.player)
			local side = select(5, Spring.GetTeamInfo(playerTeam.teamID, false))
			if want ~= nil and type(side) == "string" and side ~= "" and side:lower() ~= want.name:lower() then
				Spring.Echo(
					"["
						.. LOG_TAG
						.. "] "
						.. missionName
						.. " is written for a "
						.. want.name
						.. " player; this game's player is "
						.. side
						.. ". The mission will run, but its roster and beats assume "
						.. want.name
						.. "."
				)
			end
		end
	end

	-- Roster parses before trigger files load, so Unit/Units references
	-- validate against declared names — a typo is a load error, not a silent never-true condition.
	local rosterEntries = parseRoster(missionName)
	if rosterEntries == nil then
		return false
	end
	local rosterNames = {} ---@type table<string, boolean>
	local rosterGroups = {} ---@type table<string, boolean>
	for _, entry in ipairs(rosterEntries) do
		if entry.name ~= nil then
			rosterNames[entry.name] = true
		end
		if entry.group ~= nil then
			rosterGroups[entry.group] = true
		end
	end

	local contributions = loadContributions()
	local Unit = Verbs.MakeUnit(rosterNames)

	-- Staging: nothing armed changes until every file has parsed. The
	-- includes are as unprotected as the roster's, and fail the same way.
	local staging = TriggerEngine.New()
	local objectiveDecls = nil ---@type MissionObjectiveDeclarationEntry[]|nil
	local declaredObjectives = nil ---@type table<string, boolean>|nil
	local parsed, err = pcall(function()
		-- The definition site parses first: objectives.lua declares the ids
		-- the trigger files may speak, and its declarations compile into
		-- ordinary triggers through the same DSL — same AND composition,
		-- same positional identity, same fired-latch persistence.
		local objectivesPath = MISSIONS_DIR .. missionName .. "/objectives.lua"
		if VFS.FileExists(objectivesPath) then
			local filename = missionName .. "/objectives.lua"
			local file = Objectives.ForFile(filename)
			local env = {
				Objective = file.Objective,
				Team = { Player = playerTeam },
				UnitDef = Verbs.UnitDef,
				Unit = Unit,
			}
			local fileContributions = {}
			for _, contribution in ipairs(contributions) do
				local forFile = contribution.ForFile({
					filename = filename,
					Register = staging.Register,
					names = rosterNames,
					groups = rosterGroups,
				})
				for key, value in pairs(forFile.env) do
					if env[key] ~= nil then
						error(filename .. ": two modules contribute the global " .. key)
					end
					env[key] = value
				end
				fileContributions[#fileContributions + 1] = forFile
			end
			VFS.Include(objectivesPath, env)
			objectiveDecls = file.Finalize()
			for _, forFile in ipairs(fileContributions) do
				if forFile.Finalize then
					forFile.Finalize()
				end
			end
			declaredObjectives = {}
			for _, decl in ipairs(objectiveDecls) do
				declaredObjectives[decl.id] = true
			end

			local derived = DSL.ForFile(filename, staging.Register)
			-- The cadence predecessor: the nearest earlier line that CAN
			-- complete. Standing objectives (no completion) are transparent
			-- to the cadence — a line that never completes must not dam it.
			local prevCompletable = nil
			for _, decl in ipairs(objectiveDecls) do
				-- One trigger per disjunct: OR is multiple triggers, exactly
				-- as it is in the trigger files. Complete is idempotent, so a
				-- second way firing later is a no-op.
				for _, group in ipairs(decl.completions) do
					local chain = derived.When(group[1])
					for i = 2, #group do
						chain = chain.When(group[i])
					end
					chain.Do(Objective(decl.id).Complete())
				end
				-- The reveal cadence, one line behind the completion chain.
				-- A line with no moment and no completable predecessor needs
				-- no trigger — arming reveals it (publishObjectives).
				local revealedWhen = decl.revealedWhen
				if revealedWhen == nil and prevCompletable ~= nil then
					revealedWhen = Objective(prevCompletable.id).IsComplete()
				end
				if revealedWhen ~= nil then
					derived.When(revealedWhen).Do(Objective(decl.id).Reveal())
				else
					decl.revealAtArm = true
				end
				if #decl.completions > 0 then
					prevCompletable = decl
				end
			end
			derived.Finalize()
		end

		for _, filePath in ipairs(files) do
			-- Identity is mission-relative so ids survive install-path differences.
			local filename = filePath:sub(#MISSIONS_DIR + 1)
			local file = DSL.ForFile(filename, staging.Register)
			-- With a definition site in play, speaking an undeclared id is a
			-- load error naming this file — the roster's contract for Unit.
			local ObjectiveVerb = Objective
			if declaredObjectives ~= nil then
				ObjectiveVerb = function(name)
					if not declaredObjectives[name] then
						error(
							filename
								.. ': Objective("'
								.. tostring(name)
								.. '") — objectives.lua declares no such objective'
						)
					end
					return Objective(name)
				end
			end
			local env = {
				When = file.When,
				Team = { Player = playerTeam },
				UnitDef = Verbs.UnitDef,
				Unit = Unit,
				Objective = ObjectiveVerb,
			}
			-- Each required module adds its vocabulary; a name collision between
			-- modules is a load error, not a silent shadow.
			local fileContributions = {}
			for _, contribution in ipairs(contributions) do
				local forFile = contribution.ForFile({
					filename = filename,
					Register = staging.Register,
					names = rosterNames,
					groups = rosterGroups,
				})
				for key, value in pairs(forFile.env) do
					if env[key] ~= nil then
						error(filename .. ": two modules contribute the global " .. key)
					end
					env[key] = value
				end
				fileContributions[#fileContributions + 1] = forFile
			end
			VFS.Include(filePath, env)
			-- Statements register here, and a half-finished chain (no Do) is a
			-- load error naming the file and statement.
			file.Finalize()
			for _, forFile in ipairs(fileContributions) do
				if forFile.Finalize then
					forFile.Finalize()
				end
			end
		end
	end)
	if not parsed then
		Spring.Log(LOG_TAG, LOG.ERROR, readableLoadError(err))
		return false
	end

	-- The commit point: the armed set is replaced, not amended. On a fresh
	-- run the progress that belonged to it goes with it; on a preserving
	-- reload the save pile is re-applied over the new definitions — fired
	-- stays fired, countdowns keep counting (heldSince rides along), and the
	-- editor nudging one number does not restart the mission.
	local savedState = preserve and engine.GetState() or nil
	engine = staging
	if preserve then
		-- After a /luarules reload the previous engine is gone; fired at
		-- least survives in the params. heldSince cannot, so countdowns
		-- restart in that one path — the honest floor.
		savedState = savedState or { fired = {}, heldSince = {} }
		for name in pairs(Spring.GetGameRulesParams()) do
			local id = name:match("^mission_trigger_fired_(.+)$")
			if id ~= nil then
				savedState.fired[id] = true
			end
		end
		engine.SetState(savedState)
		publishedFired = {}
		for id in pairs(savedState.fired) do
			publishedFired[id] = true
		end
	else
		resetObjectives()
		resetFired()
	end
	syncWatchedCallins()
	-- CreateUnit raises; a bad roster is a load error, not a stack trace out
	-- of the chat action.
	local ran, spawned
	if preserve then
		ran, spawned = pcall(rebindRoster, rosterEntries)
	else
		ran, spawned = pcall(spawnRoster, rosterEntries, playerTeam)
	end
	if not ran then
		Spring.Log(LOG_TAG, LOG.ERROR, tostring(spawned))
		despawnRoster()
	end
	if not ran or not spawned then
		activeMission = nil
		Spring.SetGameRulesParam("mission_active", 0)
		return false
	end
	activeMission = missionName
	Spring.SetGameRulesParam("mission_active", 1)
	Spring.SetGameRulesParam("mission_name", missionName)
	publishObjectives(objectiveDecls)
	-- The ledger, persisted: a /luarules reload wipes every local, and the
	-- re-arm in Initialize needs to know what the previous life spawned.
	Spring.SetGameRulesParam("mission_spawned_units", table.concat(spawnedUnits, ","))
	for groupName, units in pairs(groupUnits) do
		Spring.SetGameRulesParam("mission_group_" .. groupName, table.concat(units, ","))
	end
	Spring.Echo(
		"["
			.. LOG_TAG
			.. "] mission armed: "
			.. missionName
			.. " ("
			.. #engine.Triggers()
			.. " trigger(s))"
			.. (preserve and " — progress preserved" or "")
	)
	return true
end

---Run one of the module's declared actions, refusing on its own
---precondition. The guard, the name check and "is anything armed" live in
---actions/, not here: this is the calling convention, not the behaviour.
---@param name string action file name under actions/
---@param request table|nil
---@return boolean ran
local function perform(name, request)
	-- The module's own surface travels in the request: an action file runs in
	-- the registrar's environment, where the gadget's GG is not visible.
	request = request or {}
	request.loader = GG.Missions
	local action = ModuleHandler.LoadActions("missions").byName[name]
	if action == nil then
		Spring.Log(LOG_TAG, LOG.ERROR, "missions has no action named " .. tostring(name))
		return false
	end
	if action.validate then
		local allowed, reason = action.validate(request)
		if not allowed then
			Spring.Log(LOG_TAG, LOG.ERROR, "mission." .. name .. ": " .. tostring(reason))
			return false
		end
	end
	return action.execute(request) and true or false
end

--- `/mission load <name>` and `/mission reload`, with the bare
--- `/luarules mission <name>` kept working: it is what the in-game panel and
--- every existing note still say.
---@param cmd string
---@param line string
---@param words string[]
local function missionChatAction(cmd, line, words, playerID)
	-- Synced chat actions arrive from ANY player in multiplayer; arming or reloading a mission is not an open verb.
	if not ChatGuard.IsAllowed(BAR.Utilities.Gametype.IsSinglePlayer(), Spring.IsCheatingEnabled()) then
		Spring.Log(
			LOG_TAG,
			LOG.WARNING,
			"/mission refused: multiplayer without cheats (player " .. tostring(playerID) .. ")"
		)
		return true
	end
	local verb = words[1]
	if verb == "reload" then
		perform("reload")
	elseif verb == "restart" then
		perform("restart")
	elseif verb == "load" then
		perform("load", { mission = words[2] })
	elseif verb ~= nil and verb ~= "" then
		perform("load", { mission = verb })
	else
		Spring.Log(LOG_TAG, LOG.ERROR, "usage: /mission load <name> | /mission reload | /mission restart")
	end
	return true
end

local rearmAfterLuaReload

function gadget:Initialize()
	-- The module's synced surface: what a caller outside this gadget may do
	-- with a mission. actions/ is the declared face of it.
	GG.Missions = {
		Load = loadMission,
		---The hot-patch: same mission, new definitions, progress preserved.
		Reload = function()
			return activeMission ~= nil and loadMission(activeMission, true)
		end,
		---The fresh run: same mission from the top.
		Restart = function()
			return activeMission ~= nil and loadMission(activeMission)
		end,
		Active = function()
			return activeMission
		end,
		---The mission bus, open to other modules.
		---
		---Engine callins reach the engine through syncWatchedCallins; a module
		---event has no callin to hook, so the module that raises it says so
		---here. Same convention mission.objective_changed already uses
		---internally — this only makes it reachable from outside.
		---@param name MissionEventName
		OnEvent = function(name)
			engine.OnEvent(name)
		end,
	}
	gadgetHandler:AddChatAction(
		"mission",
		missionChatAction,
		"missions: /mission load <name> | /mission reload | /mission restart"
	)
	rearmAfterLuaReload()
end

---A lobby that picked a mission on the game axis wrote it into the
---mission_name modoption; arm it when the game starts. "none" is the wire
---value for no mission. The chat command and the editor can still arm
---whatever they like later — this is only the game-start path.
function gadget:GameStart()
	local fromLobby = Spring.GetModOptions().mission_name
	if fromLobby ~= nil and fromLobby ~= "" and fromLobby ~= "none" then
		loadMission(fromLobby)
	end
end

---A /luarules reload mid-match wipes every local and GameStart does not come
---again — the mission silently disarmed, triggers stopped firing, and the
---reload action answered "no active mission". The armed name survives in the
---rules params, so a reload re-arms it: same semantics as /mission reload
---(the persisted ledger despawns the previous roster before the respawn).
rearmAfterLuaReload = function()
	if Spring.GetGameFrame() <= 0 then
		return
	end
	if Spring.GetGameRulesParam("mission_active") ~= 1 then
		return
	end
	local armed = Spring.GetGameRulesParam("mission_name")
	if type(armed) == "string" and armed ~= "" then
		Spring.Echo("[" .. LOG_TAG .. "] re-arming " .. armed .. " after luarules reload")
		loadMission(armed, true)
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("mission")
	GG.Missions = nil
end

---@param frame integer
function gadget:GameFrame(frame)
	if activeMission ~= nil and frame % EVALUATE_PERIOD == 0 then
		ctx.frame = frame
		engine.Evaluate(ctx)
		publishFired()
	end
end
