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
local Objectives = VFS.Include("modules/missions/lib/objectives.lua")
local Events = VFS.Include("modules/missions/lib/events.lua")

local MISSIONS_DIR = "modules/missions/"
local EVALUATE_PERIOD = 15 -- frames

local engine = TriggerEngine.New()
local activeMission = nil ---@type string|nil
local contributedContext = {} ---@type table<string, boolean> ctx keys the required modules supplied

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

---@type MissionRuntime
local runtime = {
	Protections = {
		Get = function(unitID)
			return protectCounts[unitID] or 0
		end,
		Set = function(unitID, count)
			protectCounts[unitID] = count > 0 and count or nil
			persistProtectLedger()
		end,
	},
	Log = function(level, message)
		Spring.Log(LOG_TAG, level, message)
	end,
}

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
}

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

---Rulesparam writes have no callin, so Complete emits "mission.objective_changed" for IsComplete()'s input.
---@param name string
---@return MissionObjective
local function Objective(name)
	return {
		Complete = function()
			return {
				execute = function()
					-- idempotent: OR disjuncts complete once, whichever way fires later
					if Spring.GetGameRulesParam("objective_" .. name) == 1 then
						return
					end
					Spring.SetGameRulesParam("objective_" .. name, 1)
					-- Completing implies revealing: the tracker must never owe
					-- the player a checkmark on a line it refused to draw.
					Spring.SetGameRulesParam("objective_revealed_" .. name, 1)
					Spring.Echo("[" .. LOG_TAG .. "] objective complete: " .. name)
					engine.OnEvent(Events.ObjectiveChanged)
				end,
			}
		end,
		-- same objective_ prefix as Complete, so a fresh load sweeps both piles together
		Reveal = function()
			return {
				execute = function()
					Spring.SetGameRulesParam("objective_revealed_" .. name, 1)
				end,
			}
		end,
		IsComplete = function()
			return {
				inputs = { Events.ObjectiveChanged },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsObjectiveComplete(name)
				end,
			}
		end,
	}
end

local FORWARDABLE_CALLINS = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken", "UnitEnteredLos" }

-- Callins forward as bare bus events; a module that latches state on one
-- (the roster) supplies its own forwarder here.
local forwarders = {}

---@param addOnly boolean|nil a trigger armed mid-run (Protect ... Until) can only add a
---watch, and removing a callin from inside a callin is the handler crash combat documents
local function syncWatchedCallins(addOnly)
	local watched = engine.WatchedInputs()
	for _, name in ipairs(FORWARDABLE_CALLINS) do
		if watched[name] and gadget[name] == nil then
			gadget[name] = forwarders[name] or function()
				engine.OnEvent(name)
			end
			gadgetHandler:UpdateCallIn(name)
		elseif not addOnly and not watched[name] and gadget[name] ~= nil then
			gadget[name] = nil
			gadgetHandler:UpdateCallIn(name)
		end
	end
end

---@return MissionDslContribution[]
local function loadContributions()
	local contributions = {}
	local manifest = ModuleHandler.Discover().missions
	for _, name in ipairs(manifest.requires) do
		local path = "modules/" .. name .. "/mission_dsl.lua"
		if VFS.FileExists(path) then
			contributions[#contributions + 1] = VFS.Include(path)
		elseif VFS.FileExists("modules/" .. name .. "/types/dsl.lua") then
			-- usually a new file the engine has not rescanned; without this the
			-- author sees only a nil global in their trigger file
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

-- Which trigger ids have been published as fired. Derived, not progress: the
-- engine's own state is the truth, this only avoids re-writing a param that
-- has not changed.
local publishedFired = {} ---@type table<string, boolean>

---Publishes what has FIRED, deliberately not "is the condition true": a
---once-trigger stays fired after its condition goes false, and an editor
---shading off the live condition would flicker back to unfired.
local function publishFired()
	local state = engine.GetState()
	for id, count in pairs(state.fires) do
		if publishedFired[id] ~= count then
			publishedFired[id] = count
			Spring.SetGameRulesParam("mission_trigger_fired_" .. id, 1)
			Spring.SetGameRulesParam("mission_trigger_fires_" .. id, count)
		end
	end
end

local function resetFired()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^mission_trigger_fire") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
	publishedFired = {}
end

local function resetObjectives()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^objective_") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
end

---Everything under the objective_ prefix, so presentation sweeps with progress.
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
	for _, decl in ipairs(declarations) do
		if decl.revealAtArm then
			Spring.SetGameRulesParam("objective_revealed_" .. decl.id, 1)
		end
	end
end

---VFS.Include wraps a Lua error in engine bookkeeping (include mode, pcall
---depth, environment flag) and buries the one line an author needs.
---@param err any
---@return string
local function readableLoadError(err)
	local text = tostring(err)
	-- anchored on both ends so a message containing its own parentheses (`Named(...)`) comes out whole
	local inner = text:match("error=%-?%d+ %((.*)%) ptop=")
	if inner == nil then
		return text
	end
	local path = text:match("file=(%S+)")
	-- the chunk name and line point into the DSL, where the CHECK lives, not at the mistake
	inner = inner:gsub('^%[string "[^"]*"%]:%d+: ', "")
	if path ~= nil then
		return (path:gsub("^" .. MISSIONS_DIR, "")) .. ": " .. inner
	end
	return inner
end

---One transaction: the incoming mission arms into a staging engine swapped in
---whole, so a file that fails to parse leaves the running mission untouched.
---@param missionName string
---@return boolean loaded
---@param missionName string
---@param preserve boolean|nil keep progress and the field: the editor nudging
---a number mid-run is not a request to start over
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

	-- The mission's own module system: its files link with VFS.Include, and a
	-- definition file's return table is what an include yields — once per load,
	-- the same table to every importer, so objectives.lua never registers twice.
	local missionDir = MISSIONS_DIR .. missionName .. "/"
	local included = {} ---@type table<string, table|false>
	local sandboxVFS = {}
	sandboxVFS.Include = function(path)
		assert(type(path) == "string", "VFS.Include expects a path")
		local normalized = path:gsub("\\", "/"):gsub("^%./", "")
		if normalized:sub(1, #missionDir) ~= missionDir then
			error("a mission may only include its own files, not " .. tostring(path))
		end
		local exports = included[normalized]
		if exports == nil then
			error(normalized .. " is not a definition file loaded before this one — include objectives.lua")
		end
		if exports == false then
			error(normalized .. " returned nothing to include — return the handles the other files need")
		end
		return exports
	end

	local contributions = loadContributions()

	for key in pairs(contributedContext) do
		ctx[key] = nil
	end
	contributedContext = {}
	local knownEvents = {}
	for _, name in ipairs(FORWARDABLE_CALLINS) do
		knownEvents[name] = true
	end
	for _, name in pairs(Events) do
		knownEvents[name] = true
	end
	for _, contribution in ipairs(contributions) do
		if contribution.Context ~= nil then
			for key, value in pairs(contribution.Context(runtime)) do
				if ctx[key] ~= nil then
					error("two modules contribute the context function " .. key)
				end
				ctx[key] = value
				contributedContext[key] = true
			end
		end
		for _, name in pairs(contribution.Events or {}) do
			knownEvents[name] = true
		end
	end

	local staging = TriggerEngine.New()

	---@param filename string
	---@param env table<string, any>
	---@return fun()
	local function contribute(filename, env)
		local fileContributions = {}
		for _, contribution in ipairs(contributions) do
			local forFile = contribution.ForFile({
				filename = filename,
				Register = staging.Register,
			})
			for key, value in pairs(forFile.env) do
				if env[key] ~= nil then
					error(filename .. ": two modules contribute the global " .. key)
				end
				env[key] = value
			end
			fileContributions[#fileContributions + 1] = forFile
		end
		return function()
			for _, forFile in ipairs(fileContributions) do
				if forFile.Finalize then
					forFile.Finalize()
				end
			end
		end
	end
	local objectiveDecls = nil ---@type MissionObjectiveDeclarationEntry[]|nil
	local declaredObjectives = nil ---@type table<string, boolean>|nil
	local parsed, err = pcall(function()
		local function checkInputs()
			for _, trigger in ipairs(staging.Triggers()) do
				for _, input in ipairs(trigger.condition.inputs or {}) do
					if not knownEvents[input] then
						error(
							trigger.filename
								.. ": trigger "
								.. tostring(trigger.order)
								.. ' listens for "'
								.. tostring(input)
								.. '", which no callin or required module raises'
						)
					end
				end
			end
		end
		-- The definition site parses first: objectives.lua declares the ids the
		-- trigger files may speak.
		local objectivesPath = MISSIONS_DIR .. missionName .. "/objectives.lua"
		if VFS.FileExists(objectivesPath) then
			local filename = missionName .. "/objectives.lua"
			local file = Objectives.ForFile(filename, function(id, verb)
				return Objective(id)[verb]()
			end)
			local env = {
				Objective = file.Objective,
				Team = { Player = playerTeam },
				UnitDef = Verbs.UnitDef,
				VFS = sandboxVFS,
			}
			local finalizeContributions = contribute(filename, env)
			local exports = VFS.Include(objectivesPath, env)
			objectiveDecls = file.Finalize(exports)
			included[objectivesPath] = exports or false
			finalizeContributions()
			declaredObjectives = {}
			for _, decl in ipairs(objectiveDecls) do
				declaredObjectives[decl.id] = true
			end

			local derived = DSL.ForFile(filename, staging.Register)
			-- standing objectives (no completion) are transparent to the cadence:
			-- a line that never completes must not dam it
			local prevCompletable = nil
			for _, decl in ipairs(objectiveDecls) do
				-- one trigger per disjunct; Complete is idempotent, so a second way firing later is a no-op
				for _, group in ipairs(decl.completions) do
					local chain = derived.When(group[1])
					for i = 2, #group do
						chain = chain.When(group[i])
					end
					for _, gate in ipairs(decl.gates or {}) do
						chain = chain.When(gate)
					end
					chain.Do(Objective(decl.id).Complete())
				end
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
			-- mission-relative so ids survive install-path differences
			local filename = filePath:sub(#MISSIONS_DIR + 1)
			local file = DSL.ForFile(filename, staging.Register)
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
				Objective = ObjectiveVerb,
				VFS = sandboxVFS,
			}
			local finalizeContributions = contribute(filename, env)
			VFS.Include(filePath, env)
			file.Finalize()
			finalizeContributions()
		end
		checkInputs()
	end)
	if not parsed then
		Spring.Log(LOG_TAG, LOG.ERROR, readableLoadError(err))
		return false
	end

	-- on a preserving reload the saved state is re-applied over the new
	-- definitions, so the editor nudging one number does not restart the mission
	local savedState = preserve and engine.GetState() or nil
	engine = staging
	if preserve then
		-- after a /luarules reload the previous engine is gone; fired survives
		-- in the params, heldSince cannot, so countdowns restart in that one path
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
	activeMission = missionName
	Spring.SetGameRulesParam("mission_active", 1)
	Spring.SetGameRulesParam("mission_name", missionName)
	publishObjectives(objectiveDecls)
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

---@param name string action file name under actions/
---@param request table|nil
---@return boolean ran
local function perform(name, request)
	-- an action file runs in the registrar's environment, where the gadget's GG is not visible
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

--- The bare `/luarules mission <name>` is kept working: the in-game panel still says it.
---@param cmd string
---@param line string
---@param words string[]
local function missionChatAction(cmd, line, words, playerID)
	-- synced chat actions arrive from ANY player in multiplayer
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
	GG.Missions = {
		Load = loadMission,
		Reload = function()
			return activeMission ~= nil and loadMission(activeMission, true)
		end,
		Restart = function()
			return activeMission ~= nil and loadMission(activeMission)
		end,
		Active = function()
			return activeMission
		end,
		---A module event has no callin to hook, so the module that raises it says so here.
		---@param name string a member of the raising module's Events enum
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

---"none" is the wire value for no mission.
function gadget:GameStart()
	local fromLobby = Spring.GetModOptions().mission_name
	if fromLobby ~= nil and fromLobby ~= "" and fromLobby ~= "none" then
		loadMission(fromLobby)
	end
end

---A /luarules reload mid-match wipes every local and GameStart does not come
---again, silently disarming the mission; the armed name survives in the rules params.
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
		syncWatchedCallins(true)
		publishFired()
	end
end
