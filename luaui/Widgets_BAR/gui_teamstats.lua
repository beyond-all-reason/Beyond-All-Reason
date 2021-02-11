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
local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)

local fontSize = 22		-- is caclulated somewhere else anyway
local fontSizePercentage = 0.6 -- fontSize * X = actual fontsize
local update = 30 -- in frames
local replaceEndStats = false
local highLightColour = {1,1,1,0.7}
local sortHighLightColour = {1,0.87,0.87,1}
local sortHighLightColourDesc = {0.9,1,0.9,1}
local activeSortColour = {1,0.62,0.62,1}
local activeSortColourDesc = {0.66,1,0.66,1}
local oddLineColour = {0.23,0.23,0.23,0.4}
local evenLineColour = {0.8,0.8,0.8,0.4}
local sortLineColour = {0.82,0.82,0.82,0.85}

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	player = 'Player',
	dead = 'dead',
	gone = 'gone',
	damagedealt1 = 'Damage',
	damagedealt2 = 'Dealt',
	damagereceived1 = 'Damage',
	damagereceived2 = 'Received',
	unitsproduced1 = 'Units',
	unitsproduced2 = 'Produced',
	unitskilled1 = 'Units',
	unitskilled2 = 'Killed',
	unitsdied1 = 'Units',
	unitsdied2 = 'Died',
	damageefficiency1 = 'Damage',
	damageefficiency2 = 'Efficiency',
	aggressionlevel1 = 'Aggression',
	aggressionlevel2 = 'Level',
	metalproduced1 = 'Metal',
	metalproduced2 = 'Produced',
	metalexcess1 = 'Metal',
	metalexcess2 = 'Excess',
	energyproduced1 = 'Energy',
	energyproduced2 = 'Produced',
	energyexcess1 = 'Energy',
	energyexcess2 = 'Excess',
}

local widgetScale

local customScale = 1

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local header = {
	"frame",
	"damageDealt",
	"damageReceived",
	"unitsProduced",
--	"unitsReceived",
--	"unitsSent",
--	"unitsCaptured",
--	"unitsOutCaptured",
	"unitsKilled",
	"unitsDied",
	"damageEfficiency",
--	"killEfficiency",
	"aggressionLevel",
--	"metalUsed",
	"metalProduced",
	"metalExcess",
--	"metalReceived",
--	"metalSent",
--	"energyUsed",
	"energyProduced",
	"energyExcess",
--	"energyReceived",
--	"energySent",
--	"resourcesUsed",
--	"resourcesProduced",
--	"resourcesExcess",
--	"resourcesReceived",
--	"resourcesSent",
}

local headerRemap = {}	-- filled in initialize

local guiData = {
	mainPanel = {
		relSizes = {
			x = {
				min = 0.2333,
				max = 0.7666,
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

local glRect	= gl.Rect
local glColor	= gl.Color
local glText	= gl.Text
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glBeginText = gl.BeginText
local glEndText = gl.EndText

local GetGaiaTeamID			= Spring.GetGaiaTeamID
local GetAllyTeamList		= Spring.GetAllyTeamList
local GetTeamList			= Spring.GetTeamList
local MyTeamID				= Spring.GetMyTeamID()
local GetTeamStatsHistory	= Spring.GetTeamStatsHistory
local GetUnitDefID			= Spring.GetUnitDefID
local GetTeamColor			= Spring.GetTeamColor
local GetTeamInfo			= Spring.GetTeamInfo
local GetPlayerInfo			= Spring.GetPlayerInfo
local IsGUIHidden			= Spring.IsGUIHidden
local GetMouseState			= Spring.GetMouseState
local GetGameFrame			= Spring.GetGameFrame
local floor					= math.floor
local min					= math.min
local max					= math.max
local pi					= math.pi
local sin					= math.sin
local cos					= math.cos
local ceil					= math.ceil
local floor					= math.floor
local abs					= math.abs
local huge					= math.huge
local sort					= table.sort
local log10					= math.log10
local round					= math.round
local char					= string.char
local format				= string.format
local SIsuffixes = {"p","n","u","m","","k","M","G","T"}
local borderRemap = {left={"x","min",-1},right={"x","max",1},top={"y","max",1},bottom={"y","min",-1}}

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local elementCorner = Spring.FlowUI.elementCorner

local font, chobbyInterface, backgroundGuishader, gameStarted, bgpadding

function roundNumber(num,useFirstDecimal)
	return useFirstDecimal and format("%0.1f",round(num,1)) or round(num)
end

function convertSIPrefix(value,thresholdmodifier,noSmallValues,useFirstDecimal)
	if value == 0 or not value then
		return value
	end
	local halfScale = ceil(#SIsuffixes/2)
	if useFirstDecimal then
		useFirstDecimal = useFirstDecimal + halfScale
	end
	useFirstDecimal = useFirstDecimal or #SIsuffixes+1
	local sign = value > 0
	value = abs(value)
	thresholdmodifier = thresholdmodifier or 1
	local startIndex = 1
	if noSmallValues then
		startIndex = halfScale
	end
	local baseVal = 10^(-12)
	local retVal = ""
	for i=startIndex, #SIsuffixes do
		local tenPower = baseVal*10^(3*(i-1))
		local compareVal = baseVal*10^(3*i) * thresholdmodifier
		if value < compareVal then
			retVal = roundNumber(value/tenPower,i>=useFirstDecimal) .. SIsuffixes[i]
			break
		end
	end
	if not sign then
		retVal = "-" .. retVal
	end
	return retVal
end

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
	return char(255,min(max(floor(colorarray[1]*255),1),255),min(max(floor(colorarray[2]*255),1),255),min(max(floor(colorarray[3]*255),1),255))
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
	widgetScale = ((vsx+vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx/vsy) - 1.78)))		-- make smaller for ultrawide screens

	font = WG['fonts'].getFont()
	for _, data in pairs(headerRemap) do
		maxColumnTextSize = max(font:GetTextWidth(data[1]),maxColumnTextSize)
		maxColumnTextSize = max(font:GetTextWidth(data[2]),maxColumnTextSize)
	end

	bgpadding = Spring.FlowUI.elementPadding
	elementCorner = Spring.FlowUI.elementCorner

	calcAbsSizes()
	updateFontSize()
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('teamstats')
	end

	headerRemap = {
		frame = {" ",texts.player},
		--metalUsed = {"Metal","Used"},
		metalProduced = {texts.metalproduced1,texts.metalproduced2},
		metalExcess = {texts.metalexcess1,texts.metalexcess2},
		--metalReceived = {"Metal","Received"},
		--metalSent = {"Metal","Sent"},
		--energyUsed = {"Energy","Used"},
		energyProduced = {texts.energyproduced1,texts.energyproduced2},
		energyExcess = {texts.energyexcess1,texts.energyexcess2},
		--energyReceived = {"Energy","Received"},
		--energySent = {"Energy","Sent"},
		damageDealt = {texts.damagedealt1,texts.damagedealt2},
		damageReceived = {texts.damagereceived1,texts.damagereceived2},
		damageEfficiency = {texts.damageefficiency1,texts.damageefficiency2},
		unitsProduced = {texts.unitsproduced1,texts.unitsproduced2},
		unitsDied = {texts.unitsdied1,texts.unitsdied2},
		--unitsReceived = {"Units","Received"},
		--unitsSent = {"Units","Sent"},
		--unitsCaptured = {"Units","Captured"},
		--unitsOutCaptured = {"Units","OutCaptured"},
		unitsKilled = {texts.unitskilled1,texts.unitskilled2},
		--resourcesUsed = {"Resources","Used"},
		--resourcesProduced = {"Resources","Produced"},
		--resourcesExcess = {"Resources","Excess"},
		--resourcesReceived = {"Resources","Received"},
		--resourcesSent = {"Resources","Sent"},
		--killEfficiency = {"Killing","Efficiency"},
		aggressionLevel = {texts.aggressionlevel1,texts.aggressionlevel2},
	}

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


function widget:KeyPress(key)
	if key == 27 then	-- ESC
		guiData.mainPanel.visible = false
	end
end

function widget:Shutdown()
	glDeleteList(textDisplayList)
	glDeleteList(backgroundDisplayList)
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('teamstats_window')
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
	widget:GameFrame(GetGameFrame(),true)
end

function widget:GameFrame(n,forceupdate)
	if n > 0 then
		gameStarted = true
	end
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
					for varName,value in pairs(history) do
						allyTotal[varName] = (allyTotal[varName] or 0 ) + value
					end
					history.time = nil
					local teamColor = {GetTeamColor(teamID)}
					local _,leader,isDead = GetTeamInfo(teamID,false)
					local playerName,isActive = GetPlayerInfo(leader,false)
					if Spring.GetGameRulesParam('ainame_'..teamID) then
						playerName = Spring.GetGameRulesParam('ainame_'..teamID)
					end
					if gameStarted ~= nil then
						if not playerName then
							playerName = teamControllers[teamID] or texts.gone
						else
							teamControllers[teamID] = playerName
						end
						if isDead then
							playerName = playerName .. " ("..texts.dead..")"
						elseif not isActive then
							playerName = playerName .. " ("..texts.gone..")"
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
			totalNumLines = totalNumLines + 1
			allyInsertCount = allyInsertCount + 1
		end
	end
	sort(teamData,compareAllyTeams)
	if totalNumLines ~= prevNumLines then
		guiData.mainPanel.absSizes.y.min = guiData.mainPanel.absSizes.y.max - totalNumLines*fontSize
	end
	prevNumLines = totalNumLines
	glDeleteList(textDisplayList)
	textDisplayList = glCreateList(ReGenerateTextDisplayList)
	glDeleteList(backgroundDisplayList)
	backgroundDisplayList = glCreateList(ReGenerateBackgroundDisplayList)
end


function widget:GameOver()
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
	local line = floor(relativey/fontSize) +1
	local column = floor(relativex/columnSize) +1
	return line,column
end


function updateFontSize()
	columnSize = guiData.mainPanel.absSizes.x.length / numColums
	local fakeColumnSize = guiData.mainPanel.absSizes.x.length / (numColums-1)
	fontSize = 11*widgetScale + floor(fakeColumnSize/maxColumnTextSize)
end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)

	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
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

local uiOpacitySec = 0
function widget:Update(dt)
	local x,y = GetMouseState()
	if x ~= mousex or y ~= mousey then
		widget:MouseMove(x,y,x-mousex,y-mousey)
	end
	mousex,mousey = x,y

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			widget:ViewResize()
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	if IsGUIHidden() then return end
	if not guiData.mainPanel.visible then
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('teamstats_window')
		end
		return
	end
	DrawBackground()
	DrawAllStats()

	local x, y, pressed = Spring.GetMouseState()
	local x1,y1,x2,y2 = math.floor(guiData.mainPanel.absSizes.x.min), math.floor(guiData.mainPanel.absSizes.y.min), math.floor(guiData.mainPanel.absSizes.x.max), math.floor(guiData.mainPanel.absSizes.y.max)
	if IsOnRect(x, y, x1,y1,x2,y2) then
		Spring.SetMouseCursor('cursornormal')
	end
end

function DrawBackground()
	if not guiData.mainPanel.visible then
		return
	end
	if backgroundDisplayList then
		glCallList(backgroundDisplayList)
	end

	local x1,y1,x2,y2 = math.floor(guiData.mainPanel.absSizes.x.min), math.floor(guiData.mainPanel.absSizes.y.min), math.floor(guiData.mainPanel.absSizes.x.max), math.floor(guiData.mainPanel.absSizes.y.max)
	if WG['guishader'] then
		gl.Color(0,0,0,0.8)
	else
		gl.Color(0,0,0,0.85)
	end
	UiElement(x1-bgpadding,y1-bgpadding,x2+bgpadding,y2+bgpadding, 1, 1, 1, 1, 1,1,1,1, ui_opacity + 0.2)
	if WG['guishader'] then
		if backgroundGuishader ~= nil then
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = glCreateList( function()
			RectRound(x1-bgpadding,y1-bgpadding,x2+bgpadding,y2+bgpadding, elementCorner)
		end)
		WG['guishader'].InsertDlist(backgroundGuishader,'teamstats_window')
	end
end

function DrawAllStats()
	if not guiData.mainPanel.visible then
		return
	end
	if textDisplayList then
		glCallList(textDisplayList)
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
		if lineCount > 2 then
			RectRound(math.floor(boxSizes.x.min), math.floor(boxSizes.y.max -lineCount*fontSize), math.floor(boxSizes.x.max), math.floor(boxSizes.y.max -(lineCount-1)*fontSize), bgpadding, 1,1,1,1, {colour[1],colour[2],colour[3],colour[4]}, {colour[1],colour[2],colour[3],colour[4]*3})
		elseif lineCount == 1 then
			--RectRound(boxSizes.x.min, boxSizes.y.max -(lineCount+1)*fontSize, boxSizes.x.max, boxSizes.y.max -(lineCount-1)*fontSize, 3*widgetScale)
		end
	end
	if selectedLine and selectedLine < 3 and selectedColumn and selectedColumn > 0 and selectedColumn <= numColums then
		if sortAscending then
			glColor(sortHighLightColour)
		else
			glColor(sortHighLightColourDesc)
		end
		RectRound(math.floor(boxSizes.x.min +(selectedColumn)*columnSize-columnSize/2), math.floor(boxSizes.y.max -2*fontSize), math.floor(boxSizes.x.min +(selectedColumn+1)*columnSize-columnSize/2), math.floor(boxSizes.y.max), bgpadding)
	end
	for selectedIndex, headerName in ipairs(header) do
		if sortVar == headerName then
			if sortAscending then
				glColor(activeSortColour)
			else
				glColor(activeSortColourDesc)
			end
			RectRound(math.floor(boxSizes.x.min +(selectedIndex)*columnSize-columnSize/2), math.floor(boxSizes.y.max -2*fontSize), math.floor(boxSizes.x.min +(selectedIndex+1)*columnSize-columnSize/2), math.floor(boxSizes.y.max), bgpadding)
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
		--print the header
		local colCount = 0
		local heightCorrection = fontSize*((1-fontSizePercentage)/2)

		for _, headerName in ipairs(header) do
			font:Print(headerRemap[headerName][1], baseXSize + columnSize*colCount, baseYSize+heightCorrection-lineCount*fontSize, (fontSize*fontSizePercentage), "dco")
			font:Print(headerRemap[headerName][2], baseXSize + columnSize*colCount, baseYSize+heightCorrection-(lineCount+1)*fontSize, (fontSize*fontSizePercentage), "dco")
			colCount = colCount + 1
		end
		lineCount = lineCount + 3
		for _, allyTeamData in ipairs(teamData) do
			for _, teamData in ipairs(allyTeamData) do
				local colCount = 0
				for _, varName in ipairs(header) do
					local value = teamData[varName]
					if value == huge or value == -huge then
						value = "-"
					elseif tonumber(value) then
						if varName:sub(1,5) ~= "units" and varName ~= "aggressionLevel" then
							value = convertSIPrefix(value,1,true,1)
						else
							value = convertSIPrefix(value)
						end
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
					font:Print(color..value, baseXSize + columnSize*colCount, baseYSize+heightCorrection-lineCount*fontSize, (fontSize*fontSizePercentage), "dco")
					colCount = colCount + 1
				end
				lineCount = lineCount + 1
			end
			lineCount = lineCount + 1 -- add line break after end of allyteam
		end
	font:End()
end
