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

local MISSIONS_DIR = "modules/missions/"
local EVALUATE_PERIOD = 15 -- frames

local engine = TriggerEngine.New()
local activeMission = nil ---@type string|nil

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
local FORWARDABLE_CALLINS = { "UnitFinished", "UnitDestroyed", "UnitGiven", "UnitTaken" }

---(Re)hook engine callins to match the engine's watched-input set. Called
---after every mission (re)load, when the watch set may have changed.
local function syncWatchedCallins()
	local watched = engine.WatchedInputs()
	for _, name in ipairs(FORWARDABLE_CALLINS) do
		if watched[name] and gadget[name] == nil then
			gadget[name] = function()
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
		---@param team MissionTeam
		---@return MissionEffect
		Victory = function(team)
			assert(type(team) == "table" and type(team.allyTeam) == "number",
				"MatchFlow.Victory expects a Team handle (e.g. Team.Player)")
			return {
				execute = function()
					matchflowApi.Victory(team.allyTeam)
				end,
			}
		end,
		---@param team MissionTeam
		---@return MissionEffect
		Defeat = function(team)
			assert(type(team) == "table" and type(team.allyTeam) == "number",
				"MatchFlow.Defeat expects a Team handle (e.g. Team.Player)")
			return {
				execute = function()
					matchflowApi.Defeat({ team.allyTeam })
				end,
			}
		end,
	}
end

---Load (or reload) a mission: run each triggers/*.lua through the injected
---environment. The sandbox IS the API surface — trigger files see the five
---verbs and nothing else. Unregister-by-identity first makes loading
---idempotent and is the hot-reload path.
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

	local matchFlow = makeMatchFlowVerbs(ModuleHandler.Get("matchflow"))

	for _, filePath in ipairs(files) do
		-- Identity is mission-relative so ids survive install-path differences.
		local filename = filePath:sub(#MISSIONS_DIR + 1)
		engine.UnregisterFile(filename)
		local env = {
			T = DSL.ForFile(filename, engine.Register),
			Team = { Player = playerTeam },
			UnitDef = Verbs.UnitDef,
			Objective = Objective,
			MatchFlow = matchFlow,
		}
		VFS.Include(filePath, env)
	end

	syncWatchedCallins()
	activeMission = missionName
	Spring.SetGameRulesParam("mission_active", 1)
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
