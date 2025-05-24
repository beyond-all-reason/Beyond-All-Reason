local widget = widget ---@type Widget

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

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only
local useRenderToTextureBg = useRenderToTexture

local alwaysShow = true		-- always show AT LEAST the label
local alwaysShowLabel = true	-- always show the label regardless
local showWhenSpec = false
local showStack = false
local usedIconSizeMult = 0.98
local playSounds = true
local soundVolume = 0.5
local setHeight = 0.046
local maxIcons = 9
local showRez = true
local doUpdateForce = true

local leftclick = 'LuaUI/Sounds/buildbar_add.wav'
local rightclick = 'LuaUI/Sounds/buildbar_click.wav'

local vsx, vsy = Spring.GetViewGeometry()
local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local spec = Spring.GetSpectatingState()

local widgetSpaceMargin, backgroundPadding, elementCorner, RectRound, UiElement, UiUnit

local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetMouseState = Spring.GetMouseState
local spGetUnitCommands = Spring.GetUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
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
local iconSize = 0
local usedWidth = 0
local usedHeight = 0
local uiTexWidth = 1
local hovered = false
local prevHovered = false
local numIcons = 0
local hoveredIcon
local selectedUnits = Spring.GetSelectedUnits() or {}
local buildmenuShowingPosY = 0
local buildmenuAlwaysShow = false
local buildmenuIsShowing = true
local doUpdate = true

local iconButtons = {}
local existingIcons = {}
local clicks = {}
local unitList = {}

local idleList = {}

local font, font2, buildmenuBottomPosition, dlist, dlistGuishader, backgroundRect, ordermenuPosY

local unitHumanName = {}
local unitConf = {}
local function refreshUnitDefs()
	unitHumanName = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.translatedHumanName then
			unitHumanName[unitDefID] = unitDef.translatedHumanName
		end
		if unitDef.buildSpeed > 0 and not string.find(unitDef.name, 'spy') and (unitDef.canAssist or unitDef.buildOptions[1] or (showRez and unitDef.canResurrect)) and not unitDef.customParams.isairbase then
			unitConf[unitDefID] = unitDef.isFactory
		end
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, Spring.GetUnitTeam(unitID))
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if myTeamID == unitTeam and unitConf[unitDefID] ~= nil then
		unitList[unitID] = unitDefID
	end
end

function widget:VisibleUnitRemoved(unitID)
	unitList[unitID] = nil
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

local function drawBackground()
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0), nil, nil, nil, nil, nil, nil, nil, nil, useRenderToTextureBg)
end

local function drawContent()
	local mult = numIcons
	if numIcons == 0 then
		mult = 1
	end
	if mult > maxIcons then
		mult = maxIcons
		numIcons = mult
	end

	local iconWidth = iconSize - backgroundPadding
	local startOffsetX = 0
	if numIcons > 0 and alwaysShowLabel then
		startOffsetX = iconWidth
	end

	if numIcons == 0 or alwaysShowLabel then
		local iconRect = {
			floor(posX * vsx),
			floor(posY * vsy),
			floor(posX * vsx) + usedWidth - (iconWidth * numIcons),
			floor(posY * vsy) + usedHeight
		}
		local fontSize = height*vsy*0.33
		local offset = ((iconRect[3]-iconRect[1])/5)
		local offsetY = -(fontSize*(posY > 0 and 0.22 or 0.31))
		local style = 'c'
		font2:Begin()
		font2:SetOutlineColor(0.35,0.35,0.35,useRenderToTexture and 0.35 or 0.15)
		font2:SetTextColor(0.5,0.5,0.5,useRenderToTexture and 1 or 0.5)
		offset = (fontSize*0.6)
		font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), iconRect[1]+((iconRect[3]-iconRect[1])/2)-offset, iconRect[2]+((iconRect[4]-iconRect[2])/2)+offset+offsetY, fontSize, style)
		fontSize = fontSize * 1.2
		font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), iconRect[1]+((iconRect[3]-iconRect[1])/2), iconRect[2]+((iconRect[4]-iconRect[2])/2)+offsetY, fontSize, style)
		fontSize = fontSize * 1.2
		offset = (fontSize*0.48)
		font2:Print(Spring.I18N('ui.idleBuilders.sleeping'), iconRect[1]+((iconRect[3]-iconRect[1])/2)+offset, iconRect[2]+((iconRect[4]-iconRect[2])/2)-offset+offsetY, fontSize, style)
		font2:End()
	end


	if numIcons > 0 then
		local iconCounter = 0
		iconButtons = {}
		for i=1, maxIcons do
			if existingIcons[i] then
				local iconRect = {
					backgroundRect[1]+backgroundPadding+((iconSize-backgroundPadding)*iconCounter)+startOffsetX,
					backgroundRect[2]+(posY-height > 0 and backgroundPadding or 0),
					backgroundRect[1]+backgroundPadding+(iconSize-backgroundPadding)+((iconSize-backgroundPadding)*iconCounter)+startOffsetX,
					backgroundRect[4]-backgroundPadding
				}

				local unitCount = #idleList[existingIcons[i]]
				local unitDefID = existingIcons[i]

				gl.Color(1,1,1,1)
				iconButtons[#iconButtons+1] = {iconRect[1],iconRect[2],iconRect[3],iconRect[4],i}
				local iconSize = iconRect[3]-iconRect[1]-iconMargin-iconMargin
				local usedIconSize = iconSize * usedIconSizeMult
				local offset = 0
				if showStack then
					if unitCount > 4 then
						usedIconSize = floor(usedIconSize*0.78)
						offset = floor((iconSize - usedIconSize) / 4)
					elseif unitCount > 3 then
						usedIconSize = floor(usedIconSize*0.83)
						offset = floor((iconSize - usedIconSize) / 3)
					elseif unitCount> 2 then
						usedIconSize = floor(usedIconSize*0.86)
						offset = floor((iconSize - usedIconSize) / 2)
					elseif unitCount > 1 then
						usedIconSize = floor(usedIconSize*0.88)
						offset = iconSize - (usedIconSize*1.06)
					else
						usedIconSize = floor(usedIconSize*0.94)
						offset = iconSize - usedIconSize
					end
				end

				local texSize = floor(iconSize*1.33)
				local zoom = i == hoveredIcon and (b and 0.15 or 0.105) or 0.05
				local highlightOpacity = 0
				if i == hoveredIcon then
					highlightOpacity = 0.22
				end
				if showStack then
					if unitCount > 4 then
						drawIcon(
							unitDefID,
							{iconRect[1]+iconMargin+(offset*4), iconRect[4]-iconMargin-(offset*4)-usedIconSize, iconRect[1]+iconMargin+(offset*4)+usedIconSize, iconRect[4]-iconMargin-(offset*4)},
							0.33, zoom, texSize, highlightOpacity
						)
					end
					if unitCount > 3 then
						drawIcon(
							unitDefID,
							{iconRect[1]+iconMargin+(offset*3), iconRect[4]-iconMargin-(offset*3)-usedIconSize, iconRect[1]+iconMargin+(offset*3)+usedIconSize, iconRect[4]-iconMargin-(offset*3)},
							0.45, zoom, texSize, highlightOpacity
						)
					end
					if unitCount > 2 then
						drawIcon(
							unitDefID,
							{iconRect[1]+iconMargin+(offset*2), iconRect[4]-iconMargin-(offset*2)-usedIconSize, iconRect[1]+iconMargin+(offset*2)+usedIconSize, iconRect[4]-iconMargin-(offset*2)},
							0.55, zoom, texSize, highlightOpacity
						)
					end
					if unitCount > 1 then
						drawIcon(
							unitDefID,
							{iconRect[1]+iconMargin+offset, iconRect[4]-iconMargin-offset-usedIconSize, iconRect[1]+iconMargin+offset+usedIconSize, iconRect[4]-iconMargin-offset},
							0.7, zoom, texSize, highlightOpacity
						)
					end
				end
				drawIcon(
					unitDefID,
					{iconRect[1]+iconMargin, iconRect[4]-iconMargin-usedIconSize, iconRect[1]+iconMargin+usedIconSize, iconRect[4]-iconMargin},
					1, zoom, texSize, highlightOpacity
				)

				if unitCount > 1 then
					local fontSize = height*vsy*0.39
					font:Begin()
					font:Print('\255\240\240\240'..unitCount, iconRect[1]+iconMargin+(fontSize*0.18), iconRect[4]-iconMargin-(fontSize*0.92), fontSize, "o")
					font:End()
				end

				iconCounter = iconCounter + 1
			end
		end
	end
end

local function updateList(force)
	local prevIdleList = idleList
	idleList = {}
	local queue
	for unitID, unitDefID in pairs(unitList) do
		queue = unitConf[unitDefID] and spGetFactoryCommands(unitID, 0) or spGetUnitCommands(unitID, 0)
		if queue == 0 then
			if spValidUnitID(unitID) and not spGetUnitIsDead(unitID) and not spGetUnitIsBeingBuilt(unitID) then
				if idleList[unitDefID] then
					idleList[unitDefID][#idleList[unitDefID] + 1] = unitID
				else
					idleList[unitDefID] = { unitID }
				end
			end
		end
	end

	numIcons = 0
	existingIcons = {}
	for unitDefID, _ in pairs(idleList) do
		numIcons = numIcons + 1
		existingIcons[numIcons] = unitDefID
	end

	table.sort(existingIcons, function (a,b) return a < b end)

	local prevhoveredIcon = hoveredIcon
	hoveredIcon = -1
	local x, y = spGetMouseState()
	if iconButtons then
		for i,v in pairs(iconButtons) do
			if math_isInRect(x, y, iconButtons[i][1], iconButtons[i][2], iconButtons[i][3], iconButtons[i][4]) then
				hoveredIcon = iconButtons[i][5]
				break
			end
		end
	end

	-- compare with previous idle list
	if not force then
		local changes = false
		for unitDefID, units in pairs(prevIdleList) do
			if not idleList[unitDefID] or #idleList[unitDefID] ~= #units then
				changes = true
				break
			end
		end
		if not changes then
			for unitDefID, units in pairs(idleList) do
				if not prevIdleList[unitDefID] or #prevIdleList[unitDefID] ~= #units then
					changes = true
					break
				end
			end
		end
		if hovered ~= prevHovered then
			changes = true
		end
		prevHovered = hovered
		if not changes then
			if not hovered then
				return
			elseif hoveredIcon == prevhoveredIcon then
				return
			end
		end
	end

	if dlist then
		dlist = gl.DeleteList(dlist)
	end

	if numIcons == 0 and not alwaysShow then
		if backgroundRect then
			backgroundRect = nil
			checkGuishader(true)
		end
	else
		local mult = numIcons
		if numIcons == 0 then
			mult = 1
		end
		if mult > maxIcons then
			mult = maxIcons
			numIcons = mult
		end

		local iconWidth = iconSize - backgroundPadding
		local startOffsetX = 0
		if numIcons > 0 and alwaysShowLabel then
			startOffsetX = iconWidth
		end
		usedWidth = (iconWidth * mult) + backgroundPadding + backgroundPadding + startOffsetX
		if usedWidth > uiTexWidth then
			uiTexWidth = usedWidth
			if uiTex then
				gl.DeleteTextureFBO(uiTex)
				uiTex = nil
			end
		end
		local prevBackgroundX2 = backgroundRect and backgroundRect[3] or 0
		backgroundRect = {
			floor(posX * vsx),
			floor(posY * vsy),
			floor(posX * vsx) + usedWidth,
			floor(posY * vsy) + usedHeight
		}
		if uiBgTex and backgroundRect and backgroundRect[3] ~= prevBackgroundX2 then
			gl.DeleteTextureFBO(uiBgTex)
			uiBgTex = nil
		end

		if useRenderToTextureBg then
			if not uiBgTex then
				uiBgTex = gl.CreateTexture(math.floor(uiTexWidth), math.floor(backgroundRect[4]-backgroundRect[2]), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
				gl.RenderToTexture(uiBgTex, function()
					gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
					gl.PushMatrix()
					gl.Translate(-1, -1, 0)
					gl.Scale(2 / (backgroundRect[3]-backgroundRect[1]), 2 / (backgroundRect[4]-backgroundRect[2]),	0)
					gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
					drawBackground()
					gl.PopMatrix()
				end)
			end
		end
		if useRenderToTexture then
			if not uiTex then
				uiTex = gl.CreateTexture(math.floor(uiTexWidth)*2, math.floor(backgroundRect[4]-backgroundRect[2])*2, {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
			end
			gl.RenderToTexture(uiTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / uiTexWidth, 2 / (backgroundRect[4]-backgroundRect[2]),	0)
				gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
				drawContent()
				gl.PopMatrix()
			end)
		else
			dlist = gl.CreateList(function()
				if not useRenderToTextureBg then
					drawBackground()
				end
				drawContent()
			end)
		end

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
			doUpdateForce = true
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

local doCheckUnitGroupsPos = false
function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	height = setHeight * uiScale

	local outlineMult = math.clamp(1/(vsy/1400), 1, 2)
	font2 = WG['fonts'].getFont(nil, 1.2 * 1.8, 0.45 * 1.25*outlineMult, 1.3+(outlineMult*0.25))
	font = WG['fonts'].getFont(fontFile, 1.1 * 1.8, 0.45 * 1.25*outlineMult, 1.3+(outlineMult*0.25))

	elementCorner = WG.FlowUI.elementCorner
	backgroundPadding = WG.FlowUI.elementPadding
	widgetSpaceMargin = WG.FlowUI.elementMargin

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
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
	if doCheckUnitGroupsPos then  -- this is the worlds stupides workaround for not creating display lists in intialize or update with unitpics too early, especially seen in save games and scenarios.
		checkUnitGroupsPos(true)
	end
	iconMargin = floor((backgroundPadding * 0.5) + 0.5)
	iconSize = floor((height * vsy) - (posY-height > 0 and backgroundPadding or 0))
	usedHeight = iconSize + (posY-height > 0 and backgroundPadding or 0)

	if WG['unitgroups'] then
		local px, py, sx, sy = WG['unitgroups'].getPosition()
		local oldPosX, oldPosY = posX, posY
		posY = py / vsy
		posX = (sx + widgetSpaceMargin) / vsx
	end
end


function widget:LanguageChanged()
	refreshUnitDefs()
end

function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	if not showWhenSpec and spec then
		widgetHandler:RemoveWidget()
		return
	end
end

local initializeGameFrame = 0

function widget:Initialize()
	if not showWhenSpec and spec then
		widgetHandler:RemoveWidget()
		return
	end
	refreshUnitDefs()
	initializeGameFrame = Spring.GetGameFrame()
	widget:ViewResize()
	widget:PlayerChanged()
	WG['idlebuilders'] = {}
	WG['idlebuilders'].getPosition = function()
		return posX, posY, backgroundRect and backgroundRect[3] or posX, backgroundRect and backgroundRect[4] or posY + usedHeight
	end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

function widget:Shutdown()
	if dlist then
		gl.DeleteList(dlist)
	end
	if uiBgTex then
		gl.DeleteTextureFBO(uiBgTex)
	end
	if uiTex then
		gl.DeleteTextureFBO(uiTex)
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('idlebuilders')
		dlistGuishader = nil
	end
	WG['idlebuilders'] = nil
end



local sec = 0
local sec2 = 0
local timerStart = Spring.GetTimer()
local function Update()
	if Spring.GetGameFrame() <= initializeGameFrame and initializeGameFrame ~= 0 then
		return
	end
	doCheckUnitGroupsPos = true
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

	local x, y, b = spGetMouseState()
	if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		hovered = true

		local tooltipTitle = Spring.I18N('ui.idleBuilders.name')
		local tooltipAddition = ''
		if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			for i,v in pairs(iconButtons) do
				if math_isInRect(x, y, iconButtons[i][1], iconButtons[i][2], iconButtons[i][3], iconButtons[i][4]) then
					local unitDefID = existingIcons[i]
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
		if WG['tooltip'] then
			WG['tooltip'].ShowTooltip('idlebuilders', tooltipAddition, nil, nil, tooltipTitle)
		end

		Spring.SetMouseCursor('cursornormal')
		if b then
			sec = sec + 0.4
		end
	elseif hovered then
		sec = sec + 0.5
		hovered = false
		doUpdate = true
	end

	if sec > 0.33 then
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

		doUpdate = true	-- TODO: find a way to detect changes and only doUpdate then
	elseif hovered and sec2 > 0.05 then
		sec2 = 0
		doUpdate = true
	end
end

function widget:DrawScreen()
	Update()
	if doUpdate or doUpdateForce then
		updateList(doUpdateForce)
		doUpdate = false
		doUpdateForce = nil
	end
	if (not spec or showWhenSpec) and (dlist or uiTex or uiBgTex) then
		if useRenderToTextureBg then
			if uiBgTex then
				-- background element
				gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
				gl.Texture(uiBgTex)
				gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
				gl.Texture(false)
				gl.Color(1,1,1,1)
			end
		end
		if useRenderToTexture then
			if uiTex then
				--content
				gl.Color(1,1,1,1)
				gl.Texture(uiTex)
				gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[1]+uiTexWidth, backgroundRect[4], false, true)
				gl.Texture(false)
			end
		else
			gl.CallList(dlist)
		end
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end

	if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		local _, _, _, shift = Spring.GetModKeyState()
		if button == 1 or button == 3 then
			for i,v in pairs(iconButtons) do
				if math_isInRect(x, y, iconButtons[i][1], iconButtons[i][2], iconButtons[i][3], iconButtons[i][4]) then
					local unitDefID = existingIcons[i]
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
