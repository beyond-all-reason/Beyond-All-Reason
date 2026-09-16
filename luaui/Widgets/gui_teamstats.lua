local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "TeamStats",
		desc = "Shows game stats.",
		author = "Floris",
		version = "2.0",
		date = "",
		license = "GNU GPL, v2 or later",
		layer = -99990,
		enabled = true,
	}
end

local text = VFS.Include("luaui/Include/keybind_text.lua")

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathAbs = math.abs
local mathLog10 = math.log10
local mathHuge = math.huge
local tableSort = table.sort
local stringFormat = string.format
local stringLower = string.lower
local formatSI = string.formatSI
local math_isInRect = math.isInRect

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spIsGUIHidden = Spring.IsGUIHidden
local spGetGameFrame = Spring.GetGameFrame
local spGetTeamStatsHistory = Spring.GetTeamStatsHistory
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamColor = Spring.GetTeamColor
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetTeamList = Spring.GetTeamList
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spGetModKeyState = Spring.GetModKeyState
local spPlaySoundFile = Spring.PlaySoundFile
local spSetMouseCursor = Spring.SetMouseCursor

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glTexture = gl.Texture
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local GL_TRIANGLES = GL.TRIANGLES

-- Frames between refreshes while the panel is open. The engine's newest history entry is
-- live, so every refresh really is newer data.
local UPDATE_FRAMES = 30

---@type boolean
local playSounds = true
local buttonclick = "LuaUI/Sounds/buildbar_waypoint.wav"

-- The Graphs entry in the column is where a history page will go. Off until there is one
-- to open, so players are not offered something that does nothing.
---@type boolean
local showPlannedPages = false

local screenHeightOrg = 610
local screenWidthOrg = 1100
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local vsx, vsy = spGetViewGeometry()
local widgetScale = (vsy / 1080)
local screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
local screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

---@type function
local RectRound
---@type function
local UiElement
---@type function
local UiScroller
---@type function
local UiScrollerAt
---@type function
local Highlight
---@type function
local UiToggle
---@type number
local elementCorner
---@type LuaFont
local font

----------------------------------------------------------------
-- The columns
----------------------------------------------------------------

-- Every column the panel can show. `group` is the caption spanning the neighbouring
-- columns that share it, `stat` the column's full name for its tooltip and `short` the
-- caption under the group, all i18n keys under ui.teamStats: a column in the overview is
-- a few characters wide, so the caption is the short form and the tooltip the full one.
-- `fmt` says how a value prints: "si" takes an SI prefix, "percent" prints as one and
-- "plain" is the number as it is. `rate` marks a running total the per-minute switch
-- turns into a rate; a ratio, a level or what is in storage right now is not one.
---@type table<string, table>
local COLUMNS = {
	name = { group = "", stat = "player", short = "player", fmt = "name" },
	damageDealt = { group = "damage", stat = "damageDealt", short = "damageDealt", fmt = "si", rate = true },
	damageReceived = { group = "damage", stat = "damageReceived", short = "shortReceived", fmt = "si", rate = true },
	damageEfficiency = { group = "damage", stat = "damageEfficiency", short = "shortEfficiency", fmt = "percent" },
	unitsProduced = { group = "units", stat = "unitsProduced", short = "shortBuilt", fmt = "si", rate = true },
	unitsKilled = { group = "units", stat = "unitsKilled", short = "unitsKilled", fmt = "si", rate = true },
	unitsDied = { group = "units", stat = "unitsDied", short = "unitsDied", fmt = "si", rate = true },
	killEfficiency = { group = "units", stat = "killEfficiency", short = "shortEfficiency", fmt = "percent" },
	unitsCaptured = { group = "units", stat = "unitsCaptured", short = "unitsCaptured", fmt = "si", rate = true },
	unitsStolen = { group = "units", stat = "unitsStolen", short = "unitsStolen", fmt = "si", rate = true },
	unitsReceived = { group = "units", stat = "unitsReceived", short = "unitsReceived", fmt = "si", rate = true },
	unitsSent = { group = "units", stat = "unitsSent", short = "unitsSent", fmt = "si", rate = true },
	unitsActive = { group = "units", stat = "unitsActive", short = "unitsActive", fmt = "si" },
	metalProduced = { group = "metal", stat = "resourceProduced", short = "shortProduced", fmt = "si", rate = true },
	metalUsed = { group = "metal", stat = "resourceUsed", short = "resourceUsed", fmt = "si", rate = true },
	metalExcess = { group = "metal", stat = "resourceExcess", short = "resourceExcess", fmt = "si", rate = true },
	metalSent = { group = "metal", stat = "resourceSent", short = "resourceSent", fmt = "si", rate = true },
	metalReceived = { group = "metal", stat = "resourceReceived", short = "shortReceived", fmt = "si", rate = true },
	metalStored = { group = "metal", stat = "resourceStored", short = "resourceStored", fmt = "si" },
	energyProduced = { group = "energy", stat = "resourceProduced", short = "shortProduced", fmt = "si", rate = true },
	energyUsed = { group = "energy", stat = "resourceUsed", short = "resourceUsed", fmt = "si", rate = true },
	energyExcess = { group = "energy", stat = "resourceExcess", short = "resourceExcess", fmt = "si", rate = true },
	energySent = { group = "energy", stat = "resourceSent", short = "resourceSent", fmt = "si", rate = true },
	energyReceived = { group = "energy", stat = "resourceReceived", short = "shortReceived", fmt = "si", rate = true },
	energyStored = { group = "energy", stat = "resourceStored", short = "resourceStored", fmt = "si" },
	aggressionLevel = { group = "activity", stat = "aggression", short = "shortAggression", fmt = "plain" },
	actionsPerMinute = { group = "activity", stat = "actionsPerMinute", short = "shortActionsPerMinute", fmt = "plain" },
	-- What is happening right now, read fresh at every refresh: the economy from the engine
	-- and the rest from the team stats gadget. None of these is a running total, so the
	-- per-minute switch leaves them be. `of` names the two amounts a percentage is made of,
	-- for its tooltip, and `count` the number of units behind a value.
	metalIncome = { group = "metal", stat = "resourceIncome", short = "resourceIncome", fmt = "si" },
	metalExpense = { group = "metal", stat = "resourceExpense", short = "resourceExpense", fmt = "si" },
	metalLevel = {
		group = "metal",
		stat = "resourceLevel",
		short = "resourceLevel",
		fmt = "percent",
		of = { "metalCurrent", "metalStorage" },
	},
	energyIncome = { group = "energy", stat = "resourceIncome", short = "resourceIncome", fmt = "si" },
	energyExpense = { group = "energy", stat = "resourceExpense", short = "resourceExpense", fmt = "si" },
	energyLevel = {
		group = "energy",
		stat = "resourceLevel",
		short = "resourceLevel",
		fmt = "percent",
		of = { "energyCurrent", "energyStorage" },
	},
	conversion = {
		group = "industry",
		stat = "conversion",
		short = "shortConversion",
		fmt = "percent",
		of = { "convUse", "convCapacity" },
	},
	buildPower = { group = "industry", stat = "buildPower", short = "shortBuildPower", fmt = "si" },
	buildPowerUse = {
		group = "industry",
		stat = "buildPowerUse",
		short = "shortBuildPowerUse",
		fmt = "percent",
		of = { "buildPowerActive", "buildPower" },
	},
	-- The total sits with the unit counts, so a view showing it alone captions it "Units".
	unitValue = { group = "units", stat = "unitValue", short = "shortValue", fmt = "si", count = "unitCount" },
	valueArmy = { group = "value", stat = "valueArmy", short = "shortArmy", fmt = "si", count = "countArmy" },
	valueAir = { group = "value", stat = "valueAir", short = "shortAir", fmt = "si", count = "countAir" },
	valueSea = { group = "value", stat = "valueSea", short = "shortSea", fmt = "si", count = "countSea" },
	valueDefense = {
		group = "value",
		stat = "valueDefense",
		short = "shortDefense",
		fmt = "si",
		count = "countDefense",
	},
	valueStrategic = {
		group = "value",
		stat = "valueStrategic",
		short = "shortStrategic",
		fmt = "si",
		count = "countStrategic",
	},
	valueFactories = {
		group = "value",
		stat = "valueFactories",
		short = "shortFactories",
		fmt = "si",
		count = "countFactories",
	},
	valueBuilders = {
		group = "value",
		stat = "valueBuilders",
		short = "shortBuilders",
		fmt = "si",
		count = "countBuilders",
	},
	valueEconomy = {
		group = "value",
		stat = "valueEconomy",
		short = "shortEconomy",
		fmt = "si",
		count = "countEconomy",
	},
	valueUtility = {
		group = "value",
		stat = "valueUtility",
		short = "shortUtility",
		fmt = "si",
		count = "countUtility",
	},
	-- Running totals the gadget keeps: what was destroyed and lost, in metal.
	killedValue = { group = "traded", stat = "killedValue", short = "unitsKilled", fmt = "si", rate = true },
	lostValue = { group = "traded", stat = "lostValue", short = "unitsDied", fmt = "si", rate = true },
	valueEfficiency = {
		group = "traded",
		stat = "valueEfficiency",
		short = "shortEfficiency",
		fmt = "percent",
		even = true,
	},
	teamKillValue = { group = "traded", stat = "teamKillValue", short = "shortTeamKill", fmt = "si", rate = true },
	comKills = { group = "commanders", stat = "comKills", short = "unitsKilled", fmt = "si", rate = true },
	comLost = { group = "commanders", stat = "comLost", short = "unitsDied", fmt = "si", rate = true },
}
for key, column in pairs(COLUMNS) do
	column.key = key
end
-- A ratio that is good above even and bad below it: the efficiencies. A level or a
-- share of capacity is neither.
COLUMNS.damageEfficiency.even = true
COLUMNS.killEfficiency.even = true
-- The columns only the team stats gadget can fill. Without it they are left out of the
-- table rather than shown empty; the economy and the conversion the engine tells allies
-- on its own stay.
for _, key in ipairs({
	"buildPower",
	"buildPowerUse",
	"unitValue",
	"killedValue",
	"lostValue",
	"valueEfficiency",
	"teamKillValue",
	"comKills",
	"comLost",
}) do
	COLUMNS[key].gadget = true
end
for _, column in pairs(COLUMNS) do
	if column.group == "value" then
		column.gadget = true
	end
end

-- The column's views: which columns each shows, in order. The first is the overview the
-- panel opens on; the others each take one side of the game and have room for all of it.
local GROUPS = {
	{
		key = "all",
		columns = {
			"damageDealt",
			"damageReceived",
			"damageEfficiency",
			"unitsProduced",
			"unitsKilled",
			"unitsDied",
			"metalProduced",
			"metalExcess",
			"energyProduced",
			"energyExcess",
			"aggressionLevel",
			"actionsPerMinute",
		},
	},
	{
		key = "live",
		columns = {
			"metalIncome",
			"metalExpense",
			"metalLevel",
			"energyIncome",
			"energyExpense",
			"energyLevel",
			"conversion",
			"buildPower",
			"buildPowerUse",
			"unitValue",
			"unitsActive",
		},
	},
	{
		key = "economy",
		columns = {
			"metalProduced",
			"metalUsed",
			"metalExcess",
			"metalSent",
			"metalReceived",
			"metalStored",
			"energyProduced",
			"energyUsed",
			"energyExcess",
			"energySent",
			"energyReceived",
			"energyStored",
		},
	},
	{
		key = "combat",
		columns = {
			"damageDealt",
			"damageReceived",
			"damageEfficiency",
			"unitsKilled",
			"unitsDied",
			"killEfficiency",
			"killedValue",
			"lostValue",
			"valueEfficiency",
			"teamKillValue",
			"comKills",
			"comLost",
		},
	},
	{
		key = "units",
		columns = {
			"unitsProduced",
			"unitsKilled",
			"unitsDied",
			"killEfficiency",
			"unitsCaptured",
			"unitsStolen",
			"unitsReceived",
			"unitsSent",
			"unitsActive",
		},
	},
	{
		key = "composition",
		columns = {
			"unitValue",
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
	},
	{
		key = "activity",
		columns = {
			"actionsPerMinute",
			"aggressionLevel",
			"damageDealt",
			"unitsProduced",
			"metalProduced",
			"energyProduced",
		},
	},
}
local groupByKey = {}
for _, group in ipairs(GROUPS) do
	groupByKey[group.key] = group
end

-- The engine's own counters, which an ally team's total is the sum of. Everything else a
-- row shows is derived from these, for a team and for its ally team alike.
local SUMMED = {
	"metalUsed",
	"metalProduced",
	"metalExcess",
	"metalReceived",
	"metalSent",
	"energyUsed",
	"energyProduced",
	"energyExcess",
	"energyReceived",
	"energySent",
	"damageDealt",
	"damageReceived",
	"unitsProduced",
	"unitsDied",
	"unitsReceived",
	"unitsSent",
	"unitsCaptured",
	"unitsOutCaptured",
	"unitsKilled",
	"actionsPerMinute",
	-- The live amounts, summed the same way; the ratios among them are derived from the
	-- sums. A team the viewer may not see leaves its ally team's total unknown.
	"metalIncome",
	"metalExpense",
	"metalCurrent",
	"metalStorage",
	"energyIncome",
	"energyExpense",
	"energyCurrent",
	"energyStorage",
	"convCapacity",
	"convUse",
	"buildPower",
	"buildPowerActive",
	"unitCount",
	"unitValue",
	"killedValue",
	"killedArmyValue",
	"killedEcoValue",
	"lostValue",
	"teamKillValue",
	"comKills",
	"comLost",
}
-- The composition buckets the gadget counts, each with a count and a value.
for _, bucket in ipairs({ "Army", "Air", "Sea", "Defense", "Strategic", "Factories", "Builders", "Economy", "Utility" }) do
	SUMMED[#SUMMED + 1] = "count" .. bucket
	SUMMED[#SUMMED + 1] = "value" .. bucket
end

-- The header switches, right to left as they are laid out. `groupByTeam` only means
-- something with ally teams to group by, so it is left out of a free-for-all.
---@type table[]
local switches = {
	{ key = "groupByTeam" },
	-- Only offered while there are bands to take a share of.
	{ key = "shareOfTeam" },
	{ key = "perMinute" },
	{ key = "bars" },
}
---@type table<string, boolean>
local filters = { groupByTeam = true, shareOfTeam = false, perMinute = false, bars = false }

-- Excess is waste once it passes a share of what was produced; these say what to compare
-- each excess column with.
local WASTE_OF = { metalExcess = "metalProduced", energyExcess = "energyProduced" }

-- The lines a player's name shows on hover, view by view: every column the panel has,
-- so the ones the open view hides are a hover away. A line with no caption continues the
-- one above it.
local CARD_LINES = {
	{ "damage", { "damageDealt", "damageReceived", "damageEfficiency" } },
	{ "units", { "unitsProduced", "unitsKilled", "unitsDied", "killEfficiency" } },
	{ "", { "unitsCaptured", "unitsStolen", "unitsReceived", "unitsSent", "unitsActive", "unitValue" } },
	{ "traded", { "killedValue", "lostValue", "valueEfficiency", "teamKillValue" } },
	{ "commanders", { "comKills", "comLost" } },
	{ "metal", { "metalProduced", "metalUsed", "metalExcess", "metalSent", "metalReceived", "metalStored" } },
	{ "", { "metalIncome", "metalExpense", "metalLevel" } },
	{ "energy", { "energyProduced", "energyUsed", "energyExcess", "energySent", "energyReceived", "energyStored" } },
	{ "", { "energyIncome", "energyExpense", "energyLevel" } },
	{ "industry", { "conversion", "buildPower", "buildPowerUse" } },
	{ "value", { "valueArmy", "valueAir", "valueSea", "valueDefense", "valueStrategic" } },
	{ "", { "valueFactories", "valueBuilders", "valueEconomy", "valueUtility" } },
	{ "activity", { "aggressionLevel", "actionsPerMinute" } },
}

----------------------------------------------------------------
-- Layout and look
----------------------------------------------------------------

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the other
-- panels hold their own.
local metrics = {
	rowHeight = 24,
	rowFs = 13,
	-- An ally team's band stands taller than the rows under it and is set larger, so it
	-- reads as a divider rather than another row.
	bandRowHeight = 32,
	bandFs = 14,
	-- The two rows of the table header: the group captions spanning their columns, and
	-- the stat captions under them that sort when clicked.
	groupRowHeight = 22,
	groupFs = 13,
	statRowHeight = 24,
	statFs = 12,
	catRowHeight = 29,
	catFs = 13,
	-- The rule in the column between the views and the pages.
	dividerH = 14,
	rowPad = 6,
	-- Room a number keeps from the right edge of its cell; the sort marker sits in it.
	cellPad = 7,
	sidePad = 12,
	catInset = 4,
	-- The bar of team colour down a row's left edge, and how far it stops short of the
	-- rows above and below so each reads as its own.
	accentW = 3,
	accentPad = 3,
	-- The bar behind a number, inside its row by this much top and bottom.
	barInset = 4,
	-- The line along the bottom of a group caption and of an ally team's band.
	underlineH = 2,
	-- Everything that sits against the panel's right edge - the switches and the
	-- scrollbar - is held off it by this much.
	edgeInset = 4,
	-- The band the title and the switches share, and the gap below.
	headerH = 34,
	headerGap = 4,
	-- Clearance between the table header and the first row.
	tableGap = 4,
	-- Clearance between the right edge of the rows and the scrollbar beside them.
	listGap = 12,
	-- How far the column's card rises above the first entry in it.
	cardLip = 5,
	-- The panel title: its baseline below the top edge, and its size.
	titleY = 17,
	titleFs = 20,
	-- How far the column starts below the table beside it, to leave the title room.
	sidebarDrop = 8,
	sidebarW = 190,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- The name column: never narrower than this, and otherwise this share of the table.
	nameMinW = 150,
	nameShare = 0.2,
	-- The sort marker beside the caption of the sorted column.
	triW = 5,
	triH = 4,
	toggleFs = 13,
	captionBleed = 3,
	switchGap = 16,
	-- Corner radii, taken from FlowUI's so the panel rounds like the rest of the UI.
	csSmall = 2,
	csPanel = 4,
	-- Filled in by the layout.
	nameIndent = 0,
	bandTop = 0,
	groupTop = 0,
	groupBottom = 0,
	statTop = 0,
	statBottom = 0,
}
local look = {
	-- The column sits on its own darker card, so it reads apart from the table.
	sidebarFill = { 0, 0, 0, 0.24 },
	sidebarFillTop = { 0, 0, 0, 0.16 },
	selectedFill = { 1, 1, 1, 0.13 },
	white = { 1, 1, 1 },
	-- Rows, entries and captions hover with the same FlowUI highlight the settings list
	-- uses, at the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- Underline under a group caption and an ally team's band: a thin bar fading up out
	-- of the bottom edge, in the hue of the caption above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	sheenTop = { 1, 1, 1, 0.05 },
	-- The rule closing the table header off from the rows, and the one in the column.
	rule = { 1, 1, 1, 0.08 },
	-- The bar behind a number, scaled to the column's largest.
	barFill = { 1, 1, 1, 0.07 },
	-- Every second team row under a band takes this, so the eye keeps its line across a
	-- dozen columns. Faint: it is a guide, not a highlight.
	stripeFill = { 1, 1, 1, 0.035 },
	-- The sort marker.
	sortMark = { 0.92, 0.73, 0.27, 0.9 },
	-- The font is shared with every other widget, and whichever of them set its outline
	-- last is what a bake would freeze in; pinned after every Begin, the way the keybind
	-- editor and the widget selector pin theirs.
	outline = { 0, 0, 0, 0.4 },
	-- The sorted column, tinted down its length in the hue of its caption, so the eye
	-- follows the values the table is ordered by.
	sortedFill = { 1, 0.78, 0.51, 0.04 },
	-- Excess above this share of what was produced reads as waste.
	wasteShare = 0.1,
}
local colorTitle = "\255\235\235\235"
local colorHeader = "\255\255\200\130"
local colorKey = "\255\235\185\070"
local colorName = "\255\235\235\235"
local colorValue = "\255\215\212\208"
-- An ally team's totals in its band: lighter than a player's numbers, since they sit on
-- the band's own sheen, and not the warm of the caption beside them.
local colorTotal = "\255\225\222\218"
local colorSelected = "\255\210\210\205"
local colorDim = "\255\160\160\160"
-- An entry that cannot be opened: dimmer than the dim used for ordinary secondary text,
-- since it has to read as unavailable rather than merely quiet.
local colorFaded = "\255\115\115\115"
-- A ratio that came out ahead and one that did not: damage or kills traded above or below
-- even, and excess that wasted a real share of what was produced.
local colorGood = "\255\150\220\150"
local colorBad = "\255\235\135\120"

-- The captions, in the language of the last load.
---@type table<string, any>
local L = {}

---@type boolean?, boolean?
local show, showOnceMore
---@type integer?, integer?, integer?, string?
local panelList, windowList, backgroundGuishader, panelSig
---@type number, number, number, number, number
local listTop, listBottom, listX1, listRight, barX1 = 0, 0, 0, 0, 0

-- The column's entries: the views, then a rule, then the pages.
---@type table[]
local entries = {}
local selectedGroup = "all"
-- The columns the table shows right now, each with the x range it takes, and the group
-- captions spanning them.
---@type table[]
local columns = {}
---@type table[]
local spans = {}

-- What the panel shows: every ally team with its teams and their totals, and the rows the
-- table makes of them under the current sort and grouping.
---@type table[]
local allies = {}
---@type table[]
local rows = {}
-- Bumped by rebuildRows, so the baked panel knows the list behind it changed.
local rowsGen = 0
-- Bumped by the layout. A cached row layout carries the value it was built against and
-- is measured again when it moves, without every row being walked at resize.
local layoutGen = 0
---@type table<string, number>
local rowMetrics = { gen = -1, rows = -1, totalH = 0 }
-- The largest value each column shows, for the bars.
---@type table<string, number?>
local colMax = {}
local scroll = 0
---@type boolean
local dragging = false
-- Where the thumb was taken hold of, as the distance from the cursor to its top edge.
---@type number
local dragGrab = 0
local sortKey = "damageDealt"
---@type boolean
local sortAscending = false
-- What the cursor is over, in the terms the baked panel is painted with. Refilled in
-- place each frame rather than allocated.
---@type table<string, integer>
local hover = { sb = 0, row = 0, col = 0, hcol = 0, tog = 0, bar = 0 }

local teamAPM = {}
-- What the team stats gadget last handed over: the live values of every team the
-- viewer may see, keyed by team, and the frame it did so. A gadget cannot be called
-- from a widget, so the panel registers a receiver while it is open and the gadget
-- calls it every second; after `stale` frames without, the values count as gone rather
-- than old, and the table falls back to what the engine tells allies on its own.
-- `postGame` asks for one more read after game over, so the other side's live values
-- show once they may. `on` is whether the gadget is taken to be there: yes until the
-- panel has been open (`opened`) for `stale` frames without a hand-over, or the
-- hand-overs stop; while it is not, the gadget's columns, views and the history page
-- are left out of the panel rather than shown empty.
---@type table<string, any>
local handover = { all = nil, frame = nil, opened = nil, stale = UPDATE_FRAMES * 3, postGame = false, on = true }
-- The last name seen for each team, for a player who has since left.
local teamControllers = {}
-- The frame each team died on, so a rate is over the time the team was in the game.
local deathFrame = {}
---@type boolean
local gameover = false

local isFFA = BAR.Utilities.Gametype.IsFFA()
local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {
	Spring.GetConfigInt("anonymousColorR", 255) / 255,
	Spring.GetConfigInt("anonymousColorG", 0) / 255,
	Spring.GetConfigInt("anonymousColorB", 0) / 255,
}
local isSpec = spGetSpectatingState()
local localTeamID = spGetLocalTeamID()

-- Text is queued while the panel is baked and printed in one Begin/End at the end.
local pending = {}
local pendingCount = 0

---@type function
local rebuildRows

----------------------------------------------------------------
-- Numbers
----------------------------------------------------------------

-- Not a number: what a cell shows as "-" and sorts last. A value the viewer may not see,
-- or a ratio with nothing under it.
local NAN = 0 / 0

local function known(v)
	return v ~= nil and v == v
end

-- The percentages a row derives from two amounts, in one table: the file is near Lua's
-- limit on locals.
local ratio = {}

-- `a` as a percentage of `b`; unknown when either is, or when there is no `b` to be a
-- share of.
ratio.share = function(a, b)
	if not known(a) or not known(b) or b == 0 then
		return NAN
	end
	return a / b * 100
end

-- Like share, but nothing in nothing is empty rather than unknown.
ratio.level = function(a, b)
	if not known(a) or not known(b) then
		return NAN
	end
	if b == 0 then
		return 0
	end
	return a / b * 100
end

-- Traded above or below even; something destroyed for nothing lost is infinitely good.
ratio.efficiency = function(killed, lost)
	if not known(killed) or not known(lost) then
		return NAN
	end
	if lost == 0 then
		return killed > 0 and mathHuge or NAN
	end
	return killed / lost * 100
end

-- Ratios and levels, from the counters they are made of. Run for a team and for an ally
-- team's total alike, so a band's efficiency is the efficiency of its sums.
local function derive(s)
	s.metalStored = s.metalProduced + s.metalReceived - (s.metalUsed + s.metalSent + s.metalExcess)
	s.energyStored = s.energyProduced + s.energyReceived - (s.energyUsed + s.energySent + s.energyExcess)
	s.unitsStolen = s.unitsOutCaptured
	s.unitsActive = s.unitsProduced
		+ s.unitsReceived
		+ s.unitsCaptured
		- (s.unitsDied + s.unitsSent + s.unitsOutCaptured)
	if s.damageReceived ~= 0 then
		s.damageEfficiency = (s.damageDealt / s.damageReceived) * 100
	else
		s.damageEfficiency = mathHuge
	end
	if s.unitsDied ~= 0 then
		s.killEfficiency = (s.unitsKilled / s.unitsDied) * 100
	else
		s.killEfficiency = mathHuge
	end
	-- Energy counts at a sixtieth of metal, the game's usual exchange.
	local resources = s.metalProduced + s.metalReceived + (s.energyProduced + s.energyReceived) / 60
	if resources ~= 0 and s.damageDealt ~= 0 then
		s.aggressionLevel = mathFloor(10 * mathLog10(s.damageDealt / resources) + 0.5)
	else
		s.aggressionLevel = -mathHuge
	end
	-- The live ratios, from amounts that can be unknown: a team the viewer may not see
	-- has none, and its ally team's sums are unknown with it.
	s.metalLevel = ratio.level(s.metalCurrent, s.metalStorage)
	s.energyLevel = ratio.level(s.energyCurrent, s.energyStorage)
	s.conversion = ratio.share(s.convUse, s.convCapacity)
	s.buildPowerUse = ratio.share(s.buildPowerActive, s.buildPower)
	s.valueEfficiency = ratio.efficiency(s.killedValue, s.lostValue)
end

local function isFinite(v)
	return v == v and v ~= mathHuge and v ~= -mathHuge
end

-- A number as a cell shows it: whole below a thousand, with a prefix above it, and one
-- decimal when it is small enough for that to be all there is - a rate can be.
local function formatNumber(v)
	if not isFinite(v) then
		return "-"
	end
	local a = mathAbs(v)
	if a < 0.05 then
		return "0"
	end
	if a < 10 then
		local s = stringFormat("%.1f", v)
		return (s:gsub("%.0$", ""))
	end
	if a < 1000 then
		return stringFormat("%d", mathFloor(v + 0.5))
	end
	return formatSI(v) or stringFormat("%.0f", v)
end

-- `share` prints an amount as the percentage the share switch turned it into.
local function formatCell(column, v, share)
	if column.fmt == "percent" or share then
		if not isFinite(v) then
			return "-"
		end
		return stringFormat("%d%%", mathFloor(v + 0.5))
	elseif column.fmt == "plain" then
		if not isFinite(v) then
			return "-"
		end
		return stringFormat("%d", mathFloor(v + 0.5))
	end
	return formatNumber(v)
end

-- The whole number with its thousands marked off, for the tooltip: a cell rounds to
-- three figures.
local function formatWhole(v)
	local a = mathAbs(v)
	if a < 100 and mathAbs(a - mathFloor(a + 0.5)) > 0.05 then
		return stringFormat("%.1f", v)
	end
	local s = stringFormat("%d", mathFloor(a + 0.5))
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return (v < 0 and "-" or "") .. s
end

local function formatExact(column, v)
	if not isFinite(v) then
		return "-"
	end
	if column.fmt == "percent" then
		return stringFormat("%.1f%%", v)
	end
	return formatWhole(v)
end

-- What a cell's number is made of, for its tooltip: the units behind a value, or the two
-- amounts behind a percentage. Nothing when they are not known.
local function cellDetail(column, stats)
	if column.count then
		local n = stats[column.count]
		if known(n) then
			local key = n == 1 and "ui.teamStats.unitOne" or "ui.teamStats.unitCount"
			return BAR.I18N(key, { count = formatWhole(n) })
		end
	elseif column.of then
		local a, b = stats[column.of[1]], stats[column.of[2]]
		if known(a) and known(b) then
			return BAR.I18N("ui.teamStats.ofTotal", { value = formatWhole(a), total = formatWhole(b) })
		end
	end
	return nil
end

local function gameTime(frames)
	return stringFormat("%d:%02d", mathFloor(frames / 1800), mathFloor(frames / 30) % 60)
end

-- Whether the table has ally teams to show: the grouping switch, in a game with sides.
local function grouped()
	return filters.groupByTeam and not isFFA
end

-- Whether amounts are shown as each player's share of their ally team's.
local function shareMode()
	return filters.shareOfTeam and grouped()
end

-- A team's counter, or the rate it makes over the team's time in the game when the
-- switch asks for one.
local function baseValue(column, team)
	local v = team.stats[column.key]
	if v == nil then
		return NAN
	end
	if filters.perMinute and column.rate then
		return v / team.minutes
	end
	return v
end

-- What an ally team's band shows: the total, or the sum of its teams' rates, since each
-- was in the game for its own time.
local function bandValue(column, ally)
	if filters.perMinute and column.rate then
		local sum = 0
		for i = 1, #ally.teams do
			sum = sum + baseValue(column, ally.teams[i])
		end
		return sum
	end
	return ally.total[column.key]
end

-- What a team's cell shows: the counter or rate, or under the share switch the share of
-- what its band shows, so the two agree whatever the other switches say. Ratios and
-- levels have no share.
local function cellValue(column, team)
	local v = baseValue(column, team)
	if filters.shareOfTeam and column.fmt == "si" and team.ally and grouped() then
		local total = bandValue(column, team.ally)
		if total ~= 0 then
			return v / total * 100
		end
		return 0
	end
	return v
end

-- The colour a value earns, or nil for the plain one: a ratio above even is good and
-- below it bad, and excess past a share of what was produced is waste.
local function tone(column, stats, v)
	if column.fmt == "percent" then
		if not column.even or not isFinite(v) or mathAbs(v - 100) < 0.5 then
			return nil
		end
		return v > 100 and colorGood or colorBad
	end
	local produced = WASTE_OF[column.key]
	if produced and stats[produced] > 0 and stats[column.key] / stats[produced] > look.wasteShare then
		return colorBad
	end
	return nil
end

----------------------------------------------------------------
-- The data
----------------------------------------------------------------

-- `live` is what the team stats gadget says about the team right now, when it is running
-- and the viewer may see the team.
local function readTeam(teamID, allyID, frame, live)
	local count = spGetTeamStatsHistory(teamID)
	local history = count and spGetTeamStatsHistory(teamID, count)
	local s = history and history[#history]
	if not s then
		return nil
	end
	-- The engine's entry, with everything else the row shows added to it.
	---@cast s table
	s.actionsPerMinute = teamAPM[teamID] or 0
	local milestones
	if live then
		for key, v in pairs(live) do
			if key ~= "milestones" and key ~= "dead" then
				s[key] = v
			end
		end
		milestones = live.milestones
	else
		-- Without the gadget the engine still tells allies their economy, and the
		-- conversion gadget its use of the converters.
		local current, storage, _, income, expense = Spring.GetTeamResources(teamID, "metal")
		if current then
			s.metalCurrent, s.metalStorage, s.metalIncome, s.metalExpense = current, storage, income, expense
			current, storage, _, income, expense = Spring.GetTeamResources(teamID, "energy")
			s.energyCurrent, s.energyStorage, s.energyIncome, s.energyExpense = current, storage, income, expense
			s.convCapacity = Spring.GetTeamRulesParam(teamID, "mmCapacity")
			s.convUse = Spring.GetTeamRulesParam(teamID, "mmUse")
		end
	end
	derive(s)

	local _, leader, isDead = spGetTeamInfo(teamID, false)
	local name, isActive = spGetPlayerInfo(leader, false)
	if WG.playernames and WG.playernames.getPlayername then
		name = WG.playernames.getPlayername(leader) or name
	end
	local aiName = spGetGameRulesParam("ainame_" .. teamID)
	if aiName then
		name = tostring(aiName)
	end
	if name then
		teamControllers[teamID] = name
	else
		name = teamControllers[teamID] or ""
	end
	local gone = not isActive
	local label = name
	if isDead == true then
		label = BAR.I18N("ui.teamStats.dead", { player = name })
	elseif gone then
		label = BAR.I18N("ui.teamStats.gone", { player = name })
	end

	local r, g, b
	if not isSpec and anonymousMode ~= "disabled" and teamID ~= localTeamID then
		r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	else
		r, g, b = spGetTeamColor(teamID)
	end

	-- A rate is over the time the team was in the game, and never over less than a
	-- minute, or the first seconds would show rates of thousands.
	local alive = deathFrame[teamID] and mathMin(deathFrame[teamID], frame) or frame
	return {
		id = teamID,
		allyID = allyID,
		stats = s,
		name = name,
		sortName = stringLower(name),
		label = label,
		accent = { r, g, b, isDead and 0.35 or 0.9 },
		dead = isDead,
		gone = gone,
		isLocal = not isSpec and teamID == localTeamID,
		aliveFrames = alive,
		minutes = mathMax(alive, 1800) / 1800,
		milestones = milestones,
	}
end

-- Reads every team's newest stats and the names, colours and states beside them.
local function refreshStats()
	local frame = spGetGameFrame()
	local gaia = spGetGaiaTeamID()
	localTeamID = spGetLocalTeamID()
	-- The gadget's last hand-over, unless it has gone quiet.
	local live = handover.all
	if live and frame - handover.frame > handover.stale then
		live = nil
	end
	allies = {}
	for _, allyID in ipairs(spGetAllyTeamList()) do
		local ally = { id = allyID, teams = {}, total = {} }
		local teamList = spGetTeamList(allyID)
		---@cast teamList -?
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaia then
				local team = readTeam(teamID, allyID, frame, live and live[teamID])
				if team then
					team.ally = ally
					ally.teams[#ally.teams + 1] = team
					for i = 1, #SUMMED do
						local key = SUMMED[i]
						local v = team.stats[key]
						local total = ally.total[key]
						-- A member's unknown makes the total unknown, and keeps it so.
						if v == nil then
							ally.total[key] = NAN
						elseif total == nil then
							ally.total[key] = v
						else
							ally.total[key] = total + v
						end
					end
				end
			end
		end
		if #ally.teams > 0 then
			derive(ally.total)
			allies[#allies + 1] = ally
		end
	end
	rebuildRows()
end

----------------------------------------------------------------
-- The rows
----------------------------------------------------------------

local function compareTeams(a, b)
	if sortKey == "name" then
		if a.sortName ~= b.sortName then
			if sortAscending then
				return a.sortName < b.sortName
			end
			return a.sortName > b.sortName
		end
		return a.id < b.id
	end
	if a.sortVal ~= b.sortVal then
		if sortAscending then
			return a.sortVal < b.sortVal
		end
		return a.sortVal > b.sortVal
	end
	return a.id < b.id
end

local function compareAllies(a, b)
	if sortKey ~= "name" and a.sortVal ~= b.sortVal then
		if sortAscending then
			return a.sortVal < b.sortVal
		end
		return a.sortVal > b.sortVal
	end
	return a.id < b.id
end

-- Sorts the teams inside their ally teams and the ally teams by their totals, then lays
-- them out as rows: a band per ally team with its teams under it, or one flat list.
rebuildRows = function()
	rows = {}
	rowsGen = rowsGen + 1
	local column = COLUMNS[sortKey] or COLUMNS.damageDealt

	-- An unknown sorts below everything; as itself it would compare as nothing and break
	-- the order.
	local function sortable(v)
		if v ~= v then
			return -mathHuge
		end
		return v
	end
	for i = 1, #allies do
		local ally = allies[i]
		for j = 1, #ally.teams do
			local team = ally.teams[j]
			team.sortVal = column.fmt ~= "name" and sortable(cellValue(column, team)) or 0
		end
		tableSort(ally.teams, compareTeams)
		ally.sortVal = column.fmt ~= "name" and sortable(bandValue(column, ally)) or 0
	end
	tableSort(allies, compareAllies)

	if grouped() then
		for i = 1, #allies do
			local ally = allies[i]
			rows[#rows + 1] = { type = "band", ally = ally }
			for j = 1, #ally.teams do
				-- Striped by place under the band, so the pattern starts afresh with each
				-- ally team rather than running on across its band.
				rows[#rows + 1] = { type = "team", team = ally.teams[j], stripe = j % 2 == 0 }
			end
		end
	else
		local teams = {}
		for i = 1, #allies do
			local ally = allies[i]
			for j = 1, #ally.teams do
				teams[#teams + 1] = ally.teams[j]
			end
		end
		tableSort(teams, compareTeams)
		for i = 1, #teams do
			rows[#rows + 1] = { type = "team", team = teams[i], stripe = i % 2 == 0 }
		end
	end

	-- The bars are scaled to the largest a column shows among the teams, whatever view
	-- is open, so switching views does not walk the rows again.
	colMax = {}
	for key, col in pairs(COLUMNS) do
		if col.fmt ~= "name" and col.fmt ~= "plain" then
			local top = 0
			for i = 1, #allies do
				local ally = allies[i]
				for j = 1, #ally.teams do
					local v = cellValue(col, ally.teams[j])
					if isFinite(v) and v > top then
						top = v
					end
				end
			end
			colMax[key] = top
		end
	end
end

local function rowHeightOf(row)
	if row.type == "band" then
		return metrics.bandRowHeight
	end
	return metrics.rowHeight
end

-- A row's position is a sum of what is above it rather than its index times one height:
-- a band is not the height of an ordinary row. The running total is stamped onto the
-- rows, and redone when the list or the layout changes.
local function ensureRowMetrics()
	if rowMetrics.gen == layoutGen and rowMetrics.rows == rowsGen then
		return
	end

	local off = 0
	for i = 1, #rows do
		rows[i].off = off
		off = off + rowHeightOf(rows[i])
	end
	rowMetrics.totalH = off
	rowMetrics.gen, rowMetrics.rows = layoutGen, rowsGen
end

-- Pixels of content above the first painted row.
local function scrollOffset()
	ensureRowMetrics()
	local first = rows[scroll + 1]

	return first and first.off or 0
end

-- Furthest offset that still fills the band. Walked from the end, so it does not depend
-- on where the list is scrolled to now.
local function maxScroll()
	ensureRowMetrics()
	local band = listTop - listBottom
	local used = 0
	local i = #rows
	while i > 0 do
		local h = rowHeightOf(rows[i])
		if used + h > band then
			break
		end
		used = used + h
		i = i - 1
	end

	return i
end

local function clampScroll()
	local top = maxScroll()
	if scroll > top then
		scroll = top
	end
	if scroll < 0 then
		scroll = 0
	end
end

local function setScroll(n)
	scroll = n
	clampScroll()
end

-- The painted row under y, as its offset from the first painted one. Every hover test and
-- the panel signature go through this, so neither can disagree with what was drawn. nil
-- when y is outside the band or past the last whole row the band can hold.
local function rowAt(y)
	ensureRowMetrics()
	if y > listTop or y <= listBottom then
		return nil
	end

	local base = scrollOffset()
	for i = scroll + 1, #rows do
		local top = listTop - (rows[i].off - base)
		local bottom = top - rowHeightOf(rows[i])
		if bottom < listBottom then
			break
		end
		-- Half-open on the shared edge: rows stack, so one row's top is the next one's
		-- bottom and a closed test would put the cursor in both.
		if y <= top and y > bottom then
			return i - scroll
		end
	end

	return nil
end

-- The column under x, or nil outside the table. Half-open on the shared edge.
local function columnAt(x)
	for i = 1, #columns do
		local c = columns[i]
		if x >= c.x1 and x < c.x2 then
			return i
		end
	end

	return nil
end

----------------------------------------------------------------
-- The scrollbar
----------------------------------------------------------------

local function scrollerThumb()
	return UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, listTop, rowMetrics.totalH, scrollOffset())
end

-- Scrolls so the thumb's top sits where the cursor has dragged it. The offset taken at the
-- grab is what keeps this relative: the thumb moves with the cursor rather than centring
-- itself on it, so taking hold of it does not shift the view before the drag begins.
local function scrollFromY(y)
	local _, _, trackTop, travel = scrollerThumb()
	if not travel or travel <= 0 then
		return
	end

	local f = (trackTop - (y - dragGrab)) / travel
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end
	setScroll(mathFloor(f * maxScroll() + 0.5))
end

-- Takes hold of the bar. On the thumb that is a grab, and the view stays where it is; on
-- the track either side of it the thumb jumps to the cursor first and is then dragged from
-- its middle, which is what a press on empty track is asking for.
local function grabScroller(y)
	local top, height = scrollerThumb()
	if not top then
		return
	end

	dragging = true
	if y <= top and y >= top - height then
		dragGrab = y - top
	else
		dragGrab = -mathFloor(height * 0.5)
		scrollFromY(y)
	end
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

-- The column starts below where the table does, so the title above it is not crowded by
-- the first entry. Everything in the column measures from here.
local function sidebarTop()
	return metrics.bandTop - metrics.sidebarDrop
end

local function entryRect(i)
	local top = sidebarTop()
	for j = 1, i - 1 do
		local e = entries[j]
		---@cast e -?
		top = top - (e.divider and metrics.dividerH or metrics.catRowHeight)
	end
	local h = entries[i].divider and metrics.dividerH or metrics.catRowHeight

	return area.x1, top - h, area.x1 + metrics.sidebarW, top
end

-- The entry under x,y, or nil. The rule between the views and the pages is not one.
local function sidebarIndexAt(x, y)
	if x < area.x1 or x > area.x1 + metrics.sidebarW then
		return nil
	end
	for i = 1, #entries do
		local _, y1, _, y2 = entryRect(i)
		if y <= y2 and y > y1 then
			if entries[i].divider then
				return nil
			end
			return i
		end
	end

	return nil
end

local function switchAt(x, y)
	for i = 1, #switches do
		local hit = switches[i].hit
		if hit and math_isInRect(x, y, hit[1], hit[2], hit[3], hit[4]) then
			return i
		end
	end

	return nil
end

-- The stat caption under x,y, which sorts the table when clicked.
local function headerColumnAt(x, y)
	if y > metrics.statTop or y <= metrics.statBottom then
		return nil
	end

	return columnAt(x)
end

-- The columns the open view shows, each given its x range: the name column takes its
-- share and the numeric ones split the rest evenly, with the leftover pixels going to the
-- name so the last column ends exactly at the table's right edge.
local function layoutColumns()
	local group = groupByKey[selectedGroup] or GROUPS[1]
	columns = { COLUMNS.name }
	for i = 1, #group.columns do
		local c = COLUMNS[group.columns[i]]
		if handover.on or not c.gadget then
			columns[#columns + 1] = c
		end
	end

	local tableW = listRight - listX1
	local n = #columns - 1
	---@type number
	local nameW = mathMax(metrics.nameMinW, mathFloor(tableW * metrics.nameShare))
	local colW = mathFloor((tableW - nameW) / n)
	nameW = tableW - colW * n

	local x = listX1
	for i = 1, #columns do
		local c = columns[i]
		c.x1 = x
		c.x2 = x + (i == 1 and nameW or colW)
		x = c.x2
		-- The caption takes the whole cell: the sort marker sits in the cell's padding, so
		-- it never takes room from the caption when the column is the sorted one.
		local room = c.x2 - c.x1 - metrics.cellPad * 2
		if i == 1 then
			room = c.x2 - c.x1 - metrics.nameIndent - metrics.cellPad - metrics.triW - metrics.rowPad
		end
		c.fitStat = text.fit(font, L.stat[c.key], room, metrics.statFs)
		c.statW = mathFloor(font:GetTextWidth(c.fitStat) * metrics.statFs)
	end

	-- Neighbouring columns with the same group share one caption over them.
	spans = {}
	---@type table?
	local span
	for i = 2, #columns do
		local c = columns[i]
		if span and span.group == c.group then
			span.x2 = c.x2
			span.rate = span.rate or c.rate
		else
			span = { group = c.group, x1 = c.x1, x2 = c.x2, rate = c.rate }
			spans[#spans + 1] = span
		end
	end
	for i = 1, #spans do
		local s = spans[i]
		local label = L.caption[s.group] or s.group
		if filters.perMinute and s.rate then
			label = label .. L.perMinuteSuffix
		end
		s.label = text.fit(font, label, s.x2 - s.x1 - metrics.cellPad * 2, metrics.groupFs)
	end

	layoutGen = layoutGen + 1
	clampScroll()
end

-- Rebuilds every rect against the panel size. Whole pixels throughout, so glyph and
-- rectangle edges do not land between pixels.
local function setLayout()
	local s = widgetScale
	local pad = mathFloor(8 * s)
	area.x1 = screenX + pad
	area.y1 = screenY - screenHeight + pad
	area.x2 = screenX + screenWidth - pad
	area.y2 = screenY - pad

	metrics.rowHeight = mathFloor(24 * s)
	metrics.rowFs = mathFloor(metrics.rowHeight * 0.55)
	metrics.bandRowHeight = mathFloor(metrics.rowHeight * 1.35)
	metrics.bandFs = mathFloor(metrics.rowFs * 0.95 * 1.13)
	metrics.groupRowHeight = mathFloor(22 * s)
	metrics.groupFs = metrics.rowFs
	metrics.statRowHeight = metrics.rowHeight
	metrics.statFs = mathFloor(metrics.rowFs * 0.92)
	metrics.catRowHeight = mathFloor(29 * s)
	metrics.catFs = mathFloor(metrics.catRowHeight * 0.55 * 0.85)
	metrics.dividerH = mathFloor(14 * s)
	metrics.rowPad = mathFloor(6 * s)
	metrics.cellPad = mathFloor(7 * s)
	metrics.sidePad = mathFloor(12 * s)
	metrics.catInset = mathFloor(4 * s)
	metrics.accentW = mathMax(2, mathFloor(3 * s))
	metrics.accentPad = mathMax(1, mathFloor(3 * s))
	metrics.barInset = mathMax(2, mathFloor(4 * s))
	metrics.underlineH = mathMax(1, mathFloor(2 * s))
	metrics.edgeInset = mathFloor(4 * s)
	metrics.headerH = mathFloor(34 * s)
	metrics.headerGap = mathFloor(4 * s)
	metrics.tableGap = mathFloor(4 * s)
	metrics.listGap = mathFloor(12 * s)
	metrics.cardLip = mathFloor(5 * s)
	metrics.titleY = mathFloor(17 * s)
	metrics.titleFs = mathFloor(metrics.rowHeight * 0.85)
	metrics.sidebarDrop = mathFloor(8 * s)
	metrics.sidebarW = mathFloor(190 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.nameMinW = mathFloor(150 * s)
	-- Narrower than the cell padding it sits in.
	metrics.triW = mathMax(4, mathFloor(5 * s))
	metrics.triH = mathMax(3, mathFloor(4 * s))
	metrics.switchGap = mathFloor(16 * s)
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)
	metrics.nameIndent = metrics.accentW + metrics.rowPad * 2

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	metrics.bandTop = area.y2 - metrics.headerH - metrics.headerGap
	-- The table header: group captions, then the stat captions, then a gap to the rows.
	metrics.groupTop = metrics.bandTop
	metrics.groupBottom = metrics.groupTop - metrics.groupRowHeight
	metrics.statTop = metrics.groupBottom
	metrics.statBottom = metrics.statTop - metrics.statRowHeight
	listTop = metrics.statBottom - metrics.tableGap
	listBottom = area.y1 + metrics.edgeInset
	-- The scrollbar owns a column of its own: its right edge lines up with the switches
	-- above it, and the rows stop a clear gap short of it rather than running up against
	-- it, so the bar sits in a channel rather than hugging them.
	barX1 = area.x2 - metrics.edgeInset - metrics.barW
	listRight = barX1 - metrics.listGap

	-- The header band: the switches, right to left from the panel's edge. A switch this
	-- small is a poor click target on its own, so its caption is part of it and the hover
	-- covers both.
	local rowTop = area.y2 - mathFloor(4 * s)
	local rowBottom = area.y2 - metrics.headerH + mathFloor(4 * s)
	local togW = mathFloor(38 * s)
	local togH = mathFloor((rowTop - rowBottom) * 0.62)
	local togY = mathFloor((rowTop + rowBottom) * 0.5)
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	-- Outlined text spreads past the box it is measured in, so the caption side gets back
	-- the room its outline took.
	metrics.captionBleed = mathFloor(metrics.toggleFs * 0.2 + 0.5)
	---@type number
	local x2 = area.x2 - metrics.edgeInset
	for i = #switches, 1, -1 do
		local sw = switches[i]
		if (sw.key == "groupByTeam" and isFFA) or (sw.key == "shareOfTeam" and not grouped()) then
			sw.draw, sw.hit = nil, nil
		else
			local labelW = mathFloor(font:GetTextWidth(sw.label) * metrics.toggleFs)
			sw.draw = { x2 - togW, togY - mathFloor(togH * 0.5), x2, togY - mathFloor(togH * 0.5) + togH }
			sw.hit = {
				sw.draw[1] - metrics.rowPad * 2 - labelW - metrics.captionBleed,
				rowBottom,
				x2 + metrics.rowPad,
				rowTop,
			}
			x2 = sw.hit[1] - metrics.switchGap
		end
	end

	layoutColumns()
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

local function queueText(str, x, y, size, opts)
	local at = pendingCount * 5
	pending[at + 1] = str
	pending[at + 2] = x
	pending[at + 3] = y
	pending[at + 4] = size
	pending[at + 5] = opts
	pendingCount = pendingCount + 1
end

local function flushText()
	if pendingCount == 0 then
		return
	end

	font:Begin()
	font:SetOutlineColor(look.outline)
	for i = 0, pendingCount - 1 do
		local at = i * 5
		font:Print(pending[at + 1], pending[at + 2], pending[at + 3], pending[at + 4], pending[at + 5])
	end
	font:End()

	pendingCount = 0
end

-- The sort marker: a small triangle pointing the way the column is sorted.
---@type number, number, number, number, boolean
local triX, triY, triW, triH, triUp = 0, 0, 0, 0, false
local function triangleVertices()
	if triUp then
		glVertex(triX, triY)
		glVertex(triX + triW, triY)
		glVertex(triX + triW * 0.5, triY + triH)
	else
		glVertex(triX, triY + triH)
		glVertex(triX + triW, triY + triH)
		glVertex(triX + triW * 0.5, triY)
	end
end

local function drawSortMark(x, cy)
	triX, triY, triW, triH, triUp = x, cy - mathFloor(metrics.triH * 0.5), metrics.triW, metrics.triH, sortAscending
	glColor(look.sortMark)
	glBeginEnd(GL_TRIANGLES, triangleVertices)
	glColor(1, 1, 1, 1)
end

-- What a row shows, fitted to the columns. Cached on the row and redone when the
-- columns move: the rows themselves are rebuilt whenever the values behind them change.
local function fitRow(row)
	if row.fitGen == layoutGen then
		return
	end
	row.fitGen = layoutGen
	row.cells = {}
	row.vals = {}
	row.tones = {}

	local nameColumn = columns[1]
	---@cast nameColumn -?
	if row.type == "team" then
		local team = row.team
		local share = shareMode()
		local room = nameColumn.x2 - nameColumn.x1 - metrics.nameIndent - metrics.cellPad
		row.fitName = text.fit(font, team.label, room, metrics.rowFs)
		for i = 2, #columns do
			local c = columns[i]
			local v = cellValue(c, team)
			row.vals[i] = v
			row.cells[i] = formatCell(c, v, share and c.fmt == "si")
			row.tones[i] = tone(c, team.stats, v)
		end
	else
		local ally = row.ally
		local caption = BAR.I18N("ui.teamStats.team", { number = ally.id + 1 })
		local members = #ally.teams == 1 and L.memberOne or BAR.I18N("ui.teamStats.members", { count = #ally.teams })
		local room = nameColumn.x2 - nameColumn.x1 - metrics.rowPad * 2
		row.caption = text.fit(font, caption, room, metrics.bandFs)
		row.captionW = mathFloor(font:GetTextWidth(row.caption) * metrics.bandFs)
		-- The count goes after the caption when it fits beside it, and is dropped when
		-- not: cut short it would say nothing.
		local left = room - row.captionW - metrics.rowPad * 2
		if font:GetTextWidth(members) * metrics.rowFs <= left then
			row.members = members
		else
			row.members = nil
		end
		for i = 2, #columns do
			local c = columns[i]
			local v = bandValue(c, ally)
			row.vals[i] = v
			row.cells[i] = formatCell(c, v)
			row.tones[i] = tone(c, ally.total, v)
		end
	end
end

local function drawBand(row, top, bottom)
	RectRound(
		listX1,
		bottom,
		listRight,
		top - metrics.csSmall,
		metrics.csSmall,
		1,
		1,
		0,
		0,
		look.sheenTop,
		look.sheenTop
	)
	RectRound(
		listX1,
		bottom,
		listRight,
		bottom + metrics.underlineH,
		0,
		0,
		0,
		0,
		0,
		look.headerLine,
		look.headerLineFade
	)
	local by = text.baseline(font, bottom, top, metrics.bandFs)
	queueText(colorHeader .. row.caption, listX1 + metrics.rowPad, by, metrics.bandFs, "o")
	if row.members then
		queueText(
			colorDim .. row.members,
			listX1 + metrics.rowPad * 3 + row.captionW,
			text.baseline(font, bottom, top, metrics.rowFs),
			metrics.rowFs,
			"o"
		)
	end
	local vy = text.baseline(font, bottom, top, metrics.rowFs)
	for i = 2, #columns do
		queueText(
			(row.tones[i] or colorTotal) .. row.cells[i],
			columns[i].x2 - metrics.cellPad,
			vy,
			metrics.rowFs,
			"or"
		)
	end
end

local function drawTeamRow(row, top, bottom, hovered)
	local team = row.team
	if row.stripe then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.stripeFill)
	end
	if team.isLocal then
		RectRound(listX1, bottom, listRight, top, metrics.csSmall, 1, 1, 1, 1, look.selectedFill)
	end
	if hovered then
		Highlight(listX1, bottom, listRight, top, metrics.csSmall, look.rowHoverOpacity, look.white)
	end
	-- The team's colour down the left edge, the way an adjusted option is marked in the
	-- game info panel, so a row is found by colour before its name is read.
	RectRound(
		listX1,
		bottom + metrics.accentPad,
		listX1 + metrics.accentW,
		top - metrics.accentPad,
		0,
		0,
		0,
		0,
		0,
		team.accent
	)

	if filters.bars then
		for i = 2, #columns do
			local c = columns[i]
			local top_ = colMax[c.key]
			local v = row.vals[i]
			if top_ and top_ > 0 and v and isFinite(v) and v > 0 then
				local room = c.x2 - c.x1 - metrics.cellPad * 2
				local w = mathFloor(room * mathMin(1, v / top_))
				if w >= 2 then
					RectRound(
						c.x1 + metrics.cellPad,
						bottom + metrics.barInset,
						c.x1 + metrics.cellPad + w,
						top - metrics.barInset,
						mathMin(metrics.csSmall, mathFloor(w * 0.5)),
						1,
						1,
						1,
						1,
						look.barFill
					)
				end
			end
		end
	end

	local by = text.baseline(font, bottom, top, metrics.rowFs)
	local quiet = team.dead or team.gone
	queueText((quiet and colorDim or colorName) .. row.fitName, listX1 + metrics.nameIndent, by, metrics.rowFs, "o")
	for i = 2, #columns do
		local valueColor = quiet and colorDim or (row.tones[i] or colorValue)
		queueText(valueColor .. row.cells[i], columns[i].x2 - metrics.cellPad, by, metrics.rowFs, "or")
	end
end

-- Whole rows only: the band can end mid-row, and a row painted below it would be clipped
-- by nothing.
local function drawRows()
	local base = scrollOffset()

	-- The sorted column's tint, from the first row to the last one drawn, under them all.
	---@type table?
	local sortedColumn
	for i = 2, #columns do
		if columns[i].key == sortKey then
			sortedColumn = columns[i]
		end
	end
	if sortedColumn then
		local bottom = listTop
		for i = scroll + 1, #rows do
			local rowBottom = listTop - (rows[i].off - base) - rowHeightOf(rows[i])
			if rowBottom < listBottom then
				break
			end
			bottom = rowBottom
		end
		if bottom < listTop then
			RectRound(sortedColumn.x1, bottom, sortedColumn.x2, listTop, metrics.csSmall, 0, 0, 1, 1, look.sortedFill)
		end
	end

	for i = 1, #rows - scroll do
		local row = rows[scroll + i]
		if not row then
			break
		end
		local top = listTop - (row.off - base)
		local bottom = top - rowHeightOf(row)
		if bottom < listBottom then
			break
		end
		fitRow(row)
		if row.type == "band" then
			drawBand(row, top, bottom)
		else
			drawTeamRow(row, top, bottom, hover.row == i)
		end
	end
end

-- The table header: a caption over each group of columns with a line under it, and the
-- stat captions under those, the sorted one marked.
local function drawTableHeader()
	local gy = text.baseline(font, metrics.groupBottom, metrics.groupTop, metrics.groupFs)
	for i = 1, #spans do
		local s = spans[i]
		if s.label ~= "" then
			RectRound(
				s.x1 + metrics.rowPad,
				metrics.groupBottom,
				s.x2 - metrics.rowPad,
				metrics.groupBottom + metrics.underlineH,
				0,
				0,
				0,
				0,
				0,
				look.headerLine,
				look.headerLineFade
			)
			queueText(colorHeader .. s.label, mathFloor((s.x1 + s.x2) * 0.5), gy, metrics.groupFs, "oc")
		end
	end

	local sy = text.baseline(font, metrics.statBottom, metrics.statTop, metrics.statFs)
	local cy = mathFloor((metrics.statBottom + metrics.statTop) * 0.5)
	for i = 1, #columns do
		local c = columns[i]
		local hovered = hover.hcol == i
		local sorted = c.key == sortKey
		if hovered then
			Highlight(
				c.x1,
				metrics.statBottom,
				c.x2,
				metrics.statTop,
				metrics.csSmall,
				look.rowHoverOpacity,
				look.white
			)
		end
		local color = sorted and colorKey or (hovered and colorTitle or colorDim)
		if i == 1 then
			queueText(color .. c.fitStat, c.x1 + metrics.nameIndent, sy, metrics.statFs, "o")
			if sorted then
				drawSortMark(c.x1 + metrics.nameIndent + c.statW + metrics.rowPad, cy)
			end
		else
			queueText(color .. c.fitStat, c.x2 - metrics.cellPad, sy, metrics.statFs, "or")
			-- In the padding after the caption, over the right edge the numbers line up on.
			if sorted then
				drawSortMark(c.x2 - metrics.cellPad + 1, cy)
			end
		end
	end

	-- A rule closing the header off from the rows.
	RectRound(listX1, metrics.statBottom, listRight, metrics.statBottom + 1, 0, 0, 0, 0, 0, look.rule)
end

-- The column: its own card under the title, then the views, a rule, and the pages.
local function drawSidebar()
	RectRound(
		area.x1,
		area.y1,
		area.x1 + metrics.sidebarW,
		sidebarTop() + metrics.cardLip,
		metrics.csPanel,
		1,
		1,
		1,
		1,
		look.sidebarFill,
		look.sidebarFillTop
	)
	queueText(L.titleText, area.x1 + metrics.sidePad, area.y2 - metrics.titleY, metrics.titleFs, "ov")

	for i = 1, #entries do
		local e = entries[i]
		local x1, y1, x2, y2 = entryRect(i)
		if y1 < listBottom then
			break
		end
		if e.divider then
			local y = mathFloor((y1 + y2) * 0.5)
			RectRound(x1 + metrics.sidePad, y, x2 - metrics.sidePad, y + 1, 0, 0, 0, 0, 0, look.rule)
		else
			local selected = e.key == selectedGroup
			if selected then
				RectRound(
					x1 + metrics.catInset,
					y1,
					x2 - metrics.catInset,
					y2,
					metrics.csSmall,
					1,
					1,
					1,
					1,
					look.selectedFill
				)
			elseif i == hover.sb and not e.disabled then
				Highlight(
					x1 + metrics.catInset,
					y1,
					x2 - metrics.catInset,
					y2,
					metrics.csSmall,
					look.rowHoverOpacity,
					look.white
				)
			end
			local color = e.disabled and colorFaded or (selected and colorSelected or colorDim)
			queueText(color .. e.label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.catFs, "ov")
		end
	end
end

-- The switches and their captions. The plate goes behind the switch and the switch
-- lights itself: painting over it would only dull it.
local function drawHeader()
	for i = 1, #switches do
		local sw = switches[i]
		if sw.draw then
			local hovered = hover.tog == i
			if hovered then
				Highlight(sw.hit[1], sw.hit[2], sw.hit[3], sw.hit[4], metrics.csSmall, look.rowHoverOpacity, look.white)
			end
			UiToggle(sw.draw[1], sw.draw[2], sw.draw[3], sw.draw[4], filters[sw.key], hovered)
			queueText(
				(filters[sw.key] and colorSelected or colorDim) .. sw.label,
				sw.draw[1] - metrics.rowPad,
				mathFloor((sw.hit[2] + sw.hit[4]) * 0.5),
				metrics.toggleFs,
				"rov"
			)
		end
	end
end

-- Everything inside the panel: the column, the switches, the table and the scroller.
-- Baked and replayed until the cursor, the list or the screen moves.
local function drawPanel()
	drawSidebar()
	drawHeader()
	drawTableHeader()
	drawRows()

	if rowMetrics.totalH > 0 then
		UiScroller(
			barX1,
			listBottom,
			area.x2 - metrics.edgeInset,
			listTop,
			rowMetrics.totalH,
			scrollOffset(),
			hover.bar == 1,
			dragging
		)
	end

	flushText()

	-- The toggle's glow leaves its own tint as the current colour, and this list is
	-- replayed every frame, so the leak would reach whoever draws next.
	glColor(1, 1, 1, 1)
end

local function drawWindow()
	UiElement(
		screenX,
		screenY - screenHeight,
		screenX + screenWidth,
		screenY,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		WG.FlowUI.clampedOpacity
	)
end

local function dropLists()
	if panelList then
		glDeleteList(panelList)
		panelList = nil
		panelSig = nil
	end
	if windowList then
		glDeleteList(windowList)
		windowList = nil
	end
end

local function deleteGuishader()
	if backgroundGuishader ~= nil then
		if WG.guishader then
			WG.guishader.DeleteDlist("teamstats")
		else
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = nil
	end
end

-- Reads the hover state and answers a signature of everything the baked panel is painted
-- from. Same signature, same picture, so the display list is replayed as it is. The body
-- column under the cursor is read too, for the tooltip, but nothing is painted from it.
local function panelSignature(mx, my)
	hover.sb = sidebarIndexAt(mx, my) or 0
	hover.row = 0
	hover.col = 0
	hover.hcol = 0
	hover.tog = switchAt(mx, my) or 0
	hover.bar = 0

	if hover.tog == 0 and mx >= listX1 and mx < listRight then
		hover.hcol = headerColumnAt(mx, my) or 0
		if hover.hcol == 0 then
			hover.row = rowAt(my) or 0
			if hover.row > 0 then
				hover.col = columnAt(mx) or 0
			end
		end
	elseif mx >= barX1 and mx <= area.x2 then
		-- The thumb itself, not the track: it is the part that can be taken hold of, so it
		-- is the part that lights up.
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			hover.bar = 1
		end
	end

	return hover.sb
		.. "|"
		.. hover.row
		.. "|"
		.. hover.hcol
		.. "|"
		.. hover.tog
		.. "|"
		.. hover.bar
		.. "|"
		.. scroll
		.. "|"
		.. rowsGen
		.. "|"
		.. layoutGen
		.. "|"
		.. (dragging and 1 or 0)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

-- The column's full name, for a tooltip: its group and the stat, "Damage · Received".
local function columnTitle(column)
	local caption = L.caption[column.group]
	if caption and caption ~= "" then
		return caption .. " \194\183 " .. L.full[column.key]
	end
	return L.full[column.key]
end

-- The lines a player's name shows on hover: every column, view by view, at the values the
-- table would show them, and the time the team has been in the game. Built once per read
-- of the numbers: the rows are rebuilt whenever the values or the switches change.
local function nameCard(team)
	if team.cardGen == rowsGen then
		return team.card
	end

	local share = shareMode()
	local lines = {}
	for i = 1, #CARD_LINES do
		local spec = CARD_LINES[i]
		local parts = {}
		for j = 1, #spec[2] do
			local column = COLUMNS[spec[2][j]]
			if handover.on or not column.gadget then
				local v = cellValue(column, team)
				parts[#parts + 1] = colorDim
					.. L.full[column.key]
					.. " "
					.. (tone(column, team.stats, v) or colorTitle)
					.. formatCell(column, v, share and column.fmt == "si")
			end
		end
		if #parts > 0 then
			local caption = spec[1] ~= "" and (colorHeader .. L.caption[spec[1]] .. ": ") or "      "
			lines[#lines + 1] = caption .. table.concat(parts, colorDim .. "  \194\183  ")
		end
	end

	-- The milestones, when the gadget has any: the game time, what it was and the unit
	-- that made it so, a few to a line.
	local marks = team.milestones
	if marks and #marks > 0 then
		local parts = {}
		for i = 1, #marks do
			local m = marks[i]
			local label = L.milestone[m.key] or m.key
			local ud = m.unitDefID and UnitDefs[m.unitDefID] or nil
			---@cast ud table?
			if ud then
				label = label .. " (" .. (ud.translatedHumanName or ud.name) .. ")"
			end
			parts[#parts + 1] = colorDim .. gameTime(m.frame) .. " " .. colorTitle .. label
			if #parts == 3 or i == #marks then
				local caption = i <= 3 and (colorHeader .. L.milestones .. ": ") or "      "
				lines[#lines + 1] = caption .. table.concat(parts, colorDim .. "  \194\183  ")
				parts = {}
			end
		end
	end

	local time = gameTime(team.aliveFrames or 0)
	local key = (team.dead and deathFrame[team.id]) and "ui.teamStats.diedAt" or "ui.teamStats.timeInGame"
	lines[#lines + 1] = colorDim .. BAR.I18N(key, { time = time })

	team.card = table.concat(lines, "\n")
	team.cardGen = rowsGen

	return team.card
end

-- The column's entries: every view with something to show, then a rule and the history
-- page. A view of the gadget's columns alone, and the page the gadget's history would
-- fill, are left out while the gadget is not there. A view that went away hands over to
-- the overview.
local function rebuildEntries()
	entries = {}
	local selectedStays = false
	for _, group in ipairs(GROUPS) do
		local shown = handover.on
		if not shown then
			for i = 1, #group.columns do
				if not COLUMNS[group.columns[i]].gadget then
					shown = true
				end
			end
		end
		if shown then
			entries[#entries + 1] = { key = group.key, label = L.group[group.key] }
			selectedStays = selectedStays or group.key == selectedGroup
		end
	end
	if not selectedStays then
		selectedGroup = GROUPS[1].key
	end
	if showPlannedPages and handover.on then
		entries[#entries + 1] = { divider = true }
		entries[#entries + 1] = { key = "graphs", label = L.group.graphs, disabled = true }
	end
end

local function loadLabels()
	L.title = BAR.I18N("ui.teamStats.title")
	L.titleText = colorTitle .. L.title
	L.notYet = BAR.I18N("ui.teamStats.notYet")
	L.perMinuteSuffix = BAR.I18N("ui.teamStats.perMinuteSuffix")
	L.perMinuteNote = BAR.I18N("ui.teamStats.perMinuteNote")
	L.memberOne = BAR.I18N("ui.teamStats.memberOne")
	-- The milestone kinds the gadget records.
	L.milestones = BAR.I18N("ui.teamStats.milestones")
	L.milestone = {}
	for _, key in ipairs({ "factory", "tech2", "tech3", "nuke", "antinuke", "lrpc", "commanderLost", "teamDied" }) do
		L.milestone[key] = BAR.I18N("ui.teamStats.milestone." .. key)
	end

	L.group = {}
	for _, group in ipairs(GROUPS) do
		L.group[group.key] = BAR.I18N("ui.teamStats.group." .. group.key)
	end
	L.group.graphs = BAR.I18N("ui.teamStats.group.graphs")

	L.switch, L.switchDesc = {}, {}
	for _, sw in ipairs(switches) do
		L.switch[sw.key] = BAR.I18N("ui.teamStats.switch." .. sw.key)
		L.switchDesc[sw.key] = BAR.I18N("ui.teamStats.switch." .. sw.key .. "Desc")
		sw.label = L.switch[sw.key]
	end

	L.caption, L.stat, L.full, L.desc = {}, {}, {}, {}
	for key, column in pairs(COLUMNS) do
		if column.group ~= "" and not L.caption[column.group] then
			L.caption[column.group] = BAR.I18N("ui.teamStats." .. column.group)
		end
		L.stat[key] = BAR.I18N("ui.teamStats." .. column.short)
		L.full[key] = BAR.I18N("ui.teamStats." .. column.stat)
		if key ~= "name" then
			L.desc[key] = BAR.I18N("ui.teamStats.desc." .. key)
		end
	end

	rebuildEntries()
end

-- The panel's state, read at once: the gadget's hand-over is the only thing that can
-- change what the panel is made of between two frames.
local function syncGadgetState(frame)
	local on
	if handover.frame then
		on = frame - handover.frame <= handover.stale
	else
		on = handover.opened == nil or frame - handover.opened <= handover.stale
	end
	if on == handover.on then
		return
	end
	handover.on = on
	rebuildEntries()
	setLayout()
	dropLists()
end

-- Reads the numbers, after settling whether the gadget is still there to read from.
local function refresh()
	syncGadgetState(spGetGameFrame())
	refreshStats()
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font = WG.fonts.getFont()
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller
	UiScrollerAt = WG.FlowUI.Draw.ScrollerGeometry
	Highlight = WG.FlowUI.Draw.SelectHighlight
	UiToggle = WG.FlowUI.Draw.Toggle

	setLayout()
	dropLists()
	deleteGuishader()
end

function widget:DrawScreen()
	if not (show or showOnceMore) then
		deleteGuishader()
		return
	end

	-- Pinned rather than assumed: widgets on lower layers draw first and leave blending,
	-- colour and the texture wherever they finished.
	glTexture(false)
	glColor(1, 1, 1, 1)

	local mx, my, lmb = spGetMouseState()
	if dragging then
		if lmb then
			scrollFromY(my)
		else
			dragging = false
		end
	end

	local sig = panelSignature(show and mx or -1, show and my or -1)
	if sig ~= panelSig then
		if panelList then
			glDeleteList(panelList)
		end
		panelList = glCreateList(drawPanel)
		panelSig = sig
	end

	if not windowList then
		windowList = glCreateList(drawWindow)
	end
	---@cast panelList -?
	glCallList(windowList)
	glCallList(panelList)

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "teamstats", nil, widget)
	end
	showOnceMore = false

	if show and math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		spSetMouseCursor("cursornormal")

		if WG.tooltip then
			local title, tip
			local entry = hover.sb > 0 and entries[hover.sb] or nil
			if hover.hcol > 1 then
				local column = columns[hover.hcol]
				---@cast column -?
				title = columnTitle(column)
				tip = L.desc[column.key]
				if filters.perMinute and column.rate then
					tip = tip .. "\n" .. colorDim .. L.perMinuteNote
				end
			elseif hover.tog > 0 then
				local sw = switches[hover.tog]
				---@cast sw -?
				title = sw.label
				tip = L.switchDesc[sw.key]
			elseif entry and entry.disabled then
				title = entry.label
				tip = L.notYet
			elseif hover.row > 0 and hover.col == 1 then
				-- Everything about the player, on the name: the columns the open view hides too.
				local row = rows[scroll + hover.row]
				if row and row.type == "team" then
					title = row.team.label
					tip = nameCard(row.team)
				end
			elseif hover.row > 0 and hover.col > 1 then
				-- The cell's whole number: a cell rounds to three figures. A share says what it
				-- is a share of.
				local row = rows[scroll + hover.row]
				local column = columns[hover.col]
				---@cast column -?
				if row then
					fitRow(row)
					title = row.type == "team" and row.team.name or row.caption
					local v = row.vals[hover.col]
					local exact = formatExact(column, v)
					if row.type == "team" and shareMode() and column.fmt == "si" and isFinite(v) then
						exact = BAR.I18N("ui.teamStats.ofTeam", {
							share = stringFormat("%.1f%%", v),
							value = formatExact(column, baseValue(column, row.team)),
						})
					end
					local detail = cellDetail(column, row.type == "team" and row.team.stats or row.ally.total)
					if detail then
						exact = exact .. " " .. colorDim .. detail
					end
					tip = colorDim .. columnTitle(column) .. ": " .. colorTitle .. exact
				end
			end
			if tip then
				WG.tooltip.ShowTooltip("teamstats", tip, nil, nil, title)
			end
		end
	end
end

-- The gadget's hand-over, every second while the panel is open: read at once, so the
-- table follows the game a second at a time. The values are kept when the panel closes,
-- so a reopen shows the last ones until the next hand-over rather than nothing.
local function receiveLive(all, frame)
	handover.all, handover.frame = all, frame
	if show and (not gameover or handover.postGame) then
		handover.postGame = false
		refresh()
	end
end

local function closePanel()
	show = false
	dragging = false
	widgetHandler:DeregisterGlobal("TeamStatsLive")
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("teamstats")
	end
end

local function setShown(state)
	if not state then
		closePanel()
		return
	end

	if not show and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = true
	-- Registered while open only, so the gadget hands nothing over to a closed panel.
	widgetHandler:RegisterGlobal("TeamStatsLive", receiveLive)
	handover.opened = spGetGameFrame()
	-- The numbers freeze at game over; a panel first opened after it still needs one read.
	if not gameover or #allies == 0 then
		refresh()
	end
end

local function selectEntry(i)
	local e = entries[i] or {}
	if e.disabled or e.key == selectedGroup then
		return
	end
	selectedGroup = e.key
	layoutColumns()
	if playSounds then
		spPlaySoundFile(buttonclick, 0.6, "ui")
	end
end

local function sortBy(column)
	if column.key == sortKey then
		sortAscending = not sortAscending
	else
		sortKey = column.key
		-- Names read best from A, numbers from the largest.
		sortAscending = column.key == "name"
	end
	rebuildRows()
	if playSounds then
		spPlaySoundFile(buttonclick, 0.6, "ui")
	end
end

local function toggleSwitch(i)
	local sw = switches[i] or {}
	local key = tostring(sw.key)
	filters[key] = not filters[key]
	-- Grouping decides whether the share switch is offered, so the header is laid out
	-- again. The others only change what the columns say: a rate changes every value and
	-- so the order, and the captions say when they are rates.
	if key == "groupByTeam" then
		setLayout()
	else
		layoutColumns()
	end
	rebuildRows()
	if playSounds then
		spPlaySoundFile(buttonclick, 0.6, "ui")
	end
end

function widget:KeyPress(key)
	if show and key == 27 then
		-- ESC
		showOnceMore = true
		closePanel()
		return true
	end

	return false
end

-- Swallowed across the whole panel, not just the table: a wheel that gets through zooms
-- the camera behind it.
function widget:MouseWheel(up, _value)
	if not show then
		return false
	end

	local x, y = spGetMouseState()
	if not math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		return false
	end

	-- The chat history's modifiers: Ctrl moves three notches' worth at once, Shift a whole
	-- page - the rows the band holds from where the list is now, since a band is taller.
	local _, ctrl, _, shift = spGetModKeyState()
	local step = ctrl and metrics.wheelRows * 3 or metrics.wheelRows
	if shift then
		ensureRowMetrics()
		local band, used = listTop - listBottom, 0
		step = 0
		for i = scroll + 1, #rows do
			used = used + rowHeightOf(rows[i])
			if used > band then
				break
			end
			step = step + 1
		end
		step = mathMax(1, step)
	end
	setScroll(scroll + (up and -step or step))

	return true
end

-- Clicks inside the panel pick a view, flip a switch, sort a column or grab the
-- scrollbar; a press outside closes it.
local function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then
		return false
	end

	if not show then
		return false
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and button == 1 then
			local sw = switchAt(x, y)
			local i = sidebarIndexAt(x, y)
			local col = x >= listX1 and x < listRight and headerColumnAt(x, y)
			if sw then
				toggleSwitch(sw)
			elseif i then
				selectEntry(i)
			elseif col then
				sortBy(columns[col])
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, listTop) then
				-- The strip between the bar and the panel edge stays grabbable too.
				grabScroller(y)
			end
		end

		return true
	elseif not release then
		-- Only a press outside closes. A release out here belongs to a drag that started
		-- on the scrollbar.
		showOnceMore = true -- show once more because the guishader lags behind
		closePanel()

		return true
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function widget:GameFrame(n)
	if gameover or not show or n % UPDATE_FRAMES ~= 0 then
		return
	end
	-- The gadget's hand-over read the numbers this second already.
	if handover.frame and n - handover.frame < UPDATE_FRAMES then
		return
	end
	refresh()
end

-- The numbers stop at game over: what happens in the minutes after is not the game.
function widget:GameOver()
	refresh()
	gameover = true
	handover.postGame = true
end

function widget:TeamDied(teamID)
	deathFrame[teamID] = spGetGameFrame()
end

function widget:ApmEvent(teamID, apm)
	teamAPM[teamID] = apm
end

-- Who the viewer is decides which row is theirs and which colours they may see.
function widget:PlayerChanged()
	isSpec = spGetSpectatingState()
	localTeamID = spGetLocalTeamID()
	if show and not gameover then
		refresh()
	end
end

function widget:Initialize()
	loadLabels()
	widget:ViewResize()

	widgetHandler:AddAction("teamstats", function()
		setShown(not show)

		return true
	end, nil, "p")
	widgetHandler:AddAction("teamstatus_close", function()
		if show then
			setShown(false)

			return true
		end
	end, nil, "p")

	-- lets the handler hide the rest of the interface while the panel is open
	widgetHandler:RegisterModalWindow(function()
		return show == true
	end)

	WG.teamstats = {}
	WG.teamstats.toggle = function(state)
		if state == nil then
			state = not show
		end
		setShown(state)
	end
	WG.teamstats.isvisible = function()
		return show
	end
end

function widget:Shutdown()
	dropLists()
	deleteGuishader()
	widgetHandler:DeregisterGlobal("TeamStatsLive")
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("teamstats")
	end
	WG.teamstats = nil
end

-- The sort, the view and the switches are kept between games: someone who reads the
-- table one way wants it that way every time they open it.
function widget:GetConfigData()
	return {
		sortKey = sortKey,
		sortAscending = sortAscending,
		group = selectedGroup,
		groupByTeam = filters.groupByTeam,
		perMinute = filters.perMinute,
		bars = filters.bars,
	}
end

-- Runs before Initialize, so the first layout already honours it.
function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	-- The old panel saved the sort under another name, with the name column as "frame".
	local key = data.sortKey or data.sortVar
	if key == "frame" then
		key = "name"
	end
	if key and COLUMNS[key] then
		sortKey = key
	end
	if data.sortAscending ~= nil then
		sortAscending = data.sortAscending == true
	end
	if data.group and groupByKey[data.group] then
		selectedGroup = data.group
	end
	for filterKey in pairs(filters) do
		if data[filterKey] ~= nil then
			filters[filterKey] = data[filterKey] == true
		end
	end
end

function widget:LanguageChanged()
	loadLabels()
	widget:ViewResize()
	-- Names with a dead or gone suffix are read in the language of the read.
	if #allies > 0 and not gameover then
		refresh()
	end
end
