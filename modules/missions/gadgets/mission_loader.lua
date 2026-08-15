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
		local Transfer = ModuleHandler.Get("transfer")
		for owner, batch in pairs(byOwner) do
			if fiat then
				Transfer.Give(batch, teamID)
			else
				Transfer.Units(batch, teamID, owner)
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
	end,
	Unprotect = function(name)
		local unitID = namedUnits[name]
		if unitID ~= nil and Spring.ValidUnitID(unitID) then
			ModuleHandler.Get("combat").Unprotect(unitID)
		end
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
					Spring.SetGameRulesParam("objective_" .. name, 1)
					Spring.Echo("[" .. LOG_TAG .. "] objective complete: " .. name)
					engine.OnEvent("mission.objective_changed")
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
	UnitDestroyed = function(_, unitID)
		local name = unitNames[unitID]
		if name ~= nil then
			Spring.SetGameRulesParam("mission_unit_dead_" .. name, 1)
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

---Destroy everything a previous arm spawned and reset the registry.
local function despawnRoster()
	for _, unitID in ipairs(spawnedUnits) do
		if Spring.ValidUnitID(unitID) then
			Spring.DestroyUnit(unitID, false, true)
		end
	end
	namedUnits, unitNames, groupUnits, spawnedUnits = {}, {}, {}, {}
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
			UnitDef = Verbs.UnitDef,
		})
		return file.Finalize()
	end)
	if not ok then
		Spring.Log(LOG_TAG, LOG.ERROR, tostring(entries))
		return nil
	end
	return entries
end

---Spawn parsed roster entries. Runs AFTER syncWatchedCallins so spawn-time
---callins (a unit born inside LOS) reach the latches; any failed spawn fails the load.
---@param entries MissionRosterEntry[]
---@param playerTeam MissionTeam
---@return boolean ok
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
		local x, z = entry.fx * Game.mapSizeX, entry.fz * Game.mapSizeZ
		local unitID = Spring.CreateUnit(entry.def, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
		if unitID == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "could not spawn roster unit " .. entry.def .. " (unit limit)")
			despawnRoster()
			return false
		end
		spawnedUnits[#spawnedUnits + 1] = unitID
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
local function loadMission(missionName)
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
	local parsed, err = pcall(function()
		for _, filePath in ipairs(files) do
			-- Identity is mission-relative so ids survive install-path differences.
			local filename = filePath:sub(#MISSIONS_DIR + 1)
			local file = DSL.ForFile(filename, staging.Register)
			local env = {
				When = file.When,
				Team = { Player = playerTeam },
				UnitDef = Verbs.UnitDef,
				Unit = Unit,
				Objective = Objective,
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
		Spring.Log(LOG_TAG, LOG.ERROR, tostring(err))
		return false
	end

	-- The commit point: the armed set is replaced, not amended, and the
	-- progress that belonged to it goes with it.
	engine = staging
	resetObjectives()
	syncWatchedCallins()
	-- CreateUnit raises; a bad roster is a load error, not a stack trace out
	-- of the chat action.
	local ran, spawned = pcall(spawnRoster, rosterEntries, playerTeam)
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
	Spring.Echo("[" .. LOG_TAG .. "] mission armed: " .. missionName .. " (" .. #engine.Triggers() .. " trigger(s))")
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
	elseif verb == "load" then
		perform("load", { mission = words[2] })
	elseif verb ~= nil and verb ~= "" then
		perform("load", { mission = verb })
	else
		Spring.Log(LOG_TAG, LOG.ERROR, "usage: /mission load <name> | /mission reload")
	end
	return true
end

function gadget:Initialize()
	-- The module's synced surface: what a caller outside this gadget may do
	-- with a mission. actions/ is the declared face of it.
	GG.Missions = {
		Load = loadMission,
		Reload = function()
			return activeMission ~= nil and loadMission(activeMission)
		end,
		Active = function()
			return activeMission
		end,
	}
	gadgetHandler:AddChatAction("mission", missionChatAction, "missions: /mission load <name> | /mission reload")
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

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("mission")
	GG.Missions = nil
end

---@param frame integer
function gadget:GameFrame(frame)
	if activeMission ~= nil and frame % EVALUATE_PERIOD == 0 then
		ctx.frame = frame
		engine.Evaluate(ctx)
	end
end
