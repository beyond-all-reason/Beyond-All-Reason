function widget:GetInfo()
    return {
        name = "Spectator HUD",
        desc = "Display Game Metrics",
        author = "CMDR*Zod",
        date = "2024",
        license = "GNU GPL v3 (or later)",
        layer = 1,
        handler = true,
        enabled = true
    }
end

--[[
Spectator HUD is a widget that displays various game metrics and is running only
spectator mode.

At start, Spectator HUD is running in "versus mode". In versus mode, or vsmode,
statistics of both teams are compared against each other.

Altnernatively, the user can switch from vsmode to "normal mode". In normal
mode, the user chooses one metric to display at a time.

Spectator HUD is placed at the top right of the screen.
]]

local mathmax = math.max
local mathfloor = math.floor
local mathabs = math.abs

local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glBlending = gl.Blending
local glRect = gl.Rect
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glVertex = gl.Vertex

local spGetMouseState = Spring.GetMouseState

local rectRound

local haveFullView = false

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local widgetScale = 0.8
local widgetConfig = 3

local widgetDimensions = {}
local headerDimensions = {}

local viewScreenWidth, viewScreenHeight

local buttonSideLength

local statsBarWidth, statsBarHeight
local statsAreaWidth, statsAreaHeight

local vsModeMetricWidth, vsModeMetricHeight
local vsModeMetricsAreaWidth, vsModeMetricsAreaHeight

local metricChangeBottom
local sortingTop, sortingBottom, sortingLeft, sortingRight
local toggleVSModeTop, toggleVSModeBottom, toggleVSModeLeft, toggleVSModeRight
local statsAreaTop, statsAreaBottom, statsAreaLeft, statsAreaRight
local vsModeMetricsAreaTop, vsModeMetricsAreaBottom, vsModeMetricsAreaLeft, vsModeMetricsAreaRight

local backgroundShader

local headerLabel = "Metal Income"
local headerLabelDefault = "Metal Income"
--[[ note: headerLabelDefault is a silly hack. GetTextHeight will return different value depending
     on the provided text. Therefore, we need to always provide it with the same text or otherwise
     the widget will keep on resizing depending on the header label.
]]

local sortingBackgroundDisplayList
local toggleVSModeBackgroundDisplayList

local statsAreaBackgroundDisplayList
local vsModeBackgroundDisplayLists = {}

local textColorWhite = { 1, 1, 1, 1 }
local font
local fontSize
local fontSizeMetric
local fontSizeVSBar
local fontSizeVSModeKnob

-- TODO: this constant need to be scaled with widget size, screen size and ui_scale
local statBarHeightToHeaderHeight = 1.0

local distanceFromTopBar

local borderPadding
local headerLabelPadding
local buttonPadding
local teamDecalPadding
local teamDecalShrink
local vsModeMetricIconPadding
local teamDecalHeight
local vsModeMetricIconHeight
local vsModeMetricIconWidth
local barOutlineWidth
local barOutlinePadding
local barOutlineCornerSize
local teamDecalCornerSize
local vsModeBarTextPadding
local vsModeDeltaPadding
local vsModeKnobHeight
local vsModeKnobWidth
local vsModeMetricKnobPadding
local vsModeKnobOutline
local vsModeKnobCornerSize
local vsModeBarTriangleSize

local vsModeBarMarkerWidth, vsModeBarMarkerHeight

local vsModeBarPadding
local vsModeLineHeight

local vsModeBarTooltipOffsetX
local vsModeBarTooltipOffsetY

-- note: the different between defaults and constants is that defaults are adjusted according to
-- screen size, widget size and ui scale. On the other hand, constants do not change.
local constants = {
    darkerBarsFactor = 0.4,
    darkerLinesFactor = 0.7,
    darkerSideKnobsFactor = 0.5,
    darkerMiddleKnobFactor = 0.7,

    darkerDecal = 0.8,

    configLevel = {
        basic = 1,
        advanced = 2,
        expert = 3,
        unavailable = 4,
    },
}

local defaults = {
    fontSize = 64 * 1.2,
    fontSizeVSModeKnob = 32,

    distanceFromTopBar = 10,

    borderPadding = 5,
    headerLabelPadding = 20,
    buttonPadding = 8,
    teamDecalPadding = 6,
    teamDecalShrink = 6,
    vsModeMetricIconPadding = 6,
    barOutlineWidth = 4,
    barOutlinePadding = 4,
    barOutlineCornerSize = 8,
    teamDecalCornerSize = 8,
    vsModeBarTextPadding = 20,
    vsModeDeltaPadding = 20,
    vsModeMetricKnobPadding = 20,
    vsModeKnobOutline =  4,
    vsModeKnobCornerSize = 5,
    vsModeBarTriangleSize = 5,

    vsModeBarMarkerWidth = 2,
    vsModeBarMarkerHeight = 8,

    vsModeBarPadding = 8,
    vsModeLineHeight = 12,

    vsModeBarTooltipOffsetX = 60,
    vsModeBarTooltipOffsetY = -60,
}

local tooltipNames = {}

local sortingTooltipName = "spectator_hud_sorting"
local sortingTooltipTitle = "Sorting"

local toggleVSModeTooltipName = "spectator_hud_versus_mode"
local toggleVSModeTooltipTitle = "Versus Mode"
local toggleVSModeTooltipText = "Toggle Versus Mode on/off"

local gaiaID = Spring.GetGaiaTeamID()
local gaiaAllyID = select(6, Spring.GetTeamInfo(gaiaID, false))

local headerTooltipName = "spectator_hud_header"
local headerTooltipTitle = "Select Metric"
local metricsAvailable = {
    { key="metalIncome", configLevel=constants.configLevel.basic, text="M/s" },
    { key="reclaimMetalIncome", configLevel=constants.configLevel.unavailable, text="MR" },
    { key="energyConversionMetalIncome", configLevel=constants.configLevel.expert, text="EC" },
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

local vsMode = true
local vsModeEnabled = false

local metricChosenKey = "metalIncome"
local metricChangeInProgress = false
local sortingChosen = "player"
local teamStats = {}
local vsModeStats = {}

local playerData = nil
local teamOrder = nil

local images = {
    sortingPlayer = "LuaUI/Images/spectator_hud/sorting-player.png",
    sortingTeam = "LuaUI/Images/spectator_hud/sorting-team.png",
    sortingTeamAggregate = "LuaUI/Images/spectator_hud/sorting-plus.png",
    toggleVSMode = "LuaUI/Images/spectator_hud/button-vs.png",
}

local settings = {
    useMovingAverage = false,
    movingAverageWindowSize = 16,

    statsUpdateFrequency = 2        -- every 2nd frame
}

local unitCache = {}
local cachedTotals = {}
local unitDefsToTrack = {}

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
        return unitDef.buildSpeed and (unitDef.buildSpeed > 0)
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
            return value[1]
        end,
        update = nil,
        remove = function(unitID, value)
            return value[1]
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

local function teamHasCommander(teamID)
    local hasCom = false
	for commanderDefID, _ in pairs(unitDefsToTrack.commanderUnitDefs) do
		if Spring.GetTeamUnitDefCount(teamID, commanderDefID) > 0 then
			local unitList = Spring.GetTeamUnitsByDefs(teamID, commanderDefID)
			for i = 1, #unitList do
				if not Spring.GetUnitIsDead(unitList[i]) then
					hasCom = true
				end
			end
		end
	end
	return hasCom
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

local function getAmountOfTeams()
    local amountOfTeams = 0
    for _, allyID in ipairs(Spring.GetAllyTeamList()) do
        if allyID ~= gaiaAllyID then
            local teamList = Spring.GetTeamList(allyID)
            amountOfTeams = amountOfTeams + #teamList
        end
    end
    return amountOfTeams
end

local function getMetricFromID(id)
    for _,metric in ipairs(metricsEnabled) do
        if metric.id == id then
            return metric
        end
    end
    return nil
end

local function getMetricChosen()
    for _, currentMetric in ipairs(metricsEnabled) do
        if metricChosenKey == currentMetric.key then
            return currentMetric
        end
    end
    return nil
end

local updateHeaderTooltip -- symbol declaration, function definition later
local function setMetricChosen(metricKey, ignoreUpdateHeader)
    local metricChosenKeyOld = metricChosenKey
    metricChosenKey = metricKey
    local metricChosen = getMetricChosen()
    if not metricChosen then
        metricChosenKey = metricChosenKeyOld
        return
    end

    if ignoreUpdateHeader then
        return
    end

    headerLabel = metricChosen.title
    updateHeaderTooltip()
end

local function buildMetricsEnabled()
    metricsEnabled = {}

    local index = 1
    for _,metric in ipairs(metricsAvailable) do
        if widgetConfig >= metric.configLevel then
            local metricEnabled = table.copy(metric)
            metricEnabled.id = index
            metricsEnabled[index] = metricEnabled
            if metricChosenKey == metricEnabled.key then
                metricChosenEnabled = true
            end
            local i18nTitleKey = "ui.spectator_hud." .. metricEnabled.key .. "_title"
            metricEnabled.title = Spring.I18N(i18nTitleKey)
            local i18nTooltipKey = "ui.spectator_hud." .. metricEnabled.key .. "_tooltip"
            metricEnabled.tooltip = Spring.I18N(i18nTooltipKey)
            index = index + 1
        end
    end

    if not metricChosenEnabled then
        local firstAvailableMetric = metricsEnabled[1]
        setMetricChosen(firstAvailableMetric.key)
    end
end

local function getAmountOfMetrics()
    return #metricsEnabled
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
    local result = 0

    if statKey == "metalIncome" then
        result = select(4, Spring.GetTeamResources(teamID, "metal")) or 0
    elseif statKey == "reclaimMetalIncome" then
        for unitID,unitPassive in pairs(unitCache[teamID].reclaimerUnits) do
            result = result + unitCache.reclaimerUnits.update(unitID, unitPassive)[1]
        end
        result = mathmax(0, result)
    elseif statKey == "energyConversionMetalIncome" then
        for unitID,_ in pairs(unitCache[teamID].energyConverters) do
            result = result + unitCache.energyConverters.update(unitID, 0)
        end
    elseif statKey == "energyIncome" then
        result = select(4, Spring.GetTeamResources(teamID, "energy")) or 0
    elseif statKey == "reclaimEnergyIncome" then
        for unitID,unitPassive in pairs(unitCache[teamID].reclaimerUnits) do
            result = result + unitCache.reclaimerUnits.update(unitID, unitPassive)[2]
        end
        result = mathmax(0, result)
    elseif statKey == "buildPower" then
        result = cachedTotals[teamID].buildPower
    elseif statKey == "metalProduced" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        if statsHistory and #statsHistory > 0 then
            result = statsHistory[1].metalProduced
        end
    elseif statKey == "energyProduced" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        if statsHistory and #statsHistory > 0 then
            result = statsHistory[1].energyProduced
        end
    elseif statKey == "metalExcess" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        if statsHistory and #statsHistory > 0 then
            result = statsHistory[1].metalExcess
        end
    elseif statKey == "energyExcess" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        if statsHistory and #statsHistory > 0 then
            result = statsHistory[1].energyExcess
        end
    elseif statKey == "armyValue" then
        result = cachedTotals[teamID].armyUnits
    elseif statKey == "defenseValue" then
        result = cachedTotals[teamID].defenseUnits
    elseif statKey == "utilityValue" then
        result = cachedTotals[teamID].utilityUnits
    elseif statKey == "economyValue" then
        result = cachedTotals[teamID].economyBuildings
    elseif statKey == "damageDealt" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        local damageDealt = 0
        if statsHistory and #statsHistory > 0 then
            damageDealt = statsHistory[1].damageDealt
        end
        result = damageDealt
    elseif statKey == "damageReceived" then
        local historyMax = Spring.GetTeamStatsHistory(teamID)
        local statsHistory = Spring.GetTeamStatsHistory(teamID, historyMax)
        local damageReceived = 0
        if statsHistory and #statsHistory > 0 then
            damageReceived = statsHistory[1].damageReceived
        end
        result = damageReceived
    elseif statKey == "damageEfficiency" then
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
    local colorDarker = function(color)
        local factor = 0.7
        local alpha = 0.2
        return {
            color[1] * factor,
            color[2] * factor,
            color[3] * factor,
            alpha
        }
    end

    teamStats = {}
    teamStats.allyTeams = {}

    for _, allyID in ipairs(Spring.GetAllyTeamList()) do
        teamStats[allyID] = {}
        if allyID ~= gaiaAllyID then
            teamStats.allyTeams[allyID] = {}
            local allyTeam = teamStats.allyTeams[allyID]
            allyTeam.id = allyID
            local teamList = Spring.GetTeamList(allyID)

            local colorCaptain = playerData[teamList[1]].color
            allyTeam.color = colorCaptain
            allyTeam.colorDarker = colorDarker(colorCaptain)
            allyTeam.name = string.format("Team %d", allyID)
            allyTeam.allyTeam = allyTeam  -- self-reference used in displaying teamaggregate

            allyTeam.teams = {}

            for _, teamID in ipairs(teamList) do
                allyTeam.teams[teamID] = {}
                local team = allyTeam.teams[teamID]
                team.id = teamID
                team.color = playerData[teamID].color
                team.colorDecal = makeDarkerColor(playerData[teamID].color, constants.darkerDecal)
                team.name = playerData[teamID].name
                team.allyTeam = allyTeam

                team.hasCommander = false

                team.movingAverage = {}
                initMovingAverage(team.movingAverage)
                team.value = 0
            end

            allyTeam.value = 0  -- used for team sorting and aggregate mode
        end
    end

    teamStats.data = {}

    if (sortingChosen == "player") or (sortingChosen == "team") then
        for _,allyID in ipairs(Spring.GetAllyTeamList()) do
            if allyID ~= gaiaAllyID then
                local teamList = Spring.GetTeamList(allyID)
                for _,teamID in ipairs(teamList) do
                    table.insert(teamStats.data, teamStats.allyTeams[allyID].teams[teamID])
                end
            end
        end
    elseif sortingChosen == "teamaggregate" then
        for _,allyID in ipairs(Spring.GetAllyTeamList()) do
            if allyID ~= gaiaAllyID then
                table.insert(teamStats.data, teamStats.allyTeams[allyID])
            end
        end
    end
end

local function updateStatsNormalMode(statKey)
    for _, allyID in ipairs(Spring.GetAllyTeamList()) do
        if allyID ~= gaiaAllyID then
            local teamList = Spring.GetTeamList(allyID)

            local allyTeamTotal = 0
            for _, teamID in ipairs(teamList) do
                local team = teamStats.allyTeams[allyID].teams[teamID]
                team.hasCommander = teamHasCommander(teamID)

                local teamValue = getOneStat(statKey, teamID)
                updateMovingAverage(team.movingAverage, teamValue)
                team.value = team.movingAverage.average
                allyTeamTotal = allyTeamTotal + team.value
            end

            teamStats.allyTeams[allyID].value = allyTeamTotal
        end
    end

    if sortingChosen == "player" then
        table.sort(teamStats.data, function (left, right)
            if left.value == right.value then
                return left.id < right.id
            end
            return left.value < right.value
        end)
    elseif sortingChosen == "team" then
        table.sort(teamStats.data, function (left, right)
            if left.allyTeam ~= right.allyTeam then
                if left.allyTeam.value == right.allyTeam.value then
                    return left.id < right.id
                end
                return left.allyTeam.value < right.allyTeam.value
            end
            if left.value == right.value then
                return left.id < right.id
            end
            return left.value < right.value
        end)
    elseif sortingChosen == "teamaggregate" then
        table.sort(teamStats.data, function (left, right)
            if left.value == right.value then
                return left.id < right.id
            end
            return left.value < right.value
        end)
    end
end

local function createVSModeStats()
    -- This function exists as a performance optimization. On every GameFrame()
    -- we update vsmode stats. However, rather than recreating tables in Lua
    -- which would require memory allocation and release and thus extra work for
    -- the garbage collector, we reuse the same memory over and over. It is in
    -- this function the memory is allocated.
    -- As a nice bonus, this function reduces calls to GetTeamColor().
    -- Note that the counter-part to this function where we release memory is not
    -- needed as we are not looking to save memory.

    -- Here's the layout of memory in vsModeStats, formatted in yaml

--[[
vsModeStats:
- allyID:
  - metrics:
    - metric.id:
      - values:
        teamID: team value
      total: allyTeam value
  color: team captain color
  colorBar: team captain color for bars
  colorLine: team captain color for lines
  colorKnobSide: team captain color for side knob
  colorKnobMiddle: team captain color for middle knob
]]

    vsModeStats = {}

    for _, allyID in ipairs(Spring.GetAllyTeamList()) do
        if allyID ~= gaiaAllyID then
            vsModeStats[allyID] = {}
            local teamList = Spring.GetTeamList(allyID)
            -- use color of captain
            local colorCaptain = playerData[teamList[1]].color
            vsModeStats[allyID].color = colorCaptain
            vsModeStats[allyID].colorBar = makeDarkerColor(colorCaptain, constants.darkerBarsFactor)
            vsModeStats[allyID].colorLine = makeDarkerColor(colorCaptain, constants.darkerLinesFactor)
            vsModeStats[allyID].colorKnobSide = makeDarkerColor(colorCaptain, constants.darkerSideKnobsFactor)
            vsModeStats[allyID].colorKnobMiddle = makeDarkerColor(colorCaptain, constants.darkerMiddleKnobFactor)

            vsModeStats[allyID].metrics = {}
            for _, metric in ipairs(metricsEnabled) do
                vsModeStats[allyID].metrics[metric.id] = {}
                vsModeStats[allyID].metrics[metric.id].values = {}

                for _, teamID in ipairs(teamList) do
                    vsModeStats[allyID].metrics[metric.id].values[teamID] = {}
                    initMovingAverage(vsModeStats[allyID].metrics[metric.id].values[teamID])
                end

                vsModeStats[allyID].metrics[metric.id].total = 0
            end
        end
    end
end

local function updateStatsVSMode()
    for _, allyID in ipairs(Spring.GetAllyTeamList()) do
        if allyID ~= gaiaAllyID then
            local teamList = Spring.GetTeamList(allyID)
            for _,metric in ipairs(metricsEnabled) do
                local statsTable = vsModeStats[allyID].metrics[metric.id]
                local valueAllyTeam = 0
                for _,teamID in ipairs(teamList) do
                    local valueTeam = getOneStat(metric.key, teamID)
                    updateMovingAverage(statsTable.values[teamID], valueTeam)
                    valueAllyTeam = valueAllyTeam + statsTable.values[teamID].average
                end
                statsTable.total = valueAllyTeam
            end
        end
    end
end

local function updateStats()
    if not vsMode then
        updateStatsNormalMode(metricChosenKey)
    else
        updateStatsVSMode()
    end
end

local function calculateHeaderSize()
    local headerTextHeight = font:GetTextHeight(headerLabelDefault) * fontSize
    headerDimensions.height = mathfloor(2 * borderPadding + headerTextHeight)

    -- all buttons on the header are squares and of the same size
    -- their sides are the same length as the header height
    buttonSideLength = headerDimensions.height

    -- currently, we have four buttons
    headerDimensions.width = widgetDimensions.width - 2 * buttonSideLength
end

local function calculateStatsBarSize()
    statsBarHeight = mathfloor(headerDimensions.height * statBarHeightToHeaderHeight)
    statsBarWidth = widgetDimensions.width
end

local function calculateVSModeMetricSize()
    vsModeMetricHeight = mathfloor(headerDimensions.height * statBarHeightToHeaderHeight)
    vsModeMetricWidth = widgetDimensions.width
end

local function setSortingPosition()
    sortingTop = widgetDimensions.top
    sortingBottom = widgetDimensions.top - buttonSideLength
    sortingLeft = widgetDimensions.right - buttonSideLength
    sortingRight = widgetDimensions.right
end

local function setToggleVSModePosition()
    toggleVSModeTop = widgetDimensions.top
    toggleVSModeBottom = widgetDimensions.top - buttonSideLength
    toggleVSModeLeft = sortingLeft - buttonSideLength
    toggleVSModeRight = sortingLeft
end

local function setHeaderPosition()
    headerDimensions.top = widgetDimensions.top
    headerDimensions.bottom = widgetDimensions.top - headerDimensions.height
    headerDimensions.left = widgetDimensions.left
    headerDimensions.right = widgetDimensions.left + headerDimensions.width

    metricChangeBottom = headerDimensions.bottom - headerDimensions.height * getAmountOfMetrics()
end

local function setStatsAreaPosition()
    statsAreaTop = widgetDimensions.top - headerDimensions.height
    statsAreaBottom = widgetDimensions.bottom
    statsAreaLeft = widgetDimensions.left
    statsAreaRight = widgetDimensions.right
end

local function setVSModeMetricsAreaPosition()
    vsModeMetricsAreaTop = widgetDimensions.top - headerDimensions.height
    vsModeMetricsAreaBottom = widgetDimensions.bottom
    vsModeMetricsAreaLeft = widgetDimensions.left
    vsModeMetricsAreaRight = widgetDimensions.right
end

local function calculateWidgetSizeScaleVariables(scaleMultiplier)
    -- Lua has a limit in "upvalues" (60 in total) and therefore this is split
    -- into a separate function
    distanceFromTopBar = mathfloor(defaults.distanceFromTopBar * scaleMultiplier)
    borderPadding = mathfloor(defaults.borderPadding * scaleMultiplier)
    headerLabelPadding = mathfloor(defaults.headerLabelPadding * scaleMultiplier)
    buttonPadding = mathfloor(defaults.buttonPadding * scaleMultiplier)
    teamDecalPadding = mathfloor(defaults.teamDecalPadding * scaleMultiplier)
    teamDecalShrink = mathfloor(defaults.teamDecalShrink * scaleMultiplier)
    vsModeMetricIconPadding = mathfloor(defaults.vsModeMetricIconPadding * scaleMultiplier)
    barOutlineWidth = mathfloor(defaults.barOutlineWidth * scaleMultiplier)
    barOutlinePadding = mathfloor(defaults.barOutlinePadding * scaleMultiplier)
    barOutlineCornerSize = mathfloor(defaults.barOutlineCornerSize * scaleMultiplier)
    teamDecalCornerSize = mathfloor(defaults.teamDecalCornerSize * scaleMultiplier)
    vsModeBarTextPadding = mathfloor(defaults.vsModeBarTextPadding * scaleMultiplier)
    vsModeDeltaPadding = mathfloor(defaults.vsModeDeltaPadding * scaleMultiplier)
    vsModeMetricKnobPadding = mathfloor(defaults.vsModeMetricKnobPadding * scaleMultiplier)
    vsModeKnobOutline = mathfloor(defaults.vsModeKnobOutline * scaleMultiplier)
    vsModeKnobCornerSize = mathfloor(defaults.vsModeKnobCornerSize * scaleMultiplier)
    vsModeBarTriangleSize = mathfloor(defaults.vsModeBarTriangleSize * scaleMultiplier)
    vsModeBarPadding = mathfloor(defaults.vsModeBarPadding * scaleMultiplier)
    vsModeLineHeight = mathfloor(defaults.vsModeLineHeight * scaleMultiplier)
    vsModeBarTooltipOffsetX = mathfloor(defaults.vsModeBarTooltipOffsetX * scaleMultiplier)
    vsModeBarTooltipOffsetY = mathfloor(defaults.vsModeBarTooltipOffsetY * scaleMultiplier)
end

local function calculateWidgetSize()
    local scaleMultiplier = ui_scale * widgetScale * viewScreenWidth / 3840
    calculateWidgetSizeScaleVariables(scaleMultiplier)

    fontSize = mathfloor(defaults.fontSize * scaleMultiplier)
    fontSizeMetric = mathfloor(fontSize * 0.5)
    fontSizeVSBar = mathfloor(fontSize * 0.5)
    fontSizeVSModeKnob = mathfloor(defaults.fontSizeVSModeKnob * scaleMultiplier)

    widgetDimensions.width = mathfloor(viewScreenWidth * 0.20 * ui_scale * widgetScale)

    calculateHeaderSize()
    calculateStatsBarSize()
    calculateVSModeMetricSize()
    statsAreaWidth = widgetDimensions.width
    vsModeMetricsAreaWidth = widgetDimensions.width

    local statBarAmount
    if sortingChosen == "teamaggregate" then
        statBarAmount = getAmountOfAllyTeams()
    else
        statBarAmount = getAmountOfTeams()
    end
    statsAreaHeight = statsBarHeight * statBarAmount
    teamDecalHeight = statsBarHeight - borderPadding * 2 - teamDecalPadding * 2
    vsModeMetricIconHeight = vsModeMetricHeight - borderPadding * 2 - vsModeMetricIconPadding * 2
    vsModeMetricIconWidth = vsModeMetricIconHeight * 2
    vsModeBarMarkerWidth = mathfloor(defaults.vsModeBarMarkerWidth * scaleMultiplier)
    vsModeBarMarkerHeight = mathfloor(defaults.vsModeBarMarkerHeight * scaleMultiplier)
    vsModeKnobHeight = vsModeMetricHeight - borderPadding * 2 - vsModeMetricKnobPadding * 2
    vsModeKnobWidth = vsModeKnobHeight * 5

    vsModeMetricsAreaHeight = vsModeMetricHeight * getAmountOfMetrics()

    if not vsMode then
        widgetDimensions.height = headerDimensions.height + statsAreaHeight
    else
        widgetDimensions.height = headerDimensions.height + vsModeMetricsAreaHeight
    end
end

local function setWidgetPosition()
    -- widget is placed underneath topbar
    if WG['topbar'] then
        local topBarPosition = WG['topbar'].GetPosition()
        widgetDimensions.top = topBarPosition[2] - distanceFromTopBar
    else
        widgetDimensions.top = viewScreenHeight
    end
    widgetDimensions.bottom = widgetDimensions.top - widgetDimensions.height
    widgetDimensions.right = viewScreenWidth
    widgetDimensions.left = widgetDimensions.right - widgetDimensions.width

    setHeaderPosition()
    setSortingPosition()
    setToggleVSModePosition()
    setStatsAreaPosition()
    setVSModeMetricsAreaPosition()
end

local function createBackgroundShader()
    if WG['guishader'] then
        backgroundShader = gl.CreateList(function ()
            rectRound(
                widgetDimensions.left,
                widgetDimensions.bottom,
                widgetDimensions.right,
                widgetDimensions.top,
                WG.FlowUI.elementCorner)
        end)
        WG['guishader'].InsertDlist(backgroundShader, 'spectator_hud', true)
    end
end

local function drawHeader()
    WG.FlowUI.Draw.Element(
        headerDimensions.left,
        headerDimensions.bottom,
        headerDimensions.right,
        headerDimensions.top,
        1, 1, 1, 1,
        1, 1, 1, 1
    )

    font:Begin()
    font:SetTextColor(textColorWhite)
    font:Print(
        headerLabel,
        headerDimensions.left + borderPadding + headerLabelPadding,
        headerDimensions.bottom + borderPadding + headerLabelPadding,
        fontSize - headerLabelPadding * 2,
        'o'
    )
    font:End()
end

updateHeaderTooltip = function ()
    if WG['tooltip'] then
        local metricChosen = getMetricChosen()
        local tooltipText = metricChosen.tooltip
        WG['tooltip'].AddTooltip(
            headerTooltipName,
            { headerDimensions.left, headerDimensions.bottom, headerDimensions.right, headerDimensions.top },
            tooltipText,
            nil,
            headerTooltipTitle
        )
    end
end

local function updateSortingTooltip()
    if WG['tooltip'] then
        local tooltipText
        if sortingChosen == "player" then
            tooltipText = "Sort by Player (click to change)"
        elseif sortingChosen == "team" then
            tooltipText = "Sort by Team (click to change)"
        elseif sortingChosen == "teamaggregate" then
            tooltipText = "Sort by Team Aggregate (click to change)"
        end
    
        WG['tooltip'].AddTooltip(
            sortingTooltipName,
            { sortingLeft, sortingBottom, sortingRight, sortingTop },
            tooltipText,
            nil,
            sortingTooltipTitle
        )
    end
end

local function updateToggleVSModeTooltip()
    if WG['tooltip'] then
        WG['tooltip'].AddTooltip(
            toggleVSModeTooltipName,
            { toggleVSModeLeft, toggleVSModeBottom, toggleVSModeRight, toggleVSModeTop },
            toggleVSModeTooltipText,
            nil,
            toggleVSModeTooltipTitle
        )
    end
end

local function updateVSModeTooltips()
    local iconLeft = vsModeMetricsAreaLeft + borderPadding + vsModeMetricIconPadding
    local iconRight = iconLeft + vsModeMetricIconWidth

    if WG['tooltip'] then
        for _, metric in ipairs(metricsEnabled) do
            local bottom = vsModeMetricsAreaTop - metric.id * vsModeMetricHeight
            local top = bottom + vsModeMetricHeight

            local iconBottom = bottom + borderPadding + vsModeMetricIconPadding
            local iconTop = iconBottom + vsModeMetricIconHeight

            WG['tooltip'].AddTooltip(
                string.format("spectator_hud_vsmode_%d", metric.id),
                { iconLeft, iconBottom, iconRight, iconTop },
                metric.tooltip,
                nil,
                metric.title
            )
        end
    end
end

local function deleteHeaderTooltip()
    if WG['tooltip'] then
        WG['tooltip'].RemoveTooltip(headerTooltipName)
    end
end

local function deleteSortingTooltip()
    if WG['tooltip'] then
        WG['tooltip'].RemoveTooltip(sortingTooltipName)
    end
end

local function deleteToggleVSModeTooltip()
    if WG['tooltip'] then
        WG['tooltip'].RemoveTooltip(toggleVSModeTooltipName)
    end
end

local function deleteVSModeTooltips()
    if WG['tooltip'] then
        for _, metric in ipairs(metricsEnabled) do
            WG['tooltip'].RemoveTooltip(string.format("spectator_hud_vsmode_%d", metric.id))
        end
    end
end

local function createSorting()
    sortingBackgroundDisplayList = gl.CreateList(function ()
        WG.FlowUI.Draw.Element(
            sortingLeft,
            sortingBottom,
            sortingRight,
            sortingTop,
            1, 1, 1, 1,
            1, 1, 1, 1
        )
    end)
end

local function createToggleVSMode()
    toggleVSModeBackgroundDisplayList = gl.CreateList(function ()
        WG.FlowUI.Draw.Element(
            toggleVSModeLeft,
            toggleVSModeBottom,
            toggleVSModeRight,
            toggleVSModeTop,
            1, 1, 1, 1,
            1, 1, 1, 1
        )
    end)
end

local function drawSorting()
    glColor(1, 1, 1, 1)
    if sortingChosen == "player" then
        glTexture(images["sortingPlayer"])
    elseif sortingChosen == "team" then
        glTexture(images["sortingTeam"])
    elseif sortingChosen == "teamaggregate" then
        glTexture(images["sortingTeamAggregate"])
    end
    glTexRect(
        sortingLeft + buttonPadding,
        sortingBottom + buttonPadding,
        sortingRight - buttonPadding,
        sortingTop - buttonPadding
    )
    glTexture(false)
end

local function drawToggleVSMode()
    -- TODO: add visual indication when toggle disabled
    glColor(1, 1, 1, 1)
    glTexture(images["toggleVSMode"])
    glTexRect(
        toggleVSModeLeft + buttonPadding,
        toggleVSModeBottom + buttonPadding,
        toggleVSModeRight - buttonPadding,
        toggleVSModeTop - buttonPadding
    )
    glTexture(false)

    if vsMode then
        glBlending(GL.SRC_ALPHA, GL.ONE)
        glColor(1, 0.2, 0.2, 0.2)
        glRect(
            toggleVSModeLeft + buttonPadding,
            toggleVSModeBottom + buttonPadding,
            toggleVSModeRight - buttonPadding,
            toggleVSModeTop - buttonPadding
        )
        glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end
end

local function createStatsArea()
    statsAreaBackgroundDisplayList = gl.CreateList(function ()
        WG.FlowUI.Draw.Element(
            statsAreaLeft,
            statsAreaBottom,
            statsAreaRight,
            statsAreaTop,
            1, 1, 1, 1,
            1, 1, 1, 1
        )
    end)
end

local function createVSModeBackgroudDisplayLists()
    vsModeBackgroundDisplayLists = {}
    for _, metric in ipairs(metricsEnabled) do
        local currentBottom = vsModeMetricsAreaTop - metric.id * vsModeMetricHeight
        local currentTop = currentBottom + vsModeMetricHeight
        local currentDisplayList = gl.CreateList(function ()
            WG.FlowUI.Draw.Element(
                vsModeMetricsAreaLeft,
                currentBottom,
                vsModeMetricsAreaRight,
                currentTop,
                1, 1, 1, 1,
                1, 1, 1, 1
            )
        end)
        table.insert(vsModeBackgroundDisplayLists, currentDisplayList)
    end
end

local function drawAUnicolorBar(left, bottom, right, top, value, max, color, bgColor)
    glColor(bgColor)
    rectRound(
        left,
        bottom,
        right,
        top,
        barOutlineCornerSize
    )

    local scaleFactor = (right - left - 2 * (barOutlineWidth + barOutlinePadding)) / max

    local leftInner = left + barOutlineWidth + barOutlinePadding
    local bottomInner = bottom + barOutlineWidth + barOutlinePadding
    local rightInner = left + barOutlineWidth + barOutlinePadding + mathfloor(value * scaleFactor)
    local topInner = top - barOutlineWidth - barOutlinePadding

    glColor(color)
    glRect(leftInner, bottomInner, rightInner, topInner)

    local function addDarkGradient(left, bottom, right, top)
        glBlending(GL.SRC_ALPHA, GL.ONE)

        local middle = mathfloor((right + left) / 2)

        glColor(0, 0, 0, 0.15)
        glVertex(left, bottom)
        glVertex(left, top)

        glColor(0, 0, 0, 0.3)
        glVertex(middle, top)
        glVertex(middle, bottom)

        glColor(0, 0, 0, 0.3)
        glVertex(middle, bottom)
        glVertex(middle, top)

        glColor(0, 0, 0, 0.15)
        glVertex(right, top)
        glVertex(right, bottom)

        glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
    end
    glBeginEnd(GL.QUADS, addDarkGradient, leftInner, bottomInner, rightInner, topInner)
end

local function drawAStatsBar(index, value, max, color, colorDecal, bgColor, hasCommander, playerName)
    local statBarBottom = statsAreaTop - index * statsBarHeight
    local statBarTop = statBarBottom + statsBarHeight

    local teamDecalBottom = statBarBottom + borderPadding + teamDecalPadding
    local teamDecalTop = statBarTop - borderPadding - teamDecalPadding

    local teamDecalSize = teamDecalTop - teamDecalBottom

    local teamDecalLeft = statsAreaLeft + borderPadding + teamDecalPadding
    local teamDecalRight = teamDecalLeft + teamDecalSize

    local shrink = hasCommander and 0 or teamDecalShrink

    rectRound(
        teamDecalLeft + shrink,
        teamDecalBottom + shrink,
        teamDecalRight - shrink,
        teamDecalTop - shrink,
        teamDecalCornerSize,
        1, 1, 1, 1,
        colorDecal
    )
    glColor(1, 1, 1, 1)

    local barLeft = teamDecalRight + borderPadding * 2 + teamDecalPadding
    local barRight = statsAreaRight - borderPadding - teamDecalPadding

    local barBottom = teamDecalBottom
    local barTop = teamDecalTop
    drawAUnicolorBar(
        barLeft,
        barBottom,
        barRight,
        barTop,
        value,
        max,
        color,
        bgColor
    )

    local amountText = formatResources(value, false)
    local amountMiddle = teamDecalRight + mathfloor((statsAreaRight - teamDecalRight) / 2)
    local amountCenter = barBottom + mathfloor((barTop - barBottom) / 2)
    font:Begin()
        font:SetTextColor(textColorWhite)
        font:Print(
            amountText,
            amountMiddle,
            amountCenter,
            fontSizeMetric,
            'cvo'
        )
    font:End()

    if WG['tooltip'] and playerName then
        local tooltipName = string.format("stat_bar_player_%d", index)
        WG['tooltip'].AddTooltip(
            tooltipName,
            {
                teamDecalLeft,
                teamDecalBottom,
                teamDecalRight,
                teamDecalTop
            },
            playerName
        )
        table.insert(tooltipNames, tooltipName)
    end
end

local function drawStatsBars()
    local max = 1
    for _, currentData in ipairs(teamStats.data) do
        if max < currentData.value then
            max = currentData.value
        end
    end

    local index = #teamStats.data
    for _, currentData in ipairs(teamStats.data) do
        drawAStatsBar(
            index,
            currentData.value,
            max,
            currentData.color,
            currentData.colorDecal,
            currentData.allyTeam.colorDarker,
            currentData.hasCommander,
            currentData.name
        )
        index = index - 1
    end
end

local function drawVSModeKnob(left, bottom, right, top, color, text)
    local greyFactor = 0.5
    local matchingGreyRed = color[1] * greyFactor
    local matchingGreyGreen = color[2] * greyFactor
    local matchingGreyBlue = color[3] * greyFactor
    glColor(matchingGreyRed, matchingGreyGreen, matchingGreyBlue, 1)
    rectRound(
        left,
        bottom,
        right,
        top,
        vsModeKnobCornerSize
    )
    glColor(color)
    rectRound(
        left + vsModeKnobOutline,
        bottom + vsModeKnobOutline,
        right - vsModeKnobOutline,
        top - vsModeKnobOutline,
        vsModeKnobCornerSize
    )

    local knobTextAreaWidth = right - left - 2 * vsModeKnobOutline
    local fontSizeSmaller = fontSizeVSModeKnob
    local textWidth = font:GetTextWidth(text)
    while textWidth * fontSizeSmaller > knobTextAreaWidth do
        fontSizeSmaller = fontSizeSmaller - 1
    end

    font:Begin()
        font:SetTextColor(textColorWhite)
        font:Print(
            text,
            mathfloor((right + left) / 2),
            mathfloor((top + bottom) / 2),
            fontSizeSmaller,
            'cvO'
        )
    font:End()
end

local colorKnobMiddleGrey = { 0.5, 0.5, 0.5, 1 }
local function drawVSBar(left, bottom, right, top, indexLeft, indexRight, metricID)
    local statsLeft = vsModeStats[indexLeft].metrics[metricID]
    local statsRight = vsModeStats[indexRight].metrics[metricID]

    local valueLeft = statsLeft.total
    local valueRight = statsRight.total

    local barTop = top - vsModeBarPadding
    local barBottom = bottom + vsModeBarPadding

    local barLength = right - left - vsModeKnobWidth

    local leftBarWidth
    if valueLeft > 0 or valueRight > 0 then
        leftBarWidth = mathfloor(barLength * valueLeft / (valueLeft + valueRight))
    else
        leftBarWidth = mathfloor(barLength / 2)
    end
    local rightBarWidth = barLength - leftBarWidth

    local colorMiddleKnob
    if valueLeft > valueRight then
        colorMiddleKnob = vsModeStats[indexLeft].colorKnobMiddle
    elseif valueRight > valueLeft then
        colorMiddleKnob = vsModeStats[indexRight].colorKnobMiddle
    else
        -- color grey if even
        colorMiddleKnob = colorKnobMiddleGrey
    end

    glColor(vsModeStats[indexLeft].colorBar)
    glRect(
        left,
        barBottom,
        left + leftBarWidth,
        barTop
    )

    glColor(vsModeStats[indexRight].colorBar)
    glRect(
        right - rightBarWidth,
        barBottom,
        right,
        barTop
    )

    -- only draw team lines if mouse on bar
    local mouseX, mouseY = spGetMouseState()
    if ((valueLeft > 0) or (valueRight > 0)) and
            ((mouseX > left) and (mouseX < right) and (mouseY > bottom) and (mouseY < top)) then
        local scalingFactor = barLength / (valueLeft + valueRight)
        local lineMiddle = mathfloor((top + bottom) / 2)

        local lineStart
        local lineEnd = left
        for _, teamID in ipairs(Spring.GetTeamList(indexLeft)) do
            local teamValue = statsLeft.values[teamID].average
            local teamColor = playerData[teamID].color
            lineStart = lineEnd
            lineEnd = lineEnd + mathfloor(teamValue * scalingFactor)
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
        for _, teamID in ipairs(Spring.GetTeamList(indexRight)) do
            local teamValue = statsRight.values[teamID].average
            local teamColor = playerData[teamID].color
            lineStart = lineEnd
            lineEnd = lineEnd + mathfloor(teamValue * scalingFactor)
            glColor(teamColor)
            glRect(
                lineStart,
                barBottom,
                lineEnd,
                barTop
            )
        end

        -- when mouseover, middle knob shows absolute values
        drawVSModeKnob(
            left + leftBarWidth + 1,
            bottom,
            right - rightBarWidth - 1,
            top,
            colorMiddleKnob,
            formatResources(mathabs(valueLeft - valueRight), true)
        )
    else
        local lineMiddle = mathfloor((top + bottom) / 2)
        local lineBottom = lineMiddle - mathfloor(vsModeLineHeight / 2)
        local lineTop = lineMiddle + mathfloor(vsModeLineHeight / 2)

        glColor(vsModeStats[indexLeft].colorLine)
        glRect(
            left,
            lineBottom,
            left + leftBarWidth,
            lineTop
        )

        glColor(vsModeStats[indexRight].colorLine)
        glRect(
            right - rightBarWidth,
            lineBottom,
            right,
            lineTop
        )

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
        drawVSModeKnob(
            left + leftBarWidth + 1,
            bottom,
            right - rightBarWidth - 1,
            top,
            colorMiddleKnob,
            relativeLeadString
        )
    end

    if WG['tooltip'] and ((mouseX > left) and (mouseX < right) and (mouseY > bottom) and (mouseY < top)) then
        local leftTeamValues = {}
        for _, teamID in ipairs(Spring.GetTeamList(indexLeft)) do
            table.insert(leftTeamValues, {
                value=statsLeft.values[teamID].average,
                name=playerData[teamID].name
            })
        end
        table.sort(leftTeamValues, function(left, right) return left.value > right.value end)

        local rightTeamValues = {}
        for _, teamID in ipairs(Spring.GetTeamList(indexRight)) do
            table.insert(rightTeamValues, {
                value=statsRight.values[teamID].average,
                name=playerData[teamID].name
            })
        end
        table.sort(rightTeamValues, function(left, right) return left.value > right.value end)

        local leftTeamValuesStringTable = {}
        for _,value in ipairs(leftTeamValues) do
            table.insert(leftTeamValuesStringTable, string.format("  %s: %s\n",
                value.name,
                formatResources(value.value, true)))
        end
        local rightTeamValuesStringTable = {}
        for _,value in ipairs(rightTeamValues) do
            table.insert(rightTeamValuesStringTable, string.format("  %s: %s\n",
                value.name,
                formatResources(value.value, true)))
        end

        local tooltipString = string.format("Team %d: %s\n", indexLeft, formatResources(valueLeft, true)) ..
            table.concat(leftTeamValuesStringTable) ..
            string.format("Team %d: %s\n", indexRight, formatResources(valueRight, true)) ..
            table.concat(rightTeamValuesStringTable)

        -- remove last \n
        tooltipString = tooltipString:sub(1, -2)

        local metric = getMetricFromID(metricID)
        local metricTitle = metric.title

        WG['tooltip'].ShowTooltip(
            "spectator_hud_vsmode_mouseover_tooltip",
            tooltipString,
            mouseX + vsModeBarTooltipOffsetX,
            mouseY + vsModeBarTooltipOffsetY,
            metricTitle
        )
    end
end

local function drawVSModeMetrics()
    local indexLeft = teamOrder and teamOrder[1] or 0
    local indexRight = teamOrder and teamOrder[2] or 1
    for _, metric in ipairs(metricsEnabled) do
        local statsLeft = vsModeStats[indexLeft].metrics[metric.id]
        local statsRight = vsModeStats[indexRight].metrics[metric.id]

        local bottom = vsModeMetricsAreaTop - metric.id * vsModeMetricHeight

        local iconLeft = vsModeMetricsAreaLeft + borderPadding + vsModeMetricIconPadding
        local iconRight = iconLeft + vsModeMetricIconWidth
        local iconBottom = bottom + borderPadding + vsModeMetricIconPadding
        local iconTop = iconBottom + vsModeMetricIconHeight

        local iconHCenter = mathfloor((iconRight + iconLeft) / 2)
        local iconVCenter = mathfloor((iconTop + iconBottom) / 2)
        local iconText = metric.text

        font:Begin()
            font:SetTextColor(textColorWhite)
            font:Print(
                iconText,
                iconHCenter,
                iconVCenter,
                fontSizeVSBar,
                'cvo'
            )
        font:End()

        local leftKnobLeft = iconRight + borderPadding + vsModeMetricIconPadding * 2
        local leftKnobBottom = iconBottom
        local leftKnobRight = leftKnobLeft + vsModeKnobWidth
        local leftKnobTop = iconTop
        drawVSModeKnob(
            leftKnobLeft,
            leftKnobBottom,
            leftKnobRight,
            leftKnobTop,
            vsModeStats[indexLeft].colorKnobSide,
            formatResources(statsLeft.total, true)
        )

        local rightKnobRight = vsModeMetricsAreaRight - borderPadding - vsModeMetricIconPadding * 2
        local rightKnobBottom = iconBottom
        local rightKnobLeft = rightKnobRight - vsModeKnobWidth
        local rightKnobTop = iconTop
        drawVSModeKnob(
            rightKnobLeft,
            rightKnobBottom,
            rightKnobRight,
            rightKnobTop,
            vsModeStats[indexRight].colorKnobSide,
            formatResources(statsRight.total, true)
        )

        drawVSBar(
            leftKnobRight,
            iconBottom,
            rightKnobLeft,
            iconTop,
            indexLeft,
            indexRight,
            metric.id
        )
    end
end

local function mySelector(px, py, sx, sy)
    -- modified version of WG.FlowUI.Draw.Selector

    local cs = (sy-py)*0.05
	local edgeWidth = mathmax(1, mathfloor((sy-py) * 0.05))

	-- faint dark outline edge
	rectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.5 })
	-- body
	rectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.05, 0.05, 0.05, 0.8 }, { 0.15, 0.15, 0.15, 0.8 })

	-- highlight
	glBlending(GL.SRC_ALPHA, GL.ONE)
	-- top
	rectRound(px, sy-(edgeWidth*3), sx, sy, edgeWidth, 1,1,1,1, { 1,1,1,0 }, { 1,1,1,0.035 })
	-- bottom
	rectRound(px, py, sx, py+(edgeWidth*3), edgeWidth, 1,1,1,1, { 1,1,1,0.025 }, { 1,1,1,0  })
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- button
	rectRound(px, py, sx, sy, cs, 1, 1, 1, 1, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.14 })
	--WG.FlowUI.Draw.Button(sx-(sy-py), py, sx, sy, 1, 1, 1, 1, 1,1,1,1, nil, { 1, 1, 1, 0.1 }, nil, cs)
end

local function drawMetricChange()
    mySelector(
        headerDimensions.left,
        metricChangeBottom,
        headerDimensions.right,
        headerDimensions.bottom
    )

    -- TODO: this is not working, find out why
    local mouseX, mouseY = spGetMouseState()
    if (mouseX > headerDimensions.left) and
            (mouseX < headerDimensions.right) and
            (mouseY > headerDimensions.bottom) and
            (mouseY < metricChangeBottom) then
        local mouseHovered = mathfloor((mouseY - metricChangeBottom) / headerDimensions.height)
        local highlightBottom = metricChangeBottom + mouseHovered * headerDimensions.height
        local highlightTop = highlightBottom + headerDimensions.height
        WG.FlowUI.Draw.SelectHighlight(
            headerDimensions.left,
            highlightBottom,
            headerDimensions.right,
            highlightTop
        )
    end

    font:Begin()
        font:SetTextColor(textColorWhite)
        local distanceFromTop = 0
        local amountOfMetrics = getAmountOfMetrics()
        for _, currentMetric in ipairs(metricsEnabled) do
            local textLeft = headerDimensions.left + borderPadding + headerLabelPadding
            local textBottom = metricChangeBottom + borderPadding + headerLabelPadding +
                (amountOfMetrics - distanceFromTop - 1) * headerDimensions.height
            font:Print(
                currentMetric.title,
                textLeft,
                textBottom,
                fontSize - headerLabelPadding * 2,
                'o'
            )
            distanceFromTop = distanceFromTop + 1
        end
    font:End()
end

local function deleteBackgroundShader()
    if WG['guishader'] then
        WG['guishader'].DeleteDlist('spectator_hud')
        backgroundShader = gl.DeleteList(backgroundShader)
    end
end

local function deleteSorting()
    gl.DeleteList(sortingBackgroundDisplayList)
end

local function deleteToggleVSMode()
    gl.DeleteList(toggleVSModeBackgroundDisplayList)
end

local function deleteStatsArea()
    gl.DeleteList(statsAreaBackgroundDisplayList)
end

local function deleteVSModeBackgroudDisplayLists()
    for _, vsModeBackgroundDisplayList in ipairs(vsModeBackgroundDisplayLists) do
        gl.DeleteList(vsModeBackgroundDisplayList)
    end
end

local function init()
    buildMetricsEnabled()
    local metricChosen = getMetricChosen()
    if metricChosen then
        headerLabel = metricChosen.title
    end

    if widgetConfig == constants.configLevel.basic then
        settings.statsUpdateFrequency = 30  -- once a second
        settings.useMovingAverage = false
    elseif widgetConfig == constants.configLevel.advanced then
        settings.statsUpdateFrequency = 6  -- 5 times a second
        settings.useMovingAverage = true 
        settings.movingAverageWindowSize = 4  -- approx 1 sec
    elseif widgetConfig == constants.configLevel.expert then
        settings.statsUpdateFrequency = 2  -- 15 times a second, same as engine slowUpdate
        settings.useMovingAverage = true 
        settings.movingAverageWindowSize = 16  -- approx 1 sec
    end

    viewScreenWidth, viewScreenHeight = Spring.GetViewGeometry()

    widgetDimensions = {}
    headerDimensions = {}

    calculateWidgetSize()
    setWidgetPosition()

    createBackgroundShader()
    updateHeaderTooltip()
    createSorting()
    updateSortingTooltip()
    createToggleVSMode()
    updateToggleVSModeTooltip()
    createStatsArea()
    createVSModeBackgroudDisplayLists()

    vsModeEnabled = getAmountOfAllyTeams() == 2
    if not vsModeEnabled then
        vsMode = false
    end

    if vsMode then
        updateVSModeTooltips()
    end

    buildUnitDefs()
    buildUnitCache()

    if not vsMode then
        createTeamStats()
    else
        createVSModeStats()
    end
    updateStats()
end

local function deInit()
    if WG['tooltip'] then
        for _, tooltipName in ipairs(tooltipNames) do
            WG['tooltip'].RemoveTooltip(tooltipName)
        end
    end

    deleteBackgroundShader()
    deleteHeaderTooltip()
    deleteSorting()
    deleteSortingTooltip()
    deleteToggleVSMode()
    deleteToggleVSModeTooltip()
    deleteStatsArea()
    deleteVSModeBackgroudDisplayLists()
end

local function reInit()
    deInit()

    font = WG['fonts'].getFont()

    init()
end

local function tearDownVSMode()
    deleteVSModeTooltips()
end

local function processPlayerCountChanged()
    reInit()
end

local function checkAndUpdateHaveFullView()
    local haveFullViewOld = haveFullView
    haveFullView = select(2, Spring.GetSpectatingState())
    return haveFullView ~= haveFullViewOld
end

function widget:Initialize()
    if widgetHandler:IsWidgetKnown("Ecostats") then
        widgetHandler:DisableWidget("Ecostats")
    end

    WG["spectator_hud"] = {}

    WG["spectator_hud"].getWidgetSize = function()
        return widgetScale
    end
    WG["spectator_hud"].setWidgetSize = function(value)
        widgetScale = value
        reInit()
    end

    WG["spectator_hud"].getConfig = function()
        return widgetConfig
    end
    WG["spectator_hud"].setConfig = function(value)
        widgetConfig = value
        reInit()
    end

    rectRound = WG.FlowUI.Draw.RectRound

    checkAndUpdateHaveFullView()

    font = WG['fonts'].getFont()

    buildPlayerData()

    init()
end

function widget:Shutdown()
    deInit()
end

function widget:TeamDied(teamID)
    checkAndUpdateHaveFullView()

    if haveFullView then
        processPlayerCountChanged()
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

local function isInDimensions(x, y, dimensions)
    return (x > dimensions["left"]) and (x < dimensions["right"]) and (y > dimensions["bottom"]) and (y < dimensions["top"])
end

function widget:MousePress(x, y, button)
    if isInDimensions(x, y, headerDimensions) and not metricChangeInProgress then
        metricChangeInProgress = true
        return
    end

    if metricChangeInProgress then
        if (x > headerDimensions.left) and (x < headerDimensions.right) and
                (y > metricChangeBottom) and (y < headerDimensions.top) then
            -- no change if user pressed header
            if (y < headerDimensions.bottom) then
                local metricID = getAmountOfMetrics() - mathfloor((y - metricChangeBottom) / headerDimensions.height)
                local metric = getMetricFromID(metricID)
                setMetricChosen(metric.key)
                if vsMode then
                    vsMode = false
                    tearDownVSMode()
                end
                reInit()
                updateStats()
            end
        end

        metricChangeInProgress = false
        return
    end

    if (x > sortingLeft) and (x < sortingRight) and (y > sortingBottom) and (y < sortingTop) then
        if sortingChosen == "player" then
            sortingChosen = "team"
        elseif sortingChosen == "team" then
            sortingChosen = "teamaggregate"
        elseif sortingChosen == "teamaggregate" then
            sortingChosen = "player"
        end
        -- we need to do full reinit because amount of rows to display has changed
        reInit()
        return
    end

    if vsModeEnabled then
        if (x > toggleVSModeLeft) and (x < toggleVSModeRight) and (y > toggleVSModeBottom) and (y < toggleVSModeTop) then
            vsMode = not vsMode
            if not vsMode then
                tearDownVSMode()
            end
            reInit()
            return
        end
    end
end

function widget:ViewResize()
    rectRound = WG.FlowUI.Draw.RectRound

    reInit()
end
             
function widget:GameFrame(frameNum)
    if not haveFullView then
        return
    end

    if (frameNum > 0) and (not teamOrder) then
        -- collect player start positions
        local teamStartXAverages = {}
        for _, allyID in ipairs(Spring.GetAllyTeamList()) do
            if allyID ~= gaiaAllyID then
                local xAccumulator = 0
                local teamList = Spring.GetTeamList(allyID)
                for _,teamID in ipairs(teamList) do
                    local x, _, _ = Spring.GetTeamStartPosition(teamID)
                    xAccumulator = xAccumulator + x
                end
                local xAverage = xAccumulator / #teamList
                table.insert(teamStartXAverages, { allyID, xAverage })
            end
        end

        -- sort averages and create team order (from left to right)
        table.sort(teamStartXAverages, function (left, right)
            return left[2] < right[2]
        end)
        teamOrder = {}
        for i,teamStartX in ipairs(teamStartXAverages) do
            teamOrder[i] = teamStartX[1]
        end
    end

    if frameNum % settings.statsUpdateFrequency == 1 then
        updateStats()
    end
end

function widget:Update(dt)
    local haveFullViewOld = haveFullView
    haveFullView = select(2, Spring.GetSpectatingState())
    if haveFullView ~= haveFullViewOld then
        if haveFullView then
            init()
            return
        else
            deInit()
            return
        end
    end
end

function widget:DrawScreen()
    if not haveFullView then
        return
    end

    gl.PushMatrix()
        drawHeader()

        gl.CallList(sortingBackgroundDisplayList)
        drawSorting()

        gl.CallList(toggleVSModeBackgroundDisplayList)
        drawToggleVSMode()

        if not vsMode then
            gl.CallList(statsAreaBackgroundDisplayList)
            drawStatsBars()
        else
            for _, vsModeBackgroundDisplayList in ipairs(vsModeBackgroundDisplayLists) do
                gl.CallList(vsModeBackgroundDisplayList)
            end

            drawVSModeMetrics()
        end

        if metricChangeInProgress then
            drawMetricChange()
        end
    gl.PopMatrix()
end

function widget:GetConfigData()
    local result = {
        widgetScale = widgetScale,
        widgetConfig = widgetConfig,
    }

    return result
end

function widget:SetConfigData(data)
    if data.widgetScale then
        widgetScale = data.widgetScale
    end
    if data.widgetConfig then
        widgetConfig = data.widgetConfig
    end
end
