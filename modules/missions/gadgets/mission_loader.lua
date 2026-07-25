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

-- The roster registry: units spawned from the mission's units.lua.
-- Destroyed/spotted state is LATCHED into rulesparams (mission_unit_dead_*,
-- mission_unit_spotted_*) by the forwarders below — engine-serialized and
-- readable unsynced, same home as objective completion.
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
		return Spring.GetGameRulesParam("mission_unit_spotted_" .. name .. "_" .. allyTeamID) == 1
	end,
	TransferGroup = function(groupName, teamID)
		local units = groupUnits[groupName]
		if units == nil then
			Spring.Log(LOG_TAG, LOG.WARNING, "Units.Transfer: no roster group named " .. groupName)
			return
		end
		for _, unitID in ipairs(units) do
			if Spring.ValidUnitID(unitID) then
				Spring.TransferUnit(unitID, teamID, true)
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

---Demo rule (documented in hello_pawns_plan.md): Team.Player is the first
---human team — lowest non-Gaia teamID with no Lua AI and not the AI-hosted kind.
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

---Objective verb, demo-minimal. Closure-free surface: Complete() is LAZY —
---it builds an effect the engine executes when the trigger fires, so mission
---files chain it with Do instead of wrapping it in a function. IsComplete()
---is the condition side, so victory can be its own trigger driven by
---objective state (the "all objectives complete -> win" shape in miniature).
---Completion state lives in rulesparams (objective_<name>) —
---engine-serialized, so it survives a savegame like the rest of the trigger
---progress pile.
---
---Rulesparam changes have no callin, but this module is the thing that
---completes objectives — so Complete() emits "mission.objective_changed" on
---the mission bus, and IsComplete() declares it as its input (see
---mission_authoring_dsl.md, "Conditions declare their inputs").
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

-- Engine callins the bus can forward. The gadget hooks ONLY the callins some
-- registered trigger actually watches (the don't-hook-what-you-don't-use
-- rule, applied automatically per mission); everything else stays unhooked.
local FORWARDABLE_CALLINS = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken", "UnitEnteredLos" }

-- Most callins forward as bare bus events; these also latch roster-unit
-- state into rulesparams first (conditions read the latch — "has been
-- destroyed/spotted", not "is right now").
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

---The MatchFlow verbs injected into mission files: same names as the module
---api, but LAZY — Victory(team) builds an effect for a Do chain; the module's
---imperative api fires only when the trigger does. Takes the Team handle, not
---a raw allyTeam id, so the mission line reads as English.
---@param matchflowApi table the matchflow module api (ModuleHandler.Get)
---@return MissionMatchFlow
local function makeMatchFlowVerbs(matchflowApi)
	return {
		---The mission-start condition. Empty inputs = evaluated once when the
		---trigger arms (never event-driven after that) — arming IS the
		---mission starting, so it holds at the first cadence tick.
		---@return MissionCondition
		Started = function()
			return {
				inputs = {},
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.frame > 0
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionEffect
		Victory = function(team)
			assert(type(team) == "table" and type(team.allyTeam) == "number", "MatchFlow.Victory expects a Team handle (e.g. Team.Player)")
			return {
				execute = function()
					matchflowApi.Victory(team.allyTeam)
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionEffect
		Defeat = function(team)
			assert(type(team) == "table" and type(team.allyTeam) == "number", "MatchFlow.Defeat expects a Team handle (e.g. Team.Player)")
			return {
				execute = function()
					matchflowApi.Defeat({ team.allyTeam })
				end,
			}
		end,
	}
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

---Spawn the mission's units.lua roster (optional — trigger-only missions
---stay legal). Runs AFTER syncWatchedCallins so spawn-time callins (a unit
---born inside LOS) reach the latches. Any failed spawn fails the load:
---roster names are story-critical.
---@param missionName string
---@param playerTeam MissionTeam
---@return boolean ok
local function spawnRoster(missionName, playerTeam)
	despawnRoster()
	local rosterPath = MISSIONS_DIR .. missionName .. "/units.lua"
	if not VFS.FileExists(rosterPath) then
		return true
	end
	local ok, entries = pcall(function()
		return Roster.Parse(VFS.Include(rosterPath))
	end)
	if not ok then
		Spring.Log(LOG_TAG, LOG.ERROR, tostring(entries))
		return false
	end

	local teamFor = {
		player = playerTeam.teamID,
		gaia = Spring.GetGaiaTeamID(),
		enemy = resolveEnemyTeam(playerTeam.teamID),
	}
	local allyTeams = Spring.GetAllyTeamList()
	for _, entry in ipairs(entries) do
		local teamID = teamFor[entry.team]
		if teamID == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "roster needs an \"" .. entry.team .. "\" team but none exists")
			despawnRoster()
			return false
		end
		local y = Spring.GetGroundHeight(entry.x, entry.z)
		local unitID = Spring.CreateUnit(entry.def, entry.x, y, entry.z, entry.facing, teamID)
		if unitID == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "could not spawn roster unit " .. entry.def .. " (unknown def or unit limit)")
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
			for _, allyTeamID in ipairs(allyTeams) do
				Spring.SetGameRulesParam("mission_unit_spotted_" .. entry.name .. "_" .. allyTeamID, 0)
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

---Load (or reload) a mission: run each triggers/*.lua through the injected
---environment. The sandbox IS the API surface — trigger files see the
---injected verbs and nothing else. Arming clears every armed trigger first
---(filenames are mission-qualified, so per-file unregistration alone would
---leak the previous mission's triggers across a switch); reloading the same
---mission is the same path.
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

	local armedFiles = {}
	for _, trigger in ipairs(engine.Triggers()) do
		armedFiles[trigger.filename] = true
	end
	for filename in pairs(armedFiles) do
		engine.UnregisterFile(filename)
	end

	local matchFlow = makeMatchFlowVerbs(ModuleHandler.Get("matchflow"))

	for _, filePath in ipairs(files) do
		-- Identity is mission-relative so ids survive install-path differences.
		local filename = filePath:sub(#MISSIONS_DIR + 1)
		local file = DSL.ForFile(filename, engine.Register)
		local untils = {} ---@type { unit: MissionUnitRef, condition: MissionCondition }[]
		local combat = Verbs.MakeCombat(untils)
		local env = {
			When = file.When,
			Team = { Player = playerTeam },
			UnitDef = Verbs.UnitDef,
			Unit = Verbs.Unit,
			Units = Verbs.Units,
			Objective = Objective,
			MatchFlow = matchFlow,
			Combat = combat,
		}
		VFS.Include(filePath, env)
		-- The commit point: statements register here, and a half-finished
		-- chain (no Do) is a load error naming the file and statement.
		file.Finalize()
		-- The Until sugar, desugared: each recorded companion is the literal
		-- statement When(condition).Do(Combat.Unprotect(unit)).
		for order, entry in ipairs(untils) do
			engine.Register({
				id = filename .. ":until:" .. order,
				filename = filename,
				order = order,
				condition = entry.condition,
				effects = { combat.Unprotect(entry.unit) },
				once = true,
			})
		end
	end

	syncWatchedCallins()
	if not spawnRoster(missionName, playerTeam) then
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

---@param cmd string
---@param line string
---@param words string[]
local function missionChatAction(cmd, line, words, playerID)
	-- Synced chat actions arrive from ANY player in multiplayer; arming or
	-- reloading a mission is not an open verb (review point on PR #8375).
	if not ChatGuard.IsAllowed(Spring.Utilities.Gametype.IsSinglePlayer(), Spring.IsCheatingEnabled()) then
		Spring.Log(LOG_TAG, LOG.WARNING, "/mission refused: multiplayer without cheats (player " .. tostring(playerID) .. ")")
		return true
	end
	local missionName = words[1]
	if missionName == nil or missionName == "" then
		Spring.Log(LOG_TAG, LOG.ERROR, "usage: /luarules mission <name> | reload")
		return true
	end
	if missionName == "reload" then
		if activeMission == nil then
			Spring.Log(LOG_TAG, LOG.ERROR, "no active mission to reload")
			return true
		end
		missionName = activeMission
	end
	loadMission(missionName)
	return true
end

function gadget:Initialize()
	gadgetHandler:AddChatAction("mission", missionChatAction, "load a mission: /luarules mission <name>")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("mission")
end

---@param frame integer
function gadget:GameFrame(frame)
	if activeMission ~= nil and frame % EVALUATE_PERIOD == 0 then
		ctx.frame = frame
		engine.Evaluate(ctx)
	end
end
