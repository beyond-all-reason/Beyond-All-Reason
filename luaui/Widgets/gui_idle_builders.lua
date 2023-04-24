function widget:GetInfo()
	return {
		name = "Idle Builders",
		desc = "Interface to display idle builders",
		author = "Floris (original by Ray)",
		date = "March 2021",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true
	}
end

local alwaysShow = true		-- always show AT LEAST the label
local alwaysShowLabel = true	-- always show the label regardless
local showWhenSpec = false
local showStack = false
local iconSizeMult = 0.98
local playSounds = true
local soundVolume = 0.5
local setHeight = 0.046
local maxGroups = 9

local leftclick = 'LuaUI/Sounds/buildbar_add.wav'
local rightclick = 'LuaUI/Sounds/buildbar_click.wav'

local vsx, vsy = Spring.GetViewGeometry()
local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local spec = Spring.GetSpectatingState()

local widgetSpaceMargin, backgroundPadding, elementCorner, RectRound, TexturedRectRound, UiElement, UiButton, UiUnit


local spGetMouseState = Spring.GetMouseState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetFullBuildQueue = Spring.GetFullBuildQueue
local spGetUnitHealth = Spring.GetUnitHealth
local spGetCommandQueue = Spring.GetCommandQueue
local spGetTeamUnitsSorted = Spring.GetTeamUnitsSorted
local myTeamID = Spring.GetMyTeamID()

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local math_isInRect = math.isInRect

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local height = setHeight * uiScale
local posX = 0
local posY = 0
local iconMargin = 0
local groupSize = 0
local usedWidth = 0
local usedHeight = 0
local hovered = false
local numGroups = 0
local selectedUnits = Spring.GetSelectedUnits() or {}
local selectionHasChanged = true
local selectedGroups = {}
local buildmenuShowingPosY = 0
local buildmenuAlwaysShow = false
local buildmenuIsShowing = true

local groupButtons = {}
local existingGroups = {}
local clicks = {}

local nearIdle = 0 -- this means that factories with only X build items left will be shown as idle
local qCount = {}
local idleList = {}

local font, font2, buildmenuBottomPosition, dlist, dlistGuishader, backgroundRect, ordermenuPosY

local isBuilder = {}
local isFactory = {}
local unitHumanName = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1]) and not unitDef.customParams.isairbase then
		isBuilder[unitDefID] = true
	end
	if unitDef.isFactory then
		isFactory[unitDefID] = true
	end

	if unitDef.translatedHumanName then
		unitHumanName[unitDefID] = unitDef.translatedHumanName
	end
end

local function isIdleBuilder(unitID)
	local udef = spGetUnitDefID(unitID)
	local qCount = 0
	if isBuilder[udef] then
		--- can build
		local buildQueue = spGetFullBuildQueue(unitID)
		if not buildQueue[1] then
			--- has no build queue
			local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
			if buildProgress == 1 then
				--- isnt under construction
				if isFactory[udef] then
					return true
				else
					if spGetCommandQueue(unitID, 0) == 0 then
						return true
					end
				end
			end
		elseif isFactory[udef] then
			for _, thing in ipairs(buildQueue) do
				for _, count in pairs(thing) do
					qCount = qCount + count
				end
			end
			if qCount <= nearIdle then
				qCount[unitID] = qCount
				return true
			end
		end
	end
	return false
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			WG['guishader'].RemoveDlist('idlebuilders')
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader and backgroundRect then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner, ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0))
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'idlebuilders')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function drawIcon(unitDefID, rect, lightness, zoom, texSize, highlightOpacity)
	--Spring.Debug.TraceFullEcho()
	gl.Color(lightness,lightness,lightness,1)
	UiUnit(
		rect[1], rect[2], rect[3], rect[4],
		ceil(backgroundPadding*0.5), 1,1,1,1,
		zoom,
		nil, math.max(0.1, highlightOpacity or 0.1),
		'#'..unitDefID,
		nil, nil, nil, nil
	)
	if highlightOpacity then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(1,1,1,highlightOpacity)
		RectRound(rect[1], rect[2], rect[3], rect[4], min(max(1, floor((rect[3]-rect[1]) * 0.024)), floor((vsy*0.0015)+0.5)))
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
end

local function updateList()
	if dlist then
		dlist = gl.DeleteList(dlist)
	end

	idleList = {}
	qCount = {}
	local myUnits = spGetTeamUnitsSorted(myTeamID)
	for unitDefID, units in pairs(myUnits) do
		if type(units) == 'table' then
			for count, unitID in pairs(units) do
				if count ~= 'n' and isIdleBuilder(unitID) then
					if idleList[unitDefID] then
						idleList[unitDefID][#idleList[unitDefID] + 1] = unitID
					else
						idleList[unitDefID] = { unitID }
					end
				end
			end
		end
	end

	numGroups = 0
	existingGroups = {}
	for unitDefID, units in pairs(idleList) do
		numGroups = numGroups + 1
		existingGroups[numGroups] = unitDefID
	end

	if numGroups == 0 and not alwaysShow then
		if backgroundRect then
			backgroundRect = nil
			checkGuishader(true)
		end
	else
		dlist = gl.CreateList(function()
			local mult = numGroups
			if numGroups == 0 then
				mult = 1
			end
			if mult > maxGroups then
				mult = maxGroups
				numGroups = mult
			end

			local groupWidth = groupSize - backgroundPadding
			local startOffsetX = 0
			if numGroups > 0 and alwaysShowLabel then
				startOffsetX = groupWidth
			end
			usedWidth = (groupWidth * mult) + backgroundPadding + backgroundPadding + startOffsetX

			backgroundRect = {
				floor(posX * vsx),
				floor(posY * vsy),
				floor(posX * vsx) + usedWidth,
				floor(posY * vsy) + usedHeight
			}

			UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0))

			if numGroups == 0 or alwaysShowLabel then
				local groupRect = {
					floor(posX * vsx),
					floor(posY * vsy),
					floor(posX * vsx) + usedWidth - (groupWidth * numGroups),
					floor(posY * vsy) + usedHeight
				}
				local fontSize = height*vsy*0.33
				local offset = ((groupRect[3]-groupRect[1])/5)
				local offsetY = -(fontSize*(posY > 0 and 0.22 or 0.31))
				local style = 'c'
				font2:Begin()
				font2:SetTextColor(1,1,1,0.2)
				offset = (fontSize*0.6)
				font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), groupRect[1]+((groupRect[3]-groupRect[1])/2)-offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)+offset+offsetY, fontSize, style)
				fontSize = fontSize * 1.2
				font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+((groupRect[4]-groupRect[2])/2)+offsetY, fontSize, style)
				fontSize = fontSize * 1.2
				offset = (fontSize*0.48)
				font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), groupRect[1]+((groupRect[3]-groupRect[1])/2)+offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)-offset+offsetY, fontSize, style)
				font2:End()
			end

			if numGroups > 0 then
				local hoveredGroup = -1
				local x, y, b, b2, b3 = spGetMouseState()
				if groupButtons then
					for i,v in pairs(groupButtons) do
						if math_isInRect(x, y, groupButtons[i][1], groupButtons[i][2], groupButtons[i][3], groupButtons[i][4]) then
							hoveredGroup = groupButtons[i][5]
							break
						end
					end
				end

				local groupCounter = 0
				groupButtons = {}
				for group=1, maxGroups do
					if existingGroups[group] then
						local groupRect = {
							backgroundRect[1]+backgroundPadding+((groupSize-backgroundPadding)*groupCounter)+startOffsetX,
							backgroundRect[2]+(posY-height > 0 and backgroundPadding or 0),
							backgroundRect[1]+backgroundPadding+(groupSize-backgroundPadding)+((groupSize-backgroundPadding)*groupCounter)+startOffsetX,
							backgroundRect[4]-backgroundPadding
						}

						local unitCount = #idleList[existingGroups[group]]
						local unitDefID = existingGroups[group]

						gl.Color(1,1,1,1)
						groupButtons[#groupButtons+1] = {groupRect[1],groupRect[2],groupRect[3],groupRect[4],group}
						local groupSize = groupRect[3]-groupRect[1]-iconMargin-iconMargin
						local iconSize = groupSize * iconSizeMult
						local offset = 0
						if showStack then
							if unitCount > 4 then
								iconSize = floor(iconSize*0.78)
								offset = floor((groupSize - iconSize) / 4)
							elseif unitCount > 3 then
								iconSize = floor(iconSize*0.83)
								offset = floor((groupSize - iconSize) / 3)
							elseif unitCount> 2 then
								iconSize = floor(iconSize*0.86)
								offset = floor((groupSize - iconSize) / 2)
							elseif unitCount > 1 then
								iconSize = floor(iconSize*0.88)
								offset = groupSize - (iconSize*1.06)
							else
								iconSize = floor(iconSize*0.94)
								offset = groupSize - iconSize
							end
						end

						local texSize = floor(groupSize*1.33)
						local zoom = group == hoveredGroup and (b and 0.15 or 0.105) or 0.05
						local highlightOpacity = 0
						if selectedGroups[group] then
							zoom = zoom + 0.08
							highlightOpacity = 0.17
						elseif group == hoveredGroup then
							highlightOpacity = 0.22
						end
						if showStack then
							if unitCount > 4 then
								drawIcon(
									unitDefID,
									{groupRect[1]+iconMargin+(offset*4), groupRect[4]-iconMargin-(offset*4)-iconSize, groupRect[1]+iconMargin+(offset*4)+iconSize, groupRect[4]-iconMargin-(offset*4)},
									0.33, zoom, texSize, highlightOpacity
								)
							end
							if unitCount > 3 then
								drawIcon(
									unitDefID,
									{groupRect[1]+iconMargin+(offset*3), groupRect[4]-iconMargin-(offset*3)-iconSize, groupRect[1]+iconMargin+(offset*3)+iconSize, groupRect[4]-iconMargin-(offset*3)},
									0.45, zoom, texSize, highlightOpacity
								)
							end
							if unitCount > 2 then
								drawIcon(
									unitDefID,
									{groupRect[1]+iconMargin+(offset*2), groupRect[4]-iconMargin-(offset*2)-iconSize, groupRect[1]+iconMargin+(offset*2)+iconSize, groupRect[4]-iconMargin-(offset*2)},
									0.55, zoom, texSize, highlightOpacity
								)
							end
							if unitCount > 1 then
								drawIcon(
									unitDefID,
									{groupRect[1]+iconMargin+offset, groupRect[4]-iconMargin-offset-iconSize, groupRect[1]+iconMargin+offset+iconSize, groupRect[4]-iconMargin-offset},
									0.7, zoom, texSize, highlightOpacity
								)
							end
						end
						drawIcon(
							unitDefID,
							{groupRect[1]+iconMargin, groupRect[4]-iconMargin-iconSize, groupRect[1]+iconMargin+iconSize, groupRect[4]-iconMargin},
							1, zoom, texSize, highlightOpacity
						)

						if unitCount > 1 then
							local fontSize = height*vsy*0.39
							font:Begin()
							font:Print('\255\240\240\240'..unitCount, groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.92), fontSize, "o")
							font:End()
						end

						groupCounter = groupCounter + 1
					end
				end
			end
		end)
		checkGuishader(true)
	end
end

local function checkUnitGroupsPos(isViewresize)

	if WG['unitgroups'] then
		local px, py, sx, sy = WG['unitgroups'].getPosition()
		local oldPosX, oldPosY = posX, posY
		posY = py / vsy
		posX = (sx + widgetSpaceMargin) / vsx
		if posX ~= oldPosX or posY ~= oldPosY then
			if not isViewresize then
				widget:ViewResize()
			end
			updateList()
		end
	else
		if buildmenuBottomPosition and not buildmenuAlwaysShow and WG['buildmenu'] and WG['info'] then
			if (not selectedUnits[1] or not WG['buildmenu'].getIsShowing()) and (posX > 0 or not WG['info'].getIsShowing()) then
				if posY ~= 0 then
					posY = 0
					if not isViewresize then
						widget:ViewResize()
					end
					doUpdate = true
				end
			else
				if posY ~= buildmenuShowingPosY then
					posY = buildmenuShowingPosY
					doUpdate = true
				end
			end
		end
		if not isViewresize then
			widget:ViewResize()
			doUpdate = true
		end
	end
end
local checkgroups = false
function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	height = setHeight * uiScale

	font2 = WG['fonts'].getFont(nil, 1.3, 0.35, 1.4)
	font = WG['fonts'].getFont(fontFile, 1.15, 0.35, 1.25)

	elementCorner = WG.FlowUI.elementCorner
	backgroundPadding = WG.FlowUI.elementPadding
	widgetSpaceMargin = WG.FlowUI.elementMargin

	RectRound = WG.FlowUI.Draw.RectRound
	TexturedRectRound = WG.FlowUI.Draw.TexturedRectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiUnit = WG.FlowUI.Draw.Unit

	if WG['buildmenu'] then
		buildmenuBottomPosition = WG['buildmenu'].getBottomPosition()
		buildmenuIsShowing = WG['buildmenu'].getIsShowing()
	end

	local omPosX, omPosY, omWidth, omHeight = 0, 0, 0, 0
	if WG['ordermenu'] then
		omPosX, omPosY, omWidth, omHeight = WG['ordermenu'].getPosition()
	end
	ordermenuPosY = omPosY

	if buildmenuBottomPosition then
		posY = omHeight + (widgetSpaceMargin/vsy)
		if omPosX <= 0.01 then
			posX = omPosX + omWidth + (widgetSpaceMargin/vsx)
		else
			posX = 0
		end
	else
		posY = 0
		posX = omPosX + omWidth + (widgetSpaceMargin/vsx)
	end

	if buildmenuBottomPosition and not buildmenuAlwaysShow then
		buildmenuShowingPosY = posY
		if (not selectedUnits[1] or not WG['buildmenu'].getIsShowing()) then
			posY = 0
		end
	end
	if checkgroups then  -- this is the worlds stupides workaround for not creating display lists in intialize or update with unitpics too early, especially seen in save games and scenarios.
		checkUnitGroupsPos(true)
	end
	iconMargin = floor((backgroundPadding * 0.5) + 0.5)
	groupSize = floor((height * vsy) - (posY-height > 0 and backgroundPadding or 0))
	usedHeight = groupSize + (posY-height > 0 and backgroundPadding or 0)
end

function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	if not showWhenSpec and Spring.GetGameFrame() > 1 and spec then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Initialize()
	widget:ViewResize()
	widget:PlayerChanged()
	WG['idlebuilders'] = {}
	WG['idlebuilders'].getPosition = function()
		return posX, posY, backgroundRect and backgroundRect[3] or posX, backgroundRect and backgroundRect[4] or posY + usedHeight
	end
end

function widget:Shutdown()
	if dlist then
		gl.DeleteList(dlist)
	end
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('idlebuilders')
		dlistGuishader = nil
	end
	WG['idlebuilders'] = nil
end



local sec = 0
local sec2 = 0
local doUpdate = true
local timerStart = Spring.GetTimer()
function Update()
	if Spring.GetGameFrame() <1 then return end
	checkgroups = true
	if not (not spec or showWhenSpec) then
		return
	end

	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end
	local now = Spring.GetTimer()
	local dt = Spring.DiffTimers(now, timerStart)
	timerStart = now

	doUpdate = false
	sec = sec + dt
	sec2 = sec2 + dt

	checkUnitGroupsPos()

	local x, y, b, b2, b3 = spGetMouseState()
	if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		hovered = true

		local tooltipTitle = Spring.I18N('ui.idleBuilders.name')
		local tooltipAddition = ''
		if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			local alt, ctrl, meta, shift = Spring.GetModKeyState()
			for i,v in pairs(groupButtons) do
				if math_isInRect(x, y, groupButtons[i][1], groupButtons[i][2], groupButtons[i][3], groupButtons[i][4]) then
					local unitDefID = existingGroups[i]
					if unitDefID then
						tooltipTitle = Spring.I18N('ui.idleBuilders.idle', { unit = unitHumanName[unitDefID], highlightColor = "\255\190\255\190" })
						if #idleList[unitDefID] > 1 then
							tooltipAddition = Spring.I18N('ui.idleBuilders.controls').. '\n'..Spring.I18N('ui.idleBuilders.controls1')
						else
							tooltipAddition = tooltipAddition ..Spring.I18N('ui.idleBuilders.controls1')
						end
					end
					break
				end
			end
		end
		WG['tooltip'].ShowTooltip('idlebuilders', tooltipAddition, nil, nil, tooltipTitle)

		Spring.SetMouseCursor('cursornormal')
		if b then
			sec = sec + 0.4
		end
	elseif hovered then
		sec = sec + 0.5
		hovered = false
		doUpdate = true
	end


	if sec > 0.4 then
		sec = 0
		if WG['buildmenu'] then
			if buildmenuBottomPosition ~= WG['buildmenu'].getBottomPosition() or buildmenuIsShowing ~= WG['buildmenu'].getIsShowing() then
				widget:ViewResize()
				doUpdate = true
			end
		end
		if WG['ordermenu'] then
			local prevOrdermenuPosY = ordermenuPosY
			ordermenuPosY = select(2, WG['ordermenu'].getPosition())
			if ordermenuPosY ~= prevOrdermenuPosY then
				widget:ViewResize()
				doUpdate = true
			end
		end

		doUpdate = true	-- TODO: find a way to detect group changes and only doUpdate then
	elseif hovered and sec2 > 0.05 then
		sec2 = 0
		doUpdate = true
	end

	if doUpdate then
		updateList()
	end
end

function widget:DrawScreen()
	Update()
	if (not spec or showWhenSpec) and dlist then
		gl.CallList(dlist)
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end

	if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if button == 1 or button == 3 then
			for i,v in pairs(groupButtons) do
				if math_isInRect(x, y, groupButtons[i][1], groupButtons[i][2], groupButtons[i][3], groupButtons[i][4]) then
					local unitDefID = existingGroups[i]
					if unitDefID then
						local units = {}
						if shift then
							units = idleList[unitDefID]
						else
							local num = 1
							if #idleList[unitDefID] > 1 then
								if clicks[unitDefID] then
									clicks[unitDefID] = clicks[unitDefID] + 1
								else
									clicks[unitDefID] = 1
								end
								num = (clicks[unitDefID]) % (#idleList[unitDefID]) + 1
							end
							units = { idleList[unitDefID][num] }
						end
						Spring.SelectUnitArray(units)
					end
					if button == 3 then
						Spring.SendCommands("viewselection")
					end
					if playSounds then
						Spring.PlaySoundFile((button == 3 and rightclick or leftclick), soundVolume, 'ui')
					end
					return true
				end
			end
		end
		return true
	end
end

function widget:SelectionChanged(sel)
	selectedUnits = sel or {}
	selectionHasChanged = true
end


function widget:GetConfigData()
	return {
		alwaysShow = alwaysShow
	}
end

function widget:SetConfigData(data)
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
end
