local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Squad Selection",
		desc = "Automagical squad creation and proximity-based selection",
		author = "Baldric, yyyy",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 300,
		enabled = true,
	}
end

-------------------------------------------------------------------------------
-- Squad Selection
--
-- Feature gallery:        https://bar-stuff.madebygabe.dev/squad-selection
-- Readme / documentation: https://github.com/MadeByGabe/squad-selection
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

---@class SquadConfig
---@field cyclingToNextSquad boolean
---@field leftClickSelectsSquad boolean
---@field leftClickSteps (number|string)[]
---@field leftClickStepsEnabled boolean
---@field leftClickAppendFiltersDomain boolean
---@field leftClickFilteredRetargets boolean
---@field rightClickSquadCreate boolean
---@field rightClickMovesSquad boolean
---@field rightClickMoveRange number
---@field ctrlRightClickCreatesSquad boolean
---@field ctrlRightClickDragCreatesSquad boolean
---@field commandCreatesSquad boolean
---@field mergeIntoReserves boolean
---@field selectionAutoExtend boolean
---@field showReserveSquads boolean
---@field viewselectionDoubleTapMs number
---@field viewselectionDoubleTapPx number
---@field mruSize number
---@field excludeConstructors boolean
---@field excludeResurrectionUnits boolean
---@field excludeCombatEngineers boolean
---@field excludedUnitTypes string
---@field visualizationMode string
---@field convexHullPadding number
---@field convexHullArcResolution number
---@field convexHullFillOpacity number
---@field convexHullBorderOpacity number
---@field convexHullBorderThickness number
---@field convexHullColorMode string
---@field convexHullCustomColorR number
---@field convexHullCustomColorG number
---@field convexHullCustomColorB number
---@field reserveStripePeriod number
---@field reserveStripeAlphaMul number
---@field hullPulseAmplitude number
---@field hullPulseRate number
---@field idleColorBlendSeconds number
---@field highlightBlendSeconds number
---@field debug boolean

---@type SquadConfig
local config = {
	cyclingToNextSquad = true, -- when full squad/type is selected, exclude it to cycle to next
	leftClickSelectsSquad = true, -- left-click can be used to select squads
	leftClickSteps = { 1, 0.5, "distance_850" }, -- step values + optional distance cap for left-click selection; {1} = whole squad, {"distance_850", 0.5, 1} = 50% then 100% within 850 elmos
	leftClickStepsEnabled = false, -- when true, left-click (replace and append) uses leftClickSteps; when false (default), both use {1} (whole squad, no distance cap). Bind a hotkey via `squad_setting toggle leftClickStepsEnabled` to flip on demand
	leftClickAppendFiltersDomain = true, -- when true, left-click Shift-append only cycles into squads whose domains ⊆ the selection's; when false, append behaves like the plain `append` keyword
	leftClickFilteredRetargets = true, -- when true, Alt+Ctrl-click (replace-mode filtered) acts like the `retarget` keyword: if the closest unit's type isn't in the current selection, treat the click as a fresh selection on that new type instead of using the selection's types as the filter. Append mode is unaffected.
	rightClickSquadCreate = false, -- right-click creates squads; bind a hotkey via `squad_setting toggle rightClickSquadCreate` to flip on demand
	rightClickMovesSquad = true, -- right-click commands the closest squad
	rightClickMoveRange = 850, -- max world-distance (elmos) from the cursor for the right-click-move feature to highlight/pick a squad; 0 = unlimited
	ctrlRightClickCreatesSquad = false, -- Ctrl+right-click creates a squad (click still passes through, so the engine's move-in-formation runs too which can cause issues)
	ctrlRightClickDragCreatesSquad = true, -- hold Ctrl then right-click drag past the engine's MouseDragFrontCommandThreshold to create a squad (click still passes through)
	commandCreatesSquad = false,
	mergeIntoReserves = true, -- when false, `squad_create` never merges the selection into a reserve squad; it always creates a fresh manual squad
	selectionAutoExtend = false, -- when true, freshly built units auto-extend the current selection while their reserve is fully selected (the wait/patrol rally opt-out still applies on top)
	showReserveSquads = false, -- when true, auto per-factory reserves + uncategorized reserve are visualized
	viewselectionDoubleTapMs = 300, -- second rapid same-place non-append squad-select tap (single-step, or multi-step at the last step) calls viewselection on the just-selected squad (0 disables)
	viewselectionDoubleTapPx = 5, -- max screen-pixel distance between the two taps (0 disables the gesture, same as Ms — the comparison is strict)
	mruSize = 3, -- how many recent squads squad_cycle_recent cycles through
	excludeConstructors = true, -- when true, the curated constructor/commander list (CONSTRUCTOR_UNITS) is excluded from squad tracking
	excludeResurrectionUnits = false, -- when true, the curated resurrection-unit list (RESURRECTION_UNITS) is excluded from squad tracking
	excludeCombatEngineers = false, -- when true, the curated combat-engineer list (COMBAT_ENGINEER_UNITS) is excluded from squad tracking
	excludedUnitTypes = "", -- comma-separated unit names the player has manually excluded from squad tracking (independent of the three toggles above)
	visualizationMode = "convexHull", -- "convexHull" or "none"
	convexHullPadding = 60, -- space (in elmos) between the units and the hull boundary
	convexHullArcResolution = 0.4, -- angle that each chord of the arc spans in radians; smaller = smoother but more expensive
	convexHullFillOpacity = 0.25,
	convexHullBorderOpacity = 0.3,
	convexHullBorderThickness = 2,
	convexHullColorMode = "team", -- "team" (team color), "custom" (single custom RGB), "squad" (per-squad golden-ratio hue)
	convexHullCustomColorR = 0, -- Red component of custom hull color (0–1)
	convexHullCustomColorG = 0.3, -- Green component
	convexHullCustomColorB = 0.7, -- Blue component
	-- Animation tuning (no panel control).
	reserveStripePeriod = 64, -- diagonal-stripe period in world elmos for reserve squad fills
	reserveStripeAlphaMul = 0.3, -- opacity of the dim stripe band relative to the bright band
	hullPulseAmplitude = 0.25, -- breathing pulse amplitude on hull alpha
	hullPulseRate = 1.5, -- breathing pulse rate; period ≈ 2π / rate seconds
	idleColorBlendSeconds = 0.5, -- seconds for the idle/active hull color to fully crossfade (0 = instant)
	highlightBlendSeconds = 0.1, -- seconds for the closest-squad highlight to fade in/out (0 = instant)
	debug = false,
}

-- Snapshot of the defaults defined above, used by `squad_setting reload`.
local configDefaults = {}
for k, v in pairs(config) do
	configDefaults[k] = v
end

-------------------------------------------------------------------------------
-- Localized Spring API
--
-- Avoids repeated global table lookups. Matters most in DrawScreen where we
-- iterate every tracked unit each frame; negligible for one-shot calls in
-- Initialize, but kept here as an at-a-glance "imports" list.
-------------------------------------------------------------------------------

local spEcho = Spring.Echo
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetTeamUnits = Spring.GetTeamUnits
---@type fun(unitID: number): integer?
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetSelectedUnits = Spring.GetSelectedUnits
---@type fun(unitIDs: number[], append?: boolean) Re-typed: unit IDs are `number` here (Spring.GetSelectedUnits returns number[]), but the engine annotation wants integer[].
local spSelectUnitArray = Spring.SelectUnitArray
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spIsGUIHidden = Spring.IsGUIHidden
local spGetModKeyState = Spring.GetModKeyState
local spGetSpectatingState = Spring.GetSpectatingState
local spGetActiveCommand = Spring.GetActiveCommand
local spGetLocalPlayerID = Spring.GetLocalPlayerID
---@type fun(groupID: number): number[]?
local spGetGroupUnits = Spring.GetGroupUnits
---@type fun(unitID: number): integer?
local spGetUnitGroup = Spring.GetUnitGroup
local spGetMouseCursor = Spring.GetMouseCursor
local spGetConfigInt = Spring.GetConfigInt
local spIsReplay = Spring.IsReplay
local spGetGroundHeight = Spring.GetGroundHeight
---@type fun(unitID: number, count: integer): commands: Command[]
local spGetUnitCommands = Spring.GetUnitCommands
---@type fun(unitID: number): integer?
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetTeamColor = Spring.GetTeamColor
local spSendCommands = Spring.SendCommands
local spGiveOrder = Spring.GiveOrder
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spIsSphereInView = Spring.IsSphereInView
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader
local glGetUniformLocation = gl.GetUniformLocation
local glUniform = gl.Uniform
local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

--- Array of member unitIDs (1-based; order not meaningful) plus identity/visual metadata.
---@class Squad
---@field [number] number Member unitIDs (1-based; order not meaningful).
---@field index number? Monotonically increasing squad id. Companion widgets derive colors/letters from it. Set by assignSquadTag right after creation.
---@field tagSeed number? Golden-ratio phase offset; drives hull animation phase and per-squad color. Set by assignSquadTag right after creation.
---@field color number[]? {r, g, b} squad color (from indexToColor). Set by assignSquadTag right after creation.
---@field isReserve boolean? True for hidden reserve squads (per-factory auto-squads + the uncategorized reserves).
---@field fromFactory boolean? True when this reserve was auto-created for a factory.
---@field uncatDomain Domain? Set only on the three permanent uncategorized reserves.

---@alias Domain "land"|"air"|"naval"

local squads = {} ---@type Squad[] ordered list of squad arrays
local unitSquad = {} ---@type table<number, Squad?> unitID -> the squad array it belongs to (nil for untracked units)
local unitSlot = {} ---@type table<number, number> unitID -> index within that squad (for O(1) removal)
local factorySquad = {} ---@type table<number, Squad> factoryUnitID -> squad (every factory gets an auto-created squad)
local uncategorizedReserve = {} ---@type table<Domain, Squad> domain -> reserve squad for units with no factory origin

local mru = {} ---@type Squad[] most-recently-used squads, newest at index 1

local squadSelCount = {} ---@type table<Squad, number> squad -> number of selected units in it
local selectionDirty = true -- forces a full recount on the first draw frame
local squadIdleState = {} ---@type table<Squad, boolean> squad -> true when >50% of the squad is idle
local squadIdleBlend = {} ---@type table<Squad, number> squad -> 0..1 blend between team color and idle color
local squadHighlightBlend = {} ---@type table<Squad, number> squad -> 0..1 blend for the closest-squad preview highlight (opacity only)
local squadControlBlend = {} ---@type table<Squad, number> squad -> 0..1 blend for the actively-commanded squad (RMB held); adds the border emphasis
local squadHideIdleAirHull = {} ---@type table<Squad, boolean> squad -> true when an idle squad is entirely airborne air units
local idleScanIndex = 0 -- round-robin index into squads for incremental idle-state updates

---@class PendingDragCreate Screen pos of a Ctrl+RMB press awaiting a drag past MouseDragFrontCommandThreshold to fire squad_create (config.ctrlRightClickDragCreatesSquad).
---@field x number Mouse screen x at press time.
---@field y number Mouse screen y at press time.

---@class PendingSquadMove Captured on an Alt/Space RMB (or plain RMB with empty selection) press (config.rightClickMovesSquad).
---@field squad Squad The picked squad to command on RMB release.
---@field formation boolean Ctrl held → slowest-speed "move in formation".
---@field keepSelection boolean Space (meta) held → keep the moved squad selected instead of restoring the prior selection.

local pendingDragCreate = nil ---@type PendingDragCreate?
local pendingSquadMove = nil ---@type PendingSquadMove?
local highlightLockedSquad = nil ---@type Squad? while Shift is held over the squad-move highlight, the latched target squad — so a Shift-queue stays on one squad even as the cursor drifts near others
local beforeSquadSelectCallback = nil ---@type fun(info: table): (boolean|table)? optional WG hook: return false to cancel a doSquadSelect call
local squadChangeListeners = {} -- array of callback functions

-- Unit classification caches (declared early so utility helpers capture locals, not globals).
local defidOf = {} ---@type table<number, number|false> unitID -> defID (false when lookup fails; nil means "not cached")
local isCombat = {} ---@type table<number, boolean> defID -> squad-eligible
local isFactory = {} ---@type table<number, boolean> defID -> immobile with buildOptions
local isStrafingAir = {} ---@type table<number, boolean> defID -> air units that strafe/fly around while idle
local unitDomain = {} ---@type table<number, Domain?> defID -> movement domain (nil when not classified)

---@class LastSquadSelect Snapshot of the most recent doSquadSelect tap.
---@field t any Spring timer at tap time (for the double-tap window).
---@field x number Mouse screen x at tap time.
---@field y number Mouse screen y at tap time.
---@field append boolean? Whether the tap appended (vs replaced).
---@field kind string Logical selection type ("plain"/"filtered"/"group", optionally ":portion"); same-mode gestures only fire on a matching kind.
---@field squad Squad? Final target squad once known; stays nil on no-ops (the reserve-merge gate relies on this).

--- Most recent successful doSquadSelect; powers two same-mode double-tap gestures
--- (replace→replace fires viewselection, append→append upgrades plain append to
--- append_domain), both gated to a matching `kind` (selection type) so mixed
--- sequences don't fire, and gates the reserve-merge branch of
--- createSquadFromSelection on `squad`.
---@type LastSquadSelect?
local lastSquadSelect = nil

-------------------------------------------------------------------------------
-- Debug
-------------------------------------------------------------------------------

-- Varargs so call sites pay no concatenation cost when debug is off.
local function log(...)
	if not config.debug then
		return
	end
	local n = select("#", ...)
	if n == 1 then
		spEcho("[Squad] " .. tostring((...)))
		return
	end
	local parts = { ... }
	for i = 1, n do
		parts[i] = tostring(parts[i])
	end
	spEcho("[Squad] " .. table.concat(parts))
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

---@param x number
---@param min number
---@param max number
---@return number
local function constrain(x, min, max)
	return math.max(min, math.min(max, x))
end

-- Move `current` toward `target` by at most `step` (for animated blends).
---@param current number
---@param target number
---@param step number
---@return number
local function approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Recompute whether a squad is "idle" (>50% units with no commands).
---@param sq Squad
---@return boolean idle
local function refreshSquadIdleState(sq)
	local size = #sq
	if size == 0 then
		squadIdleState[sq] = false
		squadHideIdleAirHull[sq] = false
		return false
	end

	local threshold = math.floor(size * 0.5) + 1
	local idle = 0
	local idleReached = false
	for i = 1, size do
		if spGetUnitCommandCount(sq[i]) == 0 then
			idle = idle + 1
			if idle >= threshold then
				idleReached = true
				break
			end
		end
		if idle + (size - i) < threshold then
			break
		end
	end

	if not idleReached then
		squadIdleState[sq] = false
		squadHideIdleAirHull[sq] = false
		return false
	end

	squadIdleState[sq] = true

	-- Hide hull only when the whole squad is strafing-air and currently flying.
	local hideHull = true
	for i = 1, size do
		local u = sq[i]
		local defId = defidOf[u]
		if not (defId and isStrafingAir[defId]) then
			hideHull = false
			break
		end
		local x, y, z = spGetUnitPosition(u)
		if not x then
			hideHull = false
			break
		end
		if y <= spGetGroundHeight(x, z) + 50 then
			hideHull = false
			break
		end
	end
	squadHideIdleAirHull[sq] = hideHull
	return true
end

local function sweepIdleState()
	local present = {}
	for i = 1, #squads do
		present[squads[i]] = true
	end
	for sq, _ in pairs(squadIdleState) do
		if not present[sq] then
			squadIdleState[sq] = nil
			squadIdleBlend[sq] = nil
			squadHideIdleAirHull[sq] = nil
			squadHighlightBlend[sq] = nil
			squadControlBlend[sq] = nil
		end
	end
	if highlightLockedSquad and not present[highlightLockedSquad] then
		highlightLockedSquad = nil
	end
end

-------------------------------------------------------------------------------
-- Squad identity
--
-- Each squad gets a monotonically increasing number index on creation,
-- stored as squad.index. Companion widgets use this to derive their own
-- colors, letters, or other visuals. squad.tag_seed (golden-ratio step
-- over index) is used internally for hull animation phase offsets and color.
-------------------------------------------------------------------------------

local nextSquadTag = 0

-------------------------------------------------------------------------------
-- Per-squad color helpers
-------------------------------------------------------------------------------

local GOLDEN_HUE_STEP = 0.381966
local SQUAD_SAT = 0.75
local SQUAD_VAL = 0.7

local function hsvToRgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

local function indexToColor(idx)
	local h = ((idx - 1) * GOLDEN_HUE_STEP) % 1
	return hsvToRgb(h, SQUAD_SAT, SQUAD_VAL)
end

---@param squad Squad Receives .index, .tagSeed and .color.
local function assignSquadTag(squad)
	nextSquadTag = nextSquadTag + 1
	squad.index = nextSquadTag
	-- Golden-ratio step spreads consecutive squads ~0.618 of a period apart.
	squad.tagSeed = nextSquadTag * 0.6180339887
	squad.color = { indexToColor(nextSquadTag) }
end

-- Unit classification
--
-- isCombat[defID] — true if the unit type is squad-eligible.
-------------------------------------------------------------------------------

---@param unitId number
---@return number|false defID an number defID, or false when the lookup fails
local function getDefid(unitId)
	local v = defidOf[unitId]
	if v ~= nil then
		return v
	end
	local id = spGetUnitDefID(unitId)
	v = id or false
	defidOf[unitId] = v
	return v
end

-- Curated constructor + commander list. Every mobile unit is squad-eligible by
-- default; these are excluded when config.excludeConstructors is on. A literal
-- list (rather than a buildOptions heuristic) because BAR has too many
-- faction/tier/edge cases — combat units that happen to build (Commando, Infestor)
local CONSTRUCTOR_UNITS = "armcom,corcom,armca,corca,armck,corck,armcs,corcs,armbeaver,cormuskrat,armcv,corcv,armaca,coraca,corch,armch,armack,corack,corcsa,armcsa,armacv,coracv,armacsub,coracsub,legck,legcom,legack,legcv,legotter,legacv,legca,legaca,legnavyconship,leganavyconsub,legch,legspcon"

-- Curated resurrection-unit list.
local RESURRECTION_UNITS = "armrectr,cornecro,legrezbot,legnavyrezsub,armrecl,correcl"

-- Curated combat-engineer list.
local COMBAT_ENGINEER_UNITS = "armfark,legaceb,armconsul,corfast,legdecom,armdecom,cordecom,leganavyengineer,armmls,cormls"

--- Parse a comma-separated name list into `set[name] = true` (whitespace trimmed).
---@param set table<string, boolean>
---@param csv string
local function addExcludedNames(set, csv)
	for name in csv:gmatch("[^,]+") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
end

--- Pre-compute isCombat for every defID in one pass.
--
-- Squad eligibility is "any mobile unit, minus exclusions".
local function classifyUnitdefs()
	local excluded = {}
	if config.excludeConstructors then
		addExcludedNames(excluded, CONSTRUCTOR_UNITS)
	end
	if config.excludeResurrectionUnits then
		addExcludedNames(excluded, RESURRECTION_UNITS)
	end
	if config.excludeCombatEngineers then
		addExcludedNames(excluded, COMBAT_ENGINEER_UNITS)
	end
	if config.excludedUnitTypes and config.excludedUnitTypes ~= "" then
		addExcludedNames(excluded, config.excludedUnitTypes)
	end

	for defID, def in pairs(UnitDefs) do
		-- Squad eligibility, speed is needed because of mines
		if def.canMove and def.speed and def.speed > 0 and not excluded[def.name] then
			isCombat[defID] = true
		else
			isCombat[defID] = false
		end

		if def.isFactory then
			isFactory[defID] = true
		end

		isStrafingAir[defID] = def.isStrafingAirUnit and true or false

		if def.canFly then
			unitDomain[defID] = "air"
		elseif def.minWaterDepth and def.minWaterDepth > 0 then
			unitDomain[defID] = "naval"
		else
			unitDomain[defID] = "land"
		end
	end
end

---@param defId number
---@return Domain
local function reserveDomainForDef(defId)
	return unitDomain[defId] or "land"
end

---@param defId number
---@return Squad
local function getUncategorizedReserveForDef(defId)
	local d = reserveDomainForDef(defId)
	return uncategorizedReserve[d] or uncategorizedReserve.land
end

-------------------------------------------------------------------------------
-- Squad change listeners
--
-- Companion widgets register via WG['squadselection'].addSquadChangeListener(fn).
-- Callbacks receive (event, unitID, squad):
--   "add"     — unitID was added to squad
--   "remove"  — unitID was removed from squad (fired before internal cleanup)
--   "rebuild" — wholesale state change; unitID and squad are nil.
--               Listeners should re-read getSquadState() and rebuild from scratch.
-- Registering a listener immediately fires "rebuild" so the companion can sync.
-------------------------------------------------------------------------------

---@param event "add"|"remove"|"rebuild"
---@param unitId number? nil for "rebuild".
---@param squad Squad? nil for "rebuild".
local function notifySquadChange(event, unitId, squad)
	for i = 1, #squadChangeListeners do
		local ok, err = pcall(squadChangeListeners[i], event, unitId, squad)
		if not ok then
			spEcho("[Squad] listener error: " .. tostring(err))
		end
	end
end

-------------------------------------------------------------------------------
-- Squad operations
-------------------------------------------------------------------------------

---@param unitId number
---@param squad Squad
local function addToSquad(unitId, squad)
	local slot = #squad + 1
	squad[slot] = unitId
	unitSquad[unitId] = squad
	unitSlot[unitId] = slot
	if squad.index then
		notifySquadChange("add", unitId, squad)
	end
	squadIdleState[squad] = false
	squadHideIdleAirHull[squad] = false
end

-- Swap-with-last removal: O(1), order within a squad is not meaningful.
---@param unitId number
local function removeFromSquad(unitId)
	local squad = unitSquad[unitId]
	if not squad then
		return
	end

	notifySquadChange("remove", unitId, squad)

	local slot = unitSlot[unitId]
	local last = squad[#squad]

	if last ~= unitId then
		squad[slot] = last
		unitSlot[last] = slot
	end

	squad[#squad] = nil
	unitSquad[unitId] = nil
	unitSlot[unitId] = nil
	squadIdleState[squad] = false
	squadHideIdleAirHull[squad] = false
end

-------------------------------------------------------------------------------
-- MRU (most-recently-used squads)
--
-- Push points are both inside createSquadFromSelection: successful squad
-- creation, and right-click on a selection that already matches an existing squad.
-- Plain selection changes and command issuance do NOT push.
-------------------------------------------------------------------------------

---@param sq Squad?
local function pushToMru(sq)
	if not sq then
		return
	end
	for i = 1, #mru do
		if mru[i] == sq then
			table.remove(mru, i)
			break
		end
	end
	table.insert(mru, 1, sq)
	while #mru > config.mruSize do
		mru[#mru] = nil
	end
end

local function sweepMru()
	local present = {}
	for _, sq in ipairs(squads) do
		present[sq] = true
	end
	for i = #mru, 1, -1 do
		if not present[mru[i]] then
			table.remove(mru, i)
		end
	end
end

---@param i number Index into `mru` (1 = most recent).
local function recallMru(i)
	local sq = mru[i]
	if not sq then
		return
	end
	local units = {}
	for j = 1, #sq do
		units[j] = sq[j]
	end
	spSelectUnitArray(units)
	spSendCommands("viewselection")
end

-- A squad is prunable when empty, except:
--   - the uncategorized reserve is permanent
--   - factory reserves are kept while any factory still references them
---@param sq Squad
---@return boolean
local function isPrunable(sq)
	if #sq ~= 0 then
		return false
	end
	if sq.uncatDomain then
		return false
	end
	if sq.fromFactory then
		for _, fsq in pairs(factorySquad) do
			if fsq == sq then
				return false
			end
		end
		return true
	end
	return not sq.isReserve
end

local function pruneEmptySquads()
	for i = #squads, 1, -1 do
		local sq = squads[i]
		if isPrunable(sq) then
			log("Squad [", sq.index or "?", "] emptied and removed")
			squadSelCount[sq] = nil
			table.remove(squads, i)
		end
	end
	sweepMru()
	sweepIdleState()
end

-------------------------------------------------------------------------------
-- Squad creation from selection
-------------------------------------------------------------------------------

-- Returns true if `unitId`'s command queue contains a CMD_WAIT anywhere.
-- Used by the uncategorized-reserve path in UnitCreated to skip the selection
-- auto-extend for a freshly resurrected unit (rez bots leave units in
-- CMD_WAIT until fully healed).
local function unitQueueHasWait(unitId)
	local cmds = spGetUnitCommands(unitId, -1)
	if not cmds then
		return false
	end
	for i = 1, #cmds do
		if cmds[i].id == CMD.WAIT then
			return true
		end
	end
	return false
end

-- Returns true if the factory's command queue ends with CMD_WAIT or
-- CMD_PATROL — i.e. the rally's last waypoint is a "stay busy here" signal
-- rather than a move-and-forget. Used to opt the reserve out of the
-- selection auto-extend in UnitCreated.
local function factoryRallyEndsWithWaitOrPatrol(factoryId)
	local cmds = spGetUnitCommands(factoryId, -1)
	if not cmds or #cmds == 0 then
		return false
	end

	local lastId = cmds[#cmds].id
	return lastId == CMD.WAIT or lastId == CMD.PATROL
end

-- Returns true if every unit in `sq` is present in `selectedSet`.
-- Empty squads return false to avoid vacuous matches.
---@param sq Squad
---@param selectedSet table<number, boolean>
---@return boolean
local function squadFullySelected(sq, selectedSet)
	if #sq == 0 then
		return false
	end
	for i = 1, #sq do
		if not selectedSet[sq[i]] then
			return false
		end
	end
	return true
end

-- Returns the squad if the selection's combat units exactly match one squad
-- (including reserves), nil otherwise.
---@param selected number[] unitIDs (typically from spGetSelectedUnits).
---@return Squad?
local function selectionIsExistingSquad(selected)
	local squad = nil ---@type Squad?
	local combatCount = 0
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			combatCount = combatCount + 1
			local s = unitSquad[u]
			if squad == nil then
				squad = s
			elseif s ~= squad then
				return nil
			end
		end
	end
	if squad == nil or #squad ~= combatCount then
		return nil
	end
	return squad
end

--- Create a new hidden reserve squad and register it in `squads`.
-- Used for per-factory auto-squads and the uncategorized reserve.
---@param fromFactory boolean? True for per-factory auto-squads.
---@return Squad
local function makeReserveSquad(fromFactory)
	local sq = {} ---@type Squad
	assignSquadTag(sq)
	sq.isReserve = true
	sq.fromFactory = fromFactory or false
	squads[#squads + 1] = sq
	return sq
end

--- Auto-create a reserve squad for a newly built/received factory.
---@param factoryId number
---@return Squad
local function createFactorySquad(factoryId)
	local sq = makeReserveSquad(true)
	factorySquad[factoryId] = sq
	log("Factory ", factoryId, " → auto squad [", sq.index, "]")
	return sq
end

--- "This selection becomes one squad" — merges or splits depending on state.
--  - If the selection already exactly occupies one squad (no other factories
--    reference it) → no-op.
--  - Otherwise → reassign all selected factories to a fresh shared squad.
--    Units already built stay in their old squads
local function assignFactorySquad()
	local selected = spGetSelectedUnits()
	local factories = {} ---@type number[]
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isFactory[defId] then
			factories[#factories + 1] = u
		end
	end
	if #factories == 0 or #factories ~= #selected then
		return
	end

	-- Detect the "already exactly one squad" case.
	local selectionSet = {}
	for i = 1, #factories do
		selectionSet[factories[i]] = true
	end
	if not factories[1] then
		return
	end
	local shared = factorySquad[factories[1]]
	local allShare = shared ~= nil
	for i = 2, #factories do
		if factorySquad[factories[i]] ~= shared then
			allShare = false
			break
		end
	end
	if allShare then
		local extra = false
		for fid, sq in pairs(factorySquad) do
			if sq == shared and not selectionSet[fid] then
				extra = true
				break
			end
		end
		if not extra then
			return
		end
	end

	-- Reassign all selected factories to a fresh shared squad.
	local newSquad = makeReserveSquad(true)
	for i = 1, #factories do
		factorySquad[factories[i]] = newSquad
	end

	pruneEmptySquads()

	log("Factory squad [", newSquad.index, "] assigned to ", #factories, " factory(s)")
end

local playerInputSinceLastResquad = false
local function createSquadFromSelection(unitThatMustBeInSelection)
	local selected = spGetSelectedUnits()
	if #selected == 0 then
		return
	end

	local requiredUnitPresent = false
	if unitThatMustBeInSelection then
		for i = 1, #selected do
			if selected[i] == unitThatMustBeInSelection then
				requiredUnitPresent = true
			end
		end
		if not requiredUnitPresent then
			return
		end
	end

	local existing = selectionIsExistingSquad(selected)
	if existing and not existing.isReserve then
		pushToMru(existing)
		return
	end

	-- `existing` being nil here means the selection spans more than one squad
	-- (or partial squads). If it fully contains a reserve squad in that mix
	-- AND the player's last widget squad-select targeted that same reserve,
	-- merge the rest of the selection INTO that reserve instead of creating a
	-- new manual squad. When the selection is exactly one reserve (`existing`
	-- set + isReserve), we skip this branch and fall through to new-squad
	-- creation — extracting the reserve into a manual squad is the intended
	-- action in that case.
	--
	-- The `lastSquadSelect.squad == sq` gate captures player intent: merging
	-- only happens when the player explicitly squad-selected the reserve via
	-- the widget. Manual selections that happen to include all of a (possibly
	-- one-unit) reserve don't trigger merges — common case is selecting a
	-- fresh factory output to reinforce a manual squad, where the new unit's
	-- reserve being trivially "fully selected" used to swallow the manual
	-- squad on squad_create.
	local targetReserve = lastSquadSelect and lastSquadSelect.squad
	if not existing and targetReserve and targetReserve.isReserve and config.mergeIntoReserves then
		local selectedSet = {}
		for i = 1, #selected do
			selectedSet[selected[i]] = true
		end
		if squadFullySelected(targetReserve, selectedSet) then
			local sq = targetReserve
			local moved = 0
			for i = 1, #selected do
				local u = selected[i]
				local defId = getDefid(u)
				if defId and isCombat[defId] and unitSquad[u] ~= sq then
					removeFromSquad(u)
					addToSquad(u, sq)
					moved = moved + 1
				end
			end
			pruneEmptySquads()
			playerInputSinceLastResquad = false
			notifySquadChange("rebuild", nil, nil)
			selectionDirty = true
			pushToMru(sq)

			local units = {}
			for i = 1, #sq do
				units[i] = sq[i]
			end
			spSelectUnitArray(units)

			log("Merged ", moved, " unit(s) → reserve squad [", sq.index or "?", "]")
			return
		end
	end

	local newSquad = {} ---@type Squad
	for i = 1, #selected do
		local u = selected[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			removeFromSquad(u)
			addToSquad(u, newSquad)
			playerInputSinceLastResquad = false
		end
	end

	if #newSquad == 0 then
		return
	end

	-- A non-reserve source squad fully consumed by the selection is now
	-- empty; inherit its identity so the player's "real" squad carries on
	-- under the same index instead of getting a fresh one.
	local donor ---@type Squad?
	for _, sq in ipairs(squads) do
		if #sq == 0 and not sq.isReserve then
			donor = sq
			break
		end
	end

	if donor then
		newSquad.index, newSquad.tagSeed, newSquad.color = donor.index, donor.tagSeed, donor.color
	else
		assignSquadTag(newSquad)
	end
	squads[#squads + 1] = newSquad
	pruneEmptySquads()
	playerInputSinceLastResquad = false
	notifySquadChange("rebuild", nil, nil)
	-- Selection itself didn't change, but selected units moved between squads.
	-- Force DrawWorldPreUnit to rebuild per-squad selected counts.
	selectionDirty = true
	pushToMru(newSquad)

	log("New squad [", newSquad.index, "]: ", #newSquad, " units")
end

-------------------------------------------------------------------------------
-- Finding closest unit
--
-- Returns the mouse cursor's world position, then iterates all tracked units
-- to find the one nearest to it.
-------------------------------------------------------------------------------

local function getMouseWorldPos()
	local mx, my = spGetMouseState()

	-- PIP minimap: when active, the engine minimap is hidden/minimized so
	-- spGetMiniMapGeometry() returns stale data. Use the WG API instead.
	local wgMinimap = WG and WG["minimap"]
	local wgPip0 = WG and WG["pip0"]
	local pipMinimized = wgPip0 and wgPip0.IsMinimized and wgPip0.IsMinimized()
	if wgMinimap and wgMinimap.isPipMinimapActive and wgMinimap.isPipMinimapActive() and not pipMinimized then
		local getBounds = wgMinimap.getScreenBounds ---@type function?
		if getBounds then
			local l, b, r, t = getBounds()
			if l and r > l and t > b and mx >= l and mx <= r and my >= b and my <= t then
				local rx = (mx - l) / (r - l)
				local ry = (my - b) / (t - b)
				local wx = Game.mapSizeX * rx
				local wz = Game.mapSizeZ - Game.mapSizeZ * ry
				return wx, wz
			end
		end
	end

	-- Standard minimap (engine geometry).
	local mmX, mmY, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	if mmX and mmW > 0 and mmH > 0 and not minimized and not maximized then
		local rx = (mx - mmX) / mmW
		local ry = (my - mmY) / mmH
		if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
			local wx = Game.mapSizeX * rx
			local wz = Game.mapSizeZ - Game.mapSizeZ * ry
			return wx, wz
		end
	end

	-- Normal path: trace screen ray into the 3D world.
	local _, coords = spTraceScreenRay(mx, my, true)
	if not coords then
		return nil
	end
	return coords[1], coords[3] -- world x, world z
end

-- Cylinder radius (elmos) for perf heuristic.
local SEARCH_RADIUS = 850

-- Full scan over every tracked unit. Fallback when the cylinder finds nothing.
local function findClosestSquadFullScan(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq)
	local bestUnit = nil
	local bestDistSq = maxDistSq or math.huge

	for _, squad in ipairs(squads) do
		local squadOk = true
		if domainFilter then
			for j = 1, #squad do
				local did = defidOf[squad[j]]
				local d = did and unitDomain[did]
				if d and not domainFilter[d] then
					squadOk = false
					break
				end
			end
		end
		if squadOk then
			for j = 1, #squad do
				local u = squad[j]
				if not (exclude and exclude[u]) and not (groupSet and not groupSet[u]) then
					if not filterDefs or (defidOf[u] and filterDefs[defidOf[u]]) then
						local x, _, z = spGetUnitPosition(u)
						if x then
							local dx = x - wx
							local dz = z - wz
							local distSq = dx * dx + dz * dz
							if distSq < bestDistSq then
								bestDistSq = distSq
								bestUnit = u
							end
						end
					end
				end
			end
		end
	end

	return bestUnit and unitSquad[bestUnit] or nil, bestUnit
end

-- Returns the squad containing the unit closest to (wx, wz), or nil if none.
-- Optional filterDefs (defID set), groupSet (unitID set), and exclude
-- (unitID set) narrow the search. A unit is a candidate only if it passes all three filters.
-- domainFilter (set of allowed domain strings) rejects entire squads whose
-- units include any domain not in the set — so e.g. a pure-land filter skips
-- mixed land+air squads, not just their air units.
--
-- A cylinder around the cursor pre-filters the candidates.
---@param filterDefs table<number, boolean>? defID set; a unit qualifies only if its defID is present.
---@param groupSet table<number, boolean>? unitID set; a unit qualifies only if it is a member.
---@param exclude table<number, boolean>? unitID set to skip (e.g. already-selected units when cycling).
---@param wx number Cursor world x.
---@param wz number Cursor world z.
---@param domainFilter table<Domain, boolean>? Allowed domains; rejects entire squads containing any other domain.
---@param maxDistSq number? Squared world-distance cap; nil falls back to SEARCH_RADIUS then a full scan.
---@return Squad? squad, number? closestUnit
local function findClosestSquad(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq)
	local radius = maxDistSq and math.sqrt(maxDistSq) or SEARCH_RADIUS
	local candidates = spGetUnitsInCylinder(wx, wz, radius)

	local bestUnit = nil
	local bestDistSq = maxDistSq or math.huge
	local domainOk = {} ---@type table<Squad, boolean> memo: squad table -> bool

	for i = 1, #candidates do
		local u = candidates[i]
		local squad = unitSquad[u] -- nil for untracked units (enemy/allied/non-combat)
		if squad and not (exclude and exclude[u]) and not (groupSet and not groupSet[u]) then
			if not filterDefs or (defidOf[u] and filterDefs[defidOf[u]]) then
				-- domainFilter is squad-level: check the whole squad, not just its
				-- in-cylinder units. Memoized so each squad is inspected once.
				local squadOk = true
				if domainFilter then
					local cached = domainOk[squad]
					if cached ~= nil then
						squadOk = cached
					else
						for j = 1, #squad do
							local did = defidOf[squad[j]]
							local d = did and unitDomain[did]
							if d and not domainFilter[d] then
								squadOk = false
								break
							end
						end
						domainOk[squad] = squadOk
					end
				end
				if squadOk then
					local x, _, z = spGetUnitPosition(u)
					if x then
						local dx = x - wx
						local dz = z - wz
						local distSq = dx * dx + dz * dz
						if distSq < bestDistSq then
							bestDistSq = distSq
							bestUnit = u
						end
					end
				end
			end
		end
	end

	-- Unbounded miss: a qualifying squad, if any, is farther than SEARCH_RADIUS.
	if not bestUnit and not maxDistSq then
		return findClosestSquadFullScan(filterDefs, groupSet, exclude, wx, wz, domainFilter, maxDistSq)
	end

	return bestUnit and unitSquad[bestUnit] or nil, bestUnit
end

-------------------------------------------------------------------------------
-- Selection analysis
-------------------------------------------------------------------------------

---@class SelectionInfo Summary of the current selection used by squad-select actions.
---@field selectedSet table<number, boolean> unitID -> true, for O(1) membership tests.
---@field selectedTypeSet table<number, boolean> defIDs present in the selection (tracked squad units only). Filters squads by unit type, e.g. "select all Grunts in the closest squad".
---@field selectedDomainSet table<Domain, boolean> domains ("land"/"air"/"naval") in the selection. Used by append_domain to constrain cycling to compatible squads.
---@field hasTrackedUnits boolean True when at least one selected unit is a tracked squad unit with a known type; otherwise callers fall back to type-agnostic behavior.

--- Inspect the current selection and return a summary used by squad-select actions.
---@return SelectionInfo
local function analyzeSelection()
	local selected = spGetSelectedUnits()
	local selectedSet = {}
	local selectedTypeSet = {}
	local selectedDomainSet = {}
	local hasTrackedUnits = false

	for i = 1, #selected do
		local u = selected[i]
		selectedSet[u] = true
		if unitSquad[u] then
			local defId = defidOf[u]
			if defId then
				selectedTypeSet[defId] = true
				local d = unitDomain[defId]
				if d then
					selectedDomainSet[d] = true
				end
				hasTrackedUnits = true
			end
		end
	end

	return {
		selectedSet = selectedSet,
		selectedTypeSet = selectedTypeSet,
		selectedDomainSet = selectedDomainSet,
		hasTrackedUnits = hasTrackedUnits,
	}
end

-------------------------------------------------------------------------------
-- Selection primitives
--
-- All six selection actions share one core, doSquadSelect. The per-action
-- wrappers only differ in which opts they pass:
--
--   whole-squad / filtered / group    → steps={1}, cycleWhenFull=true
--   portion / portion-filtered /group → steps=<parsed>, cycleWhenFull=false
--
-- Filtering by unit type and by control group is expressed uniformly via the
-- filterDefs / groupSet options.
-------------------------------------------------------------------------------

--- Convert a step value to a unit count.
-- 0 → 1 unit; 0 < step <= 1 → percentage; step > 1 → fixed count.
---@param step number|1|integer
---@param poolSize number
---@return number
local function stepToCount(step, poolSize)
	if poolSize <= 0 then
		return 0
	end
	if step <= 0 then
		return 1
	end
	if step <= 1 then
		return math.max(1, math.ceil(step * poolSize))
	end
	return math.min(math.floor(step), poolSize)
end

--- Parse portion action args: optional "append"/"append_domain" keyword,
-- optional "distance_<N>" modifier that caps selection to units within N
-- world-distance of the cursor, plus step numbers. "append_domain" implies
-- append and additionally restricts squad cycling to domains present in the
-- current selection.
---@param args (string|number)[]? Raw action args.
---@return boolean append, boolean useDomainFilter, number[] steps, number? maxDistance, boolean retarget
local function parsePortionArgs(args)
	if not args then
		return false, false, {}, nil, false
	end
	local append = false
	local useDomainFilter = false
	local retarget = false
	local steps = {}
	local maxDistance
	for i = 1, #args do
		local arg = args[i]
		if arg == "append" then
			append = true
		elseif arg == "append_domain" then
			append = true
			useDomainFilter = true
		elseif arg == "retarget" then
			retarget = true
		elseif type(arg) == "string" and arg:sub(1, 9) == "distance_" then
			local d = tonumber(arg:sub(10))
			if d and d > 0 then
				maxDistance = d
			end
		else
			local n = tonumber(arg)
			if n then
				steps[#steps + 1] = n
			end
		end
	end
	return append, useDomainFilter, steps, maxDistance, retarget
end

--- Sort a unit array in-place by distance to a world point.
---@param units number[]
---@param wx number
---@param wz number
local function sortUnitsByDistance(units, wx, wz)
	local distCache = {}
	for i = 1, #units do
		local u = units[i]
		local x, _, z = spGetUnitPosition(u)
		if x then
			distCache[u] = (x - wx) * (x - wx) + (z - wz) * (z - wz)
		else
			distCache[u] = math.huge
		end
	end
	table.sort(units, function(a, b)
		return distCache[a] < distCache[b]
	end)
end

--- Build a squad's pool(s): units matching the optional filters.
-- Returns (pool, stepPool). stepPool is the filter-only pool used for step
-- progression; pool is stepPool additionally capped to units within
-- maxDistanceSq of (wx, wz). When maxDistanceSq is nil the two are the
-- same array.
---@param squad Squad
---@param filterDefs table<number, boolean>? defID set narrowing the pool to matching unit types.
---@param groupSet table<number, boolean>? unitID set narrowing the pool to control-group members.
---@param maxDistanceSq number? Squared world-distance cap from (wx, wz); nil → pool == stepPool.
---@param wx number Cursor world x.
---@param wz number Cursor world z.
---@return number[] pool, number[] stepPool
local function buildPools(squad, filterDefs, groupSet, maxDistanceSq, wx, wz)
	local stepPool = {} ---@type number[]
	local pool = maxDistanceSq and {} or stepPool ---@type number[]
	for j = 1, #squad do
		local u = squad[j]
		if (not groupSet or groupSet[u]) and (not filterDefs or (defidOf[u] and filterDefs[defidOf[u]])) then
			stepPool[#stepPool + 1] = u
			if maxDistanceSq then
				local ux, _, uz = spGetUnitPosition(u)
				if ux then
					local dx = ux - wx
					local dz = uz - wz
					if dx * dx + dz * dz <= maxDistanceSq then
						pool[#pool + 1] = u
					end
				end
			end
		end
	end
	return pool, stepPool
end

--- Count how many pool units are already selected.
---@param pool number[]
---@param selectedSet table<number, boolean>
---@return integer
local function countSelectedIn(pool, selectedSet)
	local n = 0
	for i = 1, #pool do
		if selectedSet[pool[i]] then
			n = n + 1
		end
	end
	return n
end

--- True when every unit in pool is in selectedSet.
---@param pool number[]
---@param selectedSet table<number, boolean>
---@return boolean
local function poolFullySelected(pool, selectedSet)
	for i = 1, #pool do
		if not selectedSet[pool[i]] then
			return false
		end
	end
	return true
end

--- Walk the step progression: return the first resolved count greater than
-- `currentInPool`, or the last step's count once we're past the end
-- (no-op repeat).
---@param steps number[]
---@param poolSize number
---@param currentInPool number
---@return number
local function resolveTargetCount(steps, poolSize, currentInPool)
	for i = 1, #steps do
		local c = stepToCount(steps[i], poolSize)
		if c > currentInPool then
			return c
		end
	end
	return stepToCount(steps[#steps], poolSize)
end

--- Given a distance-sorted pool, pick which units go to SelectUnitArray.
-- Replace mode: first `targetCount` pool units.
-- Append mode: up to `targetCount` closest pool units that aren't already
-- selected (so repeated presses accumulate).
---@param pool number[] Distance-sorted candidate units.
---@param targetCount number
---@param selectedSet table<number, boolean>
---@param append boolean?
---@return number[] toSelect
local function pickUnits(pool, targetCount, selectedSet, append)
	local toSelect = {}
	if append then
		for i = 1, #pool do
			if not selectedSet[pool[i]] then
				toSelect[#toSelect + 1] = pool[i]
				if #toSelect >= targetCount then
					break
				end
			end
		end
	else
		for i = 1, targetCount do
			toSelect[i] = pool[i]
		end
	end
	return toSelect
end

--- Determine the defID set for filtered actions. Uses the selection's types
-- if any tracked units are selected; otherwise falls back to the closest
-- unit's type. Returns nil when nothing suitable is found (caller bails).
---@param sel SelectionInfo
---@param wx number
---@param wz number
---@return table<number, boolean>? filterDefs
local function resolveFilterDefs(sel, wx, wz)
	if sel.hasTrackedUnits then
		return sel.selectedTypeSet
	end
	local _, closest = findClosestSquad(nil, nil, nil, wx, wz)
	if not closest then
		return nil
	end
	local defId = defidOf[closest]
	if not defId then
		return nil
	end
	return {
		[defId] = true,
	}
end

--- Retarget variant: in replace mode, always peek the closest unit. If its
-- type is in the current selection's types, behave like resolveFilterDefs
-- (use the selection). If not, treat the click as a fresh selection on that
-- single new type — letting the player swing the filter to a different unit
-- type without first deselecting.
---@param sel SelectionInfo
---@param wx number
---@param wz number
---@return table<number, boolean>? filterDefs
local function resolveRetargetFilterDefs(sel, wx, wz)
	local _, closest = findClosestSquad(nil, nil, nil, wx, wz)
	if not closest then
		return resolveFilterDefs(sel, wx, wz)
	end
	local defId = defidOf[closest]
	if not defId then
		return resolveFilterDefs(sel, wx, wz)
	end
	if sel.hasTrackedUnits and sel.selectedTypeSet[defId] then
		return sel.selectedTypeSet
	end
	return {
		[defId] = true,
	}
end

--- Build a set of unitIDs belonging to a control group.
-- Tries GetGroupUnits first, falls back to iterating tracked units. (I copied this from another widget, I'm not sure how necessary it is)
---@param groupNum number
---@return table<number, boolean> groupSet
local function buildGroupSet(groupNum)
	local groupUnits = spGetGroupUnits(groupNum)

	local groupSet = {}
	if groupUnits and #groupUnits > 0 then
		for i = 1, #groupUnits do
			groupSet[groupUnits[i]] = true
		end
	else
		for _, squad in ipairs(squads) do
			for j = 1, #squad do
				local u = squad[j]
				if spGetUnitGroup(u) == groupNum then
					groupSet[u] = true
				end
			end
		end
	end
	return groupSet
end

-------------------------------------------------------------------------------
-- Unified squad selection core
-------------------------------------------------------------------------------

---@class SquadSelectOpts
---@field append boolean? Append to the current selection instead of replacing.
---@field steps number[]? Step values (nil → {1}, the whole pool). 0→1 unit, 0<n≤1→fraction of pool, n>1→fixed count.
---@field filterDefs table<number, boolean>? defID set; narrows the pool to matching unit types.
---@field groupSet table<number, boolean>? unitID set; narrows the pool to control-group members.
---@field maxDistance number? Cap the pool to units within this world distance of the cursor.
---@field cycleWhenFull boolean? When the closest squad's pool is already fully selected, re-pick a squad with those units excluded.
---@field useDomainFilter boolean? Restrict squad cycling to domains ("land"/"air"/"naval") present in the selection. Ignored when no tracked units are selected.
---@field isMousePress boolean? True for left-click-initiated selection, false for action/hotkey-initiated.

---@param opts SquadSelectOpts?
local function doSquadSelect(opts)
	opts = opts or {}

	local wx, wz = getMouseWorldPos()
	if not wx then
		return
	end

	local mx, my = spGetMouseState()

	-- External hook for companion widgets.
	-- Return false to veto selection.
	-- Return a table to shallow-override opts for this call.
	if beforeSquadSelectCallback then
		local ok, hookResult = pcall(beforeSquadSelectCallback, {
			opts = opts,
			mx = mx,
			my = my,
			wx = wx,
			wz = wz,
			selected = spGetSelectedUnits(),
		})
		if not ok then
			log("beforeSquadSelect callback error: ", hookResult)
		elseif hookResult == false then
			return
		elseif type(hookResult) == "table" then
			for k, v in pairs(hookResult) do
				opts[k] = v
			end
		end
	end

	local steps = opts.steps or { 1 }
	if #steps == 0 then
		return
	end

	-- Selection "kind" identifies the logical selection type so the same-mode
	-- double-tap gestures only fire on a same-type repeat: e.g. a squadSelect
	-- followed by a squadSelectFiltered must not trigger viewselection. The
	-- filter/group dimension plus whole-vs-portion (the codebase's whole-squad
	-- definition is exactly {} or {1}) captures every action variant.
	local kind = (opts.groupSet and "group") or (opts.filterDefs and "filtered") or "plain"
	if not (#steps == 1 and steps[1] == 1) then
		kind = kind .. ":portion"
	end

	-- Compute the double-tap window match against the *previous* tap, then
	-- snapshot its append flag and kind before we overwrite lastSquadSelect below.
	local inDoubleTapWindow = false
	local prevAppend = false ---@type boolean?
	local prevKind = nil
	if lastSquadSelect and config.viewselectionDoubleTapMs > 0 then
		local dtMs = spDiffTimers(spGetTimer(), lastSquadSelect.t, true)
		local dx = mx - lastSquadSelect.x
		local dy = my - lastSquadSelect.y
		local px = config.viewselectionDoubleTapPx
		inDoubleTapWindow = dtMs < config.viewselectionDoubleTapMs and (dx * dx + dy * dy) < (px * px)
		prevAppend = lastSquadSelect.append
		prevKind = lastSquadSelect.kind
	end

	-- Arm now (not at the end) so subsequent taps detect this one even when the selection ends up a no-op.
	-- `squad` is filled in below once the final target is known; staying nil on no-ops is the correct
	-- signal for createSquadFromSelection's reserve-merge gate (no widget selection happened).
	lastSquadSelect = {
		t = spGetTimer(),
		x = mx,
		y = my,
		append = opts.append,
		kind = kind,
		squad = nil,
	}

	-- Single-step same-mode double-tap dispatch. Replace→replace fires
	-- viewselection. Append→append flips the domain filter
	if inDoubleTapWindow and prevAppend == opts.append and prevKind == kind then
		if opts.append then
			opts.useDomainFilter = not opts.useDomainFilter
		else
			if #steps == 1 then
				spSendCommands("viewselection")
				lastSquadSelect = nil
				return
			end
		end
	end

	local sel = analyzeSelection()
	local filterDefs = opts.filterDefs
	local groupSet = opts.groupSet
	local maxDistanceSq = opts.maxDistance and opts.maxDistance * opts.maxDistance or nil
	local domainFilter = opts.useDomainFilter and sel.hasTrackedUnits and sel.selectedDomainSet or nil

	local targetSquad = findClosestSquad(filterDefs, groupSet, nil, wx, wz, domainFilter)
	if not targetSquad then
		return
	end
	local pool, stepPool = buildPools(targetSquad, filterDefs, groupSet, maxDistanceSq, wx, wz)

	if #stepPool == 0 then
		return
	end

	-- Multi-step calls need currentInStepPool to advance through the step
	-- progression; single-step ones only need fullySelected, which is a pure
	-- function of pool size and selection.
	local currentInStepPool = 0
	if #steps > 1 then
		currentInStepPool = countSelectedIn(stepPool, sel.selectedSet)
	end
	local fullySelected = #pool > 0 and poolFullySelected(pool, sel.selectedSet)

	-- Double-tap viewselection (late): multi-step replace fires only when the
	-- player has already reached the last step (no progression left), so
	-- intermediate taps still advance through steps as normal. Same same-mode
	-- gating as the early check — only replace→replace triggers.
	-- TODO: should work even with distance filter.
	if inDoubleTapWindow and prevKind == kind and #steps > 1 and not opts.append and not prevAppend and #pool > 0 and currentInStepPool >= stepToCount(steps[#steps], #stepPool) then
		spSendCommands("viewselection")
		lastSquadSelect = nil
		return
	end

	if opts.cycleWhenFull and fullySelected then
		-- If cycling finds no other squad (e.g. the player previously appended
		-- their way through every squad so nothing is unselected), keep the
		-- original target so a replace tap still replaces with the closest
		-- squad instead of silently doing nothing. For append, the empty
		-- pickUnits result later short-circuits to a no-op.
		local cycledTarget = findClosestSquad(filterDefs, groupSet, sel.selectedSet, wx, wz, domainFilter)
		if cycledTarget then
			targetSquad = cycledTarget
			pool, stepPool = buildPools(targetSquad, filterDefs, groupSet, maxDistanceSq, wx, wz)
			if #steps > 1 then
				currentInStepPool = countSelectedIn(stepPool, sel.selectedSet)
			end
		end
	end

	if #pool == 0 then
		return
	end

	local targetCount
	if #steps == 1 then
		targetCount = stepToCount(steps[1], #stepPool)
	else
		targetCount = resolveTargetCount(steps, #stepPool, currentInStepPool)
	end

	if targetCount < #pool then
		sortUnitsByDistance(pool, wx, wz)
	end
	local toSelect = pickUnits(pool, targetCount, sel.selectedSet, opts.append)
	if #toSelect == 0 then
		return
	end
	spSelectUnitArray(toSelect, opts.append)
	pushToMru(targetSquad)
	lastSquadSelect.squad = targetSquad

	log("Squad select [", targetSquad.index or "?", "]: ", #toSelect, "/", #pool, opts.append and " +append" or "")
end

-------------------------------------------------------------------------------
-- Action handlers (thin wrappers over doSquadSelect)
-------------------------------------------------------------------------------

local function squadSelect(_, _, args)
	local arg = args and args[1]
	local append = arg == "append" or arg == "append_domain"
	local useDomainFilter = arg == "append_domain"
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end

local function squadCreate()
	assignFactorySquad()
	createSquadFromSelection()
	return true
end

local function squadCycleRecent()
	if #mru == 0 then
		spEcho("[Squad] MRU is empty")
		return true
	end
	local currentSquad = selectionIsExistingSquad(spGetSelectedUnits())
	local currentIndex = 0
	for k = 1, #mru do
		if mru[k] == currentSquad then
			currentIndex = k
			break
		end
	end
	recallMru((currentIndex % #mru) + 1)
	return true
end

local function squadCycleIdle()
	if #squads == 0 then
		return true
	end

	local currentSquad = selectionIsExistingSquad(spGetSelectedUnits())
	local startIndex = 0
	if currentSquad then
		for i = 1, #squads do
			if squads[i] == currentSquad then
				startIndex = i
				break
			end
		end
	end

	local n = #squads
	for offset = 1, n do
		local sq = squads[((startIndex - 1 + offset) % n) + 1]
		local size = #sq
		if size > 0 and squadIdleState[sq] then
			local units = {}
			for j = 1, size do
				units[j] = sq[j]
			end
			spSelectUnitArray(units)
			spSendCommands("viewselection")
			pushToMru(sq)
			log("Idle squad [", sq.index or "?", "]")
			return true
		end
	end

	spEcho("[Squad] No idle squads found")
	return true
end

local function squadSelectFiltered(_, _, args)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end
	local arg = args and args[1]
	local append = arg == "append" or arg == "append_domain"
	local useDomainFilter = arg == "append_domain"
	local retarget = arg == "retarget"
	local sel = analyzeSelection()
	local filterDefs = (retarget and not append) and resolveRetargetFilterDefs(sel, wx, wz) or resolveFilterDefs(sel, wx, wz)
	if not filterDefs then
		return true
	end
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		filterDefs = filterDefs,
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end

local function squadSelectGroup(_, _, args)
	if not args or not args[1] then
		return true
	end
	local groupNum = tonumber(args[1])
	if not groupNum then
		return true
	end
	local arg = args[2]
	local append = arg == "append" or arg == "append_domain"
	local useDomainFilter = arg == "append_domain"
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		groupSet = buildGroupSet(groupNum),
		cycleWhenFull = append or config.cyclingToNextSquad,
	})
	return true
end

local function squadSelectPortion(_, _, args)
	local append, useDomainFilter, steps, maxDistance = parsePortionArgs(args)
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		maxDistance = maxDistance,
		cycleWhenFull = append,
	})
	return true
end

local function squadSelectPortionFiltered(_, _, args)
	local append, useDomainFilter, steps, maxDistance, retarget = parsePortionArgs(args)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end
	local sel = analyzeSelection()
	local filterDefs = (retarget and not append) and resolveRetargetFilterDefs(sel, wx, wz) or resolveFilterDefs(sel, wx, wz)
	if not filterDefs then
		return true
	end
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		filterDefs = filterDefs,
		maxDistance = maxDistance,
		cycleWhenFull = append,
	})
	return true
end

local function squadSelectPortionGroup(_, _, args)
	if not args or not args[1] then
		return true
	end
	local groupNum = tonumber(args[1])
	if not groupNum then
		return true
	end
	local remaining = {}
	for i = 2, #args do
		remaining[#remaining + 1] = args[i]
	end
	local append, useDomainFilter, steps, maxDistance = parsePortionArgs(remaining)
	doSquadSelect({
		append = append,
		useDomainFilter = useDomainFilter,
		steps = steps,
		groupSet = buildGroupSet(groupNum),
		maxDistance = maxDistance,
		cycleWhenFull = append,
	})
	return true
end

-- Shared core for squad_limit / squad_limit_flip. Picks the target squad (owner
-- of the tracked-selected unit closest to the cursor) and shapes the existing
-- selection against that one squad, dropping everything else. Replace-only.
--   do_flip == false → limit/narrow: result = selection ∩ target_squad.
--   do_flip == true  → limit AND flip: result = target_squad \ selection (the
--     target squad's other units). A fully-selected squad flips to empty.
--   No tracked units selected → fall back to plain closest-squad-select.
local function limitOrFlip(doFlip)
	local wx, wz = getMouseWorldPos()
	if not wx then
		return true
	end

	local sel = analyzeSelection()
	if not sel.hasTrackedUnits then
		doSquadSelect({
			cycleWhenFull = config.cyclingToNextSquad,
		})
		return true
	end

	local targetSquad
	local closestD2 = math.huge
	for u in pairs(sel.selectedSet) do
		local sq = unitSquad[u]
		if sq then
			local x, _, z = spGetUnitPosition(u)
			if x then
				local dx, dz = x - wx, z - wz
				local d2 = dx * dx + dz * dz
				if d2 < closestD2 then
					closestD2 = d2
					targetSquad = sq
				end
			end
		end
	end

	if not targetSquad then
		return true
	end

	local result = {}
	for i = 1, #targetSquad do
		local u = targetSquad[i]
		local selected = sel.selectedSet[u]
		if (doFlip and not selected) or (not doFlip and selected) then
			result[#result + 1] = u
		end
	end

	spSelectUnitArray(result)
	pushToMru(targetSquad)
	log(doFlip and "Flip" or "Limit", " squad [", targetSquad.index or "?", "]: ", #result, "/", #targetSquad)
	return true
end

local function squadLimitFlip()
	return limitOrFlip(true)
end

local function squadLimit()
	return limitOrFlip(false)
end

-- Always flips, across every squad that has a selected unit: each such squad's
-- selected units are swapped for its unselected ones. Cursor-independent.
local function squadFlip()
	local sel = analyzeSelection()
	if not sel.hasTrackedUnits then
		doSquadSelect({
			cycleWhenFull = config.cyclingToNextSquad,
		})
		return true
	end

	local flippedSquads = {}
	for u in pairs(sel.selectedSet) do
		local sq = unitSquad[u]
		if sq then
			flippedSquads[sq] = true
		end
	end

	local result = {}
	local squadCount = 0
	for sq in pairs(flippedSquads) do
		squadCount = squadCount + 1
		for i = 1, #sq do
			local u = sq[i]
			if not sel.selectedSet[u] then
				result[#result + 1] = u
			end
		end
		pushToMru(sq)
	end

	spSelectUnitArray(result)
	log("Flip ", squadCount, " squad(s): ", #result, " units")
	return true
end

-------------------------------------------------------------------------------
-- GL4 hull rendering
--
-- One shared VBO (2D world x,z + ground-sampled y) is re-uploaded per squad
-- per frame, then drawn as TRIANGLE_FAN (fill) and LINE_LOOP (border).
-- The 2D hull geometry is convex, so a fan starting from vertex 0 covers it.
-------------------------------------------------------------------------------

local HULL_MAX_VERTICES = 512
local hullShader = nil ---@type integer?
local hullColorLoc = nil ---@type GL?
local hullStripeLoc = nil ---@type GL?
local hullCentroidLoc = nil ---@type GL?
local hullPulseLoc = nil ---@type GL?
local hullVbo = nil ---@type VBO?
local hullVao = nil ---@type VAO?
local hullReady = false
local hullInitFailed = false -- so we don't spam retries after a failure
local hullTimeOrigin = nil ---@type integer? wall-clock origin for stripe/pulse animation

-- Center→edge alpha gradient: alpha at the centroid as a fraction of the edge.
local HULL_GRADIENT_CENTER = 0.2

local hullVsSrc = [[
#version 330 compatibility

layout(location = 0) in vec3 position;

out vec3 worldPos;

void main() {
	worldPos = position;
	gl_Position = gl_ModelViewProjectionMatrix * vec4(position, 1.0);
}
]]

local hullFsSrc = [[
#version 330 compatibility

uniform vec4 color;
// stripe.x = period in world units (0 disables stripes)
// stripe.y = alpha multiplier for the dim band
// stripe.z = phase offset in world units (per-squad, so overlapping hulls don't align)
uniform vec3 stripe;
// centroidRadius.xy = squad centroid in world XZ
// centroidRadius.z  = max distance from centroid to a perimeter vertex (gradient norm)
uniform vec3 centroidRadius;
// breathing alpha multiplier (per-squad phase, computed CPU-side)
uniform float pulse;
// alpha at the centroid as a fraction of the edge alpha
uniform float gradientCenter;

in vec3 worldPos;

out vec4 fragColor;

void main() {
	float a = color.a;

	if (stripe.x > 0.0) {
		float band = step(0.5, fract((worldPos.x + worldPos.z + stripe.z) / stripe.x));
		a *= mix(stripe.y, 1.0, band);
	}

	// soft center→edge alpha gradient
	vec2 toCenter = worldPos.xz - centroidRadius.xy;
	float dist = length(toCenter) / max(centroidRadius.z, 1.0);
	a *= mix(gradientCenter, 1.0, smoothstep(0.0, 1.0, dist));

	a *= pulse;

	fragColor = vec4(color.rgb, a);
}
]]

local function initGlHull()
	if hullReady or hullInitFailed then
		return hullReady
	end
	if not glCreateShader or not glGetVBO or not glGetVAO then
		log("GL4 unavailable — convex hull drawing disabled")
		hullInitFailed = true
		return false
	end

	hullShader = glCreateShader({
		vertex = hullVsSrc,
		fragment = hullFsSrc,
	})
	if not hullShader then
		local shaderLog = gl.GetShaderLog and gl.GetShaderLog() or "(no log)"
		log("Failed to compile hull shader: ", shaderLog)
		hullInitFailed = true
		return false
	end
	hullColorLoc = glGetUniformLocation(hullShader, "color")
	hullStripeLoc = glGetUniformLocation(hullShader, "stripe")
	hullCentroidLoc = glGetUniformLocation(hullShader, "centroidRadius")
	hullPulseLoc = glGetUniformLocation(hullShader, "pulse")
	local gradientLoc = glGetUniformLocation(hullShader, "gradientCenter")
	glUseShader(hullShader)
	glUniform(gradientLoc, HULL_GRADIENT_CENTER)
	glUseShader(0)

	hullVbo = glGetVBO(GL.ARRAY_BUFFER, false)
	if not hullVbo then
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VBO")
		hullInitFailed = true
		return false
	end
	hullVbo:Define(HULL_MAX_VERTICES, {
		{
			id = 0,
			name = "position",
			size = 3,
		},
	})

	hullVao = glGetVAO()
	if not hullVao then
		hullVbo:Delete()
		hullVbo = nil
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VAO")
		hullInitFailed = true
		return false
	end
	hullVao:AttachVertexBuffer(hullVbo)

	hullReady = true
	return true
end

local function cleanupGlHull()
	if hullVao then
		hullVao:Delete()
	end
	if hullVbo then
		hullVbo:Delete()
	end
	if hullShader then
		glDeleteShader(hullShader)
	end
	hullVao = nil
	hullVbo = nil
	hullShader = nil
	hullColorLoc = nil
	hullStripeLoc = nil
	hullCentroidLoc = nil
	hullPulseLoc = nil
	hullReady = false
	hullInitFailed = false
end

-------------------------------------------------------------------------------
-- Config write helper
--
-- setOptionValue(key, value) is the single config-write entry point, shared by
-- the squad_setting console action and the WG['squadselection'] set<Key> API.
-------------------------------------------------------------------------------

local function setOptionValue(key, value)
	config[key] = value
end

-- Forward declaration; defined in the Lifecycle section. Re-classifies and
-- re-routes every tracked unit (used by the exclude* settings written through
-- the panel/WG API and by the excludedUnitTypes console commands).
---@type fun(): number
local rebuildTracking

-------------------------------------------------------------------------------
-- Settings action — toggle/set config values from chat
-- Usage:
--   /luaui squad_setting toggle rightClickSquadCreate
--   /luaui squad_setting toggle ctrlRightClickCreatesSquad
--   /luaui squad_setting toggle cyclingToNextSquad
--   /luaui squad_setting set visualizationMode convexHull
--   /luaui squad_setting set visualizationMode none
--   /luaui squad_setting get cyclingToNextSquad
--   /luaui squad_setting reload
-------------------------------------------------------------------------------

local function squadSetting(_, _, args)
	if not args or not args[1] then
		spEcho("[Squad] Usage: squad_setting toggle|set|add|remove|get|reload <key> [value]")
		return
	end
	local action = args[1]

	if action == "reload" then
		for k, v in pairs(configDefaults) do
			setOptionValue(k, v)
		end
		rebuildTracking()
		spEcho("[Squad] Config reset to defaults from squad-selection.lua")
		return
	end

	local key = args[2]
	if not key or config[key] == nil then
		spEcho("[Squad] Unknown config key: " .. tostring(key))
		return
	end

	local function formatValue(v)
		if type(v) == "table" then
			return "[" .. table.concat(v, ", ") .. "]"
		end
		return tostring(v)
	end

	if action == "add" then
		if key ~= "excludedUnitTypes" then
			spEcho("[Squad] 'add' only applies to excludedUnitTypes")
			return
		end
		if not args[3] then
			spEcho("[Squad] Usage: squad_setting add excludedUnitTypes <name> [name ...]")
			return
		end
		local existing = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			existing[entry:match("^%s*(.-)%s*$")] = true
		end
		local parts = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			parts[#parts + 1] = entry:match("^%s*(.-)%s*$")
		end
		for i = 3, #args do
			local name = args[i]
			if not existing[name] then
				parts[#parts + 1] = name
				existing[name] = true
			end
		end
		setOptionValue(key, table.concat(parts, ","))
		rebuildTracking()
		spEcho('[Squad] excludedUnitTypes = "' .. config[key] .. '" (applied)')
		return
	elseif action == "remove" then
		if key ~= "excludedUnitTypes" then
			spEcho("[Squad] 'remove' only applies to excludedUnitTypes")
			return
		end
		if not args[3] then
			spEcho("[Squad] Usage: squad_setting remove excludedUnitTypes <name> [name ...]")
			return
		end
		local toRemove = {}
		for i = 3, #args do
			toRemove[args[i]] = true
		end
		local parts = {}
		for entry in config.excludedUnitTypes:gmatch("[^,]+") do
			local trimmed = entry:match("^%s*(.-)%s*$")
			if not toRemove[trimmed] then
				parts[#parts + 1] = trimmed
			end
		end
		setOptionValue(key, table.concat(parts, ","))
		rebuildTracking()
		spEcho('[Squad] excludedUnitTypes = "' .. config[key] .. '" (applied)')
		return
	elseif action == "toggle" then
		if type(config[key]) ~= "boolean" then
			spEcho("[Squad] Cannot toggle non-boolean key: " .. key)
			return
		end
		setOptionValue(key, not config[key])
		-- Eligibility toggles must re-classify and re-route all tracked units.
		if key == "excludeConstructors" or key == "excludeResurrectionUnits" or key == "excludeCombatEngineers" then
			rebuildTracking()
		end
		spEcho("[Squad] " .. key .. " = " .. tostring(config[key]))
	elseif action == "set" then
		-- excludedUnitTypes collects all remaining args joined with commas.
		if key == "excludedUnitTypes" then
			local parts = {}
			for i = 3, #args do
				parts[#parts + 1] = args[i]
			end
			setOptionValue(key, table.concat(parts, ","))
			rebuildTracking()
			spEcho('[Squad] excludedUnitTypes = "' .. config[key] .. '" (applied)')
			return
		end
		-- Table-typed keys collect all remaining args as a list of numbers and
		-- distance_<N> tokens. Passing no values clears the list.
		if type(config[key]) == "table" then
			local list = {}
			for i = 3, #args do
				local tok = args[i]
				local n = tonumber(tok)
				if n then
					list[#list + 1] = n
				elseif tok:match("^distance_%d+%.?%d*$") then
					list[#list + 1] = tok
				end
			end
			setOptionValue(key, list)
			spEcho("[Squad] " .. key .. " = " .. formatValue(list))
			return
		end
		local value = args[3]
		if not value then
			spEcho("[Squad] Missing value for set")
			return
		end
		-- coerce to number or boolean if appropriate
		if value == "true" then
			value = true
		elseif value == "false" then
			value = false
		elseif tonumber(value) then
			value = tonumber(value)
		end
		setOptionValue(key, value)
		-- Eligibility toggles must re-classify and re-route all tracked units.
		if key == "excludeConstructors" or key == "excludeResurrectionUnits" or key == "excludeCombatEngineers" then
			rebuildTracking()
		end
		spEcho("[Squad] " .. key .. " = " .. tostring(config[key]))
	elseif action == "get" then
		spEcho("[Squad] " .. key .. " = " .. formatValue(config[key]))
	else
		spEcho("[Squad] Unknown action: " .. action .. " (use toggle, set, add, remove, get, or reload)")
	end
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

-- Team color for unselected-squad hulls. Populated in widget:Initialize.
local teamColor = { 1, 1, 1 } ---@type number[]

-- Wipe and rebuild all squad tracking from scratch. Shared by widget:Initialize
-- and the excludedUnitTypes chat commands so a change to the exclusion list
-- takes effect immediately (re-classify + re-route every unit).
function rebuildTracking()
	squads = {}
	factorySquad = {}
	unitSquad = {}
	unitSlot = {}
	squadIdleState = {}
	squadIdleBlend = {}
	squadHideIdleAirHull = {}
	mru = {}
	lastSquadSelect = nil
	idleScanIndex = 0
	nextSquadTag = 0

	classifyUnitdefs()

	uncategorizedReserve = {}
	for _, d in ipairs({ "land", "air", "naval" }) do
		local sq = makeReserveSquad(false)
		sq.uncatDomain = d
		uncategorizedReserve[d] = sq
	end

	local all = spGetTeamUnits(spGetLocalTeamID())
	local count = 0

	-- Factories first, so their auto-squads exist before we route anything.
	for i = 1, #all do
		local u = all[i]
		local defId = getDefid(u)
		if defId and isFactory[defId] then
			createFactorySquad(u)
		end
	end

	-- Combat units: we have no builder info here, so everything goes to the
	-- domain-specific uncategorized reserves. Future builds route via UnitCreated.
	for i = 1, #all do
		local u = all[i]
		local defId = getDefid(u)
		if defId and isCombat[defId] then
			addToSquad(u, getUncategorizedReserveForDef(defId))
			count = count + 1
		end
	end

	selectionDirty = true
	notifySquadChange("rebuild", nil, nil)
	return count
end

function widget:Initialize()
	if spGetSpectatingState() or spIsReplay() then
		log("Spectating or replay mode detected, not initializing")
		widgetHandler:RemoveWidget()
		return
	end

	local tr, tg, tb = spGetTeamColor(spGetLocalTeamID())
	teamColor[1], teamColor[2], teamColor[3] = tr or 1, tg or 1, tb or 1

	local count = rebuildTracking()

	widgetHandler:AddAction("squad_create", squadCreate, nil, "pt")
	widgetHandler:AddAction("squad_select", squadSelect, nil, "pt")
	widgetHandler:AddAction("squad_select_filtered", squadSelectFiltered, nil, "pt")
	widgetHandler:AddAction("squad_select_group", squadSelectGroup, nil, "pt")
	widgetHandler:AddAction("squad_select_portion", squadSelectPortion, nil, "pt")
	widgetHandler:AddAction("squad_select_portion_filtered", squadSelectPortionFiltered, nil, "pt")
	widgetHandler:AddAction("squad_select_portion_group", squadSelectPortionGroup, nil, "pt")
	widgetHandler:AddAction("squad_limit_flip", squadLimitFlip, nil, "pt")
	widgetHandler:AddAction("squad_limit", squadLimit, nil, "pt")
	widgetHandler:AddAction("squad_flip", squadFlip, nil, "pt")
	widgetHandler:AddAction("squad_setting", squadSetting, nil, "t")
	widgetHandler:AddAction("squad_cycle_recent", squadCycleRecent, nil, "pt")
	widgetHandler:AddAction("squad_cycle_idle", squadCycleIdle, nil, "pt")

	-- WG interface. Auto-generates
	-- get<Key>/set<Key> pairs for every exposed config key.
	local exposedSettings = {
		"leftClickSelectsSquad",
		"leftClickSteps",
		"leftClickStepsEnabled",
		"leftClickAppendFiltersDomain",
		"leftClickFilteredRetargets",
		"cyclingToNextSquad",
		"rightClickSquadCreate",
		"rightClickMovesSquad",
		"ctrlRightClickCreatesSquad",
		"ctrlRightClickDragCreatesSquad",
		"viewselectionDoubleTapMs",
		"viewselectionDoubleTapPx",
		"mruSize",
		"excludedUnitTypes",
		"showReserveSquads",
		"mergeIntoReserves",
		"selectionAutoExtend",
		"visualizationMode",
		"convexHullPadding",
		"convexHullArcResolution",
		"convexHullFillOpacity",
		"convexHullBorderOpacity",
		"convexHullBorderThickness",
		"convexHullColorMode",
		"convexHullCustomColorR",
		"convexHullCustomColorG",
		"convexHullCustomColorB",
		"excludeConstructors",
		"excludeResurrectionUnits",
		"excludeCombatEngineers",
	}
	WG["squadselection"] = {}
	for _, key in ipairs(exposedSettings) do
		local cap = key:sub(1, 1):upper() .. key:sub(2)
		WG["squadselection"]["get" .. cap] = function()
			return config[key]
		end

		WG["squadselection"]["set" .. cap] = function(v)
			setOptionValue(key, v)
		end
	end

	-- Re-classify units. Called by gui_options.lua after writing any of the exclude* settings
	WG["squadselection"].rebuildTracking = function()
		rebuildTracking()
	end

	WG["squadselection"].setBeforeSquadSelectCallback = function(fn)
		if fn ~= nil and type(fn) ~= "function" then
			spEcho("[Squad] setBeforeSquadSelectCallback expects function or nil")
			return false
		end
		beforeSquadSelectCallback = fn
		return true
	end

	-- Read-only snapshot of all squad state for companion widgets.
	-- Returns live references — do not mutate the tables.
	-- Each entry of `squads` is a Squad (see the ---@class Squad definition near
	-- the top): number keys are unitIDs, plus .index/.tagSeed/.isReserve/etc.
	WG["squadselection"].getSquadState = function()
		return {
			squads = squads,
			unitSquad = unitSquad,
			factorySquad = factorySquad,
			uncategorizedReserve = uncategorizedReserve,
			squadIdleState = squadIdleState,
			squadIdleBlend = squadIdleBlend,
		}
	end

	WG["squadselection"].addSquadChangeListener = function(fn)
		if type(fn) ~= "function" then
			return false
		end
		squadChangeListeners[#squadChangeListeners + 1] = fn
		pcall(fn, "rebuild", nil, nil)
		return true
	end

	WG["squadselection"].removeSquadChangeListener = function(fn)
		for i = #squadChangeListeners, 1, -1 do
			if squadChangeListeners[i] == fn then
				table.remove(squadChangeListeners, i)
				return true
			end
		end
		return false
	end

	-- Create a new manual squad from an explicit list of unit IDs.
	-- Returns the new squad's .index on success, nil if no eligible units were found.
	-- Does not touch the player's selection or the reserve-merge gate.
	WG["squadselection"].createSquadFromUnits = function(unitIds)
		if not unitIds or #unitIds == 0 then
			return nil
		end

		local newSquad = {} ---@type Squad
		for i = 1, #unitIds do
			local u = unitIds[i]
			local defId = getDefid(u)
			if defId and isCombat[defId] and unitSquad[u] then
				removeFromSquad(u)
				addToSquad(u, newSquad)
			end
		end

		if #newSquad == 0 then
			return nil
		end

		assignSquadTag(newSquad)
		squads[#squads + 1] = newSquad
		pruneEmptySquads()
		notifySquadChange("rebuild", nil, nil)
		selectionDirty = true
		pushToMru(newSquad)

		log("WG createSquadFromUnits: squad [", newSquad.index, "] with ", #newSquad, " units")
		return newSquad.index
	end

	log("Initialized — ", count, " combat units in domain uncategorized reserves")
end

function widget:Update(dt)
	if pendingDragCreate then
		local mx, my, _, _, rmb = spGetMouseState()
		local _, ctrl = spGetModKeyState()
		if not (rmb and ctrl) then
			-- RMB released or Ctrl let go before dragging far enough: no create.
			pendingDragCreate = nil
		else
			local dx = mx - pendingDragCreate.x
			local dy = my - pendingDragCreate.y
			local threshold = spGetConfigInt("MouseDragFrontCommandThreshold", 30) or 30
			if dx * dx + dy * dy >= threshold * threshold then
				squadCreate()
				pendingDragCreate = nil
			end
		end
	end

	if pendingSquadMove then
		local _, _, _, _, rmb = spGetMouseState()
		if not rmb then
			-- RMB released: move-order the picked squad to the release point.
			local sq = pendingSquadMove.squad
			local formation = pendingSquadMove.formation
			local keepSelection = pendingSquadMove.keepSelection
			pendingSquadMove = nil
			if sq and #sq > 0 then
				local wx, wz = getMouseWorldPos()
				if wx then
					local wy = spGetGroundHeight(wx, wz) or 0
					local units = {}
					for i = 1, #sq do
						units[i] = sq[i]
					end
					local _, _, _, shift = spGetModKeyState()
					local opts = (shift and CMD.OPT_SHIFT or 0) + (formation and CMD.OPT_CTRL or 0) ---@type integer
					local saved = spGetSelectedUnits()
					spSelectUnitArray(units)
					spGiveOrder(CMD.MOVE, { wx, wy, wz }, opts)
					if not keepSelection then
						spSelectUnitArray(saved)
					end
					pushToMru(sq)
					log("RMB squad ", formation and "formation move" or "move", " [", sq.index or "?", "]: ", #units, " unit(s)", shift and " (queued)" or "")
				end
			end
		end
	end

	if #squads == 0 then
		idleScanIndex = 0
		return
	end

	if idleScanIndex >= #squads then
		idleScanIndex = 0
	end
	idleScanIndex = idleScanIndex + 1

	local sq = squads[idleScanIndex]
	if sq then
		refreshSquadIdleState(sq)
	end

	-- Highlight (closest-squad preview) and control (commanded squad) targets.
	-- While RMB is held both lock to the commanded squad; otherwise highlight
	-- tracks the closest squad, which Shift latches so a queue stays on one squad.
	local highlightTarget, controlTarget
	if pendingSquadMove then
		highlightTarget = pendingSquadMove.squad
		controlTarget = highlightTarget
	elseif config.rightClickMovesSquad then
		local alt, _, _, shift = spGetModKeyState()
		if alt or spGetSelectedUnits()[1] == nil then
			if not (shift and highlightLockedSquad) then
				local hx, hz = getMouseWorldPos()
				local maxDistSq = config.rightClickMoveRange > 0 and config.rightClickMoveRange * config.rightClickMoveRange or nil
				highlightLockedSquad = hx and findClosestSquad(nil, nil, nil, hx, hz, nil, maxDistSq) or nil
			end
			highlightTarget = highlightLockedSquad
			if shift then
				-- A Shift-latched squad is the live target of the queued moves, so show it as controlled.
				controlTarget = highlightLockedSquad
			else
				highlightLockedSquad = nil
			end
		else
			highlightLockedSquad = nil
		end
	else
		highlightLockedSquad = nil
	end

	-- Animate idle + highlight + control blends for all squads.
	local step = config.idleColorBlendSeconds > 0 and constrain(dt / config.idleColorBlendSeconds, 0, 1) or 1
	local hlStep = config.highlightBlendSeconds > 0 and constrain(dt / config.highlightBlendSeconds, 0, 1) or 1
	for i = 1, #squads do
		local s = squads[i]
		squadIdleBlend[s] = approach(squadIdleBlend[s] or 0, squadIdleState[s] and 1 or 0, step)
		squadHighlightBlend[s] = approach(squadHighlightBlend[s] or 0, s == highlightTarget and 1 or 0, hlStep)
		squadControlBlend[s] = approach(squadControlBlend[s] or 0, s == controlTarget and 1 or 0, hlStep)
	end
end

function widget:Shutdown()
	beforeSquadSelectCallback = nil
	squadChangeListeners = {}
	WG["squadselection"] = nil
	widgetHandler:RemoveAction("squad_create")
	widgetHandler:RemoveAction("squad_select")
	widgetHandler:RemoveAction("squad_select_filtered")
	widgetHandler:RemoveAction("squad_select_group")
	widgetHandler:RemoveAction("squad_select_portion")
	widgetHandler:RemoveAction("squad_select_portion_filtered")
	widgetHandler:RemoveAction("squad_select_portion_group")
	widgetHandler:RemoveAction("squad_limit_flip")
	widgetHandler:RemoveAction("squad_limit")
	widgetHandler:RemoveAction("squad_flip")
	widgetHandler:RemoveAction("squad_setting")
	widgetHandler:RemoveAction("squad_cycle_recent")
	widgetHandler:RemoveAction("squad_cycle_idle")
	cleanupGlHull()
	log("Shutdown")
end

function widget:PlayerChanged(playerID)
	if playerID ~= spGetLocalPlayerID() then
		return
	end
	if spGetSpectatingState() then
		log("Became spectator, shutting down")
		widgetHandler:RemoveWidget()
	end
end

function widget:GameOver()
	widgetHandler:RemoveWidget()
end

function widget:UnitCreated(unitId, unitDefId, unitTeam, builderId)
	if unitTeam ~= spGetLocalTeamID() then
		return
	end
	defidOf[unitId] = unitDefId or false

	if unitDefId and isFactory[unitDefId] then
		createFactorySquad(unitId)
	end

	if unitDefId and isCombat[unitDefId] then
		local sq = (builderId and factorySquad[builderId]) or getUncategorizedReserveForDef(unitDefId)
		local extendSelection = false
		if sq.isReserve and config.selectionAutoExtend then
			local selSet = {}
			for _, u in ipairs(spGetSelectedUnits()) do
				selSet[u] = true
			end
			extendSelection = squadFullySelected(sq, selSet)
		end
		-- Opt-out for the selection auto-extend, split by reserve kind:
		--   Factory reserve → the rally's trailing CMD_WAIT or CMD_PATROL is
		--     the signal — suppress the extend when set.
		--   Uncategorized reserve → no rally to inspect; fall back to the
		--     unit's own queue. Covers resurrection bots, which wake with
		--     CMD_WAIT until fully healed.
		if extendSelection then
			if sq.fromFactory and builderId then
				if factoryRallyEndsWithWaitOrPatrol(builderId) then
					extendSelection = false
				end
			elseif unitQueueHasWait(unitId) then
				extendSelection = false
			end
		end
		addToSquad(unitId, sq)
		if extendSelection then
			spSelectUnitArray({ unitId }, true)
		end
		log("Unit ", unitId, " created → squad [", sq.index or "?", "] (", #sq, " units)")
	end
end

--- Remove a unit's tracking state (combat unit AND/OR factory).
-- Returns true if anything was cleared.
local function stopTracking(unitId)
	local tracked = unitSquad[unitId] ~= nil
	local wasFactory = factorySquad[unitId] ~= nil

	removeFromSquad(unitId)
	defidOf[unitId] = nil
	factorySquad[unitId] = nil

	if tracked or wasFactory then
		pruneEmptySquads()
		return true
	end
	return false
end

function widget:UnitDestroyed(unitId, _unitDefId, _unitTeam, _)
	if stopTracking(unitId) then
		log("Unit ", unitId, " destroyed — ", #squads, " squad(s) remain")
	end
end

function widget:UnitTaken(unitId, _unitDefId, unitTeam, newTeam)
	if unitTeam ~= spGetLocalTeamID() then
		return
	end
	if stopTracking(unitId) then
		log("Unit ", unitId, " taken by team ", newTeam)
	end
end

function widget:UnitGiven(unitId, unitDefId, unitTeam, _oldTeam)
	if unitTeam ~= spGetLocalTeamID() then
		return
	end
	defidOf[unitId] = unitDefId or false

	if unitDefId and isFactory[unitDefId] then
		createFactorySquad(unitId)
	end

	if unitDefId and isCombat[unitDefId] then
		local sq = getUncategorizedReserveForDef(unitDefId)
		addToSquad(unitId, sq)
		log("Unit ", unitId, " given to us → uncategorized-", (sq.uncatDomain or "?"), " reserve (", #sq, " units)")
	end
end

-------------------------------------------------------------------------------
-- Selection-change tracking (for cached allSelected per squad)
-------------------------------------------------------------------------------

function widget:SelectionChanged(sel)
	-- Reset all counts
	for sq, _ in pairs(squadSelCount) do
		squadSelCount[sq] = 0
	end
	-- Tally from the new selection
	for i = 1, #sel do
		local sq = unitSquad[sel[i]]
		if sq then
			squadSelCount[sq] = (squadSelCount[sq] or 0) + 1
		end
	end
	selectionDirty = false
end

-------------------------------------------------------------------------------
-- Input
-------------------------------------------------------------------------------
function widget:MousePress(x, y, button)
	playerInputSinceLastResquad = true
	local alt, ctrl, meta, shift = spGetModKeyState()
	local cursor = spGetMouseCursor()
	if button == 3 then
		local plain = not (alt or ctrl or meta or shift)
		local modCombo = ctrl and not alt and not meta and not shift
		-- The squad-move gesture fires like a normal RMB move: Alt commands a squad
		-- even with units selected; without Alt only when nothing is selected, so we
		-- never hijack an RMB move of your current selection. Shift queues, Ctrl makes
		-- it a slowest-speed "move in formation", and Space (meta) keeps the moved
		-- squad selected — Space sets keepSelection only, never WHEN we fire.
		local willCreate = (config.rightClickSquadCreate and plain) or (config.ctrlRightClickCreatesSquad and modCombo)
		if willCreate and cursor ~= "cursornormal" then
			squadCreate()
		elseif config.ctrlRightClickDragCreatesSquad and modCombo and cursor ~= "cursornormal" then
			-- Defer creation: fire only once the player drags past the engine's
			-- front-command threshold (checked in widget:Update). A plain Ctrl+RMB
			-- with no drag never creates in this mode.
			pendingDragCreate = {
				x = x,
				y = y,
			}
		elseif config.rightClickMovesSquad and (alt or spGetSelectedUnits()[1] == nil) then
			if spTraceScreenRay(x, y) ~= "unit" then
				local sq
				if shift and highlightLockedSquad and #highlightLockedSquad > 0 then
					-- Shift reuses the latched squad so each queued move hits it.
					sq = highlightLockedSquad
				else
					local wx, wz = getMouseWorldPos()
					if wx then
						local maxDistSq = config.rightClickMoveRange > 0 and config.rightClickMoveRange * config.rightClickMoveRange or nil
						sq = findClosestSquad(nil, nil, nil, wx, wz, nil, maxDistSq)
					end
				end
				-- If the picked squad is exactly the current selection, don't
				-- intercept — let the engine drive its normal RMB drag (formation
				-- move) rather than clobbering it with our single-point order.
				-- Exception: Space (meta) is not a formation drag but the engine's
				-- front-of-queue insert; Alt+Space explicitly asks for the widget's
				-- simple move, so we still intercept even when picked == selection.
				local pickedIsSelection = false
				if sq and not meta then
					local selUnits = spGetSelectedUnits()
					if #selUnits == #sq then
						local selSet = {}
						for i = 1, #selUnits do
							selSet[selUnits[i]] = true
						end
						pickedIsSelection = squadFullySelected(sq, selSet)
					end
				end
				if sq and not pickedIsSelection then
					pendingSquadMove = {
						squad = sq,
						formation = ctrl, -- Ctrl → slowest-speed "move in formation" (see widget:Update)
						keepSelection = meta, -- Space → leave the moved squad selected instead of restoring
					}
					if alt then
						return true -- consume so the engine doesn't move the current selection
					end
				end
			end
		end
	elseif button == 1 and config.leftClickSelectsSquad then
		-- A plain ground click normally deselects the selection on mouse-release
		-- (engine behavior), which would wipe the squad we just selected here on
		-- press. So a modifier is required to trigger: Ctrl → replace,
		-- Ctrl+Shift → append, +Alt → filtered. Alt+Shift also triggers (filtered
		-- append) since Ctrl is redundant there.
		--
		-- Exception: when SmartSelect's "deselect only when drag-selecting" option
		-- is on, a plain click keeps the selection, so we drop the modifier
		-- requirement and allow modifier-free squad-select (plain → replace,
		-- Shift → append, Alt → filtered, Alt+Shift → filtered append).
		local smartSelectRetainsClick = WG["smartselect"] and WG["smartselect"].getDeselectOnlyOnDrag and WG["smartselect"].getDeselectOnlyOnDrag()
		if not smartSelectRetainsClick and not (ctrl or (alt and shift)) then
			return false
		end

		-- Skip when an active command is pending (fight, patrol, build, etc.). This may be unnecessary or should be configurable.
		local _, cmdID = spGetActiveCommand()
		if cmdID then
			return false
		end
		-- Skip clicks that land directly on a unit — engine select takes over.
		if spTraceScreenRay(x, y) == "unit" then
			return false
		end
		-- Skip when something is already selected and the cursor isn't the move
		-- cursor (hack: implies we're over a UI element, not open ground).
		if spGetSelectedUnits()[1] ~= nil and cursor ~= "Move" then
			return false
		end

		local stepsConfig = config.leftClickStepsEnabled and config.leftClickSteps or { 1 }
		local _, _, steps, maxDistance = parsePortionArgs(stepsConfig)
		if #steps == 0 then
			steps = { 1 }
		end
		-- Whole-squad mode = the config is just {1} (or was empty and fell back
		-- to {1}). Anything else (including {0.5} or {5}) is portion mode.
		local wholeSquad = #steps == 1 and steps[1] == 1
		local append = shift

		-- Append always cycles across squads (grow-the-selection semantics).
		-- Whole-squad replace cycles per user config.
		local opts = {
			append = append,
			useDomainFilter = append and config.leftClickAppendFiltersDomain,
			steps = steps,
			maxDistance = maxDistance,
			isMousePress = true,
			cycleWhenFull = append or (wholeSquad and config.cyclingToNextSquad),
		}

		if alt then
			local wx, wz = getMouseWorldPos()
			if not wx then
				return false
			end
			local sel = analyzeSelection()
			opts.filterDefs = (config.leftClickFilteredRetargets and not append) and resolveRetargetFilterDefs(sel, wx, wz) or resolveFilterDefs(sel, wx, wz)
			if not opts.filterDefs then
				return false
			end
		end

		doSquadSelect(opts)
	end
	-- Never return true: let the click pass through to the engine.
	return false
end

function widget:KeyPress()
	playerInputSinceLastResquad = true
	return false
end

-------------------------------------------------------------------------------
-- Settings persistence (data/LuaUi/Config/BYAR.lua -> Squad Selection)
-------------------------------------------------------------------------------

function widget:SetConfigData(data)
	for key, value in pairs(data) do
		if config[key] ~= nil then
			config[key] = value
		end
	end
	-- Migrate existing users from the previous default {1} to the new {1, 0.5, "distance_850"}.
	-- Anyone who deliberately customized leftClickSteps already has something other than {1}.
	if type(config.leftClickSteps) == "table" and #config.leftClickSteps == 1 and config.leftClickSteps[1] == 1 then
		config.leftClickSteps = { 1, 0.5, "distance_850" }
	end
end

function widget:GetConfigData()
	return config
end

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Convex hull
-------------------------------------------------------------------------------

-- Persistent scratch buffers. Tables inside (scratchWorld / scratchPadded
-- entries) are reused across frames. scratchHull / scratchUpper hold refs
-- *into* scratchWorld, not independent tables.
local scratchWorld = {} -- {x=world_x, y=world_z} per unit
local scratchHull = {} -- refs into scratchWorld
local scratchUpper = {} -- internal to convexHull
local scratchPadded = {} -- {x, y} per padded-hull vertex
local scratchFlat = {} -- flat {x, y, z, x, y, z, ...} for VBO upload

local function comparePoints(a, b)
	return a.x < b.x or (a.x == b.x and a.y < b.y)
end

local function cross(o, a, b)
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

local function truncate(buf, newLen)
	for i = #buf, newLen + 1, -1 do
		buf[i] = nil
	end
end

-- Writes refs-into-world into out. Sorts `world` in place. Expects #world == n.
local function convexHull(world, n, out, upper)
	table.sort(world, comparePoints)

	local h = 0
	for i = 1, n do
		local p = world[i]
		while h >= 2 and cross(out[h - 1], out[h], p) <= 0 do
			out[h] = nil
			h = h - 1
		end
		h = h + 1
		out[h] = p
	end

	local u = 0
	for i = n, 1, -1 do
		local p = world[i]
		while u >= 2 and cross(upper[u - 1], upper[u], p) <= 0 do
			upper[u] = nil
			u = u - 1
		end
		u = u + 1
		upper[u] = p
	end

	for i = 2, u - 1 do
		h = h + 1
		out[h] = upper[i]
	end

	truncate(upper, 0)
	truncate(out, h)
	return h
end

-- circle for squads with only one unit. Writes into out, reuses its tables.
local function paddedCircle(cx, cy, radius, arcSegmentsAngle, out)
	local segments = math.max(math.ceil(2 * math.pi / arcSegmentsAngle), 3)
	for i = 0, segments - 1 do
		local angle = 2 * math.pi * i / segments
		local p = out[i + 1]
		if not p then
			p = {}
			out[i + 1] = p
		end
		p.x = cx + radius * math.cos(angle)
		p.y = cy + radius * math.sin(angle)
	end
	truncate(out, segments)
	return segments
end

-- rounded padded convex hull for 2+ units. Writes into out, reuses its tables.
local function paddedMoreThanOneUnit(hull, nHull, radius, arcSegmentsAngle, out)
	local n = 0
	for i = 1, nHull do
		local prev = hull[i == 1 and nHull or i - 1]
		local curr = hull[i]
		local nxt = hull[i == nHull and 1 or i + 1]

		local dxPrev = curr.x - prev.x
		local dyPrev = curr.y - prev.y
		local dxNext = nxt.x - curr.x
		local dyNext = nxt.y - curr.y

		-- right normals (outward for CCW): (dy, -dx)
		local anglePrev = math.atan2(-dxPrev, dyPrev)
		local angleNext = math.atan2(-dxNext, dyNext)
		local angleDiff = angleNext - anglePrev
		while angleDiff < 0 do
			angleDiff = angleDiff + 2 * math.pi
		end
		local arcSegments = math.max(math.ceil(angleDiff / arcSegmentsAngle), 1)
		for j = 0, arcSegments do
			local t = j / arcSegments
			local theta = anglePrev + t * angleDiff
			n = n + 1
			local p = out[n]
			if not p then
				p = {}
				out[n] = p
			end
			p.x = curr.x + radius * math.cos(theta)
			p.y = curr.y + radius * math.sin(theta)
		end
	end
	truncate(out, n)
	return n
end

-- Fill scratchPadded from scratchWorld[1..nWorld]. Returns padded count.
local function getPaddedHull(nWorld, radius, arcSegmentsAngle)
	if nWorld == 1 then
		local p = scratchWorld[1]
		return paddedCircle(p.x, p.y, radius, arcSegmentsAngle, scratchPadded)
	elseif nWorld >= 2 then
		local nHull = convexHull(scratchWorld, nWorld, scratchHull, scratchUpper)
		return paddedMoreThanOneUnit(scratchHull, nHull, radius, arcSegmentsAngle, scratchPadded)
	else
		truncate(scratchPadded, 0)
		return 0
	end
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or config.visualizationMode ~= "convexHull" then
		return
	end
	if not squads or #squads == 0 then
		return
	end
	if not hullReady and not initGlHull() then
		return
	end
	-- After a successful init these are all set; assert so the analyzer narrows them.
	if not (hullShader and hullVbo and hullVao and hullColorLoc and hullStripeLoc and hullCentroidLoc and hullPulseLoc) then
		return
	end

	-- Lazy recount if SelectionChanged hasn't fired yet (e.g. first frame)
	if selectionDirty then
		local sel = spGetSelectedUnits()
		for sq, _ in pairs(squadSelCount) do
			squadSelCount[sq] = 0
		end
		for i = 1, #sel do
			local sq = unitSquad[sel[i]]
			if sq then
				squadSelCount[sq] = (squadSelCount[sq] or 0) + 1
			end
		end
		selectionDirty = false
	end

	-- re-read styling each frame so squad_setting changes take effect live
	local fillOpacity = config.convexHullFillOpacity
	local borderOpacity = config.convexHullBorderOpacity
	local borderThickness = config.convexHullBorderThickness
	local padding = config.convexHullPadding
	local arcRes = config.convexHullArcResolution
	local showReserves = config.showReserveSquads
	local colorMode = config.convexHullColorMode

	if not hullTimeOrigin then
		hullTimeOrigin = spGetTimer()
	end
	local now = spDiffTimers(spGetTimer(), hullTimeOrigin)

	glDepthTest(false)
	glUseShader(hullShader)
	glLineWidth(borderThickness)

	for _, squad in ipairs(squads) do
		if not squad.isReserve or showReserves then
			local size = #squad
			if size > 0 then
				local idleBlend = squadIdleBlend[squad] or 0
				local alphaScale = 1 ---@type number
				if squadHideIdleAirHull[squad] then
					alphaScale = 1 - idleBlend
				end

				if alphaScale <= 0.001 then
					-- Fully hidden for idle flying-air squads.
				else
					local cr, cg, cb
					local fullySelected = (squadSelCount[squad] or 0) >= size
					if fullySelected then
						cr, cg, cb = 1, 1, 1
					elseif colorMode == "custom" then
						cr, cg, cb = config.convexHullCustomColorR, config.convexHullCustomColorG, config.convexHullCustomColorB
					elseif colorMode == "squad" and squad.color then
						cr, cg, cb = squad.color[1], squad.color[2], squad.color[3]
					else
						cr = teamColor[1]
						cg = teamColor[2]
						cb = teamColor[3]
					end
					local hb = squadHighlightBlend[squad] or 0
					local ctb = squadControlBlend[squad] or 0
					local effIdle = idleBlend * (1 - hb)
					if effIdle > 0 and not fullySelected then
						local ir = cr * 0.3
						local ig = cg * 0.3
						local ib = cb * 0.3
						cr = cr + (ir - cr) * effIdle
						cg = cg + (ig - cg) * effIdle
						cb = cb + (ib - cb) * effIdle
					end
					if squad.isReserve then
						alphaScale = alphaScale * 0.6
						cr, cg, cb = cr * 1.5, cg * 1.5, cb * 1.5
					end

					-- Highlight tiers faded in by their blends. The commanded squad
					-- always has hb fading in alongside ctb (see Update), so control
					-- stacks on top of hover (extra brightness + border width).
					local effFill, effBorder = fillOpacity, borderOpacity
					local effPadding = padding
					if hb > 0 or ctb > 0 then
						effFill = math.min(1, fillOpacity + 0.2 * hb + 0.2 * ctb)
						effBorder = math.min(1, borderOpacity + 0.2 * hb + 0.2 * ctb)
						effPadding = padding + 5 * hb + 5 * ctb
						local bright = 0.4 * ctb
						cr = cr + (1 - cr) * bright
						cg = cg + (1 - cg) * bright
						cb = cb + (1 - cb) * bright
					end

					-- fill scratchWorld in place (reuse {x,y} tables) and track
					-- the bbox in the same pass, so we can frustum-cull without a
					-- second iteration.
					local nWorld = 0
					local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
					for i = 1, size do
						local x, _, z = spGetUnitPosition(squad[i])
						if x and z then
							nWorld = nWorld + 1
							local p = scratchWorld[nWorld]
							if not p then
								p = {}
								scratchWorld[nWorld] = p
							end
							p.x = x
							p.y = z
							if x < minX then
								minX = x
							end
							if x > maxX then
								maxX = x
							end
							if z < minZ then
								minZ = z
							end
							if z > maxZ then
								maxZ = z
							end
						end
					end
					truncate(scratchWorld, nWorld)

					if nWorld > 0 then
						-- Frustum cull: enclose the squad + padding in one sphere
						-- around the bbox centre. Vertical slop (256) covers
						-- terrain variation under the ground-projected hull.
						local cx = (minX + maxX) * 0.5
						local cz = (minZ + maxZ) * 0.5
						local hx = (maxX - minX) * 0.5
						local hz = (maxZ - minZ) * 0.5
						local cy = spGetGroundHeight(cx, cz)
						local radius = math.sqrt(hx * hx + hz * hz) + effPadding + 256
						local visible = (not spIsSphereInView) or spIsSphereInView(cx, cy, cz, radius)

						if visible then
							local n = getPaddedHull(nWorld, effPadding, arcRes)
							if n >= 3 and n <= HULL_MAX_VERTICES then
								local seed = squad.tagSeed or 0

								-- Centroid (average of padded vertices) and max radius
								-- are uploaded as a uniform to drive the fragment-shader
								-- center→edge alpha gradient. The hull stays convex so
								-- TRIANGLE_FAN can still pivot on vertex 0.
								local pcx, pcy = 0, 0 ---@type number, number
								local fi = 0
								for i = 1, n do
									local p = scratchPadded[i]
									pcx = pcx + p.x
									pcy = pcy + p.y
									scratchFlat[fi + 1] = p.x
									scratchFlat[fi + 2] = spGetGroundHeight(p.x, p.y)
									scratchFlat[fi + 3] = p.y
									fi = fi + 3
								end
								pcx = pcx / n
								pcy = pcy / n

								local maxR2 = 0 ---@type number
								for i = 1, n do
									local p = scratchPadded[i]
									local rdx = p.x - pcx
									local rdy = p.y - pcy
									local r2 = rdx * rdx + rdy * rdy
									if r2 > maxR2 then
										maxR2 = r2
									end
								end
								local hullRadiusNorm = math.sqrt(maxR2)

								hullVbo:Upload(scratchFlat, nil, nil, 1, fi)

								local pulseVal = 1 + config.hullPulseAmplitude * math.sin(now * config.hullPulseRate + seed * 6.2831853)
								glUniform(hullCentroidLoc, pcx, pcy, hullRadiusNorm)
								glUniform(hullPulseLoc, pulseVal)

								if squad.isReserve then
									glUniform(hullStripeLoc, config.reserveStripePeriod, config.reserveStripeAlphaMul, seed * config.reserveStripePeriod)
								else
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effFill * alphaScale)
								hullVao:DrawArrays(GL.TRIANGLE_FAN, n)
								if squad.isReserve then
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effBorder * alphaScale)
								if ctb > 0 then
									glLineWidth(borderThickness + 2 * ctb)
									hullVao:DrawArrays(GL.LINE_LOOP, n)
									glLineWidth(borderThickness)
								else
									hullVao:DrawArrays(GL.LINE_LOOP, n)
								end
							end
						end
					end
				end
			end
		end
	end

	glUseShader(0)
	glLineWidth(1)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam)
	if not config.commandCreatesSquad then
		return
	end

	local teamId = spGetLocalTeamID()
	if playerInputSinceLastResquad and unitTeam == teamId and isCombat[unitDefID] then
		createSquadFromSelection(unitID)
	end
end
