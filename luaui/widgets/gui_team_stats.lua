function widget:GetInfo()
	return {
		name      = "Team stats",
		desc      = "Shows game stats.",
		author    = "",
		version   = "",
		date      = "",
		license   = "",
		layer     = -10,
		enabled   = false,
	}
end

local bgcorner	= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

local fontSize = 12
local update = 30 -- in frames
local replaceEndStats = false
local highLightColour = {0.5,0.8,0.5,0.66}
local activeSortColour = {0.7,0.7,1,0.95}
local oddLineColour = {0.22,0.22,0.22,0.33}
local evenLineColour = {0.7,0.7,0.7,0.33}
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
	"metalUsed",
	"metalProduced",
--	"metalExcess",
	"metalReceived",
	"metalSent",
	"energyUsed",
	"energyProduced",
--	"energyExcess",
	"energyReceived",
	"energySent",
	--"resourcesUsed",
	--"resourcesProduced",
	--"resourcesExcess",
	--"resourcesReceived",
	--"resourcesSent",
}

local glRect	= gl.Rect
local glColor	= gl.Color
local glText	= gl.Text
local glGetTextWidth = gl.GetTextWidth
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

function rectBoxWithBorder(boxData,fillColor,edgeColor)
	if fillColor then
		glColor(fillColor)
	end
	rectBox(boxData)
	if edgeColor then
		glColor(edgeColor)
	end
	local borderSize = boxData.draggingBorderSize
	boxData = boxData.absSizes
	glRect(boxData.x.min, boxData.y.max, boxData.x.max, boxData.y.max - borderSize ) -- top
	glRect(boxData.x.min, boxData.y.max, boxData.x.min + borderSize , boxData.y.min) -- left
	glRect(boxData.x.min, boxData.y.min + borderSize, boxData.x.max, boxData.y.min) -- bottom
	glRect(boxData.x.max - borderSize, boxData.y.max, boxData.x.max, boxData.y.min) -- right
end

function rectBox(boxData,fillColor)
	boxData = boxData.absSizes
	if fillColor then
		glColor(fillColor)
	end
	glRect(boxData.x.min,boxData.y.max,boxData.x.max,boxData.y.min)
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

function getColourOutline(colour)
	local luminance  = colour[1] * 0.299 + colour[2] * 0.587 + colour[3] * 0.114
	return luminance > 0.25 and "o" or "O"
end

function viewResize(scalingVec,guiData)
	for boxType, boxData in pairs(guiData) do
		guiData[boxType].absSizes = convertCoords(boxData.relSizes,scalingVec)
	end
	return guiData
end

function tweakMousePress(mouseCoords,guiData)
	local boxType, border, masks = isAbove(mouseCoords,guiData)
	if not boxType then
		return false, guiData
	end
	for boxName in pairs(guiData) do
		guiData[boxName].changing = {}
	end
	if border then
		guiData[boxType].changing.resizing = masks
	else
		guiData[boxType].changing.dragging = true
	end
	return boxType, guiData
end

function convertCoords(sourceCoords,scalingVec)
	local newCoords = {}
	for coordName, coordData in pairs(sourceCoords) do
		newCoords[coordName] = {}
		for minmax, value in pairs(coordData) do
			newCoords[coordName][minmax] = value*scalingVec[coordName]
		end
	end
	return newCoords
end

function tweakMouseRelease(guiData)
	local vsx,vsy = widgetHandler:GetViewSizes()
	local scalingVec = {x=1/vsx,y=1/vsy}
	for boxType, boxData in pairs(guiData) do
		guiData[boxType].relSizes = convertCoords(boxData.absSizes,scalingVec)
		guiData[boxType].changing = {}
	end
	return guiData
end

function tweakMouseMove(mouseDelta, guiData)
	local changed
	for boxType, boxData in pairs(guiData) do
		for changeType,changeVal in pairs(boxData.changing) do
			if changeType == "dragging" then
				changed = boxType
				for coordName,coordData in pairs(boxData.absSizes) do
					for absname,minMax in pairs(coordData) do
						if absname ~= "length" then
							guiData[boxType].absSizes[coordName][absname] = minMax + mouseDelta[coordName]
						end
					end
				end
			elseif changeType == "resizing" then
				changed = boxType
				local borderMasks = changeVal
				local boxSizes = boxData.absSizes
				local minSize = boxData.draggingBorderSize*3
				for borderName, borderVal in pairs(borderMasks) do
					if borderVal then
						local coordName = borderRemap[borderName][1]
						local coordDir = borderRemap[borderName][2]
						local dir = borderRemap[borderName][3]
						if boxSizes[coordName].length + mouseDelta[coordName]*dir > minSize then
							boxSizes[coordName][coordDir] = boxSizes[coordName][coordDir] + mouseDelta[coordName]
							boxSizes[coordName].length = boxSizes[coordName].max - boxSizes[coordName].min
						end
					end
				end
				guiData[boxType].absSizes = boxSizes
			end
		end
	end
	return changed,guiData
end

local guiData = {
	smallBox = {
		relSizes = {
			x = {
				min = 0.96,
				max = 1,
				length = 0.04,
			},
			y = {
				min = 0.7,
				max = 0.74,
				length = 0.04,
			},
		},
		draggingBorderSize = 7,
		visible = true,
	},
	mainPanel = {
		relSizes = {
			x = {
				min = 0.05,
				max = 0.95,
				length = 0.86,
			},
			y = {
				min = 0.2,
				max = 0.8,
				length = 0.6,
			},
		},
		draggingBorderSize = 7,
		visible = false,
	},
}
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
local headerRemap = {
	frame = {"Player","Name"},
	metalUsed = {"Metal","Used"},
	metalProduced = {"Metal","Produced"},
	metalExcess = {"Metal","Excess"},
	metalReceived = {"Metal","Received"},
	metalSent = {"Metal","Sent"},
	energyUsed = {"Energy","Used"},
	energyProduced = {"Energy","Produced"},
	energyExcess = {"Energy","Excess"},
	energyReceived = {"Energy","Received"},
	energySent = {"Energy","Sent"},
	damageDealt = {"Damage","Dealt"},
	damageReceived = {"Damage","Received"},
	damageEfficiency = {"Damage","Efficiency"},
	unitsProduced = {"Units","Produced"},
	unitsDied = {"Units","Died"},
	unitsReceived = {"Units","Received"},
	unitsSent = {"Units","Sent"},
	unitsCaptured = {"Units","Captured"},
	unitsOutCaptured = {"Units","OutCaptured"},
	unitsKilled = {"Units","Killed"},
	resourcesUsed = {"Resources","Used"},
	resourcesProduced = {"Resources","Produced"},
	resourcesExcess = {"Resources","Excess"},
	resourcesReceived = {"Resources","Received"},
	resourcesSent = {"Resources","Sent"},
	killEfficiency = {"Killing","Efficiency"},
	aggressionLevel = {"Aggression","Level"},
}
for _, data in pairs(headerRemap) do
	maxColumnTextSize = max(glGetTextWidth(data[1]),maxColumnTextSize)
	maxColumnTextSize = max(glGetTextWidth(data[2]),maxColumnTextSize)
end

local sortVar = "damageDealt"
local sortAscending = false

local numColums = #header +1


function widget:SetConfigData(data)
	guiData = data.guiData or guiData
	forceWithinScreen()
	sortVar = data.sortVar or sortVar
	sortAscending = data.sortAscending or sortAscending
	local vsx,vsy = widgetHandler:GetViewSizes()
	widget:ViewResize(vsx,vsy)
end

function widget:GetConfigData(data)
	return{
		guiData = guiData,
		sortVar = sortVar,
		sortAscending = sortAscending,
	}
end


function forceWithinScreen()
	if guiData.smallBox.relSizes.x.min < 0 then
		guiData.smallBox.relSizes.x.min = 0
		guiData.smallBox.relSizes.x.max = guiData.smallBox.relSizes.x.length
	end
	if guiData.smallBox.relSizes.y.min < 0 then
		guiData.smallBox.relSizes.y.min = 0
		guiData.smallBox.relSizes.y.max = guiData.smallBox.relSizes.y.length
	end
	if guiData.smallBox.relSizes.x.max > 1 then
		guiData.smallBox.relSizes.x.max = 1
		guiData.smallBox.relSizes.x.min = 1 - guiData.smallBox.relSizes.x.length
	end
	if guiData.smallBox.relSizes.y.max > 1 then
		guiData.smallBox.relSizes.y.max = 1
		guiData.smallBox.relSizes.y.min = 1 - guiData.smallBox.relSizes.y.length
	end
end


function calcAbsSizes()
	--forceWithinScreen()
	
	local vsx,vsy = gl.GetViewSizes()
	guiData.smallBox.absSizes = {
		x = {
			min = (guiData.smallBox.relSizes.x.min * vsx),
			max = (guiData.smallBox.relSizes.x.max * vsx),
			length = (guiData.smallBox.relSizes.x.length * vsx),
		},
		y = {
			min = (guiData.smallBox.relSizes.y.min * vsy),
			max = (guiData.smallBox.relSizes.y.max * vsy),
			length = (guiData.smallBox.relSizes.y.length * vsy),
		}
	}
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

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx,vsy = viewSizeX, viewSizeY
	calcAbsSizes()
	updateFontSize()
	createButtonList()
end

function widget:Initialize()
	guiData.mainPanel.visible = false
	local vsx,vsy = widgetHandler:GetViewSizes()
	widget:ViewResize(vsx,vsy)
	local _,_, paused = Spring.GetGameSpeed()
	if paused then
		widget:GameFrame(GetGameFrame(),true)
	end
	createButtonList()
end

function createButtonList()
	if buttonDrawList ~= nil then
		gl.DeleteList(buttonDrawList)
	end
	buttonDrawList = gl.CreateList(DrawButton)
end

function widget:Shutdown()
	glDeleteList(textDisplayList)
	glDeleteList(backgroundDisplayList)
	if buttonDrawList ~= nil then
		gl.DeleteList(buttonDrawList)
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('teamstats_button')
		WG['guishader_api'].RemoveRect('teamstats_window')
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
	guiData.smallBox.visible = n ~= 0
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
					local _,leader,isDead = GetTeamInfo(teamID)
					local playerName,isActive = GetPlayerInfo(leader)
					if not playerName then
						playerName = teamControllers[teamID] or "gone"
					else
						teamControllers[teamID] = playerName
					end
					if isDead or spectator then
						playerName = playerName .. " (dead)"
					elseif not isActive then
						playerName = playerName .. " (gone)"
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
					history.frame = colorToChar(teamColor) .. playerName
					allyVec[teamInsertCount] = history
					totalNumLines = totalNumLines + 1
					teamInsertCount = teamInsertCount + 1
				end
			end
		end
		if teamInsertCount ~= 1 then
			sort(allyVec,compareTeams)
			if teamInsertCount > 2 then
				allyTotal.frame = "Total sum"
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
		guiData = tweakMouseRelease(guiData)
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


function widget:IsAbove(x,y)
	return isAbove({x=x,y=y},guiData)
end

function widget:MousePress(mx,my,button)
	if gameStarted == nil then return end
	
	local boxType = widget:IsAbove(mx,my)
	if not boxType then
		guiData.mainPanel.visible = false
		return false
	end
	if boxType == "smallBox" then
		guiData.mainPanel.visible = not guiData.mainPanel.visible
		widget:GameFrame(GetGameFrame(),true)
	elseif boxType == "mainPanel" then
		local line, column = getLineAndColumn(mx,my)
		if line <= 3 then -- header
			local newSort = header[column]
			if newSort then
				if sortVar == newSort then
					sortAscending = not sortAscending
				end
				sortVar = newSort
			end
		else
			guiData.mainPanel.visible = not guiData.mainPanel.visible
		end
	end
	return true
end

function getLineAndColumn(x,y)
	local relativex = x - guiData.mainPanel.absSizes.x.min - columnSize/2
	local relativey = guiData.mainPanel.absSizes.y.max - y
	local line = floor(relativey/fontSize) +1
	local column = floor(relativex/columnSize) +1
	return line,column
end



function widget:TweakMousePress(x, y, button)
	if button ~= 2 then
		return false
	end
	local ok
	ok, guiData = tweakMousePress({x=x,y=y},guiData)
	createButtonList()
	return ok
end

function updateFontSize()
	columnSize = guiData.mainPanel.absSizes.x.length / numColums
	local fakeColumnSize = guiData.mainPanel.absSizes.x.length / (numColums-1)
	fontSize = floor(fakeColumnSize/maxColumnTextSize)
end

function widget:TweakMouseMove(x, y, dx, dy, button)
	_, guiData = tweakMouseMove({x=dx,y=dy}, guiData)
	updateFontSize()
	glDeleteList(textDisplayList)
	textDisplayList = glCreateList(ReGenerateTextDisplayList)
	glDeleteList(backgroundDisplayList)
	backgroundDisplayList = glCreateList(ReGenerateBackgroundDisplayList)
	createButtonList()
end

function widget:TweakMouseRelease(mx,my,button)
	guiData = tweakMouseRelease(guiData)
	forceWithinScreen()
	calcAbsSizes()
	createButtonList()
end

function widget:MouseMove(mx,my,dx,dy)
	local boxType = widget:IsAbove(mx,my)
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

function widget:Update()
	local x,y = GetMouseState()
	if x ~= mousex or y ~= mousey then
		widget:MouseMove(x,y,x-mousex,y-mousey)
	end
	mousex,mousey = x,y
end

function widget:DrawScreen()
	if IsGUIHidden() then
		return
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('teamstats_window')
	end
	gl.CallList(buttonDrawList)
	DrawBackground()
	DrawAllStats()
end

local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.07		-- texture offset, because else gaps could show
	local o = offset
	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end


function DrawButton()
	if not guiData.smallBox.visible then
		return
	end
	local boxAbsData = guiData.smallBox.absSizes
	local tempFontSize = 14
	--[[if widgetHandler:InTweakMode() then
		rectBoxWithBorder(guiData.smallBox,{0,0,0,0.7})
	else
		rectBox(guiData.smallBox,{0,0,0,0.5})
	end]]--
	local x1,y1,x2,y2 = guiData.smallBox.absSizes.x.min, guiData.smallBox.absSizes.y.min, guiData.smallBox.absSizes.x.max, guiData.smallBox.absSizes.y.max
	
	gl.Color(0,0,0,0.6)
	RectRound(x1,y1,x2,y2,7)
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(x1,y1,x2,y2,'teamstats_button')
	end
	
	glText(colorToChar({1,1,1}) .. "Team Stats",boxAbsData.x.min+boxAbsData.x.length/2, boxAbsData.y.max-boxAbsData.y.length/2, tempFontSize, "ovc")
end

function DrawBackground()
	if not guiData.mainPanel.visible then
		return
	end
	if widgetHandler:InTweakMode() then
		rectBoxWithBorder(guiData.mainPanel,{0,0,0,0.4})
	else
		if backgroundDisplayList then
			glCallList(backgroundDisplayList)
		end
	end
	
	local x1,y1,x2,y2 = guiData.mainPanel.absSizes.x.min, guiData.mainPanel.absSizes.y.min, guiData.mainPanel.absSizes.x.max, guiData.mainPanel.absSizes.y.max
	
	gl.Color(0,0,0,0.7)
	local padding = 5
	RectRound(x1-padding,y1-padding,x2+padding,y2+padding,7)
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(x1-padding,y1-padding,x2+padding,y2+padding,'teamstats_window')
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
	local boxSizes = guiData.mainPanel.absSizes
	for lineCount=1,prevNumLines do
		local colour = evenLineColour
		if lineCount > 2 and (lineCount+1)%2 == 0 then
			colour = oddLineColour
		end
		if lineCount == selectedLine and selectedLine > 2 then
			colour = highLightColour
		end
		glColor(colour)
		glRect(boxSizes.x.min,boxSizes.y.max -(lineCount-1)*fontSize,boxSizes.x.max, boxSizes.y.max -lineCount*fontSize)
	end
	for selectedIndex, headerName in ipairs(header) do
		if sortVar == headerName then
			glColor(activeSortColour)
			glRect(boxSizes.x.min +(selectedIndex)*columnSize-columnSize/2,boxSizes.y.max,boxSizes.x.min +(selectedIndex+1)*columnSize-columnSize/2, boxSizes.y.max -2*fontSize)
			break
		end
	end
	if selectedLine and selectedLine < 3 and selectedColumn and selectedColumn > 0 and selectedColumn < numColums then
		glColor(highLightColour)
		glRect(boxSizes.x.min +(selectedColumn)*columnSize-columnSize/2,boxSizes.y.max,boxSizes.x.min +(selectedColumn+1)*columnSize-columnSize/2, boxSizes.y.max -2*fontSize)
	end
end

function ReGenerateTextDisplayList()
	local lineCount = 1
	local boxSizes = guiData.mainPanel.absSizes
	local baseXSize = boxSizes.x.min + columnSize
	local baseYSize = boxSizes.y.max

	glBeginText()
		--print the header
		local colCount = 0

		for _, headerName in ipairs(header) do
			glText(headerRemap[headerName][1], baseXSize + columnSize*colCount, baseYSize-lineCount*fontSize, fontSize, "dco")
			glText(headerRemap[headerName][2], baseXSize + columnSize*colCount, baseYSize-(lineCount+1)*fontSize, fontSize, "dc")
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
					glText(value, baseXSize + columnSize*colCount, baseYSize-lineCount*fontSize, fontSize, "dco")
					colCount = colCount + 1
				end
				lineCount = lineCount + 1
			end
			lineCount = lineCount + 1 -- add line break after end of allyteam
		end
	glEndText()
end


