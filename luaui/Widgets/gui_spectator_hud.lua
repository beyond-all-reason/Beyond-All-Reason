local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Spectator HUD",
		desc = "Display Game Metrics",
		author = "CMDR*Zod",
		date = "2024",
		license = "GNU GPL v3 (or later)",
		layer = 2, -- after eco stats widget which is on layer 1; see Initialize()
		handler = true,
		enabled = false
	}
end

--[[
Spectator HUD is a widget that displays various game metrics. It is only enabled in spectator mode and only works when
spectating a game between two allyTeams (excluding Gaia). The widget is drawn at the top-right corner of the screen.

Each metric is displayed on it's own row. Each metric row has to the left a shorthand text representation of the metric
such as "M/s" for metal income. Then, each row has a metric bar.

The metric bar is split in two, one for each allyTeam. In the middle of the bar is a "knob" that moves according to
the balance of the metric. For example, if the balance of a metric is 2:1, then the the team at the left will have a
bar twice as long the team to the right. Furthermore, on the sides of the metric bars are two more "knobs" that
contain a text value display of the metric amounts.

 ---------------------------------------------------------------------------------
|  -------     -------                          -------                   ------  |
| |  M/s  |   |   12  |------------------------|   4   |-----------------|   8  | |
|  -------     -------                          -------                   ------  |
 ---------------------------------------------------------------------------------

Above is an ASCII art depiction of how a single metric display is rendered.

All geometry variables are calculated during widget initialization. In the render pass during DrawScreen() geometry
variables are mainly accessed, not computed. Especially horizontal values can be pre-calculated as they're same for all
metrics. The exception to this are the metric bars themselves as they are dynamic in size and depend on statistics from
the game in progress.

The geometry information is stored in global tables that are named like {something}Dimensions, e.g. widgetDimensions.
All geometry is resized according to both the game overall "ui_scale" and widget-specific option widgetScale.

The enabled metrics are configurable options. The table metricsAvailable contain all metrics. During widget
initialization, the table metricsEnabled is populated with the enabled metrics.

Note that the widget can be soft reset. Events causing a soft reset include changing widget size, changing enabled
metrics or changing from spectating view to player view.
]]

local viewScreenWidth
local viewScreenHeight

local LuaShader = gl.LuaShader

local mathfloor = math.floor
local mathabs = math.abs

local glColor = gl.Color
local glRect = gl.Rect

local gaiaID = Spring.GetGaiaTeamID()
local gaiaAllyID = select(6, Spring.GetTeamInfo(gaiaID, false))

local widgetEnabled = nil
local ecostatsHidden = false

local haveFullView = false

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local scaleMultiplier = nil

local widgetDimensions = {}
local metricDimensions = {}
local titleDimensions = {}
local knobDimensions = {}
local barDimensions = {}

local textColorWhite = { 1, 1, 1, 1 }

local knobVAO = nil
local metricDisplayLists = {}

local shader = nil

local regenerateTextTextures = true
local titleTexture = nil
local titleTextureDone = false
local statsTexture = nil
local updateNow = false

local knobVertexShaderSource = [[
#version 420
#line 10000
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 pos;
layout (location = 1) in vec4 posBias;
layout (location = 2) in vec4 aKnobColor;

out vec4 knobColor;

#line 15000
void main() {
	gl_Position = pos + posBias;
	knobColor = aKnobColor;
}
]]

-- Add uniform color for the whole knob
local knobFragmentShaderSource = [[
#version 420
#line 20000
out vec4 FragColor;

in vec4 knobColor;

#line 25000
void main() {
	FragColor = knobColor;
}
]]

local function coordinateScreenToOpenGL(screenCoord, screenSize)
	return screenCoord / screenSize * 2.0 - 1.0
end
local function coordinateScreenXToOpenGL(screenCoord)
	return coordinateScreenToOpenGL(screenCoord, viewScreenWidth)
end
local function coordinateScreenYToOpenGL(screenCoord)
	return coordinateScreenToOpenGL(screenCoord, viewScreenHeight)
end

-- note: the different between defaults and constants is that defaults are adjusted according to
-- screen size, widget size and ui scale. On the other hand, constants do not change.
local constants = {
	darkerBarsFactor = 0.4,
	darkerLinesFactor = 0.7,
	darkerSideKnobsFactor = 0.6,
	darkerMiddleKnobFactor = 0.75,

	darkerDecal = 0.8,

	titleDimensions = {
		heightToWidthFactor = 1.5,
	},

	knobDimensions = {
		heightToWidthFactor = 2,
	},

	configLevel = {
		basic = 1,
		advanced = 2,
		expert = 3,
		custom = 4,
		unavailable = 5,
	},
}

local defaults = {
	widgetDimensions = {
		width = 768,
		-- height is determined by metric height and amount of metrics

		borderPadding = 5,
		distanceFromTopBar = 10,
	},

	metricDimensions = {
		height = 80,
		-- width is same as widget width
	},

	titleDimensions = {
		fontSize = 40,

		padding = 6,
	},

	knobDimensions = {
		fontSize = 44,

		cornerSize = 8,
		outline = 4,
		padding = 8,
	},

	barDimensions = {
		padding = 12,
		lineHeight = 8,
	},
}

local settings = {
	useMovingAverage = false,
	movingAverageWindowSize = 16,

	statsUpdateFrequency = 2,		 -- every 2nd frame

	widgetScale = 0.8,
	widgetConfig = constants.configLevel.basic,

	-- this table is used only when widgetConfig is set to custom
	metricsEnabled = {},
	oneTimeEcostatsEnableDone = false,
}

local metricKeys = {
	metalIncome = "metalIncome",
	energyConversionMetalIncome = "energyConversionMetalIncome",
	energyIncome = "energyIncome",
	buildPower = "buildPower",
	metalProduced = "metalProduced",
	energyProduced = "energyProduced",
	metalExcess = "metalExcess",
	energyExcess = "energyExcess",
	armyValue = "armyValue",
	defenseValue = "defenseValue",
	utilityValue = "utilityValue",
	economyValue = "economyValue",
	damageDealt = "damageDealt",
	damageReceived = "damageReceived",
	damageEfficiency = "damageEfficiency",
}

local metricsAvailable = {
	{ key="metalIncome", configLevel=constants.configLevel.basic, text="M/s" },
	{ key="reclaimMetalIncome", configLevel=constants.configLevel.unavailable, text="MR" },
	{ key="energyConversionMetalIncome", configLevel=constants.configLevel.unavailable, text="EC" },
	{ key="energyIncome", configLevel=constants.configLevel.basic, text="E/s" },
	{ key="reclaimEnergyIncome", configLevel=constants.configLevel.unavailable, text="ER" },
	{ key="buildPower", configLevel=constants.configLevel.expert, text="BP" },
	{ key="metalProduced", configLevel=constants.configLevel.basic, text="MP" },
	{ key="energyProduced", configLevel=constants.configLevel.basic, text="EP" },
	{ key="metalExcess", configLevel=constants.configLevel.expert, text="ME" },
	{ key="energyExcess", configLevel=constants.configLevel.expert, text="EE" },
	{ key="armyValue", configLevel=constants.configLevel.basic, text="AV" },
	{ key="defenseValue", configLevel=constants.configLevel.advanced, text="DV" },
	{ key="utilityValue", configLevel=constants.configLevel.unavailable, text="UV" },
	{ key="economyValue", configLevel=constants.configLevel.expert, text="EV" },
	{ key="damageDealt", configLevel=constants.configLevel.advanced, text="Dmg" },
	{ key="damageReceived", configLevel=constants.configLevel.unavailable, text="DR" },
	{ key="damageEfficiency", configLevel=constants.configLevel.unavailable, text="D%" },
}
local metricsEnabled = {}

-- set defaults before loading values from config
for _,metric in ipairs(metricsAvailable) do
	settings.metricsEnabled[metric.key] = metric.configLevel == constants.configLevel.basic
end

local allyTeamTable = nil

local playerData = nil
local teamOrder = nil

local teamStats = nil

local unitCache = {}
local cachedTotals = {}
local unitDefsToTrack = {}

local function checkAndUpdateHaveFullView()
	local haveFullViewOld = haveFullView
	haveFullView = select(2, Spring.GetSpectatingState())
	return haveFullView ~= haveFullViewOld
end

local function buildUnitDefs()
	local function isCommander(unitDefID, unitDef)
		return unitDef.customParams.iscommander
	end

	local function isReclaimerUnit(unitDefID, unitDef)
		return unitDef.isBuilder and not unitDef.isFactory
	end

	local function isEnergyConverter(unitDefID, unitDef)
		return unitDef.customParams.energyconv_capacity and unitDef.customParams.energyconv_efficiency
	end

	local function isBuildPower(unitDefID, unitDef)
		return unitDef.buildSpeed and (unitDef.buildSpeed > 0) and unitDef.canAssist
	end

	local function isArmyUnit(unitDefID, unitDef)
		-- anything with a least one weapon and speed above zero is considered an army unit
		return unitDef.weapons and (#unitDef.weapons > 0) and unitDef.speed and (unitDef.speed > 0)
	end

	local function isDefenseUnit(unitDefID, unitDef)
		return unitDef.weapons and (#unitDef.weapons > 0) and (not unitDef.speed or (unitDef.speed == 0))
	end

	local function isUtilityUnit(unitDefID, unitDef)
		return unitDef.customParams.unitgroup == 'util'
	end

	local function isEconomyBuilding(unitDefID, unitDef)
		return (unitDef.customParams.unitgroup == 'metal') or (unitDef.customParams.unitgroup == 'energy')
	end

	unitDefsToTrack = {}
	unitDefsToTrack.commanderUnitDefs = {}
	unitDefsToTrack.reclaimerUnitDefs = {}
	unitDefsToTrack.energyConverterDefs = {}
	unitDefsToTrack.buildPowerDefs = {}
	unitDefsToTrack.armyUnitDefs = {}
	unitDefsToTrack.defenseUnitDefs = {}
	unitDefsToTrack.utilityUnitDefs = {}
	unitDefsToTrack.economyBuildingDefs = {}

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if isCommander(unitDefID, unitDef) then
			unitDefsToTrack.commanderUnitDefs[unitDefID] = true
		end
		if isReclaimerUnit(unitDefID, unitDef) then
			unitDefsToTrack.reclaimerUnitDefs[unitDefID] = { unitDef.metalMake, unitDef.energyMake }
		end
		if isEnergyConverter(unitDefID, unitDef) then
			unitDefsToTrack.energyConverterDefs[unitDefID] = tonumber(unitDef.customParams.energyconv_capacity)
		end
		if isBuildPower(unitDefID, unitDef) then
			unitDefsToTrack.buildPowerDefs[unitDefID] = unitDef.buildSpeed
		end
		if isArmyUnit(unitDefID, unitDef) then
			unitDefsToTrack.armyUnitDefs[unitDefID] = { unitDef.metalCost, unitDef.energyCost }
		end
		if isDefenseUnit(unitDefID, unitDef) then
			unitDefsToTrack.defenseUnitDefs[unitDefID] = { unitDef.metalCost, unitDef.energyCost }
		end
		if isUtilityUnit(unitDefID, unitDef) then
			unitDefsToTrack.utilityUnitDefs[unitDefID] = { unitDef.metalCost, unitDef.energyCost }
		end
		if isEconomyBuilding(unitDefID, unitDef) then
			unitDefsToTrack.economyBuildingDefs[unitDefID] = { unitDef.metalCost, unitDef.energyCost }
		end
	end
end

local function addToUnitCache(teamID, unitID, unitDefID)
	local function addToUnitCacheInternal(cache, teamID, unitID, value)
		if unitCache[teamID][cache] then
			if not unitCache[teamID][cache][unitID] then
				if cachedTotals[teamID][cache] then
					local valueToAdd = 0
					if unitCache[cache].add then
						valueToAdd = unitCache[cache].add(unitID, value)
					end
					cachedTotals[teamID][cache] = cachedTotals[teamID][cache] + valueToAdd
				end
				unitCache[teamID][cache][unitID] = value
			end
		end
	end

	if unitDefsToTrack.reclaimerUnitDefs[unitDefID] then
		addToUnitCacheInternal("reclaimerUnits", teamID, unitID,
					   unitDefsToTrack.reclaimerUnitDefs[unitDefID])
	end
	if unitDefsToTrack.energyConverterDefs[unitDefID] then
		addToUnitCacheInternal("energyConverters", teamID, unitID,
					   unitDefsToTrack.energyConverterDefs[unitDefID])
	end
	if unitDefsToTrack.buildPowerDefs[unitDefID] then
		addToUnitCacheInternal("buildPower", teamID, unitID,
					   unitDefsToTrack.buildPowerDefs[unitDefID])
	end
	if unitDefsToTrack.armyUnitDefs[unitDefID] then
		addToUnitCacheInternal("armyUnits", teamID, unitID,
					   unitDefsToTrack.armyUnitDefs[unitDefID])
	end
	if unitDefsToTrack.defenseUnitDefs[unitDefID] then
		addToUnitCacheInternal("defenseUnits", teamID, unitID,
					   unitDefsToTrack.defenseUnitDefs[unitDefID])
	end
	if unitDefsToTrack.utilityUnitDefs[unitDefID] then
		addToUnitCacheInternal("utilityUnits", teamID, unitID,
					   unitDefsToTrack.utilityUnitDefs[unitDefID])
	end
	if unitDefsToTrack.economyBuildingDefs[unitDefID] then
		addToUnitCacheInternal("economyBuildings", teamID, unitID,
					   unitDefsToTrack.economyBuildingDefs[unitDefID])
	end
end

local function removeFromUnitCache(teamID, unitID, unitDefID)
	local function removeFromUnitCacheInternal(cache, teamID, unitID, value)
		if unitCache[teamID][cache] then
			if unitCache[teamID][cache][unitID] then
				if cachedTotals[teamID][cache] then
					local valueToRemove = 0
					if unitCache[cache].remove then
						valueToRemove = unitCache[cache].remove(unitID, value)
					end
					cachedTotals[teamID][cache] = cachedTotals[teamID][cache] - valueToRemove
				end
				unitCache[teamID][cache][unitID] = nil
			end
		end
	end

	if unitDefsToTrack.reclaimerUnitDefs[unitDefID] then
		removeFromUnitCacheInternal("reclaimerUnits", teamID, unitID,
					   unitDefsToTrack.reclaimerUnitDefs[unitDefID])
	end
	if unitDefsToTrack.energyConverterDefs[unitDefID] then
		removeFromUnitCacheInternal("energyConverters", teamID, unitID,
					   unitDefsToTrack.energyConverterDefs[unitDefID])
	end
	if unitDefsToTrack.buildPowerDefs[unitDefID] then
		removeFromUnitCacheInternal("buildPower", teamID, unitID,
					   unitDefsToTrack.buildPowerDefs[unitDefID])
	end
	if unitDefsToTrack.armyUnitDefs[unitDefID] then
		removeFromUnitCacheInternal("armyUnits", teamID, unitID,
					   unitDefsToTrack.armyUnitDefs[unitDefID])
	end
	if unitDefsToTrack.defenseUnitDefs[unitDefID] then
		removeFromUnitCacheInternal("defenseUnits", teamID, unitID,
					   unitDefsToTrack.defenseUnitDefs[unitDefID])
	end
	if unitDefsToTrack.utilityUnitDefs[unitDefID] then
		removeFromUnitCacheInternal("utilityUnits", teamID, unitID,
					   unitDefsToTrack.utilityUnitDefs[unitDefID])
	end
	if unitDefsToTrack.economyBuildingDefs[unitDefID] then
		removeFromUnitCacheInternal("economyBuildings", teamID, unitID,
					   unitDefsToTrack.economyBuildingDefs[unitDefID])
	end
end

local function buildUnitCache()
	unitCache = {}
	cachedTotals = {}

	unitCache.reclaimerUnits = {
		add = nil,
		update = function(unitID, value)
			local reclaimMetal = 0
			local reclaimEnergy = 0
			local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(unitID)
			if metalMake then
				if value[1] then
					reclaimMetal = metalMake - value[1]
				else
					reclaimMetal = metalMake
				end
				if value[2] then
					reclaimEnergy = energyMake - value[2]
				else
					reclaimEnergy = energyMake
				end
			end
			return { reclaimMetal, reclaimEnergy }
		end,
		remove = nil,
	}
	unitCache.energyConverters = {
		add = nil,
		update = function(unitID, value)
			local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(unitID)
			if metalMake then
				return metalMake
			end
			return 0
		end,
		remove = nil,
	}
	unitCache.buildPower = {
		add = function(unitID, value)
			return value
		end,
		update = nil,
		remove = function(unitID, value)
			return value
		end,
	}
	unitCache.armyUnits = {
		add = function(unitID, value)
			local result = value[1]
			--if options.useMetalEquivalent70 then
			--	  result = result + (value[2] / 70)
			--end
			return result
		end,
		update = nil,
		remove = function(unitID, value)
			local result = value[1]
			--if options.useMetalEquivalent70 then
			--	  result = result + (value[2] / 70)
			--end
			return result
		end,
	}
	unitCache.defenseUnits = unitCache.armyUnits
	unitCache.utilityUnits = unitCache.armyUnits
	unitCache.economyBuildings = unitCache.armyUnits

	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			local teamList = Spring.GetTeamList(allyID)
			for _, teamID in ipairs(teamList) do
				unitCache[teamID] = {}
				cachedTotals[teamID] = {}
				unitCache[teamID].reclaimerUnits = {}
				cachedTotals[teamID].reclaimerUnits = 0
				unitCache[teamID].energyConverters = {}
				cachedTotals[teamID].energyConverters = 0
				unitCache[teamID].buildPower = {}
				cachedTotals[teamID].buildPower = 0
				unitCache[teamID].armyUnits = {}
				cachedTotals[teamID].armyUnits = 0
				unitCache[teamID].defenseUnits = {}
				cachedTotals[teamID].defenseUnits = 0
				unitCache[teamID].utilityUnits = {}
				cachedTotals[teamID].utilityUnits = 0
				unitCache[teamID].economyBuildings = {}
				cachedTotals[teamID].economyBuildings = 0
				local unitIDs = Spring.GetTeamUnits(teamID)
				for i=1,#unitIDs do
					local unitID = unitIDs[i]
					if not Spring.GetUnitIsBeingBuilt(unitID) then
						local unitDefID = Spring.GetUnitDefID(unitID)
						addToUnitCache(teamID, unitID, unitDefID)
					end
				end
			end
		end
	end
end

local function buildPlayerData()
	playerData = {}
	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			local teamList = Spring.GetTeamList(allyID)
			for _,teamID in ipairs(teamList) do
				local playerName = nil
				local playerID = Spring.GetPlayerList(teamID, false)
				if playerID and playerID[1] then
					-- it's a player
					playerName = select(1, Spring.GetPlayerInfo(playerID[1], false))
				else
					local aiName = Spring.GetGameRulesParam("ainame_" .. teamID)
					if aiName then
						-- it's AI
						playerName = aiName
					else
						-- player is gone
						playerName = "(gone)"
					end
				end

				playerData[teamID] = {}
				playerData[teamID].name = playerName

				local teamColor = { Spring.GetTeamColor(teamID) }
				playerData[teamID].color = teamColor
			end
		end
	end
end

local function makeDarkerColor(color, factor, alpha)
	local newColor = {}

	if factor then
		newColor[1] = color[1] * factor
		newColor[2] = color[2] * factor
		newColor[3] = color[3] * factor
	else
		newColor[1] = color[1]
		newColor[2] = color[2]
		newColor[3] = color[3]
	end

	if alpha then
		newColor[4] = alpha
	else
		newColor[4] = color[4]
	end

	return newColor
end

local function round(num, idp)
	local mult = 10 ^ (idp or 0)
	return mathfloor(num * mult + 0.5) / mult
end

local function formatResources(amount, short)
	local thousand = 1000
	local tenThousand = 10 * thousand
	local million = thousand * thousand
	local tenMillion = 10 * million

	if short then
		if amount >= tenMillion then
			return string.format("%dM", amount / million)
		elseif amount >= million then
			return string.format("%.1fM", amount / million)
		elseif amount >= tenThousand then
			return string.format("%dk", amount / thousand)
		elseif amount >= thousand then
			return string.format("%.1fk", amount / thousand)
		else
			return string.format("%d", amount)
		end
	end

	local function addSpaces(number)
		if number >= 1000 then
			return string.format("%s %03d", addSpaces(mathfloor(number / 1000)), number % 1000)
		end
		return number
	end
	return addSpaces(round(amount))
end

local function buildAllyTeamTable()
	-- Data structure layout:
	-- allyTeamTable
	--	- allyTeamIndex
	--		- colorCaptain
	--		- colorBar
	--		- colorLine
	--		- colorKnobSide
	--		- colorKnobMiddle
	--		- name
	--		- spawn?
	--		- teams
	allyTeamTable = {}

	local allyTeamIndex = 1
	for _,allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			allyTeamTable[allyTeamIndex] = {}

			local teamList = Spring.GetTeamList(allyID)
			local colorCaptain = playerData[teamList[1]].color
			allyTeamTable[allyTeamIndex].color = colorCaptain
			allyTeamTable[allyTeamIndex].colorBar = makeDarkerColor(colorCaptain, constants.darkerBarsFactor)
			allyTeamTable[allyTeamIndex].colorLine = makeDarkerColor(colorCaptain, constants.darkerLinesFactor)
			allyTeamTable[allyTeamIndex].colorKnobSide = makeDarkerColor(colorCaptain, constants.darkerSideKnobsFactor)
			allyTeamTable[allyTeamIndex].colorKnobMiddle = makeDarkerColor(colorCaptain, constants.darkerMiddleKnobFactor)
			allyTeamTable[allyTeamIndex].name = string.format("Team %d", allyID)

			allyTeamTable[allyTeamIndex].teams = {}

			local teamIndex = 1
			for _,teamID in ipairs(teamList) do
				allyTeamTable[allyTeamIndex].teams[teamIndex] = teamID
				teamIndex = teamIndex + 1
			end

			allyTeamIndex = allyTeamIndex + 1
		end
	end
end

local function getAmountOfAllyTeams()
	local amountOfAllyTeams = 0
	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			amountOfAllyTeams = amountOfAllyTeams + 1
		end
	end
	return amountOfAllyTeams
end

local function buildMetricsEnabled()
	metricsEnabled = {}
	local index = 1
	for _,metric in ipairs(metricsAvailable) do
		local addMetric = false
		if settings.widgetConfig == constants.configLevel.custom then
			if settings.metricsEnabled[metric.key] then
				addMetric = true
			end
		elseif settings.widgetConfig >= metric.configLevel then
			addMetric = true
		end

		if addMetric then
			local metricEnabled = table.copy(metric)
			metricEnabled.id = index
			metricsEnabled[index] = metricEnabled
			local i18nTitleKey = "ui.spectator_hud." .. metricEnabled.key .. "_title"
			metricEnabled.title = Spring.I18N(i18nTitleKey)
			local i18nTooltipKey = "ui.spectator_hud." .. metricEnabled.key .. "_tooltip"
			metricEnabled.tooltip = Spring.I18N(i18nTooltipKey)
			index = index + 1
		end
	end
end

local function getWidgetHeightMax()
	-- TODO: check that we don't overlap with advplayerlist
	return viewScreenHeight / 2
end

local function calculateWidgetDimensions()
	-- calculate base for scaleMultiplier
	scaleMultiplier = ui_scale * settings.widgetScale * viewScreenWidth / 3840

	-- widget is not allowed to be too tall
	widgetDimensions.height = math.min(
		math.floor(defaults.metricDimensions.height * #metricsEnabled * scaleMultiplier),
		getWidgetHeightMax())

	-- every metric gets same amount of pixels
	metricDimensions.height = math.floor(widgetDimensions.height / #metricsEnabled)

	-- recalculate widget height based on metric height
	widgetDimensions.height = metricDimensions.height * #metricsEnabled

	-- scaleMultiplier has to be recalculated after potentially shrinking widget height
	scaleMultiplier = widgetDimensions.height / (defaults.metricDimensions.height * #metricsEnabled)

	widgetDimensions.width = math.floor(defaults.widgetDimensions.width * scaleMultiplier)

	widgetDimensions.borderPadding = mathfloor(defaults.widgetDimensions.borderPadding * scaleMultiplier)

	widgetDimensions.right = viewScreenWidth
	widgetDimensions.left = viewScreenWidth - widgetDimensions.width

	widgetDimensions.distanceFromTopBar = mathfloor(defaults.widgetDimensions.distanceFromTopBar * scaleMultiplier)
	if WG['topbar'] and WG['topbar'].getShowButtons() then
		local topBarPosition = WG['topbar'].GetPosition()
		widgetDimensions.top = topBarPosition[2] -- widgetDimensions.distanceFromTopBar
	else
		widgetDimensions.top = viewScreenHeight
	end
	widgetDimensions.bottom = widgetDimensions.top - widgetDimensions.height
end

local function calculateMetricDimensions()
	metricDimensions.width = widgetDimensions.width
end

local function calculateTitleDimensions()
	titleDimensions.fontSize = math.floor(defaults.titleDimensions.fontSize * scaleMultiplier)
	titleDimensions.padding = math.floor(defaults.titleDimensions.padding * scaleMultiplier)

	titleDimensions.height = metricDimensions.height
	titleDimensions.width = math.floor(titleDimensions.height * constants.titleDimensions.heightToWidthFactor)

	titleDimensions.left = widgetDimensions.left + widgetDimensions.borderPadding + titleDimensions.padding
	titleDimensions.right = titleDimensions.left + titleDimensions.width

	titleDimensions.horizontalCenter = math.floor((titleDimensions.right + titleDimensions.left) / 2)
	titleDimensions.verticalCenterOffset = math.floor(titleDimensions.height / 2)

	titleDimensions.widthHalf = math.floor(titleDimensions.width / 2)
end

local function calculateKnobDimensions()
	knobDimensions.fontSize = math.floor(defaults.knobDimensions.fontSize * scaleMultiplier)
	knobDimensions.padding = math.floor(defaults.knobDimensions.padding * scaleMultiplier)

	knobDimensions.height = metricDimensions.height - 2 * knobDimensions.padding
	knobDimensions.width = knobDimensions.height * constants.knobDimensions.heightToWidthFactor

	knobDimensions.cornerSize = math.floor(defaults.knobDimensions.cornerSize * scaleMultiplier)
	knobDimensions.outline = math.floor(defaults.knobDimensions.outline * scaleMultiplier)

	knobDimensions.leftKnobLeft = titleDimensions.right + knobDimensions.padding
	knobDimensions.leftKnobRight = knobDimensions.leftKnobLeft + knobDimensions.width

	knobDimensions.rightKnobRight = widgetDimensions.right - widgetDimensions.borderPadding - knobDimensions.padding
	knobDimensions.rightKnobLeft = knobDimensions.rightKnobRight - knobDimensions.width
end

local function calculateBarDimensions()
	barDimensions.padding = math.floor(defaults.barDimensions.padding * scaleMultiplier)
	barDimensions.paddingFromMetric = knobDimensions.padding + barDimensions.padding

	local barHeight = knobDimensions.height - 2 * barDimensions.padding
	local lineHeight = defaults.barDimensions.lineHeight * scaleMultiplier
	barDimensions.lineMiddleOffset = math.floor((barHeight - lineHeight) / 2)

	barDimensions.left = knobDimensions.leftKnobRight + 1
	barDimensions.right = knobDimensions.rightKnobLeft - 1

	barDimensions.width = barDimensions.right - barDimensions.left - knobDimensions.width
end

local function calculateDimensions()
	calculateWidgetDimensions()
	calculateMetricDimensions()
	calculateTitleDimensions()
	calculateKnobDimensions()
	calculateBarDimensions()
end

local function createTextures()
	local textureProperties = {
		target = GL.TEXTURE_2D,
		format = GL.RGBA,
		fbo = true,
	}

	local titleTextureSizeX = titleDimensions.width
	local titleTextureSizeY = widgetDimensions.height
	titleTexture = gl.CreateTexture(titleTextureSizeX, titleTextureSizeY, textureProperties)
	titleTextureDone = false

	local knobTextureSizeX = knobDimensions.rightKnobRight - knobDimensions.leftKnobLeft
	local knobTextureSizeY = widgetDimensions.height
	statsTexture = gl.CreateTexture(knobTextureSizeX, knobTextureSizeY, textureProperties)
end

local function deleteTextures()
	if titleTexture then
		gl.DeleteTexture(titleTexture)
		titleTexture = nil
	end

	if statsTexture then
		gl.DeleteTexture(statsTexture)
		statsTexture = nil
	end
end

local function updateMetricTextTooltips()
	if WG['tooltip'] then
		for metricIndex,metric in ipairs(metricsEnabled) do
			local bottom = widgetDimensions.top - metricIndex * metricDimensions.height
			local top = bottom + metricDimensions.height

			local left = titleDimensions.left
			local right = titleDimensions.right

			WG['tooltip'].AddTooltip(
				string.format("spectator_hud_vsmode_%d", metric.id),
				{ left, bottom, right, top },
				metric.tooltip,
				nil,
				metric.title
			)
		end
	end
end

local function initMovingAverage(movingAverage)
	if not settings.useMovingAverage then
		movingAverage.average = 0
		return
	end

	movingAverage.average = 0
	movingAverage.index = 0
	movingAverage.data = {}
	for i=1,settings.movingAverageWindowSize do
		movingAverage.data[i] = 0
	end
end

local function updateMovingAverage(movingAverage, newValue)
	if not settings.useMovingAverage then
		movingAverage.average = newValue
		return
	end

	if movingAverage.index == 0 then
		for i=1,settings.movingAverageWindowSize do
			movingAverage.data[i] = newValue
		end
		movingAverage.average = newValue
		movingAverage.index = 1
	end

	local newIndex = movingAverage.index + 1
	newIndex = newIndex <= settings.movingAverageWindowSize and newIndex or 1
	movingAverage.index = newIndex

	local oldValue = movingAverage.data[newIndex]
	movingAverage.data[newIndex] = newValue

	movingAverage.average = movingAverage.average + (newValue - oldValue) / settings.movingAverageWindowSize

	if (movingAverage.average * settings.movingAverageWindowSize) < 0.5 then
		movingAverage.average = 0
	end
end

local function getOneStat(statKey, teamID)
	-- TODO: refactor the function to be able to fetch multiple metrics at the same time.
	-- For example, metalProduced and metalExcess are fetched with the same call to
	-- Spring.GetTeamResourceStats(teamID, "m"), so calling this function twice is a waste.

	local result = 0

	if statKey == metricKeys.metalIncome then
		result = select(4, Spring.GetTeamResources(teamID, "metal")) or 0
	elseif statKey == metricKeys.energyConversionMetalIncome then
		for unitID,_ in pairs(unitCache[teamID].energyConverters) do
			result = result + unitCache.energyConverters.update(unitID, 0)
		end
	elseif statKey == metricKeys.energyIncome then
		result = select(4, Spring.GetTeamResources(teamID, "energy")) or 0
	elseif statKey == metricKeys.buildPower then
		result = cachedTotals[teamID].buildPower
	elseif statKey == metricKeys.metalProduced then
		--local metalUsed, metalProduced, metalExcessed, metalReceived, metalSent
		local _, metalProduced, _, _, _ = Spring.GetTeamResourceStats(teamID, "m")
		result = metalProduced
	elseif statKey == metricKeys.energyProduced then
		local _, energyProduced, _, _, _ = Spring.GetTeamResourceStats(teamID, "e")
		result = energyProduced
	elseif statKey == metricKeys.metalExcess then
		local _, _, metalExcess, _, _ = Spring.GetTeamResourceStats(teamID, "m")
		result = metalExcess
	elseif statKey == metricKeys.energyExcess then
		local _, _, energyExcess, _, _ = Spring.GetTeamResourceStats(teamID, "e")
		result = energyExcess
	elseif statKey == metricKeys.armyValue then
		result = cachedTotals[teamID].armyUnits
	elseif statKey == metricKeys.defenseValue then
		result = cachedTotals[teamID].defenseUnits
	elseif statKey == metricKeys.utilityValue then
		result = cachedTotals[teamID].utilityUnits
	elseif statKey == metricKeys.economyValue then
		result = cachedTotals[teamID].economyBuildings
	elseif statKey == metricKeys.damageDealt then
		local historyMax = Spring.GetTeamStatsHistory(teamID)
		local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
		local damageDealt = 0
		if statsHistory and #statsHistory > 0 then
			damageDealt = statsHistory[1].damageDealt
		end
		result = damageDealt
	elseif statKey == metricKeys.damageReceived then
		local historyMax = Spring.GetTeamStatsHistory(teamID)
		local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
		local damageReceived = 0
		if statsHistory and #statsHistory > 0 then
			damageReceived = statsHistory[1].damageReceived
		end
		result = damageReceived
	elseif statKey == metricKeys.damageEfficiency then
		local historyMax = Spring.GetTeamStatsHistory(teamID)
		local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
		local damageDealt = 0
		local damageReceived = 0
		if statsHistory and #statsHistory > 0 then
			damageDealt = statsHistory[1].damageDealt
			damageReceived = statsHistory[1].damageReceived
		end
		if damageReceived < 1 then
			-- avoid dividing by 0
			damageReceived = 1
		end
		result = mathfloor(damageDealt * 100 / damageReceived)
	end

	return round(result)
end

local function createTeamStats()
	-- Note: The game uses it's own ID's for AllyTeams and Teams (commonly, allyTeamID and teamID). To optimize lookup,
	-- we use our own indexing instead.

	-- Note2: Our rendering code assumes there's exactly two AllyTeams (in addition to GaiaTeam). However, while we
	-- could hard-code the amount of AllyTeams in statistics code, there's no benefit in doing so. Therefore, the stats
	-- code covers the general case, too.

	-- Data structure layout is as follows:
	-- teamStats:
	--	- metric
	--		- aggregates
	--			- allyTeam 1
	--			- allyTeam 2
	--		- allyTeams
	--			- allyTeam 1
	--				- team 1
	--				- team 2
	--				- ...
	--			- allyTeam 2
	--				- team 1
	--				- team 2
	--				- ...

	teamStats = {}

	for metricIndex,_ in ipairs(metricsEnabled) do
		teamStats[metricIndex] = {}
		teamStats[metricIndex].aggregates = {}
		teamStats[metricIndex].allyTeams = {}
		for allyIndex,allyTeam in ipairs(allyTeamTable) do
			teamStats[metricIndex].aggregates[allyIndex] = 0
			teamStats[metricIndex].allyTeams[allyIndex] = {}
			for teamIndex,teamID in ipairs(allyTeam.teams) do
				teamStats[metricIndex].allyTeams[allyIndex][teamIndex] = {}
				initMovingAverage(teamStats[metricIndex].allyTeams[allyIndex][teamIndex])
			end
		end
	end
end

local function updateStats()
	for metricIndex,metric in ipairs(metricsEnabled) do
		for allyIndex,allyTeam in ipairs(allyTeamTable) do
			local teamAggregate = 0
			for teamIndex,teamID in ipairs(allyTeam.teams) do
				local valueTeam = getOneStat(metric.key, teamID)
				updateMovingAverage(teamStats[metricIndex].allyTeams[allyIndex][teamIndex], valueTeam)
				teamAggregate = teamAggregate + teamStats[metricIndex].allyTeams[allyIndex][teamIndex].average
			end

			teamStats[metricIndex].aggregates[allyIndex] = teamAggregate
		end
	end

	regenerateTextTextures = true
end

local colorKnobMiddleGrey = { 0.5, 0.5, 0.5, 1 }
local function drawMetricBar(left, bottom, right, top, indexLeft, indexRight, metricIndex, mouseOver)
	local valueLeft = teamStats[metricIndex].aggregates[indexLeft]
	local valueRight = teamStats[metricIndex].aggregates[indexRight]

	local barTop = top - barDimensions.paddingFromMetric
	local barBottom = bottom + barDimensions.paddingFromMetric

	local barLength = barDimensions.width

	local leftBarWidth
	if valueLeft > 0 or valueRight > 0 then
		leftBarWidth = mathfloor(barLength * valueLeft / (valueLeft + valueRight))
	else
		leftBarWidth = mathfloor(barLength / 2)
	end
	local rightBarWidth = barLength - leftBarWidth

	if (not mouseOver) or ((valueLeft == 0) and (valueRight == 0)) then
		glColor(allyTeamTable[indexLeft].colorBar)
		glRect(
			left,
			barBottom,
			left + leftBarWidth,
			barTop
		)

		glColor(allyTeamTable[indexRight].colorBar)
		glRect(
			right - rightBarWidth,
			barBottom,
			right,
			barTop
		)

		local lineBottom = barBottom + barDimensions.lineMiddleOffset
		local lineTop = barTop - barDimensions.lineMiddleOffset

		glColor(allyTeamTable[indexLeft].colorLine)
		glRect(
			left,
			lineBottom,
			left + leftBarWidth,
			lineTop
		)

		glColor(allyTeamTable[indexRight].colorLine)
		glRect(
			right - rightBarWidth,
			lineBottom,
			right,
			lineTop
		)
	else
		-- do "rainbow" colors
		local scalingFactor = barLength / (valueLeft + valueRight)

		local lineStart
		local lineEnd = left
		for teamIndex,teamID in ipairs(allyTeamTable[indexLeft].teams) do
			local teamValue = teamStats[metricIndex].allyTeams[indexLeft][teamIndex].average
			local teamColor = playerData[teamID].color

			lineStart = lineEnd
			lineEnd = lineStart + mathfloor(scalingFactor * teamValue)

			glColor(teamColor)
			glRect(
				lineStart,
				barBottom,
				lineEnd,
				barTop
			)
		end

		local lineStart
		local lineEnd = right - rightBarWidth
		for teamIndex,teamID in ipairs(allyTeamTable[indexRight].teams) do
			local teamValue = teamStats[metricIndex].allyTeams[indexRight][teamIndex].average
			local teamColor = playerData[teamID].color

			lineStart = lineEnd
			lineEnd = lineStart + mathfloor(scalingFactor * teamValue)

			glColor(teamColor)
			glRect(
				lineStart,
				barBottom,
				lineEnd,
				barTop
			)
		end
	end
end

local function drawBars()
	local indexLeft = teamOrder and teamOrder[1] or 1
	local indexRight = teamOrder and teamOrder[2] or 2

	local mouseX, mouseY = Spring.GetMouseState()
	local mouseOnBar= false
	if (mouseX > barDimensions.left) and (mouseX < barDimensions.right) and
		(mouseY > widgetDimensions.bottom) and (mouseY < widgetDimensions.top) then
		mouseOnBar = true
	end

	for metricIndex,metric in ipairs(metricsEnabled) do
		local bottom = widgetDimensions.top - metricIndex * metricDimensions.height
		local top = bottom + metricDimensions.height

		local mouseOver = false
		if mouseOnBar then
			if (mouseY > bottom) and (mouseY < top) then
				mouseOver = true
			end
		end

		drawMetricBar(
			knobDimensions.leftKnobRight,
			bottom,
			knobDimensions.rightKnobLeft,
			top,
			indexLeft,
			indexRight,
			metricIndex,
			mouseOver
		)
	end
end

local function drawText()
	local indexLeft = teamOrder and teamOrder[1] or 1
	local indexRight = teamOrder and teamOrder[2] or 2

	gl.R2tHelper.BlendTexRect(titleTexture, titleDimensions.left, widgetDimensions.bottom, titleDimensions.right, widgetDimensions.top, true)
	gl.R2tHelper.BlendTexRect(statsTexture, knobDimensions.leftKnobLeft, widgetDimensions.bottom, knobDimensions.rightKnobRight, widgetDimensions.top, true)
end

local function doTitleTexture()
	local function drawTitlesToTexture()
		gl.Translate(-1, -1, 0)
		gl.Scale(
			2 / titleDimensions.width,
			2 / widgetDimensions.height,
			0
		)
		font:Begin(true)
		font:SetTextColor(textColorWhite)

		for metricIndex,metric in ipairs(metricsEnabled) do
			local bottom = widgetDimensions.height - metricIndex * metricDimensions.height

			local textHCenter = titleDimensions.widthHalf
			local textVCenter = bottom + titleDimensions.verticalCenterOffset
			local textText = metricsEnabled[metricIndex].text

			font:Print(
				textText,
				textHCenter,
				textVCenter,
				titleDimensions.fontSize,
				'cvo'
			)
		end
		font:End()
	end

	gl.R2tHelper.RenderToTexture(titleTexture, drawTitlesToTexture,	true)
end

local function updateStatsTexture()
	local function drawStatsToTexture()
		local function drawMetricKnobText(left, bottom, right, top, text)
			local knobTextAreaWidth = right - left - 2 * knobDimensions.outline
			local fontSizeSmaller = knobDimensions.fontSize
			local textWidth = font:GetTextWidth(text)
			while textWidth * fontSizeSmaller > knobTextAreaWidth do
				fontSizeSmaller = fontSizeSmaller - 1
			end

			font:Print(
				text,
				mathfloor((right + left) / 2),
				mathfloor((top + bottom) / 2),
				fontSizeSmaller,
				'cvO'
			)
		end

		local statsTextureWidth = knobDimensions.rightKnobRight - knobDimensions.leftKnobLeft
		local statsTextureHeight = widgetDimensions.height

		gl.Translate(-1, -1, 0)
		gl.Scale(
			2 / statsTextureWidth,
			2 / statsTextureHeight,
			0
		)
		font:Begin(true)
			font:SetTextColor(textColorWhite)

			local indexLeft = teamOrder and teamOrder[1] or 1
			local indexRight = teamOrder and teamOrder[2] or 2
			for metricIndex,metric in ipairs(metricsEnabled) do
				local bottom = widgetDimensions.height - metricIndex * metricDimensions.height
				local top = bottom + metricDimensions.height

				local valueLeft = teamStats[metricIndex].aggregates[indexLeft]
				local valueRight = teamStats[metricIndex].aggregates[indexRight]

				-- draw left knob text
				drawMetricKnobText(
					0,
					bottom,
					knobDimensions.width,
					top,
					formatResources(valueLeft, true)
				)

				-- draw right knob text
				drawMetricKnobText(
					knobDimensions.rightKnobLeft - knobDimensions.leftKnobLeft,
					bottom,
					knobDimensions.rightKnobRight - knobDimensions.leftKnobLeft,
					top,
					formatResources(valueRight, true)
				)

				-- draw middle knob text
				local barLength = knobDimensions.rightKnobLeft - knobDimensions.leftKnobRight - knobDimensions.width
				local leftBarWidth
				if valueLeft > 0 or valueRight > 0 then
					leftBarWidth = mathfloor(barLength * valueLeft / (valueLeft + valueRight))
				else
					leftBarWidth = mathfloor(barLength / 2)
				end
				local rightBarWidth = barLength - leftBarWidth -- TODO: remove unused variable

				local relativeLead = 0
				local relativeLeadMax = 999
				local relativeLeadString = nil
				if valueLeft > valueRight then
					if valueRight > 0 then
						relativeLead = mathfloor(100 * mathabs(valueLeft - valueRight) / valueRight)
					else
						relativeLeadString = "∞"
					end
				elseif valueRight > valueLeft then
					if valueLeft > 0 then
						relativeLead = mathfloor(100 * mathabs(valueRight - valueLeft) / valueLeft)
					else
						relativeLeadString = "∞"
					end
				end
				if relativeLead > relativeLeadMax then
					relativeLeadString = string.format("%d+%%", relativeLeadMax)
				elseif not relativeLeadString then
					relativeLeadString = string.format("%d%%", relativeLead)
				end

				local middleKnobLeft = knobDimensions.width + leftBarWidth + 1
				drawMetricKnobText(
					middleKnobLeft,
					bottom,
					middleKnobLeft + knobDimensions.width,
					top,
					relativeLeadString
				)
			end
		font:End()
	end

	gl.R2tHelper.RenderToTexture(statsTexture, drawStatsToTexture, true)
end

local function updateTextTextures()
	if not titleTextureDone then
		doTitleTexture()
		titleTextureDone = true
	end

	updateStatsTexture()
end

local function createMetricDisplayLists()
	metricDisplayLists = {}

	local left = widgetDimensions.left
	local right = widgetDimensions.right
	for metricIndex,_ in ipairs(metricsEnabled) do
		local bottom = widgetDimensions.top - metricIndex * metricDimensions.height
		local top = bottom + metricDimensions.height

		local newDisplayList = gl.CreateList(function ()
			WG.FlowUI.Draw.Element(
				left,
				bottom,
				right,
				top,
				metricIndex == 1 and 0 or 1, 1, 1, 1,
				metricIndex == 1 and 0 or 1, 1, 1, 1
			)
		end)
		table.insert(metricDisplayLists, newDisplayList)
	end
end

local function deleteMetricDisplayLists()
	for _,metricDisplayList in ipairs(metricDisplayLists) do
		gl.DeleteList(metricDisplayList)
	end
end

local function createKnobVertices(vertexMatrix, left, bottom, right, top, cornerRadius, cornerTriangleAmount)
	local function addCornerVertices(vertexMatrix, startIndex, startAngle, originX, originY, cornerRadiusX, cornerRadiusY)
		-- first, add the corner vertex
		vertexMatrix[startIndex] = originX --rectRight
		vertexMatrix[startIndex+1] = originY -- rectBottom
		vertexMatrix[startIndex+2] = 0
		vertexMatrix[startIndex+3] = 1

		local alpha = math.pi / 2 / cornerTriangleAmount
		for sliceIndex=0,cornerTriangleAmount do
			local x = originX + cornerRadiusX * (math.cos(startAngle + alpha * sliceIndex))
			local y = originY + cornerRadiusY * (math.sin(startAngle + alpha * sliceIndex))

			local vertexIndex = startIndex + (sliceIndex+1)*4

			vertexMatrix[vertexIndex] = x
			vertexMatrix[vertexIndex+1] = y
			vertexMatrix[vertexIndex+2] = 0
			vertexMatrix[vertexIndex+3] = 1
		end
	end

	local function addRectangleVertices(vertexMatrix, startIndex, rectLeft, rectBottom, rectRight, rectTop)
		vertexMatrix[startIndex] = rectLeft
		vertexMatrix[startIndex+1] = rectTop
		vertexMatrix[startIndex+2] = 0
		vertexMatrix[startIndex+3] = 1

		vertexMatrix[startIndex+4] = rectRight
		vertexMatrix[startIndex+5] = rectTop
		vertexMatrix[startIndex+6] = 0
		vertexMatrix[startIndex+7] = 1

		vertexMatrix[startIndex+8] = rectLeft
		vertexMatrix[startIndex+9] = rectBottom
		vertexMatrix[startIndex+10] = 0
		vertexMatrix[startIndex+11] = 1

		vertexMatrix[startIndex+12] = rectRight
		vertexMatrix[startIndex+13] = rectBottom
		vertexMatrix[startIndex+14] = 0
		vertexMatrix[startIndex+15] = 1
	end

	local vertexIndex = 1

	local cornerRadiusX = coordinateScreenXToOpenGL(cornerRadius) + 1.0
	local cornerRadiusY = coordinateScreenYToOpenGL(cornerRadius) + 1.0

	local leftOpenGL = coordinateScreenXToOpenGL(left)
	local bottomOpenGL = coordinateScreenYToOpenGL(bottom)
	local rightOpenGL = coordinateScreenXToOpenGL(right)
	local topOpenGL = coordinateScreenYToOpenGL(top)

	-- 1. create top-left corner triangles
	addCornerVertices(
		vertexMatrix,
		vertexIndex,
		math.pi/2,
		leftOpenGL + cornerRadiusX,
		topOpenGL - cornerRadiusY,
		cornerRadiusX,
		cornerRadiusY
	)
	vertexIndex = vertexIndex + 4 + (cornerTriangleAmount+1)*4

	-- 2. create top-mid rectangle triangles
	addRectangleVertices(
		vertexMatrix,
		vertexIndex,
		leftOpenGL + cornerRadiusX,
		topOpenGL - cornerRadiusY,
		rightOpenGL - cornerRadiusX,
		topOpenGL
	)
	vertexIndex = vertexIndex + 16

	-- 3. create top-right corner triangles
	addCornerVertices(
		vertexMatrix,
		vertexIndex,
		0,
		rightOpenGL - cornerRadiusX,
		topOpenGL - cornerRadiusY,
		cornerRadiusX,
		cornerRadiusY
	)
	vertexIndex = vertexIndex + 4 + (cornerTriangleAmount+1)*4

	-- 4. create mid-left rectangle triangles
	addRectangleVertices(
		vertexMatrix,
		vertexIndex,
		leftOpenGL,
		bottomOpenGL + cornerRadiusY,
		leftOpenGL + cornerRadiusX,
		topOpenGL - cornerRadiusY
	)
	vertexIndex = vertexIndex + 16

	-- 5. create mid-mid rectangle triangles
	addRectangleVertices(
		vertexMatrix,
		vertexIndex,
		leftOpenGL + cornerRadiusX,
		bottomOpenGL + cornerRadiusY,
		rightOpenGL - cornerRadiusX,
		topOpenGL - cornerRadiusY
	)
	vertexIndex = vertexIndex + 16

	-- 6. create mid-right rectangle triangles
	addRectangleVertices(
		vertexMatrix,
		vertexIndex,
		rightOpenGL - cornerRadiusX,
		bottomOpenGL + cornerRadiusY,
		rightOpenGL,
		topOpenGL - cornerRadiusY
	)
	vertexIndex = vertexIndex + 16

	-- 7. create bottom-left corner triangles
	addCornerVertices(
		vertexMatrix,
		vertexIndex,
		math.pi,
		leftOpenGL + cornerRadiusX,
		bottomOpenGL + cornerRadiusY,
		cornerRadiusX,
		cornerRadiusY
	)
	vertexIndex = vertexIndex + 4 + (cornerTriangleAmount+1)*4

	-- 8. create bottom-mid rectangle triangles
	addRectangleVertices(
		vertexMatrix,
		vertexIndex,
		leftOpenGL + cornerRadiusX,
		bottomOpenGL + cornerRadiusY,
		rightOpenGL - cornerRadiusX,
		bottomOpenGL
	)
	vertexIndex = vertexIndex + 16

	-- 9. create bottom-left corner triangles
	addCornerVertices(
		vertexMatrix,
		vertexIndex,
		-math.pi/2,
		rightOpenGL - cornerRadiusX,
		bottomOpenGL + cornerRadiusY,
		cornerRadiusX,
		cornerRadiusY
	)
	vertexIndex = vertexIndex + 4 + (cornerTriangleAmount+1)*4

	return vertexIndex
end

local function insertKnobIndices(indexData, vertexStartIndex, cornerTriangleAmount)
	local function insertCornerIndices(currentVertexOffset)
		for i=1,cornerTriangleAmount do
			table.insert(indexData, currentVertexOffset + 0)
			table.insert(indexData, currentVertexOffset + i)
			table.insert(indexData, currentVertexOffset + i+1)
		end
		return currentVertexOffset + cornerTriangleAmount + 2
	end

	local function insertRectangleIndices(currentVertexOffset)
		table.insert(indexData, currentVertexOffset)
		table.insert(indexData, currentVertexOffset+1)
		table.insert(indexData, currentVertexOffset+2)
		table.insert(indexData, currentVertexOffset+1)
		table.insert(indexData, currentVertexOffset+2)
		table.insert(indexData, currentVertexOffset+3)
		return currentVertexOffset + 4
	end

	local vertexOffset = vertexStartIndex

	-- 1
	vertexOffset = insertCornerIndices(vertexOffset)

	-- 2
	vertexOffset = insertRectangleIndices(vertexOffset)

	-- 3
	vertexOffset = insertCornerIndices(vertexOffset)

	-- 4
	vertexOffset = insertRectangleIndices(vertexOffset)

	-- 5
	vertexOffset = insertRectangleIndices(vertexOffset)

	-- 6
	vertexOffset = insertRectangleIndices(vertexOffset)

	-- 7
	vertexOffset = insertCornerIndices(vertexOffset)

	-- 8
	vertexOffset = insertRectangleIndices(vertexOffset)

	-- 9
	vertexOffset = insertCornerIndices(vertexOffset)

	return vertexOffset
end

local function createKnobVAO()
	local instanceCount = #metricsEnabled * 3
	local cornerTriangleAmount = 6
	local width = knobDimensions.width
	local height = knobDimensions.height
	local cornerRadius = knobDimensions.cornerSize
	local border = knobDimensions.outline

	if knobVAO then
		knobVAO.vaoInner:Delete()
		knobVAO.vaoOutline:Delete()
	end
	knobVAO = {}
	knobVAO.vaoInner = gl.GetVAO()
	knobVAO.vaoOutline = gl.GetVAO()

	knobVAO.cornerTriangleAmount = cornerTriangleAmount

	-- build vertexVBO
	local vertexDataOutline = {}
	createKnobVertices(
		vertexDataOutline,
		0,
		0,
		width,
		height,
		cornerRadius,
		cornerTriangleAmount
	)
	local vertexDataInner = {}
	createKnobVertices(
		vertexDataInner,
		border,
		border,
		width - border,
		height - border,
		cornerRadius,
		cornerTriangleAmount
	)

	local vertexVBOInner = gl.GetVBO(GL.ARRAY_BUFFER, false)
	vertexVBOInner:Define(#vertexDataInner/4, {
		{ id = 0, name = "aPos", size = 4 },
	})
	vertexVBOInner:Upload(vertexDataInner)

	local vertexVBOOutline = gl.GetVBO(GL.ARRAY_BUFFER, false)
	vertexVBOOutline:Define(#vertexDataOutline/4, {
		{ id = 0, name = "aPos", size = 4 },
	})
	vertexVBOOutline:Upload(vertexDataOutline)

	-- build indexVBO
	local indexVBOInner = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local indexVBOOutline = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local indexData = {}
	local vertexOffset = 0
	vertexOffset = insertKnobIndices(indexData, vertexOffset, cornerTriangleAmount)
	indexVBOInner:Define(#indexData, GL.UNSIGNED_INT)
	indexVBOInner:Upload(indexData)
	indexVBOOutline:Define(#indexData, GL.UNSIGNED_INT)
	indexVBOOutline:Upload(indexData)

	-- create and attach instanceVBO (note: the data is populated separately)
	knobVAO.instanceVBOInner = gl.GetVBO(GL.ARRAY_BUFFER, true)
	knobVAO.instanceVBOInner:Define(instanceCount, {
		{ id = 1, name = "posBias", size=4 },
		{ id = 2, name = "aKnobColor", size=4 },
	})

	knobVAO.instanceVBOOutline = gl.GetVBO(GL.ARRAY_BUFFER, true)
	knobVAO.instanceVBOOutline:Define(instanceCount, {
		{ id = 1, name = "posBias", size=4 },
		{ id = 2, name = "aKnobColor", size=4 },
	})

	knobVAO.instances = 0

	knobVAO.vaoInner:AttachVertexBuffer(vertexVBOInner)
	knobVAO.vaoInner:AttachInstanceBuffer(knobVAO.instanceVBOInner)
	knobVAO.vaoInner:AttachIndexBuffer(indexVBOInner)

	knobVAO.vaoOutline:AttachVertexBuffer(vertexVBOOutline)
	knobVAO.vaoOutline:AttachInstanceBuffer(knobVAO.instanceVBOOutline)
	knobVAO.vaoOutline:AttachIndexBuffer(indexVBOOutline)

	return knobVAO
end

local function addKnob(knobVAO, left, bottom, color)
	local instanceData = {}

	-- posBias
	table.insert(instanceData, coordinateScreenXToOpenGL(left)+1.0)
	table.insert(instanceData, coordinateScreenYToOpenGL(bottom)+1.0)
	table.insert(instanceData, 0.0)
	table.insert(instanceData, 0.0)

	-- aKnobColor
	instanceData[5] = color[1]
	instanceData[6] = color[2]
	instanceData[7] = color[3]
	instanceData[8] = color[4]
	knobVAO.instanceVBOInner:Upload(instanceData, -1, knobVAO.instances)

	local greyFactor = 0.5
	instanceData[5] = color[1] * greyFactor
	instanceData[6] = color[2] * greyFactor
	instanceData[7] = color[3] * greyFactor
	instanceData[8] = color[4] * greyFactor
	knobVAO.instanceVBOOutline:Upload(instanceData, -1, knobVAO.instances)

	knobVAO.instances = knobVAO.instances + 1

	return knobVAO.instances
end

local function addSideKnobs()
	local indexLeft = teamOrder and teamOrder[1] or 1
	local indexRight = teamOrder and teamOrder[2] or 2

	for metricIndex,_ in ipairs(metricsEnabled) do
		local bottom = widgetDimensions.top - metricIndex * metricDimensions.height
		local knobBottom = bottom + knobDimensions.padding

		local leftKnobColor = allyTeamTable[indexLeft].colorKnobSide
		local rightKnobColor = allyTeamTable[indexRight].colorKnobSide

		addKnob(knobVAO, knobDimensions.leftKnobLeft, knobBottom, leftKnobColor)
		addKnob(knobVAO, knobDimensions.rightKnobLeft, knobBottom, rightKnobColor)
	end
end

local function addMiddleKnobs()
	for metricIndex,_ in ipairs(metricsEnabled) do
		local bottom = widgetDimensions.top - metricIndex * metricDimensions.height + 1.0
		local textBottom = bottom + titleDimensions.padding

		local middleKnobLeft = (knobDimensions.rightKnobLeft + knobDimensions.leftKnobRight) / 2 - knobDimensions.width / 2
		local middleKnobBottom = textBottom

		local middleKnobColor = colorKnobMiddleGrey

		addKnob(knobVAO, middleKnobLeft, middleKnobBottom, middleKnobColor)
	end
end

local modifyKnobInstanceData = {0, 0, 0, 0, 0, 0, 0, 0}
local function modifyKnob(knobVAO, instance, left, bottom, color)
	-- note: instead of using a local variable instanceData that rebuild a table every time this function is called,
	-- we use the global variable modifyKnobInstanceData to avoid recreating a table and instead reusing the table.
	--local instanceData = {}

	-- posBias
	modifyKnobInstanceData[1] = coordinateScreenXToOpenGL(left) + 1.0
	modifyKnobInstanceData[2] = coordinateScreenYToOpenGL(bottom) + 1.0
	modifyKnobInstanceData[3] = 0.0
	modifyKnobInstanceData[4] = 0.0

	-- aKnobColor
	modifyKnobInstanceData[5] = color[1]
	modifyKnobInstanceData[6] = color[2]
	modifyKnobInstanceData[7] = color[3]
	modifyKnobInstanceData[8] = color[4]
	knobVAO.instanceVBOInner:Upload(modifyKnobInstanceData, -1, instance-1)

	local greyFactor = 0.5
	modifyKnobInstanceData[5] = color[1] * greyFactor
	modifyKnobInstanceData[6] = color[2] * greyFactor
	modifyKnobInstanceData[7] = color[3] * greyFactor
	modifyKnobInstanceData[8] = color[4] * greyFactor
	knobVAO.instanceVBOOutline:Upload(modifyKnobInstanceData, -1, instance-1)
end

local function moveMiddleKnobs()
	local indexLeft = teamOrder and teamOrder[1] or 1
	local indexRight = teamOrder and teamOrder[2] or 2

	local instanceOffset = 2 * #metricsEnabled
	for metricIndex,_ in ipairs(metricsEnabled) do
		local bottom = widgetDimensions.top - metricIndex * metricDimensions.height

		local valueLeft = teamStats[metricIndex].aggregates[indexLeft]
		local valueRight = teamStats[metricIndex].aggregates[indexRight]

		local knobBottom = bottom + knobDimensions.padding

		local barLength = barDimensions.width

		local leftBarWidth
		if valueLeft > 0 or valueRight > 0 then
			leftBarWidth = mathfloor(barLength * valueLeft / (valueLeft + valueRight))
		else
			leftBarWidth = mathfloor(barLength / 2)
		end

		local middleKnobLeft = knobDimensions.leftKnobRight + leftBarWidth + 1

		local middleKnobColor
		if valueLeft > valueRight then
			middleKnobColor = allyTeamTable[indexLeft].colorKnobMiddle
		elseif valueRight > valueLeft then
			middleKnobColor = allyTeamTable[indexRight].colorKnobMiddle
		else
			-- color grey if even
			middleKnobColor = colorKnobMiddleGrey
		end

		local instanceID = instanceOffset + metricIndex

		modifyKnob(knobVAO, instanceID, middleKnobLeft, knobBottom, middleKnobColor)
	end
end

local function deleteKnobVAO()
	if knobVAO then
		knobVAO.vaoInner:Delete()
		knobVAO.vaoOutline:Delete()
		knobVAO = nil
	end
end

local function drawKnobVAO()
	shader:Activate()

	local amountOfTriangles = 5*2 + 4*knobVAO.cornerTriangleAmount
	knobVAO.vaoOutline:DrawElements(GL.TRIANGLES, amountOfTriangles*3, 0, knobVAO.instances)
	knobVAO.vaoInner:DrawElements(GL.TRIANGLES, amountOfTriangles*3, 0, knobVAO.instances)

	shader:Deactivate()
end

local function initGL4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	knobVertexShaderSource = knobVertexShaderSource:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	knobFragmentShaderSource = knobFragmentShaderSource:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	shader = LuaShader(
		{
			vertex = knobVertexShaderSource,
			fragment = knobFragmentShaderSource,
		},
		"spectator_hud"
	)
	local shaderCompiled = shader:Initialize()
	return shaderCompiled
end

local function hideEcostats()
	if widgetEnabled and widgetHandler:IsWidgetKnown("Ecostats") then
		local ecostatsWidget = widgetHandler:FindWidget("Ecostats")
		if (not ecostatsWidget) then return end
		ecostatsHidden = true
		widgetHandler:RemoveWidget(ecostatsWidget)
	end
end

local function showEcostats()
	if ecostatsHidden then
		widgetHandler:EnableWidget("Ecostats")
		ecostatsHidden = false
	end
end

local function init()
	font = WG['fonts'].getFont()

	viewScreenWidth, viewScreenHeight = Spring.GetViewGeometry()

	buildMetricsEnabled()

	if settings.widgetConfig == constants.configLevel.basic then
		settings.statsUpdateFrequency = 30	-- once a second
		settings.useMovingAverage = false
	elseif settings.widgetConfig == constants.configLevel.advanced then
		settings.statsUpdateFrequency = 6  -- 5 times a second
		settings.useMovingAverage = true
		settings.movingAverageWindowSize = 4  -- approx 1 sec
	elseif settings.widgetConfig == constants.configLevel.expert then
		settings.statsUpdateFrequency = 2  -- 15 times a second, same as engine slowUpdate
		settings.useMovingAverage = true
		settings.movingAverageWindowSize = 16  -- approx 1 sec
	elseif settings.widgetConfig == constants.configLevel.custom then
		settings.statsUpdateFrequency = 2
		settings.useMovingAverage = true
		settings.movingAverageWindowSize = 16
	end

	calculateDimensions()
	createTextures()

	buildPlayerData()
	buildAllyTeamTable()

	if #metricsEnabled > 0 then
		createKnobVAO()
		addSideKnobs()
		addMiddleKnobs()
	end

	createMetricDisplayLists()

	buildUnitDefs()
	buildUnitCache()

	updateMetricTextTooltips()

	createTeamStats()

	if haveFullView then
		updateStats()
		moveMiddleKnobs()
		updateNow = true
	end
end

local function deInit()
	deleteMetricDisplayLists()
	deleteKnobVAO()
	deleteTextures()
end

local function reInit()
	deInit()
	init()
end

function widget:Initialize()
	-- One time enabling of ecostats since old spectator hud versions would disable ecostats
	-- and we don't want people not being able to enable it again easily.
	if not settings.oneTimeEcostatsEnableDone and widgetHandler:IsWidgetKnown("Ecostats") then
		widgetHandler:EnableWidget("Ecostats")
	end
	-- Note: Widget is logically enabled only if there are exactly two teams
	-- If yes, we will hide ecostats (hide at init() and show at deInit())
	-- If no, we will do nothing since user might or might not be using ecostats
	widgetEnabled = getAmountOfAllyTeams() == 2
	if not widgetEnabled then return end

	WG["spectator_hud"] = {}

	WG["spectator_hud"].getWidgetSize = function()
		return settings.widgetScale
	end
	WG["spectator_hud"].setWidgetSize = function(value)
		settings.widgetScale = value
		reInit()
	end

	WG["spectator_hud"].getConfig = function()
		return settings.widgetConfig
	end
	WG["spectator_hud"].setConfig = function(value)
		settings.widgetConfig = value
		reInit()
	end

	WG["spectator_hud"].getMetricEnabled = function(metric)
		return settings.metricsEnabled[metric]
	end
	WG["spectator_hud"].setMetricEnabled = function(args)
		settings.metricsEnabled[args[1]] = args[2]
		reInit()
	end

	if not gl.CreateShader then
		-- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	if not initGL4() then
		widgetHandler:RemoveWidget()
		return
	end

	checkAndUpdateHaveFullView()

	hideEcostats()
	init()
end

function widget:Shutdown()
	deInit()
	WG["spectator_hud"] = {}
	showEcostats()

	if shader then
		shader:Finalize()
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not haveFullView then
		return
	end

	if unitCache[unitTeam] then
		addToUnitCache(unitTeam, unitID, unitDefID)
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not haveFullView then
		return
	end

	-- only track units that have been completely built
	if Spring.GetUnitIsBeingBuilt(unitID) then
		return
	end

	if unitCache[oldTeam] then
		removeFromUnitCache(oldTeam, unitID, unitDefID)
	end

	if unitCache[newTeam] then
		addToUnitCache(newTeam, unitID, unitDefID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if not haveFullView then
		return
	end

	-- unit might've been a nanoframe
	if Spring.GetUnitIsBeingBuilt(unitID) then
		return
	end

	if unitCache[unitTeam] then
		removeFromUnitCache(unitTeam, unitID, unitDefID)
	end
end


function widget:ViewResize()
	reInit()
end

function widget:GameFrame(frameNum)
	if not widgetEnabled then
		return
	end

	if checkAndUpdateHaveFullView() then
		if haveFullView then
			init()
		else
			deInit()
		end
	end

	if not haveFullView then
		return
	end

	if (frameNum > 0) and (not teamOrder) then
		-- collect player start positions
		local teamStartAverages = {}
		for _, allyID in ipairs(Spring.GetAllyTeamList()) do
			if allyID ~= gaiaAllyID then
				local accumulator = { x = 0, z = 0 }
				local teamList = Spring.GetTeamList(allyID)
				for _,teamID in ipairs(teamList) do
					local x, _, z = Spring.GetTeamStartPosition(teamID)
					accumulator.x = accumulator.x + x
					accumulator.z = accumulator.z + z
				end
				local startAverage= { x = accumulator.x / #teamList, z = accumulator.z / #teamList }
				table.insert(teamStartAverages, { allyID, startAverage })
			end
		end

		local _,rotY,_ = Spring.GetCameraRotation()

		-- sort averages and create team order (from left to right)
		table.sort(teamStartAverages, function (left, right)
			return ((left[2].x * math.cos(rotY) + left[2].z * math.sin(rotY)) <
					(right[2].x * math.cos(rotY) + right[2].z * math.sin(rotY)))
		end)
		teamOrder = {}
		for i,teamStart in ipairs(teamStartAverages) do
			teamOrder[i] = teamStart[1] + 1    -- note: allyTeam ID's start from 0
		end

		-- update knob colors by overwriting all knobs
		if knobVAO.instances > 0 then
			knobVAO.instances = 0
		end
		addSideKnobs()
		addMiddleKnobs()
	end

	if frameNum % settings.statsUpdateFrequency == 1 or updateNow then
		updateStats()

		moveMiddleKnobs()
		updateNow = false
	end
end

local sec = 0
local topbarShowButtons = true
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.05 then
		sec = 0
		if WG['topbar'] then
			local prevShowButtons = topbarShowButtons
			if WG['topbar'].getShowButtons() ~= prevShowButtons then
				topbarShowButtons = WG['topbar'].getShowButtons()
				if haveFullView then
					init()
				else
					deInit()
				end
			end
		end
	end
	if checkAndUpdateHaveFullView() then
		if haveFullView then
			init()
		else
			deInit()
		end
	end
end

function widget:DrawGenesis()
	if (not widgetEnabled) or (not haveFullView) then
		return
	end

	if regenerateTextTextures then
		updateTextTextures()
		regenerateTextTextures = false
	end
end

function widget:DrawScreen()
	if (not widgetEnabled) or (not haveFullView) then
		return
	end

	for _, metricDisplayList in ipairs(metricDisplayLists) do
		gl.CallList(metricDisplayList)
	end

	if knobVAO then
		drawKnobVAO()
	end
	drawBars()
	drawText()
end

function widget:GetConfigData()
	local result = {
		widgetScale = settings.widgetScale,
		widgetConfig = settings.widgetConfig,
		oneTimeEcostatsEnableDone = true,
	}

	result.metricsEnabled = {}
	for _,metric in pairs(metricKeys) do
		result.metricsEnabled[metric] = settings.metricsEnabled[metric]
	end

	return result
end

function widget:SetConfigData(data)
	if data.widgetScale then
		settings.widgetScale = data.widgetScale
	end
	if data.widgetConfig then
		settings.widgetConfig = data.widgetConfig
	end
	if data.oneTimeEcostatsEnableDone then
		settings.oneTimeEcostatsEnableDone = data.oneTimeEcostatsEnableDone
	end

	if data["metricsEnabled"] then
		for _,metric in pairs(metricKeys) do
			if data["metricsEnabled"][metric] then
				settings.metricsEnabled[metric] = data["metricsEnabled"][metric]
			end
		end
	end
end
