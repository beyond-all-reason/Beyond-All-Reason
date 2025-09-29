local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "TeamStats",
		desc      = "Shows game stats.",
		author    = "",
		version   = "",
		date      = "",
		license   = "",
		layer     = -99990,
		enabled   = true,
	}
end

local vsx,vsy = Spring.GetViewGeometry()

local fontSize = 22		-- is caclulated somewhere else anyway
local fontSizePercentage = 0.6 -- fontSize * X = actual fontsize
local update = 30 -- in frames
local replaceEndStats = false
local highLightColour = {1,1,1,0.1}
local sortHighLightColour = {1,0.87,0.87,0.22}
local sortHighLightColourDesc = {0.9,1,0.9,0.22}
local activeSortColour = {1,0.62,0.62,0.22}
local activeSortColourDesc = {0.66,1,0.66,0.22}
local oddLineColour = {0.28,0.28,0.28,0.06}
local evenLineColour = {1,1,1,0.06}
local sortLineColour = {0.82,0.82,0.82,0.1}

local widgetScale = (vsy / 1080)
local math_isInRect = math.isInRect

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local lineHeight = fontSize

local isFFA = Spring.Utilities.Gametype.IsFFA()

local header = {
	"frame",
	"damageDealt",
	"damageReceived",
	"unitsProduced",
	"unitsKilled",
	"unitsDied",
	"damageEfficiency",
	"metalProduced",
	"metalExcess",
	"energyProduced",
	"energyExcess",
	"aggressionLevel",
	"actionsPerMinute",
}

local headerRemap = {}	-- filled in initialize

local aspectMult = vsx / vsy
local guiData = {
	mainPanel = {
		relSizes = {
			x = {
				min = 0.1 + ((0.08*aspectMult)),
				max = 0.9 - ((0.08*aspectMult)),
				length = 0.49,
			},
			y = {
				min = 0.22,
				max = 0.76,
				length = 0.6,
			},
		},
		draggingBorderSize = 7,
		visible = false,
	},
}
guiData.mainPanel.relSizes.x.length = (guiData.mainPanel.relSizes.x.max - guiData.mainPanel.relSizes.x.min) * 0.92

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)

local glColor	= gl.Color
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local GetGaiaTeamID			= Spring.GetGaiaTeamID
local GetAllyTeamList		= Spring.GetAllyTeamList
local GetTeamList			= Spring.GetTeamList
local GetTeamStatsHistory	= Spring.GetTeamStatsHistory
local GetTeamInfo			= Spring.GetTeamInfo
local GetPlayerInfo			= Spring.GetPlayerInfo
local GetMouseState			= Spring.GetMouseState
local GetGameFrame			= Spring.GetGameFrame
local min					= math.min
local max					= math.max
local clamp					= math.clamp
local floor					= math.floor
local huge					= math.huge
local sort					= table.sort
local log10					= math.log10
local round					= math.round
local char					= string.char
local borderRemap = {left={"x","min",-1},right={"x","max",1},top={"y","max",1},bottom={"y","min",-1}}

local RectRound, UiElement, elementCorner

local font, font2, backgroundGuishader, gameStarted, bgpadding, gameover

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local isSpec = Spring.GetSpectatingState()


local playerScale = math.clamp(25 / #Spring.GetTeamList(), 0.3, 1)

function aboveRectangle(mousePos,boxData)
	local included = true
	for coordName, coordData in pairs(boxData.absSizes) do
		included = included and mousePos[coordName] >= coordData.min and mousePos[coordName] <= coordData.max
	end
	return included
end

function isAbove(mousePos,guiData)
	for boxType, boxData in pairs(guiData) do
		if boxData.visible then
			local mask = {}
			local border = false
			if aboveRectangle(mousePos,boxData) then
				local draggingBorderSize = boxData.draggingBorderSize
				for borderName, borderData in pairs(borderRemap) do
					local coordName = borderRemap[borderName][1]
					local coordDir = borderRemap[borderName][2]
					local dir = borderRemap[borderName][3]
					if coordDir == "min" then
						mask[borderName] = mousePos[coordName] < (boxData.absSizes[coordName][coordDir]+ draggingBorderSize*-1*dir)
					else
						mask[borderName] = mousePos[coordName] > (boxData.absSizes[coordName][coordDir]+ draggingBorderSize*-1*dir)
					end
					border = border or mask[borderName]
				end
				return boxType, border, mask
			end
		end
	end
end

function colorToChar(colorarray)
	return char(255,clamp(floor(colorarray[1]*255), 1, 255) ,clamp(floor(colorarray[2]*255), 1, 255) ,clamp(floor(colorarray[3]*255), 1, 255))
end

local teamData={}
local maxColumnTextSize = 0
local columnSize = 0
local prevNumLines = 0
local selectedLine
local selectedColumn
local textDisplayList
local backgroundDisplayList
local teamControllers = {}
local mousex,mousey = 0,0
local sortVar = "damageDealt"
local sortAscending = false
local numColums = #header


function widget:SetConfigData(data)
	--guiData = data.guiData or guiData -- buggy positioning, so disabled this
	sortVar = data.sortVar or sortVar
	sortAscending = data.sortAscending or sortAscending
end

function widget:GetConfigData(data)
	return{
		guiData = guiData,
		sortVar = sortVar,
		sortAscending = sortAscending,
	}
end


function calcAbsSizes()
	guiData.mainPanel.absSizes = {
		x = {
			min = (guiData.mainPanel.relSizes.x.min * vsx),
			max = (guiData.mainPanel.relSizes.x.max * vsx),
			length = (guiData.mainPanel.relSizes.x.length * vsx),
		},
		y = {
			min = (guiData.mainPanel.relSizes.y.min * vsy),
			max = (guiData.mainPanel.relSizes.y.max * vsy),
			length = (guiData.mainPanel.relSizes.y.length * vsy),
		}
	}
end

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = (vsy / 1080)

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)
	for _, data in pairs(headerRemap) do
		maxColumnTextSize = max(font:GetTextWidth(data[2]), max(font:GetTextWidth(data[1]), maxColumnTextSize))
	end

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	calcAbsSizes()
	updateFontSize()
	widget:GameFrame(GetGameFrame(),true)
end

local function refreshHeaders()
	headerRemap = {
		frame = {" ", Spring.I18N('ui.teamStats.player')},
		metalProduced = {Spring.I18N('ui.teamStats.metal'), Spring.I18N('ui.teamStats.resourceProduced')},
		metalExcess = {Spring.I18N('ui.teamStats.metal'), Spring.I18N('ui.teamStats.resourceExcess')},
		energyProduced = {Spring.I18N('ui.teamStats.energy'), Spring.I18N('ui.teamStats.resourceProduced')},
		energyExcess = {Spring.I18N('ui.teamStats.energy'), Spring.I18N('ui.teamStats.resourceExcess')},
		damageDealt = {Spring.I18N('ui.teamStats.damage'), Spring.I18N('ui.teamStats.damageDealt')},
		damageReceived = {Spring.I18N('ui.teamStats.damage'), Spring.I18N('ui.teamStats.damageReceived')},
		damageEfficiency = {Spring.I18N('ui.teamStats.damage'), Spring.I18N('ui.teamStats.damageEfficiency')},
		unitsProduced = {Spring.I18N('ui.teamStats.units'), Spring.I18N('ui.teamStats.unitsProduced')},
		unitsDied = {Spring.I18N('ui.teamStats.units'), Spring.I18N('ui.teamStats.unitsDied')},
		unitsKilled = {Spring.I18N('ui.teamStats.units'), Spring.I18N('ui.teamStats.unitsKilled')},
		aggressionLevel = {Spring.I18N('ui.teamStats.aggression'), Spring.I18N('ui.teamStats.aggressionLevel')},
		actionsPerMinute = {Spring.I18N('ui.teamStats.actionsPerMinute1'), Spring.I18N('ui.teamStats.actionsPerMinute2')},
	}
end

local function closeHandler()
	if guiData.mainPanel.visible then
		guiData.mainPanel.visible = false

		return true
	end
end

function widget:Initialize()
	widgetHandler:AddAction("teamstatus_close", closeHandler, nil, "p")

	refreshHeaders()
	guiData.mainPanel.visible = false
	widget:ViewResize()
	local _,_, paused = Spring.GetGameSpeed()
	if paused then
		widget:GameFrame(GetGameFrame(),true)
	end

	WG['teamstats'] = {}
	WG['teamstats'].toggle = function(state)
		if state ~= nil then
			guiData.mainPanel.visible = state
		else
			guiData.mainPanel.visible = not guiData.mainPanel.visible
		end
		if guiData.mainPanel.visible then
			widget:GameFrame(GetGameFrame(),true)
		end
	end
	WG['teamstats'].isvisible = function()
		return guiData.mainPanel.visible
	end
end

function widget:Shutdown()
	glDeleteList(textDisplayList)
	glDeleteList(backgroundDisplayList)
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('teamstats_window')
	end
	if backgroundGuishader ~= nil then
		glDeleteList(backgroundGuishader)
	end
end

function compareAllyTeams(a,b)
	if sortAscending then
		return a[#a][sortVar] < b[#b][sortVar]
	else
		return a[#a][sortVar] > b[#b][sortVar]
	end
end

function compareTeams(a,b)
	if sortAscending then
		return a[sortVar] < b[sortVar]
	else
		return a[sortVar] > b[sortVar]
	end
end

function widget:PlayerChanged()
	isSpec = Spring.GetSpectatingState()
	widget:GameFrame(GetGameFrame(),true)
end

function widget:GameFrame(n,forceupdate)
	if n > 0 and not gameStarted then
		gameStarted = true
		forceupdate = true
	end

	if gameover then return end

	if not forceupdate and (not guiData.mainPanel.visible or n%update ~= 0) then
		return
	end
	teamData = {}
	local totalNumLines = 2
	local allyInsertCount = 1
	for _,allyTeamID in ipairs(GetAllyTeamList()) do
		local allyVec = {}
		local allyTotal = {}
		local teamInsertCount = 1
		local teamAPM = WG.teamAPM or {}
		for _,teamID in ipairs(GetTeamList(allyTeamID)) do
			if teamID ~= GetGaiaTeamID() then
				local range = GetTeamStatsHistory(teamID)
				local history = GetTeamStatsHistory(teamID,range)
				if history then
					history = history[#history]
					history.resourcesProduced = history.metalProduced + history.energyProduced/60
					history.resourcesUsed = history.metalUsed + history.energyUsed/60
					history.resourcesExcess = history.metalExcess + history.energyExcess/60
					history.resourcesSent = history.metalSent + history.energySent/60
					history.resourcesReceived = history.metalReceived + history.energyReceived/60
					history.actionsPerMinute = teamAPM[teamID] or 0
					for varName,value in pairs(history) do
						allyTotal[varName] = (allyTotal[varName] or 0 ) + value
					end
					history.time = nil
					local teamColor
					if not isSpec and anonymousMode ~= "disabled" and teamID ~= Spring.GetLocalTeamID() then
						teamColor = { anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3] }
					else
						teamColor = { Spring.GetTeamColor(teamID) }
					end
					local _,leader,isDead = GetTeamInfo(teamID,false)
					local playerName,isActive = GetPlayerInfo(leader,false)
					playerName = (WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(leader) or playerName
					if Spring.GetGameRulesParam('ainame_'..teamID) then
						playerName = Spring.GetGameRulesParam('ainame_'..teamID)
					end
					if gameStarted ~= nil then
						if not playerName then
							playerName = teamControllers[teamID] or Spring.I18N('ui.teamStats.gone', { player = '' })
						else
							teamControllers[teamID] = playerName
						end
						if isDead then
							playerName = Spring.I18N('ui.teamStats.dead', { player = playerName })
						elseif not isActive then
							playerName = Spring.I18N('ui.teamStats.gone', { player = playerName })
						end
					end
					if history.damageReceived ~= 0 then
						history.damageEfficiency = (history.damageDealt/history.damageReceived)*100
					else
						history.damageEfficiency = huge
					end
					local totalRes = history.resourcesProduced + history.resourcesReceived
					if totalRes ~= 0 and history.damageDealt ~= 0 then
						history.aggressionLevel = round(10*log10(history.damageDealt/totalRes))
					else
						history.aggressionLevel = -huge
					end
					if history.unitsDied ~= 0 then
						history.killEfficiency = (history.unitsKilled/history.unitsDied)*100
					else
						history.killEfficiency = huge
					end

					playerName = playerName or ''

					history.frame = colorToChar(teamColor) .. playerName..'    '

					allyVec[teamInsertCount] = history
					totalNumLines = totalNumLines + 1
					teamInsertCount = teamInsertCount + 1
				end
			end
		end
		if teamInsertCount ~= 1 then
			sort(allyVec,compareTeams)
			if teamInsertCount > 2 then
				allyTotal.frame = "      "
				allyTotal.time = nil
				if allyTotal.damageReceived ~= 0 then
					allyTotal.damageEfficiency = (allyTotal.damageDealt/allyTotal.damageReceived)*100
				else
					allyTotal.damageEfficiency = huge
				end
				local totalRes = allyTotal.resourcesProduced + allyTotal.resourcesReceived
				if totalRes ~= 0 and allyTotal.damageDealt ~= 0 then
					allyTotal.aggressionLevel = round(10*log10(allyTotal.damageDealt/totalRes))
				else
					allyTotal.aggressionLevel = -huge
				end
				if allyTotal.unitsDied ~= 0 then
					allyTotal.killEfficiency = (allyTotal.unitsKilled/allyTotal.unitsDied)*100
				else
					allyTotal.killEfficiency = huge
				end
				totalNumLines = totalNumLines + 1
				allyVec[teamInsertCount] = allyTotal
			end
			teamData[allyInsertCount] = allyVec
			if not isFFA then
				totalNumLines = totalNumLines + 1
			end
			allyInsertCount = allyInsertCount + 1
		end
	end
	totalNumLines = totalNumLines + 1
	sort(teamData,compareAllyTeams)
	guiData.mainPanel.absSizes.y.min = guiData.mainPanel.absSizes.y.max - totalNumLines*lineHeight
	prevNumLines = totalNumLines
	glDeleteList(textDisplayList)
	textDisplayList = glCreateList(ReGenerateTextDisplayList)
	glDeleteList(backgroundDisplayList)
	backgroundDisplayList = glCreateList(ReGenerateBackgroundDisplayList)
end


function widget:GameOver()
	gameover = true
	if replaceEndStats then
		guiData.mainPanel.visible = true
		widget:GameFrame(GetGameFrame(),true)
		Spring.SendCommands("endgraph 0")
	end
end

function widget:MousePress(mx,my,button)
	if not guiData.mainPanel.visible then
		return
	end
	return mouseEvent(mx,my,button)
end

function widget:MouseRelease(mx,my,button)
	if not guiData.mainPanel.visible then
		return
	end
	return mouseEvent(mx,my,button,true)
end

function mouseEvent(mx,my,button,release)
	local boxType = isAbove({x=mx,y=my},guiData)
	if not boxType and guiData.mainPanel.visible then
	  	if release then
			guiData.mainPanel.visible = false
			return false
		end
		return true
	end
	if boxType == "mainPanel" then
		if release then
			local line, column = getLineAndColumn(mx,my)
			if line <= 3 then -- header
				local newSort = header[column]
				if newSort then
					if playSounds then
						Spring.PlaySoundFile(buttonclick, 0.6, 'ui')
					end
					if sortVar == newSort then
						sortAscending = not sortAscending
					end
					sortVar = newSort
					widget:GameFrame(GetGameFrame(),true)
				end
			end
		end
		return true
	end
end


function getLineAndColumn(x,y)
	local relativex = x - guiData.mainPanel.absSizes.x.min - columnSize/2
	local relativey = guiData.mainPanel.absSizes.y.max - y
	local line = floor(relativey/lineHeight) +1
	local column = floor(relativex/columnSize) +1
	return line,column
end


function updateFontSize()
	columnSize = guiData.mainPanel.absSizes.x.length / numColums
	local fakeColumnSize = guiData.mainPanel.absSizes.x.length / (numColums-1)
	fontSize = 11*widgetScale + floor(fakeColumnSize/maxColumnTextSize)
	fontSize = fontSize * playerScale
	lineHeight = fontSize
	fontSize = fontSize + math.min(fontSize * 0.5, (fontSize * ((1-playerScale)*0.7)))
end

function widget:MouseMove(mx,my,dx,dy)
	if not guiData.mainPanel.visible then
		return
	end
	local boxType = isAbove({x=mx,y=my},guiData)
	local newLine,newColumn
	if boxType == "mainPanel" then
		newLine,newColumn = getLineAndColumn(mx,my)
	end
	if selectedLine ~= newLine or selectedColumn ~= newColumn then
		selectedLine, selectedColumn = newLine, newColumn
		glDeleteList(backgroundDisplayList)
		backgroundDisplayList = glCreateList(ReGenerateBackgroundDisplayList)
	end
end

function widget:Update(dt)
	local x,y = GetMouseState()
	if x ~= mousex or y ~= mousey then
		widget:MouseMove(x,y,x-mousex,y-mousey)
	end
	mousex,mousey = x,y
end

local function DrawBackground()
	if not guiData.mainPanel.visible then
		return
	end

	gl.Color(0,0,0,WG['guishader'] and 0.8 or 0.85)
	local x1,y1,x2,y2 = math.floor(guiData.mainPanel.absSizes.x.min), math.floor(guiData.mainPanel.absSizes.y.min), math.floor(guiData.mainPanel.absSizes.x.max), math.floor(guiData.mainPanel.absSizes.y.max)
	UiElement(x1-bgpadding,y1-bgpadding,x2+bgpadding,y2+bgpadding, 1, 1, 1, 1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	if WG['guishader'] then
		if backgroundGuishader ~= nil then
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = glCreateList( function()
			RectRound(x1-bgpadding,y1-bgpadding,x2+bgpadding,y2+bgpadding, elementCorner)
		end)
		WG['guishader'].InsertDlist(backgroundGuishader,'teamstats_window')
	end

	if backgroundDisplayList then
		glCallList(backgroundDisplayList)
	end
end

local function DrawAllStats()
	if not guiData.mainPanel.visible then
		return
	end
	if textDisplayList then
		glCallList(textDisplayList)
	end
end

function widget:DrawScreen()
	if not guiData.mainPanel.visible then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('teamstats_window')
		end
		return
	end

	DrawBackground()
	DrawAllStats()

	local mx, my = Spring.GetMouseState()
	local x1,y1,x2,y2 = math.floor(guiData.mainPanel.absSizes.x.min), math.floor(guiData.mainPanel.absSizes.y.min), math.floor(guiData.mainPanel.absSizes.x.max), math.floor(guiData.mainPanel.absSizes.y.max)
	if math_isInRect(mx, my, x1,y1,x2,y2) then
		Spring.SetMouseCursor('cursornormal')
	end
end

function ReGenerateBackgroundDisplayList()
	gl.Texture(false)	-- some other widget left it on
	local boxSizes = guiData.mainPanel.absSizes
	for lineCount=1,prevNumLines do
		local colour = evenLineColour
		if lineCount == 1 or  lineCount == 2 then
			colour = sortLineColour
		end
		if lineCount > 2 and (lineCount+1)%2 == 0 then
			colour = oddLineColour
		end
		if lineCount == selectedLine and selectedLine > 3 then
			--colour = highLightColour
		end
		glColor(colour)
		if evenLineColour and lineCount > 2 then
			local bottomCorner = 0
			if math.floor(boxSizes.x.min) >= guiData.mainPanel.absSizes.y.min then
				bottomCorner = 1
			end
			RectRound(math.floor(boxSizes.x.min), math.floor(boxSizes.y.max -lineCount*lineHeight), math.floor(boxSizes.x.max), math.floor(boxSizes.y.max -(lineCount-1)*lineHeight), bgpadding, 0,0,bottomCorner,bottomCorner, {colour[1],colour[2],colour[3],colour[4]*ui_opacity}, {colour[1],colour[2],colour[3],colour[4]*3*ui_opacity})
		elseif lineCount == 1 then
			--RectRound(boxSizes.x.min, boxSizes.y.max -(lineCount+1)*lineHeight, boxSizes.x.max, boxSizes.y.max -(lineCount-1)*lineHeight, 3*widgetScale)
		end
	end
	if selectedLine and selectedLine < 3 and selectedColumn and selectedColumn > 0 and selectedColumn <= numColums then
		if sortAscending then
			glColor(sortHighLightColour[1], sortHighLightColour[2], sortHighLightColour[3], sortHighLightColour[4]*ui_opacity)
		else
			glColor(sortHighLightColourDesc[1], sortHighLightColourDesc[2], sortHighLightColourDesc[3], sortHighLightColourDesc[4]*ui_opacity)
		end
		RectRound(math.floor(boxSizes.x.min +(selectedColumn)*columnSize-columnSize/2), math.floor(boxSizes.y.max -2*lineHeight), math.floor(boxSizes.x.min +(selectedColumn+1)*columnSize-columnSize/2), math.floor(boxSizes.y.max), bgpadding, 0,0,1,1)
	end
	for selectedIndex, headerName in ipairs(header) do
		if sortVar == headerName then
			if sortAscending then
				glColor(activeSortColour[1], activeSortColour[2], activeSortColour[3], activeSortColour[4]*ui_opacity)
			else
				glColor(activeSortColourDesc[1], activeSortColourDesc[2], activeSortColourDesc[3], activeSortColourDesc[4]*ui_opacity)
			end
			RectRound(math.floor(boxSizes.x.min +(selectedIndex)*columnSize-columnSize/2), math.floor(boxSizes.y.max -2*lineHeight), math.floor(boxSizes.x.min +(selectedIndex+1)*columnSize-columnSize/2), math.floor(boxSizes.y.max), bgpadding, 0,0,1,1)
			break
		end
	end
end

function ReGenerateTextDisplayList()
	local lineCount = 1
	local boxSizes = guiData.mainPanel.absSizes
	local baseXSize = boxSizes.x.min + columnSize
	local baseYSize = boxSizes.y.max - (0.002*vsy) -- small align adjustment so text is in the middle of a row

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
		--print the header
		local colCount = 0
		local heightCorrection = lineHeight*((1-fontSizePercentage)/2)

		for _, headerName in ipairs(header) do
			font:Print(headerRemap[headerName][1], baseXSize + columnSize*colCount, baseYSize+heightCorrection-lineCount*lineHeight, (fontSize*fontSizePercentage), "dco")
			font:Print(headerRemap[headerName][2], baseXSize + columnSize*colCount, baseYSize+heightCorrection-(lineCount+1)*lineHeight, (fontSize*fontSizePercentage), "dco")
			colCount = colCount + 1
		end
		lineCount = lineCount + 3

		for _, allyTeamData in ipairs(teamData) do
			for _, teamData in ipairs(allyTeamData) do
				local colCount = 0
				for i, varName in ipairs(header) do
					local value = teamData[varName]
					if value == huge or value == -huge then
						value = "-"
					elseif tonumber(value) then
						local v = tonumber(value)
						if varName:sub(1,5) ~= "units" and varName ~= "aggressionLevel" then
							if v and math.abs(v) < 1 then
								v = 0
							end
						end
						value = string.formatSI(v)
					end
					if varName == "damageEfficiency" or varName == "killEfficiency" then
						value = value .. "%"
					end
					local color = ''
					if teamData.frame == "      "  then
						color = '\255\255\220\130'
					elseif lineCount % 2 == 1 then
						color = '\255\200\200\200'
					end
					if i == 1 then
						font2:Begin()
						font2:Print(color..value, baseXSize + columnSize*colCount, baseYSize+(heightCorrection*1.66)-lineCount*lineHeight, (fontSize*fontSizePercentage), "dco")
						font2:End()
					else
						font:Print(color..value, baseXSize + columnSize*colCount, baseYSize+heightCorrection-lineCount*lineHeight, (fontSize*fontSizePercentage), "dco")
					end
					colCount = colCount + 1
				end
				lineCount = lineCount + 1
			end
			if not isFFA then
				lineCount = lineCount + 1 -- add line break after end of allyteam
			end
		end
	font:End()
end

function widget:LanguageChanged()
	refreshHeaders()
	widget:ViewResize()
end
