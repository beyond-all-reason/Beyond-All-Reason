-- What the team stats windows show, apart from how they show it: every column, what a team's numbers are
-- and how they print, the rows of the table, the tables and categories in the column, the switches, the
-- gadget's hand-over and what is kept between games. It draws nothing and knows no place on the screen.
--
-- A window includes this once (each include is a model of its own), then gives `model.view`:
--   isShown()          whether it is open: it only listens to the gadget then
--   layout()           everything is laid out again
--   layoutColumns()    the table's columns are
--   dropLists()        what it baked is out of date
--   entriesChanged()   the column's entries changed
--   revealEntry(i)     the i-th entry was picked: to be scrolled to
--   teamsRead()        the teams were read: who is there decides some of its layout
--   registerGlobal(name, fn), deregisterGlobal(name)   its widget's, for the gadget's receiver without the API widget
-- and `model.colors` may be changed for its own look. It calls model.loadLabels() before its first layout,
-- makes the Graphs page and the tables with model.pageContext/model.tablesContext and hands them to
-- model.attach, and passes its callins on (model.gameFrame, model.gameOver, ...).
-- `switches` holds each setting with the rects the window laid it out in (`hit`, `draw`, `disabled`).

local mathFloor = math.floor
local mathMin = math.min
local mathAbs = math.abs
local mathLog10 = math.log10
local mathHuge = math.huge
local tableSort = table.sort
local stringFormat = string.format
local stringLower = string.lower
local formatSI = string.formatSI

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
local spPlaySoundFile = Spring.PlaySoundFile

---@type table<string, any>
local model = {}
-- What the window answers and is told, filled in by it.
---@type table<string, function>
local view = {}
model.view = view

-- Frames between refreshes while the panel is open. The engine's newest history entry is
-- live, so every refresh really is newer data.
local UPDATE_FRAMES = 30

---@type boolean
local playSounds = true
local buttonclick = "LuaUI/Sounds/buildbar_waypoint.wav"

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
	damageReceived = {
		group = "damage",
		stat = "damageReceived",
		short = "shortReceived",
		fmt = "si",
		rate = true,
		low = true,
	},
	-- `clamp` bounds what the chart plots of a ratio: over nothing it is infinite, and a
	-- few thousand percent early on would put every other line on the floor.
	damageEfficiency = {
		group = "damage",
		stat = "damageEfficiency",
		short = "shortEfficiency",
		fmt = "percent",
		clamp = { 0, 1000 },
	},
	unitsProduced = { group = "units", stat = "unitsProduced", short = "shortBuilt", fmt = "si", rate = true },
	unitsKilled = { group = "units", stat = "unitsKilled", short = "unitsKilled", fmt = "si", rate = true },
	unitsDied = { group = "units", stat = "unitsDied", short = "unitsDied", fmt = "si", rate = true, low = true },
	killEfficiency = {
		group = "units",
		stat = "killEfficiency",
		short = "shortEfficiency",
		fmt = "percent",
		clamp = { 0, 1000 },
	},
	unitsCaptured = { group = "units", stat = "unitsCaptured", short = "unitsCaptured", fmt = "si", rate = true },
	unitsStolen = { group = "units", stat = "unitsStolen", short = "unitsStolen", fmt = "si", rate = true, low = true },
	unitsReceived = { group = "units", stat = "unitsReceived", short = "unitsReceived", fmt = "si", rate = true },
	unitsSent = { group = "units", stat = "unitsSent", short = "unitsSent", fmt = "si", rate = true },
	unitsActive = { group = "units", stat = "unitsActive", short = "unitsActive", fmt = "si" },
	-- What the metal spent bought in damage: army worth rather than army size.
	damagePerMetal = {
		group = "damage",
		stat = "damagePerMetal",
		short = "shortDamagePerMetal",
		fmt = "plain",
		-- A few damage for every metal: whole numbers would round most of the column to the
		-- same figure, so it keeps a decimal.
		decimal = true,
	},
	metalProduced = { group = "metal", stat = "resourceProduced", short = "shortProduced", fmt = "si", rate = true },
	-- What the team's builders took from wrecks, rocks and trees: part of what it produced,
	-- which only the team stats gadget tells apart.
	metalReclaimed = {
		group = "metal",
		stat = "resourceReclaimed",
		short = "shortReclaimed",
		fmt = "si",
		rate = true,
		gadget = true,
	},
	metalUsed = { group = "metal", stat = "resourceUsed", short = "resourceUsed", fmt = "si", rate = true },
	metalExcess = {
		group = "metal",
		stat = "resourceExcess",
		short = "resourceExcess",
		fmt = "si",
		rate = true,
		low = true,
	},
	metalSent = { group = "metal", stat = "resourceSent", short = "resourceSent", fmt = "si", rate = true },
	metalReceived = { group = "metal", stat = "resourceReceived", short = "shortReceived", fmt = "si", rate = true },
	metalStored = { group = "metal", stat = "resourceStored", short = "resourceStored", fmt = "si" },
	energyProduced = { group = "energy", stat = "resourceProduced", short = "shortProduced", fmt = "si", rate = true },
	energyReclaimed = {
		group = "energy",
		stat = "resourceReclaimed",
		short = "shortReclaimed",
		fmt = "si",
		rate = true,
		gadget = true,
	},
	energyUsed = { group = "energy", stat = "resourceUsed", short = "resourceUsed", fmt = "si", rate = true },
	energyExcess = {
		group = "energy",
		stat = "resourceExcess",
		short = "resourceExcess",
		fmt = "si",
		rate = true,
		low = true,
	},
	energySent = { group = "energy", stat = "resourceSent", short = "resourceSent", fmt = "si", rate = true },
	energyReceived = { group = "energy", stat = "resourceReceived", short = "shortReceived", fmt = "si", rate = true },
	energyStored = { group = "energy", stat = "resourceStored", short = "resourceStored", fmt = "si" },
	aggressionLevel = {
		group = "activity",
		stat = "aggression",
		short = "shortAggression",
		fmt = "plain",
		clamp = { -30, 30 },
	},
	-- Live from the APM broadcast; only the team stats gadget keeps a history of it.
	actionsPerMinute = {
		group = "activity",
		stat = "actionsPerMinute",
		short = "shortActionsPerMinute",
		fmt = "plain",
		liveOnly = true,
	},
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
	-- A running total in build power minutes: the building a team could have done and did not.
	buildPowerIdle = {
		group = "industry",
		stat = "buildPowerIdle",
		short = "shortBuildPowerIdle",
		fmt = "si",
		gadget = true,
		low = true,
	},
	-- The constructors with no orders and the factories with nothing queued, as the gadget's
	-- scan last found them, out of how many the team has (`of`): commanders and nano turrets
	-- are no constructors here.
	idleCons = {
		group = "idle",
		stat = "idleCons",
		short = "shortIdleCons",
		fmt = "si",
		gadget = true,
		low = true,
		of = { "idleCons", "cons" },
		step = true,
	},
	idleLabs = {
		group = "idle",
		stat = "idleLabs",
		short = "shortIdleLabs",
		fmt = "si",
		gadget = true,
		low = true,
		of = { "idleLabs", "labs" },
		step = true,
	},
	-- The total sits with the unit counts, so a view showing it alone captions it "Units".
	unitValue = { group = "units", stat = "unitValue", short = "shortValue", fmt = "si", count = "unitCount" },
	-- In a ranked game, what the ranking orders the ally teams by - their units' worth, the
	-- ones under construction as far as they are built, and what is in their storage - the
	-- ally team's own (`ally`); shown once more than one ally team's may be seen (`ranked`):
	-- to a spectator, and to everyone after the game. Beside the units' value, under its
	-- caption: a caption of its own over one narrow column would not fit.
	allyScore = {
		group = "units",
		stat = "allyScore",
		short = "shortAllyScore",
		fmt = "si",
		gadget = true,
		ally = true,
		ranked = true,
	},
	valueArmy = { group = "value", stat = "valueArmy", short = "shortArmy", fmt = "si", count = "countArmy" },
	-- How much of what a team has on the field is fighting rather than building it.
	armyShare = { group = "value", stat = "armyShare", short = "shortArmyShare", fmt = "percent" },
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
		clamp = { 0, 1000 },
	},
	teamKillValue = { group = "traded", stat = "teamKillValue", short = "shortTeamKill", fmt = "si", rate = true },
	-- `step`: a count, charted as steps from one sample to the next rather than a slope.
	comKills = { group = "commanders", stat = "comKills", short = "unitsKilled", fmt = "si", rate = true, step = true },
	-- The map as each side holds it: the spots under its extractors and geothermal plants
	-- (none on a map without them, and then the columns are left out; `held` counts them),
	-- what its extractors draw from theirs, how much of the map it sees and has on radar, and
	-- how far toward the enemy its army stands. The last three are the ally team's own,
	-- alike for each of its teams (`ally`): a band shows them once.
	metalSpots = {
		group = "map",
		stat = "metalSpots",
		short = "shortMetalSpots",
		fmt = "si",
		gadget = true,
		spots = "metal",
		held = true,
		step = true,
	},
	-- What the spots held are worth: more on a rich spot, four times as much under an
	-- extractor of the second tech level.
	incomeMex = {
		group = "map",
		stat = "incomeMex",
		short = "shortIncomeMex",
		fmt = "si",
		gadget = true,
		spots = "metal",
	},
	geoSpots = {
		group = "map",
		stat = "geoSpots",
		short = "shortGeoSpots",
		fmt = "si",
		gadget = true,
		spots = "geo",
		held = true,
		step = true,
	},
	visionCoverage = {
		group = "map",
		stat = "visionCoverage",
		short = "shortVision",
		fmt = "percent",
		gadget = true,
		ally = true,
	},
	radarCoverage = {
		group = "map",
		stat = "radarCoverage",
		short = "shortRadar",
		fmt = "percent",
		gadget = true,
		ally = true,
	},
	-- The share of the map the side's radar jammers hide its units in.
	jammerCoverage = {
		group = "map",
		stat = "jammerCoverage",
		short = "shortJammer",
		fmt = "percent",
		gadget = true,
		ally = true,
	},
	frontLine = {
		group = "map",
		stat = "frontLine",
		short = "shortFrontLine",
		fmt = "percent",
		gadget = true,
		ally = true,
	},
	comLost = { group = "commanders", stat = "comLost", short = "unitsDied", fmt = "si", rate = true, step = true },
	-- The map's own hazards: the damage lava did to a team's units, and what it lost to lava,
	-- deep water or the void. Only on a map that has them (`hazard`).
	lavaDamage = {
		group = "map",
		stat = "lavaDamage",
		short = "shortLavaDamage",
		fmt = "si",
		rate = true,
		low = true,
		gadget = true,
		hazard = "lava",
	},
	lostWater = {
		group = "map",
		stat = "lostWater",
		short = "shortLostWater",
		fmt = "si",
		rate = true,
		low = true,
		gadget = true,
		hazard = "any",
	},
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
-- The columns whose tooltip speaks of this moment: what comes in per second, how full the
-- storage is, how many stand idle. A chart of one of them shows the whole game instead, so
-- it says so in words of its own (ui.teamStats.graphDesc).
for _, key in ipairs({
	"metalIncome",
	"metalExpense",
	"metalLevel",
	"metalStored",
	"energyIncome",
	"energyExpense",
	"energyLevel",
	"energyStored",
	"unitsActive",
	"conversion",
	"buildPowerUse",
	"idleCons",
	"idleLabs",
	"visionCoverage",
	"radarCoverage",
	"jammerCoverage",
	"frontLine",
	"allyScore",
}) do
	COLUMNS[key].overTime = true
end

-- The categories of graphs: the stats each charts, in order, each taking one side of the
-- game - and the sections the tables' Columns... card lists every column under. The built-in
-- categories never change. The player's own come before them - the Graphs page's custom
-- module keeps them at the front of this list - and the overview that ships with the game is
-- one of those. A stat is in one built-in category only: the overview and the player's own
-- are where stats from several sides meet.
---@type table[]
local GROUPS = {
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
		},
	},
	{
		key = "economy",
		columns = {
			"metalProduced",
			"metalReclaimed",
			"metalUsed",
			"metalExcess",
			"metalSent",
			"metalReceived",
			"metalStored",
			"energyProduced",
			"energyReclaimed",
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
			"damagePerMetal",
			"teamKillValue",
			"comKills",
			"comLost",
		},
	},
	{
		key = "units",
		columns = {
			"unitsProduced",
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
			"allyScore",
			"valueArmy",
			"armyShare",
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
		key = "map",
		columns = {
			"metalSpots",
			"incomeMex",
			"geoSpots",
			"visionCoverage",
			"radarCoverage",
			"jammerCoverage",
			"frontLine",
			"lavaDamage",
			"lostWater",
		},
	},
	{
		key = "activity",
		columns = {
			"actionsPerMinute",
			"aggressionLevel",
			"buildPowerIdle",
			"idleCons",
			"idleLabs",
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
	"buildPowerIdle",
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
	-- A side's spots are its teams' together, and what its extractors draw.
	"metalSpots",
	"metalSpotsUpgraded",
	"geoSpots",
	"incomeMex",
	"buildPower",
	"buildPowerActive",
	"cons",
	"idleCons",
	"labs",
	"idleLabs",
	"unitCount",
	"unitValue",
	"killedValue",
	"killedArmyValue",
	"killedEcoValue",
	"lostValue",
	"teamKillValue",
	"comKills",
	"comLost",
	"metalReclaimed",
	"energyReclaimed",
	"lavaDamage",
	"lostWater",
}
-- The composition buckets the gadget counts, each with a count and a value.
for _, bucket in ipairs({ "Army", "Air", "Sea", "Defense", "Strategic", "Factories", "Builders", "Economy", "Utility" }) do
	SUMMED[#SUMMED + 1] = "count" .. bucket
	SUMMED[#SUMMED + 1] = "value" .. bucket
end

-- The settings, top to bottom as the column shows them. Grouping only means something
-- where a side has more than one player, so a 1v1 or a free-for-all of players on their own
-- goes without it.
---@type table[]
local switches = {
	-- The page's alone: how many charts it shows at once - a value a press changes rather
	-- than a switch, so it is drawn with what it is set to.
	{ key = "perPage", page = true, value = true },
	-- Over the rows below while a custom category's graph is open: they are its own then,
	-- and greyed out on that category's page of charts, where each graph keeps its own.
	{ key = "thisGraph", page = true, heading = true },
	-- Both views: players under their team or on their own - the page keeps a grouping of
	-- its own - and every amount as the part of the total it makes up, enemies included.
	-- The grouping is not in the column but at the right end of the strip along the top,
	-- beside the teams the Graphs page picks and over the table's rows (`top`).
	{ key = "groupByTeam", perGraph = true, top = true },
	{ key = "shareOfTotal", perGraph = true },
	-- The page's alone again, below what the charts are made of: whether the selected
	-- teams' milestones go on them, and which kinds - a value, like Graphs per page.
	{ key = "milestones", page = true, perGraph = true },
	{ key = "milestoneKinds", page = true, value = true, perGraph = true },
	-- The table's alone: every number as the difference from your own, a bar behind it,
	-- or the line its history draws. The last two are both painted behind the number, so
	-- one turns the other off.
	{ key = "vsMe", table = true },
	{ key = "trend", table = true },
	{ key = "bars", table = true },
}
-- The ally teams whose players are folded away under their band, by ally id.
---@type table<integer, boolean>
local collapsed = {}
---@type table<string, boolean>
local filters = {
	groupByTeam = true,
	shareOfTotal = false,
	bars = false,
	trend = false,
	vsMe = false,
	milestones = true,
}

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
	{ "idle", { "idleCons", "idleLabs" } },
}

-- The text colours the numbers and a player's card are printed in.
local colors = {
	title = "\255\235\235\235",
	header = "\255\255\200\130",
	dim = "\255\160\160\160",
	-- A ratio that came out ahead and one that did not: damage or kills traded above or below
	-- even, and excess that wasted a real share of what was produced.
	good = "\255\150\220\150",
	bad = "\255\235\135\120",
}
model.colors = colors
-- Excess above this share of what was produced reads as waste.
local WASTE_SHARE = 0.1

-- The captions, in the language of the last load.
---@type table<string, any>
local L = {}

-- The column's entries: the tables under a caption, then the categories of graphs under
-- theirs. `selectedGroup` is the key of the one picked, a table's or a category's.
---@type table[]
model.entries = {}
model.selectedGroup = "overview"

-- What the panel shows: every ally team with its teams and their totals, and the rows the
-- table makes of them under the current sort and grouping. The list also carries the
-- viewer's own team and ally team (`me`, `myAlly`), which the comparison switch reads.
---@type table[]
model.allies = {}
---@type table[]
model.rows = {}
-- Bumped by rebuildRows, so what a window made of the list knows it changed.
model.rowsGen = 0
-- The rebuild of the rows each column's bar scale and leaders were worked out for; the rows
-- waiting for the table to be shown again.
---@type table<string, integer>
model.facts = {}
model.rowsStale = false
-- The largest value each column shows, for the bars.
---@type table<string, number?>
model.colMax = {}
model.sortKey = "damageDealt"
---@type boolean
model.sortAscending = false

local teamAPM = {}
-- What the team stats gadget last handed over: the live values of every team the
-- viewer may see, keyed by team, and the frame it did so. A gadget cannot be called
-- from a widget, so the panel registers a receiver while it is open and the gadget
-- calls it every second; after `stale` frames without, the values count as gone rather
-- than old, and the table falls back to what the engine tells allies on its own.
-- `postGame` asks for one more read after game over, so the other side's live values
-- show once they may. `direct` is set while the panel holds the receiver global itself,
-- with no API widget to hold it for everyone. `on` is whether the gadget is taken to be there: yes until the
-- panel has been open (`opened`) for `stale` frames without a hand-over, or the
-- hand-overs stop; while it is not, the gadget's columns and the categories of graphs
-- are left out of the panel rather than shown empty. `wanted` is the category the player
-- picked while that leaves it out, gone back to when it is shown again. `overFrame` is the
-- frame the game ended on, where the charts stop.
---@type table<string, any>
local handover = { all = nil, frame = nil, opened = nil, stale = UPDATE_FRAMES * 3, postGame = false, on = true }
-- Each team's name, label and colours as last read, made again only when they change; and the
-- rules param its AI's name is in.
---@type table<integer, table>
handover.idents = {}
---@type table<integer, string>
handover.aiKeys = {}
-- How many spots of a kind the map has: the spot finder's count (none of metal on a metal
-- map), or else the gadget's.
handover.spotCount = function(kind)
	local finder = WG.resource_spot_finder
	if finder then
		local list = (kind == "metal" and not finder.isMetalMap and finder.metalSpotsList)
			or (kind == "geo" and finder.geoSpotsList)
		return type(list) == "table" and #list or 0
	end
	local info = WG.teamStats and WG.teamStats.getInfo()
	return info and info[kind .. "Spots"] or 0
end
-- Whether the ally teams are ranked as far as the viewer may see: more than one ally team's
-- place known - a spectator's view, or anyone's once the game is over; never a player's own
-- side alone.
handover.rankedIn = function(all)
	local seen, count = {}, 0
	for _, live in pairs(all or {}) do
		local place = live.allyRank
		if place and place > 0 and not seen[place] then
			seen[place] = true
			count = count + 1
		end
	end
	return count > 1
end
-- The map's hazards: lava, and void water that takes away what ends up below the ground line.
handover.lavaMap = BAR.Lava ~= nil and BAR.Lava.isLavaMap == true
do
	local ok, mapinfo = pcall(VFS.Include, "mapinfo.lua")
	handover.voidMap = ok and type(mapinfo) == "table" and mapinfo.voidwater == true
end
-- Whether a column can be shown: the gadget's while it is there, a count of the map's spots
-- on a map that has some, the ranking's in a ranked game, a hazard's on a map that has it.
handover.shows = function(column)
	return (handover.on or not column.gadget)
		and (not column.spots or handover.spotCount(column.spots) > 0)
		and (not column.ranked or handover.ranked == true)
		and (not column.hazard or handover.lavaMap or (column.hazard == "any" and handover.voidMap))
end
-- The last name seen for each team, for a player who has since left.
local teamControllers = {}
-- Every team's player, read and kept from the moment the widget loads rather than from the
-- first time the panel is opened: a player who resigns or is knocked out starts spectating,
-- and the engine leaves their team without a leader (-1) to ask for a name, so a panel
-- opened after that had nothing to show but "(dead)". Read again whenever a player changes -
-- a substitute takes a team over, a name is set - and kept through a LuaUI reload in the
-- config, under the game they were read in.
handover.rememberNames = function()
	local named = WG.playernames and WG.playernames.getPlayername
	local function nameOf(playerID)
		local name = spGetPlayerInfo(playerID, false)
		return (named and named(playerID)) or name
	end
	for _, teamID in ipairs(spGetTeamList()) do
		local _, leader = spGetTeamInfo(teamID, false)
		local name
		if leader and leader >= 0 then
			name = nameOf(leader)
		end
		if not name then
			-- No leader left: the one player who still carries the team - their own, dead or
			-- given away. Only when they are the only one, so a watcher the lobby put on the
			-- team is not taken for the player who had it.
			local found, count = nil, 0
			for _, playerID in ipairs(Spring.GetPlayerList() or {}) do
				local playerName, _, _, playerTeam = spGetPlayerInfo(playerID, false)
				if playerName and playerTeam == teamID then
					found, count = playerID, count + 1
				end
			end
			if count == 1 then
				name = nameOf(found)
			end
		end
		if name and name ~= "" then
			teamControllers[teamID] = name
		elseif teamControllers[teamID] == nil then
			-- Nothing to be had: said so, rather than looked for again every second.
			teamControllers[teamID] = false
		end
	end
end
-- The frame each team died on, so a rate is over the time the team was in the game.
local deathFrame = {}
---@type boolean
model.gameover = false

-- No side with more than one player - a 1v1, or a free-for-all of players on their own -
-- so there is nothing to group by team and no team to take a share of.
local soloTeams = not BAR.Utilities.Gametype.IsTeams()
-- Nor is there when the players are one side against nothing but raptors or scavengers.
local ungrouped = soloTeams or (BAR.Utilities.Gametype.IsPvE() and BAR.Utilities.GetAllyTeamCount() <= 1)
local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {
	Spring.GetConfigInt("anonymousColorR", 255) / 255,
	Spring.GetConfigInt("anonymousColorG", 0) / 255,
	Spring.GetConfigInt("anonymousColorB", 0) / 255,
}
local isSpec = spGetSpectatingState()
local localTeamID = spGetLocalTeamID()
-- The team the viewer plays, or played before they were knocked out or resigned: "you" and
-- "me" on the panel. Never the team a spectator watches, so one who never played has none.
-- Kept in the config under the game, as the names are, for a reload after it.
---@type integer?
handover.played = not isSpec and localTeamID or nil

---@type function
local rebuildRows
-- The Graphs page (luaui/Include/teamstats_graphs.lua) and the tables with the columns the
-- player keeps in them (luaui/Include/teamstats_tables.lua), which a window makes and hands over.
---@type table<string, any>
local graphs
---@type table<string, any>
local tables

-- The tables and categories the player made, kept in a file of their own as well, out of reach
-- of the config an older version of this widget writes in a replay.
local store = require("luaui/Include/teamstats_store").new("LuaUI/Config/teamstats.json")

model.store = store

----------------------------------------------------------------
-- Numbers
----------------------------------------------------------------

-- Not a number: what a cell shows as "-" and sorts last. A value the viewer may not see,
-- or a ratio with nothing under it.
local NAN = 0 / 0

-- A number to show: not missing, not the NaN an unknown value is carried as. Anything else
-- counts as unknown, so a caller that hands over what an `and` left behind cannot go on to
-- compare it with a number.
local function known(v)
	return type(v) == "number" and v == v
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

-- Every team's together of a key, which a share of the total is a share of: added up the
-- first time a share of it is asked for after the teams were read. A team whose number is
-- unknown is left out of it rather than making everyone's share unknown: it shows none
-- itself, and the rest are shares of what is known.
ratio.grand = function(key)
	---@diagnostic disable-next-line: undefined-field
	local grand = model.allies.grand
	if not grand then
		grand = {}
		---@diagnostic disable-next-line: inject-field
		model.allies.grand = grand
	end
	local sum = grand[key]
	if sum == nil then
		sum = 0
		for i = 1, #model.allies do
			local teams = model.allies[i].teams
			for j = 1, #teams do
				local v = teams[j].stats[key]
				if type(v) == "number" and v == v then
					sum = sum + v
				end
			end
		end
		grand[key] = sum
	end
	return sum
end

-- The keys an ally team's total adds up its teams' counters for, and the columns whose value
-- is the ally team's own, alike for each of its teams.
ratio.summed = {}
for i = 1, #SUMMED do
	ratio.summed[SUMMED[i]] = true
end
ratio.allyKeys = {}
for key, column in pairs(COLUMNS) do
	if column.ally then
		ratio.allyKeys[#ratio.allyKeys + 1] = key
	end
end

-- An ally team's total of a counter, added up the first time it is read, and its ratios made
-- from them (by `derive`) the first time one of those is: only what the rows on show read -
-- nothing while the Graphs page is on - rather than every counter every second. A member's
-- unknown makes the total unknown.
ratio.totalsOf = function(ally, derive)
	local derived = false
	return {
		__index = function(total, key)
			if not ratio.summed[key] then
				-- Once, before anything else not added up is looked for: derive reads the sums
				-- through here, and what it looks for and does not make stays nothing.
				if not derived then
					derived = true
					derive(total)
					return rawget(total, key)
				end
				return nil
			end
			local teams = ally.teams
			local sum = nil
			for j = 1, #teams do
				local v = teams[j].stats[key]
				if v == nil then
					sum = NAN
					break
				end
				sum = (sum or 0) + v
			end
			if sum ~= nil then
				rawset(total, key, sum)
			end
			return sum
		end,
	}
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
-- What each value derive() makes is made of, for the charts: they add up only these over
-- a unit's teams rather than every counter. The engine's ratios read the whole set of its
-- counters derive() works from, the live ones their two amounts.
ratio.engine = {
	"metalProduced",
	"metalReceived",
	"metalUsed",
	"energyProduced",
	"energyReceived",
	"damageDealt",
	"damageReceived",
	"unitsProduced",
	"unitsReceived",
	"unitsCaptured",
	"unitsDied",
	"unitsSent",
	"unitsOutCaptured",
	"unitsKilled",
}
ratio.inputs = {
	unitsStolen = ratio.engine,
	unitsActive = ratio.engine,
	damageEfficiency = ratio.engine,
	damagePerMetal = ratio.engine,
	killEfficiency = ratio.engine,
	aggressionLevel = ratio.engine,
	metalStored = { "metalCurrent" },
	energyStored = { "energyCurrent" },
	metalLevel = { "metalCurrent", "metalStorage" },
	energyLevel = { "energyCurrent", "energyStorage" },
	conversion = { "convUse", "convCapacity" },
	buildPowerUse = { "buildPowerActive", "buildPower" },
	valueEfficiency = { "killedValue", "lostValue" },
	armyShare = { "valueArmy", "unitValue" },
}

local function derive(s)
	-- The engine's counters come as a set or not at all: a graph sample taken from the
	-- gadget alone has none of them.
	if s.metalProduced ~= nil then
		s.unitsStolen = s.unitsOutCaptured
		s.unitsActive = s.unitsProduced
			+ s.unitsReceived
			+ s.unitsCaptured
			- (s.unitsDied + s.unitsSent + s.unitsOutCaptured)
		-- A ratio of nothing to nothing is no number at all, not a boundless one: a team
		-- that has neither dealt nor taken a blow has no efficiency yet, and a chart that
		-- read one would run along its ceiling from the first second of the game. Trading
		-- something for nothing lost is boundless, and stays so.
		s.damageEfficiency = ratio.efficiency(s.damageDealt, s.damageReceived)
		s.killEfficiency = ratio.efficiency(s.unitsKilled, s.unitsDied)
		s.damagePerMetal = s.metalUsed ~= 0 and s.damageDealt / s.metalUsed or NAN
		-- Energy counts at a sixtieth of metal, the game's usual exchange.
		local resources = s.metalProduced + s.metalReceived + (s.energyProduced + s.energyReceived) / 60
		if resources ~= 0 and s.damageDealt ~= 0 then
			s.aggressionLevel = mathFloor(10 * mathLog10(s.damageDealt / resources) + 0.5)
		else
			s.aggressionLevel = NAN
		end
	end
	-- The live ratios, from amounts that can be unknown: a team the viewer may not see
	-- has none, and its ally team's sums are unknown with it. What is in storage is read,
	-- not counted up from the counters: those leave out what a team started with, which
	-- the game sets rather than produces, and would put a spent start below zero.
	s.metalStored = known(s.metalCurrent) and s.metalCurrent or NAN
	s.energyStored = known(s.energyCurrent) and s.energyCurrent or NAN
	s.metalLevel = ratio.level(s.metalCurrent, s.metalStorage)
	s.energyLevel = ratio.level(s.energyCurrent, s.energyStorage)
	s.conversion = ratio.share(s.convUse, s.convCapacity)
	s.buildPowerUse = ratio.share(s.buildPowerActive, s.buildPower)
	s.valueEfficiency = ratio.efficiency(s.killedValue, s.lostValue)
	s.armyShare = ratio.share(s.valueArmy, s.unitValue)
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
local function formatCell(column, v, share, mine)
	if mine ~= nil then
		if not isFinite(v) or not isFinite(mine) then
			return "-", nil
		end
		local d = v - mine
		if mathAbs(d) < (column.decimal and 0.05 or 0.5) then
			return "=", colors.dim
		end
		local better = column.low and d < 0 or (not column.low and d > 0)
		return (d > 0 and "+" or "-") .. formatCell(column, mathAbs(d), share), better and colors.good or colors.bad
	end
	if column.fmt == "percent" or share then
		if not isFinite(v) then
			return "-"
		end
		return stringFormat("%d%%", mathFloor(v + 0.5))
	elseif column.fmt == "plain" then
		if not isFinite(v) then
			return "-"
		end
		if column.decimal then
			return stringFormat("%.1f", v)
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
	elseif column.held then
		-- Held out of how many the map has, and how many of the metal ones under an upgrade.
		local n, total = stats[column.key], handover.spotCount(column.spots)
		if known(n) and total > 0 then
			local upgraded = column.spots == "metal" and stats.metalSpotsUpgraded or nil
			if known(upgraded) and upgraded > 0 then
				return BAR.I18N(
					"ui.teamStats.ofTotalUpgraded",
					{ value = formatWhole(n), total = formatWhole(total), upgraded = formatWhole(upgraded) }
				)
			end
			return BAR.I18N("ui.teamStats.ofTotal", { value = formatWhole(n), total = formatWhole(total) })
		end
	end
	return nil
end

local function gameTime(frames)
	return stringFormat("%d:%02d", mathFloor(frames / 1800), mathFloor(frames / 30) % 60)
end

-- Whether there are ally teams to group: a game with teams, and more than one side listed.
-- A player sees only their own until the game is over, and grouped that is a single line.
local function canGroup()
	return not ungrouped and #model.allies > 1
end

-- Whether the table has ally teams to show: the grouping switch, when they can be grouped.
local function grouped()
	return filters.groupByTeam and canGroup()
end

-- Whether amounts are shown as the share of the total of every team listed.
local function shareMode()
	return filters.shareOfTotal
end

-- A team's counter, or NaN when it is not known.
local function baseValue(column, team)
	local v = team.stats[column.key]
	if v == nil then
		return NAN
	end
	return v
end

-- What an ally team's band shows: its total, or under the share switch the part of every
-- team's total together it makes up. Ratios and levels have no share.
local function bandValue(column, ally)
	local v = ally.total[column.key]
	if v ~= nil and shareMode() and column.fmt == "si" then
		local total = ratio.grand(column.key)
		if total ~= 0 then
			return v / total * 100
		end
		return 0
	end
	return v
end

-- What a team's cell shows: the counter, or under the share switch the part of every
-- team's total together it made - so a band's share is its players' added up, and an enemy
-- is compared like an ally. Ratios and levels have no share.
local function cellValue(column, team)
	local v = baseValue(column, team)
	if shareMode() and column.fmt == "si" then
		local total = ratio.grand(column.key)
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
		return v > 100 and colors.good or colors.bad
	end
	local produced = WASTE_OF[column.key]
	if produced and stats[produced] > 0 and stats[column.key] / stats[produced] > WASTE_SHARE then
		return colors.bad
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
	-- The engine's entry, with everything else the row shows added to it: the gadget's values
	-- read through it rather than copied in - a hundred and more a team, every second - and
	-- none of them named like one of the engine's.
	---@cast s table
	local milestones
	if live then
		setmetatable(s, { __index = live })
		if live.actionsPerMinute == nil then
			s.actionsPerMinute = teamAPM[teamID] or 0
		end
		milestones = live.milestones
	else
		s.actionsPerMinute = teamAPM[teamID] or 0
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

	local _, leader, isDead, isAI = spGetTeamInfo(teamID, false)
	local name, isActive = spGetPlayerInfo(leader, false)
	if WG.playernames and WG.playernames.getPlayername then
		name = WG.playernames.getPlayername(leader) or name
	end
	local aiKey = handover.aiKeys[teamID]
	if not aiKey then
		aiKey = "ainame_" .. teamID
		handover.aiKeys[teamID] = aiKey
	end
	local aiName = spGetGameRulesParam(aiKey)
	if aiName then
		name = tostring(aiName)
	end
	if name then
		teamControllers[teamID] = name
	else
		-- Nobody to ask any more: the name this team was last read under, else one last look
		-- for whoever carries it; a team nothing is known about is said to be unknown rather
		-- than left as a bare "(dead)".
		if teamControllers[teamID] == nil then
			handover.rememberNames()
		end
		name = teamControllers[teamID] or L.unknownPlayer
	end
	-- An AI says so after its name, the way the player list writes it. The name kept for a
	-- team nobody answers for any more is the bare one, so this is never said twice.
	if isAI then
		name = BAR.I18N("ui.playersList.aiName", { name = name })
	end
	local gone = not isActive

	local r, g, b
	if not isSpec and anonymousMode ~= "disabled" and teamID ~= localTeamID then
		r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	else
		r, g, b = spGetTeamColor(teamID)
		r, g, b = r or 1, g or 1, b or 1
	end

	-- The label, the name to sort by and the colours only change with the player, their state
	-- or the colour: made again when one of them did, else kept from the last read.
	local id = handover.idents[teamID]
	if not id or id.name ~= name or id.dead ~= isDead or id.gone ~= gone or id.r ~= r or id.g ~= g or id.b ~= b then
		local label = name
		if isDead == true then
			label = BAR.I18N("ui.teamStats.dead", { player = name })
		elseif gone then
			label = BAR.I18N("ui.teamStats.gone", { player = name })
		end
		id = {
			name = name,
			dead = isDead,
			gone = gone,
			r = r,
			g = g,
			b = b,
			label = label,
			sortName = stringLower(name),
			-- The name in the team's colour, lifted towards white so a dark team still reads
			-- on the dark panel.
			nameColor = string.char(
				255,
				mathFloor((r * 0.65 + 0.35) * 255),
				mathFloor((g * 0.65 + 0.35) * 255),
				mathFloor((b * 0.65 + 0.35) * 255)
			),
			accent = { r, g, b, isDead and 0.35 or 0.9 },
		}
		handover.idents[teamID] = id
	end

	-- A rate is over the time the team was in the game, and never over less than a
	-- minute, or the first seconds would show rates of thousands.
	local alive = deathFrame[teamID] and mathMin(deathFrame[teamID], frame) or frame
	return {
		id = teamID,
		allyID = allyID,
		stats = s,
		-- The columns this team leads, filled in when the rows are built.
		leads = {},
		name = name,
		sortName = id.sortName,
		label = id.label,
		nameColor = id.nameColor,
		accent = id.accent,
		dead = isDead,
		gone = gone,
		-- The viewer's own: the team they play or played, never one they only watch.
		isLocal = teamID == handover.played,
		aliveFrames = alive,
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
	local allies = {}
	model.allies = allies
	-- The teams read and as what: a player is shown the other side only at game over.
	local read = {}
	for _, allyID in ipairs(spGetAllyTeamList()) do
		---@cast allyID integer
		local ally = { id = allyID, teams = {}, total = {}, leads = {} }
		local teamList = spGetTeamList(allyID)
		---@cast teamList -?
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaia then
				local team = readTeam(teamID, allyID, frame, live and live[teamID])
				if team then
					read[#read + 1] = teamID .. (team.dead and "d" or "") .. (team.gone and "g" or "") .. team.name
					team.ally = ally
					ally.teams[#ally.teams + 1] = team
					if team.isLocal then
						---@diagnostic disable-next-line: inject-field
						allies.me, allies.myAlly = team, ally
					end
				end
			end
		end
		if #ally.teams > 0 then
			-- What the ally team holds as one - its sight, its radar, its army's standing - is
			-- alike for each of its teams: the band shows it once, off the first that knows it.
			for i = 1, #ratio.allyKeys do
				local key = ratio.allyKeys[i]
				local v = NAN
				for j = #ally.teams, 1, -1 do
					local own = ally.teams[j].stats[key]
					if known(own) then
						v = own
					end
				end
				ally.total[key] = v
			end
			-- The rest added up, and the ratios made, as they are read.
			setmetatable(ally.total, ratio.totalsOf(ally, derive))
			allies[#allies + 1] = ally
		end
	end
	-- The page is made again when they change: refilling its charts keeps the teams it had.
	local key = table.concat(read, "|")
	if graphs and key ~= handover.teamsRead then
		graphs.invalidate()
	end
	handover.teamsRead = key
	-- The rows are the table's: while the Graphs page is on, they wait for the table.
	if graphs and graphs.open then
		model.rowsStale = true
	else
		rebuildRows()
	end
end

----------------------------------------------------------------
-- The rows
----------------------------------------------------------------

local function compareTeams(a, b)
	if model.sortKey == "name" then
		if a.sortName ~= b.sortName then
			if model.sortAscending then
				return a.sortName < b.sortName
			end
			return a.sortName > b.sortName
		end
		return a.id < b.id
	end
	if a.sortVal ~= b.sortVal then
		if model.sortAscending then
			return a.sortVal < b.sortVal
		end
		return a.sortVal > b.sortVal
	end
	return a.id < b.id
end

local function compareAllies(a, b)
	if model.sortKey ~= "name" and a.sortVal ~= b.sortVal then
		if model.sortAscending then
			return a.sortVal < b.sortVal
		end
		return a.sortVal > b.sortVal
	end
	return a.id < b.id
end

-- Sorts the teams inside their ally teams and the ally teams by their totals, then lays
-- them out as rows: a band per ally team with its teams under it, or one flat list.
rebuildRows = function()
	local rows = {}
	model.rows = rows
	model.rowsGen = model.rowsGen + 1
	local allies = model.allies
	local column = COLUMNS[model.sortKey] or COLUMNS.damageDealt

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
			-- An ally team of one is its one team: the band says the name and the numbers
			-- once. A band of more folds its teams away when clicked.
			local solo = #ally.teams == 1 and ally.teams[1] or nil
			rows[#rows + 1] =
				{ type = "band", ally = ally, team = solo, folded = not solo and collapsed[ally.id] or nil }
			if not solo and not collapsed[ally.id] then
				for j = 1, #ally.teams do
					-- Striped by place under the band, so the pattern starts afresh with each
					-- ally team rather than running on across its band.
					rows[#rows + 1] = { type = "team", team = ally.teams[j], stripe = j % 2 == 0, trendKey = false }
				end
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
			rows[#rows + 1] = { type = "team", team = teams[i], stripe = i % 2 == 0, trendKey = false }
		end
	end

	-- The rows the trend lines are drawn for, each with the teams it stands for: the page
	-- keeps the histories and hands back one line per cell.
	if filters.trend then
		local list = {}
		for i = 1, #rows do
			local row = rows[i]
			local members = {}
			if row.team then
				members[1] = row.team.id
				row.trendKey = "t" .. row.team.id
			else
				for j = 1, #row.ally.teams do
					members[j] = row.ally.teams[j].id
				end
				row.trendKey = "a" .. row.ally.id
			end
			list[#list + 1] = { key = row.trendKey, members = members }
		end
		graphs.setTrendRows(list)
	end

	-- The bars' scale and who leads each column: worked out for the columns drawn, as they
	-- are drawn (drawRows), rather than for every column of every view.
	model.colMax = {}
	for i = 1, #allies do
		allies[i].leads = {}
		for j = 1, #allies[i].teams do
			allies[i].teams[j].leads = {}
		end
	end
end

-- What a row shows in each of these columns: the value, its text and the colour it earned.
function model.fillRow(row, columns)
	row.cells = {}
	row.vals = {}
	row.tones = {}
	local share = shareMode()
	if row.type == "team" then
		local team = row.team
		---@type table?
		---@diagnostic disable-next-line: undefined-field
		local me = (filters.vsMe and not team.isLocal) and model.allies.me or nil
		for i = 2, #columns do
			local c = columns[i]
			local v = cellValue(c, team)
			row.vals[i] = v
			if me then
				row.cells[i], row.tones[i] = formatCell(c, v, share and c.fmt == "si", cellValue(c, me))
			else
				row.cells[i] = formatCell(c, v, share and c.fmt == "si")
				row.tones[i] = tone(c, team.stats, v)
			end
		end
	else
		local ally = row.ally
		---@type table?
		---@diagnostic disable-next-line: undefined-field
		local mine = (filters.vsMe and model.allies.myAlly ~= ally) and model.allies.myAlly or nil
		for i = 2, #columns do
			local c = columns[i]
			local v = bandValue(c, ally)
			row.vals[i] = v
			if mine then
				row.cells[i], row.tones[i] = formatCell(c, v, share and c.fmt == "si", bandValue(c, mine))
			else
				row.cells[i] = formatCell(c, v, share and c.fmt == "si")
				row.tones[i] = tone(c, ally.total, v)
			end
		end
	end
end

-- What a band is called: a side of one player is that player, and says their name rather than the
-- side's number, which would say nothing the colour does not. A side of more is named after itself,
-- with how many players it holds to go beside it.
function model.bandCaption(row)
	local ally = row.ally
	local caption = row.team and row.team.label or BAR.I18N("ui.teamStats.team", { number = ally.id + 1 })
	local members = not row.team and BAR.I18N("ui.teamStats.members", { count = #ally.teams }) or nil
	return caption, members
end

-- The bars are scaled to the largest a column shows among the teams, and each column
-- marks who leads it - the largest, or the smallest where less is better - among the
-- players and among the ally teams: once a rebuild of the rows, for the columns on show.
function model.columnFacts(columns)
	local allies, facts, rowsGen = model.allies, model.facts, model.rowsGen
	for c = 2, #columns do
		local col = columns[c]
		local key = col.key
		if facts[key] ~= rowsGen then
			facts[key] = rowsGen
			local top = 0
			---@type table?, number?, table?, number?
			local bestTeam, bestValue, bestAlly, bestTotal = nil, nil, nil, nil
			for i = 1, #allies do
				local ally = allies[i]
				ally.leads[key] = nil
				for j = 1, #ally.teams do
					local team = ally.teams[j]
					team.leads[key] = nil
					local v = cellValue(col, team)
					if isFinite(v) then
						if v > top then
							top = v
						end
						if bestValue == nil or (col.low and v < bestValue) or (not col.low and v > bestValue) then
							bestTeam, bestValue = team, v
						end
					end
				end
				local total = bandValue(col, ally)
				if isFinite(total) then
					if bestTotal == nil or (col.low and total < bestTotal) or (not col.low and total > bestTotal) then
						bestAlly, bestTotal = ally, total
					end
				end
			end
			model.colMax[key] = col.fmt ~= "plain" and top or nil
			-- Nobody leads a column everyone is at zero in.
			if bestTeam and bestValue ~= 0 then
				bestTeam.leads[key] = true
			end
			if bestAlly and bestTotal ~= 0 and #allies > 1 then
				bestAlly.leads[key] = true
			end
		end
	end
end

-- The column's full name, for a tooltip: its group and the stat, "Damage · Received".
local function columnTitle(column)
	local caption = L.caption[column.group]
	if caption and caption ~= "" then
		return caption .. " \194\183 " .. L.full[column.key]
	end
	return L.full[column.key]
end

-- The tooltip a player's name shows on hover: a row a caption, every column view by view at
-- the values the table would show them, and the time the team has been in the game as its
-- note. Built once per read of the numbers: the rows are rebuilt whenever the values or the
-- switches change.
local function nameCard(team)
	if team.cardGen == model.rowsGen then
		return team.card
	end

	local share = shareMode()
	local rows = {}
	for i = 1, #CARD_LINES do
		local spec = CARD_LINES[i]
		local parts = {}
		for j = 1, #spec[2] do
			local column = COLUMNS[spec[2][j]]
			if handover.shows(column) then
				local v = cellValue(column, team)
				parts[#parts + 1] = colors.dim
					.. L.full[column.key]
					.. " "
					.. (tone(column, team.stats, v) or colors.title)
					.. formatCell(column, v, share and column.fmt == "si")
			end
		end
		if #parts > 0 then
			local caption = spec[1] ~= "" and (colors.header .. L.caption[spec[1]]) or ""
			rows[#rows + 1] = { caption, table.concat(parts, colors.dim .. "  \194\183  ") }
		end
	end

	-- The milestones, when the gadget has any: the game time, what it was and the unit
	-- that made it so, a few to a line. The ones that tell the game's story - the economy's
	-- smaller steps are left to their charts, and strikes that cost less than a quarter of
	-- what they hit - and one that came again (a commander lost, a nuke) at its first time,
	-- with how often.
	local marks = team.milestones
	if marks and #marks > 0 then
		local shown, times = {}, {}
		for i = 1, #marks do
			local m = marks[i]
			local strike = m.key == "ecoStrike" or m.key == "armyLoss" or m.key == "raid"
			if L.milestone[m.key] and not (strike and (m.share or 0) < 0.25) then
				if times[m.key] then
					times[m.key] = times[m.key] + 1
				else
					times[m.key] = 1
					shown[#shown + 1] = m
				end
			end
		end
		local parts = {}
		for i, m in ipairs(shown) do
			local label = L.milestone[m.key]
			local ud = m.unitDefID and UnitDefs[m.unitDefID] or nil
			---@cast ud table?
			if ud then
				label = label .. " (" .. (ud.translatedHumanName or ud.name) .. ")"
			end
			if times[m.key] > 1 then
				label = label .. colors.dim .. " \195\151" .. times[m.key]
			end
			parts[#parts + 1] = colors.dim .. gameTime(m.frame) .. " " .. colors.title .. label
			if #parts == 3 or i == #shown then
				local caption = i <= 3 and (colors.header .. L.milestones) or ""
				rows[#rows + 1] = { caption, table.concat(parts, colors.dim .. "  \194\183  ") }
				parts = {}
			end
		end
	end

	local time = gameTime(team.aliveFrames or 0)
	local key = (team.dead and deathFrame[team.id]) and "ui.teamStats.diedAt" or "ui.teamStats.timeInGame"

	team.card = { rows = rows, note = BAR.I18N(key, { time = time }) }
	team.cardGen = model.rowsGen

	return team.card
end

-- The tooltip of a cell of `column` in `row`, showing `v`: its whole number, a cell rounding to
-- three figures, with what it is made of. A share says what it is a share of.
local function cellTip(column, row, v)
	local isTeam = row.type == "team"
	local value = v
	local shared = shareMode() and column.fmt == "si" and isFinite(v)
	if shared then
		value = isTeam and baseValue(column, row.team) or row.ally.total[column.key]
	end
	local exact = formatExact(column, value)
	local detail = cellDetail(column, isTeam and row.team.stats or row.ally.total)
	if detail then
		exact = exact .. " " .. colors.dim .. detail
	end
	local rows = { { columnTitle(column), exact } }
	if shared then
		rows[2] = { BAR.I18N("ui.teamStats.switch.shareOfTotal"), stringFormat("%.1f%%", v), dim = true }
		rows[3] = { BAR.I18N("ui.teamStats.everyTeam"), formatExact(column, model.ratio.grand(column.key)), dim = true }
	end
	return { rows = rows }
end

-- A text broken to fit `width`, a wrapped line starting in the colour the one before ended in. Kept by what it said: a
-- tooltip asks every frame.
local wrappedLines, wrappedWidth, wrappedCount = {}, nil, 0
local function wrapText(text, font, width)
	if width ~= wrappedWidth or wrappedCount >= 100 then
		wrappedLines, wrappedWidth, wrappedCount = {}, width, 0
	end
	local wrapped = wrappedLines[text]
	if not wrapped then
		local lines, count, color = {}, 0, ""
		for line in (font:WrapText(text, width) .. "\n"):gmatch("(.-)\n") do
			count = count + 1
			lines[count] = color .. line
			for code in line:gmatch("\255...") do
				color = code
			end
		end
		wrapped = table.concat(lines, "\n")
		wrappedLines[text] = wrapped
		wrappedCount = wrappedCount + 1
	end
	return wrapped
end

-- What goes to WG.tooltip for a text or a content table: its text and note wrapped, a table's rows as they are.
local function wrapTip(tip, font, width)
	if type(tip) ~= "table" then
		return wrapText(tip, font, width)
	end
	local wrapped = {}
	for k, v in pairs(tip) do
		wrapped[k] = v
	end
	wrapped.text = tip.text and wrapText(tip.text, font, width)
	wrapped.note = tip.note and wrapText(tip.note, font, width)
	return wrapped
end

-- The column's entries: the tables under their caption, then under theirs the categories of
-- graphs with something to show; each caption's + makes a new one. The graphs are made of
-- the gadget's history, so while the gadget is not there they are left out, and so is a
-- category of its columns alone. A pick that went away hands over to the overview - or to a
-- table, without the graphs or when it was a table - and is gone back to once it is shown
-- again: it is still the player's pick. The view follows the pick.
local function rebuildEntries()
	local wasTable = tables.byKey[model.selectedGroup] ~= nil
	for _, e in ipairs(model.entries) do
		wasTable = wasTable or (e.table and e.key == model.selectedGroup)
	end
	local entries = {}
	model.entries = entries
	local want = handover.wanted or model.selectedGroup
	local wantShown, selectedStays = false, false
	local function add(entry)
		entries[#entries + 1] = entry
		wantShown = wantShown or entry.key == want
		selectedStays = selectedStays or entry.key == model.selectedGroup
	end
	-- Each caption carries the + that makes a new one of its kind.
	entries[#entries + 1] = { section = true, key = "newTable", label = L.section.tables, add = true }
	for _, t in ipairs(tables.list) do
		add({ key = t.key, label = tables.label(t), table = true })
	end
	if handover.on then
		entries[#entries + 1] = { section = true, key = "newCategory", label = L.section.graphs, add = true }
		local afterCustom = false
		for _, group in ipairs(GROUPS) do
			if group.custom then
				add({ key = group.key, label = group.label, custom = true })
				afterCustom = true
			else
				-- A rule between the player's categories and the built-in ones.
				if afterCustom then
					entries[#entries + 1] = { divider = true }
					afterCustom = false
				end
				local shown = false
				for i = 1, #group.columns do
					if handover.shows(COLUMNS[group.columns[i]]) then
						shown = true
					end
				end
				if shown then
					add({ key = group.key, label = L.group[group.key] })
				end
			end
		end
	end
	view.entriesChanged()
	if wantShown then
		model.selectedGroup, handover.wanted = want, nil
	elseif not selectedStays then
		-- Hidden, not gone: kept as the pick, and saved as it. A deleted one is not kept.
		if not handover.wanted and groupByKey[model.selectedGroup] then
			handover.wanted = model.selectedGroup
		end
		model.selectedGroup = (handover.on and not wasTable) and "overview" or tables.current
	end
	local open = tables.byKey[model.selectedGroup] == nil
	if open ~= graphs.open then
		graphs.open = open
		if open then
			graphs.invalidate()
		end
	end
	-- A table is sorted the way it was left.
	if not open then
		tables.current = model.selectedGroup
		model.sortKey, model.sortAscending = tables.sortOf(model.selectedGroup)
	end
end

local function loadLabels()
	L.title = BAR.I18N("ui.teamStats.title")
	L.titleText = colors.title .. L.title
	L.notYet = BAR.I18N("ui.teamStats.notYet")
	L.unknownPlayer = BAR.I18N("ui.teamStats.unknownPlayer")
	L.foldHint = BAR.I18N("ui.teamStats.foldHint")
	-- The milestone kinds a player's card lists: the ones that tell the game's story.
	L.milestones = BAR.I18N("ui.teamStats.milestones")
	L.milestone = {}
	L.milestoneOrder = {
		"tech2",
		"tech3",
		"moho",
		"fusion",
		"afus",
		"air",
		"naval",
		"nuke",
		"antinuke",
		"lrpc",
		"firstKill",
		"firstLoss",
		"commanderKill",
		"commanderLost",
		"nukeLaunched",
		"nuked",
		"ecoStrike",
		"armyLoss",
		"raid",
		"teamDied",
	}
	for _, key in ipairs(L.milestoneOrder) do
		L.milestone[key] = BAR.I18N("ui.teamStats.milestone." .. key)
	end

	L.group = {}
	for _, group in ipairs(GROUPS) do
		if not group.custom then
			L.group[group.key] = BAR.I18N("ui.teamStats.group." .. group.key)
		end
	end
	-- The overview's name is the language's until the player renames it.
	graphs.custom.apply()

	L.perGraphOpen = BAR.I18N("ui.teamStats.custom.perGraphOpen")
	L.categoryHint = BAR.I18N("ui.teamStats.custom.categoryHint")
	L.overviewHint = BAR.I18N("ui.teamStats.custom.overviewHint")
	L.perGraphGrid = BAR.I18N("ui.teamStats.custom.perGraphGrid")
	L.groupAll = BAR.I18N("ui.teamStats.custom.groupAll")
	L.section = {
		tables = BAR.I18N("ui.teamStats.section.tables"),
		graphs = BAR.I18N("ui.teamStats.section.graphs"),
	}
	L.newTable = BAR.I18N("ui.teamStats.tables.newTable")
	L.newTableDesc = BAR.I18N("ui.teamStats.tables.newTableDesc")
	L.newCategory = BAR.I18N("ui.teamStats.custom.newCategory")
	L.newCategoryDesc = BAR.I18N("ui.teamStats.custom.newCategoryDesc")
	L.tableEmpty = BAR.I18N("ui.teamStats.tables.empty")
	L.columnsDesc = BAR.I18N("ui.teamStats.tables.columnsDesc")
	L.captionHint = BAR.I18N("ui.teamStats.tables.captionHint")
	L.switch, L.switchDesc = {}, {}
	for _, sw in ipairs(switches) do
		L.switch[sw.key] = BAR.I18N("ui.teamStats.switch." .. sw.key)
		-- A caption row is never hovered for a tooltip, so it has nothing to explain.
		if not sw.heading then
			L.switchDesc[sw.key] = BAR.I18N("ui.teamStats.switch." .. sw.key .. "Desc")
		end
		sw.label = L.switch[sw.key]
	end

	L.caption, L.stat, L.full, L.desc, L.graphDesc = {}, {}, {}, {}, {}
	for key, column in pairs(COLUMNS) do
		if column.group ~= "" and not L.caption[column.group] then
			L.caption[column.group] = BAR.I18N("ui.teamStats." .. column.group)
		end
		L.stat[key] = BAR.I18N("ui.teamStats." .. column.short)
		L.full[key] = BAR.I18N("ui.teamStats." .. column.stat)
		if key ~= "name" then
			L.desc[key] = BAR.I18N("ui.teamStats.desc." .. key)
		end
		-- What the same stat means on a chart, where it runs over the whole game.
		if column.overTime then
			L.graphDesc[key] = BAR.I18N("ui.teamStats.graphDesc." .. key)
		end
	end

	rebuildEntries()
end

-- The panel's state, read at once: the gadget's hand-over is the only thing that can
-- change what the panel is made of between two frames.
local function syncGadgetState(frame)
	local on
	if WG.teamStats then
		-- The API widget listens for every widget, so it knows first.
		on = WG.teamStats.isAvailable()
	else
		-- Opening the panel gives the gadget that long again, as the API widget does.
		local last = handover.frame
		if handover.opened and (not last or handover.opened > last) then
			last = handover.opened
		end
		on = last == nil or frame - last <= handover.stale
	end
	if on == handover.on then
		return
	end
	handover.on = on
	rebuildEntries()
	view.layout()
	view.dropLists()
end

-- Reads the numbers, after settling whether the gadget is still there to read from. That
-- is only known while the panel listens: closed, it is handed nothing, and a read then - at
-- game over, or on a language change - would take its views and the page away for nothing.
local function refresh()
	if view.isShown() then
		syncGadgetState(spGetGameFrame())
	end
	refreshStats()
	view.teamsRead()
	-- The page's histories are the table's trend lines too.
	if graphs.open or filters.trend then
		graphs.refresh()
	end
end

-- The gadget's hand-over, every second while the panel is open: read at once, so the
-- table follows the game a second at a time. The values are kept when the panel closes,
-- so a reopen shows the last ones until the next hand-over rather than nothing.
local function receiveLive(all, frame)
	handover.all, handover.frame = all, frame
	-- The ranking comes and goes with what may be seen: a spectator's, everyone's after the
	-- game. The views, the columns and the charts follow.
	local ranked = handover.rankedIn(all)
	if ranked ~= (handover.ranked == true) then
		handover.ranked = ranked
		if view.isShown() then
			rebuildEntries()
			view.layout()
			view.dropLists()
		end
	end
	if view.isShown() and (not model.gameover or handover.postGame) then
		handover.postGame = false
		refresh()
	end
end

-- The gadget's hand-over reaches the panel through the team stats API widget when it is
-- there, so other widgets share it, and straight from the gadget when it is not.
local function listen(on)
	local hub = WG.teamStats
	if on then
		if hub then
			if not hub.isSubscribed("teamstats") then
				hub.subscribe("teamstats", {
					live = receiveLive,
					history = graphs.receiveHistory,
					units = graphs.receiveUnits,
					reset = graphs.gadgetRestarted,
				})
			end
		elseif not handover.direct then
			-- The receiver is the API widget's when it is there: only one the panel
			-- registered itself is the panel's to take down.
			handover.direct = view.registerGlobal("TeamStatsLive", receiveLive)
		end
	else
		if hub then
			hub.unsubscribe("teamstats")
		end
		if handover.direct then
			view.deregisterGlobal("TeamStatsLive")
			handover.direct = false
		end
	end
end

-- The window opened. Listening while open only, so the gadget hands nothing over to a closed panel.
local function opened()
	listen(true)
	handover.opened = spGetGameFrame()
	-- The numbers freeze at game over; a panel first opened after it still needs one read.
	-- The charts ask for what they do not have yet whenever the panel opens: after game
	-- over nothing else would, and an answer the panel was closed for is lost.
	graphs.askAgain()
	if not model.gameover or #model.allies == 0 then
		refresh()
	elseif graphs.open or filters.trend then
		graphs.refresh()
	end
end

-- A press's sound.
function model.playSound()
	if playSounds then
		spPlaySoundFile(buttonclick, 0.6, "ui")
	end
end

-- Picks a table or a category of graphs by its key: the view follows the pick, and a table
-- comes sorted the way it was left. `quiet` when what asked for it made its own sound.
local function selectEntry(key, quiet)
	---@type table?, integer
	local e, at = nil, 0
	for i = 1, #model.entries do
		if model.entries[i].key == key then
			e, at = model.entries[i], i
		end
	end
	-- The + on the Graphs caption: an empty category of the player's own, picked and named on
	-- the spot.
	if e and e.add and key == "newCategory" then
		local category = graphs.custom.create()
		rebuildEntries()
		selectEntry(category.key, quiet)
		graphs.startNaming(category.key)
		graphs.invalidate()
		view.dropLists()
		return
	end
	-- The + on the Tables caption: an empty table of the player's own, picked, named on the
	-- spot, and its Columns... card open to fill it.
	if e and e.add then
		local t = tables.create()
		rebuildEntries()
		selectEntry(t.key, quiet)
		graphs.startNaming(t.key, tables.label(t), function(name)
			tables.rename(t.key, name)
		end)
		tables.openCard(t.key)
		return
	end
	if not e or e.disabled or key == model.selectedGroup then
		return
	end
	-- A pick of their own replaces the one waiting for the gadget to come back.
	handover.wanted = nil
	model.selectedGroup = key
	view.revealEntry(at)
	tables.closeCard()
	if e.table then
		tables.current = key
		model.sortKey, model.sortAscending = tables.sortOf(key)
		rebuildRows()
	end
	local open = not e.table
	if open ~= graphs.open then
		graphs.open = open
		view.layout()
		view.dropLists()
		if open then
			graphs.refresh()
			graphs.invalidate()
		end
	else
		view.layout()
	end
	if not quiet then
		model.playSound()
	end
end

local function sortBy(column)
	if column.key == model.sortKey then
		model.sortAscending = not model.sortAscending
	else
		model.sortKey = column.key
		-- Names read best from A, numbers from the largest.
		model.sortAscending = column.key == "name"
	end
	tables.setSort(tables.current, model.sortKey, model.sortAscending)
	rebuildRows()
	model.playSound()
end

local function toggleSwitch(i, back)
	local sw = switches[i] or {}
	if sw.disabled then
		return
	end
	local key = tostring(sw.key)
	if sw.value then
		-- A setting with a value rather than a state: the left button steps it on, the
		-- right one back.
		graphs.settingPress(key, back)
		view.layout()
	elseif sw.perGraph and graphs.open and graphs.openGraph() then
		-- A custom category's graph keeps its own: the switch sets it for that graph alone.
		local graph = graphs.openGraph()
		---@cast graph -?
		local field = key == "groupByTeam" and "grouped" or (key == "shareOfTotal" and "share" or "milestones")
		graph[field] = not graph[field]
		graphs.invalidate()
		view.layout()
	elseif key == "groupByTeam" and graphs.open then
		-- The page groups its own way: the table keeps the grouping it was left with. On a
		-- custom category's page of charts every graph of it goes along, so the charts group
		-- the way the bar picks.
		local state = not graphs.grouped
		graphs.setGrouped(state)
		local group = groupByKey[model.selectedGroup]
		for _, graph in ipairs(group and group.custom and group.graphs or {}) do
			graph.grouped = state
		end
		graphs.invalidate()
		-- Grouping decides whether the share switch is offered here too.
		view.layout()
	else
		filters[key] = not filters[key]
		-- Bars and trends both sit behind the numbers: one of them at a time.
		if filters[key] and (key == "bars" or key == "trend") then
			filters[key == "bars" and "trend" or "bars"] = false
		end
		if key == "trend" and filters.trend then
			graphs.refresh()
		end
		-- Grouping decides whether the share switch is offered, so the header is laid
		-- out again. The others only change what the columns say: a rate changes every
		-- value and so the order, and the captions say when they are rates.
		if key == "groupByTeam" then
			view.layout()
		else
			view.layoutColumns()
		end
		rebuildRows()
		-- The chart is made of what the switches say too.
		graphs.invalidate()
	end
	model.playSound()
end

-- A band's players folded away, or back.
function model.toggleFold(allyID)
	collapsed[allyID] = not collapsed[allyID] or nil
	rebuildRows()
	model.playSound()
end

function model.gameFrame(n)
	if not view.isShown() or n % UPDATE_FRAMES ~= 0 then
		return
	end
	-- The numbers stay as the game left them, but a gadget gone since takes its columns along.
	if model.gameover then
		syncGadgetState(n)
		return
	end
	-- The gadget's hand-over read the numbers this second already.
	if handover.frame and n - handover.frame < UPDATE_FRAMES then
		return
	end
	-- A reloaded API widget forgets its subscribers; this puts the panel back on its list.
	listen(true)
	refresh()
end

-- The numbers stop at game over: what happens in the minutes after is not the game.
function model.gameOver()
	-- The gadget takes its last sample and opens every team's numbers: asked for again, as
	-- nothing refreshes the charts on its own after this.
	graphs.askAgain()
	refresh()
	model.gameover = true
	handover.postGame = true
	handover.overFrame = spGetGameFrame()
end

function model.teamDied(teamID)
	deathFrame[teamID] = spGetGameFrame()
end

function model.apmEvent(teamID, apm)
	teamAPM[teamID] = apm
end

-- Who the viewer is decides which row is theirs and which colours they may see. A spectator
-- switching the team they watch lands here too, and keeps the team they played, if any.
function model.playerChanged()
	isSpec = spGetSpectatingState()
	localTeamID = spGetLocalTeamID()
	if not isSpec then
		handover.played = localTeamID
	end
	-- A player resigning or being knocked out leaves their team without a leader: their name
	-- is still to be had at this moment, and kept for the rows.
	handover.rememberNames()
	if view.isShown() and not model.gameover then
		refresh()
	elseif model.gameover then
		-- The numbers stay as the game left them; only whose team is the viewer's moves.
		local allies = model.allies
		---@diagnostic disable-next-line: inject-field
		allies.me, allies.myAlly = nil, nil
		for _, ally in ipairs(allies) do
			for _, team in ipairs(ally.teams) do
				team.isLocal = team.id == handover.played
				if team.isLocal then
					---@diagnostic disable-next-line: inject-field
					allies.me, allies.myAlly = team, ally
				end
			end
		end
		rebuildRows()
	end
	-- The page's You button is the viewer's own team.
	graphs.invalidate()
end

function model.languageChanged()
	loadLabels()
	handover.idents = {}
end

-- The tables, the pick and the switches are kept between games: someone who reads the
-- panel one way wants it that way every time they open it.
function model.getConfig()
	-- The names of this game's teams, for a reload mid-game: a team whose player has gone
	-- cannot be named again from the engine. Copied, not the table the rows are read from.
	local names = {}
	for teamID, name in pairs(teamControllers) do
		if type(name) == "string" then
			names[teamID] = name
		end
	end
	local data = {
		gameID = Game.gameID or spGetGameRulesParam("GameID"),
		names = names,
		-- The team the viewer played, for a reload after they were out: the engine no longer
		-- says so once they spectate.
		played = handover.played,
		-- Each table's columns and sort.
		tables = tables.getConfig(),
		-- The player's pick, even while the gadget's absence has it hidden.
		group = handover.wanted or model.selectedGroup,
		groupByTeam = filters.groupByTeam,
		shareOfTotal = filters.shareOfTotal,
		bars = filters.bars,
		trend = filters.trend,
		vsMe = filters.vsMe,
		milestones = filters.milestones,
	}
	-- And the page's own: what it shows, how, and which kinds of milestone it leaves off.
	for key, value in pairs(graphs.getConfig()) do
		data[key] = value
	end
	store.write(data.tables, data.customCategories)
	return data
end

-- Runs before Initialize, so the first layout already honours it.
function model.setConfig(data)
	if type(data) ~= "table" then
		return
	end
	data = store.merge(data)
	-- The names read in this same game, from before a reload, and the team the viewer played.
	if data.gameID and data.gameID == (Game.gameID or spGetGameRulesParam("GameID")) then
		for teamID, name in pairs(type(data.names) == "table" and data.names or {}) do
			if type(name) == "string" and name ~= "" then
				teamControllers[tonumber(teamID) or teamID] = name
			end
		end
		if isSpec and handover.played == nil and type(data.played) == "number" then
			handover.played = data.played
		end
	end
	tables.setConfig(data.tables)
	-- Before the tables, the panel kept one sort - the old one under another name, with the
	-- name column as "frame": the summary takes it.
	local key = data.sortKey or data.sortVar
	if key == "frame" then
		key = "name"
	end
	if not data.tables and key and COLUMNS[key] then
		tables.setSort(tables.current, key, data.sortAscending == true)
	end
	-- The page's settings first: they hold the custom categories the open group may be.
	graphs.setConfig(data)
	if data.group and (groupByKey[data.group] or tables.byKey[data.group]) then
		model.selectedGroup = data.group
	end
	for filterKey in pairs(filters) do
		if data[filterKey] ~= nil then
			filters[filterKey] = data[filterKey] == true
		end
	end
end

-- The Graphs page and the tables, made by the window with what is its own in `own`, are handed over
-- here; the model reads them from then on.
function model.attach(page, tablesOf)
	graphs, tables = page, tablesOf
end

-- What the Graphs page reads of the model, added to what it takes from the window: its look, metrics
-- and colours, its draw calls and text queue, and the table's lines (trendRows).
function model.pageContext(own)
	own.COLUMNS = COLUMNS
	own.GROUPS = GROUPS
	own.groupByKey = groupByKey
	own.L = L
	own.columnTitle = columnTitle
	own.derive = derive
	own.derivedInputs = ratio.inputs
	own.columnShown = handover.shows
	-- The categories changed: the sidebar, the columns and the stat list follow.
	own.categoriesChanged = function()
		rebuildEntries()
		view.layout()
		graphs.invalidate()
		view.dropLists()
	end
	-- A category picked by the page's cards: a new one pasted, or the overview for a deleted one.
	own.selectGroup = function(key)
		selectEntry(key, true)
	end
	-- Typed text reaches a widget only while SDL is asked for it.
	own.textInput = function(on)
		if on and Spring.SDLStartTextInput then
			Spring.SDLStartTextInput()
		elseif not on and Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end
	own.filters = filters
	own.soloTeams = model.soloTeams
	own.canGroup = canGroup
	own.selectedGroup = function()
		return model.selectedGroup
	end
	own.allies = function()
		return model.allies
	end
	own.live = function()
		return handover.all
	end
	own.gadgetOn = function()
		return handover.on
	end
	own.frame = spGetGameFrame
	own.history = spGetTeamStatsHistory
	-- Only while the panel is on the hub's list: a history asked for then comes back to it.
	own.hub = function()
		local hub = WG.teamStats
		return hub and hub.isSubscribed("teamstats") and hub or nil
	end
	own.overFrame = function()
		return handover.overFrame
	end
	-- Whether the ally teams' places in a ranking may be seen, more than one of them.
	own.ranked = function()
		return handover.ranked == true
	end
	own.i18n = BAR.I18N
	own.playSound = model.playSound
	return own
end

-- What the tables read of the model, added to what they take from the window; their right-click cards
-- are the page's cards of actions.
function model.tablesContext(own)
	own.COLUMNS = COLUMNS
	own.GROUPS = GROUPS
	own.L = L
	own.columnShown = handover.shows
	own.columnTitle = columnTitle
	own.i18n = BAR.I18N
	own.openMenu = function(...)
		return graphs.openMenu(...)
	end
	-- A table's columns changed: laid out again, and sorted again when the sorted one went.
	own.changed = function()
		model.sortKey, model.sortAscending = tables.sortOf(tables.current)
		view.layoutColumns()
		rebuildRows()
	end
	-- Tables made, renamed, moved or deleted: the sidebar follows, and the table shown with it.
	own.listChanged = function()
		rebuildEntries()
		view.layout()
		rebuildRows()
		view.dropLists()
	end
	own.startNaming = function(key)
		local t = tables.byKey[key]
		if t then
			graphs.startNaming(key, tables.label(t), function(name)
				tables.rename(key, name)
			end)
		end
	end
	own.playSound = model.playSound
	return own
end

model.COLUMNS, model.GROUPS, model.groupByKey, model.switches = COLUMNS, GROUPS, groupByKey, switches
model.filters, model.handover, model.L, model.ratio = filters, handover, L, ratio
model.teamControllers, model.deathFrame = teamControllers, deathFrame
model.soloTeams = soloTeams
model.known, model.isFinite, model.derive = known, isFinite, derive
model.formatCell, model.formatExact, model.cellDetail = formatCell, formatExact, cellDetail
model.canGroup, model.grouped, model.shareMode = canGroup, grouped, shareMode
model.baseValue, model.bandValue, model.cellValue, model.tone = baseValue, bandValue, cellValue, tone
model.columnTitle, model.nameCard = columnTitle, nameCard
model.cellTip, model.wrapTip = cellTip, wrapTip
model.rebuildRows, model.rebuildEntries, model.loadLabels = rebuildRows, rebuildEntries, loadLabels
model.refresh, model.syncGadgetState, model.listen, model.opened = refresh, syncGadgetState, listen, opened
model.selectEntry, model.sortBy, model.toggleSwitch = selectEntry, sortBy, toggleSwitch

return model
