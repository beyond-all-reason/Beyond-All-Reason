-- The Graphs page of the team stats panel: one chart of the picked stat over the game,
-- the teams as its series, with a stat list beside it and a legend bar above it that
-- selects or hides teams. The panel owns the frame, the sidebar and the switches
-- and hands this page the room between them; the page keeps the histories it plots (the
-- engine's own team statistics and the team stats gadget's, through WG.teamStats) and
-- rebuilds the chart when either grows or the pick changes.
--
-- The panel gives `ctx`: its column and label tables, the derive step that turns a
-- sample's counters into every column's value, its look, metrics and colours, the
-- FlowUI and gl draw calls and its text queue, and readers for what changes at runtime
-- (the ally teams read into the table, the gadget's last hand-over, the switches, the
-- group picked in the sidebar). See gui_teamstats.lua for the fields.

local Graph = VFS.Include("luaui/Include/graph.lua")
local Custom = VFS.Include("luaui/Include/teamstats_custom.lua")
local Editbox = VFS.Include("luaui/Include/keybind_editbox.lua")
local KEYSYMS = VFS.Include("luaui/Include/keybind_keysyms.lua")

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathHuge = math.huge
local mathAbs = math.abs
local tableSort = table.sort
local tableConcat = table.concat

-- The composition bands: one colour per bucket, in the composition view's column order.
-- Softer than any team colour, so the bands are not read as teams.
local BUCKET_COLORS = {
	{ 0.86, 0.56, 0.48 },
	{ 0.68, 0.8, 0.9 },
	{ 0.5, 0.62, 0.8 },
	{ 0.72, 0.72, 0.7 },
	{ 0.7, 0.62, 0.84 },
	{ 0.86, 0.8, 0.54 },
	{ 0.62, 0.8, 0.62 },
	{ 0.52, 0.78, 0.76 },
	{ 0.82, 0.68, 0.76 },
}

-- What goes on each chart besides its lines, in the order its settings list them: the
-- milestones that say something about what it plots, and the marks its own lines make -
-- `lead` (one overtaking the rest and staying ahead), `peak` (a line's high point, once it
-- has come down from it), `drop` (a line's steepest fall) and `crossing` (a line crossing
-- its even mark) - and the stretches of time `dry` (no energy left) and `full` (the
-- storage of the chart's resource full). `teammateOut` is a teammate out of the game, whose
-- units and resources the rest were handed. Every chart over time has `teamDied` as well:
-- a team's end explains the end of its lines.
local MARKS = {
	-- Flow
	metalIncome = { "moho", "converter", "advConverter", "ecoStrike", "commanderLost", "peak" },
	metalExpense = { "tech2" },
	metalLevel = { "full" },
	energyIncome = { "fusion", "afus", "geo", "ecoStrike", "peak" },
	energyExpense = { "converter", "advConverter", "nuke", "antinuke", "dry" },
	energyLevel = { "dry", "full" },
	conversion = { "converter", "advConverter", "ecoStrike", "dry" },
	buildPower = { "tech2", "nano", "ecoStrike", "commanderLost", "peak", "drop" },
	buildPowerUse = { "dry" },
	incomeMetal = { "moho", "converter", "advConverter", "ecoStrike" },
	incomeEnergy = { "fusion", "afus", "geo", "ecoStrike" },
	-- Economy
	metalProduced = { "lead", "moho", "converter", "advConverter", "ecoStrike" },
	metalReclaimed = { "lead" },
	metalUsed = { "lead", "tech2" },
	metalExcess = { "full" },
	metalReceived = { "teammateOut" },
	metalStored = { "full" },
	energyProduced = { "lead", "fusion", "afus", "geo", "ecoStrike" },
	energyReclaimed = { "lead" },
	energyUsed = { "lead", "converter", "advConverter" },
	energyExcess = { "full", "converter" },
	energyReceived = { "teammateOut" },
	energyStored = { "dry", "full" },
	-- Combat
	damageDealt = { "lead", "raid", "nukeLaunched", "lrpc", "firstKill" },
	damageReceived = { "ecoStrike", "armyLoss", "nuked", "firstLoss", "commanderLost" },
	damageEfficiency = { "crossing", "raid", "armyLoss", "firstKill", "firstLoss" },
	unitsKilled = { "lead", "raid", "firstKill", "nukeLaunched" },
	unitsDied = { "ecoStrike", "armyLoss", "nuked", "firstLoss", "commanderLost" },
	killEfficiency = { "crossing", "raid", "armyLoss", "firstKill", "firstLoss" },
	killedValue = { "lead", "raid", "commanderKill", "nukeLaunched", "firstKill" },
	lostValue = { "ecoStrike", "armyLoss", "nuked", "commanderLost", "firstLoss" },
	valueEfficiency = { "crossing", "raid", "armyLoss", "commanderKill", "commanderLost" },
	damagePerMetal = { "tech2", "tech3", "peak" },
	teamKillValue = { "commanderLost" },
	comKills = { "commanderKill" },
	comLost = { "commanderLost" },
	losses = { "ecoStrike", "armyLoss", "nuked", "commanderLost" },
	-- Units
	unitsProduced = { "lead", "tech2", "air", "naval" },
	unitsReceived = { "teammateOut" },
	unitsActive = { "peak", "drop", "armyLoss" },
	-- Composition
	composition = { "air", "naval", "tech2", "tech3", "ecoStrike", "armyLoss", "nuke", "antinuke", "lrpc" },
	tech = { "tech2", "tech3", "ecoStrike", "armyLoss" },
	unitValue = { "drop", "peak", "tech2", "tech3", "ecoStrike", "armyLoss" },
	valueArmy = { "drop", "peak", "armyLoss", "tech3" },
	armyShare = { "drop", "armyLoss" },
	valueAir = { "air", "drop", "armyLoss" },
	valueSea = { "naval", "drop", "armyLoss" },
	valueDefense = { "drop", "peak", "armyLoss" },
	valueStrategic = { "nuke", "antinuke", "lrpc" },
	valueFactories = { "tech2", "tech3", "air", "naval", "ecoStrike" },
	valueBuilders = { "tech2", "nano", "ecoStrike", "commanderLost" },
	valueEconomy = { "moho", "fusion", "afus", "converter", "advConverter", "geo", "ecoStrike" },
	valueUtility = { "radar", "ecoStrike" },
	-- What was built of each kind: a tech level or a new kind of factory changes it. What the
	-- losses and the kills were dealt by: the strikes, the nukes, the commanders.
	built = { "tech2", "tech3", "air", "naval", "fusion" },
	lostTo = { "ecoStrike", "armyLoss", "nuked", "commanderLost" },
	killedWith = { "raid", "nukeLaunched", "commanderKill" },
	-- A ranked game: taking first place, and what moved it; the score it is ranked by.
	ranking = { "lead", "ecoStrike", "armyLoss", "raid" },
	allyScore = { "lead", "peak", "drop", "ecoStrike", "armyLoss", "raid" },
	-- Map
	metalSpots = { "moho", "drop", "ecoStrike", "peak" },
	incomeMex = { "moho", "drop", "ecoStrike", "peak" },
	geoSpots = { "geo", "drop", "ecoStrike" },
	visionCoverage = { "drop", "peak", "armyLoss" },
	radarCoverage = { "radar", "drop", "ecoStrike" },
	jammerCoverage = { "drop", "ecoStrike" },
	frontLine = { "crossing", "drop", "armyLoss" },
	-- Activity
	actionsPerMinute = { "peak" },
	buildPowerIdle = { "dry" },
	-- The timeline is made of the milestones that tell the game's story.
	timeline = {
		"tech2",
		"tech3",
		"firstKill",
		"firstLoss",
		"commanderKill",
		"commanderLost",
		"ecoStrike",
		"armyLoss",
		"raid",
		"moho",
		"fusion",
		"afus",
		"air",
		"naval",
		"nuke",
		"antinuke",
		"lrpc",
		"nukeLaunched",
		"nuked",
	},
}
-- The charts that have no time, or no team, to mark.
---@type table<string, boolean?>
local UNMARKED = { profile = true, wind = true, lavaLevel = true, unitReport = true }
-- What kind of event a milestone is, as a badge on its picture - the picture is the unit, the
-- frame the team's colour, the badge the kind - named once in the chart's title row: the first
-- of something built, a tech level reached, an attack made, a loss taken. A team out of the
-- game is its skull.
local BADGES = {
	built = { sign = "plus", color = { 0.36, 0.78, 0.42 } },
	tech = { sign = "up", color = { 0.35, 0.6, 1 } },
	attack = { sign = "cross", color = { 0.98, 0.66, 0.2 } },
	lost = { sign = "minus", color = { 0.9, 0.3, 0.26 } },
}
local BADGE_ORDER = { "built", "tech", "attack", "lost" }
---@type table<string, string?>
local BADGE_OF = {
	tech2 = "tech",
	tech3 = "tech",
	nuke = "built",
	antinuke = "built",
	lrpc = "built",
	moho = "built",
	converter = "built",
	advConverter = "built",
	fusion = "built",
	afus = "built",
	geo = "built",
	radar = "built",
	nano = "built",
	air = "built",
	naval = "built",
	firstKill = "attack",
	commanderKill = "attack",
	raid = "attack",
	nukeLaunched = "attack",
	firstLoss = "lost",
	commanderLost = "lost",
	ecoStrike = "lost",
	armyLoss = "lost",
	nuked = "lost",
}
-- The marks a chart's own lines make, and the shape each is drawn as; the stretches of time.
---@type table<string, string?>
local LINE_MARKS = { lead = "dot", peak = "up", drop = "down", crossing = "diamond" }
---@type table<string, boolean?>
local SPAN_MARKS = { dry = true, full = true }
-- The marks a card explains beyond their name.
local DESCRIBED = {
	lead = true,
	peak = true,
	drop = true,
	crossing = true,
	dry = true,
	full = true,
	teammateOut = true,
	ecoStrike = true,
	armyLoss = true,
	raid = true,
}
-- Strikes: a side of a team hit hard, and one dealt. Each tells how much it cost.
---@type table<string, boolean?>
local STRIKES = { ecoStrike = true, armyLoss = true, raid = true }
-- How much a milestone of each kind tells, 0 to 1, where it does not say what it cost: which
-- of them a crowded stretch of a chart keeps. A team's end always stays.
local IMPORTANCE = {
	commanderLost = 0.9,
	commanderKill = 0.85,
	tech3 = 0.8,
	tech2 = 0.7,
	nuke = 0.7,
	teammateOut = 0.7,
	lrpc = 0.6,
	nukeLaunched = 0.6,
	afus = 0.6,
	antinuke = 0.5,
	fusion = 0.5,
	moho = 0.5,
	air = 0.4,
	naval = 0.4,
	geo = 0.35,
	advConverter = 0.35,
	converter = 0.3,
	firstKill = 0.3,
	firstLoss = 0.3,
	nano = 0.25,
	radar = 0.2,
}
-- The shortest stretch of a chart's time the milestones are thinned over, and how many a
-- stretch keeps (a lane of the timeline as many).
local STRETCH = 900
local STRETCH_ROOM = 3
-- Where a line crosses from behind to ahead, and what that is called either way.
---@type table<string, { at: number, up: string, down: string }?>
local CROSSING = {
	damageEfficiency = { at = 100, up = "aheadEven", down = "behindEven" },
	killEfficiency = { at = 100, up = "aheadEven", down = "behindEven" },
	valueEfficiency = { at = 100, up = "aheadEven", down = "behindEven" },
	frontLine = { at = 50, up = "pastMiddle", down = "behindMiddle" },
}
-- A sample's period in frames, and how much of it (per cent) without energy or with the
-- storage full makes the sample part of a stretch.
local PERIOD = 450
local SPAN_SHARE = 20
-- Every game starts with the storage full: the samples of the opening, up to this frame, are
-- how a game begins rather than how it was played, and no part of a stretch of it full.
local OPENING = 900
-- A lead taken by less than this share of the leader's value is no lead; only this many of
-- the latest changes of lead, and of crossings a line, are marked.
local LEAD_MARGIN = 0.05
local MAX_LEADS = 12
local MAX_CROSSINGS = 8

-- The marks a chart can carry, in the order its settings list them, `teamDied` last.
---@type table<string, string[]?>
local marksCache = {}
---@return string[]
local function marksOf(stat)
	if not stat then
		return {}
	end
	local held = marksCache[stat]
	if held then
		return held
	end
	---@type string[]
	local list = {}
	if not UNMARKED[stat] then
		for _, kind in ipairs(MARKS[stat] or {}) do
			list[#list + 1] = kind
		end
		list[#list + 1] = "teamDied"
	end
	marksCache[stat] = list
	return list
end

-- The items of one list put at the end of another.
---@param list table[]
---@param items table[]
local function append(list, items)
	for _, item in ipairs(items) do
		list[#list + 1] = item
	end
end

-- The grids a page can be split into, in the order the setting cycles through them.
local PAGES = {
	{ n = 9, cols = 3, rows = 3 },
	{ n = 12, cols = 4, rows = 3 },
	{ n = 16, cols = 4, rows = 4 },
}
-- How many charts of a grid, or columns of the table's trend lines, are worked out again
-- in a frame when the histories grow.
local CATCH_UP_PER_FRAME = 1
-- A trend line has at most this many points: a cell is a few dozen pixels wide.
local TREND_POINTS = 40

-- The picture of a team out of the game, which has no unit to show: a skull, on a dark
-- plate so it reads over the chart.
local SKULL = ":l:LuaUI/Images/skull.dds"
local SKULL_BACKDROP = { 0.08, 0.08, 0.08, 0.92 }
-- A line mark's shape in the card of kinds, where it stands for every team's colour.
local KIND_GREY = { 0.78, 0.78, 0.78 }

-- What a team's losses were lost to, the gadget's keys in the order the chart stacks them,
-- and their colours: enemies in red, the rest apart from it and from each other.
local LOSS_CAUSES = { "lostEnemy", "lostFriendly", "lostWater", "lostSelfD", "lostReclaimed", "lostOther" }
local CAUSE_COLORS = {
	{ 0.86, 0.3, 0.26 },
	{ 0.66, 0.46, 0.92 },
	{ 1.0, 0.56, 0.16 },
	{ 0.5, 0.62, 0.78 },
	{ 0.3, 0.76, 0.64 },
	{ 0.55, 0.55, 0.55 },
}
local WIND_COLOR = { 0.6, 0.82, 1 }
local LAVA_COLOR = { 1, 0.45, 0.12 }
-- What dealt a loss or a kill, as the gadget tells them apart: the forces on the ground,
-- aircraft, long-range artillery and nukes - earth, sky, fire and the flash.
local DEALT_BY = { "ground", "air", "artillery", "nuke" }
local DEALT_COLORS = { { 0.66, 0.6, 0.46 }, { 0.55, 0.78, 1 }, { 1, 0.56, 0.2 }, { 0.95, 0.9, 0.35 } }
-- The unit report card: the value a type destroyed, in the one team's colour when it is one
-- team's, else in this; what was spent on it in grey under it. At most this many types:
-- the open card scrolls through them.
local REPORT_COLOR = { 0.86, 0.42, 0.34 }
local REPORT_BUILT = { 0.45, 0.45, 0.45 }
local REPORT_ROWS = 250
-- How many of its rows a notch of the wheel scrolls the open report card by.
local REPORT_WHEEL = 3
-- How often the report card's records are asked for while it is on the page.
local UNITS_FRAMES = 150
-- The charts of one whole in its parts, a band each: what the losses were lost to, where
-- the income comes from right now, the value on the field by tech level. `names` is where
-- the parts' names are, `labels` the names' own keys where they are not the parts' keys;
-- `dropEmpty` leaves out a part nothing was ever in - tidal on a map without water.
---@type table<string, { keys: string[], names: string, labels: string[]?, colors: number[][], dropEmpty: boolean? }?>
local PARTS = {
	losses = { keys = LOSS_CAUSES, names = "ui.teamStats.graph.cause.", colors = CAUSE_COLORS },
	incomeMetal = {
		keys = { "incomeMex", "incomeConverters", "incomeReclaim", "incomeMetalOther" },
		names = "ui.teamStats.graph.source.",
		colors = { { 0.62, 0.66, 0.74 }, { 0.95, 0.78, 0.25 }, { 0.3, 0.76, 0.5 }, { 0.5, 0.5, 0.5 } },
		dropEmpty = true,
	},
	incomeEnergy = {
		keys = {
			"incomeWind",
			"incomeSolar",
			"incomeTidal",
			"incomeGeo",
			"incomeFusion",
			"incomeEnergyReclaim",
			"incomeEnergyOther",
		},
		names = "ui.teamStats.graph.source.",
		colors = {
			{ 0.6, 0.82, 1 },
			{ 1, 0.86, 0.3 },
			{ 0.25, 0.7, 0.75 },
			{ 1, 0.5, 0.2 },
			{ 0.75, 0.45, 1 },
			{ 0.3, 0.76, 0.5 },
			{ 0.5, 0.5, 0.5 },
		},
		dropEmpty = true,
	},
	tech = {
		keys = { "valueT1", "valueT2", "valueT3" },
		names = "ui.teamStats.graph.techLevel.",
		colors = { { 0.55, 0.72, 0.5 }, { 0.35, 0.6, 1 }, { 0.85, 0.45, 1 } },
		dropEmpty = true,
	},
	-- Where the metal went: the value of everything finished, by the composition's kinds.
	built = {
		keys = {
			"builtArmy",
			"builtAir",
			"builtSea",
			"builtDefense",
			"builtStrategic",
			"builtFactories",
			"builtBuilders",
			"builtEconomy",
			"builtUtility",
		},
		names = "ui.teamStats.",
		labels = {
			"valueArmy",
			"valueAir",
			"valueSea",
			"valueDefense",
			"valueStrategic",
			"valueFactories",
			"valueBuilders",
			"valueEconomy",
			"valueUtility",
		},
		colors = BUCKET_COLORS,
		dropEmpty = true,
	},
	-- The value an enemy destroyed of the teams', and the value they destroyed of an enemy's,
	-- by what dealt the blow.
	lostTo = {
		keys = { "lostToGround", "lostToAir", "lostToArtillery", "lostToNuke" },
		names = "ui.teamStats.graph.dealtBy.",
		labels = DEALT_BY,
		colors = DEALT_COLORS,
		dropEmpty = true,
	},
	killedWith = {
		keys = { "killedWithGround", "killedWithAir", "killedWithArtillery", "killedWithNuke" },
		names = "ui.teamStats.graph.dealtBy.",
		labels = DEALT_BY,
		colors = DEALT_COLORS,
		dropEmpty = true,
	},
}
-- The charts that are no column's and read the gadget's samples.
local GADGET_CHARTS = {
	timeline = true,
	ranking = true,
	composition = true,
	wind = true,
	lavaLevel = true,
	losses = true,
	incomeMetal = true,
	incomeEnergy = true,
	tech = true,
	built = true,
	lostTo = true,
	killedWith = true,
	unitReport = true,
}

-- Whether the map's wind changes at all: wind that always blows the same would chart as a
-- flat line, and a map without any as a line along the floor.
local function windy()
	return Game ~= nil and (Game.windMax or 0) > (Game.windMin or 0)
end

-- Whether the map's lava rises or falls at all, by the tides the map sets it: lava that stays
-- where it starts would chart as a flat line.
local function lavaMoves()
	local lava = BAR and BAR.Lava
	if not (lava and lava.isLavaMap) then
		return false
	end
	for _, tide in ipairs(lava.tideRhythm or {}) do
		if math.abs((tide[1] or lava.level) - lava.level) > 1 then
			return true
		end
	end
	return false
end

-- The team profile's axes, in the order they go round the wheel from the top.
local PROFILE_AXES = {
	{ key = "damageDealt" },
	{ key = "unitsProduced" },
	{ key = "metalProduced" },
	{ key = "energyProduced" },
	{ key = "unitValue", gadget = true },
	{ key = "actionsPerMinute", gadget = true },
}

-- The legend bar's looks: a block is a button, the picked one lit and framed warm; the
-- squares under the cursor are framed white, over a pick's frame, so a press's target
-- stands out whatever state it is in.
local PLATE = { 1, 1, 1, 0.05 }
local PICKED_FRAME = { 1, 0.78, 0.51, 0.85 }
local HOVER_FRAME = { 1, 1, 1, 0.85 }

-- A number with an SI prefix, when the game's string helpers are there to give one.
local function siText(v)
	---@diagnostic disable-next-line: undefined-field
	local formatSI = string.formatSI
	return formatSI and formatSI(v) or nil
end

-- A percentage for an axis or a tooltip: whole, a prefix past a million, infinity as
-- its sign.
local function percentFormat(v)
	if v == mathHuge then
		return "\226\136\158"
	elseif v == -mathHuge then
		return "-\226\136\158"
	end
	local si = math.abs(v) >= 1e6 and siText(v)
	if si then
		return si .. "%"
	end
	return string.format("%.0f%%", v)
end

-- A value in a mark's text, the way the chart's axis prints it.
local function valueText(column, v)
	if column and column.fmt == "percent" then
		return percentFormat(v)
	end
	local si = mathAbs(v) >= 1000 and siText(v)
	if si then
		return si
	end
	if mathAbs(v) < 10 and v ~= mathFloor(v) then
		return string.format("%.1f", v)
	end
	return string.format("%d", mathFloor(v + 0.5))
end

-- A colour as a text colour code, lifted towards white so a dark team still reads.
local function tint(c)
	return string.char(
		255,
		mathFloor((c[1] * 0.65 + 0.35) * 255),
		mathFloor((c[2] * 0.65 + 0.35) * 255),
		mathFloor((c[3] * 0.65 + 0.35) * 255)
	)
end

local M = {}

function M.new(ctx)
	---@type table<string, any>
	local page = {
		open = true,
		stat = "damageDealt",
		-- Units right-clicked off the chart, by key.
		---@type table<string, boolean>
		hidden = {},
		-- The players picked in the legend bar, by "team<id>" key, however it groups them;
		-- none is every team alike. They stand out on the chart, or with Remove unselected on
		-- they are all it shows. Starts on the viewer's own team, when they have one and
		-- Remove unselected is off.
		---@type table<string, boolean>
		selected = {},
		selectionSet = false,
		-- The viewer's team as the last build saw it: a spectator can switch it.
		---@type table?
		viewer = nil,
		-- Whether the units not picked are left off the charts rather than faded behind.
		hideUnselected = false,
		-- The axes of the profile wheel, as the last build read them.
		---@type table[]
		profileAxes = {},
		-- The page's own grouping, kept apart from the table's: a chart of ally teams and
		-- a table of ally teams are different questions, and picking a single player on the
		-- chart should not flatten the table.
		grouped = true,
		hover = { stat = 0, legend = 0, block = 0, kind = 0, filter = 0, addTo = 0 },
		-- A card of actions over everything, taking the next press: what a custom category,
		-- a custom graph or the Add to... button offers.
		---@type table?
		menu = nil,
		-- A category being named, in a field over its sidebar entry.
		---@type table?
		naming = nil,
		-- A press on a graph of the player's own, until it is let go: { key, graph, x, y,
		-- moving } - a click opens the graph, a drag moves it.
		---@type table?
		drag = nil,
		-- Per team: the engine's history entries taken at the period, derived, and how
		-- many of the engine's list they are; the live newest entry is left out so the
		-- chart changes once a period, not every second.
		---@type table<integer, { used: integer, entries: table[], frames: number[] }>
		engine = {},
		-- Per team: the gadget's samples as a run per key.
		---@type table<integer, { frames: number[], values: table<string, number[]> }>
		gadget = {},
		-- Per team: what each of its unit types did, as the gadget last handed it over, and
		-- the frame the records were last asked for.
		---@type table<integer, table<integer, table>>
		typeStats = {},
		---@type integer?
		typesAsked = nil,
		-- [teamID] = the sample period its history was last asked for in. Per team, so a team
		-- that comes into view - the other side at game over - is asked for at once.
		---@type table<integer, integer>
		askedPeriod = {},
		-- Bumped when either history grows: what was worked out from it is worked out again.
		version = 0,
		-- Whether any team has a sample at all: tells a chart that waits for the first
		-- ones from a stat that has nothing to plot.
		anySamples = false,
		-- Everything is built again when `dirty`; when only the histories grew (`stale`),
		-- the charts catch up a few a frame, so a page of them never stalls the game.
		dirty = true,
		stale = false,
		---@type table[]
		statList = {},
		-- The stat list's entries by key: a custom category's graph is listed under a key of
		-- its own, with the stat it shows and the settings it keeps.
		---@type table<string, table>
		entryByKey = {},
		---@type table[]
		units = {},
		---@type table<string, table>
		unitByKey = {},
		-- The legend bar: the All button, then a block per ally team, and the squares in
		-- the blocks as hit targets.
		---@type table[]
		barBlocks = {},
		---@type table[]
		barItems = {},
		barLabels = true,
		-- Bumped whenever what the panel bakes for the page changes: the pick, the
		-- selection, the hidden set, the bar's layout. Part of the panel's bake signature.
		gen = 0,
		---@type table?
		rects = nil,
		---@type table?
		chartHit = nil,
		-- The grid: how many charts a page holds, which row it starts at, the charts on
		-- it and the one under the cursor.
		perPage = 12,
		scroll = 0,
		maxScroll = 0,
		---@type table[]
		miniCharts = {},
		---@type table?
		miniHit = nil,
		-- A chart opened from the grid, by stat key: it takes the whole page until it is
		-- closed again.
		---@type string?
		zoom = nil,
		-- The group the stat list was built for; another one shows its own charts.
		---@type string?
		group = nil,
		-- Where the card of milestone kinds is anchored: the settings row that opens it.
		---@type table?
		kindsAnchor = nil,
		-- The marks left off each chart, by stat and kind, and whether the card that picks
		-- them for the chart open is open.
		---@type table<string, table<string, boolean>>
		marksOff = {},
		kindsOpen = false,
		---@type table[]
		kindRects = {},
		empty = true,
		scale = 1,
	}

	-- The player's own categories, kept at the front of the panel's groups.
	page.custom = Custom.new(ctx)

	-- Its hits are only used until the next one: the cursor's, a frame at a time.
	local chart = Graph.new({
		kind = "line",
		legend = false,
		xUnit = "frames",
		lineWidth = 2,
		includeZero = true,
		reuseHits = true,
		look = { plotFill = { 0, 0, 0, 0.16 } },
	})
	page.chart = chart

	-- The custom category's graph open on its own, if one is: its settings are the page's
	-- while it is.
	function page.openGraph()
		local entry = page.zoom and page.entryByKey[page.zoom]
		return entry and entry.graph or nil
	end

	-- Ally teams as the units of the legend bar, in a game where a side has more than one
	-- player to group: the switch's grouping, or the open custom graph's own.
	local function grouped()
		local graph = page.openGraph()
		local on = page.grouped
		if graph then
			on = graph.grouped
		end
		return on and not ctx.soloTeams
	end

	-- The stat a chart shows, whatever its entry is called.
	local function statOf(key)
		local entry = key and page.entryByKey[key]
		return entry and entry.stat or key
	end

	-- The marks left off a chart: a custom category's graph keeps its own, the page one set
	-- a chart, made when first asked for.
	local function marksOffFor(key)
		local entry = key and page.entryByKey[key]
		if entry and entry.graph then
			return entry.graph.off
		end
		local stat = statOf(key) or ""
		local off = page.marksOff[stat]
		if not off then
			off = {}
			page.marksOff[stat] = off
		end
		return off
	end

	-- The settings a chart is drawn with: a custom category's graph keeps its own, every
	-- other chart takes the switches' and the marks left off it.
	local function settingsOf(key)
		local entry = key and page.entryByKey[key]
		if entry and entry.graph then
			return entry.graph
		end
		return {
			grouped = page.grouped,
			share = ctx.filters.shareOfTotal,
			milestones = ctx.filters.milestones,
			off = marksOffFor(key),
		}
	end

	-- The marks left off the chart open.
	local function kindsOff()
		return marksOffFor(page.zoom or page.stat)
	end

	-- Picks and hides are kept per player - "team<id>" - whichever way the bar groups them,
	-- so a graph drawn per player keeps a pick of one player through a page grouped by
	-- ally team, and back. A whole ally team's key is still read: "ally<id>" is all of its
	-- players.
	-- The keys made once a team, not every time a pick is looked up; nothing picked or hidden -
	-- mostly the case - needs no key at all.
	---@type table<integer, string>, table<integer, string>
	local teamKeys, allyKeys = {}, {}
	local function teamIn(set, team)
		if next(set) == nil then
			return false
		end
		local tk, ak = teamKeys[team.id], allyKeys[team.allyID]
		if not tk then
			tk = "team" .. team.id
			teamKeys[team.id] = tk
		end
		if not ak then
			ak = "ally" .. team.allyID
			allyKeys[team.allyID] = ak
		end
		return set[tk] == true or set[ak] == true
	end

	-- Whether a unit is picked or hidden, whichever way it is grouped: a player goes with
	-- its own key or its ally team's; an ally team is picked with any of its players and
	-- hidden with all of them.
	local function isPicked(u)
		for _, team in ipairs(u.teams) do
			if teamIn(page.selected, team) then
				return true
			end
		end
		return false
	end

	local function isHidden(u)
		for _, team in ipairs(u.teams) do
			if not teamIn(page.hidden, team) then
				return false
			end
		end
		return #u.teams > 0
	end

	-- Every player of a unit picked: what makes a press on it take the pick back out.
	local function allPicked(u)
		for _, team in ipairs(u.teams) do
			if not teamIn(page.selected, team) then
				return false
			end
		end
		return #u.teams > 0
	end

	-- Picks or unpicks - hides or shows - every player a unit stands for. A whole ally
	-- team's key is taken apart into its players first, so one of them can go on its own.
	local function setTeams(set, u, on)
		for _, team in ipairs(u.teams) do
			local allyKey = "ally" .. team.allyID
			if set[allyKey] then
				set[allyKey] = nil
				local ally = page.unitByKey and page.unitByKey[allyKey]
				for _, id in ipairs(ally and ally.members or {}) do
					set["team" .. id] = true
				end
			end
			set["team" .. team.id] = on or nil
		end
	end
	page.isPicked, page.isHidden, page.allPicked = isPicked, isHidden, allPicked

	-- The units a chart of these settings is drawn with: ally teams or players.
	local function unitsFor(settings)
		local list = (settings.grouped and not ctx.soloTeams) and page.allyUnits or page.playerUnits
		return list or page.units
	end

	-- The Group by team switch while the page is open, from the panel.
	function page.setGrouped(state)
		if page.grouped ~= state then
			page.grouped = state
			page.dirty = true
			page.gen = page.gen + 1
			page.rebuildUnits()
		end
	end

	----------------------------------------------------------------
	-- The stat list
	----------------------------------------------------------------

	-- The marks the chart open can carry, in the order its settings name them; none on a
	-- grid, where the charts are too small for any.
	local function milestoneKinds()
		if page.zoom == nil then
			return {}
		end
		return marksOf(statOf(page.zoom))
	end

	-- What a kind of mark is called.
	local function markName(kind)
		return ctx.i18n("ui.teamStats.milestone." .. kind)
	end

	-- Whether the chart open has anything to mark - on a grid, whether the charts it opens
	-- may - and whether there is a card of marks to pick from, which only a chart open has.
	function page.marksApply()
		return page.zoom == nil or #marksOf(statOf(page.zoom)) > 0
	end

	function page.kindsApply()
		return #milestoneKinds() > 0
	end

	-- What a settings row with a value says, and what pressing it does. The panel asks
	-- rather than knowing, so a new setting only needs adding here.
	function page.settingValue(key)
		if key == "perPage" then
			return page.perPage
		end
		local kinds = milestoneKinds()
		if #kinds == 0 then
			return "\226\128\147"
		end
		local off = kindsOff()
		local on = 0
		for _, kind in ipairs(kinds) do
			if not off[kind] then
				on = on + 1
			end
		end
		return on .. "/" .. #kinds
	end

	-- The card put away from outside: Escape, or the panel closing.
	function page.closeKinds()
		if page.kindsOpen then
			page.kindsOpen = false
			page.dirty = true
			page.gen = page.gen + 1
		end
	end

	function page.settingPress(key, back)
		if key == "perPage" then
			page.cyclePerPage(back)
			return
		end
		-- The card of kinds opens over the charts and closes on the next press.
		page.kindsOpen = not page.kindsOpen
		page.dirty = true
		page.gen = page.gen + 1
	end

	-- Whether the stat list is shown beside the charts: a grid says what each chart is in
	-- its own title, so the list would only take room from it.
	function page.listShown()
		return not page.gridded()
	end

	function page.rebuildStatList()
		local group = ctx.groupByKey[ctx.selectedGroup()] or ctx.GROUPS[1]
		if page.group ~= group.key then
			-- A group of its own charts: the page shows them rather than staying on the one
			-- that was open in the group before.
			page.group, page.zoom, page.scroll = group.key, nil, 0
		end
		local list = {}
		do
			-- The way back to the grid, kept apart from the stats by a rule.
			list[#list + 1] = { key = "overview", label = ctx.i18n("ui.teamStats.graph.overview"), back = true }
			list[#list + 1] = { divider = true }
		end
		if group.custom then
			-- A custom category's graphs in its order, each under a key of its own: one stat
			-- can be in it twice, drawn two ways. What needs the gadget waits for it.
			for _, graph in ipairs(group.graphs) do
				local column = ctx.COLUMNS[graph.stat]
				local needsGadget = column and (column.gadget or column.liveOnly) or GADGET_CHARTS[graph.stat]
				-- The wind on a map where it never changes would be a flat line, a count of the
				-- map's spots on one without them nothing.
				if
					(ctx.gadgetOn() or not needsGadget)
					and (graph.stat ~= "wind" or windy())
					and (graph.stat ~= "lavaLevel" or lavaMoves())
					and (graph.stat ~= "ranking" or ctx.ranked())
					and (not column or ctx.columnShown(column))
				then
					local label = column and ctx.columnTitle(column) or ctx.i18n("ui.teamStats.graph." .. graph.stat)
					-- Only an amount has a total to take a part of: a ratio or a level added
					-- with the switch on is still drawn as it is.
					if column and graph.share and column.fmt == "si" then
						label = label .. " \194\183 " .. ctx.L.switch.shareOfTotal
					end
					list[#list + 1] = {
						key = "g" .. graph.id,
						stat = graph.stat,
						label = label,
						column = column,
						graph = graph,
					}
				end
			end
		else
			if group.key == "composition" and ctx.gadgetOn() then
				-- In a ranked game the standing leads: what the rest adds up to.
				if ctx.ranked() then
					list[#list + 1] = { key = "ranking", label = ctx.i18n("ui.teamStats.graph.ranking") }
				end
				list[#list + 1] = { key = "composition", label = ctx.i18n("ui.teamStats.graph.composition") }
				list[#list + 1] = { key = "tech", label = ctx.i18n("ui.teamStats.graph.tech") }
				list[#list + 1] = { key = "built", label = ctx.i18n("ui.teamStats.graph.built") }
			end
			for i = 1, #group.columns do
				local column = ctx.COLUMNS[group.columns[i]]
				if ctx.columnShown(column) and (ctx.gadgetOn() or not column.liveOnly) then
					list[#list + 1] = { key = column.key, label = ctx.columnTitle(column), column = column }
				end
			end
			-- Charts that are no one column's: where the income comes from, what the combat's
			-- losses were lost to, and the map's wind, on a map where it changes.
			if group.key == "live" and ctx.gadgetOn() then
				list[#list + 1] = { key = "incomeMetal", label = ctx.i18n("ui.teamStats.graph.incomeMetal") }
				list[#list + 1] = { key = "incomeEnergy", label = ctx.i18n("ui.teamStats.graph.incomeEnergy") }
			end
			if group.key == "map" and ctx.gadgetOn() and windy() then
				list[#list + 1] = { key = "wind", label = ctx.i18n("ui.teamStats.graph.wind") }
			end
			if group.key == "map" and ctx.gadgetOn() and lavaMoves() then
				list[#list + 1] = { key = "lavaLevel", label = ctx.i18n("ui.teamStats.graph.lavaLevel") }
			end
			if group.key == "combat" and ctx.gadgetOn() then
				list[#list + 1] = { key = "losses", label = ctx.i18n("ui.teamStats.graph.losses") }
				list[#list + 1] = { key = "lostTo", label = ctx.i18n("ui.teamStats.graph.lostTo") }
				list[#list + 1] = { key = "killedWith", label = ctx.i18n("ui.teamStats.graph.killedWith") }
				list[#list + 1] = { key = "unitReport", label = ctx.i18n("ui.teamStats.graph.unitReport") }
			end
		end
		page.statList = list
		page.entryByKey = {}
		for _, entry in ipairs(list) do
			if entry.key then
				page.entryByKey[entry.key] = entry
			end
		end
		local found = false
		---@type table?
		local first = nil
		for i = 1, #list do
			if list[i].key == page.stat then
				found = true
			end
			if not first and list[i].key and not list[i].back and not list[i].divider then
				first = list[i]
			end
		end
		if not found and first then
			page.stat = first.key
		end
		page.dirty = true
		page.gen = page.gen + 1
	end

	----------------------------------------------------------------
	-- Layout
	----------------------------------------------------------------

	---@type fun()
	local layoutBar

	-- The room the panel hands over, bottom-left to top-right, and the scale: the stat
	-- list down the left, the legend bar along the top, the chart in the rest. The list's
	-- card spans listY1..listY2 when given, so it lines up with the sidebar's beside it;
	-- the bar runs to barX2 when given, past the charts' right edge.
	function page.setLayout(x1, y1, x2, y2, s, listY1, listY2, barX2)
		page.scale = s
		-- Kept so the page can lay itself out again when the list comes or goes without the
		-- panel having a reason to.
		page.layoutArgs = { x1, y1, x2, y2, s, listY1, listY2, barX2 }
		page.listWas = page.listShown()
		local gap = mathFloor(12 * s)
		local listW = page.listShown() and mathFloor(200 * s) or -gap
		local barH = ctx.metrics.rowHeight + mathFloor(8 * s)
		page.rects = {
			list = { x1, listY1 or y1, x1 + mathMax(0, listW), listY2 or y2 },
			-- The bar keeps its place whether the stat list shows or not: the list's card
			-- starts below it.
			bar = { x1, y2 - barH, barX2 or x2, y2 },
			chart = { x1 + listW + gap, y1, x2, y2 - barH - mathFloor(4 * s) },
			-- The sidebar's entry height, so the two lists run level.
			rowH = ctx.metrics.catRowHeight,
			-- A legend square, the block plate's inset from the bar, and the frame around
			-- the picked block.
			square = ctx.metrics.rowHeight - mathFloor(8 * s),
			inset = mathFloor(2 * s),
			frame = mathMax(2, mathFloor(s)),
		}
		local c = page.rects.chart
		---@cast c [number, number, number, number]
		chart:setBounds(c[1], c[2], c[3] - c[1], c[4] - c[2])
		page.rebuildStatList()
		layoutBar()
	end

	-- Where the card of kinds hangs: the rect of the settings row that opens it.
	function page.setKindsAnchor(rect)
		page.kindsAnchor = rect
	end

	-- Whether leaving the unpicked teams off can show anything a highlight does not: not
	-- with two players, where picking one of them already says all there is to say.
	function page.filterOffered()
		local players = 0
		for _, u in ipairs(page.units) do
			players = players + #u.members
		end
		return players > 2
	end

	-- Whether the charts are the picked units alone right now: the switch is on, it means
	-- something in this game, and something is picked.
	local function filtering()
		if not (page.hideUnselected and page.filterOffered()) then
			return false
		end
		for _, u in ipairs(page.units) do
			if isPicked(u) and not isHidden(u) then
				return true
			end
		end
		return false
	end

	-- The switch that leaves the unpicked teams off belongs with the picking: the page draws
	-- it at the end of the legend bar.
	---@type fun(): table?
	local filterToggleRect

	-- Where that switch sits on the bar, for whoever needs to point at it.
	function page.filterToggle()
		return filterToggleRect()
	end

	-- The switch's room and rect, and the Add to... button's, worked out once a layout (the
	-- cursor asks for them every frame): kept with the rects they were worked out for, which
	-- a layout - a new size, font or language - makes anew.
	---@type { rects: table?, reserve: number, toggle: [number, number, number, number]?, addTo: [number, number, number, number]?, addToLabel: string? }
	local laidOut = { rects = nil, reserve = 0, toggle = nil, addTo = nil, addToLabel = nil }
	local function layoutParts()
		local r = page.rects
		if laidOut.rects == r then
			return laidOut
		end
		laidOut.rects = r
		local font = ctx.font()
		local label = ctx.i18n("ui.teamStats.graph.hideUnselected")
		local labelW = font and mathFloor(font:GetTextWidth(label) * ctx.metrics.catFs) or mathFloor(90 * page.scale)
		laidOut.reserve = labelW + mathFloor(38 * page.scale) + ctx.metrics.sidePad + ctx.metrics.rowPad * 2
		local togW = mathFloor(38 * page.scale)
		local togH = mathFloor(ctx.metrics.rowHeight * 0.52)
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local x2 = r.bar[3]
		laidOut.toggle = { x2 - togW, cy - mathFloor(togH * 0.5), x2, cy - mathFloor(togH * 0.5) + togH }
		local fs = ctx.metrics.catFs
		local addLabel = ctx.i18n("ui.teamStats.custom.addTo")
		local w = (font and mathFloor(font:GetTextWidth(addLabel) * fs) or #addLabel * fs * 0.55)
			+ ctx.metrics.sidePad * 2
		local h = mathFloor(ctx.metrics.rowHeight * 0.8)
		laidOut.addTo, laidOut.addToLabel = { r.chart[3] - w, r.chart[4] - h, r.chart[3], r.chart[4] }, addLabel
		return laidOut
	end

	-- The room the switch and its caption take at the end of the bar, which the team
	-- blocks leave free.
	local function filterReserve()
		if not page.rects or not page.filterOffered() then
			return 0
		end
		return layoutParts().reserve
	end

	function filterToggleRect()
		if not page.rects or not page.filterOffered() then
			return nil
		end
		return layoutParts().toggle
	end

	function page.setFont(font, fontSize, nameFont)
		chart:configure({ font = font, fontSize = fontSize, nameFont = nameFont or font })
		page.dirty = true
	end

	local function statRect(i)
		local r = page.rects.list
		local top = r[4] - ctx.metrics.cardLip - (i - 1) * page.rects.rowH
		return r[1], top - page.rects.rowH, r[3], top
	end

	----------------------------------------------------------------
	-- Histories
	----------------------------------------------------------------

	-- Reads what grew since the last time: the engine's entries past the ones held, all
	-- but the live newest, and asks the gadget for the samples past the ones held once
	-- per period. Called by the panel every second while the page is open.
	function page.refresh()
		local grew = false
		local frame = ctx.frame()
		local hub = ctx.hub()
		local period = mathFloor(frame / 450)
		-- The engine goes on counting after game over; the charts stop where the game did.
		local over = ctx.overFrame()
		for _, ally in ipairs(ctx.allies()) do
			for _, team in ipairs(ally.teams) do
				local teamID = team.id
				local count = ctx.history(teamID)
				local e = page.engine[teamID]
				if not e then
					e = { used = 0, entries = {}, frames = {} }
					page.engine[teamID] = e
				end
				if count and count - 1 > e.used then
					-- Both indices: without the second the engine gives one entry.
					local entries = ctx.history(teamID, e.used + 1, count)
					if entries then
						-- The newest is live; the ones before it are the period's.
						for i = 1, #entries - 1 do
							local entry = entries[i]
							if not over or (entry.frame or 0) <= over then
								ctx.derive(entry)
								e.entries[#e.entries + 1] = entry
								e.frames[#e.frames + 1] = entry.frame
							end
						end
						e.used = e.used + mathMax(0, #entries - 1)
						grew = true
					end
				end
				-- Asked for once a period, and counted as asked only once the hub took it.
				if hub and page.askedPeriod[teamID] ~= period then
					local g = page.gadget[teamID]
					if hub.requestHistory(teamID, (g and #g.frames or 0) + 1) then
						page.askedPeriod[teamID] = period
					end
				end
			end
		end
		if grew then
			page.version = page.version + 1
			page.stale = true
		end
		if page.reportShown() then
			page.askTypes()
		end
	end

	-- The report card's records, asked for every few seconds while it is on the page: by the
	-- page as it refreshes, and by the card as it is filled - after game over the page
	-- refreshes only as the panel opens. The gadget answers within the second.
	function page.askTypes()
		local hub = ctx.hub()
		local frame = ctx.frame()
		local asked = page.typesAsked
		if not (hub and hub.requestUnits) or (asked and frame - asked < UNITS_FRAMES) then
			return
		end
		for _, ally in ipairs(ctx.allies()) do
			for _, team in ipairs(ally.teams) do
				if hub.requestUnits(team.id) then
					page.typesAsked = frame
				end
			end
		end
	end

	-- Whether the unit report card is on the page: open on its own, or in the grid.
	function page.reportShown()
		if not page.gridded() then
			return statOf(page.zoom or page.stat) == "unitReport"
		end
		for _, mini in ipairs(page.miniCharts or {}) do
			if statOf(mini.key) == "unitReport" then
				return true
			end
		end
		return false
	end

	-- A team's unit types as the gadget handed them over, through the panel's subscription.
	-- Only the report card is made of them: it alone is filled again.
	function page.receiveUnits(teamID, units)
		page.typeStats[teamID] = units
		if not page.gridded() then
			if statOf(page.zoom or page.stat) == "unitReport" then
				page.stale = true
			end
			return
		end
		for _, mini in ipairs(page.miniCharts or {}) do
			if statOf(mini.key) == "unitReport" then
				mini.version = -1
				page.stale = true
			end
		end
	end

	-- The gadget started over - a reload it could not pick up from: the samples and records held
	-- here are its old run's, so they go, and are asked for again from the first.
	-- Everything asked for again at the next refresh: the panel opened, or the game ended - its
	-- last sample taken and the other side's numbers open to everyone.
	function page.askAgain()
		page.askedPeriod, page.typesAsked = {}, nil
	end

	function page.gadgetRestarted()
		page.gadget, page.typeStats = {}, {}
		page.askAgain()
		page.version = page.version + 1
		page.dirty = true
	end

	-- The gadget's answer, through the panel's subscription.
	function page.receiveHistory(teamID, h)
		if not h or not h.frames or #h.frames == 0 then
			return
		end
		-- Flat, as the gadget hands it over: its keys come with it from the layout. Without
		-- them it cannot be read; the page asks again next period.
		local flat, keys = rawget(h, "flat"), rawget(h, "keys")
		if flat and not keys then
			return
		end
		local g = page.gadget[teamID]
		if not g or h.from == 1 then
			g = { frames = {}, values = {} }
			page.gadget[teamID] = g
		elseif h.from ~= #g.frames + 1 then
			-- Out of step with what is held: start over from what came.
			return
		end
		local n = #h.frames
		for i = 1, n do
			g.frames[#g.frames + 1] = h.frames[i]
		end
		if flat then
			-- Key k's values are the k-th run of n.
			for k = 1, #keys do
				local key = keys[k]
				local held = g.values[key]
				if not held then
					held = {}
					g.values[key] = held
				end
				local base, size = (k - 1) * n, #held
				for i = 1, n do
					held[size + i] = flat[base + i]
				end
			end
		else
			for key, run in pairs(h.values) do
				local held = g.values[key]
				if not held then
					held = {}
					g.values[key] = held
				end
				for i = 1, #run do
					held[#held + 1] = run[i]
				end
			end
		end
		page.version = page.version + 1
		page.stale = true
	end

	-- Whether any team has a sample of either kind yet.
	local function anySamples()
		for _, e in pairs(page.engine) do
			if #e.entries > 0 then
				return true
			end
		end
		for _, g in pairs(page.gadget) do
			if #g.frames > 0 then
				return true
			end
		end
		return false
	end

	-- What was worked out from the histories: runs by unit, key and way, with their points.
	-- Carried over as the histories grow - a new sample is added to a run rather than every
	-- sample added up again - and dropped once nothing asked for them over a whole version.
	---@type { version: integer, runs: table<string, table?> }
	local worked = { version = -1, runs = {} }
	-- A unit's members as part of a run's name, made once for a list of them.
	---@type table<table, string>
	local namesOfMembers = setmetatable({}, { __mode = "k" })

	-- Where a team's history of a key is: the engine's entries hold its counters, the
	-- gadget's samples the rest. The frames, and the entries or the runs by key.
	local function sourceOf(teamID, key)
		local e = page.engine[teamID]
		if e and e.entries[1] and e.entries[1][key] ~= nil then
			return e.frames, e.entries, nil
		end
		local g = page.gadget[teamID]
		if g and g.values[key] then
			return g.frames, nil, g.values
		end
		return nil, nil, nil
	end

	-- Adds to a run its members' samples it has not had yet: the inputs added up by place
	-- when the members share their frames, else by frame, then derived, bounded and turned
	-- into a rate as the run is asked for. `run.had[m]` is how many of member m's samples it
	-- has, `run.last` the frame it got to.
	local function accumulate(run)
		local spec = run.spec
		local fs, es, gs, had, n = run.fs, run.es, run.gs, run.had, run.n
		if n == 0 then
			return
		end
		local inputs, key, once = spec.inputs, spec.key, spec.once
		-- The frames to add. By place: the first member's past what the run had. By frame:
		-- every member's past it, in order, each once.
		---@type number[]
		local at
		---@type table<number, integer>?
		local place = nil
		if run.aligned then
			at = {}
			local f = fs[1]
			for i = had[1] + 1, #f do
				at[#at + 1] = f[i]
			end
		else
			local seen = {}
			at = {}
			for m = 1, n do
				local f = fs[m]
				for i = had[m] + 1, #f do
					local frame = f[i]
					if not seen[frame] then
						seen[frame] = true
						at[#at + 1] = frame
					end
				end
			end
			tableSort(at)
			place = {}
			for i = 1, #at do
				place[at[i]] = i
			end
		end
		if #at == 0 then
			return
		end
		---@type table<string, number[]>
		local sums = {}
		for j = 1, #inputs do
			local k = inputs[j]
			local acc = {}
			for m = 1, n do
				local f, entries, values = fs[m], es[m], gs[m]
				local vs = values and values[k]
				local from = had[m]
				for i = from + 1, #f do
					local v
					if entries then
						local entry = entries[i]
						v = entry and entry[k]
					elseif vs then
						v = vs[i]
					end
					if v then
						local slot = place and place[f[i]] or i - from
						if once then
							acc[slot] = acc[slot] or v
						else
							acc[slot] = (acc[slot] or 0) + v
						end
					end
				end
			end
			sums[k] = acc
		end
		for m = 1, n do
			had[m] = #fs[m]
		end
		run.last = at[#at]

		-- One sample's sums at a time, for derive() to read. The run keeps the range of the
		-- values it holds as they come.
		local scratch = {}
		local xs, ys = run.xs, run.ys
		local clamp, perMinute = spec.clamp, spec.perMinute
		local low, high = run.low, run.high
		for i = 1, #at do
			local frame = at[i]
			local v
			if spec.derived then
				local complete = true
				for j = 1, #inputs do
					local k = inputs[j]
					local sum = sums[k][i]
					if sum == nil then
						complete = false
					end
					scratch[k] = sum
				end
				scratch[key] = nil
				if complete then
					ctx.derive(scratch)
					v = scratch[key]
				end
			else
				v = sums[key][i]
			end
			if v and v == v then
				local raw = v
				if clamp then
					v = mathMax(clamp[1], mathMin(clamp[2], v))
				end
				if v ~= mathHuge and v ~= -mathHuge then
					if perMinute then
						local previous = run.previous
						if previous then
							local minutes = (frame - run.previousFrame) / 1800
							local rate = minutes > 0 and (v - previous) / minutes or 0
							xs[#xs + 1] = frame
							ys[#ys + 1] = rate
							low, high = mathMin(low, rate), mathMax(high, rate)
						end
						run.previous, run.previousFrame = v, frame
					else
						xs[#xs + 1] = frame
						ys[#ys + 1] = v
						low, high = mathMin(low, v), mathMax(high, v)
						if raw ~= v then
							run.raws = run.raws or {}
							run.raws[#xs] = raw
						end
					end
				end
			end
		end
		run.low, run.high = low, high
	end

	-- A run's members with a history of what it is made of, read afresh: which of them have
	-- one, their frames and entries or runs, and whether they all run over the same frames.
	local function sourcesOf(members, first)
		---@type number[][], (table[]|false)[], (table<string, number[]>|false)[], integer
		local fs, es, gs, n = {}, {}, {}, 0
		local aligned = true
		---@type number[]?
		local frames = nil
		for _, teamID in ipairs(members) do
			local f, entries, values = sourceOf(teamID, first)
			if f and #f > 0 then
				n = n + 1
				fs[n], es[n], gs[n] = f, entries or false, values or false
				if not frames then
					frames = f
				elseif #f ~= #frames or f[1] ~= frames[1] or f[#f] ~= frames[#frames] then
					aligned = false
				end
			end
		end
		return fs, es, gs, n, aligned
	end

	-- The runs of a gadget history a run adds up, by input: another in their place is another
	-- history, however alike.
	local function arraysOf(values, inputs)
		local list = {}
		for j = 1, #inputs do
			list[j] = values[inputs[j]] or false
		end
		return list
	end

	-- Whether a run can take its members' new samples as they are: the same histories it
	-- read, grown only at their ends, past the frame it got to; and still sharing their
	-- frames when it added them up by place.
	local function growsOn(run, fs, es, gs, n, aligned)
		if n ~= run.n or aligned ~= run.aligned then
			return false
		end
		local inputs = run.spec.inputs
		for m = 1, n do
			local f = fs[m]
			if f ~= run.fs[m] or es[m] ~= run.es[m] or gs[m] ~= run.gs[m] then
				return false
			end
			local values = gs[m]
			if values then
				local arrays = run.arrays[m]
				for j = 1, #inputs do
					if (values[inputs[j]] or false) ~= arrays[j] then
						return false
					end
				end
			end
			local had = run.had[m]
			if #f < had or (#f > had and run.last and f[had + 1] <= run.last) then
				return false
			end
		end
		return true
	end

	-- The members' histories of `key` added up sample by sample and derived:
	-- { xs = frames, ys = values, raws = values before a clamp or nil }, in frame order.
	-- Only what the value is made of is added up - the key itself, or what derive() makes
	-- it from. Every team is sampled at the same frames, so the members' samples are
	-- added by place; members that are not (one out of the game early) by frame. Per
	-- minute turns a running total into the rate between two samples. A clamp bounds the
	-- value for the plot, keeping what it really was for the tooltip. Worked out once for
	-- every chart and trend line of a unit and stat, and as the histories grow, the new
	-- samples added to it; from scratch again when a history was replaced or a member
	-- came to have one.
	local function runOf(members, key, perMinute, clamp)
		if worked.version ~= page.version then
			-- What nothing asked for over the last version goes.
			local kept = worked.version
			for id, run in pairs(worked.runs) do
				if run.asked < kept then
					worked.runs[id] = nil
				end
			end
			worked.version = page.version
		end
		local names = namesOfMembers[members]
		if not names then
			names = tableConcat(members, ",")
			namesOfMembers[members] = names
		end
		local id = names
			.. "|"
			.. key
			.. (perMinute and "|m" or "")
			.. (clamp and ("|" .. clamp[1] .. ":" .. clamp[2]) or "")
		local run = worked.runs[id]
		if run and run.version == page.version then
			run.asked = page.version
			return run, id
		end
		local inputs = ctx.derivedInputs[key]
		local fs, es, gs, n, aligned = sourcesOf(members, (inputs or { key })[1])
		if not (run and growsOn(run, fs, es, gs, n, aligned)) then
			local column = ctx.COLUMNS[key]
			run = {
				xs = {},
				ys = {},
				raws = nil,
				spec = {
					key = key,
					inputs = inputs or { key },
					derived = inputs ~= nil,
					once = column ~= nil and column.ally == true,
					perMinute = perMinute,
					clamp = clamp,
				},
				fs = fs,
				es = es,
				gs = gs,
				n = n,
				aligned = aligned,
				had = {},
				last = nil,
				low = mathHuge,
				high = -mathHuge,
			}
			run.arrays = {}
			for m = 1, n do
				run.had[m] = 0
				if gs[m] then
					run.arrays[m] = arraysOf(gs[m], run.spec.inputs)
				end
			end
			worked.runs[id] = run
		end
		accumulate(run)
		run.version, run.asked = page.version, page.version
		return run, id
	end

	-- The same as points for a chart: { { frame, value, raw }, ... }, kept with the run and
	-- grown with it.
	local function pointsOf(members, key, perMinute, clamp)
		local run = runOf(members, key, perMinute, clamp)
		local points = run.points
		if not points then
			points = {}
			run.points = points
		end
		local xs, ys, raws = run.xs, run.ys, run.raws
		for i = #points + 1, #xs do
			points[i] = { xs[i], ys[i], raws and raws[i] or nil }
		end
		return points
	end

	----------------------------------------------------------------
	-- Trend lines for the table's cells
	----------------------------------------------------------------

	-- The table draws a small line of each cell's history behind its number. The rows it
	-- wants them for are handed over whenever it rebuilds them ({ key, members } each);
	-- a column's lines are then built for every row at once, so they share one range and
	-- can be read against each other. They are kept with the version of the histories they
	-- were drawn from: when those grow, the columns catch up a few a frame, the old lines
	-- shown meanwhile, and the list the lines are baked in is made again once all have.
	---@type { sig: string, rows: table[], lines: table<string, table>, gen: integer, caught: integer, list: integer?, listFor: string? }
	local trend = { sig = "", rows = {}, lines = {}, gen = 0, caught = -1, list = nil, listFor = nil }
	-- That list is made again at every hand-over as well - the numbers beside the lines change
	-- their width, rows move - so each row's lines are baked into a list of their own where
	-- the table put them, and the trend list calls the rows' lists: a row's own list is made
	-- again only when its lines, their places or its colour changed. Its lines are drawn point
	-- by point in it, which the engine replays at little cost (each line a list of its own,
	-- placed by a matrix, was tried: it cost several times as much a frame). [rowKey] = { list,
	-- n, cells = { x, y, w, h, ... }, lines = { line, ... }, r, g, b, a, width }
	---@type table<string, table>
	local trendRowLists = {}
	-- The row being handed over cell by cell, and the rows' lists the trend list calls.
	---@type { rowKey: string?, n: integer, cells: number[], lines: table[], r: number, g: number, b: number, a: number, width: number }
	local gather = { rowKey = nil, n = 0, cells = {}, lines = {}, r = 0, g = 0, b = 0, a = 0, width = 1 }
	---@type integer[]
	local shownRows = {}

	-- Every row's own list, deleted: the rows changed, the layout did, or the page goes.
	local function dropRowLists()
		for _, row in pairs(trendRowLists) do
			gl.DeleteList(row.list)
		end
		trendRowLists = {}
	end

	function page.setTrendRows(list)
		-- Which rows there are, not the order they are sorted in: a table sorted by a number
		-- that moves every second would otherwise throw every line away every second.
		local parts = {}
		for _, row in ipairs(list) do
			parts[#parts + 1] = row.key .. "=" .. tableConcat(row.members, ".")
		end
		tableSort(parts)
		local sig = tableConcat(parts, "|")
		trend.rows = list
		if sig ~= trend.sig then
			dropRowLists()
			trend.sig, trend.lines = sig, {}
			trend.gen = trend.gen + 1
		end
	end

	-- Every row's run of one column, normalised into the unit square: x is the game time
	-- across every row's samples, y the value against the range the rows share (a running
	-- total measured from zero, anything else from its own floor). At most TREND_POINTS
	-- points a line, the last always among them.
	local function buildTrend(key, perMinute)
		local column = ctx.COLUMNS[key]
		local runs = {}
		local xMin, xMax = mathHuge, -mathHuge
		local yMin, yMax = mathHuge, -mathHuge
		for _, row in ipairs(trend.rows) do
			local run = runOf(row.members, key, perMinute, column and column.clamp)
			local xs = run.xs
			if #xs > 1 then
				runs[row.key] = run
				xMin, xMax = mathMin(xMin, xs[1]), mathMax(xMax, xs[#xs])
				yMin, yMax = mathMin(yMin, run.low), mathMax(yMax, run.high)
			end
		end
		local lines = {}
		if xMax > xMin then
			-- A running total is read against zero; a rate or a level against its own floor.
			local lo = (column and column.fmt == "si" and not perMinute) and mathMin(0, yMin) or yMin
			local span = yMax - lo
			for rowKey, run in pairs(runs) do
				local line = {}
				local xs, ys = run.xs, run.ys
				local n = #xs
				local stride = mathMax(1, math.ceil(n / TREND_POINTS))
				local width = xMax - xMin
				-- Every stride-th sample from the first, and the last.
				for i = 1, n, stride do
					line[#line + 1] = (xs[i] - xMin) / width
					line[#line + 1] = span > 0 and (ys[i] - lo) / span or 0.5
				end
				if (n - 1) % stride ~= 0 then
					line[#line + 1] = (xs[n] - xMin) / width
					line[#line + 1] = span > 0 and (ys[n] - lo) / span or 0.5
				end
				lines[rowKey] = line
			end
		end
		return lines
	end

	-- A column's lines as they are held, made at once only the first time.
	local function trendLines(key, perMinute)
		local cacheKey = key .. (perMinute and "/m" or "")
		local held = trend.lines[cacheKey]
		if not held then
			held = { key = key, perMinute = perMinute, version = page.version, lines = buildTrend(key, perMinute) }
			trend.lines[cacheKey] = held
		end
		return held.lines
	end

	-- The histories grew: a few columns a frame are drawn again from them, and once every
	-- one has, the lines shown change all at once.
	local function trendCatchUp()
		local budget = CATCH_UP_PER_FRAME
		for _, held in pairs(trend.lines) do
			if held.version ~= page.version then
				if budget == 0 then
					return
				end
				held.lines = buildTrend(held.key, held.perMinute)
				held.version = page.version
				budget = budget - 1
			end
		end
		if trend.caught ~= page.version then
			trend.caught = page.version
			trend.gen = trend.gen + 1
		end
	end

	-- One cell's line, drawn into its rect while its row's list is made. The vertices come
	-- from one function with the line in upvalues, not a closure a cell.
	---@type number[], number, number, number, number
	local cellLine, cellX, cellY, cellW, cellH = {}, 0, 0, 0, 0
	local function cellVertices()
		for i = 1, #cellLine - 1, 2 do
			gl.Vertex(cellX + (cellLine[i] or 0) * cellW, cellY + (cellLine[i + 1] or 0) * cellH)
		end
	end

	-- A row's lines, into its own list: its width and colour once, a strip a cell.
	local function drawRow(row)
		gl.LineWidth(row.width)
		gl.Color(row.r, row.g, row.b, row.a)
		local cells, lines = row.cells, row.lines
		for i = 1, row.n do
			local at = i * 4
			cellLine, cellX, cellY, cellW, cellH = lines[i], cells[at - 3], cells[at - 2], cells[at - 1], cells[at]
			gl.BeginEnd(GL.LINE_STRIP, cellVertices)
		end
	end

	-- The row handed over: its list kept when nothing about it changed, else made again.
	local function flushRow()
		local rowKey, n = gather.rowKey, gather.n
		gather.rowKey, gather.n = nil, 0
		if not rowKey or n == 0 then
			return
		end
		---@type table?
		local row = trendRowLists[rowKey]
		local same = row ~= nil
			and row.n == n
			and row.width == gather.width
			and row.r == gather.r
			and row.g == gather.g
			and row.b == gather.b
			and row.a == gather.a
		if same then
			---@cast row -?
			local had, now = row.cells, gather.cells
			for i = 1, n * 4 do
				if had[i] ~= now[i] then
					same = false
					break
				end
			end
			local hadLines, nowLines = row.lines, gather.lines
			for i = 1, same and n or 0 do
				if hadLines[i] ~= nowLines[i] then
					same = false
					break
				end
			end
		end
		if not same then
			if row then
				gl.DeleteList(row.list)
			else
				row = { cells = {}, lines = {} }
				trendRowLists[rowKey] = row
			end
			-- The cells handed over become the row's; its old arrays take the next row's.
			row.cells, gather.cells = gather.cells, row.cells
			row.lines, gather.lines = gather.lines, row.lines
			row.n, row.width = n, gather.width
			row.r, row.g, row.b, row.a = gather.r, gather.g, gather.b, gather.a
			row.list = gl.CreateList(drawRow, row)
		end
		---@cast row -?
		shownRows[#shownRows + 1] = row.list
	end

	-- One cell's line and the rect the table gives it, handed over by `ctx.trendRows` row by
	-- row - a row's cells in its one colour.
	function page.trendCell(rowKey, key, perMinute, x1, y1, x2, y2, color, width)
		local line = trendLines(key, perMinute)[rowKey]
		if not line or #line < 4 then
			return false
		end
		local w, h = x2 - x1, y2 - y1
		if w <= 2 or h <= 2 then
			return false
		end
		if gather.rowKey ~= rowKey then
			flushRow()
			gather.rowKey = rowKey
			gather.r, gather.g, gather.b, gather.a = color[1], color[2], color[3], color[4] or 0.5
			gather.width = width or 1
		end
		local n = gather.n + 1
		gather.n = n
		local cells, at = gather.cells, n * 4
		cells[at - 3], cells[at - 2], cells[at - 1], cells[at] = x1, y1, w, h
		gather.lines[n] = line
		return true
	end

	-- The table's trend lines, from a list of their own: the table is baked again whenever
	-- the cursor moves onto another row, and would draw every line again with it. Made again
	-- when the rows, the scroll, the layout or the lines change - the rows' own lists first,
	-- where they changed, as a list is not made while another one is.
	function page.drawTrendList(rowsGen, scroll, layoutGen)
		trendCatchUp()
		local sig = rowsGen .. "|" .. scroll .. "|" .. layoutGen .. "|" .. trend.gen
		if trend.listFor ~= sig or not trend.list then
			if trend.list then
				gl.DeleteList(trend.list)
			end
			for i = #shownRows, 1, -1 do
				shownRows[i] = nil
			end
			ctx.trendRows()
			flushRow()
			trend.list = gl.CreateList(function()
				if gl.Smoothing then
					gl.Smoothing(false, true, false)
				end
				for i = 1, #shownRows do
					gl.CallList(shownRows[i])
				end
				gl.LineWidth(1)
				if gl.Smoothing then
					gl.Smoothing(false, false, false)
				end
				gl.Color(1, 1, 1, 1)
			end)
			trend.listFor = sig
		end
		gl.CallList(trend.list)
	end

	function page.dropTrendList()
		if trend.list then
			gl.DeleteList(trend.list)
			trend.list, trend.listFor = nil, nil
		end
		dropRowLists()
	end

	----------------------------------------------------------------
	-- Series and the legend bar
	----------------------------------------------------------------

	-- What a series stands for: an ally team with the grouping switch on, a team without.
	-- In a fixed order, ally teams by id and teams by id, the way the player list has
	-- them, whatever the table is sorted by.
	function page.rebuildUnits()
		local allies = {}
		for _, ally in ipairs(ctx.allies()) do
			local teams = {}
			for _, team in ipairs(ally.teams) do
				teams[#teams + 1] = team
			end
			tableSort(teams, function(a, b)
				return a.id < b.id
			end)
			allies[#allies + 1] = { id = ally.id, teams = teams }
		end
		tableSort(allies, function(a, b)
			return a.id < b.id
		end)

		-- Both ways every time: the bar groups one way, and a custom graph may be drawn the
		-- other.
		local allyUnits, playerUnits = {}, {}
		local byKey = {}
		for _, ally in ipairs(allies) do
			local first = ally.teams[1]
			local members = {}
			local isLocal = false
			for _, team in ipairs(ally.teams) do
				members[#members + 1] = team.id
				isLocal = isLocal or team.isLocal == true
			end
			local unit = {
				key = "ally" .. ally.id,
				allyID = ally.id,
				-- A side of one player goes by that player's name: its number would say
				-- nothing beside it.
				name = (#ally.teams == 1 and ally.teams[1].name)
					or ctx.i18n("ui.teamStats.team", { number = ally.id + 1 }),
				color = first and { first.accent[1], first.accent[2], first.accent[3] } or { 0.8, 0.8, 0.8 },
				members = members,
				teams = ally.teams,
				isLocal = isLocal,
			}
			allyUnits[#allyUnits + 1] = unit
			byKey[unit.key] = unit
			for _, team in ipairs(ally.teams) do
				local player = {
					key = "team" .. team.id,
					allyID = ally.id,
					teamID = team.id,
					name = team.name,
					color = { team.accent[1], team.accent[2], team.accent[3] },
					members = { team.id },
					teams = { team },
					isLocal = team.isLocal,
					quiet = team.dead or team.gone,
				}
				playerUnits[#playerUnits + 1] = player
				byKey[player.key] = player
			end
		end
		page.allyUnits, page.playerUnits = allyUnits, playerUnits
		local units = grouped() and allyUnits or playerUnits
		page.units = units
		page.unitByKey = byKey

		-- The selection and the hidden set, player by player: a whole ally team's key is
		-- taken apart into its players, which loses nothing whichever way the bar or a graph
		-- groups them. A player no longer listed drops out.
		local function perPlayer(set)
			local out = {}
			for key in pairs(set) do
				local unit = byKey[key]
				for _, team in ipairs(unit and unit.teams or {}) do
					out["team" .. team.id] = true
				end
			end
			return out
		end
		page.selected = perPlayer(page.selected)
		page.hidden = perPlayer(page.hidden)
		-- A spectator switching the team they watch: a selection that was that team alone,
		-- or its whole ally team, goes with them as the first selection did; one they picked
		-- themselves stays.
		---@type table?
		local viewer = nil
		for _, ally in ipairs(allies) do
			for _, team in ipairs(ally.teams) do
				if team.isLocal then
					viewer = team
				end
			end
		end
		local was = page.viewer
		if was and viewer and was.id ~= viewer.id then
			local function teamsOf(allyID)
				local keys = {}
				local unit = byKey["ally" .. allyID]
				for _, team in ipairs(unit and unit.teams or {}) do
					keys["team" .. team.id] = true
				end
				return keys
			end
			---@return boolean
			local function exactly(keys)
				local n, want = 0, 0
				for key in pairs(page.selected) do
					if not keys[key] then
						return false
					end
					n = n + 1
				end
				for _ in pairs(keys) do
					want = want + 1
				end
				return n > 0 and n == want
			end
			local wasTeam = exactly({ ["team" .. was.id] = true })
			local wasAlly = exactly(teamsOf(was.allyID))
			if wasAlly and (grouped() or not wasTeam) then
				page.selected = teamsOf(viewer.allyID)
			elseif wasTeam then
				page.selected = { ["team" .. viewer.id] = true }
			end
		end
		page.viewer = viewer and { id = viewer.id, allyID = viewer.allyID } or nil
		-- The first selection is the viewer's own unit - unless Remove unselected is on, when
		-- every chart would open on them alone in every game; a cleared one stays cleared.
		if not page.selectionSet then
			page.selectionSet = true
			if not page.hideUnselected then
				for _, unit in ipairs(units) do
					if unit.isLocal then
						setTeams(page.selected, unit, true)
					end
				end
			end
		end
		layoutBar()
	end

	-- The legend bar: the All button first, then a button per ally team, its caption and
	-- its members as squares of their colour side by side. Captions stay while the whole
	-- row fits; squares shrink when even that does not. With the grouping switch on the
	-- whole button is the ally team; off, each square is its player and the caption is
	-- only a caption.
	layoutBar = function()
		local r = page.rects
		if not r then
			return
		end
		local pad = ctx.metrics.sidePad
		local fs = ctx.metrics.catFs
		local font = ctx.font()
		-- A block standing for a team or a player is captioned with its name, in the face
		-- the interface names players in, so its room is measured in that face too.
		local nameFont = ctx.nameFont()
		local function widthOf(label, isName)
			local face = isName and nameFont or font
			return face and mathFloor(face:GetTextWidth(label) * fs) or #label * fs * 0.55
		end
		local all = { all = true, label = ctx.i18n("ui.teamStats.graph.all"), members = {} }
		all.labelW = widthOf(all.label)
		-- One unit on the bar - the viewer alone, the other side not to be seen yet - leaves
		-- nothing to pick between: no All, no You.
		local single = #page.units <= 1
		---@type table[]
		local blocks = {}
		if not single then
			blocks[1] = all
		end
		-- Whoever is playing gets their own team a press away, beside All - unless every
		-- side is one player, when their own block already carries their name.
		---@type table?
		local mine = nil
		for _, unit in ipairs(page.units) do
			if unit.isLocal and not ctx.soloTeams then
				mine = unit
			end
		end
		if mine and not single then
			local me = { me = true, unit = mine, label = ctx.i18n("ui.teamStats.graph.you"), members = {} }
			me.labelW = widthOf(me.label)
			blocks[#blocks + 1] = me
		end
		local youLabel = ctx.i18n("ui.teamStats.graph.you")
		local seen = {}
		for _, unit in ipairs(page.units) do
			for _, team in ipairs(unit.teams) do
				local block = seen[team.allyID]
				if not block then
					-- A side of one is named after its player, and the viewer's own - playing
					-- or watching it - is "You" where every side is one player, since nothing
					-- else on the bar is theirs. In a game of teams the viewer has a block of
					-- their own beside All, so a side of one keeps its player's name there.
					local allyUnit = page.unitByKey and page.unitByKey["ally" .. team.allyID]
					local label = ctx.i18n("ui.teamStats.team", { number = team.allyID + 1 })
					if ctx.soloTeams then
						label = team.isLocal and youLabel or team.name
					elseif allyUnit and #allyUnit.teams == 1 then
						label = team.name
					end
					block = {
						ally = team.allyID,
						label = label,
						members = {},
						unit = grouped() and unit or nil,
					}
					-- The caption when the name does not fit: a team's number; in a game of
					-- sides of one only the viewer's "You" is kept.
					if not ctx.soloTeams then
						block.short = tostring(team.allyID + 1)
					elseif team.isLocal then
						block.short = youLabel
					end
					seen[team.allyID] = block
					blocks[#blocks + 1] = block
				end
				block.members[#block.members + 1] = { team = team, unit = unit }
			end
		end
		local count, labelW, shortW = 0, 0, 0
		local teamBlocks = 0
		for i = 1, #blocks do
			local b = blocks[i]
			if not b.all and not b.me then
				count = count + #b.members
				b.named = true
				b.labelW = widthOf(b.label, true)
				labelW = labelW + b.labelW + pad
				if b.short then
					b.shortW = widthOf(b.short)
					shortW = shortW + b.shortW + pad
				end
				teamBlocks = teamBlocks + 1
			end
		end
		-- The All button always keeps its caption; the team blocks share what is left once
		-- the switch at the end of the bar has its room.
		local fixed = all.labelW + pad * 3 + (blocks[2] and blocks[2].me and blocks[2].labelW + r.square + pad * 3 or 0)
		local avail = r.bar[3] - r.bar[1] - pad * 2 - fixed - filterReserve()
		local square = r.square
		-- What a crowded bar gives up, in turn: first the room between the teams, then the
		-- names - a team keeps its number, the viewer in a free-for-all their "You", as long
		-- as the squares keep half their width beside it - then every caption. The squares
		-- keep their height and give up width to what is left, so the row never runs into
		-- the switch at its end.
		local fullSep, minSep = pad * 2, mathMax(4, mathFloor(pad * 0.5))
		local function sepFor(captionW, width)
			return (avail - count * width - captionW) / mathMax(1, teamBlocks)
		end
		---@type string?, number
		local captions, captionW = "full", labelW
		if sepFor(labelW, square) < minSep then
			if shortW > 0 and sepFor(shortW, mathMax(4, mathFloor(square * 0.5))) >= minSep then
				captions, captionW = "short", shortW
			else
				captions, captionW = nil, 0
			end
		end
		---@type number
		local sep = mathMax(minSep, mathMin(fullSep, mathFloor(sepFor(captionW, square))))
		---@type number
		local width = square
		if count * width + teamBlocks * sep + captionW > avail then
			width = mathMax(2, mathFloor((avail - teamBlocks * sep - captionW) / mathMax(1, count)))
		end
		local items = {}
		local x = r.bar[1] + pad
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local y1 = cy - mathFloor(square * 0.5)
		local y2 = y1 + square
		local half = mathFloor(pad * 0.5)
		-- A team's plate reaches a little past its squares, and stops short of the next.
		local margin = mathMax(1, mathMin(half, mathFloor(sep * 0.5) - 1))
		for _, b in ipairs(blocks) do
			local fixedBlock = b.all or b.me
			local air = fixedBlock and half or margin
			b.x1 = x - air
			if fixedBlock then
				b.labelX = x
				x = x + b.labelW
				if b.me then
					-- Your own colour beside the caption, the same square the teams get.
					x = x + half
					b.swatch = { x, y1, x + square, y2 }
					x = x + square
				end
			else
				local caption = captions == "full" and b.label or (captions == "short" and b.short or nil)
				if caption then
					b.labelX = x
					b.caption = caption
					x = x + (captions == "full" and b.labelW or b.shortW) + pad
				end
				for _, member in ipairs(b.members) do
					items[#items + 1] =
						{ unit = member.unit, team = member.team, block = b, x1 = x, y1 = y1, x2 = x + width, y2 = y2 }
					x = x + width
				end
			end
			b.x2 = x + air
			x = x + (fixedBlock and pad * 2 or sep)
		end
		-- A press between two plates goes to the nearer one: the gaps are split between them,
		-- so there is nowhere along the row that picks nothing.
		for i = 1, #blocks do
			local b = blocks[i]
			local before, after = blocks[i - 1], blocks[i + 1]
			b.hx1 = before and mathFloor((before.x2 + b.x1) * 0.5) or b.x1
			b.hx2 = after and mathFloor((b.x2 + after.x1) * 0.5) or b.x2
		end
		page.barBlocks = blocks
		page.barItems = items
		page.barLabels = captions ~= nil
		page.barShort = captions == "short"
		page.barY1, page.barY2 = y1, y2
		page.gen = page.gen + 1
	end

	-- The units not hidden from the chart, of the bar's or of the list given.
	local function shownUnits(of)
		---@type table[]
		local list = {}
		for _, u in ipairs(of or page.units) do
			if not isHidden(u) then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- The selected units among the shown.
	local function pickedUnits(of)
		---@type table[]
		local list = {}
		for _, u in ipairs(of or page.units) do
			if isPicked(u) and not isHidden(u) then
				list[#list + 1] = u
			end
		end
		return list
	end

	-- Whether % of total has anything to share out: two units or more on the charts. One
	-- team picked with Remove unselected on would be all of its own total.
	-- An open chart of a ratio or a level - or one that is not a column's - has no total to
	-- take a part of either.
	function page.shareApplies()
		local key = page.zoom or page.stat
		if page.zoom then
			local stat = statOf(key)
			-- A whole in its parts is shares or amounts whoever is on it.
			if PARTS[stat] or stat == "composition" then
				return true
			end
			local column = ctx.COLUMNS[stat]
			if not (column and column.fmt == "si") then
				return false
			end
		end
		local units = unitsFor(settingsOf(key))
		local plotted = filtering() and pickedUnits(units) or shownUnits(units)
		return #plotted > 1
	end

	-- Whether what is on show is drawn over game time: a grid always has charts that are,
	-- an open profile is a wheel. The panel asks before it lays the switches out.
	function page.overTime()
		return page.gridded() or statOf(page.zoom or page.stat) ~= "profile"
	end

	-- Whether the milestones switch means anything: the timeline is made of them.
	function page.milestonesOwn()
		return statOf(page.stat) == "timeline"
	end

	-- The units a chart is about, named for its title: every team, one by name, or how many.
	local function namesOf(list)
		if #list == #page.units then
			return ctx.i18n("ui.teamStats.graph.all")
		elseif #list == 1 then
			return list[1].name
		end
		return ctx.i18n(grouped() and "ui.teamStats.graph.teams" or "ui.teamStats.graph.players", { count = #list })
	end

	-- The milestones of these units' players as pictures on the chart, each framed in its
	-- player's colour, on the unit's series where `indexByKey` names one, else in the lane.
	-- The hover text says whose it was, in their colour, then when and what.
	-- Where a timeline's lanes sit, and how close two pictures may be in x before one has
	-- to move out of the other's way. Filled in while the timeline is built.
	---@type table<string, number?>
	local lanes = {}
	local timelineGap = 0

	-- The rows a lane's pictures take, alternating above and below its line so the team
	-- keeps its height: the first free row whose last picture is far enough behind.
	local LANE_ROWS = { 0, 0.24, -0.24, 0.12, -0.12, 0.36, -0.36 }

	-- The kinds of milestone a chart shows: the ones it can carry, less those left off and
	-- those its own lines make.
	local function eventKinds(statKey, off)
		---@type table<string, boolean>
		local wanted = {}
		for _, kind in ipairs(marksOf(statKey)) do
			if not off[kind] and not LINE_MARKS[kind] and not SPAN_MARKS[kind] then
				wanted[kind] = true
			end
		end
		return wanted
	end

	-- How telling a milestone is, 0 to 1: a strike by what it cost that side of the team - the
	-- square root of its share, so a tenth still counts for something and half is nearly
	-- everything - a nuke's hit somewhat whatever it killed, the rest by their kind.
	local function severityOf(m, kind)
		local share = mathMax(0, m.share or 0)
		if STRIKES[kind] then
			return mathMin(1, math.sqrt(share))
		elseif kind == "nuked" then
			return mathMax(0.4, mathMin(1, math.sqrt(share)))
		end
		return IMPORTANCE[kind] or 0.3
	end

	-- Of the milestones a chart could show, the ones it has room for. Its time is cut into
	-- stretches - 30 seconds, a minute, two, four... counted from the start of the game, the
	-- shortest that leaves each about one and a half pictures across the chart's `room` - and
	-- each stretch keeps its most telling few (a lane of the timeline its own), the earlier of
	-- two alike, handing the rest to the first it keeps, whose hover names them. A team's end
	-- always stays: it explains the end of its lines. As the game goes on only the newest
	-- stretch takes new ones, and stretches merge only once the game has grown to twice the
	-- length, so what a chart shows seldom changes.
	local function thin(candidates, room, byLane)
		local slots = mathMax(1, mathFloor(room / 1.5))
		local width = STRETCH
		local span = mathMax(1, ctx.frame())
		while span / width > slots do
			width = width * 2
		end
		---@type table<string, table[]>, string[]
		local groups, order = {}, {}
		for _, c in ipairs(candidates) do
			local key = mathFloor(c.m.frame / width) .. (byLane and ("|" .. c.unit.key) or "")
			local group = groups[key]
			if not group then
				group = {}
				groups[key] = group
				order[#order + 1] = key
			end
			group[#group + 1] = c
		end
		local kept = {}
		for _, key in ipairs(order) do
			local group = groups[key]
			---@cast group -?
			tableSort(group, function(a, b)
				if a.must ~= b.must then
					return a.must
				end
				if a.severity ~= b.severity then
					return a.severity > b.severity
				end
				if a.m.frame ~= b.m.frame then
					return a.m.frame < b.m.frame
				end
				if a.team.id ~= b.team.id then
					return a.team.id < b.team.id
				end
				return a.kind < b.kind
			end)
			---@type integer, table?
			local shown, first = 0, nil
			local hidden = {}
			for _, c in ipairs(group) do
				if c.must or shown < STRETCH_ROOM then
					kept[#kept + 1] = c
					if not c.must then
						shown = shown + 1
						first = first or c
					end
				else
					hidden[#hidden + 1] = c
				end
			end
			if first and #hidden > 0 then
				first.hidden = hidden
			end
		end
		return kept
	end

	---@return table[]
	local function milestoneMarkers(list, indexByKey, always, statKey, settings, room)
		---@type table[]
		local markers = {}
		local live = ctx.live()
		if not live or not (always or settings.milestones) then
			return markers
		end
		local wanted = eventKinds(statKey, settings.off)
		if not next(wanted) then
			return markers
		end
		-- Every player's name, for whom a strike was dealt on.
		local names = {}
		for _, ally in ipairs(ctx.allies()) do
			for _, team in ipairs(ally.teams) do
				names[team.id] = (team.nameColor or "") .. team.name .. ctx.colors.title
			end
		end
		-- What a milestone is called: a strike by what dealt it, and on whom when dealt.
		local function labelOf(m, kind)
			if (kind == "ecoStrike" or kind == "raid") and m.cause then
				local cause = m.cause:sub(1, 1):upper() .. m.cause:sub(2)
				return ctx.i18n("ui.teamStats.milestone." .. kind .. cause, { name = names[m.victim] or "" })
			end
			return markName(kind)
		end
		---@type table[]
		local candidates = {}
		for _, unit in ipairs(list) do
			-- Its own players' milestones; where the chart asks for them, the ends of the
			-- teammates it is not made of, whose units and resources it was handed.
			local sources = {}
			for _, team in ipairs(unit.teams) do
				sources[#sources + 1] = team
			end
			local own = #sources
			if wanted.teammateOut then
				local mine = {}
				for _, team in ipairs(unit.teams) do
					mine[team.id] = true
				end
				for _, ally in ipairs(ctx.allies()) do
					if ally.id == unit.allyID then
						for _, team in ipairs(ally.teams) do
							if not mine[team.id] then
								sources[#sources + 1] = team
							end
						end
					end
				end
			end
			for si, team in ipairs(sources) do
				local teamLive = live[team.id]
				for _, m in ipairs(teamLive and teamLive.milestones or {}) do
					local kind = m.key
					if si > own then
						kind = kind == "teamDied" and "teammateOut" or nil
					end
					if kind and wanted[kind] then
						candidates[#candidates + 1] = {
							m = m,
							kind = kind,
							team = team,
							unit = unit,
							severity = severityOf(m, kind),
							must = kind == "teamDied",
						}
					end
				end
			end
		end
		local kept = thin(candidates, room or 20, next(lanes) ~= nil)
		-- In the order they happened, for the rows of a lane: one set of rows per unit, its
		-- lane its own.
		tableSort(kept, function(a, b)
			if a.m.frame ~= b.m.frame then
				return a.m.frame < b.m.frame
			end
			return a.unit.key < b.unit.key
		end)
		---@type table<string, table<integer, number>>
		local rows = {}
		for _, c in ipairs(kept) do
			local m, kind, team, unit = c.m, c.kind, c.team, c.unit
			local ud = m.unitDefID and UnitDefs[m.unitDefID] or nil
			---@cast ud table?
			local label = labelOf(m, kind)
			if ud then
				label = label .. " (" .. (ud.translatedHumanName or ud.name) .. ")"
			end
			local whose = (team.nameColor or "") .. team.name
			local text = whose .. "\n" .. ctx.colors.title .. Graph.frameLabel(m.frame) .. "  " .. label
			-- What a strike, or a nuke's hit, cost: how many units, what they were worth in
			-- metal, and what share of the side they were.
			if m.value and m.share and (STRIKES[kind] or kind == "nuked") then
				local of = (kind == "raid" and "dealt" or "lost")
					.. ((m.side == "eco" and "Eco") or (m.side == "mil" and "Mil") or "All")
				local units = m.count == 1 and ctx.i18n("ui.teamStats.mark.unitOne")
					or m.count and ctx.i18n("ui.teamStats.mark.units", { count = m.count })
					or ctx.i18n("ui.teamStats.mark.unitsSome")
				text = text
					.. "\n"
					.. ctx.colors.dim
					.. ctx.i18n("ui.teamStats.mark." .. of, {
						units = units,
						value = valueText(nil, m.value),
						share = percentFormat(m.share * 100),
					})
			end
			-- The ones its stretch had no room for.
			if c.hidden then
				local shownNames = {}
				for i, h in ipairs(c.hidden) do
					if i > 4 then
						shownNames[#shownNames + 1] = "..."
						break
					end
					shownNames[#shownNames + 1] = labelOf(h.m, h.kind)
				end
				text = text
					.. "\n"
					.. ctx.colors.dim
					.. ctx.i18n("ui.teamStats.mark.more", { count = #c.hidden, names = tableConcat(shownNames, ", ") })
			end
			local lane = lanes[unit.key]
			local y = nil
			if lane then
				-- The first row of the lane this one is clear of.
				local taken = rows[unit.key]
				if not taken then
					taken = {}
					rows[unit.key] = taken
				end
				local row = 1
				while row < #LANE_ROWS and (taken[row] or -mathHuge) > m.frame - timelineGap do
					row = row + 1
				end
				taken[row] = m.frame
				y = lane + (LANE_ROWS[row] or 0)
			end
			local died = not ud and m.key == "teamDied"
			local badgeKey = BADGE_OF[kind]
			markers[#markers + 1] = {
				x = m.frame,
				y = y,
				texture = ud and ("#" .. m.unitDefID) or (died and SKULL or nil),
				zoom = died and 0 or nil,
				backdrop = died and SKULL_BACKDROP or nil,
				text = text,
				series = indexByKey and indexByKey[unit.key] or nil,
				frame = { team.accent[1], team.accent[2], team.accent[3] },
				badge = badgeKey and BADGES[badgeKey] or nil,
				badgeKey = badgeKey,
			}
		end
		return markers
	end

	-- What a unit is worth on each profile axis right now: its teams' current stats added
	-- up, the way the table's band totals are.
	-- The chart's series from the pick and the switches. The same rules for every kind:
	-- hidden units are left out; with Remove unselected on and a selection, only the selected
	-- are plotted, otherwise every shown unit is, the selected ones lit and on top and the
	-- rest faded; the milestones are the selection's, every plotted unit's when nothing is
	-- selected. A composition is one whole, so it is the selection's summed (every shown
	-- team's without one). % of total stacks every plotted unit into one whole - ally
	-- teams against each other while grouped, players otherwise - when there are two or more
	-- to share it.
	local function profileValues(unit)
		local values = {}
		for ai, axis in ipairs(page.profileAxes) do
			local sum = 0
			for _, team in ipairs(unit.teams) do
				local v = team.stats and team.stats[axis.key]
				if v and v == v then
					sum = sum + v
				end
			end
			values[ai] = sum
		end
		return values
	end

	-- The charts a grid page draws, kept and reconfigured rather than made and freed
	-- every time the page is scrolled or the grid resized.
	---@type table[]
	local pool = {}

	-- A line per plotted unit of one column, and which of them the selection lifts.
	local function lineSeries(column, plotted)
		local series = {}
		---@type table<integer, boolean>
		local lifted = {}
		for _, u in ipairs(plotted) do
			series[#series + 1] = {
				name = u.name,
				color = u.color,
				points = pointsOf(u.members, column.key, false, column.clamp),
				width = 2,
				step = column.step,
			}
			lifted[#series] = isPicked(u)
		end
		return series, lifted
	end

	-- The marks a chart's own lines make, for the units `marked` among those `plotted` (the
	-- lines of `series`, in their order): where one overtakes the rest and stays ahead two
	-- samples, a line's highest point once it has come down from it, its steepest fall
	-- within three samples, and where it crosses its even mark. Each is a small shape on its
	-- line, in its colour; an overtaking and a crossing where the lines really cross, between
	-- the samples either side.
	---@return table[]
	local function lineMarkers(statKey, column, series, plotted, marked, off)
		---@type table[]
		local markers = {}
		---@type table<string, boolean>
		local want = {}
		for _, kind in ipairs(marksOf(statKey)) do
			if LINE_MARKS[kind] and not off[kind] then
				want[kind] = true
			end
		end
		if not next(want) then
			return markers
		end
		local isMarked = {}
		for _, u in ipairs(marked) do
			isMarked[u.key] = true
		end
		local function mark(u, si, x, kind, what, y)
			markers[#markers + 1] = {
				x = x,
				y = y,
				series = si,
				shape = LINE_MARKS[kind],
				color = u.color,
				text = tint(u.color) .. u.name .. "\n" .. ctx.colors.title .. Graph.frameLabel(x) .. "  " .. what,
			}
		end
		-- The chart's scale: a fall smaller than a tenth of it is no drop.
		local scale = 0
		for _, s in ipairs(series) do
			for _, p in ipairs(s.points) do
				scale = mathMax(scale, p[2])
			end
		end
		local cross = want.crossing and CROSSING[statKey]
		for si, s in ipairs(series) do
			local u = plotted[si]
			local pts = s.points
			local n = #pts
			if u and isMarked[u.key] and n > 1 then
				if want.peak and n > 2 then
					---@type number, integer
					local best, at = -mathHuge, 1
					for i = 1, n do
						if pts[i][2] > best then
							best, at = pts[i][2], i
						end
					end
					local last = pts[n][2]
					if best > 0 and at < n - 1 and last <= best * 0.85 then
						mark(
							u,
							si,
							pts[at][1],
							"peak",
							ctx.i18n("ui.teamStats.mark.peak", {
								value = valueText(column, pts[at][3] or best),
								now = valueText(column, pts[n][3] or last),
							})
						)
					end
				end
				if want.drop then
					---@type number, integer?, integer?
					local fall, from, to = 0, nil, nil
					for i = 1, n - 1 do
						local v = pts[i][2]
						for j = i + 1, mathMin(n, i + 3) do
							if v - pts[j][2] > fall then
								fall, from, to = v - pts[j][2], i, j
							end
						end
					end
					if from and to and fall >= pts[from][2] * 0.3 and fall >= scale * 0.1 then
						mark(
							u,
							si,
							pts[to][1],
							"drop",
							ctx.i18n("ui.teamStats.mark.drop", {
								from = valueText(column, pts[from][3] or pts[from][2]),
								to = valueText(column, pts[to][3] or pts[to][2]),
								since = Graph.frameLabel(pts[from][1]),
							})
						)
					end
				end
				if cross then
					-- Past the mark by a twentieth of it either way, so a line along it does
					-- not cross it at every sample.
					local margin = cross.at * 0.05
					if margin < 1 then
						margin = 1
					end
					---@type integer?
					local state = nil
					---@type { i: integer, up: boolean }[]
					local found = {}
					for i = 1, n do
						local v = pts[i][3] or pts[i][2]
						local now = (v >= cross.at + margin and 1) or (v <= cross.at - margin and -1) or nil
						if now then
							if state and now ~= state then
								found[#found + 1] = { i = i, up = now > 0 }
							end
							state = now
						end
					end
					for k = mathMax(1, #found - MAX_CROSSINGS + 1), #found do
						local c = found[k]
						---@cast c -?
						-- Back to the samples either side of the mark, and between them.
						local j = c.i
						while j > 1 do
							local before = pts[j - 1][3] or pts[j - 1][2]
							if (c.up and before < cross.at) or (not c.up and before > cross.at) then
								break
							end
							j = j - 1
						end
						local p1 = pts[j]
						---@cast p1 -?
						local x = p1[1]
						if j > 1 then
							local p0 = pts[j - 1]
							---@cast p0 -?
							local v0, v1 = p0[3] or p0[2], p1[3] or p1[2]
							if v1 ~= v0 then
								x = p0[1] + (cross.at - v0) / (v1 - v0) * (p1[1] - p0[1])
							end
						end
						mark(
							u,
							si,
							x,
							"crossing",
							ctx.i18n("ui.teamStats.mark." .. (c.up and cross.up or cross.down)),
							cross.at
						)
					end
				end
			end
		end
		if want.lead and #series > 1 then
			-- Every line by frame, over the frames of the longest.
			---@type table<integer, table<number, number?>>, table[]
			local byFrame, frames = {}, {}
			for si, s in ipairs(series) do
				local map = {}
				for _, p in ipairs(s.points) do
					map[p[1]] = p[2]
				end
				byFrame[si] = map
				if #s.points > #frames then
					frames = s.points
				end
			end
			---@type integer?, integer?, integer, integer
			local leader, candidate, since, count = nil, nil, 1, 0
			---@type { at: number, y: number?, from: integer, to: integer }[]
			local changes = {}
			-- Where the one taking the lead really passed the other: back to the samples either
			-- side of it, and between them.
			---@param k integer
			---@return number
			local function frameAt(k)
				local p = frames[k]
				---@cast p -?
				return p[1]
			end
			---@param from integer
			---@param to integer
			---@param idx integer
			local function passed(from, to, idx)
				local a, b = byFrame[from], byFrame[to]
				---@cast a -?
				---@cast b -?
				-- Lines of steps pass where they step.
				local s = series[to]
				if s and s.step then
					local f = frameAt(idx)
					return f, b[f]
				end
				local j = idx
				while j > 1 do
					local f = frameAt(j - 1)
					local va, vb = a[f], b[f]
					if not (va and vb) or vb <= va then
						break
					end
					j = j - 1
				end
				local f1 = frameAt(j)
				local a1, b1 = a[f1], b[f1]
				if j < 2 then
					return f1, b1
				end
				local f0 = frameAt(j - 1)
				local a0, b0 = a[f0], b[f0]
				if not (a0 and b0 and a1 and b1) then
					return f1, b1
				end
				local d0, d1 = b0 - a0, b1 - a1
				local t = d1 ~= d0 and -d0 / (d1 - d0) or 1
				return f0 + t * (f1 - f0), b0 + t * (b1 - b0)
			end
			for idx, p in ipairs(frames) do
				---@type integer?, number, number
				local top, topV, second = nil, -mathHuge, -mathHuge
				for si = 1, #series do
					local v = byFrame[si][p[1]]
					if v then
						if v > topV then
							top, topV, second = si, v, topV
						elseif v > second then
							second = v
						end
					end
				end
				-- Ahead of another by a margin: a lead; a tie or a race of one is none.
				if top and second > -mathHuge and topV > 0 and topV - second >= topV * LEAD_MARGIN then
					if not leader then
						leader = top
					elseif top == leader then
						candidate = nil
					else
						if candidate ~= top then
							candidate, since, count = top, idx, 0
						end
						count = count + 1
						if count >= 2 then
							local x, v = passed(leader, top, since)
							changes[#changes + 1] = { at = x, y = v, from = leader, to = top }
							leader, candidate = top, nil
						end
					end
				else
					candidate = nil
				end
			end
			-- The latest, and only the picked units' while some are picked.
			local shown = 0
			for i = #changes, 1, -1 do
				local c = changes[i]
				---@cast c -?
				local to, from = plotted[c.to], plotted[c.from]
				if to and from and (isMarked[to.key] or isMarked[from.key]) and shown < MAX_LEADS then
					shown = shown + 1
					mark(
						to,
						c.to,
						c.at,
						"lead",
						ctx.i18n("ui.teamStats.mark.lead", { name = tint(from.color) .. from.name .. ctx.colors.title }),
						c.y
					)
				end
			end
		end
		return markers
	end

	-- The stretches along a chart's edges, for the players of the units `marked`: without
	-- energy along the bottom (`dry`), the storage of the chart's resource full along the top
	-- (`full`) past the opening, a row per player. A sample is in a stretch when its period was
	-- that way a fifth of the time or more.
	local function spansOf(statKey, column, marked, off)
		local spans = {}
		---@type table<string, boolean>
		local kinds = {}
		for _, kind in ipairs(marksOf(statKey)) do
			if SPAN_MARKS[kind] and not off[kind] then
				kinds[kind] = true
			end
		end
		if not next(kinds) then
			return spans
		end
		local fullKey = (column and column.group == "energy") and "energyFull" or "metalFull"
		local rows = { bottom = 0, top = 0 }
		-- The samples after `after` only.
		local function stretches(team, key, edge, after)
			local g = page.gadget[team.id]
			local run = g and g.values[key]
			if not run then
				return
			end
			local frames = g.frames
			local label = ctx.i18n("ui.teamStats.mark." .. key)
			---@type integer?
			local row = nil
			local function within(i)
				return frames[i] > after and (run[i] or 0) >= SPAN_SHARE
			end
			local i, n = 1, #frames
			while i <= n do
				if within(i) then
					local j, sum = i, 0
					while j <= n and within(j) do
						sum = sum + run[j]
						j = j + 1
					end
					if not row then
						rows[edge] = rows[edge] + 1
						row = rows[edge]
					end
					local from, to = frames[i] - PERIOD, frames[j - 1]
					if from < 0 then
						from = 0
					end
					spans[#spans + 1] = {
						from = from,
						to = to,
						row = row,
						edge = edge,
						color = { team.accent[1], team.accent[2], team.accent[3], 0.85 },
						text = (team.nameColor or "") .. team.name .. "\n" .. ctx.colors.title .. Graph.frameLabel(
							from
						) .. " - " .. Graph.frameLabel(to) .. "  " .. label .. ctx.colors.dim .. "  " .. ctx.i18n(
							"ui.teamStats.mark.ofTheTime",
							{ share = percentFormat(sum / (j - i)) }
						),
					}
					i = j
				else
					i = i + 1
				end
			end
		end
		for _, u in ipairs(marked) do
			for _, team in ipairs(u.teams) do
				if kinds.dry then
					stretches(team, "energyDry", "bottom", -1)
				end
				if kinds.full then
					stretches(team, fullKey, "top", OPENING)
				end
			end
		end
		return spans
	end

	-- The unit report card's rows: each unit type of these units' players with their records
	-- added up - how many were built and their value, how many an enemy killed and theirs,
	-- the value they destroyed and the damage they dealt - the ones that fought or were built
	-- to, the most destroyed first. The bar is the value destroyed, the thin one under it the
	-- value built; the number after them says how many times over a type paid for itself.
	local function reportRows(of)
		local byDef = {}
		for _, u in ipairs(of) do
			for _, teamID in ipairs(u.members) do
				for defID, r in pairs(page.typeStats[teamID] or {}) do
					local sum = byDef[defID]
					if not sum then
						sum = { built = 0, builtValue = 0, lost = 0, lostValue = 0, killed = 0, damage = 0 }
						byDef[defID] = sum
					end
					for field, v in pairs(sum) do
						sum[field] = v + (r[field] or 0)
					end
				end
			end
		end
		---@type { defID: integer, s: table, ud: table }[]
		local list = {}
		for defID, s in pairs(byDef) do
			local ud = UnitDefs[defID]
			local armed = ud and ud.weapons and #ud.weapons > 0 and not ud.isBuilder
			if ud and (s.killed > 0 or s.damage > 0 or (armed and s.builtValue > 0)) then
				list[#list + 1] = { defID = defID, s = s, ud = ud }
			end
		end
		tableSort(list, function(a, b)
			local x, y = a.s, b.s
			if x.killed ~= y.killed then
				return x.killed > y.killed
			elseif x.damage ~= y.damage then
				return x.damage > y.damage
			elseif x.builtValue ~= y.builtValue then
				return x.builtValue > y.builtValue
			end
			return a.defID < b.defID
		end)
		local color = #of == 1 and of[1].color or REPORT_COLOR
		local title, dim = ctx.colors.title, ctx.colors.dim
		local rows = {}
		for i = 1, mathMin(#list, REPORT_ROWS) do
			local e = list[i]
			---@cast e -?
			local s, ud = e.s, e.ud
			local name = ud.translatedHumanName or ud.humanName or ud.name
			local valueText = siText(s.killed)
			local lines = { title .. name }
			if s.built > 0 then
				lines[#lines + 1] = dim
					.. ctx.i18n(
						"ui.teamStats.report.built",
						{ count = title .. siText(s.built) .. dim, value = title .. siText(s.builtValue) .. dim }
					)
			end
			if s.lost > 0 then
				lines[#lines + 1] = dim
					.. ctx.i18n(
						"ui.teamStats.report.lost",
						{ count = title .. siText(s.lost) .. dim, value = title .. siText(s.lostValue) .. dim }
					)
			end
			lines[#lines + 1] = dim
				.. ctx.i18n("ui.teamStats.report.killed", { value = title .. siText(s.killed) .. dim })
			-- How many times over it paid for itself, once it destroyed anything.
			if s.builtValue > 0 and s.killed > 0 then
				local paid = s.killed / s.builtValue
				-- Whole past ten, a tenth past one tenth, a hundredth below: a sliver still shows.
				local times
				if paid >= 10 then
					times = string.format("%d", mathFloor(paid + 0.5))
				elseif paid >= 0.1 then
					times = string.format("%.1f", paid)
				elseif paid >= 0.01 then
					times = string.format("%.2f", paid)
				else
					times = "<0.01"
				end
				valueText = valueText .. dim .. "  " .. times .. "\195\151"
				lines[#lines + 1] = dim .. ctx.i18n("ui.teamStats.report.paid", { times = title .. times .. dim })
			end
			if s.damage > 0 then
				lines[#lines + 1] = dim
					.. ctx.i18n("ui.teamStats.report.damage", { value = title .. siText(s.damage) .. dim })
			end
			rows[i] = {
				name = name,
				value = s.killed,
				sub = s.builtValue,
				color = color,
				texture = "#" .. e.defID,
				valueText = valueText,
				text = tableConcat(lines, "\n"),
			}
		end
		return rows, #list - #rows
	end

	-- What a chart of one stat is made of: the same rules for the big chart and for every
	-- small one in the grid. `small` leaves out what a little chart has no room for.
	-- Returns whether it came out empty.
	local function fillChart(target, key, small)
		local statKey, settings = statOf(key), settingsOf(key)
		local column = ctx.COLUMNS[statKey]
		local units = unitsFor(settings)
		local shown = shownUnits(units)
		local picked = pickedUnits(units)
		local anyPicked = #picked > 0
		-- Remove unselected leaves the rest off; otherwise the pick only stands out.
		---@type table[]
		local plotted = filtering() and picked or shown
		-- Something stands out only while the selection is not everything plotted.
		local lifts = anyPicked and #picked < #plotted
		local marked = anyPicked and picked or plotted
		local series, spans = {}, {}
		---@type table[]
		local markers = {}
		-- A small chart has no room for marks: none are worked out for it but the timeline's,
		-- which is made of them. How many pictures fit across a chart: its milestones are
		-- thinned to that.
		local marking = not small
		local room = (target.cfg.width or 600) * 0.8 / mathMax(8, mathFloor((target.cfg.fontSize or 12) * 2.6))
		local kind = "line"
		local title
		local yFormat = nil
		---@type table<integer, boolean>
		local lifted = {}
		local ownLegend = false

		lanes, timelineGap = {}, 0
		target.cfg.valueBands = nil
		-- Shares of a whole, unless a whole in its parts is set to pile its amounts up.
		target.cfg.stackShares = true
		target.cfg.rawFormat = nil
		if statKey == "timeline" then
			-- A lane per team, drawn from the first frame to now, with its milestones on
			-- it: what happened to whom, and when. Every team gets the same height, and
			-- pictures that fall close together are stacked into the room around the line
			-- rather than piled on one spot.
			local n = #plotted
			local frame = mathMax(1, ctx.frame())
			local indexByKey = {}
			for i, u in ipairs(plotted) do
				local lane = n - i + 1
				series[#series + 1] = {
					name = u.name,
					color = u.color,
					points = { { 0, lane }, { frame, lane } },
					width = 2,
				}
				indexByKey[u.key] = #series
				lanes[u.key] = lane
				lifted[#series] = isPicked(u)
			end
			-- A faint band of the team's colour behind each lane.
			local bands = {}
			for i, u in ipairs(plotted) do
				local lane = n - i + 1
				bands[#bands + 1] = {
					-- A little short of the next lane, so there is a gap between the teams.
					from = lane - 0.42,
					to = lane + 0.42,
					color = { u.color[1], u.color[2], u.color[3], 0.1 },
				}
			end
			target.cfg.valueBands = bands
			-- How far apart two pictures have to be in game frames not to overlap, from the
			-- room the chart has for the whole game.
			local plotW = page.rects and (page.rects.chart[3] - page.rects.chart[1]) * 0.8 or 600
			timelineGap = frame / mathMax(1, plotW / mathMax(8, mathFloor(ctx.metrics.rowFs * 2.6)))
			-- The lanes are named down the axis, and there is a clear row above and below.
			target.cfg.yMin, target.cfg.yMax, target.cfg.gridLines = 0, n + 1, n + 1
			yFormat = function(v)
				if small then
					-- No room beside a small chart: the bands say whose lane is whose.
					return ""
				end
				local u = plotted[n - mathFloor(v + 0.5) + 1]
				return u and u.name or ""
			end
			markers = milestoneMarkers(plotted, indexByKey, true, statKey, settings, room)
			title = ctx.i18n("ui.teamStats.graph.timeline")
		elseif statKey == "ranking" then
			-- A line per ally team through its places in the ranking, first at the top - the
			-- ranking is the ally teams', however the bar groups the players; an ally team of
			-- one is its player, by name - held from one sample to the next, with the score it
			-- was ranked by in the tooltip.
			---@type table[]
			local of = {}
			for _, u in ipairs(page.allyUnits or units) do
				local only = #u.teams == 1 and page.unitByKey["team" .. u.teams[1].id]
				of[#of + 1] = only or u
			end
			local shownA, pickedA = shownUnits(of), pickedUnits(of)
			local plottedA = filtering() and pickedA or shownA
			local markedA = #pickedA > 0 and pickedA or plottedA
			-- A place is every one of the ally team's teams' alike: read off the one with the
			-- longest history, the score taken once.
			local function placeRun(u)
				---@type integer, integer
				local best, most = u.members[1], -1
				for _, teamID in ipairs(u.members) do
					local g = page.gadget[teamID]
					local n = g and #g.frames or 0
					if n > most then
						best, most = teamID, n
					end
				end
				return runOf({ best }, "allyRank", false)
			end
			-- How many places there are: every ally team's, drawn or not.
			local places = 0
			for _, u in ipairs(of) do
				for _, place in ipairs(placeRun(u).ys) do
					places = mathMax(places, place)
				end
			end
			local indexByKey = {}
			for _, u in ipairs(plottedA) do
				local run = placeRun(u)
				local scoreRun = runOf(u.members, "allyScore", false)
				local scoreAt = {}
				for i, x in ipairs(scoreRun.xs) do
					scoreAt[x] = scoreRun.ys[i]
				end
				local points = {}
				for i, x in ipairs(run.xs) do
					local place = run.ys[i]
					if place and place >= 1 then
						points[#points + 1] = { x, places + 1 - place, scoreAt[x] }
					end
				end
				series[#series + 1] = { name = u.name, color = u.color, points = points, width = 2, step = true }
				indexByKey[u.key] = #series
				lifted[#series] = isPicked(u)
			end
			lifts = #pickedA > 0 and #pickedA < #plottedA
			target.cfg.yMin, target.cfg.yMax, target.cfg.gridLines = 0, places + 1, places + 1
			yFormat = function(v)
				local at = mathFloor(v + 0.5)
				local place = places + 1 - at
				if mathAbs(v - at) > 0.01 or place < 1 or place > places then
					return ""
				end
				return "#" .. place
			end
			target.cfg.rawFormat = function(v)
				return valueText(nil, v)
			end
			if marking then
				markers = milestoneMarkers(markedA, indexByKey, false, statKey, settings, room)
				if settings.milestones then
					append(markers, lineMarkers(statKey, nil, series, plottedA, markedA, settings.off))
				end
			end
			title = ctx.i18n("ui.teamStats.graph.ranking")
		elseif statKey == "profile" then
			kind = "radar"
			ownLegend = true
			local axes = {}
			for _, axis in ipairs(PROFILE_AXES) do
				if ctx.gadgetOn() or not axis.gadget then
					-- The full caption: three axes are called "produced" on their own.
					axes[#axes + 1] = { key = axis.key, label = ctx.columnTitle(ctx.COLUMNS[axis.key]) }
				end
			end
			page.profileAxes = axes
			-- Every axis is measured against the best shown team, drawn or not: a wheel of
			-- one team measured against itself would be full on every axis.
			for _, u in ipairs(shown) do
				for ai, v in ipairs(profileValues(u)) do
					axes[ai].max = mathMax(axes[ai].max or 0, v)
				end
			end
			for _, axis in ipairs(axes) do
				if not axis.max or axis.max <= 0 then
					axis.max = nil
				end
			end
			for _, u in ipairs(plotted) do
				series[#series + 1] = { name = u.name, color = u.color, values = profileValues(u), width = 2 }
				lifted[#series] = isPicked(u)
			end
			-- The axis names need room; a small wheel is read by its shape.
			target:configure({ radar = { axes = axes, rings = 4, fill = true, labels = not small } })
			title = ctx.i18n("ui.teamStats.graph.profile")
		elseif statKey == "composition" then
			kind = "stacked"
			ownLegend = true
			local of = anyPicked and picked or shown
			local members = {}
			for _, u in ipairs(of) do
				for _, teamID in ipairs(u.members) do
					members[#members + 1] = teamID
				end
			end
			local group = ctx.groupByKey.composition
			local bi = 0
			for i = 1, #group.columns do
				local c = ctx.COLUMNS[group.columns[i]]
				-- The buckets, not the total that heads the view.
				if c.count and c.group == "value" then
					bi = bi + 1
					series[#series + 1] = {
						name = ctx.L.full[c.key],
						color = BUCKET_COLORS[bi] or { 0.8, 0.8, 0.8 },
						points = pointsOf(members, c.key, false),
					}
				end
			end
			lifts = false
			-- The amounts piled up, or with % of total each bucket's share of the whole.
			target.cfg.stackShares = settings.share == true
			title = ctx.i18n("ui.teamStats.graph.composition") .. " \194\183 " .. namesOf(of)
			if settings.share then
				title = title .. " \194\183 " .. ctx.L.switch.shareOfTotal
			end
			markers = marking and milestoneMarkers(of, nil, false, statKey, settings, room) or {}
		elseif PARTS[statKey] then
			-- One whole of the picked teams - every shown team's without a pick - in its
			-- parts: each one's share of it over the game.
			local parts = PARTS[statKey]
			kind = "stacked"
			ownLegend = true
			local of = anyPicked and picked or shown
			local members = {}
			for _, u in ipairs(of) do
				for _, teamID in ipairs(u.members) do
					members[#members + 1] = teamID
				end
			end
			for i, key in ipairs(parts.keys) do
				local points = pointsOf(members, key, false)
				local any = not parts.dropEmpty
				for j = 1, #points do
					if any then
						break
					end
					any = points[j][2] ~= 0
				end
				if any then
					local label = parts.labels and parts.labels[i] or key
					series[#series + 1] =
						{ name = ctx.i18n(parts.names .. label), color = parts.colors[i], points = points }
				end
			end
			lifts = false
			target.cfg.stackShares = settings.share == true
			title = ctx.i18n("ui.teamStats.graph." .. statKey) .. " \194\183 " .. namesOf(of)
			if settings.share then
				title = title .. " \194\183 " .. ctx.L.switch.shareOfTotal
			end
			markers = marking and milestoneMarkers(of, nil, false, statKey, settings, room) or {}
		elseif statKey == "unitReport" then
			-- The picked teams' unit types - every shown team's without a pick - as a row
			-- each; the types past the room are counted under the last.
			kind = "bars"
			ownLegend = true
			page.askTypes()
			local of = anyPicked and picked or shown
			local rows, past = reportRows(of)
			series = rows
			lifts = false
			title = ctx.i18n("ui.teamStats.graph.unitReport") .. " \194\183 " .. namesOf(of)
			target.cfg.bars.legend = {
				{ name = ctx.i18n("ui.teamStats.killedValue"), color = #of == 1 and of[1].color or REPORT_COLOR },
				{ name = ctx.i18n("ui.teamStats.report.builtValue"), color = REPORT_BUILT },
			}
			target.cfg.bars.more = function(n)
				return ctx.i18n("ui.teamStats.report.more", { count = n + past })
			end
			-- The open card scrolls its rows with the wheel; one in the grid, where the wheel
			-- scrolls the grid, counts the rest.
			target.cfg.bars.scroll = not small
			target.cfg.bars.key = key
		elseif statKey == "lavaLevel" then
			-- The lava's height, which every team's sample carries: one line off the first team
			-- with samples, as the wind's.
			local points = {}
			for _, ally in ipairs(ctx.allies()) do
				for _, team in ipairs(ally.teams) do
					local g = page.gadget[team.id]
					local level = g and g.values.lavaLevel
					if #points == 0 and level then
						for i, frame in ipairs(g.frames) do
							if level[i] then
								points[#points + 1] = { frame, level[i] }
							end
						end
					end
				end
			end
			series =
				{ { name = ctx.i18n("ui.teamStats.graph.lavaLevel"), color = LAVA_COLOR, points = points, width = 2 } }
			lifts = false
			title = ctx.i18n("ui.teamStats.graph.lavaLevel")
		elseif statKey == "wind" then
			-- The wind, which every team's sample carries: one line off the first team with
			-- samples, over a faint band of the range the map's wind keeps to. The sample at
			-- the first frame is taken before the engine has blown any.
			local points = {}
			for _, ally in ipairs(ctx.allies()) do
				for _, team in ipairs(ally.teams) do
					local g = page.gadget[team.id]
					local wind = g and g.values.windSpeed
					if #points == 0 and wind then
						for i, frame in ipairs(g.frames) do
							if frame > 0 and wind[i] then
								points[#points + 1] = { frame, wind[i] }
							end
						end
					end
				end
			end
			series = { { name = ctx.i18n("ui.teamStats.graph.wind"), color = WIND_COLOR, points = points, width = 2 } }
			local low, high = Game and Game.windMin or 0, Game and Game.windMax or 0
			if high > low then
				target.cfg.valueBands =
					{ { from = low, to = high, color = { WIND_COLOR[1], WIND_COLOR[2], WIND_COLOR[3], 0.06 } } }
			end
			lifts = false
			title = ctx.i18n("ui.teamStats.graph.wind")
		elseif column and settings.share and column.fmt == "si" and #plotted > 1 then
			-- Everything on the chart as one whole, each unit its share of it: ally teams
			-- against each other while grouped, players otherwise. One unit alone would be
			-- all of it, so it keeps its line.
			kind = "stacked"
			for _, u in ipairs(plotted) do
				series[#series + 1] = {
					name = u.name,
					color = u.color,
					points = pointsOf(u.members, column.key, false),
				}
				lifted[#series] = isPicked(u)
			end
			title = ctx.columnTitle(column) .. " \194\183 " .. ctx.L.switch.shareOfTotal
			if marking then
				markers = milestoneMarkers(marked, nil, false, statKey, settings, room)
				spans = settings.milestones and spansOf(statKey, column, marked, settings.off) or {}
			end
		elseif column then
			local indexByKey = {}
			series, lifted = lineSeries(column, plotted)
			for i, u in ipairs(plotted) do
				indexByKey[u.key] = i
			end
			title = ctx.columnTitle(column)
			-- % of total set with one team or player on the chart, all of its own total: the
			-- line stays, and the title still says what is set, faded, rather than dropping it.
			if settings.share and column.fmt == "si" then
				title = title .. ctx.colors.faded .. " \194\183 " .. ctx.L.switch.shareOfTotal
			end
			if column.fmt == "percent" then
				yFormat = percentFormat
			end
			markers = marking and milestoneMarkers(marked, indexByKey, false, statKey, settings, room) or {}
			-- And what the lines themselves make, and the stretches along the edges.
			if marking and settings.milestones then
				append(markers, lineMarkers(statKey, column, series, plotted, marked, settings.off))
				spans = spansOf(statKey, column, marked, settings.off)
			end
		end

		local empty = true
		for _, s in ipairs(series) do
			-- A run over time carries points; the profile's wheel carries a value per axis, a
			-- row of bars its value.
			if s.value or #(s.points or s.values or {}) > 0 then
				empty = false
			end
		end
		-- The bands of the composition chart are named by the chart itself; teams are
		-- named by the legend bar. The axis format is set straight: a nil handed to
		-- configure would leave the last one.
		if statKey ~= "timeline" and statKey ~= "ranking" then
			target.cfg.yMin, target.cfg.yMax, target.cfg.gridLines = nil, nil, small and 2 or 4
		end
		-- Every chart over time runs from the start of the game, whenever its own samples
		-- begin, so they can be read against each other.
		target.cfg.xMin = 0
		target.cfg.yFormat = yFormat
		target:configure({
			kind = kind,
			title = title,
			legend = ownLegend and not small,
			-- A stacked chart names its bands inside them; a chart of lines names them at
			-- their ends. A small chart has room for neither, the timeline its lanes' names.
			bandLabels = kind == "stacked" and not small,
			endLabels = kind == "line" and not small and #series > 1 and statKey ~= "timeline",
			xTicks = small and 2 or 5,
			totalLabel = ctx.i18n("ui.teamStats.graph.total"),
		})
		-- The badges on the pictures, named once at the right of the title row, clear of Add
		-- to...; a small chart has no room for the names.
		---@type table<string, boolean>
		local present = {}
		for _, m in ipairs(markers) do
			if m.badgeKey then
				present[m.badgeKey] = true
			end
		end
		local badgeLegend = {}
		for _, badgeKey in ipairs(small and {} or BADGE_ORDER) do
			if present[badgeKey] then
				badgeLegend[#badgeLegend + 1] =
					{ badge = BADGES[badgeKey], name = ctx.i18n("ui.teamStats.graph.badge." .. badgeKey) }
			end
		end
		local addTo = not small and page.addToRect()
		target.cfg.markerLegend = badgeLegend
		target.cfg.titleInset = addTo and (addTo[3] - addTo[1] + mathFloor(8 * page.scale)) or 0
		target:setSeries(series)
		target:setMarkers(markers)
		target:setSpans(spans)
		target:setHighlight(lifts and lifted or nil)
		return empty
	end

	-- Whether the page is showing a grid of charts rather than one: more than one per page
	-- and none opened on its own.
	function page.gridded()
		return page.zoom == nil
	end

	-- The next grid in the list, or the one before it, wrapping round either way; the
	-- scroll goes back to the top.
	function page.cyclePerPage(back)
		local at = 1
		for i, spec in ipairs(PAGES) do
			if spec.n == page.perPage then
				at = i
			end
		end
		local step = back and -1 or 1
		local next_ = PAGES[(at - 1 + step) % #PAGES + 1]
		---@cast next_ -?
		page.perPage = next_.n
		page.scroll, page.zoom = 0, nil
		page.dirty = true
		page.gen = page.gen + 1
	end

	-- The grid a page is drawn in: the setting's, or the smallest that holds every chart of
	-- the category - never smaller than the first, so two charts are not drawn huge.
	local function pageSpec()
		local count = 0
		for _, entry in ipairs(page.statList or {}) do
			if entry.key and not entry.back and not entry.divider then
				count = count + 1
			end
		end
		local chosen = PAGES[1]
		for _, spec in ipairs(PAGES) do
			if spec.n <= page.perPage then
				chosen = spec
				if spec.n >= count then
					break
				end
			end
		end
		return chosen
	end

	-- The grid's cells, left to right and top to bottom over the chart's room.
	local function gridCells(spec)
		local r = page.rects
		---@type [number, number, number, number][]
		local cells = {}
		if not r then
			return cells
		end
		local x1, y1, x2, y2 = r.chart[1], r.chart[2], r.chart[3], r.chart[4]
		local gap = mathFloor(8 * page.scale)
		local w = mathFloor(((x2 - x1) - gap * (spec.cols - 1)) / spec.cols)
		local h = mathFloor(((y2 - y1) - gap * (spec.rows - 1)) / spec.rows)
		for i = 1, spec.cols * spec.rows do
			local col = (i - 1) % spec.cols
			local row = mathFloor((i - 1) / spec.cols)
			local cx = x1 + col * (w + gap)
			local cy = y2 - (row + 1) * h - row * gap
			cells[i] = { cx, cy, cx + w, cy + h }
		end
		return cells
	end

	-- A slot of the grid filled with its stat, for the histories as they are.
	local function fillMini(mini)
		local chartOf = mini.chart
		fillChart(chartOf, mini.key, true)
		-- A column's chart says itself whether its % of total is on it; the others take
		-- their short name from the list.
		local setup = { font = ctx.font(), fontSize = mini.fs, nameFont = ctx.nameFont() }
		if not ctx.COLUMNS[statOf(mini.key)] then
			setup.title = mini.label
		end
		chartOf:configure(setup)
		mini.version = page.version
	end

	-- The charts of the page the grid is scrolled to, built into the pool.
	function page.buildGrid()
		local spec = pageSpec()
		---@type table[]
		local list = {}
		for _, entry in ipairs(page.statList) do
			if entry.key and not entry.back and not entry.divider then
				list[#list + 1] = entry
			end
		end
		local cells = gridCells(spec)
		local rows = math.ceil(#list / spec.cols)
		page.maxScroll = mathMax(0, rows - spec.rows)
		page.scroll = mathMax(0, mathMin(page.scroll, page.maxScroll))
		local first = page.scroll * spec.cols + 1
		local last = mathMin(#list, first + spec.cols * spec.rows - 1)
		local fs = mathMax(8, mathFloor(ctx.metrics.rowFs * (spec.cols > 3 and 0.8 or 0.9)))
		page.miniCharts = {}
		for i = first, last do
			local entry = list[i]
			---@cast entry -?
			local slot = i - first + 1
			local cell = cells[slot]
			---@cast cell -?
			local chartOf = pool[slot]
			if not chartOf then
				chartOf = Graph.new({
					kind = "line",
					legend = false,
					xUnit = "frames",
					lineWidth = 2,
					includeZero = true,
					reuseHits = true,
					look = { plotFill = { 0, 0, 0, 0.16 } },
				})
				pool[slot] = chartOf
			end
			chartOf:setBounds(cell[1], cell[2], cell[3] - cell[1], cell[4] - cell[2])
			local mini = { chart = chartOf, key = entry.key, rect = cell, index = i, label = entry.label, fs = fs }
			fillMini(mini)
			page.miniCharts[slot] = mini
		end
		page.first, page.last = first, last
	end

	-- The histories grew and nothing else changed: the charts are filled again a few a
	-- frame - the open one at once - rather than the whole page in one.
	function page.catchUp()
		page.anySamples = anySamples()
		if not page.gridded() then
			local empty = fillChart(chart, page.zoom or page.stat)
			if empty ~= page.empty then
				page.empty = empty
				page.gen = page.gen + 1
			end
			page.stale = false
			return
		end
		local budget = CATCH_UP_PER_FRAME
		for _, mini in ipairs(page.miniCharts or {}) do
			if mini.version ~= page.version then
				if budget == 0 then
					return
				end
				fillMini(mini)
				budget = budget - 1
			end
		end
		page.stale = false
	end

	function page.scrollExtent()
		local spec = pageSpec()
		local r = page.rects
		if not page.gridded() or not r or page.maxScroll <= 0 then
			return 0, 0, 0
		end
		local rowH = (r.chart[4] - r.chart[2]) / spec.rows
		return (page.maxScroll + spec.rows) * rowH, page.scroll * rowH, rowH
	end

	-- The bar dragged to an offset in pixels: the nearest row of the grid.
	function page.setScrollPixels(offset)
		local _, _, rowH = page.scrollExtent()
		if rowH <= 0 then
			return
		end
		local to = mathMax(0, mathMin(page.maxScroll, mathFloor(offset / rowH + 0.5)))
		if to ~= page.scroll then
			page.scroll = to
			page.dirty = true
			page.gen = page.gen + 1
		end
	end

	function page.build()
		-- The list takes room from the charts, so opening or closing one lays the page out
		-- again before anything is drawn.
		local args = page.layoutArgs
		if args and page.listWas ~= page.listShown() then
			page.setLayout(args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
		end
		page.anySamples = anySamples()
		page.rebuildUnits()
		if page.gridded() then
			page.buildGrid()
			page.empty = #page.statList == 0
		else
			page.empty = fillChart(chart, page.zoom or page.stat)
		end
		page.dirty, page.stale = false, false
	end

	----------------------------------------------------------------
	-- Drawing
	----------------------------------------------------------------

	-- Four whole-pixel bars around a rect.
	local function frame(x1, y1, x2, y2, w, color)
		local Color, Rect = ctx.draw.Color, ctx.draw.Rect
		Color(color[1], color[2], color[3], color[4])
		Rect(x1, y1, x2, y1 + w)
		Rect(x1, y2 - w, x2, y2)
		Rect(x1, y1, x1 + w, y2)
		Rect(x2 - w, y1, x2, y2)
	end

	-- Whether a block of the bar is lit: All while nothing is selected; an ally team's
	-- while it is selected, or every one of its players is.
	local function blockLit(b)
		if b.all then
			return #pickedUnits() == 0
		end
		if b.me then
			local picked = pickedUnits()
			return #picked == 1 and picked[1] == b.unit and allPicked(b.unit)
		end
		if #b.members == 0 then
			return false
		end
		for _, m in ipairs(b.members) do
			if not teamIn(page.selected, m.team) or teamIn(page.hidden, m.team) then
				return false
			end
		end
		return true
	end

	-- What is baked into the panel's list: the stat list on a card like the sidebar's,
	-- and the legend bar.
	function page.drawPanel()
		local r = page.rects
		if not r then
			return
		end
		local look, colors, metrics = ctx.look, ctx.colors, ctx.metrics
		local RectRound, Highlight, Color, Rect = ctx.draw.RectRound, ctx.draw.Highlight, ctx.draw.Color, ctx.draw.Rect
		local fs = metrics.catFs
		local cs = metrics.csSmall

		-- The card and its stats, while the page is showing one chart; a grid names its
		-- charts itself and takes the room instead.
		if page.listShown() then
			RectRound(
				r.list[1],
				r.list[2],
				r.list[3],
				r.list[4],
				metrics.csPanel,
				1,
				1,
				1,
				1,
				look.sidebarFill,
				look.sidebarFillTop
			)
		end
		for i, entry in ipairs(page.listShown() and page.statList or {}) do
			local x1, y1, x2, y2 = statRect(i)
			if entry.divider then
				local y = mathFloor((y1 + y2) * 0.5)
				RectRound(x1 + metrics.sidePad, y, x2 - metrics.sidePad, y + 1, 0, 0, 0, 0, 0, look.rule)
			else
				-- The way back to the grid is never the pick; it is where the pick came from.
				local selected = not entry.back and entry.key == (page.zoom or page.stat)
				if selected then
					RectRound(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2, cs, 1, 1, 1, 1, look.selectedFill)
				elseif i == page.hover.stat then
					Highlight(
						x1 + metrics.catInset,
						y1,
						x2 - metrics.catInset,
						y2,
						cs,
						look.rowHoverOpacity,
						look.white
					)
				end
				local label = ctx.text.fit(ctx.font(), entry.label, x2 - x1 - metrics.sidePad * 2, fs)
				ctx.queueText(
					(selected and colors.selected or colors.dim) .. label,
					x1 + metrics.sidePad,
					mathFloor((y1 + y2) * 0.5),
					fs,
					"ov"
				)
			end
		end

		-- The legend bar: a plate per block like a button, lit and framed warm when it is
		-- selected as a whole, then its caption and squares. A selected square stands at
		-- full strength inside a warm frame (neighbours share one), the others fade while
		-- anything is selected, and a hidden one is only an outline.
		local isGrouped = grouped()
		local anyPicked = #pickedUnits() > 0
		local dropping = filtering()
		local cy = mathFloor((r.bar[2] + r.bar[4]) * 0.5)
		local py1, py2 = r.bar[2] + r.inset, r.bar[4] - r.inset
		local fw = r.frame
		for i, b in ipairs(page.barBlocks) do
			local lit = blockLit(b)
			b.lit = lit
			RectRound(b.x1, py1, b.x2, py2, cs, 1, 1, 1, 1, lit and look.selectedFill or PLATE)
			if lit then
				-- A frame that follows the plate's corners.
				ctx.draw.RectRoundOutline(b.x1, py1, b.x2, py2, cs, fw, 1, 1, 1, 1, PICKED_FRAME, PICKED_FRAME)
			end
			-- Without the grouping a square is its player, so the plate lights only for its
			-- caption, which stands for the whole ally team. A lit plate lights further.
			if i == page.hover.block and (isGrouped or b.all or page.hover.legend == 0) then
				Highlight(b.x1, py1, b.x2, py2, cs, look.barHoverOpacity, look.white)
			end
			if b.labelX then
				ctx.queueText(
					(lit and colors.selected or colors.dim) .. (b.caption or b.label),
					b.labelX,
					cy,
					fs,
					"ov",
					b.named and not b.caption and "name" or nil
				)
			end
			if b.swatch and b.unit then
				local c = b.unit.color
				Color(c[1], c[2], c[3], (lit or i == page.hover.block) and 1 or 0.85)
				Rect(b.swatch[1], b.swatch[2], b.swatch[3], b.swatch[4])
			end
		end
		-- What a press would act on: the square under the cursor, or every square of the
		-- block while grouped or on its caption.
		local hoverBlock = page.barBlocks[page.hover.block]
		for i, item in ipairs(page.barItems) do
			local c = item.team.accent
			local picked, hidden = isPicked(item.unit), isHidden(item.unit)
			local hovered = i == page.hover.legend
				or (hoverBlock ~= nil and item.block == hoverBlock and (isGrouped or page.hover.legend == 0))
			item.hovered = hovered
			-- Hidden, or left off by Remove unselected: either way not on the chart.
			if hidden or (dropping and not picked) then
				Color(c[1], c[2], c[3], hovered and 0.4 or 0.12)
				Rect(item.x1, item.y1, item.x2, item.y2)
				frame(item.x1, item.y1, item.x2, item.y2, 1, { c[1], c[2], c[3], 0.55 })
			else
				local alpha = (anyPicked and not picked) and 0.3 or 0.9
				Color(c[1], c[2], c[3], hovered and 1 or alpha)
				Rect(item.x1, item.y1, item.x2, item.y2)
			end
		end
		-- Remove unselected at the end of the bar, captioned like a settings row.
		local tog = filterToggleRect()
		if tog then
			local label = ctx.i18n("ui.teamStats.graph.hideUnselected")
			local hovered = page.hover.filter == 1
			ctx.queueText(
				(page.hideUnselected and colors.selected or colors.dim) .. label,
				tog[1] - metrics.rowPad,
				cy,
				fs,
				"rov"
			)
			ctx.draw.Toggle(tog[1], tog[2], tog[3], tog[4], page.hideUnselected, hovered)
		end

		if not isGrouped then
			---@type table?, table?
			local first, last = nil, nil
			local function frameRun()
				if first and last then
					frame(first.x1 - fw, page.barY1 - fw, last.x2 + fw, page.barY2 + fw, fw, PICKED_FRAME)
				end
				first, last = nil, nil
			end
			for _, item in ipairs(page.barItems) do
				local on = isPicked(item.unit) and not isHidden(item.unit) and not item.block.lit
				if on and first and first.block == item.block then
					last = item
				else
					frameRun()
					if on then
						first, last = item, item
					end
				end
			end
			frameRun()
		end
		-- The squares a press would act on, framed white round each run of them in a block,
		-- over a pick's warm frame; the You button's swatch the same.
		do
			---@type table?, table?
			local first, last = nil, nil
			local function frameRun()
				if first and last then
					frame(first.x1 - fw, page.barY1 - fw, last.x2 + fw, page.barY2 + fw, fw, HOVER_FRAME)
				end
				first, last = nil, nil
			end
			for _, item in ipairs(page.barItems) do
				if item.hovered and first and first.block == item.block then
					last = item
				else
					frameRun()
					if item.hovered then
						first, last = item, item
					end
				end
			end
			frameRun()
			local b = hoverBlock
			if b and b.swatch then
				frame(b.swatch[1] - fw, b.swatch[2] - fw, b.swatch[3] + fw, b.swatch[4] + fw, fw, HOVER_FRAME)
			end
		end
		Color(1, 1, 1, 1)

		local group = ctx.groupByKey[ctx.selectedGroup()]
		if group and group.custom and #group.graphs == 0 then
			-- A category of the player's own with nothing in it yet: how to fill it.
			local c = r.chart
			ctx.queueText(
				colors.dim .. ctx.i18n("ui.teamStats.custom.empty"),
				mathFloor((c[1] + c[3]) * 0.5),
				mathFloor((c[2] + c[4]) * 0.5),
				fs,
				"ovc"
			)
		elseif page.empty and not page.gridded() then
			local c = r.chart
			local key = page.anySamples and "ui.teamStats.graph.noData" or "ui.teamStats.graph.waiting"
			ctx.queueText(
				colors.dim .. ctx.i18n(key),
				mathFloor((c[1] + c[3]) * 0.5),
				mathFloor((c[2] + c[4]) * 0.5),
				fs,
				"ovc"
			)
		end
	end

	-- The card that picks which kinds of milestone go on the charts: a row per kind with a
	-- mark for the ones that are on, over the top left of the charts' room.
	function page.drawKinds()
		page.kindRects = {}
		if not page.kindsOpen or not page.rects then
			return
		end
		local look, metrics, colors = ctx.look, ctx.metrics, ctx.colors
		local RectRound, Highlight = ctx.draw.RectRound, ctx.draw.Highlight
		local kinds = milestoneKinds()
		-- The card is drawn after the charts rather than into the panel's baked list, so
		-- its text is printed here rather than queued for a batch that has been and gone.
		local texts = {}
		local fs = metrics.catFs
		local rowH = metrics.catRowHeight
		local w = mathFloor(264 * page.scale)
		-- Each kind as the chart shows it, before its name: a milestone's badge, a line mark's
		-- shape, a strip for a stretch, the skull for a team out of the game.
		local iconR = mathFloor(rowH * 0.25)
		local nameX = metrics.sidePad + iconR * 2 + mathFloor(8 * page.scale)
		-- Beside the settings row that opens it, on a backdrop solid enough to read over
		-- whatever it covers; it is drawn after the charts, so nothing lies over it.
		local anchor = page.kindsAnchor
		local gap = mathFloor(6 * page.scale)
		local x1 = anchor and anchor[3] + gap or page.rects.chart[1] + gap
		local h = rowH * (#kinds + 1) + metrics.cardLip * 2
		local y1 = anchor and mathMin(anchor[2], page.rects.chart[4] - h) or page.rects.chart[2]
		y1 = mathMax(y1, page.rects.chart[2])
		local y2 = y1 + h
		RectRound(x1, y1, x1 + w, y2, metrics.csPanel, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		texts[#texts + 1] = {
			colors.title .. ctx.i18n("ui.teamStats.switch.milestoneKinds"),
			x1 + metrics.sidePad,
			y2 - metrics.cardLip - mathFloor(rowH * 0.5),
		}
		for i, kind in ipairs(kinds) do
			local top = y2 - metrics.cardLip - i * rowH
			local rect = { x1, top - rowH, x1 + w, top }
			page.kindRects[i] = { key = kind, rect = rect }
			local on = not kindsOff()[kind]
			if i == page.hover.kind then
				Highlight(
					rect[1] + metrics.catInset,
					rect[2],
					rect[3] - metrics.catInset,
					rect[4],
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			local ix = rect[1] + metrics.sidePad + iconR
			local badgeKey = BADGE_OF[kind]
			if badgeKey then
				Graph.drawBadgeAt(BADGES[badgeKey], ix, cy, iconR)
			elseif LINE_MARKS[kind] then
				Graph.drawShapeAt(LINE_MARKS[kind], ix, cy, iconR * 0.8, KIND_GREY)
			elseif SPAN_MARKS[kind] then
				local stripH = mathMax(2, mathFloor(iconR * 0.5))
				gl.Color(KIND_GREY[1], KIND_GREY[2], KIND_GREY[3], 0.85)
				gl.Rect(ix - iconR, cy - stripH, ix + iconR, cy + stripH)
				gl.Color(1, 1, 1, 1)
			elseif kind == "teamDied" or kind == "teammateOut" then
				gl.Color(SKULL_BACKDROP[1], SKULL_BACKDROP[2], SKULL_BACKDROP[3], SKULL_BACKDROP[4])
				gl.Rect(ix - iconR, cy - iconR, ix + iconR, cy + iconR)
				gl.Color(1, 1, 1, 1)
				gl.Texture(SKULL)
				gl.TexRect(ix - iconR, cy - iconR, ix + iconR, cy + iconR)
				gl.Texture(false)
			end
			texts[#texts + 1] = {
				(on and colors.selected or colors.faded) .. markName(kind),
				rect[1] + nameX,
				cy,
			}
			-- The same switch the settings rows use, so it reads as one.
			local togW = mathFloor(38 * page.scale)
			local togH = mathFloor(rowH * 0.52)
			local tx = rect[3] - metrics.sidePad - togW
			ctx.draw.Toggle(
				tx,
				cy - mathFloor(togH * 0.5),
				tx + togW,
				cy - mathFloor(togH * 0.5) + togH,
				on,
				i == page.hover.kind
			)
		end
		-- One batch, with the outline pinned: the font is shared with every other widget.
		local font = ctx.font()
		if font then
			font:Begin()
			font:SetOutlineColor(look.outline or { 0, 0, 0, 0.4 })
			for _, t in ipairs(texts) do
				font:Print(t[1], t[2], t[3], fs, "ov")
			end
			font:End()
		end
	end

	----------------------------------------------------------------
	-- Custom categories: Add to..., the card of actions, naming
	----------------------------------------------------------------

	-- Text drawn after the panel's list is printed in a batch of its own, with the outline
	-- pinned: the font is shared with every other widget.
	local function printTexts(texts, fs)
		local font = ctx.font()
		if font then
			font:Begin()
			font:SetOutlineColor(ctx.look.outline or { 0, 0, 0, 0.4 })
			for _, t in ipairs(texts) do
				font:Print(t[1], t[2], t[3], fs, t[4] or "ov")
			end
			font:End()
		end
	end

	-- Add to...: in the open graph's top right corner, level with its title.
	function page.addToRect()
		if not page.rects or not page.zoom then
			return nil
		end
		local parts = layoutParts()
		return parts.addTo, parts.addToLabel
	end

	function page.drawAddTo()
		local rect, label = page.addToRect()
		if not rect then
			return
		end
		local look, metrics = ctx.look, ctx.metrics
		ctx.draw.RectRound(rect[1], rect[2], rect[3], rect[4], metrics.csSmall, 1, 1, 1, 1, PLATE)
		if page.hover.addTo == 1 or page.menu and page.menu.from == "addTo" then
			ctx.draw.Highlight(rect[1], rect[2], rect[3], rect[4], metrics.csSmall, look.rowHoverOpacity, look.white)
		end
		ctx.draw.Color(1, 1, 1, 1)
		printTexts({
			{
				ctx.colors.title .. label,
				mathFloor((rect[1] + rect[3]) * 0.5),
				mathFloor((rect[2] + rect[4]) * 0.5),
				"ovc",
			},
		}, metrics.catFs)
	end

	function page.menuOpen()
		return page.menu ~= nil
	end

	function page.closeMenu()
		if page.menu then
			page.menu = nil
			page.gen = page.gen + 1
		end
	end

	local function openMenu(rows, anchor, title, from)
		page.menu = { rows = rows, anchor = anchor, title = title, from = from, rects = {} }
		page.gen = page.gen + 1
	end

	-- Right-click on one of the player's categories in the sidebar: named, moved, deleted -
	-- the overview put back as it shipped instead.
	function page.openCategoryMenu(key, anchor)
		local custom = page.custom
		local category = custom.byKey(key)
		if not category then
			return
		end
		local at = 1
		for i, c in ipairs(custom.list) do
			if c == category then
				at = i
			end
		end
		local L = "ui.teamStats.custom."
		local rows = {
			{
				label = ctx.i18n(L .. "rename"),
				act = function()
					page.startNaming(key)
				end,
			},
			{
				label = ctx.i18n(L .. "moveUp"),
				disabled = at == 1,
				act = function()
					custom.move(key, -1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "moveDown"),
				disabled = at == #custom.list,
				act = function()
					custom.move(key, 1)
					ctx.categoriesChanged()
				end,
			},
		}
		-- Shared as a line of text: copied off any category, pasted as a new one when the
		-- clipboard holds one.
		rows[#rows + 1] = {
			label = ctx.i18n(L .. "copy"),
			act = function()
				local text = custom.export(key)
				if text and Spring.SetClipboard then
					Spring.SetClipboard(text)
				end
			end,
		}
		local pasted = custom.parse(Spring.GetClipboard and Spring.GetClipboard() or nil)
		rows[#rows + 1] = {
			label = ctx.i18n(L .. "paste"),
			disabled = pasted == nil,
			act = function()
				---@cast pasted -?
				local made = custom.import(pasted)
				ctx.categoriesChanged()
				ctx.selectGroup(made.key)
			end,
		}
		if category.shipped then
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "reset"),
				confirm = ctx.i18n(L .. "resetConfirm"),
				act = function()
					custom.reset(key)
					page.zoom = nil
					ctx.categoriesChanged()
				end,
			}
		else
			rows[#rows + 1] = {
				label = ctx.i18n(L .. "delete"),
				confirm = ctx.i18n(L .. "deleteConfirm"),
				act = function()
					custom.delete(key)
					if ctx.selectedGroup() == key then
						ctx.selectGroup(custom.SHIPPED_KEY)
					end
					ctx.categoriesChanged()
				end,
			}
		end
		openMenu(rows, anchor, category.label, "category")
	end

	-- Right-click on a graph of a custom category, in its stat list or on its page of charts.
	function page.openGraphMenu(entry, anchor)
		local custom = page.custom
		local graph = entry.graph
		local _, category = custom.graphById(graph.id)
		if not category then
			return
		end
		local at = 1
		for i, g in ipairs(category.graphs) do
			if g == graph then
				at = i
			end
		end
		local L = "ui.teamStats.custom."
		openMenu({
			{
				label = ctx.i18n(L .. "moveUp"),
				disabled = at == 1,
				act = function()
					custom.moveGraph(graph.id, -1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "moveDown"),
				disabled = at == #category.graphs,
				act = function()
					custom.moveGraph(graph.id, 1)
					ctx.categoriesChanged()
				end,
			},
			{
				label = ctx.i18n(L .. "remove"),
				act = function()
					custom.removeGraph(graph.id)
					if page.zoom == entry.key then
						page.zoom = nil
					end
					ctx.categoriesChanged()
				end,
			},
		}, anchor, entry.label, "graph")
	end

	-- Add to...: every category of the player's own - ticked when it has this stat already -
	-- and a new one, named as soon as it is made. The graph goes in with the settings it is
	-- drawn with right now.
	function page.openAddMenu()
		local rect = page.addToRect()
		if not rect or not page.zoom then
			return
		end
		local custom = page.custom
		local stat, settings = statOf(page.zoom), settingsOf(page.zoom)
		local rows = {}
		for _, category in ipairs(custom.list) do
			local has = false
			for _, g in ipairs(category.graphs) do
				has = has or g.stat == stat
			end
			rows[#rows + 1] = {
				label = category.label,
				check = has,
				act = function()
					custom.add(category.key, stat, settings)
					ctx.categoriesChanged()
				end,
			}
		end
		rows[#rows + 1] = {
			label = ctx.i18n("ui.teamStats.custom.newCategory"),
			act = function()
				local category = custom.create()
				custom.add(category.key, stat, settings)
				ctx.categoriesChanged()
				page.startNaming(category.key)
			end,
		}
		openMenu(rows, rect, ctx.i18n("ui.teamStats.custom.addTo"), "addTo")
	end

	-- The card: beside what opened it - under the Add to... button, flush with its right
	-- edge - on the screen, drawn over everything. A row under the cursor lights up; a
	-- greyed one does nothing; one that asks to be sure says so on the first press and acts
	-- on the second.
	function page.drawMenu(mx, my)
		local menu = page.menu
		if not menu then
			return
		end
		local look, metrics, colors = ctx.look, ctx.metrics, ctx.colors
		local fs, rowH = metrics.catFs, metrics.catRowHeight
		local font = ctx.font()
		local pad = metrics.sidePad
		local tick = mathFloor(fs * 1.2)
		---@type number
		local w = mathFloor(180 * page.scale)
		for _, row in ipairs(menu.rows) do
			local label = row.armed and row.confirm or row.label
			local tw = font and mathFloor(font:GetTextWidth(label) * fs) or #label * fs * 0.55
			w = mathMax(w, tw + pad * 2 + tick)
		end
		local titleRows = menu.title and 1 or 0
		local h = rowH * (#menu.rows + titleRows) + metrics.cardLip * 2
		local a = menu.anchor
		local gap = mathFloor(6 * page.scale)
		local vsx = Spring.GetViewGeometry()
		---@type number, number
		local x1, y2
		if menu.from == "addTo" then
			x1, y2 = mathMax(0, a[3] - w), a[2] - gap
		else
			x1, y2 = a[3] + gap, a[4]
			if x1 + w > vsx then
				x1 = a[1] - gap - w
			end
		end
		local y1 = y2 - h
		if y1 < 0 then
			y1, y2 = 0, h
		end
		ctx.draw.RectRound(x1, y1, x1 + w, y2, metrics.csPanel, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
		local texts = {}
		local top = y2 - metrics.cardLip
		if menu.title then
			texts[#texts + 1] = { colors.title .. menu.title, x1 + pad, top - mathFloor(rowH * 0.5) }
			top = top - rowH
		end
		menu.rects = {}
		for i, row in ipairs(menu.rows) do
			local rect = { x1, top - rowH, x1 + w, top }
			menu.rects[i] = rect
			local over = mx and mx >= rect[1] and mx <= rect[3] and my >= rect[2] and my <= rect[4]
			if over and not row.disabled then
				ctx.draw.Highlight(
					rect[1] + metrics.catInset,
					rect[2],
					rect[3] - metrics.catInset,
					rect[4],
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local color = row.disabled and colors.faded or (row.armed and colors.bad or colors.dim)
			if over and not row.disabled and not row.armed then
				color = colors.selected
			end
			local label = row.armed and row.confirm or row.label
			local cy = mathFloor((rect[2] + rect[4]) * 0.5)
			if row.check then
				texts[#texts + 1] = { colors.selected .. "\226\128\162", x1 + pad, cy }
			end
			texts[#texts + 1] = { color .. label, x1 + pad + tick, cy }
			top = top - rowH
		end
		ctx.draw.Color(1, 1, 1, 1)
		printTexts(texts, fs)
	end

	-- While the card is open it takes every press: a row does its thing, anywhere else only
	-- puts the card away.
	function page.menuPress(x, y, button)
		local menu = page.menu
		if not menu then
			return false
		end
		for i, rect in ipairs(menu.rects) do
			if x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4] and button ~= 3 then
				local row = menu.rows[i]
				---@cast row -?
				if row.disabled then
					return true
				end
				if row.confirm and not row.armed then
					row.armed = true
					page.gen = page.gen + 1
					ctx.playSound()
					return true
				end
				page.closeMenu()
				row.act()
				ctx.playSound()
				return true
			end
		end
		page.closeMenu()
		return true
	end

	-- Naming a category: a field over its sidebar entry, the name so far picked so typing
	-- replaces it. Enter keeps what was typed, Escape the name it had.
	function page.startNaming(key)
		local category = page.custom.byKey(key)
		if not category then
			return
		end
		local box = Editbox.new({ text = category.label, maxChars = 32, outline = ctx.look.outline })
		box:focus()
		box.selAnchor = 0
		page.naming = { key = key, box = box, was = category.label }
		ctx.textInput(true)
		page.gen = page.gen + 1
	end

	-- A name left as it was is not kept as typed: an unnamed category keeps the name it is
	-- given in the player's language. Emptied, it gets that name back.
	function page.stopNaming(keep)
		local naming = page.naming
		if not naming then
			return
		end
		page.naming = nil
		local text = naming.box:getText()
		if keep and text ~= naming.was then
			page.custom.rename(naming.key, text)
		end
		ctx.textInput(false)
		ctx.categoriesChanged()
	end

	function page.namingKey(key)
		local naming = page.naming
		if not naming then
			return false
		end
		if key == KEYSYMS.RETURN or key == KEYSYMS.KP_ENTER then
			page.stopNaming(true)
		elseif key == KEYSYMS.ESCAPE then
			page.stopNaming(false)
		else
			naming.box:keyPress(key)
		end
		return true
	end

	function page.namingText(char)
		return page.naming ~= nil and page.naming.box:textInput(char)
	end

	-- The field, where the panel says the entry is.
	function page.drawNaming(x1, y1, x2, y2)
		local naming = page.naming
		if not naming then
			return
		end
		naming.box:setRect(x1, y1, x2, y2, ctx.metrics.catFs, ctx.metrics.sidePad)
		naming.box:draw()
	end

	----------------------------------------------------------------
	-- Custom categories: a graph dragged to another place
	----------------------------------------------------------------

	-- How far a press on a graph of the player's own travels before it is a drag rather
	-- than a click, which opens the graph when it is let go.
	local function dragThreshold()
		return mathMax(4, mathFloor(6 * page.scale))
	end

	function page.dragging()
		return page.drag ~= nil
	end

	function page.dragMoving()
		return page.drag ~= nil and page.drag.moving == true
	end

	-- The graphs a drag can land among, in order, each where it is shown: the grid's
	-- charts, or the stat list's rows while one is open.
	local function dropSlots()
		---@type table[]
		local slots = {}
		if page.gridded() then
			for _, mini in ipairs(page.miniCharts or {}) do
				local entry = page.entryByKey[mini.key]
				if entry and entry.graph then
					slots[#slots + 1] = { graph = entry.graph, rect = mini.rect }
				end
			end
		elseif page.listShown() and page.rects then
			for i, entry in ipairs(page.statList) do
				if entry.graph then
					local x1, y1, x2, y2 = statRect(i)
					slots[#slots + 1] = { graph = entry.graph, rect = { x1, y1, x2, y2 } }
				end
			end
		end
		return slots
	end

	-- Where the dragged graph lands if let go at x,y: in front of the nearest graph or
	-- after it, by the half of it the cursor is over. Answers the graph it goes in front of
	-- (none: the end) and the line that marks the place; nothing where it is already, or
	-- off the charts.
	---@return { before: table?, line: number[] }?
	local function dropTarget(x, y)
		local drag, r = page.drag, page.rects
		if not drag or not r then
			return nil
		end
		local grid = page.gridded()
		local area = grid and r.chart or r.list
		if x < area[1] or x > area[3] or y < area[2] or y > area[4] then
			return nil
		end
		---@type table?
		local near = nil
		local nearest = mathHuge
		for _, slot in ipairs(dropSlots()) do
			local rc = slot.rect
			---@type number, number
			local dx, dy = mathMax(rc[1] - x, 0, x - rc[3]), mathMax(rc[2] - y, 0, y - rc[4])
			if dx * dx + dy * dy < nearest then
				near, nearest = slot, dx * dx + dy * dy
			end
		end
		local _, category = page.custom.graphById(drag.graph.id)
		if not near or not category then
			return nil
		end
		local rc = near.rect
		local after
		if grid then
			after = x > (rc[1] + rc[3]) * 0.5
		else
			-- Down the list is after: y grows upwards.
			after = y < (rc[2] + rc[4]) * 0.5
		end
		local graphs = category.graphs
		local from, at = 1, 1
		for i, graph in ipairs(graphs) do
			if graph == drag.graph then
				from = i
			end
			if graph == near.graph then
				at = after and i + 1 or i
			end
		end
		if at == from or at == from + 1 then
			return nil
		end
		-- In the gap beside the chart, or across the row's edge.
		local w = mathMax(2, mathFloor(3 * page.scale))
		if grid then
			local gap = mathFloor(8 * page.scale)
			local lx = mathFloor((after and rc[3] + gap * 0.5 or rc[1] - gap * 0.5) - w * 0.5)
			return { before = graphs[at], line = { lx, rc[2], lx + w, rc[4] } }
		end
		local ly = mathFloor((after and rc[2] or rc[4]) - w * 0.5)
		local inset = ctx.metrics.catInset
		return { before = graphs[at], line = { rc[1] + inset, ly, rc[3] - inset, ly + w } }
	end

	-- Every frame of a press on a graph of the player's own: a drag once it has travelled;
	-- held at the grid's top or bottom edge, the grid scrolls a row at a time. A press let
	-- go where the panel never heard of it is dropped.
	function page.dragUpdate(mx, my, held)
		local drag = page.drag
		if not drag then
			return
		end
		if not held then
			page.drag = nil
			page.gen = page.gen + 1
			return
		end
		if not drag.moving then
			if mathMax(mathAbs(mx - drag.x), mathAbs(my - drag.y)) <= dragThreshold() then
				return
			end
			drag.moving = true
			page.gen = page.gen + 1
		end
		local r = page.rects
		if not (r and page.gridded() and page.maxScroll > 0) then
			return
		end
		local c = r.chart
		local edge = mathFloor(24 * page.scale)
		local over = mx >= c[1] and mx <= c[3]
		local up = over and my > c[4] - edge and page.scroll > 0
		local down = over and my < c[2] + edge and page.scroll < page.maxScroll
		if not (up or down) then
			drag.edgeSince = nil
			return
		end
		local now = Spring.GetTimer()
		if not drag.edgeSince then
			drag.edgeSince = now
		elseif Spring.DiffTimers(now, drag.edgeSince) > 0.4 then
			drag.edgeSince = now
			page.wheel(up)
		end
	end

	-- The drag over the charts: the graph's own place shaded, a line where it would land,
	-- and its name beside the cursor.
	function page.drawDrag(mx, my)
		local drag = page.drag
		if not (drag and drag.moving) then
			return
		end
		local metrics, look = ctx.metrics, ctx.look
		for _, slot in ipairs(dropSlots()) do
			if slot.graph == drag.graph then
				local rc = slot.rect
				ctx.draw.RectRound(rc[1], rc[2], rc[3], rc[4], metrics.csSmall, 1, 1, 1, 1, look.dragShade)
			end
		end
		local target = dropTarget(mx, my)
		if target then
			local l = target.line
			ctx.draw.RectRound(l[1], l[2], l[3], l[4], 0, 0, 0, 0, 0, look.dropLine)
		end
		local entry = page.entryByKey[drag.key]
		if entry then
			local fs, pad = metrics.catFs, metrics.sidePad
			local font = ctx.font()
			local w = (font and mathFloor(font:GetTextWidth(entry.label) * fs) or #entry.label * fs * 0.55) + pad * 2
			local h = mathFloor(metrics.catRowHeight * 0.9)
			local x1 = mathFloor(mx + 14 * page.scale)
			if x1 + w > Spring.GetViewGeometry() then
				x1 = mathFloor(mx - 14 * page.scale - w)
			end
			local y2 = mathFloor(my - 6 * page.scale)
			ctx.draw.RectRound(x1, y2 - h, x1 + w, y2, metrics.csSmall, 1, 1, 1, 1, look.cardFill, look.cardFillTop)
			ctx.draw.Color(1, 1, 1, 1)
			printTexts({ { ctx.colors.title .. entry.label, x1 + pad, mathFloor(y2 - h * 0.5) } }, fs)
		end
	end

	-- The charts, after the panel's list: the grid of the page, or the one chart a pick or
	-- a zoom opened, each with its own hover overlay. The chart under the cursor is framed
	-- and answers the tooltip.
	-- The grid's charts are drawn into a texture of their own, and the texture onto the screen
	-- every frame: a dozen charts' lists called every frame cost the engine several times the
	-- one textured rect. Drawn into it again when a chart is to be made again, when other
	-- charts or lists fill the grid, or when its room moved or changed size. `drawn` holds each
	-- chart and its list as they were drawn into it.
	---@type { tex: integer?, x: number, y: number, w: number, h: number, valid: boolean, drawn: table }
	local gridTex = { tex = nil, x = 0, y = 0, w = 0, h = 0, valid = false, drawn = {} }

	function page.dropGridTexture()
		if gridTex.tex then
			gl.DeleteTexture(gridTex.tex)
		end
		gridTex.tex, gridTex.valid = nil, false
	end

	-- Whether the texture still shows what the charts would draw.
	local function gridCurrent(minis, x, y, w, h)
		if not gridTex.valid or gridTex.x ~= x or gridTex.y ~= y or gridTex.w ~= w or gridTex.h ~= h then
			return false
		end
		local drawn = gridTex.drawn
		if #drawn ~= #minis * 2 then
			return false
		end
		for i = 1, #minis do
			local c = minis[i].chart
			if c.dirty or not c.list or drawn[i * 2 - 1] ~= c or drawn[i * 2] ~= c.list then
				return false
			end
		end
		return true
	end

	local function drawMinis(minis)
		for i = 1, #minis do
			minis[i].chart:draw()
		end
	end

	-- The grid's charts, without their hover: from the texture, drawn into first when it no
	-- longer shows them - or straight, where there is no texture to draw into.
	local function drawGrid(minis)
		local r = page.rects and page.rects.chart
		local helper = gl.R2tHelper
		if not r or not helper then
			drawMinis(minis)
			return
		end
		local x, y = mathFloor(r[1]), mathFloor(r[2])
		local w, h = math.ceil(r[3]) - x, math.ceil(r[4]) - y
		if w <= 0 or h <= 0 then
			drawMinis(minis)
			return
		end
		if not gridCurrent(minis, x, y, w, h) then
			if not gridTex.tex or gridTex.w ~= w or gridTex.h ~= h then
				page.dropGridTexture()
				gridTex.tex = gl.CreateTexture(w, h, { target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true })
				if not gridTex.tex then
					drawMinis(minis)
					return
				end
			end
			helper.RenderInRect(gridTex.tex, x, y, x + w, y + h, function()
				drawMinis(minis)
			end, true)
			local drawn = gridTex.drawn
			for k = #drawn, 1, -1 do
				drawn[k] = nil
			end
			for i = 1, #minis do
				local c = minis[i].chart
				drawn[i * 2 - 1], drawn[i * 2] = c, c.list
			end
			gridTex.x, gridTex.y, gridTex.w, gridTex.h, gridTex.valid = x, y, w, h, true
		end
		helper.BlendTexRect(gridTex.tex, x, y, x + w, y + h, true)
	end

	function page.drawChart(mx, my)
		if page.dirty then
			page.build()
		elseif page.stale then
			page.catchUp()
		end
		local r = page.rects
		local inside = r and mx >= r.chart[1] and mx <= r.chart[3] and my >= r.chart[2] and my <= r.chart[4]
		-- The card of kinds lies over the charts: what is under it is not under the cursor.
		if page.hover.kind > 0 then
			inside = false
		end
		if page.gridded() then
			page.chartHit, page.miniHit = nil, nil
			local minis = page.miniCharts or {}
			for _, mini in ipairs(minis) do
				local over = inside
					and mx >= mini.rect[1]
					and mx <= mini.rect[3]
					and my >= mini.rect[2]
					and my <= mini.rect[4]
				local hit = over and mini.chart:hitTest(mx, my) or nil
				if over then
					page.miniHit = mini
					page.chartHit = hit
				end
				-- Drawn without its hover: the one under the cursor gets it last, over the
				-- charts beside it and over the light that marks it.
				mini.chart:setHover(nil)
			end
			drawGrid(minis)
			-- The one under the cursor is marked, so it is clear what a press would open: a
			-- rounded outline that fades inwards rather than a hard box.
			---@type table?
			local mini = page.miniHit
			if mini then
				mini.chart:setHover(page.chartHit)
				ctx.draw.Highlight(
					mini.rect[1],
					mini.rect[2],
					mini.rect[3],
					mini.rect[4],
					ctx.metrics.csPanel,
					ctx.look.chartHoverOpacity,
					ctx.look.white
				)
				ctx.draw.Color(1, 1, 1, 1)
				mini.chart:drawOverlay()
			end
			page.drawKinds()
			return
		end
		-- The button in the chart's corner is not the chart.
		if page.hover.addTo == 1 then
			inside = false
		end
		local hit = inside and chart:hitTest(mx, my) or nil
		-- One chart fills the page: no small one answers for the tooltip any more.
		page.chartHit, page.miniHit = hit, nil
		chart:setHover(hit)
		chart:draw()
		page.drawAddTo()
		page.drawKinds()
	end

	-- With one chart open, the one before or after it in the list: the arrow keys go through
	-- a category's charts without going back to the grid. Answers whether there was one.
	function page.step(delta)
		if page.gridded() then
			return false
		end
		local keys, at = {}, nil
		for _, entry in ipairs(page.statList) do
			if entry.key and not entry.back and not entry.divider then
				keys[#keys + 1] = entry.key
				if entry.key == page.zoom then
					at = #keys
				end
			end
		end
		local to = at and keys[at + delta]
		if not to then
			return false
		end
		page.stat, page.zoom = to, to
		page.dirty = true
		page.gen = page.gen + 1
		return true
	end

	-- The arrow keys while a chart is open: left and up go back, right and down on. They
	-- are the page's then even at either end of the list, so they never move the camera
	-- behind the panel.
	function page.keyPress(key)
		if page.gridded() then
			return false
		end
		if key == KEYSYMS.LEFT or key == KEYSYMS.UP then
			page.step(-1)
			return true
		elseif key == KEYSYMS.RIGHT or key == KEYSYMS.DOWN then
			page.step(1)
			return true
		end
		return false
	end

	-- The wheel over the charts moves the grid a row at a time. With one chart open it stays
	-- on it - stepping to the next chart is the arrow keys' - and scrolls one of rows too long
	-- for it, the report card. Answers whether it moved anything.
	function page.wheel(up)
		if not page.gridded() then
			return chart:scrollBars(up and -REPORT_WHEEL or REPORT_WHEEL)
		end
		if page.maxScroll <= 0 then
			return false
		end
		local to = mathMax(0, mathMin(page.maxScroll, page.scroll + (up and -1 or 1)))
		if to == page.scroll then
			return false
		end
		page.scroll = to
		page.dirty = true
		page.gen = page.gen + 1
		return true
	end

	----------------------------------------------------------------
	-- The cursor
	----------------------------------------------------------------

	-- Which list entry, legend square or legend block the cursor is over, for the
	-- panel's bake signature.
	function page.hoverAt(mx, my)
		page.hover.stat, page.hover.legend, page.hover.block, page.hover.kind, page.hover.filter = 0, 0, 0, 0, 0
		page.hover.addTo = 0
		local add = page.addToRect()
		if add and mx >= add[1] and mx <= add[3] and my >= add[2] and my <= add[4] then
			page.hover.addTo = 1
		end
		local tog = filterToggleRect()
		if tog and mx >= tog[3] - filterReserve() and mx <= tog[3] and my >= tog[2] and my <= tog[4] then
			page.hover.filter = 1
		end
		for i, row in ipairs(page.kindRects) do
			local r2 = row.rect
			if mx >= r2[1] and mx <= r2[3] and my >= r2[2] and my <= r2[4] then
				page.hover.kind = i
			end
		end
		local r = page.rects
		if not r then
			return "0|0|0|0"
		end
		-- The bar runs above the stat list, so it is asked first.
		if my >= r.bar[2] and my <= r.bar[4] then
			for i, b in ipairs(page.barBlocks) do
				if mx >= b.hx1 and mx < b.hx2 then
					page.hover.block = i
				end
			end
			for i, item in ipairs(page.barItems) do
				if mx >= item.x1 and mx < item.x2 and my >= item.y1 and my <= item.y2 then
					page.hover.legend = i
				end
			end
		elseif page.listShown() and mx >= r.list[1] and mx <= r.list[3] then
			for i = 1, #page.statList do
				local _, y1, _, y2 = statRect(i)
				if my > y1 and my <= y2 and not page.statList[i].divider then
					page.hover.stat = i
				end
			end
		end
		return page.hover.stat
			.. "|"
			.. page.hover.legend
			.. "|"
			.. page.hover.block
			.. "|"
			.. page.hover.kind
			.. "|"
			.. page.hover.filter
			.. "|"
			.. page.hover.addTo
			.. "|"
			.. page.gen
	end

	-- The units a press in the bar acts on: a square's; with the grouping switch on the
	-- block's ally team, off it the caption's players, all of them.
	local function unitsUnderCursor()
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			return { item.unit }
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			if b.unit then
				return { b.unit }
			elseif not b.all and not b.me then
				local list = {}
				for _, m in ipairs(b.members) do
					list[#list + 1] = m.unit
				end
				return list
			end
		end
		return nil
	end

	local function changed()
		page.dirty = true
		page.gen = page.gen + 1
		ctx.playSound()
	end

	-- A press: picks a stat. On the bar a click adds the units under the cursor to the
	-- selection, or takes them out when they all were in it; Ctrl+click makes them the
	-- whole selection; right-click hides them, or shows them again when they all were
	-- hidden. All clears the selection and shows every team again.
	function page.mousePress(x, y, button)
		page.hoverAt(x, y)
		if page.kindsOpen then
			local row = page.kindRects[page.hover.kind]
			if row and button ~= 3 then
				local off = kindsOff()
				off[row.key] = not off[row.key] or nil
				changed()
				return true
			end
			-- A press anywhere else puts the card away.
			page.kindsOpen = false
			changed()
			return true
		end
		-- Add to... on the open graph, before the press on the chart that closes it.
		if page.hover.addTo == 1 and button ~= 3 then
			page.openAddMenu()
			return true
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			-- A custom category's graph is moved or removed from its right-click card.
			if button == 3 and entry.graph then
				local x1, y1, x2, y2 = statRect(page.hover.stat)
				page.openGraphMenu(entry, { x1, y1, x2, y2 })
				return true
			end
			if button ~= 3 and entry.back then
				-- Back to the grid the chart was opened from.
				page.zoom = nil
				changed()
			elseif button == 1 and entry.graph then
				-- One of the player's own: opened when let go, moved when dragged.
				page.drag = { key = entry.key, graph = entry.graph, x = x, y = y }
			elseif button ~= 3 then
				page.stat = entry.key
				-- The list is how a stat is opened, whatever the grid is showing.
				page.zoom = entry.key
				changed()
			end
			return true
		end
		if button == 3 and page.miniHit then
			local entry = page.entryByKey[page.miniHit.key]
			if entry and entry.graph then
				page.openGraphMenu(entry, page.miniHit.rect)
				return true
			end
		end
		if button ~= 3 and page.miniHit then
			local entry = page.entryByKey[page.miniHit.key]
			if button == 1 and entry and entry.graph then
				page.drag = { key = entry.key, graph = entry.graph, x = x, y = y }
				return true
			end
			-- The grid answered what it is for; this one opens on its own.
			page.stat = page.miniHit.key
			page.zoom = page.miniHit.key
			changed()
			return true
		end
		if button ~= 3 and page.zoom and page.rects then
			local c = page.rects.chart
			if x >= c[1] and x <= c[3] and y >= c[2] and y <= c[4] then
				-- And a press on the opened chart goes back to the grid.
				page.zoom = nil
				changed()
				return true
			end
		end
		if page.hover.filter == 1 and button ~= 3 then
			page.hideUnselected = not page.hideUnselected
			changed()
			return true
		end
		local block = page.hover.block > 0 and page.barBlocks[page.hover.block] or nil
		if block and block.me and button ~= 3 then
			-- Your own team alone, whatever was picked before.
			page.selected = {}
			setTeams(page.selected, block.unit, true)
			setTeams(page.hidden, block.unit, false)
			changed()
			return true
		end
		if block and block.all then
			if button ~= 3 and (next(page.selected) or next(page.hidden)) then
				page.selected, page.hidden = {}, {}
				changed()
			end
			return true
		end
		local targets = unitsUnderCursor()
		if targets then
			local allHidden, allSelected = true, true
			for _, u in ipairs(targets) do
				allHidden = allHidden and isHidden(u)
				allSelected = allSelected and allPicked(u) and not isHidden(u)
			end
			local _, ctrl = Spring.GetModKeyState()
			if button == 3 then
				for _, u in ipairs(targets) do
					setTeams(page.hidden, u, not allHidden)
					if not allHidden then
						setTeams(page.selected, u, false)
					end
				end
			else
				if ctrl then
					page.selected = {}
				end
				for _, u in ipairs(targets) do
					local on = ctrl or not allSelected
					setTeams(page.selected, u, on)
					if on then
						setTeams(page.hidden, u, false)
					end
				end
			end
			changed()
			return true
		end
		return block ~= nil
	end

	-- The press on a graph of the player's own, let go: travelled, the graph lands where the
	-- line showed; not, it was a click, and the graph opens.
	function page.mouseRelease(x, y)
		local drag = page.drag
		if not drag then
			return false
		end
		if drag.moving or mathMax(mathAbs(x - drag.x), mathAbs(y - drag.y)) > dragThreshold() then
			local target = dropTarget(x, y)
			page.drag = nil
			page.gen = page.gen + 1
			if target then
				page.custom.placeGraph(drag.graph.id, target.before and target.before.id)
				ctx.categoriesChanged()
				ctx.playSound()
			end
			return true
		end
		page.drag = nil
		page.stat = drag.key
		page.zoom = drag.key
		changed()
		return true
	end

	-- What the units under the cursor are to the chart right now, and what the mouse does
	-- to them: a line on their state (selected, not, hidden, and what that means with
	-- the switches as they are), one on their milestones when those are on the chart,
	-- then the controls.
	local function barHint(targets)
		local L = "ui.teamStats.graph."
		local allHidden, allSelected, someSelected = true, true, false
		for _, u in ipairs(targets) do
			local shownU = not isHidden(u)
			allHidden = allHidden and not shownU
			allSelected = allSelected and allPicked(u) and shownU
			-- An ally team with only some of its players picked is some of it.
			someSelected = someSelected or (isPicked(u) and shownU)
		end
		local composition = statOf(page.stat) == "composition"
		local anyPicked = #pickedUnits() > 0
		local dropping = filtering()
		local state
		if allHidden then
			state = "hidden"
		elseif allSelected then
			state = composition and "counted" or (dropping and "only" or "lit")
		elseif someSelected then
			state = "some"
		elseif anyPicked then
			state = composition and "notCounted" or (dropping and "left" or "faded")
		else
			state = composition and "allCounted" or "alike"
		end
		local group = #targets > 1
		local lines = { ctx.colors.title .. ctx.i18n(L .. "state." .. state) }
		if settingsOf(page.zoom or page.stat).milestones and not allHidden and (allSelected or not anyPicked) then
			local key = group and "milestonesGroup" or "milestones"
			lines[#lines + 1] = ctx.colors.title .. ctx.i18n(L .. "state." .. key)
		end
		-- Grouped, a team is one line on the bar: its players are picked apart only with the
		-- grouping off.
		local several = false
		for _, u in ipairs(targets) do
			several = several or #u.members > 1
		end
		if grouped() and several then
			lines[#lines + 1] = ctx.colors.dim .. ctx.i18n(L .. "state.grouped")
		end
		local suffix = group and "Group" or ""
		for _, control in ipairs({ "click", "ctrlClick", "rightClick" }) do
			lines[#lines + 1] = ctx.colors.dim .. ctx.i18n(L .. "control." .. control .. suffix)
		end
		return table.concat(lines, "\n")
	end

	-- What a stat's chart shows, in words: its column's description where it is a column's -
	-- the chart's own wording where the table's speaks of this moment - else the chart's.
	-- Nothing for one whose description is left empty.
	local function describeStat(stat)
		local desc
		if ctx.COLUMNS[stat] then
			desc = ctx.L.graphDesc[stat] or ctx.L.desc[stat]
		else
			desc = ctx.i18n("ui.teamStats.graph." .. stat .. "Desc")
		end
		if not desc or not desc:find("%S") then
			return nil
		end
		return desc
	end

	-- The tooltip for the cursor: the chart's description, a stat's explanation, or the
	-- units under the cursor in the bar and how the bar works.
	function page.tooltip()
		local kindRow = page.kindRects[page.hover.kind]
		if kindRow then
			local hint = ctx.i18n("ui.teamStats.graph.kindHint")
			if DESCRIBED[kindRow.key] then
				hint = ctx.i18n("ui.teamStats.milestoneDesc." .. kindRow.key) .. "\n" .. ctx.colors.dim .. hint
			end
			return markName(kindRow.key), hint
		end
		if page.chartHit or page.miniHit then
			local hovered = page.miniHit and page.miniHit.chart or chart
			local desc = page.chartHit and hovered:describe(page.chartHit) or nil
			-- Its % of total faded in the title: why it keeps its line.
			local key = page.miniHit and page.miniHit.key or page.zoom or page.stat
			local column = ctx.COLUMNS[statOf(key)]
			local idle = settingsOf(key).share and column and column.fmt == "si" and hovered.cfg.kind ~= "stacked"
			if page.chartHit and idle and page.chartHit.kind ~= "marker" then
				desc = (desc or "") .. "\n" .. ctx.colors.dim .. ctx.i18n("ui.teamStats.graph.shareOne")
			end
			-- A chart of a grid says what it shows, as its name in the list does, over what is
			-- under the cursor: small, its title alone may not.
			if page.miniHit then
				local about = describeStat(statOf(key))
				if about then
					desc = desc and (about .. "\n\n" .. desc) or about
				end
			end
			return hovered.cfg.title, desc
		end
		if page.hover.stat > 0 then
			local entry = page.statList[page.hover.stat]
			---@cast entry -?
			if entry.back then
				return entry.label, ctx.i18n("ui.teamStats.graph.overviewDesc")
			end
			-- Explained by what it shows: a custom category's graph is keyed as itself, and
			-- says it can be moved or removed.
			local desc = describeStat(entry.stat or entry.key)
			if entry.graph then
				desc = (desc and desc .. "\n" or "") .. ctx.colors.dim .. ctx.i18n("ui.teamStats.custom.graphHint")
			end
			return entry.label, desc or ""
		end
		if page.hover.filter == 1 then
			return ctx.i18n("ui.teamStats.graph.hideUnselected"), ctx.i18n("ui.teamStats.graph.hideUnselectedDesc")
		end
		if page.hover.addTo == 1 then
			return ctx.i18n("ui.teamStats.custom.addTo"), ctx.i18n("ui.teamStats.custom.addToDesc")
		end
		if page.hover.legend > 0 then
			local item = page.barItems[page.hover.legend]
			---@cast item -?
			local title = (item.team.nameColor or "") .. item.team.name
			if item.unit.name ~= item.team.name then
				title = title .. ctx.colors.title .. " \194\183 " .. item.unit.name
			end
			return title, barHint({ item.unit })
		end
		if page.hover.block > 0 then
			local b = page.barBlocks[page.hover.block]
			---@cast b -?
			if b.me then
				local tip = ""
				-- Grouped, your own line is your whole team's.
				if grouped() and b.unit and #b.unit.members > 1 then
					tip = tip .. ctx.colors.dim .. ctx.i18n("ui.teamStats.graph.youGrouped")
				end
				return b.label, tip
			end
			if b.all then
				local tip = ctx.i18n("ui.teamStats.graph.allHint")
				if settingsOf(page.zoom or page.stat).milestones then
					tip = tip .. "\n" .. ctx.i18n("ui.teamStats.graph.allMilestones")
				end
				return b.label, tip
			end
			local targets = unitsUnderCursor()
			---@cast targets -?
			return b.label, barHint(targets)
		end
		return nil
	end

	----------------------------------------------------------------
	-- Housekeeping
	----------------------------------------------------------------

	function page.getConfig()
		-- The marks left off, a list a chart; charts with none left off are not kept.
		local off = {}
		for stat, kinds in pairs(page.marksOff) do
			local list = {}
			for kind, on in pairs(kinds) do
				if on then
					list[#list + 1] = kind
				end
			end
			if #list > 0 then
				tableSort(list)
				off[stat] = list
			end
		end
		return {
			graphStat = page.stat,
			graphsOpen = page.open,
			graphGroupByTeam = page.grouped,
			graphPerPage = page.perPage,
			graphMarksOff = off,
			graphHideUnselected = page.hideUnselected,
			customCategories = page.custom.getConfig(),
		}
	end

	function page.setConfig(data)
		page.custom.setConfig(data.customCategories)
		if type(data.graphStat) == "string" then
			page.stat = data.graphStat
		end
		if type(data.graphMarksOff) == "table" then
			page.marksOff = {}
			for stat, list in pairs(data.graphMarksOff) do
				if type(stat) == "string" and type(list) == "table" then
					local set = {}
					for _, kind in ipairs(list) do
						set[kind] = true
					end
					page.marksOff[stat] = set
				end
			end
		end
		if data.graphsOpen ~= nil then
			page.open = data.graphsOpen == true
		end
		if data.graphGroupByTeam ~= nil then
			page.grouped = data.graphGroupByTeam == true
		end
		if data.graphHideUnselected ~= nil then
			page.hideUnselected = data.graphHideUnselected == true
		end
		for _, spec in ipairs(PAGES) do
			if spec.n == data.graphPerPage then
				page.perPage = spec.n
			end
		end
	end

	-- The switches and the sidebar change what the chart is made of.
	function page.invalidate()
		page.dirty = true
	end

	function page.destroy()
		chart:destroy()
		for _, chartOf in ipairs(pool) do
			chartOf:destroy()
		end
		page.dropTrendList()
		page.dropGridTexture()
	end

	return page
end

return M
