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
local showPlannedPages = true

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

-- The column's views: which columns each shows, in order, each taking one side of the game.
-- The built-in categories, which never change. The player's own come before them - the
-- Graphs page's custom module keeps them at the front of this list - and the overview that
-- ships with the game is one of those. A stat is in one built-in category only: the
-- overview and the player's own are where stats from several sides meet.
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
	-- The Graphs page: a mode, so it leads the column; its state is the page's, not a filter.
	{ key = "graphs", mode = true },
	-- The page's alone: how many charts it shows at once - a value a press changes rather
	-- than a switch, so it is drawn with what it is set to.
	{ key = "perPage", page = true, value = true },
	-- Over the rows below while a custom category's graph is open: they are its own then,
	-- and greyed out on that category's page of charts, where each graph keeps its own.
	{ key = "thisGraph", page = true, heading = true },
	-- Both views: players under their team or on their own - the page keeps a grouping of
	-- its own - and every amount as the part of the total it makes up, enemies included.
	{ key = "groupByTeam", perGraph = true },
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

----------------------------------------------------------------
-- Layout and look
----------------------------------------------------------------

local area = { x1 = 0, y1 = 0, x2 = 0, y2 = 0 }
-- Sizes derived from the scale, in one table rather than a local each, the way the other
-- panels hold their own.
local metrics = {
	-- The numbers are set in the monospaced face, so a column of them lines up figure
	-- under figure however wide each one is, and the player names in the face the rest of
	-- the interface names players in; everything else is the interface's own.
	numFont = nil,
	nameFont = nil,
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
	-- The bar behind a number, inside its row by this much top and bottom; the trend line
	-- that can take its place is drawn this thick.
	barInset = 4,
	trendW = 1,
	-- The mark under the number of a column a row leads: this far above the row's bottom
	-- edge, and this thick.
	leadDrop = 3,
	leadH = 2,
	-- The line along the bottom of a group caption and of an ally team's band.
	underlineH = 2,
	-- Everything that sits against the panel's right edge - the switches and the
	-- scrollbar - is held off it by this much.
	edgeInset = 4,
	-- The band the title sits in, and the gap below it.
	headerH = 34,
	-- Where the settings block under the sidebar's groups starts; the groups stop there.
	settingsTop = 0,
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
	-- Between the column and the Graphs page's stat list, two cards side by side.
	pageGap = 8,
	barW = 14,
	-- Rows the wheel moves per notch.
	wheelRows = 3,
	-- The name column: never narrower than this, and otherwise this share of the table.
	nameMinW = 150,
	nameShare = 0.2,
	-- A number's column at its widest, twice what a view of twelve gives each: a view of a
	-- few keeps its numbers near the names, and the table ends with its last column.
	colMaxW = 150,
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
	-- A card laid over the charts, which has to read over whatever is under it: opaque, or
	-- the lines and captions behind it ghost through.
	cardFill = { 0.05, 0.05, 0.05, 1 },
	cardFillTop = { 0.1, 0.1, 0.1, 1 },
	selectedFill = { 1, 1, 1, 0.13 },
	white = { 1, 1, 1 },
	-- Rows, entries and captions hover with the same FlowUI highlight the settings list
	-- uses, at the strength it gives a plain row.
	rowHoverOpacity = 0.14,
	-- A chart in the overview under the cursor: fainter than a row, over a larger area.
	chartHoverOpacity = 0.09,
	-- A block of the Graphs page's legend bar under the cursor: small, so lit more than a
	-- row, and over a lit block too.
	barHoverOpacity = 0.24,
	-- A graph dragged in a category of the player's own: its place shaded, and the line
	-- where it would land in the hue of the captions.
	dragShade = { 0, 0, 0, 0.45 },
	dropLine = { 1, 0.78, 0.51, 0.9 },
	-- Underline under a group caption and an ally team's band: a thin bar fading up out
	-- of the bottom edge, in the hue of the caption above it.
	headerLine = { 1, 0.78, 0.51, 0.4 },
	headerLineFade = { 1, 0.78, 0.51, 0 },
	sheenTop = { 1, 1, 1, 0.05 },
	-- The rule closing the table header off from the rows, and the one in the column.
	rule = { 1, 1, 1, 0.08 },
	-- The bar behind a number, scaled to the column's largest.
	barFill = { 1, 1, 1, 0.07 },
	-- A band's trend line, where the band stands for several players and so for no colour
	-- of its own.
	trendBand = { 1, 0.86, 0.66, 0.4 },
	-- The mark under the number of a column a row leads.
	leadMark = { 1, 0.78, 0.51, 0.55 },
	-- Laid over a switch whose row is dimmed, so its state reads but its colour does not
	-- call for a press.
	mutedFill = { 0.09, 0.09, 0.09, 0.62 },
	-- Every second team row under a band takes this, so the eye keeps its line across a
	-- dozen columns. Faint: it is a guide, not a highlight.
	stripeFill = { 1, 1, 1, 0.022 },
	-- The sort marker.
	sortMark = { 0.92, 0.73, 0.27, 0.9 },
	-- The font is shared with every other widget, and whichever of them set its outline
	-- last is what a bake would freeze in; pinned after every Begin, the way the keybind
	-- editor and the widget selector pin theirs.
	outline = { 0, 0, 0, 0.4 },
	-- The sorted column, tinted down its length in the hue of its caption, so the eye
	-- follows the values the table is ordered by.
	sortedFill = { 1, 0.78, 0.51, 0.04 },
	-- The line framing the sorted column, caption to last row, in the same hue.
	sortedLine = { 1, 0.78, 0.51, 0.28 },
	-- The sorted column's numbers, a shade warmer than the rest.
	sortedText = "\255\240\226\205",
	-- A number that is nothing, or not known: quieter, so what there is stands out.
	zeroText = "\255\150\150\150",
	-- Excess above this share of what was produced reads as waste.
	wasteShare = 0.1,
}
local colorTitle = "\255\235\235\235"
local colorHeader = "\255\255\200\130"
local colorKey = "\255\235\185\070"
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
local selectedGroup = "overview"
-- The columns the table shows right now, each with the x range it takes, and the group
-- captions spanning them.
---@type table[]
local columns = {}
---@type table[]
local spans = {}

-- What the panel shows: every ally team with its teams and their totals, and the rows the
-- table makes of them under the current sort and grouping. The list also carries the
-- viewer's own team and ally team (`me`, `myAlly`), which the comparison switch reads.
---@type table[]
local allies = {}
---@type table[]
local rows = {}
-- Bumped by rebuildRows, so the baked panel knows the list behind it changed.
local rowsGen = 0
-- Bumped by the layout. A cached row layout carries the value it was built against and
-- is measured again when it moves, without every row being walked at resize.
local layoutGen = 0
-- `facts`: the rebuild of the rows each column's bar scale and leaders were worked out for;
-- `stale`: the rows wait for the table to be shown again.
---@type { gen: number, rows: number, totalH: number, facts: table<string, integer>, stale: boolean }
local rowMetrics = { gen = -1, rows = -1, totalH = 0, facts = {}, stale = false }
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
-- show once they may. `direct` is set while the panel holds the receiver global itself,
-- with no API widget to hold it for everyone. `on` is whether the gadget is taken to be there: yes until the
-- panel has been open (`opened`) for `stale` frames without a hand-over, or the
-- hand-overs stop; while it is not, the gadget's columns, views and the history page
-- are left out of the panel rather than shown empty. `wanted` is the view the player
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
local gameover = false

-- No side with more than one player - a 1v1, or a free-for-all of players on their own -
-- so there is nothing to group by team and no team to take a share of.
local soloTeams = not BAR.Utilities.Gametype.IsTeams()
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
-- The Graphs page (luaui/Include/teamstats_graphs.lua), made at the end of the file once
-- everything it reads from is declared.
---@type table<string, any>
local graphs

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
	local grand = allies.grand
	if not grand then
		grand = {}
		---@diagnostic disable-next-line: inject-field
		allies.grand = grand
	end
	local sum = grand[key]
	if sum == nil then
		sum = 0
		for i = 1, #allies do
			local teams = allies[i].teams
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
			return "=", colorDim
		end
		local better = column.low and d < 0 or (not column.low and d > 0)
		return (d > 0 and "+" or "-") .. formatCell(column, mathAbs(d), share), better and colorGood or colorBad
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

-- Whether the table has ally teams to show: the grouping switch, in a game with teams.
local function grouped()
	return filters.groupByTeam and not soloTeams
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
		-- A spectator always watches one team; that one is theirs here.
		isLocal = teamID == localTeamID,
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
	allies = {}
	for _, allyID in ipairs(spGetAllyTeamList()) do
		---@cast allyID integer
		local ally = { id = allyID, teams = {}, total = {}, leads = {} }
		local teamList = spGetTeamList(allyID)
		---@cast teamList -?
		for _, teamID in ipairs(teamList) do
			if teamID ~= gaia then
				local team = readTeam(teamID, allyID, frame, live and live[teamID])
				if team then
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
	-- The rows are the table's: while the Graphs page is on, they wait for the table.
	if graphs and graphs.open then
		rowMetrics.stale = true
	else
		rebuildRows()
	end
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
	colMax = {}
	for i = 1, #allies do
		allies[i].leads = {}
		for j = 1, #allies[i].teams do
			allies[i].teams[j].leads = {}
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

-- The bar serves whichever of the two is open: the table's rows, or the grid of charts on
-- the Graphs page, which runs up to the top of the charts. Its band and its thumb come out
-- of the same call, so the page's top is worked out once.
local function scrollerThumb()
	local total, offset = rowMetrics.totalH, scrollOffset()
	local top = listTop
	if graphs and graphs.open then
		total, offset = graphs.scrollExtent()
		top = graphs.rects and graphs.rects.chart[4] or listTop
	end
	local a, b, c, d = UiScrollerAt(barX1, listBottom, area.x2 - metrics.edgeInset, top, total, offset)
	return a, b, c, d, top, total, offset
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
	if graphs and graphs.open then
		-- The grid scrolls by whole rows, so the bar asks for the row it landed on.
		local total = graphs.scrollExtent()
		local c = graphs.rects and graphs.rects.chart
		-- The page's own generation is part of the bake signature, so the picture follows.
		graphs.setScrollPixels(f * mathMax(0, total - (c and c[4] - c[2] or 0)))
		return
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
		if y1 < metrics.settingsTop then
			return nil
		end
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
		if hit and not switches[i].heading and math_isInRect(x, y, hit[1], hit[2], hit[3], hit[4]) then
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
-- name, up to a width a number's column never passes. The table's right edge is where its
-- last column ends.
local function layoutColumns()
	local group = groupByKey[selectedGroup] or GROUPS[1]
	---@cast group -?
	columns = { COLUMNS.name }
	for i = 1, #group.columns do
		local c = COLUMNS[group.columns[i]]
		if handover.shows(c) then
			columns[#columns + 1] = c
		end
	end

	-- The room is the channel up to the scrollbar's; the table itself ends with its last
	-- column, which a view of few columns leaves short of it.
	local tableW = barX1 - metrics.listGap - listX1
	local n = #columns - 1
	---@type number
	local nameW = mathMax(metrics.nameMinW, mathFloor(tableW * metrics.nameShare))
	---@type number
	local colW = metrics.colMaxW
	if n > 0 and mathFloor((tableW - nameW) / n) < colW then
		colW = mathFloor((tableW - nameW) / n)
		nameW = tableW - colW * n
	end
	listRight = listX1 + nameW + colW * n

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
		else
			span = { group = c.group, x1 = c.x1, x2 = c.x2 }
			spans[#spans + 1] = span
		end
	end
	for i = 1, #spans do
		local s = spans[i]
		local label = L.caption[s.group] or s.group
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
	metrics.trendW = mathMax(1, mathFloor(1.5 * s))
	metrics.leadDrop = mathMax(2, mathFloor(3 * s))
	metrics.leadH = mathMax(1, mathFloor(2 * s))
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
	metrics.pageGap = mathFloor(8 * s)
	metrics.barW = mathFloor(14 * s)
	metrics.nameMinW = mathFloor(150 * s)
	metrics.colMaxW = mathFloor(150 * s)
	-- Narrower than the cell padding it sits in.
	metrics.triW = mathMax(4, mathFloor(5 * s))
	metrics.triH = mathMax(3, mathFloor(4 * s))
	metrics.switchGap = mathFloor(16 * s)
	metrics.csPanel = mathFloor(elementCorner)
	metrics.csSmall = mathFloor(elementCorner * 0.66)
	metrics.nameIndent = metrics.accentW + metrics.rowPad * 2

	listX1 = area.x1 + metrics.sidebarW + metrics.listGap
	-- The sidebar's card starts below the panel's title; the table and the page beside it
	-- have no title of their own to clear, so they start at the panel's own edge.
	metrics.bandTop = area.y2 - metrics.headerH - metrics.headerGap
	-- The table header: group captions, then the stat captions, then a gap to the rows.
	metrics.groupTop = area.y2 - metrics.headerGap * 2
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
	-- The Graphs page takes the table's room, header rows and scrollbar included. Its
	-- stat list is a card like the column's, so it sits closer and spans the same height.
	if graphs then
		graphs.setFont(font, metrics.rowFs, metrics.nameFont)
		graphs.setLayout(
			area.x1 + metrics.sidebarW + metrics.pageGap,
			listBottom,
			listRight,
			metrics.groupTop,
			s,
			area.y1,
			sidebarTop() + metrics.cardLip,
			-- The legend bar runs over the scrollbar's column, which only starts below it,
			-- and ends where the scrollbar does.
			area.x2 - metrics.edgeInset
		)
	end

	-- The settings: a row each under the sidebar's groups, the caption on the left and the
	-- toggle on the right, laid out from the bottom of the column upwards so the block
	-- stays put however many groups there are. A switch the open view cannot use keeps its
	-- row and is dimmed, so nothing ever moves when one is pressed.
	metrics.toggleFs = mathFloor(metrics.rowFs * 1.05)
	local togW = mathFloor(38 * s)
	local togH = mathFloor(metrics.catRowHeight * 0.52)
	local onGraphs = graphs and graphs.open
	---@diagnostic disable-next-line: undefined-field
	local canCompare = allies.me ~= nil
	local y = listBottom + metrics.edgeInset
	local customGroup = groupByKey[selectedGroup] and groupByKey[selectedGroup].custom
	for i = #switches, 1, -1 do
		local sw = switches[i]
		-- Which view a switch belongs to; the mode switch belongs to both.
		local mine = not ((sw.table and onGraphs) or (sw.page and not onGraphs))
		-- A custom category's page of charts: every graph on it keeps its own settings.
		local customCharts = onGraphs and customGroup and not graphs.openGraph()
		if sw.mode and not (showPlannedPages and handover.on) then
			mine = false
		end
		-- Without a side of more than one player there is nothing to group.
		if soloTeams and sw.key == "groupByTeam" then
			mine = false
		end
		-- The caption over a custom graph's own rows, only while one is open.
		if sw.heading and not (onGraphs and graphs.openGraph()) then
			mine = false
		end
		if mine then
			local cy = y + mathFloor(metrics.catRowHeight * 0.5)
			sw.hit = {
				area.x1 + metrics.catInset,
				y,
				area.x1 + metrics.sidebarW - metrics.catInset,
				y + metrics.catRowHeight,
			}
			sw.draw = {
				sw.hit[3] - metrics.sidePad - togW,
				cy - mathFloor(togH * 0.5),
				sw.hit[3] - metrics.sidePad,
				cy - mathFloor(togH * 0.5) + togH,
			}
			-- Nothing to say: the switch stays where it is and greys out.
			sw.disabled = (
				sw.key == "milestones"
				and graphs
				and (not graphs.overTime() or graphs.milestonesOwn() or not graphs.marksApply())
			)
				or (sw.key == "milestoneKinds" and graphs and not graphs.kindsApply())
				or (sw.key == "vsMe" and not canCompare)
				or (sw.key == "shareOfTotal" and onGraphs and not graphs.shareApplies())
				or (sw.perGraph and customCharts)
				or nil
			y = y + metrics.catRowHeight
		else
			sw.draw, sw.hit, sw.disabled = nil, nil, nil
		end
	end
	-- The rule above the block, and where the group list has to stop.
	metrics.settingsTop = y + mathFloor(4 * s)
	if graphs then
		for i = 1, #switches do
			if switches[i].key == "milestoneKinds" then
				graphs.setKindsAnchor(switches[i].hit)
			end
		end
	end

	layoutColumns()
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------

-- `face` says which of the three the string is set in: the interface's own, the numbers'
-- or the names'.
local function queueText(str, x, y, size, opts, face)
	local at = pendingCount * 6
	pending[at + 1] = str
	pending[at + 2] = x
	pending[at + 3] = y
	pending[at + 4] = size
	pending[at + 5] = opts
	pending[at + 6] = face or false
	pendingCount = pendingCount + 1
end

-- One batch a face: it draws what was queued for it, in the order it was queued in. The
-- three never overlap on the screen, so the order between them does not matter.
local function flushBatch(face, key)
	local began = false
	for i = 0, pendingCount - 1 do
		local at = i * 6
		if pending[at + 6] == key then
			if not began then
				began = true
				face:Begin()
				face:SetOutlineColor(look.outline)
			end
			face:Print(pending[at + 1], pending[at + 2], pending[at + 3], pending[at + 4], pending[at + 5])
		end
	end
	if began then
		face:End()
	end
end

local function flushText()
	if pendingCount == 0 then
		return
	end

	flushBatch(font, false)
	flushBatch(metrics.numFont or font, "number")
	flushBatch(metrics.nameFont or font, "name")

	pendingCount = 0
end

-- The sort marker: a small triangle pointing the way the column is sorted.
---@type number, number, number, number, boolean, boolean
local triX, triY, triW, triH, triUp, triRight = 0, 0, 0, 0, false, false
local function triangleVertices()
	if triRight then
		glVertex(triX, triY)
		glVertex(triX, triY + triH)
		glVertex(triX + triW, triY + triH * 0.5)
	elseif triUp then
		glVertex(triX, triY)
		glVertex(triX + triW, triY)
		glVertex(triX + triW * 0.5, triY + triH)
	else
		glVertex(triX, triY + triH)
		glVertex(triX + triW, triY + triH)
		glVertex(triX + triW * 0.5, triY)
	end
end

local function drawTriMark(x, cy, up, right)
	triX, triY, triW, triH, triUp, triRight =
		x, cy - mathFloor(metrics.triH * 0.5), metrics.triW, metrics.triH, up, right
	glColor(look.sortMark)
	glBeginEnd(GL_TRIANGLES, triangleVertices)
	glColor(1, 1, 1, 1)
end

-- The mark under the number of a column its row leads: a short bar the width of the
-- number, in the warm hue the panel uses for what stands out.
local function drawLeadMark(column, cell, bottom)
	local w = mathFloor((metrics.numFont or font):GetTextWidth(cell) * metrics.rowFs)
	if w < 4 then
		return
	end
	RectRound(
		column.x2 - metrics.cellPad - w,
		bottom + metrics.leadDrop,
		column.x2 - metrics.cellPad,
		bottom + metrics.leadDrop + metrics.leadH,
		0,
		0,
		0,
		0,
		0,
		look.leadMark
	)
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
		row.fitName = text.fit(metrics.nameFont or font, team.label, room, metrics.rowFs)
		---@type table?
		---@diagnostic disable-next-line: undefined-field
		local me = (filters.vsMe and not team.isLocal) and allies.me or nil
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
		-- A side of one player is that player: the band says their name rather than the
		-- side's number, which would say nothing the colour does not. A side of more is
		-- named after itself, with how many players it holds beside it.
		local caption = row.team and row.team.label or BAR.I18N("ui.teamStats.team", { number = ally.id + 1 })
		local members = not row.team and BAR.I18N("ui.teamStats.members", { count = #ally.teams }) or nil
		local room = nameColumn.x2 - nameColumn.x1 - metrics.rowPad * 2
		local face = row.team and (metrics.nameFont or font) or font
		row.caption = text.fit(face, caption, room, metrics.bandFs)
		row.captionW = mathFloor(face:GetTextWidth(row.caption) * metrics.bandFs)
		-- The count goes after the caption when it fits beside it, and is dropped when
		-- not: cut short it would say nothing.
		local left = room - row.captionW - metrics.rowPad * 2 - metrics.triW * 2
		if members and font:GetTextWidth(members) * metrics.rowFs <= left then
			row.members = members
			row.membersW = mathFloor(font:GetTextWidth(members) * metrics.rowFs) + metrics.rowPad
		else
			row.members = nil
			row.membersW = 0
		end
		---@type table?
		---@diagnostic disable-next-line: undefined-field
		local mine = (filters.vsMe and allies.myAlly ~= ally) and allies.myAlly or nil
		local share = shareMode()
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

local function drawBand(row, top, bottom, hovered)
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
	local nameColumn = columns[1]
	---@cast nameColumn -?
	if hovered and not row.team then
		-- The caption is the fold button.
		Highlight(
			listX1,
			bottom,
			nameColumn.x2,
			top - metrics.csSmall,
			metrics.csSmall,
			look.rowHoverOpacity,
			look.white
		)
	end
	if row.team then
		RectRound(
			listX1,
			bottom + metrics.accentPad,
			listX1 + metrics.accentW,
			top - metrics.csSmall - metrics.accentPad,
			0,
			0,
			0,
			0,
			0,
			row.team.accent
		)
	end
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
	local captionX = listX1 + (row.team and metrics.nameIndent or metrics.rowPad)
	queueText(colorHeader .. row.caption, captionX, by, metrics.bandFs, "o", row.team and "name" or nil)
	if row.members then
		local team = row.team
		local color = colorDim
		if team then
			color = (team.dead or team.gone) and colorDim or team.nameColor
		end
		queueText(
			color .. row.members,
			captionX + metrics.rowPad * 2 + row.captionW,
			text.baseline(font, bottom, top, metrics.rowFs),
			metrics.rowFs,
			"o"
		)
	end
	if not row.team then
		-- Down while the band's players are shown, right once they are folded away.
		drawTriMark(
			captionX + metrics.rowPad * 2 + row.captionW + (row.membersW or 0),
			mathFloor((bottom + top - metrics.csSmall) * 0.5),
			false,
			row.folded == true
		)
	end
	local vy = text.baseline(font, bottom, top, metrics.rowFs)
	for i = 2, #columns do
		local v = row.vals[i]
		local valueColor = row.tones[i] or ((v == 0 or not isFinite(v)) and look.zeroText or colorTotal)
		queueText(valueColor .. row.cells[i], columns[i].x2 - metrics.cellPad, vy, metrics.rowFs, "or", "number")
		if row.ally.leads[columns[i].key] then
			drawLeadMark(columns[i], row.cells[i], bottom)
		end
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
	queueText(
		(quiet and colorDim or team.nameColor) .. row.fitName,
		listX1 + metrics.nameIndent,
		by,
		metrics.rowFs,
		"o",
		"name"
	)
	for i = 2, #columns do
		local v = row.vals[i]
		local valueColor
		if quiet then
			valueColor = colorDim
		elseif row.tones[i] then
			valueColor = row.tones[i]
		elseif v == 0 or not isFinite(v) then
			valueColor = look.zeroText
		elseif columns[i].key == sortKey then
			valueColor = look.sortedText
		else
			valueColor = colorValue
		end
		queueText(valueColor .. row.cells[i], columns[i].x2 - metrics.cellPad, by, metrics.rowFs, "or", "number")
		if team.leads[columns[i].key] then
			drawLeadMark(columns[i], row.cells[i], bottom)
		end
	end
end

-- Whole rows only: the band can end mid-row, and a row painted below it would be clipped
-- by nothing.
local function drawRows()
	local base = scrollOffset()

	-- The bars are scaled to the largest a column shows among the teams, and each column
	-- marks who leads it - the largest, or the smallest where less is better - among the
	-- players and among the ally teams: once a rebuild of the rows, for the columns on show.
	local facts = rowMetrics.facts
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
			colMax[key] = col.fmt ~= "plain" and top or nil
			-- Nobody leads a column everyone is at zero in.
			if bestTeam and bestValue ~= 0 then
				bestTeam.leads[key] = true
			end
			if bestAlly and bestTotal ~= 0 and #allies > 1 then
				bestAlly.leads[key] = true
			end
		end
	end

	-- The sorted column's tint, from the first row to the last one drawn, under them all.
	---@type table?
	local sortedColumn
	for i = 2, #columns do
		if columns[i].key == sortKey then
			sortedColumn = columns[i]
		end
	end
	if sortedColumn then
		-- From the top of the first row drawn - a band's plate starts a corner lower - to
		-- the bottom of the last.
		local first = rows[scroll + 1]
		local top = listTop - ((first and first.type == "band") and metrics.csSmall or 0)
		local bottom = listTop
		for i = scroll + 1, #rows do
			local rowBottom = listTop - (rows[i].off - base) - rowHeightOf(rows[i])
			if rowBottom < listBottom then
				break
			end
			bottom = rowBottom
		end
		if bottom < top then
			RectRound(sortedColumn.x1, bottom, sortedColumn.x2, top, metrics.csSmall, 0, 0, 1, 1, look.sortedFill)
			-- And a frame around it, from the first row to the last one drawn, so the column
			-- the table is ordered by is found at a glance. The caption stays outside: its
			-- sort marker says enough, and a frame up there would run into the group line.
			-- Plain whole-pixel rects, so all four sides are the same thickness.
			local x1, x2 = sortedColumn.x1, sortedColumn.x2
			glColor(look.sortedLine)
			gl.Rect(x1, bottom, x1 + 1, top)
			gl.Rect(x2 - 1, bottom, x2, top)
			gl.Rect(x1, top - 1, x2, top)
			gl.Rect(x1, bottom, x2, bottom + 1)
			glColor(1, 1, 1, 1)
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
			drawBand(row, top, bottom, hover.row == i)
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
				drawTriMark(c.x1 + metrics.nameIndent + c.statW + metrics.rowPad, cy, sortAscending, false)
			end
		else
			queueText(color .. c.fitStat, c.x2 - metrics.cellPad, sy, metrics.statFs, "or")
			-- In the padding after the caption, over the right edge the numbers line up on.
			if sorted then
				drawTriMark(c.x2 - metrics.cellPad + 1, cy, sortAscending, false)
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
		if y1 < metrics.settingsTop then
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
			if not (graphs.naming and graphs.naming.key == e.key) then
				queueText(color .. e.label, x1 + metrics.sidePad, mathFloor((y1 + y2) * 0.5), metrics.catFs, "ov")
			end
		end
	end
end

-- The switches and their captions. The plate goes behind the switch and the switch
-- lights itself: painting over it would only dull it.
-- The settings block under the groups: a rule, then a row per switch with its caption on
-- the left and its toggle on the right. A row the open view cannot use is dimmed and does
-- not answer the cursor.
local function drawSettings()
	local top = 0
	for i = 1, #switches do
		local sw = switches[i]
		if sw.draw and sw.heading then
			top = mathMax(top, sw.hit[4])
			queueText(
				colorFaded .. sw.label,
				sw.hit[1] + metrics.sidePad,
				mathFloor((sw.hit[2] + sw.hit[4]) * 0.5),
				metrics.toggleFs,
				"ov"
			)
		elseif sw.draw then
			top = mathMax(top, sw.hit[4])
			local hovered = hover.tog == i and not sw.disabled
			if hovered then
				Highlight(sw.hit[1], sw.hit[2], sw.hit[3], sw.hit[4], metrics.csSmall, look.rowHoverOpacity, look.white)
			end
			-- The Graphs switch shows the page's state, and the grouping switch the
			-- grouping of whichever of the two is open.
			local on = filters[sw.key]
			local graph = graphs.open and sw.perGraph and graphs.openGraph()
			if sw.mode then
				on = graphs.open
			elseif graph then
				-- The open custom graph's own.
				on = (sw.key == "groupByTeam" and graph.grouped)
					or (sw.key == "shareOfTotal" and graph.share)
					or (sw.key == "milestones" and graph.milestones)
			elseif sw.key == "groupByTeam" and graphs.open then
				on = graphs.grouped
			end
			local cy = mathFloor((sw.hit[2] + sw.hit[4]) * 0.5)
			queueText(
				(sw.disabled and colorFaded or (on and colorSelected or colorDim)) .. sw.label,
				sw.hit[1] + metrics.sidePad,
				cy,
				metrics.toggleFs,
				"ov"
			)
			if sw.value then
				queueText(
					(sw.disabled and colorFaded or colorSelected) .. tostring(graphs.settingValue(sw.key)),
					sw.hit[3] - metrics.sidePad,
					cy,
					metrics.toggleFs,
					"rov"
				)
			else
				UiToggle(sw.draw[1], sw.draw[2], sw.draw[3], sw.draw[4], on, hovered)
				if sw.disabled then
					-- FlowUI rounds a switch by a tenth of its height and draws an edge
					-- around it; the mute covers both.
					local edge = mathMax(1, mathFloor((sw.draw[4] - sw.draw[2]) * 0.1))
					RectRound(
						sw.draw[1] - edge,
						sw.draw[2] - edge,
						sw.draw[3] + edge,
						sw.draw[4] + edge,
						edge * 2,
						1,
						1,
						1,
						1,
						look.mutedFill
					)
				end
			end
		end
	end
	if top > 0 then
		local y = top + mathFloor(metrics.catRowHeight * 0.3)
		RectRound(
			area.x1 + metrics.sidePad,
			y,
			area.x1 + metrics.sidebarW - metrics.sidePad,
			y + 1,
			0,
			0,
			0,
			0,
			0,
			look.rule
		)
	end
end

-- Everything inside the panel: the column, the switches, the table and the scroller.
-- Baked and replayed until the cursor, the list or the screen moves.
local function drawPanel()
	drawSidebar()
	drawSettings()
	if graphs.open then
		graphs.drawPanel()
		local top, total, offset = select(5, scrollerThumb())
		if total > 0 then
			UiScroller(barX1, listBottom, area.x2 - metrics.edgeInset, top, total, offset, hover.bar == 1, dragging)
		end
		flushText()
		glColor(1, 1, 1, 1)
		return
	end
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
	graphs.dropTrendList()
	graphs.dropGridTexture()
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
	if mx >= barX1 and mx <= area.x2 then
		-- The thumb itself, not the track: it is the part that can be taken hold of, so it
		-- is the part that lights up.
		local top, height = scrollerThumb()
		if top and my <= top and my >= top - height then
			hover.bar = 1
		end
	end

	local extra = ""
	if graphs.open then
		extra = "|g" .. graphs.hoverAt(mx, my)
	elseif hover.tog == 0 and mx >= listX1 and mx < listRight then
		hover.hcol = headerColumnAt(mx, my) or 0
		if hover.hcol == 0 then
			hover.row = rowAt(my) or 0
			if hover.row > 0 then
				hover.col = columnAt(mx) or 0
			end
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
		.. extra
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
			if handover.shows(column) then
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
				label = label .. colorDim .. " \195\151" .. times[m.key]
			end
			parts[#parts + 1] = colorDim .. gameTime(m.frame) .. " " .. colorTitle .. label
			if #parts == 3 or i == #shown then
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
-- the overview, and is gone back to once it is shown again: it is still the player's pick.
local function rebuildEntries()
	entries = {}
	local want = handover.wanted or selectedGroup
	local wantShown, selectedStays = false, false
	local afterCustom = false
	for _, group in ipairs(GROUPS) do
		local shown = true
		if group.custom then
			entries[#entries + 1] = { key = group.key, label = group.label, custom = true }
			afterCustom = true
		else
			-- A rule between the player's categories and the built-in ones.
			if afterCustom then
				entries[#entries + 1] = { divider = true }
				afterCustom = false
			end
			shown = false
			for i = 1, #group.columns do
				if handover.shows(COLUMNS[group.columns[i]]) then
					shown = true
				end
			end
			if shown then
				entries[#entries + 1] = { key = group.key, label = L.group[group.key] }
			end
		end
		if shown then
			wantShown = wantShown or group.key == want
			selectedStays = selectedStays or group.key == selectedGroup
		end
	end
	if wantShown then
		selectedGroup, handover.wanted = want, nil
	elseif not selectedStays then
		-- Hidden, not gone: kept as the pick, and saved as it. A deleted one is not kept.
		if not handover.wanted and groupByKey[selectedGroup] then
			handover.wanted = selectedGroup
		end
		selectedGroup = "overview"
	end
	if not (showPlannedPages and handover.on) and graphs and graphs.open then
		-- The page went with the gadget: back to the table.
		graphs.open = false
	end
end

local function loadLabels()
	L.title = BAR.I18N("ui.teamStats.title")
	L.titleText = colorTitle .. L.title
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
	elseif handover.frame then
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

-- Reads the numbers, after settling whether the gadget is still there to read from. That
-- is only known while the panel listens: closed, it is handed nothing, and a read then - at
-- game over, or on a language change - would take its views and the page away for nothing.
local function refresh()
	if show then
		syncGadgetState(spGetGameFrame())
	end
	refreshStats()
	-- Whether the viewer has a team of their own is only known once the teams are read,
	-- which is after the first layout: the comparison switch lights up when it is. Only a
	-- switch laid out out of step is laid out again: a layout rebuilds every chart.
	---@diagnostic disable-next-line: undefined-field
	local canCompare = allies.me ~= nil
	for i = 1, #switches do
		local sw = switches[i]
		if sw.key == "vsMe" and sw.hit and (sw.disabled == true) == canCompare then
			setLayout()
		end
	end
	-- The page's histories are the table's trend lines too.
	if graphs.open or filters.trend then
		graphs.refresh()
	end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font = WG.fonts.getFont()
	metrics.numFont = WG.fonts.getFont(3)
	metrics.nameFont = WG.fonts.getFont(2)
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
	-- A graph pressed in a category of the player's own turns into a drag as it travels.
	graphs.dragUpdate(mx, my, lmb)
	-- An open card of actions has the cursor to itself, and so has a graph being dragged:
	-- nothing under them lights up.
	local hx, hy = mx, my
	if not show or graphs.menuOpen() or graphs.dragMoving() then
		hx, hy = -1, -1
	end

	-- The rows the table waited for while the Graphs page was on.
	if rowMetrics.stale and not graphs.open then
		rowMetrics.stale = false
		rebuildRows()
	end
	local sig = panelSignature(hx, hy)
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
	-- The table's trend lines, from a list of their own: the panel is baked again whenever
	-- the cursor moves onto another row, and would draw every line again with it.
	if show and filters.trend and not graphs.open then
		graphs.drawTrendList(rowsGen, scroll, layoutGen)
	end
	if show and graphs.open then
		-- The chart keeps its own list and draws its hover overlay straight, so the
		-- cursor moving over it never rebakes the panel.
		graphs.drawChart(hx, hy)
		graphs.drawDrag(mx, my)
	end
	-- A category being named: its field over its sidebar entry.
	if show and graphs.naming then
		for i = 1, #entries do
			if entries[i].key == graphs.naming.key then
				local x1, y1, x2, y2 = entryRect(i)
				graphs.drawNaming(x1 + metrics.catInset, y1, x2 - metrics.catInset, y2)
			end
		end
	end
	-- A card of actions, over everything, in either view.
	if show and graphs.menuOpen() then
		graphs.drawMenu(mx, my)
	end

	if WG.guishader and backgroundGuishader == nil then
		backgroundGuishader = glCreateList(function()
			RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 1, 1, 1, 1)
		end)
		WG.guishader.InsertDlist(backgroundGuishader, "teamstats", nil, widget)
	end
	showOnceMore = false

	if show and math_isInRect(mx, my, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		spSetMouseCursor("cursornormal")

		if WG.tooltip and not graphs.menuOpen() and not graphs.dragMoving() then
			local title, tip
			local entry = hover.sb > 0 and entries[hover.sb] or nil
			if graphs.open and hover.sb == 0 and hover.tog == 0 then
				title, tip = graphs.tooltip()
			elseif hover.hcol > 1 then
				local column = columns[hover.hcol]
				---@cast column -?
				title = columnTitle(column)
				tip = L.desc[column.key]
			elseif hover.tog > 0 then
				local sw = switches[hover.tog]
				---@cast sw -?
				title = sw.label
				tip = L.switchDesc[sw.key]
				-- In a custom category these rows are each graph's own.
				if sw.perGraph and graphs.open and groupByKey[selectedGroup] and groupByKey[selectedGroup].custom then
					tip = (tip or "") .. "\n" .. colorDim .. (graphs.openGraph() and L.perGraphOpen or L.perGraphGrid)
				end
			elseif entry and entry.disabled then
				title = entry.label
				tip = L.notYet
			elseif entry and entry.custom then
				title = entry.label
				-- The one that ships is reset rather than deleted.
				tip = entry.key == "overview" and L.overviewHint or L.categoryHint
			elseif hover.row > 0 and hover.col == 1 then
				-- Everything about the player, on the name: the columns the open view hides too.
				local row = rows[scroll + hover.row]
				if row and row.team then
					title = (row.team.nameColor or "") .. row.team.label
					tip = nameCard(row.team)
				elseif row then
					title = row.caption
					tip = L.foldHint
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
					if shareMode() and column.fmt == "si" and isFinite(v) then
						local total = ratio.grand(column.key)
						exact = BAR.I18N("ui.teamStats.partOfTotal", {
							share = stringFormat("%.1f%%", v),
							value = formatExact(
								column,
								row.type == "team" and baseValue(column, row.team) or row.ally.total[column.key]
							),
							total = formatExact(column, total),
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
	-- The ranking comes and goes with what may be seen: a spectator's, everyone's after the
	-- game. The views, the columns and the charts follow.
	local ranked = handover.rankedIn(all)
	if ranked ~= (handover.ranked == true) then
		handover.ranked = ranked
		if show then
			rebuildEntries()
			setLayout()
			dropLists()
		end
	end
	if show and (not gameover or handover.postGame) then
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
			handover.direct = widgetHandler:RegisterGlobal("TeamStatsLive", receiveLive)
		end
	else
		if hub then
			hub.unsubscribe("teamstats")
		end
		if handover.direct then
			widgetHandler:DeregisterGlobal("TeamStatsLive")
			handover.direct = false
		end
	end
end

local function closePanel()
	show = false
	dragging = false
	listen(false)
	-- A name being typed is kept; a card of actions and a drag are put away.
	graphs.stopNaming(true)
	graphs.closeMenu()
	graphs.drag = nil
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
	-- Listening while open only, so the gadget hands nothing over to a closed panel.
	listen(true)
	handover.opened = spGetGameFrame()
	-- The numbers freeze at game over; a panel first opened after it still needs one read.
	-- The charts ask for what they do not have yet whenever the panel opens: after game
	-- over nothing else would, and an answer the panel was closed for is lost.
	graphs.askAgain()
	if not gameover or #allies == 0 then
		refresh()
	elseif graphs.open or filters.trend then
		graphs.refresh()
	end
end

local function selectEntry(i)
	local e = entries[i] or {}
	if e.disabled then
		return
	end
	-- A pick of their own replaces the one waiting for the gadget to come back.
	handover.wanted = nil
	if e.key ~= selectedGroup then
		selectedGroup = e.key
		-- The whole header: the per-minute switch is only offered where a rate means
		-- something, and that changes with the group.
		setLayout()
	else
		return
	end
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
		setLayout()
	elseif sw.mode then
		-- The Graphs page is a mode: on, the sidebar's groups pick the stats it lists.
		graphs.open = not graphs.open
		setLayout()
		dropLists()
		if graphs.open then
			graphs.refresh()
			graphs.invalidate()
		end
	elseif sw.perGraph and graphs.open and graphs.openGraph() then
		-- A custom category's graph keeps its own: the switch sets it for that graph alone.
		local graph = graphs.openGraph()
		---@cast graph -?
		local field = key == "groupByTeam" and "grouped" or (key == "shareOfTotal" and "share" or "milestones")
		graph[field] = not graph[field]
		graphs.invalidate()
		setLayout()
	elseif key == "groupByTeam" and graphs.open then
		-- The page groups its own way: the table keeps the grouping it was left with.
		graphs.setGrouped(not graphs.grouped)
		-- Grouping decides whether the share switch is offered here too.
		setLayout()
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
			setLayout()
		else
			layoutColumns()
		end
		rebuildRows()
		-- The chart is made of what the switches say too.
		graphs.invalidate()
	end
	if playSounds then
		spPlaySoundFile(buttonclick, 0.6, "ui")
	end
end

function widget:KeyPress(key)
	-- A name being typed takes every key: Enter keeps it, Escape keeps the old one.
	if show and graphs.naming then
		return graphs.namingKey(key)
	end
	if show and key == 27 and graphs.menuOpen() then
		graphs.closeMenu()
		dropLists()
		return true
	end
	-- With one chart open, the arrow keys go through the category's charts; the settings
	-- follow the chart.
	if show and graphs.open and not graphs.menuOpen() and not graphs.kindsOpen then
		local stat = graphs.stat
		if graphs.keyPress(key) then
			if graphs.stat ~= stat then
				setLayout()
			end
			return true
		end
	end
	if show and key == 27 and graphs.open and graphs.kindsOpen then
		-- ESC closes what is open on the panel before it closes the panel.
		graphs.closeKinds()
		dropLists()
		return true
	end
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

	-- The Graphs page scrolls its grid of charts, or the rows of an open chart that has more
	-- than fit; the wheel is the panel's either way.
	if graphs.open then
		graphs.wheel(up)
		return true
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

	-- A graph pressed in a category of the player's own, let go wherever: opened, or moved
	-- to where it was dragged.
	if release and graphs.dragging() then
		local stat, applies = graphs.stat, graphs.shareApplies()
		graphs.mouseRelease(x, y)
		if graphs.stat ~= stat or graphs.shareApplies() ~= applies then
			setLayout()
		end
		return true
	end

	-- A press on a top bar button is the top bar's to handle: it closes the open windows
	-- and opens the one that was clicked. Closing (and consuming) here would swallow it.
	if WG.topbar and WG.topbar.buttonAt and WG.topbar.buttonAt(x, y) then
		return false
	end

	-- A card of actions takes every press while it is open, wherever it lands.
	if not release and graphs.menuOpen() then
		graphs.menuPress(x, y, button)
		dropLists()
		return true
	end
	-- Naming a category: a press in the field moves the caret, one anywhere else keeps the
	-- name typed so far and goes on to whatever it was on.
	if not release and graphs.naming then
		local r = graphs.naming.box.rect
		if math_isInRect(x, y, r[1], r[2], r[3], r[4]) then
			graphs.naming.box:mousePress(x, y)
			return true
		end
		graphs.stopNaming(true)
	end

	if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
		if not release and graphs.open and graphs.kindsOpen then
			graphs.mousePress(x, y, button)
			dropLists()
			return true
		end
		if not release and button == 3 then
			local sw = switchAt(x, y)
			local i = sidebarIndexAt(x, y)
			local entry = i and entries[i]
			if sw then
				-- A setting with a value steps back on the right button.
				toggleSwitch(sw, true)
			elseif entry and entry.custom then
				-- One of the player's categories: renamed, moved or deleted from its card.
				local x1, y1, x2, y2 = entryRect(i)
				graphs.openCategoryMenu(entry.key, { x1, y1, x2, y2 })
				dropLists()
			elseif graphs.open then
				-- The Graphs page's legend takes the right button too: it hides a team, which
				-- can leave one on the charts and the share with nothing to share out.
				local applies = graphs.shareApplies()
				graphs.mousePress(x, y, 3)
				if graphs.shareApplies() ~= applies then
					setLayout()
				end
			end
		elseif not release and button == 1 then
			local sw = switchAt(x, y)
			local i = sidebarIndexAt(x, y)
			local col = not graphs.open and x >= listX1 and x < listRight and headerColumnAt(x, y)
			local fold = nil
			if not graphs.open and x >= listX1 and x < listRight then
				local r = rowAt(y)
				local row = r and rows[scroll + r]
				if row and row.type == "band" and not row.team and columnAt(x) == 1 then
					fold = row.ally.id
				end
			end
			if sw then
				toggleSwitch(sw)
			elseif i then
				selectEntry(i)
			-- The bar owns its column in both views, so it is asked before the table's rows
			-- and before the page's charts.
			elseif math_isInRect(x, y, barX1, listBottom, area.x2, select(5, scrollerThumb()) or listTop) then
				-- The strip between the bar and the panel edge stays grabbable too.
				grabScroller(y)
			elseif graphs.open then
				local stat, applies = graphs.stat, graphs.shareApplies()
				graphs.mousePress(x, y, 1)
				-- Another stat, or a pick that leaves one team on the charts, changes what the
				-- settings offer: they are laid out again.
				if graphs.stat ~= stat or graphs.shareApplies() ~= applies then
					setLayout()
				end
			elseif fold then
				collapsed[fold] = not collapsed[fold] or nil
				rebuildRows()
				if playSounds then
					spPlaySoundFile(buttonclick, 0.6, "ui")
				end
			elseif col then
				sortBy(columns[col])
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

function widget:TextInput(utf8char)
	if show and graphs.naming then
		return graphs.namingText(utf8char)
	end
	return false
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
	-- A reloaded API widget forgets its subscribers; this puts the panel back on its list.
	listen(true)
	refresh()
end

-- The numbers stop at game over: what happens in the minutes after is not the game.
function widget:GameOver()
	-- The gadget takes its last sample and opens every team's numbers: asked for again, as
	-- nothing refreshes the charts on its own after this.
	graphs.askAgain()
	refresh()
	gameover = true
	handover.postGame = true
	handover.overFrame = spGetGameFrame()
end

function widget:TeamDied(teamID)
	deathFrame[teamID] = spGetGameFrame()
end

function widget:ApmEvent(teamID, apm)
	teamAPM[teamID] = apm
end

-- Who the viewer is decides which row is theirs and which colours they may see. A spectator
-- switching the team they watch lands here too.
function widget:PlayerChanged()
	isSpec = spGetSpectatingState()
	localTeamID = spGetLocalTeamID()
	-- A player resigning or being knocked out leaves their team without a leader: their name
	-- is still to be had at this moment, and kept for the rows.
	handover.rememberNames()
	if show and not gameover then
		refresh()
	elseif gameover then
		-- The numbers stay as the game left them; only whose team is the viewer's moves.
		---@diagnostic disable-next-line: inject-field
		allies.me, allies.myAlly = nil, nil
		for _, ally in ipairs(allies) do
			for _, team in ipairs(ally.teams) do
				team.isLocal = team.id == localTeamID
				if team.isLocal then
					---@diagnostic disable-next-line: inject-field
					allies.me, allies.myAlly = team, ally
				end
			end
		end
		rebuildRows()
	end
	-- The page's You button follows the team the viewer watches.
	graphs.invalidate()
end

function widget:Initialize()
	loadLabels()
	handover.rememberNames()
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
	-- The Graphs page, for a key or another widget: opens the panel on it when needed.
	WG.teamstats.showGraphs = function(state)
		if state == nil then
			state = not graphs.open
		end
		if state and not show then
			setShown(true)
		end
		if state ~= graphs.open then
			for i, sw in ipairs(switches) do
				if sw.mode and sw.hit then
					toggleSwitch(i)
				end
			end
		end
	end
end

function widget:Shutdown()
	dropLists()
	deleteGuishader()
	graphs.destroy()
	listen(false)
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("teamstats")
	end
	WG.teamstats = nil
end

-- The sort, the view and the switches are kept between games: someone who reads the
-- table one way wants it that way every time they open it.
function widget:GetConfigData()
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
		sortKey = sortKey,
		sortAscending = sortAscending,
		-- The player's pick, even while the gadget's absence has it hidden.
		group = handover.wanted or selectedGroup,
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
	return data
end

-- Runs before Initialize, so the first layout already honours it.
function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	-- The names read in this same game, from before a reload.
	if
		data.gameID
		and data.gameID == (Game.gameID or spGetGameRulesParam("GameID"))
		and type(data.names) == "table"
	then
		for teamID, name in pairs(data.names) do
			if type(name) == "string" and name ~= "" then
				teamControllers[tonumber(teamID) or teamID] = name
			end
		end
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
	-- The page's settings first: they hold the custom categories the open group may be.
	graphs.setConfig(data)
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
	handover.idents = {}
	widget:ViewResize()
	-- Names with a dead or gone suffix are read in the language of the read.
	if #allies > 0 and not gameover then
		refresh()
	end
end

-- The Graphs page, handed everything of the panel's it reads. Made here, at the end, so
-- every function above is in reach of it; the callins run later than this.
graphs = VFS.Include("luaui/Include/teamstats_graphs.lua").new({
	COLUMNS = COLUMNS,
	GROUPS = GROUPS,
	groupByKey = groupByKey,
	L = L,
	columnTitle = columnTitle,
	derive = derive,
	derivedInputs = ratio.inputs,
	columnShown = handover.shows,
	-- The history behind every number on screen, for the page's trend list: in the team's
	-- own colour, a band's in its team's when it is one team's, else in the header's hue;
	-- beside the number, in what it leaves of its cell, so neither is read through the other.
	trendRows = function()
		local base = scrollOffset()
		for i = scroll + 1, #rows do
			local row = rows[i]
			---@cast row -?
			local top = listTop - (row.off - base)
			local bottom = top - rowHeightOf(row)
			if bottom < listBottom then
				break
			end
			fitRow(row)
			if row.trendKey then
				local team = row.team
				local color, lineTop
				if row.type == "band" then
					local accent = team and team.accent
					color = accent and { accent[1], accent[2], accent[3], 0.65 } or look.trendBand
					lineTop = top - metrics.csSmall - metrics.barInset
				else
					---@cast team -?
					color = { team.accent[1], team.accent[2], team.accent[3], (team.dead or team.gone) and 0.4 or 0.75 }
					lineTop = top - metrics.barInset
				end
				for c = 2, #columns do
					local column = columns[c]
					---@cast column -?
					local right = column.x2
						- metrics.cellPad
						- mathFloor((metrics.numFont or font):GetTextWidth(row.cells[c]) * metrics.rowFs)
					graphs.trendCell(
						row.trendKey,
						column.key,
						column.rate == true,
						column.x1 + metrics.cellPad,
						bottom + metrics.barInset,
						right - metrics.rowPad,
						lineTop,
						color,
						metrics.trendW
					)
				end
			end
		end
	end,
	look = look,
	metrics = metrics,
	colors = {
		title = colorTitle,
		dim = colorDim,
		faded = colorFaded,
		selected = colorSelected,
		value = colorValue,
		bad = colorBad,
	},
	-- The categories changed: the sidebar, the columns and the stat list follow.
	categoriesChanged = function()
		rebuildEntries()
		setLayout()
		graphs.invalidate()
		dropLists()
	end,
	selectGroup = function(key)
		selectedGroup, handover.wanted = key, nil
		setLayout()
	end,
	-- Typed text reaches a widget only while SDL is asked for it.
	textInput = function(on)
		if on and Spring.SDLStartTextInput then
			Spring.SDLStartTextInput()
		elseif not on and Spring.SDLStopTextInput then
			Spring.SDLStopTextInput()
		end
	end,
	-- The FlowUI draw calls are fetched at ViewResize, so they are read when called; the
	-- plain rect is for whole-pixel lines and squares.
	draw = {
		RectRound = function(...)
			return RectRound(...)
		end,
		Highlight = function(...)
			return Highlight(...)
		end,
		Color = glColor,
		Rect = gl.Rect,
		-- Looked up when drawn: FlowUI is there by then.
		RectRoundOutline = function(...)
			return WG.FlowUI.Draw.RectRoundOutline(...)
		end,
		Toggle = function(...)
			return UiToggle(...)
		end,
	},
	queueText = queueText,
	text = text,
	font = function()
		return font
	end,
	-- The face the interface names players in, for what the page calls a team or a player.
	nameFont = function()
		return metrics.nameFont or font
	end,
	filters = filters,
	soloTeams = soloTeams,
	selectedGroup = function()
		return selectedGroup
	end,
	allies = function()
		return allies
	end,
	live = function()
		return handover.all
	end,
	gadgetOn = function()
		return handover.on
	end,
	frame = spGetGameFrame,
	history = spGetTeamStatsHistory,
	-- Only while the panel is on the hub's list: a history asked for then comes back to it.
	hub = function()
		local hub = WG.teamStats
		return hub and hub.isSubscribed("teamstats") and hub or nil
	end,
	overFrame = function()
		return handover.overFrame
	end,
	-- Whether the ally teams' places in a ranking may be seen, more than one of them.
	ranked = function()
		return handover.ranked == true
	end,
	i18n = BAR.I18N,
	playSound = function()
		if playSounds then
			spPlaySoundFile(buttonclick, 0.6, "ui")
		end
	end,
})
