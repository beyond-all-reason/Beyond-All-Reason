if not RmlUi then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Air Flight Tuning",
		desc = "Live sliders for the fixed-wing flight members, agile flight model and stock. Open with /airtuning [open|close]",
		author = "PtaQ",
		date = "2026.09.20",
		license = "GNU GPL, v2 or later",
		layer = 1000011,
		enabled = true,
	}
end

-- One window, opened with /airtuning [open|close]. Closed by default.
--
-- Values are read from Spring.GetUnitMoveTypeData of a reference aircraft (the first selected strafing aircraft,
-- kept while it lives once the selection moves on). Edits go to the synced debug gadget
-- luarules/gadgets/dbg_air_agile_flight.lua as Lua messages ("airtune:<command>", the same commands it takes as
-- /luarules chat actions, without the echo per slider step). The gadget owns all the setting and the restoring,
-- and publishes what it overrides as game rules params (airtune_over_all, airtune_over_defs), which is what lights
-- a row's reset button and what the export section writes out.
--
-- The window is the Novel PBR Tuning document loaded a second time: same frame, same style sheet, its content
-- replaced from here. Only #nt-root and the nt-* classes of gui_novelpbr_tuning.rcss are relied on.

local RML_PATH = "luaui/RmlWidgets/gui_air_flight_tuning/gui_air_flight_tuning.rml"
local LOG_PREFIX = "[air tuning] "
local MSG_PREFIX = "airtune:"
local ICON_RESET = "/luaui/images/terraform_brush/undo.png"
local ICON_PLUS = "/luaui/images/terraform_brush/plus.png"
local ICON_MINUS = "/luaui/images/terraform_brush/minus.png"
local ICON_CLOSE = "/luaui/images/terraform_brush/close.png"

local SCOPE_ALL = "*"
-- seconds between two sends of the same key while a slider is dragged
local SEND_INTERVAL = 0.1
-- seconds between two reads of the reference aircraft
local REFRESH_INTERVAL = 0.25
-- seconds a row is left alone after an edit, the command takes a few frames to come back as a read value
local EDIT_HOLD = 1.0
local RESET_HOLD = 0.4
-- opacity of a reset button whose row is not overridden, and of the same under the mouse
local RESET_DIM = "0.4"
local RESET_DIM_HOVER = "0.85"
local DEFAULT_DESC = "Point at a row to see what it does."
-- relative to the engine's write directory, a folder of its own like the Terraform Brush tools have
local EXPORT_DIR = "Air Flight Tuning/"
local EXPORT_BASENAME = "air_flight_tuning_"

-- Row fields: key (the movetype member), label (the label column is about 12 characters wide), kind ("slider" by
-- default, "bool", "switch", "group"), desc (one sentence, under 100 characters, no markup characters),
-- min/max/step/digits for sliders, integer, hardMin (typed values are clamped to it),
-- maxFrom (another read key that gives the slider its max), autoRange (max is 4 x the first value read),
-- optional (may be missing from the running engine: greyed out if GetUnitMoveTypeData does not report it),
-- unreadable + fallback(unitDef) (settable but not reported: shows what was last sent, else the fallback),
-- command + param + default for a switch (a gadget-wide toggle: the /luarules command, the game rules param that
-- reports its state, and the state the gadget starts in, which is what its reset goes back to).
-- A section may carry extra (markup put after its rows).
local SECTIONS = {
	{
		id = "model",
		title = "FLIGHT MODEL",
		hint = "These three switches always apply to all aircraft",
		rows = {
			{
				key = "agileFlight",
				label = "Agile flight",
				kind = "switch",
				command = "agile",
				param = "airtune_agile",
				default = true,
				desc = "Master switch: maneuver slowly near goals, cruise fast between them. Off is stock flight.",
			},
			{
				key = "terrainLookahead",
				label = "Lookahead",
				kind = "switch",
				command = "lookahead",
				param = "airtune_lookahead",
				default = true,
				desc = "Altitude hold looks at the terrain along the flight path, climbs early for cliffs. Off is stock.",
			},
			{
				key = "armedWhileManeuvering",
				label = "Weapons live",
				kind = "switch",
				command = "agilearmed",
				param = "airtune_armed",
				default = false,
				desc = "Off: weapons are held while maneuvering and live only in cruise. On: always live.",
			},
			{
				-- (not the gadget's: a switch of the Air Flight Mode Labels widget, through WG)
				key = "flightModeLabels",
				label = "Mode labels",
				kind = "switch",
				wg = "airFlightModeLabels",
				default = true,
				desc = "Debug: CRUISE / MANEUVER written over every fixed-wing aircraft, from the engine's flight regime.",
			},
			{
				key = "agileLandOnly",
				label = "Land only",
				kind = "bool",
				optional = true,
				desc = "Use the new model only for aircraft set to Land; aircraft set to Fly keep stock flight.",
			},
		},
	},
	{
		id = "agile",
		title = "MANEUVERING",
		hint = "0 asks the engine for its default",
		rows = {
			{
				key = "agileSpeed",
				label = "Speed",
				min = 0,
				max = 400,
				step = 1,
				digits = 0,
				desc = "Top speed while maneuvering, and the speed at which it hands over to cruise (elmos per second).",
			},
			{
				key = "agileTurnRate",
				label = "Turn rate",
				min = 0,
				max = 2000,
				step = 5,
				digits = 0,
				desc = "Heading change per frame at top maneuver speed; 65536 is a full circle, 0 gives 270.",
			},
			{
				key = "agileAccRate",
				label = "Acceleration",
				min = 0,
				max = 1,
				step = 0.005,
				digits = 3,
				desc = "Acceleration and braking limit while maneuvering (elmos per frame squared); 0 uses maxAcc.",
			},
			{
				key = "agileAltitude",
				label = "Altitude",
				min = 0,
				max = 400,
				step = 1,
				digits = 0,
				maxFrom = "wantedHeight",
				desc = "Height flown while maneuvering, never above cruise altitude; 0 uses the cruise altitude.",
			},
			{
				key = "cruiseDistance",
				label = "Cruise dist",
				min = 0,
				max = 3000,
				step = 10,
				digits = 0,
				desc = "Goals nearer than this are flown without cruising; 0 derives one turn diameter.",
			},
			{
				key = "cruiseEntryAngle",
				label = "Entry angle",
				min = 5,
				max = 120,
				step = 1,
				digits = 0,
				optional = true,
				desc = "Degrees the nose may be off the goal when it goes over to cruise; higher leaves maneuvering sooner.",
			},
			{
				key = "cruiseEntrySpeed",
				label = "Entry speed",
				min = 0.2,
				max = 1,
				step = 0.05,
				digits = 2,
				optional = true,
				desc = "How fast it must be to go over to cruise, as a share of the maneuver speed.",
			},
			{
				key = "cruiseEntryTurnBoost",
				label = "Entry boost",
				min = 1,
				max = 8,
				step = 0.25,
				digits = 2,
				optional = true,
				desc = "How much faster the nose comes round while it is heading for a cruise leg.",
			},
		},
	},
	{
		id = "hover",
		title = "HOVER",
		hint = "An aircraft holding on a point in the air",
		rows = {
			{
				key = "agileHoverBob",
				label = "Bob",
				min = 0,
				max = 20,
				step = 0.1,
				digits = 1,
				desc = "Elmos an aircraft holding in the air bobs up and down; 0 for none.",
			},
			{
				key = "agileHoverSway",
				label = "Sway",
				min = 0,
				max = 20,
				step = 0.1,
				digits = 1,
				desc = "Elmos a holding aircraft sways to its own left and right; 0 for none.",
			},
			{
				key = "agileHoverTilt",
				label = "Tilt",
				min = 0,
				max = 6,
				step = 0.05,
				digits = 2,
				desc = "How hard it leans with the sway; 1 is the angle the acceleration dictates, 0 stays level.",
			},
		},
	},
	{
		id = "stock",
		title = "STOCK FLIGHT",
		hint = "Stock fixed-wing members; 0 is a real value here",
		collapsed = true,
		rows = {
			{
				key = "maxSpeed",
				label = "Max speed",
				min = 30,
				max = 600,
				step = 1,
				digits = 0,
				hardMin = 1,
				desc = "Top speed in cruise flight (elmos per second).",
			},
			{
				key = "wantedHeight",
				label = "Cruise alt",
				min = 20,
				max = 600,
				step = 1,
				digits = 0,
				hardMin = 1,
				desc = "Cruise altitude above the ground (elmos); new aircraft get 1.5 x the unitdef value.",
			},
			{
				key = "turnRadius",
				label = "Turn radius",
				min = 0,
				max = 500,
				step = 1,
				digits = 0,
				desc = "How near a goal may be before the stock model stops steering straight at it (elmos).",
			},
			{
				key = "maxAcc",
				label = "Max acc",
				min = 0.005,
				max = 1,
				step = 0.0025,
				digits = 4,
				hardMin = 0.001,
				desc = "Forward acceleration in cruise flight (elmos per frame squared).",
			},
			{
				key = "maxDec",
				label = "Max dec",
				min = 0.005,
				max = 0.5,
				step = 0.0025,
				digits = 4,
				hardMin = 0.001,
				unreadable = true,
				fallback = function(ud)
					return math.max(0.01, ud.maxDec or 0.01)
				end,
				desc = "Braking rate for landing and stopping. Not reported by the engine: shows the last value sent.",
			},
			{
				key = "myGravity",
				label = "Gravity",
				min = 0,
				max = 2,
				step = 0.01,
				digits = 3,
				autoRange = true,
				desc = "Multiplier on map gravity that pulls the aircraft down when it is too slow to fly.",
			},
			{
				key = "attackSafetyDistance",
				label = "Safety dist",
				min = 0,
				max = 1000,
				step = 10,
				digits = 0,
				unreadable = true,
				fallback = function(ud)
					-- the engine starts it at 0, the game's unit_air_attacksafetydistance gadget sets it from this
					return tonumber(ud.customParams and ud.customParams.attacksafetydistance) or 0
				end,
				desc = "A diving attacker nearer to its target than this pulls up to cruise altitude. Not reported.",
			},
			{
				key = "collide",
				label = "Collide",
				kind = "bool",
				desc = "Aircraft bump into other aircraft and into buildings.",
			},
			{
				key = "useSmoothMesh",
				label = "Smooth mesh",
				kind = "bool",
				desc = "Hold altitude over the smoothed terrain instead of the real ground.",
			},
			{
				key = "loopbackAttack",
				label = "Loopback",
				kind = "bool",
				unreadable = true,
				fallback = function(ud)
					return (ud.canLoopbackAttack and ud.isFighterAirUnit) and true or false
				end,
				desc = "Fighters loop (Immelmann) back onto a target they overflew. Not reported by the engine.",
			},
		},
	},
	{
		id = "surfaces",
		title = "STOCK CONTROLS",
		hint = "Attitude limits and control surface rates",
		collapsed = true,
		rows = {
			{
				key = "maxBank",
				label = "Max bank",
				min = 0,
				max = 1,
				step = 0.01,
				digits = 2,
				desc = "Roll limit in a turn, as the sine of the bank angle (1 is wings vertical).",
			},
			{
				key = "maxPitch",
				label = "Max pitch",
				min = 0,
				max = 1,
				step = 0.01,
				digits = 2,
				desc = "Climb and dive limit, as the sine of the pitch angle (1 is straight up).",
			},
			{
				key = "maxAileron",
				label = "Aileron",
				min = 0,
				max = 0.06,
				step = 0.0002,
				digits = 4,
				desc = "Roll rate: how fast it banks into and out of a turn.",
			},
			{
				key = "maxElevator",
				label = "Elevator",
				min = 0,
				max = 0.05,
				step = 0.0002,
				digits = 4,
				desc = "Pitch rate: how fast the nose comes up or down.",
			},
			{
				key = "maxRudder",
				label = "Rudder",
				min = 0.0005,
				max = 0.03,
				step = 0.0001,
				digits = 4,
				hardMin = 0.0001,
				desc = "Yaw rate; the turn radius is 1 / maxRudder elmos at any speed.",
			},
		},
	},
	{
		id = "export",
		title = "EXPORT",
		hint = "Lua tables for baking, written to " .. EXPORT_DIR,
		rows = {},
		extra = '<div class="nt-row"><div class="nt-chips">'
			.. '<div id="at-save-all" class="nt-chip"><div>Save all</div></div>'
			.. '<div id="at-save-type" class="nt-chip"><div>Save type</div></div>'
			.. '<div id="at-export-print" class="nt-chip"><div>Print</div></div>'
			.. "</div></div>"
			.. '<div id="at-export-status" class="nt-note nt-hidden"></div>',
	},
}

-- Movetype member -> unitdef tag (lowercase, as the unit files and a tweakunits table spell them). Checked against
-- rts/Sim/Units/UnitDef.cpp (udTable.Get...) and the CStrafeAirMoveType / AMoveType constructors:
--   speed and agileSpeed are elmos per second in the def, the members are per frame and both are reported and
--     set in elmos per second, so they go out as they are
--   wantedHeight = 1.5 x cruiseAltitude + a random offset per aircraft: the slider value goes out divided by 1.5
--   loopbackAttack = canLoopbackAttack and the unit is a fighter
--   attackSafetyDistance has no tag, the game's unit_air_attacksafetydistance gadget sets it from a custom param
--   everything else is copied (maxAcc, maxAileron, maxElevator, maxRudder with a random +-1% per aircraft)
local EXPORT_TAGS = {
	agileFlight = "agileflight",
	agileLandOnly = "agilelandonly",
	agileSpeed = "agilespeed",
	agileTurnRate = "agileturnrate",
	agileAccRate = "agileaccrate",
	agileAltitude = "agilealtitude",
	cruiseDistance = "cruisedistance",
	agileHoverBob = "agilehoverbob",
	agileHoverSway = "agilehoversway",
	agileHoverTilt = "agilehovertilt",
	terrainLookahead = "terrainlookahead",
	cruiseEntryAngle = "cruiseentryangle",
	cruiseEntrySpeed = "cruiseentryspeed",
	cruiseEntryTurnBoost = "cruiseentryturnboost",
	maxSpeed = "speed",
	wantedHeight = "cruisealtitude",
	turnRadius = "turnradius",
	maxAcc = "maxacc",
	maxDec = "maxdec",
	myGravity = "mygravity",
	maxBank = "maxbank",
	maxPitch = "maxpitch",
	maxAileron = "maxaileron",
	maxElevator = "maxelevator",
	maxRudder = "maxrudder",
	collide = "collide",
	useSmoothMesh = "usesmoothmesh",
	loopbackAttack = "canloopbackattack",
}
-- member value x this = tag value
local EXPORT_SCALE = {
	wantedHeight = 1 / 1.5,
}
-- members that are baked as a custom param
local EXPORT_CUSTOMPARAMS = {
	attackSafetyDistance = "attacksafetydistance",
}
-- what is read off a living aircraft for the "effective" table of an export
local EFFECTIVE_KEYS = {
	"agileFlight",
	"agileLandOnly",
	"agileSpeed",
	"agileTurnRate",
	"agileAccRate",
	"agileAltitude",
	"cruiseDistance",
	"agileHoverBob",
	"agileHoverSway",
	"agileHoverTilt",
	"cruiseEntryAngle",
	"cruiseEntrySpeed",
	"cruiseEntryTurnBoost",
}

local S = {
	open = false,
	clock = 0,
	lastRefresh = -10,
	scope = SCOPE_ALL,
	values = {}, -- key -> number | boolean | nil, what the rows show
	sent = {}, -- scope id -> key -> value, what this session has overridden
	over = nil, -- scope id -> key -> value, what the gadget reports as overridden; nil if it does not report
	pending = {}, -- key -> command waiting for its send slot
	lastSent = {}, -- key -> S.clock of the last send
	rows = {},
	els = {},
	applying = false,
	haveData = false,
	collapsedSaved = {},
}

local STRAFE = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isStrafingAirUnit then
		STRAFE[unitDefID] = true
	end
end

local function log(msg)
	Spring.Echo(LOG_PREFIX .. msg)
end

local function El(id)
	local el = S.els[id]
	if el == nil and S.document then
		el = S.document:GetElementById(id)
		S.els[id] = el
	end
	return el
end

local function Format(row, v)
	if type(v) ~= "number" then
		return ""
	end
	-- never longer than six characters, the value column of a 13vw window has no room for more
	local text = string.format("%." .. (row.digits or 2) .. "f", v)
	if #text > 6 then
		text = string.format("%.4g", v)
	end
	return text
end

local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < 1e-7
	end
	return a == b
end

-- "*" for all aircraft, the unitdef name for one type, nil when a type is wanted and no aircraft is known
local function ScopeId()
	if S.scope == SCOPE_ALL then
		return SCOPE_ALL
	end
	return S.refDefName
end

-- what is overridden for a key (as the gadget reports it, else as this session sent it), the type's own override
-- before the one for all
local function SentValue(key)
	local source = S.over or S.sent
	local own = S.refDefName and source[S.refDefName]
	if own and own[key] ~= nil then
		return own[key]
	end
	local all = source[SCOPE_ALL]
	if all and all[key] ~= nil then
		return all[key]
	end
	return nil
end

-- an edit of this row in this scope is so fresh that the gadget can not have reported it yet
local function Holding(row, scopeId)
	return row.editedScope == scopeId and (S.clock - (row.editedAt or -10)) <= EDIT_HOLD
end

local function IsOverridden(row, scopeId)
	if scopeId == nil then
		return false
	end
	local source = S.over
	if source == nil or Holding(row, scopeId) then
		source = S.sent
	end
	local scoped = source[scopeId]
	return (scoped ~= nil and scoped[row.key] ~= nil)
end

local function Escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function SetDesc(text)
	local el = El("at-desc")
	if el then
		el.inner_rml = "<div>" .. (text or DEFAULT_DESC) .. "</div>"
	end
end

--------------------------------------------------------------------------------------------------
-- Commands (widget -> gadget)
--------------------------------------------------------------------------------------------------

local function Send(command)
	Spring.SendLuaRulesMsg(MSG_PREFIX .. command)
end

local function QueueSet(row, v, scopeId)
	local text
	if type(v) == "boolean" then
		text = tostring(v)
	else
		text = string.format("%.6g", v)
	end
	if scopeId == SCOPE_ALL then
		S.pending[row.key] = "agileset " .. row.key .. " " .. text
	else
		S.pending[row.key] = "agilesetdef " .. scopeId .. " " .. row.key .. " " .. text
	end
end

-- force: send everything now (mouse released, a typed value, closing)
local function FlushPending(force)
	for key, command in pairs(S.pending) do
		if force or (S.clock - (S.lastSent[key] or -10)) >= SEND_INTERVAL then
			Send(command)
			S.lastSent[key] = S.clock
			S.pending[key] = nil
		end
	end
end

--------------------------------------------------------------------------------------------------
-- View
--------------------------------------------------------------------------------------------------

local function RefreshRow(row, skipSlider)
	if row.kind == "group" then
		return
	end
	local value = S.values[row.key]
	local marked
	if row.kind == "switch" then
		marked = (row.default ~= nil and value ~= nil and value ~= row.default)
	else
		marked = IsOverridden(row, ScopeId())
	end
	local unavailable = (row.optional and S.haveData and value == nil) and true or false

	local sig = tostring(value) .. "|" .. tostring(marked) .. "|" .. tostring(unavailable)
	if sig == row.sig then
		return
	end
	row.sig = sig

	S.applying = true
	if row.kind == "bool" or row.kind == "switch" then
		local on = El("at-c-" .. row.id .. "-on")
		if on then
			on:SetClass("nt-chip-on", value == true)
		end
		local off = El("at-c-" .. row.id .. "-off")
		if off then
			off:SetClass("nt-chip-on", value == false)
		end
	else
		local slider = El("at-s-" .. row.id)
		if slider and not skipSlider and type(value) == "number" then
			slider:SetAttribute("value", tostring(value))
		end
		local numbox = El("at-n-" .. row.id)
		if numbox and numbox ~= S.focused then
			numbox:SetAttribute("value", Format(row, value))
		end
	end
	S.applying = false

	local label = El("at-l-" .. row.id)
	if label then
		label:SetClass("nt-changed", marked)
	end
	-- always there and always clickable; lit while the row is overridden in this scope
	row.marked = marked
	local reset = El("at-r-" .. row.id)
	if reset then
		reset:SetClass("nt-reset-on", marked)
		reset.style.opacity = marked and "1" or RESET_DIM
	end

	if row.optional and unavailable ~= row.unavailable then
		row.unavailable = unavailable
		local wrap = El("at-w-" .. row.id)
		if wrap then
			wrap.style.opacity = unavailable and "0.4" or "1"
		end
		local note = El("at-x-" .. row.id)
		if note then
			note:SetClass("nt-hidden", not unavailable)
		end
	end
end

local function RefreshAll()
	for _, row in ipairs(S.rows) do
		RefreshRow(row)
	end
end

local function InvalidateAll()
	for _, row in ipairs(S.rows) do
		row.sig = nil
	end
end

local function RefreshScopeChips()
	local all = El("at-scope-all")
	if all then
		all:SetClass("nt-chip-on", S.scope == SCOPE_ALL)
	end
	local def = El("at-scope-def")
	if def then
		def:SetClass("nt-chip-on", S.scope ~= SCOPE_ALL)
	end
	local text = El("at-scope-def-text")
	if text then
		text.inner_rml = S.refDefName and ("Type: " .. S.refDefName) or "Selected type"
	end
end

local function RefreshReferenceLine()
	local el = El("at-ref")
	if not el then
		return
	end
	local text
	if Spring.GetGameRulesParam("airtune_agile") == nil then
		text = "The debug gadget (dbg_air_agile_flight) is not running: nothing will apply."
	elseif S.refUnitID and S.refDefName then
		text = "Reading " .. S.refDefName .. " (unit " .. S.refUnitID .. ")"
	else
		text = "Select a fixed-wing aircraft to read its values."
	end
	if text ~= S.refLine then
		S.refLine = text
		el.inner_rml = "<div>" .. text .. "</div>"
	end
end

--------------------------------------------------------------------------------------------------
-- Reference aircraft and its values
--------------------------------------------------------------------------------------------------

local function UpdateReference()
	local found = nil
	local selected = Spring.GetSelectedUnits() or {}
	for i = 1, #selected do
		local unitDefID = Spring.GetUnitDefID(selected[i])
		if unitDefID and STRAFE[unitDefID] then
			found = selected[i]
			break
		end
	end
	if found == nil and S.refUnitID and Spring.ValidUnitID(S.refUnitID) and not Spring.GetUnitIsDead(S.refUnitID) then
		found = S.refUnitID
	end
	if found == S.refUnitID then
		return
	end

	S.refUnitID = found
	S.refDefID = found and Spring.GetUnitDefID(found) or nil
	local unitDef = S.refDefID and UnitDefs[S.refDefID]
	S.refDefName = unitDef and unitDef.name or nil
	if S.refDefName == nil then
		S.refUnitID = nil
		S.refDefID = nil
	end
	InvalidateAll()
	RefreshScopeChips()
end

local function SetSliderRange(row, max, step)
	row.max = max
	local slider = El("at-s-" .. row.id)
	if not slider then
		return
	end
	S.applying = true
	slider:SetAttribute("max", tostring(max))
	if step then
		row.step = step
		slider:SetAttribute("step", tostring(step))
	end
	S.applying = false
	row.sig = nil
end

-- "key=value<separator>key=value" into a table; numbers, true and false
local function ParsePairs(text, separator, into)
	for item in text:gmatch("[^" .. separator .. "]+") do
		local key, word = item:match("^([^=]+)=(.*)$")
		if key then
			local value
			if word == "true" then
				value = true
			elseif word == "false" then
				value = false
			else
				value = tonumber(word)
			end
			if value ~= nil then
				into[key] = value
			end
		end
	end
end

-- what the gadget reports as overridden: airtune_over_all = "key=value;key=value",
-- airtune_over_defs = "defName:key=value,key=value|defName:..." ("-" for none)
local function ReadOverrides()
	local all = Spring.GetGameRulesParam("airtune_over_all")
	local defs = Spring.GetGameRulesParam("airtune_over_defs")
	if type(all) ~= "string" and type(defs) ~= "string" then
		-- an older gadget, or none: fall back on what this session sent
		S.over = nil
		S.overRaw = nil
		return
	end
	local raw = tostring(all) .. "\n" .. tostring(defs)
	if raw == S.overRaw then
		return
	end
	S.overRaw = raw

	local over = {}
	if type(all) == "string" then
		local scoped = {}
		ParsePairs(all, ";", scoped)
		if next(scoped) ~= nil then
			over[SCOPE_ALL] = scoped
		end
	end
	if type(defs) == "string" then
		for item in defs:gmatch("[^|]+") do
			local defName, list = item:match("^([^:]+):(.*)$")
			if defName then
				local scoped = {}
				ParsePairs(list, ",", scoped)
				if next(scoped) ~= nil then
					over[defName] = scoped
				end
			end
		end
	end
	S.over = over
end

local function ReadValues()
	local mt = nil
	if S.refUnitID then
		mt = Spring.GetUnitMoveTypeData(S.refUnitID)
		if type(mt) ~= "table" or mt.name ~= "airplane" then
			mt = nil
		end
	end
	S.haveData = (mt ~= nil)
	local unitDef = S.refDefID and UnitDefs[S.refDefID]

	for _, row in ipairs(S.rows) do
		if row.kind ~= "group" and (S.clock - (row.editedAt or -10)) > EDIT_HOLD and S.pending[row.key] == nil then
			local value = nil
			if row.kind == "switch" and row.wg then
				value = (WG[row.wg] ~= false)
			elseif row.kind == "switch" then
				local param = Spring.GetGameRulesParam(row.param)
				if param ~= nil then
					value = (param == 1)
				end
			elseif mt ~= nil then
				if row.unreadable then
					value = SentValue(row.key)
					if value == nil and unitDef and row.fallback then
						value = row.fallback(unitDef)
					end
				else
					value = mt[row.key]
				end
			end

			if row.kind == "bool" or row.kind == "switch" then
				if type(value) ~= "boolean" then
					value = nil
				end
			elseif type(value) ~= "number" then
				value = nil
			end
			S.values[row.key] = value

			if value ~= nil and mt ~= nil then
				if row.maxFrom then
					local limit = mt[row.maxFrom]
					if type(limit) == "number" and limit > 1 and math.abs(math.ceil(limit) - row.max) >= 1 then
						SetSliderRange(row, math.ceil(limit), nil)
					end
				elseif row.autoRange and not row.ranged and value > 0 then
					row.ranged = true
					local max = value * 4
					SetSliderRange(row, max, max / 400)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Edits
--------------------------------------------------------------------------------------------------

local function SetValue(row, v, fromSlider)
	if row.unavailable then
		return
	end

	if row.kind == "switch" then
		if Same(S.values[row.key], v) then
			return
		end
		S.values[row.key] = v
		row.editedAt = S.clock
		if row.wg then
			WG[row.wg] = v
		else
			Send(row.command .. " " .. (v and "1" or "0"))
		end
		RefreshRow(row)
		return
	end

	if row.kind ~= "bool" then
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			return
		end
		if row.integer then
			v = math.floor(v + 0.5)
		end
		if row.hardMin and v < row.hardMin then
			v = row.hardMin
		end
	end

	local scopeId = ScopeId()
	if scopeId == nil then
		SetDesc("Select a fixed-wing aircraft first, or switch to All aircraft.")
		row.sig = nil
		RefreshRow(row)
		return
	end
	if Same(S.values[row.key], v) then
		return
	end

	S.values[row.key] = v
	row.editedAt = S.clock
	row.editedScope = scopeId
	local scoped = S.sent[scopeId]
	if scoped == nil then
		scoped = {}
		S.sent[scopeId] = scoped
	end
	scoped[row.key] = v
	QueueSet(row, v, scopeId)
	if not fromSlider then
		FlushPending(true)
	end
	RefreshRow(row, fromSlider)
end

-- works whether or not the row is lit: the gadget drops the override of this scope if it has one and gives the
-- aircraft back what they had before it
local function ResetRow(row)
	if row.kind == "group" then
		return
	end
	if row.kind == "switch" then
		-- gadget-wide, no scope and no override: back to the state the gadget starts in
		if row.default ~= nil then
			SetValue(row, row.default, false)
		end
		return
	end
	local scopeId = ScopeId()
	if scopeId == nil then
		SetDesc("Select a fixed-wing aircraft first, or switch to All aircraft.")
		return
	end
	S.pending[row.key] = nil
	if S.sent[scopeId] then
		S.sent[scopeId][row.key] = nil
	end
	if scopeId == SCOPE_ALL then
		Send("agileunset " .. row.key)
	else
		Send("agileunsetdef " .. scopeId .. " " .. row.key)
	end
	-- read it back once the gadget has had a few frames to restore it
	row.editedAt = S.clock - EDIT_HOLD + RESET_HOLD
	row.editedScope = scopeId
	row.sig = nil
	RefreshRow(row)
end

local function ResetScope()
	local scopeId = ScopeId()
	if scopeId == nil then
		SetDesc("Select a fixed-wing aircraft first, or switch to All aircraft.")
		return
	end
	S.pending = {}
	S.sent[scopeId] = nil
	if scopeId == SCOPE_ALL then
		Send("agilereset")
	else
		Send("agileresetdef " .. scopeId)
	end
	for _, row in ipairs(S.rows) do
		if row.kind ~= "switch" and row.kind ~= "group" then
			row.editedAt = S.clock - EDIT_HOLD + RESET_HOLD
			row.editedScope = scopeId
		end
	end
	InvalidateAll()
	RefreshAll()
end

local function SetScope(scope)
	if scope == S.scope then
		return
	end
	FlushPending(true)
	S.scope = scope
	InvalidateAll()
	RefreshScopeChips()
	RefreshAll()
end

--------------------------------------------------------------------------------------------------
-- Export (tweakunits-shaped tables, for baking the tuning into the unit files)
--------------------------------------------------------------------------------------------------

local function SortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function LuaKey(key)
	if key:match("^[%a_][%w_]*$") then
		return key
	end
	return string.format("[%q]", key)
end

local function LuaValue(v)
	if type(v) == "number" then
		return string.format("%.6g", v)
	elseif type(v) == "boolean" then
		return tostring(v)
	end
	return string.format("%q", tostring(v))
end

-- one "key = value," line per entry, keys sorted
local function WriteTable(lines, t, indent)
	for _, key in ipairs(SortedKeys(t)) do
		local v = t[key]
		if type(v) == "table" then
			lines[#lines + 1] = indent .. LuaKey(key) .. " = {"
			WriteTable(lines, v, indent .. "\t")
			lines[#lines + 1] = indent .. "},"
		else
			lines[#lines + 1] = indent .. LuaKey(key) .. " = " .. LuaValue(v) .. ","
		end
	end
end

local function CompactTable(t)
	local parts = {}
	for _, key in ipairs(SortedKeys(t)) do
		local v = t[key]
		parts[#parts + 1] = LuaKey(key) .. "=" .. ((type(v) == "table") and CompactTable(v) or LuaValue(v))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- the value of a tweakunits modoption, or nil without an encoder (string.base64Encode, common/stringFunctions.lua)
local function EncodeTweakunits(t)
	if type(string.base64Encode) ~= "function" then
		return nil
	end
	local text = CompactTable(t)
	-- whole groups of three bytes, so that there is no '=' padding to carry through a start script
	while #text % 3 ~= 0 do
		text = text .. " "
	end
	local ok, encoded = pcall(string.base64Encode, text)
	if not ok or type(encoded) ~= "string" then
		return nil
	end
	-- the plain alphabet: the game's tweakunits reader turns every '_' into '=' before it decodes, and its
	-- decoder takes '+' and '/' as well as '-' and '_'
	encoded = encoded:gsub("%-", "+"):gsub("_", "/")
	return encoded
end

-- the overrides of one scope: as the gadget reports them, with this session's freshest edits on top
local function ScopeOverrides(scopeId)
	local result = {}
	local source = S.over or S.sent
	for key, value in pairs(source[scopeId] or {}) do
		result[key] = value
	end
	if S.over ~= nil then
		local sent = S.sent[scopeId] or {}
		for _, row in ipairs(S.rows) do
			if Holding(row, scopeId) then
				result[row.key] = sent[row.key]
			end
		end
	end
	return result
end

local function AddTags(entry, scoped, skipped)
	for key, value in pairs(scoped) do
		local param = EXPORT_CUSTOMPARAMS[key]
		local tag = EXPORT_TAGS[key]
		if param then
			entry.customparams = entry.customparams or {}
			entry.customparams[param] = value
		elseif tag then
			if type(value) == "number" and EXPORT_SCALE[key] then
				value = value * EXPORT_SCALE[key]
			end
			entry[tag] = value
		else
			skipped[key] = true
		end
	end
end

-- onlyDefName nil: every strafing aircraft type. The overrides for all first, the type's own on top.
-- Returns the table, how many types are in it, and the overridden members that have no tag
local function BuildTweakunits(onlyDefName)
	local result, count, skipped = {}, 0, {}
	local agileOn = (Spring.GetGameRulesParam("airtune_agile") == 1)
	local lookaheadOn = (Spring.GetGameRulesParam("airtune_lookahead") == 1)
	local all = ScopeOverrides(SCOPE_ALL)
	for unitDefID in pairs(STRAFE) do
		local name = UnitDefs[unitDefID].name
		if onlyDefName == nil or name == onlyDefName then
			local entry = {}
			if agileOn then
				entry.agileflight = true
			end
			if lookaheadOn then
				entry.terrainlookahead = true
			end
			AddTags(entry, all, skipped)
			AddTags(entry, ScopeOverrides(name), skipped)
			if next(entry) ~= nil then
				result[name] = entry
				count = count + 1
			end
		end
	end
	return result, count, skipped
end

-- what one living aircraft of each type reports for the agile members, the gadget's own defaults included
local function BuildEffective(onlyDefName)
	local result, count = {}, 0
	local units = Spring.GetAllUnits() or {}
	if S.refUnitID then
		table.insert(units, 1, S.refUnitID)
	end
	for i = 1, #units do
		local unitDefID = Spring.GetUnitDefID(units[i])
		local unitDef = unitDefID and STRAFE[unitDefID] and UnitDefs[unitDefID]
		if unitDef and result[unitDef.name] == nil and (onlyDefName == nil or unitDef.name == onlyDefName) then
			local mt = Spring.GetUnitMoveTypeData(units[i])
			if type(mt) == "table" and mt.name == "airplane" then
				local entry = {}
				for _, key in ipairs(EFFECTIVE_KEYS) do
					if mt[key] ~= nil then
						entry[EXPORT_TAGS[key]] = mt[key]
					end
				end
				if next(entry) ~= nil then
					result[unitDef.name] = entry
					count = count + 1
				end
			end
		end
	end
	return result, count
end

local function ExportText(onlyDefName, tweak, count, skipped)
	local function param(name, fallback)
		local v = Spring.GetGameRulesParam(name)
		return (type(v) == "number") and string.format("%.4g", v) or fallback
	end
	local agileOn = (Spring.GetGameRulesParam("airtune_agile") == 1)
	local armed = (Spring.GetGameRulesParam("airtune_armed") == 1)

	local lines = {
		"-- Air Flight Tuning export: " .. (onlyDefName or "all strafing aircraft") .. " (" .. count .. " unit type(s))",
		"-- Saved:  " .. os.date("%Y-%m-%d %H:%M:%S"),
		"-- Engine: " .. tostring((Engine and Engine.version) or (Game and Game.version) or "unknown"),
		"-- Map:    " .. tostring((Game and Game.mapName) or "unknown"),
		"--",
		"-- How to use it, any one of:",
		"--   1. fold each entry into that unit's file under units/ (the keys are unitdef tags, lowercase)",
		"--   2. merge the tweakunits table into the unit defs from a post-defs file (same shape as the modoption)",
		"--   3. try it unbaked: the base64 line at the bottom is the value of a `tweakunits` modoption",
		"--",
		"-- Each entry is the overrides for all aircraft with the type's own overrides on top, in unitdef units:",
		"--   speed and agilespeed are elmos per second, as the sliders show them",
		"--   cruisealtitude is the Cruise alt slider / 1.5: the engine flies at 1.5 x the tag, plus a random offset",
		"--     per aircraft of -4.5 to +10.5 elmos (twice that for fighters) which the slider value does not have",
		"--   canloopbackattack is the Loopback row, it only does anything on fighters",
		"--   customparams.attacksafetydistance is the Safety dist row (luarules/gadgets/unit_air_attacksafetydistance.lua)",
		"--   maxacc, maxaileron, maxelevator and maxrudder get a random +-1% per aircraft from the engine",
		"--   0 for an agile tag or a cruiseentry tag asks the engine for its default",
	}
	if agileOn then
		lines[#lines + 1] = "-- Agile flight was ON: agileflight = true is in every entry."
	else
		lines[#lines + 1] = "-- Agile flight was switched OFF when this was saved: agileflight is in no entry."
	end
	lines[#lines + 1] = "-- Weapons live while maneuvering was "
		.. (armed and "ON" or "OFF (held while maneuvering, live in cruise)")
		.. ": that is game logic of the debug gadget"
	lines[#lines + 1] = "--   (UnitFlightRegimeChanged in luarules/gadgets/dbg_air_agile_flight.lua), not a unitdef tag."
	local skippedKeys = SortedKeys(skipped)
	if #skippedKeys > 0 then
		lines[#lines + 1] = "-- Overridden but without a unitdef tag, left out: " .. table.concat(skippedKeys, ", ")
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "local tweakunits = {"
	WriteTable(lines, tweak, "\t")
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""

	local effective, living = BuildEffective(onlyDefName)
	lines[#lines + 1] = "-- What one living aircraft of each type reported for the agile members when this was saved (" .. living .. " type(s))."
	lines[#lines + 1] = "-- Not part of tweakunits. It includes what the debug gadget sets on its own wherever nothing overrides it:"
	lines[#lines + 1] = "--   agilealtitude  = " .. param("airtune_altitude_fraction", "0.45") .. " x the cruise height (1.5 x cruisealtitude)"
	lines[#lines + 1] = "--   agilehoverbob  = " .. param("airtune_hover_bob_radii", "0.15") .. " x the unit's radius"
	lines[#lines + 1] = "--   agilehoversway = " .. param("airtune_hover_sway_radii", "0.2") .. " x the unit's radius"
	lines[#lines + 1] = "-- and the engine's derived defaults (agilespeed, agileturnrate, agileaccrate, cruisedistance, cruiseentry*)."
	lines[#lines + 1] = "-- To fly the same without the gadget, bake the three gadget values too."
	lines[#lines + 1] = "local effective = {"
	WriteTable(lines, effective, "\t")
	lines[#lines + 1] = "}"
	lines[#lines + 1] = ""

	if onlyDefName ~= nil and tweak[onlyDefName] ~= nil then
		lines[#lines + 1] = "-- Ready to paste into the unit file of " .. onlyDefName .. ", sorted by tag:"
		local snippet = {}
		WriteTable(snippet, tweak[onlyDefName], "\t")
		for _, line in ipairs(snippet) do
			lines[#lines + 1] = "--" .. line
		end
		lines[#lines + 1] = ""
	end

	lines[#lines + 1] = "return tweakunits, effective"
	lines[#lines + 1] = ""
	local encoded = EncodeTweakunits(tweak)
	if encoded then
		lines[#lines + 1] = "-- tweakunits modoption (base64 of the tweakunits table above):"
		lines[#lines + 1] = "-- " .. encoded
	else
		lines[#lines + 1] = "-- no base64 encoder here (string.base64Encode), so no tweakunits modoption line"
	end
	lines[#lines + 1] = ""
	return table.concat(lines, "\n")
end

-- the way the Feature Placer saves: a folder of its own under the write directory, plain io
local function WriteFile(path, text)
	Spring.CreateDir(EXPORT_DIR)
	local file, err = io.open(path, "w")
	if not file then
		return false, tostring(err or "could not open it for writing")
	end
	file:write(text)
	file:close()
	return true
end

local function ExportStatus(text)
	local el = El("at-export-status")
	if el then
		el.inner_rml = "<div>" .. Escape(text) .. "</div>"
		el:SetClass("nt-hidden", false)
	end
	S.descRow = nil
	SetDesc(Escape(text))
end

-- a name the status line has room for
local function ShortName(name)
	if #name > 22 then
		return name:sub(1, 20) .. ".."
	end
	return name
end

-- onlyType: just the reference aircraft's unit type
local function SaveExport(onlyType)
	FlushPending(true)
	local defName = nil
	if onlyType then
		defName = S.refDefName
		if defName == nil then
			ExportStatus("Select a fixed-wing aircraft first.")
			return
		end
	end

	local ok, err = pcall(function()
		local tweak, count, skipped = BuildTweakunits(defName)
		if count == 0 then
			ExportStatus("Nothing to save: no override, and agile flight and lookahead are off.")
			return
		end
		local text = ExportText(defName, tweak, count, skipped)
		local names
		if defName then
			names = { defName:gsub("[^%w_%-]", "_") .. ".lua" }
		else
			names = { os.date("%Y%m%d_%H%M%S") .. ".lua", "latest.lua" }
		end
		for _, name in ipairs(names) do
			local path = EXPORT_DIR .. EXPORT_BASENAME .. name
			local written, why = WriteFile(path, text)
			if not written then
				log("could not write " .. path .. ": " .. why)
				ExportStatus("Could not write .._" .. ShortName(name) .. " (" .. why .. "). Print still works.")
				return
			end
			log("saved " .. path)
		end
		local shown = ".._" .. ShortName(names[1])
		if names[2] then
			shown = shown .. " and .._" .. ShortName(names[2])
		end
		ExportStatus("Saved " .. count .. " type(s) to " .. EXPORT_DIR .. " as " .. shown)
	end)
	if not ok then
		log("export failed: " .. tostring(err))
		ExportStatus("Export failed: " .. tostring(err))
	end
end

-- the cheap way out when no file can be written: the table of the current scope in the console and infolog
local function PrintExport()
	FlushPending(true)
	local defName = nil
	if S.scope ~= SCOPE_ALL then
		defName = S.refDefName
		if defName == nil then
			ExportStatus("Select a fixed-wing aircraft first, or switch to All aircraft.")
			return
		end
	end
	local ok, err = pcall(function()
		local tweak, count = BuildTweakunits(defName)
		log("tweakunits for " .. (defName or "all strafing aircraft") .. ", " .. count .. " unit type(s):")
		Spring.Echo("{")
		for _, name in ipairs(SortedKeys(tweak)) do
			Spring.Echo("\t" .. LuaKey(name) .. " = " .. CompactTable(tweak[name]) .. ",")
		end
		Spring.Echo("}")
		local encoded = (count > 0) and EncodeTweakunits(tweak) or nil
		if encoded and #encoded <= 2000 then
			Spring.Echo("tweakunits modoption: " .. encoded)
		end
		ExportStatus("Printed " .. count .. " type(s) to the console and infolog.")
	end)
	if not ok then
		log("print failed: " .. tostring(err))
		ExportStatus("Print failed: " .. tostring(err))
	end
end

--------------------------------------------------------------------------------------------------
-- Markup
--------------------------------------------------------------------------------------------------

-- the style sheet hides a reset button until its row is changed; here it is always there, dim until then
local function ResetButtonRml(row)
	return '<div id="at-r-'
		.. row.id
		.. '" class="nt-reset" style="visibility: visible; opacity: '
		.. RESET_DIM
		.. ';"><img class="nt-icon-xs" src="'
		.. ICON_RESET
		.. '" /></div>'
end

local function LabelRml(row)
	return '<div class="nt-label" id="at-l-' .. row.id .. '"><div>' .. row.label .. "</div></div>"
end

local function UnavailableNoteRml(row)
	if not row.optional then
		return ""
	end
	return '<div id="at-x-' .. row.id .. '" class="nt-note nt-hidden"><div>not in this engine build</div></div>'
end

local function RowRml(row)
	if row.kind == "group" then
		return '<div class="nt-group"><div>' .. row.label .. "</div></div>"
	end
	if row.kind == "bool" or row.kind == "switch" then
		local out = '<div class="nt-row" id="at-w-'
			.. row.id
			.. '">'
			.. LabelRml(row)
			.. '<div class="nt-chips"><div id="at-c-'
			.. row.id
			.. '-off" class="nt-chip"><div>Off</div></div><div id="at-c-'
			.. row.id
			.. '-on" class="nt-chip"><div>On</div></div></div>'
			.. ResetButtonRml(row)
			.. "</div>"
		return out .. UnavailableNoteRml(row)
	end
	return '<div class="nt-row" id="at-w-'
		.. row.id
		.. '">'
		.. LabelRml(row)
		.. '<input type="range" id="at-s-'
		.. row.id
		.. '" class="nt-slider" min="'
		.. row.min
		.. '" max="'
		.. row.max
		.. '" step="'
		.. row.step
		.. '" value="'
		.. row.min
		.. '" />'
		.. '<input type="text" id="at-n-'
		.. row.id
		.. '" class="nt-numbox" style="flex: 0 0 50dp;" value="" />'
		.. ResetButtonRml(row)
		.. "</div>"
		.. UnavailableNoteRml(row)
end

local function BuildRoot()
	local parts = {
		'<div class="nt-header">'
			.. '<div id="at-handle" class="nt-title text-outline-darker">'
			.. '<div class="nt-title-gem"></div>'
			.. '<span class="nt-title-main">AIR FLIGHT</span>'
			.. '<span class="nt-title-accent">TUNING</span>'
			.. "</div>"
			.. '<div id="at-close" class="nt-header-btn nt-close-btn"><img class="nt-header-icon" src="'
			.. ICON_CLOSE
			.. '" /></div>'
			.. "</div>"
			.. '<div class="nt-row">'
			.. '<div class="nt-label"><div>Applies to</div></div>'
			.. '<div class="nt-chips">'
			.. '<div id="at-scope-all" class="nt-chip"><div>All aircraft</div></div>'
			.. '<div id="at-scope-def" class="nt-chip"><div id="at-scope-def-text">Selected type</div></div>'
			.. "</div>"
			.. "</div>"
			.. '<div id="at-ref" class="nt-hint"></div>'
			.. '<div id="at-body" class="nt-body" style="max-height: 62vh;">',
	}
	for _, section in ipairs(SECTIONS) do
		parts[#parts + 1] = '<div class="nt-frame" id="at-sec-'
			.. section.id
			.. '"><div class="nt-frame-title" id="at-h-'
			.. section.id
			.. '"><img id="at-a-'
			.. section.id
			.. '" class="nt-icon-sm" src="'
			.. ICON_MINUS
			.. '" /><div class="nt-frame-title-text">'
			.. section.title
			.. '</div></div><div class="nt-frame-body">'
			.. (section.hint and ('<div class="nt-hint">' .. section.hint .. "</div>") or "")
		for _, row in ipairs(section.rows) do
			parts[#parts + 1] = RowRml(row)
		end
		if section.extra then
			parts[#parts + 1] = section.extra
		end
		parts[#parts + 1] = "</div></div>"
	end
	parts[#parts + 1] = "</div>"
		.. '<div id="at-desc" class="nt-info" style="min-height: 44dp;"></div>'
		.. '<div class="nt-footer">'
		.. '<div id="at-reset-scope" class="nt-action-btn nt-danger-btn"><div class="nt-action-text">Reset this scope</div></div>'
		.. '<div id="at-print" class="nt-action-btn"><div class="nt-action-text">Info</div></div>'
		.. "</div>"
	S.root.inner_rml = table.concat(parts)
	S.els = {}
end

--------------------------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------------------------

local keyReturn -- RmlUi.key_identifier builds a fresh table on every access, resolve once

local function CommitNumbox(row, numbox)
	local text = tostring(numbox:GetAttribute("value") or "")
	local v = tonumber(text)
	-- the box shows a rounded value: leaving it untouched must not send that rounding as an override
	if v ~= nil and text ~= Format(row, S.values[row.key]) then
		SetValue(row, v, false)
	end
	row.sig = nil
	RefreshRow(row)
end

local function WireNumbox(row)
	local numbox = El("at-n-" .. row.id)
	if not numbox then
		return
	end
	numbox:AddEventListener("focus", function()
		S.focused = numbox
		Spring.SDLStartTextInput()
	end, false)
	numbox:AddEventListener("blur", function(event)
		if S.focused == numbox then
			S.focused = nil
		end
		Spring.SDLStopTextInput()
		CommitNumbox(row, numbox)
		event:StopPropagation()
	end, false)
	numbox:AddEventListener("keydown", function(event)
		if not keyReturn then
			pcall(function()
				keyReturn = RmlUi.key_identifier.RETURN
			end)
		end
		local p = event.parameters
		if p and keyReturn and p.key_identifier == keyReturn then
			numbox:Blur()
		end
	end, false)
end

local function SetSectionCollapsed(section, collapsed)
	section.collapsed = collapsed
	local el = El("at-sec-" .. section.id)
	if el then
		el:SetClass("nt-collapsed", collapsed)
	end
	local icon = El("at-a-" .. section.id)
	if icon then
		icon:SetAttribute("src", collapsed and ICON_PLUS or ICON_MINUS)
	end
end

local function WireRows()
	for _, section in ipairs(SECTIONS) do
		local header = El("at-h-" .. section.id)
		if header then
			header:AddEventListener("click", function()
				SetSectionCollapsed(section, not section.collapsed)
			end, false)
		end
		local saved = S.collapsedSaved[section.id]
		if saved == nil then
			saved = section.collapsed or false
		end
		SetSectionCollapsed(section, saved and true or false)
	end

	for _, row in ipairs(S.rows) do
		if row.kind ~= "group" then
			local wrap = El("at-w-" .. row.id)
			if wrap and row.desc then
				wrap:AddEventListener("mouseover", function()
					if S.descRow ~= row then
						S.descRow = row
						SetDesc(row.desc)
					end
				end, false)
			end
			local reset = El("at-r-" .. row.id)
			if reset then
				reset:AddEventListener("click", function()
					ResetRow(row)
				end, false)
				-- the style sheet only has a hover look for a lit button
				reset:AddEventListener("mouseover", function()
					if not row.marked then
						reset.style.opacity = RESET_DIM_HOVER
					end
				end, false)
				reset:AddEventListener("mouseout", function()
					reset.style.opacity = row.marked and "1" or RESET_DIM
				end, false)
			end
		end

		if row.kind == "bool" or row.kind == "switch" then
			local on = El("at-c-" .. row.id .. "-on")
			if on then
				on:AddEventListener("click", function()
					SetValue(row, true, false)
				end, false)
			end
			local off = El("at-c-" .. row.id .. "-off")
			if off then
				off:AddEventListener("click", function()
					SetValue(row, false, false)
				end, false)
			end
		elseif row.kind ~= "group" then
			local slider = El("at-s-" .. row.id)
			if slider then
				slider:AddEventListener("change", function(event)
					if S.applying then
						return
					end
					local p = event and event.parameters
					local v = p and tonumber(p.value)
					if v == nil then
						return
					end
					-- the echo of a value set from a read or a typed box, clamped or snapped to the slider's
					-- range and step: keep the stored value (a typed 900 must not become the slider max)
					local current = S.values[row.key]
					if type(current) == "number" then
						local shown = math.max(row.min, math.min(row.max, current))
						if math.abs(v - shown) <= row.step * 0.5 + 1e-7 then
							return
						end
					end
					SetValue(row, v, true)
				end, false)
			end
			WireNumbox(row)
		end
	end
end

--------------------------------------------------------------------------------------------------
-- Open / close, drag
--------------------------------------------------------------------------------------------------

local function SetOpen(open)
	if not S.document or open == S.open then
		return
	end
	S.open = open
	if open then
		S.lastRefresh = -10
		InvalidateAll()
		UpdateReference()
		RefreshScopeChips()
		RefreshReferenceLine()
		ReadOverrides()
		ReadValues()
		RefreshAll()
		S.document:Show()
	else
		if S.focused then
			S.focused:Blur()
		end
		FlushPending(true)
		S.drag = nil
		S.document:Hide()
	end
end

local function WireWindow()
	local doc = S.document
	local handle = El("at-handle")
	if handle then
		handle:AddEventListener("mousedown", function(event)
			local p = event.parameters
			if p and p.button and p.button ~= 0 then
				return
			end
			local mx, my = Spring.GetMouseState()
			local vsx, vsy = Spring.GetViewGeometry()
			S.drag = {
				dx = mx - S.root.offset_left,
				dy = (vsy - my) - S.root.offset_top,
				w = S.root.offset_width,
				h = S.root.offset_height,
				vsx = vsx,
				vsy = vsy,
			}
			event:StopPropagation()
		end, false)
	end
	-- the mouse button going up ends a slider drag: the last value goes out at once
	doc:AddEventListener("mouseup", function()
		S.drag = nil
		FlushPending(true)
	end, true)

	local buttons = {
		["at-close"] = function()
			SetOpen(false)
		end,
		["at-scope-all"] = function()
			SetScope(SCOPE_ALL)
		end,
		["at-scope-def"] = function()
			SetScope("def")
		end,
		["at-reset-scope"] = ResetScope,
		["at-print"] = function()
			FlushPending(true)
			Send("agileinfo")
		end,
		["at-save-all"] = function()
			SaveExport(false)
		end,
		["at-save-type"] = function()
			SaveExport(true)
		end,
		["at-export-print"] = PrintExport,
	}
	for id, fn in pairs(buttons) do
		local el = El(id)
		if el then
			el:AddEventListener("click", fn, false)
		end
	end

	local hints = {
		["at-save-all"] = "Write every strafing aircraft type as a tweakunits table: a dated file and .._latest.lua.",
		["at-save-type"] = "Write only the selected aircraft's unit type, with a snippet to paste into its unit file.",
		["at-export-print"] = "Print the tweakunits table of the current scope to the console and infolog.",
		["at-print"] = "Have the gadget print what the engine reports for one aircraft of each type, and its overrides.",
		["at-reset-scope"] = "Drop every override of the current scope; the aircraft get back what they had.",
	}
	for id, text in pairs(hints) do
		local el = El(id)
		if el then
			el:AddEventListener("mouseover", function()
				S.descRow = nil
				SetDesc(text)
			end, false)
		end
	end
end

local function TickDrag()
	local drag = S.drag
	local mx, my, _, _, _, offscreen = Spring.GetMouseState()
	if not drag or offscreen then
		return
	end
	local x = math.floor(math.max(0, math.min(drag.vsx - drag.w, mx - drag.dx)))
	local y = math.floor(math.max(0, math.min(drag.vsy - drag.h, (drag.vsy - my) - drag.dy)))
	if x ~= drag.x or y ~= drag.y then
		drag.x = x
		drag.y = y
		S.root.style.left = x .. "px"
		S.root.style.top = y .. "px"
		S.pos = { x = x, y = y }
	end
end

--------------------------------------------------------------------------------------------------
-- Call-ins
--------------------------------------------------------------------------------------------------

function widget:Initialize()
	S.context = RmlUi.GetContext("shared")
	if not S.context then
		return false
	end
	local document = S.context:LoadDocument(RML_PATH)
	if not document then
		log("could not load " .. RML_PATH .. "")
		widgetHandler:RemoveWidget(self)
		return
	end
	S.document = document
	S.root = document:GetElementById("nt-root")
	if not S.root then
		log("no #nt-root in " .. RML_PATH)
		document:Close()
		S.document = nil
		widgetHandler:RemoveWidget(self)
		return
	end

	S.rows = {}
	for _, section in ipairs(SECTIONS) do
		for _, row in ipairs(section.rows) do
			row.kind = row.kind or "slider"
			row.id = row.key
			S.rows[#S.rows + 1] = row
		end
	end

	-- (width stays what the stylesheet gives every window of this family: 13vw, at least 220px)
	local vsx, vsy = Spring.GetViewGeometry()
	if S.pos and type(S.pos.x) == "number" and type(S.pos.y) == "number" then
		S.root.style.left = math.floor(math.max(0, math.min(vsx - 120, S.pos.x))) .. "px"
		S.root.style.top = math.floor(math.max(0, math.min(vsy - 120, S.pos.y))) .. "px"
	else
		S.root.style.left = "44vw"
		S.root.style.top = "8vh"
	end

	BuildRoot()
	WireRows()
	WireWindow()
	S.wired = true
	SetDesc(nil)
	RefreshScopeChips()
	document:Hide()

	widgetHandler:AddAction("airtuning", function(_, _, params)
		local arg = params and params[1]
		if arg == "open" then
			SetOpen(true)
		elseif arg == "close" then
			SetOpen(false)
		else
			SetOpen(not S.open)
		end
	end, nil, "t")
end

function widget:Update(dt)
	if not S.open then
		return
	end
	S.clock = S.clock + (dt or 0.016)
	if S.drag then
		TickDrag()
	end
	FlushPending(false)
	if S.clock - S.lastRefresh >= REFRESH_INTERVAL then
		S.lastRefresh = S.clock
		UpdateReference()
		RefreshReferenceLine()
		ReadOverrides()
		ReadValues()
		RefreshAll()
	end
end

function widget:GetConfigData()
	-- never built (no RmlUi context, no document): hand back what was loaded
	if not S.wired then
		return { pos = S.pos, collapsed = S.collapsedSaved }
	end
	local collapsed = {}
	for _, section in ipairs(SECTIONS) do
		collapsed[section.id] = section.collapsed and true or false
	end
	return {
		pos = S.pos,
		collapsed = collapsed,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	if type(data.pos) == "table" and type(data.pos.x) == "number" and type(data.pos.y) == "number" then
		S.pos = { x = data.pos.x, y = data.pos.y }
	end
	if type(data.collapsed) == "table" then
		S.collapsedSaved = data.collapsed
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("airtuning", "t")
	if S.focused then
		Spring.SDLStopTextInput()
		S.focused = nil
	end
	if S.document then
		S.document:Close()
		S.document = nil
	end
	S.els = {}
	S.root = nil
end
