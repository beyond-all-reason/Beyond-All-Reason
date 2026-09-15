local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Spectating Stats",
		desc = "",
		author = "Floris",
		date = "April 2023",
		license = "",
		layer = 0,
		enabled = false,
	}
end

local vsx, vsy = Spring.GetViewGeometry()
local spGetUnitDefID = Spring.GetUnitDefID
local spIsGUIHidden = Spring.IsGUIHidden
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glTranslate = gl.Translate
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local ceil = math.ceil
local subString = string.sub
local flowUIDrawElement
local exo2Font
local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer()

local updateIntervalSeconds = 1.5
local titles = {"Units", "Army", "(DPS)", "Defenses", "(DPS)", "Builders", "(BP)"}
local numColumns = #titles
local columnWidths = {}
local titleFontSize = 17
local statsFontSize = 16
local titleFontHeight = 0
local statsFontHeight = 0
local titleColor = {1, 1, 1, 1}--White
local verticalPadding = 9
local horizontalPadding = 9
local columnGap = 8
local titleRowMarginBottom = 12
local statsRowMarginBottom = 4

local allyTeams = {}
local numAllyTeams = 0
-- average color of all member teams
local allyTeamColors = {}
local lastUpdate = os.clock() - 10
local displayList
-- bottom left corner
local posX, posY = vsx*0.72, vsy*0.68
local sizeX, sizeY = 0, 0
-- whether the user is holding mouse down on the UI box
local mouseDepressed = false

local weaponShowGroups = { ["0"] = true, ["1"] = true }
local weaponHideRoles = { secondary = true }

local function isFakeWeapon(weaponDef)
	return weaponDef.customParams.bogus == "1"
end

local function isDisplayWeapon(weaponDef)
	return weaponShowGroups[weaponDef.customParams.weapons_group]
		and not weaponHideRoles[weaponDef.customParams.weapons_role or ""]
end

local function isSmartSubweapon(weaponDef, unitDef)
	return unitDef.customParams.weapons_smart_select ~= nil
		and (weaponDef.customParams.smart_backup or weaponDef.customParams.smart_trajectory_checker)
end

local function displayWeaponDPS(weaponDef, unitDef)
	return not isFakeWeapon(weaponDef)
		and isDisplayWeapon(weaponDef)
		and not isSmartSubweapon(weaponDef, unitDef)
end

local unitdefMobileDps = {}
local unitdefStaticDps = {}
local unitdefBuildSpeed = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local totalDps = 0
	local weapons = unitDef.weapons
	if #weapons > 0 then
		for i = 1, #weapons do
			local weaponDef = WeaponDefs[weapons[i].weaponDef]
			if displayWeaponDPS(weaponDef, unitDef) then
				local maxDmg = 0
				for _, v in pairs(weaponDef.damages) do
					if v > maxDmg then
						maxDmg = v
					end
				end
				local dps = math.floor(maxDmg * weaponDef.salvoSize / weaponDef.reload)
				totalDps = totalDps + dps
			end
		end
		if totalDps > 0 then
			if unitDef.isBuilding then
				unitdefStaticDps[unitDefID] = totalDps
			else
				unitdefMobileDps[unitDefID] = totalDps
			end
		end
	end
	if unitDef.buildSpeed > 0 then
		unitdefBuildSpeed[unitDefID] = unitDef.buildSpeed
	end
end

function widget:Initialize()
	
	if not Spring.GetSpectatingState() and not isSinglePlayer then
		widgetHandler:RemoveWidget()
	end
	
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
	end
	
	for _, allyTeamId in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamId ~= gaiaAllyTeamID then
			allyTeams[#allyTeams+1] = allyTeamId
			numAllyTeams = numAllyTeams + 1
			
			local red, green, blue = 0, 0, 0
			local numTeamsOnAllyTeam = 0
			
			for _, teamId in ipairs(Spring.GetTeamList(allyTeamId)) do
				-- color average computed using squares (https://youtu.be/LKnqECcg6Gw)
				local teamRed, teamGreen, teamBlue = Spring.GetTeamColor(teamId)
				red = red + teamRed ^ 2
				green = green + teamGreen ^ 2
				blue = blue + teamBlue ^ 2
				numTeamsOnAllyTeam = numTeamsOnAllyTeam + 1
			end
			
			-- r g b a = 1 2 3 4
			local averageColor = {math.sqrt(red/numTeamsOnAllyTeam), math.sqrt(green/numTeamsOnAllyTeam), math.sqrt(blue/numTeamsOnAllyTeam), 1}
			allyTeamColors[allyTeamId] = averageColor
		end
	end
	
	vsx, vsy = Spring.GetViewGeometry()
	widget:ViewResize(vsx, vsy)
	
	statsFontHeight = exo2Font:GetTextHeight("0.00Q") * statsFontSize
	local maxStatWidth = exo2Font:GetTextWidth("0.00M") * statsFontSize
	for i = 1, numColumns do
		local title = titles[i]
		local titleWidth = exo2Font:GetTextWidth(title) * titleFontSize
		columnWidths[i] = math.max(titleWidth, maxStatWidth)
		titleFontHeight = math.max(exo2Font:GetTextHeight(title) * titleFontSize, titleFontHeight)
	end
	
end

function widget:ViewResize(vs_x, vs_y)
	vsx = vs_x
	vsy = vs_y
	flowUIDrawElement = WG.FlowUI.Draw.Element
	exo2Font = WG.fonts.getFont("fonts/Exo2-SemiBold.otf")
end

local function getAllyTeamStats(allyTeamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	local unitCount = 0
	local armyCount = 0
	local armyDps = 0
	local defenseCount = 0
	local defenseDps = 0
	local builders = 0
	local buildSpeed = 0
	for i, teamID in ipairs(teamList) do
		local units = Spring.GetTeamUnits(teamID)
		unitCount = unitCount + #units
		for _, unitID in ipairs(units) do
			local unitDefID = spGetUnitDefID(unitID)
			if unitdefMobileDps[unitDefID] then
				armyCount = armyCount + 1
				armyDps = armyDps + unitdefMobileDps[unitDefID]
			elseif unitdefStaticDps[unitDefID] then
				defenseCount = defenseCount + 1
				defenseDps = defenseDps + unitdefStaticDps[unitDefID]
			end
			if unitdefBuildSpeed[unitDefID] then
				builders = builders + 1
				buildSpeed = buildSpeed + unitdefBuildSpeed[unitDefID]
			end
		end
	end
	return unitCount, armyCount, armyDps, defenseCount, defenseDps, builders, buildSpeed
end

local scaleSuffixes = {"", "K", "M", "B", "T", "q", "Q", "s", "S", "O", "N"}
local function formatNumber(number)
	local i = 1
	while number >= 1000 do
		number = number / 1000
		i = i + 1
	end
	local endIndex = number >= 100 and 3 or 4
	return subString(tostring(number), 1, endIndex) .. (scaleSuffixes[i] or "-")
end

local function buildDisplayList()
	
	local scale = Spring.GetConfigFloat("ui_scale", 1)
	local scaledTitleFontHeight = ceil(titleFontHeight * scale)
	local scaledStatsFontHeight = ceil(statsFontHeight * scale)
	local scaledHorizontalPadding = ceil(horizontalPadding * scale)
	local scaledVerticalPadding = ceil(verticalPadding * scale)
	local scaledColumnGap = ceil(columnGap * scale)
	local scaledTitleRowMarginBottom = ceil(titleRowMarginBottom * scale)
	local scaledStatsRowMarginBottom = ceil(statsRowMarginBottom * scale)
	local scaledColumnWidths = {}
	local scaledTotalWidth = 0
	for i = 1, numColumns, 1 do
		local scaledColumnWidth = ceil(columnWidths[i] * scale)
		scaledColumnWidths[i] = scaledColumnWidth
		scaledTotalWidth = scaledTotalWidth + scaledColumnWidth
	end
	scaledTotalWidth = scaledTotalWidth + (2 * scaledHorizontalPadding) + (scaledColumnGap * (numColumns - 1))
	local scaledTotalHeight = (2 * scaledVerticalPadding) + scaledTitleFontHeight + scaledTitleRowMarginBottom +
						((scaledStatsFontHeight + scaledStatsRowMarginBottom) * numAllyTeams) - scaledStatsRowMarginBottom
	
	sizeX = scaledTotalWidth
	sizeY = scaledTotalHeight
	
	glDeleteList(displayList)
	displayList = glCreateList(function ()
		
		flowUIDrawElement(1e-6, 1e-6, scaledTotalWidth, scaledTotalHeight)
		
		local yBaseline = scaledVerticalPadding
		for i = 1, numAllyTeams do
			local allyTeamID = allyTeams[i]
			local allyTeamColor = allyTeamColors[allyTeamID]
			exo2Font:SetTextColor(allyTeamColor)
			local allyTeamStats = {getAllyTeamStats(allyTeamID)}
			
			local xRight = scaledTotalWidth - scaledHorizontalPadding
			for j = numColumns, 1, -1 do
				exo2Font:Print(formatNumber(allyTeamStats[j]), xRight, yBaseline, scaledStatsFontHeight, "xro")
				xRight = xRight - scaledColumnWidths[j] - scaledColumnGap
			end
			
			yBaseline = yBaseline + scaledStatsRowMarginBottom + statsFontSize
		end
		
		exo2Font:SetTextColor(titleColor)
		--yBaseline = yBaseline + scaledTitleRowMarginBottom - scaledStatsRowMarginBottom
		yBaseline = scaledTotalHeight - scaledVerticalPadding - scaledTitleFontHeight
		local xRight = scaledTotalWidth - scaledHorizontalPadding
		for i = numColumns, 1, -1 do
			exo2Font:Print(titles[i], xRight, yBaseline, scaledTitleFontHeight, "xro")
			xRight = xRight - scaledColumnWidths[i] - scaledColumnGap
		end
		
	end)
end

function widget:DrawScreen()
	if spIsGUIHidden() then
		return
	end
	if lastUpdate + updateIntervalSeconds < os.clock() then
		lastUpdate = os.clock()
		buildDisplayList()
	end
	glPushMatrix()
	glTranslate(posX, posY, 0)
	glCallList(displayList)
	glPopMatrix()
end

function widget:MousePress(x, y, button)
	if button ~= 1 then
		return false
	end
	x = x - posX
	y = y - posY
	if x >= 0 and x <= sizeX and y >= 0 and y <= sizeY then
		mouseDepressed = true
		return true
	end
	return false
end

function widget:MouseRelease(x, y, button)
	mouseDepressed = false
	return false
end

function widget:MouseMove(x, y, dx, dy, button)
	if mouseDepressed then
		posX = posX + dx
		posY = posY + dy
	end
end