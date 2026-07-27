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
local Variables = VFS.Include("modules/missions/lib/variables.lua")
local Events = VFS.Include("modules/missions/lib/events.lua")

local MISSIONS_DIR = "modules/missions/"
local EVALUATE_PERIOD = 15 -- frames

local engine = TriggerEngine.New()
local activeMission = nil ---@type string|nil
local variableKinds = {} ---@type table<string, string> variable name -> declared kind
local contributedContext = {} ---@type table<string, boolean> ctx keys the required modules supplied

-- Destroyed/spotted state is LATCHED into rulesparams: engine-serialized,
-- readable unsynced.
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

---@type MissionRuntime
local runtime = {
	UnitOf = function(name)
		return namedUnits[name]
	end,
	GroupUnits = function(groupName)
		return groupUnits[groupName]
	end,
	-- A spawned-Neutral unit holds fire until it changes hands; whoever
	-- moves it says so.
	ReleaseHoldFire = function(unitID)
		if silencedUnits[unitID] and Spring.ValidUnitID(unitID) then
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 2 }, 0)
			silencedUnits[unitID] = nil
		end
	end,
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
	-- A variable's value is a rules param: booleans travel as 0/1 (rules
	-- params hold numbers and strings), so the declared kind decodes it.
	GetVariable = function(name)
		local raw = Spring.GetGameRulesParam("mission_var_" .. name)
		if variableKinds[name] == "boolean" then
			return raw == 1
		end
		return raw
	end,
	SetVariable = function(name, value)
		if type(value) == "boolean" then
			value = value and 1 or 0
		end
		Spring.SetGameRulesParam("mission_var_" .. name, value)
		engine.OnEvent(Events.VariableChanged)
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

---Complete() is LAZY: an effect for Do, not run immediately. Rulesparam writes
---have no callin, so it emits "mission.objective_changed" for IsComplete()'s input.
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
					engine.OnEvent(Events.ObjectiveChanged)
				end,
			}
		end,
		-- Reveal is presentation state, not progress. Same objective_ prefix as
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
				inputs = { Events.ObjectiveChanged },
				---@param ctx MissionContext
				evaluate = function(ctx)
					return ctx.IsObjectiveComplete(name)
				end,
			}
		end,
	}
end

-- Only callins some registered trigger watches get hooked (don't-hook-what-you-don't-use).
local FORWARDABLE_CALLINS = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken", "UnitEnteredLos" }

-- Most callins forward as bare bus events; these also latch roster-unit
-- state first — conditions read "has been", not "is right now".
local forwarders = {
	UnitDestroyed = function(_, unitID, _, _, attackerID, _, attackerTeam)
		local name = unitNames[unitID]
		if name ~= nil then
			Spring.SetGameRulesParam("mission_unit_dead_" .. name, 1)
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

---The in-memory ledger dies with a /luarules reload, so the sweep also reads
---the persisted copy; otherwise a re-arm after a reload spawns the roster
---twice and the orphans keep shooting.
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

---Progress clears with the triggers, so the editor stops showing last run's progression.
local function resetFired()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^mission_trigger_fire") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
	publishedFired = {}
end

---Progress clears with the triggers, so a completed objective cannot re-fire
---victory on the next cadence.
local function resetObjectives()
	for name in pairs(Spring.GetGameRulesParams()) do
		if name:find("^objective_") then
			Spring.SetGameRulesParam(name, nil)
		end
	end
end

---Everything under the objective_ prefix, so presentation sweeps with progress
---and the widget needs no manifest of its own.
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

---VFS.Include wraps a Lua error in engine bookkeeping (include mode, pcall
---depth, environment flag) and buries the one line an author needs. A mission
---file naming a unit wrong should read as a mission problem, not a VFS problem.
---Anything not matching the wrapper passes through untouched.
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

---Parses before trigger files load, so Unit/Units references validate against
---declared names at load.
---@param missionName string
---@return MissionRosterEntry[]|nil entries nil on a load error; {} when the mission has no roster
---@param sandboxVFS table the mission's own VFS: Include of its definition files
---@return MissionRosterEntry[]|nil entries
---@return table|nil exports what units.lua returned, for the files that include it
local function parseRoster(missionName, sandboxVFS)
	local rosterPath = MISSIONS_DIR .. missionName .. "/units.lua"
	if not VFS.FileExists(rosterPath) then
		return {}
	end
	local ok, result = pcall(function()
		local file = Roster.ForFile(missionName .. "/units.lua")
		local exports = VFS.Include(rosterPath, {
			Spawn = file.Spawn,
			Claim = file.Claim,
			Group = file.Group,
			UnitDef = Verbs.UnitDef,
			VFS = sandboxVFS,
		})
		local entries, _, declaredGroups = file.Finalize(exports)
		return { entries, exports, declaredGroups }
	end)
	if not ok then
		Spring.Log(LOG_TAG, LOG.ERROR, readableLoadError(result))
		return nil
	end
	return result[1], result[2], result[3]
end

---Runs AFTER syncWatchedCallins so spawn-time callins (a unit born inside LOS)
---reach the latches.
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
			local x, z = entry.fx * Game.mapSizeX, entry.fz * Game.mapSizeZ
			unitID = Spring.CreateUnit(entry.def, x, Spring.GetGroundHeight(x, z), z, 0, teamID)
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

---One transaction: the incoming mission arms into a staging engine swapped in
---whole, so a file that fails to parse leaves the running mission untouched.
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
	-- the same table to every importer, so units.lua never registers twice.
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
			error(
				normalized .. " is not a definition file loaded before this one — include units.lua or objectives.lua"
			)
		end
		if exports == false then
			error(normalized .. " returned nothing to include — return the handles the other files need")
		end
		return exports
	end

	-- Roster parses before trigger files load, so Unit/Units references
	-- validate against declared names — a typo is a load error, not a silent never-true condition.
	local rosterEntries, rosterExports, declaredGroups = parseRoster(missionName, sandboxVFS)
	if rosterEntries == nil then
		return false
	end
	included[missionDir .. "units.lua"] = rosterExports or false
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
	for name in pairs(declaredGroups or {}) do
		rosterGroups[name] = true
	end

	local contributions = loadContributions()
	local Unit = Verbs.MakeUnit(rosterNames)

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

	-- Staging: nothing armed changes until every file has parsed.
	local staging = TriggerEngine.New()

	-- Each required module adds its vocabulary to a file's globals; a name
	-- collision between modules is a load error, not a silent shadow. The
	-- returned finalizer runs after the file, for contributions that arm
	-- lifetimes at load.
	---@param filename string
	---@param env table<string, any>
	---@return fun()
	local function contribute(filename, env)
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
	local variableDecls = nil ---@type MissionVariableEntry[]|nil
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
		-- Variables are a definition site too; objectives may gate on them, so
		-- they load first.
		local variablesPath = MISSIONS_DIR .. missionName .. "/variables.lua"
		if VFS.FileExists(variablesPath) then
			local file = Variables.ForFile(missionName .. "/variables.lua")
			local exports = VFS.Include(variablesPath, { Variable = file.Variable, VFS = sandboxVFS })
			variableDecls = file.Finalize(exports)
			included[variablesPath] = exports or false
		end

		-- The definition site parses first: objectives.lua declares the ids the
		-- trigger files may speak.
		local objectivesPath = MISSIONS_DIR .. missionName .. "/objectives.lua"
		if VFS.FileExists(objectivesPath) then
			local filename = missionName .. "/objectives.lua"
			-- An exported objective handle is also its effect side.
			local file = Objectives.ForFile(filename, function(id, verb)
				return Objective(id)[verb]()
			end)
			local env = {
				Objective = file.Objective,
				Team = { Player = playerTeam },
				UnitDef = Verbs.UnitDef,
				Unit = Unit,
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
					for _, gate in ipairs(decl.gates or {}) do
						chain = chain.When(gate)
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
				VFS = sandboxVFS,
			}
			local finalizeContributions = contribute(filename, env)
			VFS.Include(filePath, env)
			-- Statements register here, and a half-finished chain (no Do) is a
			-- load error naming the file and statement.
			file.Finalize()
			finalizeContributions()
		end
		checkInputs()
	end)
	if not parsed then
		Spring.Log(LOG_TAG, LOG.ERROR, readableLoadError(err))
		return false
	end

	-- The commit point: the armed set is replaced, not amended. On a preserving
	-- reload the save pile is re-applied over the new definitions, so the editor
	-- nudging one number does not restart the mission.
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
	variableKinds = {}
	for _, decl in ipairs(variableDecls or {}) do
		variableKinds[decl.name] = decl.kind
	end
	if not preserve then
		for name in pairs(Spring.GetGameRulesParams()) do
			if name:find("^mission_var_") then
				Spring.SetGameRulesParam(name, nil)
			end
		end
		for _, decl in ipairs(variableDecls or {}) do
			local value = decl.default
			if type(value) == "boolean" then
				value = value and 1 or 0
			end
			Spring.SetGameRulesParam("mission_var_" .. decl.name, value)
		end
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

--- The bare `/luarules mission <name>` is kept working: it is what the in-game
--- panel and every existing note still say.
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
		---A module event has no callin to hook, so the module that raises it says so
		---here (the convention mission.objective_changed already uses internally).
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

---"none" is the wire value for no mission. Only the game-start path: the chat
---command and the editor can still arm whatever they like later.
function gadget:GameStart()
	local fromLobby = Spring.GetModOptions().mission_name
	if fromLobby ~= nil and fromLobby ~= "" and fromLobby ~= "none" then
		loadMission(fromLobby)
	end
end

---A /luarules reload mid-match wipes every local and GameStart does not come
---again, silently disarming the mission. The armed name survives in the rules
---params, so re-arm it here (the persisted ledger despawns the previous roster).
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
