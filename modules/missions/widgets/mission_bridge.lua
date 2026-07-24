local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Bridge",
		desc = "Headless game side of the mission editor: publishes domains, samples live state for the terminals, hot-reloads the mission on artifact regeneration",
		author = "Beyond All Reason",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- No UI here: terminals (RmlUi panel, VS Code, browser) render the served
-- view. This widget contributes what only the game knows and follows the
-- file — it runs whether or not any panel is open.

local VIEW_PATH = "modules/missions/editor/mission_view.json"
local DOMAINS_PATH = "modules/missions/editor/domains.json"
local STATE_PATH = "modules/missions/editor/state.json"
local ACTIVE_PATH = "modules/missions/editor/active_mission.json"
local POLL_SECONDS = 0.5
local LIVE_SAMPLE_SECONDS = 1.0

-- Engine-provided in the widget env (system.lua whitelists it). Do NOT
-- VFS.Include json.lua: it reads `local base = _G`, nil in widget sandboxes.
local Json = Json
if not Json then
	return
end

local lastGeneration = nil
local pollAccumulator = 0
local liveAccumulator = 0
local probes = nil

local function writeJson(path, value)
	Spring.CreateDir("modules/missions/editor")
	local handle = io.open(path, "w")
	if not handle then
		Spring.Echo("[mission_bridge] cannot write " .. path)
		return
	end
	handle:write(Json.encode(value))
	handle:close()
end

--------------------------------------------------------------------------------
-- Domains: dropdown data only the game knows (UnitDefNames). Published once;
-- serve folds it into the next generation.
--------------------------------------------------------------------------------

local function publishDomains()
	local units = {}
	-- ipairs(UnitDefs) is the idiom that actually iterates the engine proxy.
	for _, def in ipairs(UnitDefs) do
		if def.name then
			local human = def.translatedHumanName or def.name
			-- Untranslated units leak raw i18n keys (units.names.x); fall back.
			if human:find("^units%.names%.") then
				human = def.name
			end
			units[#units + 1] = { value = def.name, label = human .. "  [" .. def.name .. "]" }
		end
	end
	table.sort(units, function(a, b)
		return a.value < b.value
	end)
	writeJson(DOMAINS_PATH, { units = units })
end

--------------------------------------------------------------------------------
-- Live state: sample what the view manifest asks for, publish for every
-- terminal (state.json / GET /state). Unarmed = no values: a pawn count
-- without a running mission reads as progress but is just world state.
--------------------------------------------------------------------------------

local function countFinishedUnits(unitDefName)
	local def = UnitDefNames[unitDefName]
	if not def then
		return nil
	end
	local count = 0
	for _, unitID in ipairs(Spring.GetTeamUnitsByDefs(Spring.GetMyTeamID(), def.id) or {}) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			count = count + 1
		end
	end
	return count
end

local function sampleLive()
	if not probes or #probes == 0 then
		return
	end
	local armed = Spring.GetGameRulesParam("mission_active") == 1
	local values = {}
	if armed then
		for _, probe in ipairs(probes) do
			if probe.kind == "unit_count" and probe.unit_def then
				local have = countFinishedUnits(probe.unit_def)
				if have then
					local need = math.floor(probe.need or 0)
					local done = have >= need
					values[probe.key] = {
						text = have .. "/" .. need,
						state = done and "done" or "pending",
						pct = need > 0 and math.min(1, have / need) or (done and 1 or 0),
					}
				end
			elseif probe.kind == "objective" and probe.objective then
				local done = Spring.GetGameRulesParam("objective_" .. probe.objective) == 1
				values[probe.key] = { text = done and "✓" or "–", state = done and "done" or "pending", pct = done and 1 or 0 }
			end
		end
	end
	writeJson(STATE_PATH, { t = os.time and os.time() or 0, armed = armed, values = values })
end

--------------------------------------------------------------------------------
-- Follow the file: on a new artifact generation, refresh the probe manifest
-- and hot-reload the running mission so the game tracks every accepted edit.
--------------------------------------------------------------------------------

local function pollArtifact(dt)
	pollAccumulator = pollAccumulator + dt
	if pollAccumulator < POLL_SECONDS then
		return
	end
	pollAccumulator = 0
	local text = VFS.LoadFile(VIEW_PATH, VFS.RAW_FIRST)
	if not text then
		return
	end
	local generation = text:match('"generation"%s*:%s*(%d+)')
	if generation == lastGeneration then
		return
	end
	local firstSight = lastGeneration == nil
	lastGeneration = generation
	local ok, view = pcall(Json.decode, text)
	probes = ok and type(view) == "table" and view.live or probes
	if not firstSight and Spring.GetGameRulesParam("mission_active") == 1 then
		Spring.SendCommands("luarules mission reload")
	end
end

local lastMissionName = nil

---Tell serve which mission is armed so it can re-scope the editor
---(--missions-root mode): picker click retargets form, probes, Edit button.
local function publishActiveMission()
	local name = Spring.GetGameRulesParam("mission_name")
	if name == lastMissionName or type(name) ~= "string" then
		return
	end
	lastMissionName = name
	writeJson(ACTIVE_PATH, { name = name })
end

function widget:Update(dt)
	pollArtifact(dt)
	liveAccumulator = liveAccumulator + dt
	if liveAccumulator >= LIVE_SAMPLE_SECONDS then
		liveAccumulator = 0
		publishActiveMission()
		sampleLive()
	end
end

function widget:Initialize()
	publishDomains()
end
