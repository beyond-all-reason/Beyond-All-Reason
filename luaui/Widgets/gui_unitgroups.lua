local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Groups",
		desc = "Interface to shows unit groups (via stacked icons)",
		author = "Floris",
		date = "March 2021",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only
local useRenderToTextureBg = useRenderToTexture

local alwaysShow = true		-- always show AT LEAST the label
local alwaysShowLabel = true	-- always show the label regardless
local showWhenSpec = false
local showStack = true	-- display different unitdef pics in a showStack
local iconSizeMult = 0.98
local highlightSelectedGroups = true
local playSounds = true
local soundVolume = 0.5
local setHeight = 0.046

local leftclick = 'LuaUI/Sounds/buildbar_add.wav'
local rightclick = 'LuaUI/Sounds/buildbar_click.wav'

local vsx, vsy = Spring.GetViewGeometry()

local spec = Spring.GetSpectatingState()

local widgetSpaceMargin, backgroundPadding, elementCorner, RectRound, UiElement, UiUnit

local spGetGroupList = Spring.GetGroupList
local spGetGroupUnitsCounts = Spring.GetGroupUnitsCounts
local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spGetMouseState = Spring.GetMouseState
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
local uiTexWidth = 1
local hovered = false
local numGroups = 0
local selectedUnits = Spring.GetSelectedUnits() or {}
local selectionHasChanged = true
local selectedGroups = {}
local doUpdate = true

local groupButtons = {}

local font, font2, buildmenuBottomPosition, dlist, dlistGuishader, backgroundRect, ordermenuPosY
local buildmenuAlwaysShow = false
local buildmenuShowingPosY = 0

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	height = setHeight * uiScale

	font2 = WG['fonts'].getFont()
	font = WG['fonts'].getFont(2)

	elementCorner = WG.FlowUI.elementCorner
	backgroundPadding = WG.FlowUI.elementPadding
	widgetSpaceMargin = WG.FlowUI.elementMargin

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	if WG['buildmenu'] then
		buildmenuBottomPosition = WG['buildmenu'].getBottomPosition()
		buildmenuAlwaysShow = WG['buildmenu'].getAlwaysShow()
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

	iconMargin = floor((backgroundPadding * 0.5) + 0.5)
	groupSize = floor((height * vsy) - (posY-height > 0 and backgroundPadding or 0))
	usedHeight = groupSize + (posY-height > 0 and backgroundPadding or 0)

	if uiTex then
		gl.DeleteTextureFBO(uiBgTex)
		uiBgTex = nil
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
end

function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
	if not showWhenSpec and Spring.GetGameFrame() > 1 and spec then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Initialize()
	widget:ViewResize()
	widget:PlayerChanged()
	WG['unitgroups'] = {}
	WG['unitgroups'].getPosition = function()
		return posX, backgroundRect and backgroundRect[2] or posY, backgroundRect and backgroundRect[3] or posX, backgroundRect and backgroundRect[4] or posY + usedHeight
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
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('unitgroups')
		dlistGuishader = nil
	end
	WG['unitgroups'] = nil
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			WG['guishader'].RemoveDlist('unitgroups')
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader and backgroundRect then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner, ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0))
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'unitgroups')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function drawIcon(unitDefID, rect, lightness, zoom, texSize, highlightOpacity)
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
	local existingGroups = spGetGroupList()
	numGroups = 0
	for group, _ in pairs(existingGroups) do
		numGroups = numGroups + 1
	end

	local groupWidth = groupSize - backgroundPadding
	local startOffsetX = 0
	if numGroups > 0 and alwaysShowLabel then
		startOffsetX = groupWidth
	end

	if numGroups == 0 or alwaysShowLabel then
		local groupRect = {
			floor(posX * vsx),
			floor(posY * vsy),
			floor(posX * vsx) + usedWidth - (groupWidth * numGroups),
			floor(posY * vsy) + usedHeight
		}
		local fontSize = height*vsy*0.25
		local offset = ((groupRect[3]-groupRect[1])/4.2)
		local offsetY = -(fontSize*(posY > 0 and 0.31 or 0.44))
		local style = 'co'
		font2:Begin()
		font2:SetOutlineColor(0.2, 0.2, 0.2, useRenderToTexture and 0.75 or 0.15)
		font2:SetTextColor(0.5,0.5,0.5,1)
		font2:Print(1, groupRect[1]+((groupRect[3]-groupRect[1])/2)-offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)+offset+offsetY, fontSize, style)
		font2:Print(2, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+((groupRect[4]-groupRect[2])/2)+offset+offsetY, fontSize, style)
		font2:Print(3, groupRect[1]+((groupRect[3]-groupRect[1])/2)+offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)+offset+offsetY, fontSize, style)

		font2:Print(4, groupRect[1]+((groupRect[3]-groupRect[1])/2)-offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)+offsetY, fontSize, style)
		font2:Print(5, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+((groupRect[4]-groupRect[2])/2)+offsetY, fontSize, style)
		font2:Print(6, groupRect[1]+((groupRect[3]-groupRect[1])/2)+offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)+offsetY, fontSize, style)

		font2:Print(7, groupRect[1]+((groupRect[3]-groupRect[1])/2)-offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)-offset+offsetY, fontSize, style)
		font2:Print(8, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+((groupRect[4]-groupRect[2])/2)-offset+offsetY, fontSize, "c")
		font2:Print(9, groupRect[1]+((groupRect[3]-groupRect[1])/2)+offset, groupRect[2]+((groupRect[4]-groupRect[2])/2)-offset+offsetY, fontSize, style)
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
		for group=0, 9 do
			if existingGroups[group] then
				local groupRect = {
					backgroundRect[1]+backgroundPadding+((groupSize-backgroundPadding)*groupCounter)+startOffsetX,
					backgroundRect[2]+(posY-height > 0 and backgroundPadding or 0),
					backgroundRect[1]+backgroundPadding+(groupSize-backgroundPadding)+((groupSize-backgroundPadding)*groupCounter)+startOffsetX,
					backgroundRect[4]-backgroundPadding
				}

				local unitdefCounts = spGetGroupUnitsCounts(group)
				local unitdefCount = 0
				local udefID_1
				local udefID_2
				local udefID_3
				local udefID_4
				local udefID_5
				local largestCount_1 = 0
				local largestCount_2 = 0
				local largestCount_3 = 0
				local largestCount_4 = 0
				local largestCount_5 = 0
				for uDefID, count in pairs(unitdefCounts) do
					if count > largestCount_1 then
						udefID_1 = uDefID
						largestCount_1 = count
					end
					unitdefCount = unitdefCount + 1
				end
				if unitdefCount > 1 then
					for uDefID, count in pairs(unitdefCounts) do
						if uDefID ~= udefID_1 and count > largestCount_2 then
							udefID_2 = uDefID
							largestCount_2 = count
						end
					end
					if unitdefCount > 2 then
						for uDefID, count in pairs(unitdefCounts) do
							if uDefID ~= udefID_1 and uDefID ~= udefID_2 and count > largestCount_3 then
								udefID_3 = uDefID
								largestCount_3 = count
							end
						end
						if unitdefCount > 3 then
							for uDefID, count in pairs(unitdefCounts) do
								if uDefID ~= udefID_1 and uDefID ~= udefID_2 and uDefID ~= udefID_3 and count > largestCount_4 then
									udefID_4 = uDefID
									largestCount_4 = count
								end
							end
							if unitdefCount > 3 then
								for uDefID, count in pairs(unitdefCounts) do
									if uDefID ~= udefID_1 and uDefID ~= udefID_2 and uDefID ~= udefID_3 and uDefID ~= udefID_4 and count > largestCount_5 then
										udefID_5 = uDefID
										largestCount_5 = count
									end
								end
							end
						end
					end
				end

				gl.Color(1,1,1,1)
				groupButtons[#groupButtons+1] = {groupRect[1],groupRect[2],groupRect[3],groupRect[4],group}
				local groupSize = groupRect[3]-groupRect[1]-iconMargin-iconMargin
				local iconSize = groupSize * iconSizeMult
				local offset = 0
				if showStack then
					if udefID_5 then
						iconSize = floor(iconSize*0.78)
						offset = floor((groupSize - iconSize) / 4)
					elseif udefID_4 then
						iconSize = floor(iconSize*0.83)
						offset = floor((groupSize - iconSize) / 3)
					elseif udefID_3 then
						iconSize = floor(iconSize*0.86)
						offset = floor((groupSize - iconSize) / 2)
					elseif udefID_2 then
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
					highlightOpacity = 0.17
					zoom = zoom + 0.08
				elseif group == hoveredGroup then
					highlightOpacity = 0.22
				end
				if showStack then
					if udefID_5 then
						drawIcon(
							udefID_5,
							{groupRect[1]+iconMargin+(offset*4), groupRect[4]-iconMargin-(offset*4)-iconSize, groupRect[1]+iconMargin+(offset*4)+iconSize, groupRect[4]-iconMargin-(offset*4)},
							0.33, zoom, texSize, highlightOpacity
						)
					end
					if udefID_4 then
						drawIcon(
							udefID_4,
							{groupRect[1]+iconMargin+(offset*3), groupRect[4]-iconMargin-(offset*3)-iconSize, groupRect[1]+iconMargin+(offset*3)+iconSize, groupRect[4]-iconMargin-(offset*3)},
							0.45, zoom, texSize, highlightOpacity
						)
					end
					if udefID_3 then
						drawIcon(
							udefID_3,
							{groupRect[1]+iconMargin+(offset*2), groupRect[4]-iconMargin-(offset*2)-iconSize, groupRect[1]+iconMargin+(offset*2)+iconSize, groupRect[4]-iconMargin-(offset*2)},
							0.55, zoom, texSize, highlightOpacity
						)
					end
					if udefID_2 then
						drawIcon(
							udefID_2,
							{groupRect[1]+iconMargin+offset, groupRect[4]-iconMargin-offset-iconSize, groupRect[1]+iconMargin+offset+iconSize, groupRect[4]-iconMargin-offset},
							0.7, zoom, texSize, highlightOpacity
						)
					end
				end
				drawIcon(
					udefID_1,
					{groupRect[1]+iconMargin, groupRect[4]-iconMargin-iconSize, groupRect[1]+iconMargin+iconSize, groupRect[4]-iconMargin},
					1, zoom, texSize, highlightOpacity
				)

				local fontSize = height*vsy*0.4
				font2:Begin()
				font2:Print('\255\200\255\200'..group, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+iconMargin + (fontSize*0.28), fontSize, "co")
				font2:End()
				local amount = (showStack and largestCount_1 or spGetGroupUnitsCount(group))
				if amount > 1 then
					fontSize = height*vsy*0.3
					font:Begin()
					font:Print('\255\240\240\240'..amount, groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.92), fontSize, "o")
					font:End()
				end

				groupCounter = groupCounter + 1
			end
		end
	end
end

local function updateList()
	if dlist then
		dlist = gl.DeleteList(dlist)
	end

	local existingGroups = spGetGroupList()
	numGroups = 0
	for group, _ in pairs(existingGroups) do
		numGroups = numGroups + 1
	end
	if numGroups == 0 and not alwaysShow then
		if backgroundRect then
			backgroundRect = nil
			checkGuishader(true)
		end
	else

		local mult = numGroups
		if numGroups == 0 then
			mult = 1
		end

		local groupWidth = groupSize - backgroundPadding
		local startOffsetX = 0
		if numGroups > 0 and alwaysShowLabel then
			startOffsetX = groupWidth
		end
		usedWidth = (groupWidth * mult) + backgroundPadding + backgroundPadding + startOffsetX
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

function widget:DrawScreen()
	if doUpdate then
		doUpdate = false
		updateList()
	end
	if (not spec or showWhenSpec) and (dlist or uiBgTex) then
		if uiBgTex then
			-- background element
			gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
			gl.Texture(uiBgTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], false, true)
			gl.Texture(false)
		end
		if not useRenderToTexture then
			gl.CallList(dlist)
		end
		if uiTex then
			-- content
			gl.Color(1,1,1,1)
			gl.Texture(uiTex)
			gl.TexRect(backgroundRect[1], backgroundRect[2], backgroundRect[1]+uiTexWidth, backgroundRect[4], false, true)
			gl.Texture(false)
		end
	end
end

local sec = 0
local sec2 = 0
function widget:Update(dt)
	if not (not spec or showWhenSpec) then
		return
	end

	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	doUpdate = false
	sec = sec + dt
	sec2 = sec2 + dt

	if WG['buildmenu'] then
		if buildmenuAlwaysShow ~= WG['buildmenu'].getAlwaysShow() then
			widget:ViewResize()
			doUpdate = true
		end
		if buildmenuBottomPosition and not buildmenuAlwaysShow and WG['info'] then
			if (not selectedUnits[1] or not WG['buildmenu'].getIsShowing()) and (posX > 0 or not WG['info'].getIsShowing()) then
				if posY ~= 0 then
					posY = 0
					doUpdate = true
				end
			else
				if posY ~= buildmenuShowingPosY then
					posY = buildmenuShowingPosY
					doUpdate = true
				end
			end
		end
	end

	local x, y, b = spGetMouseState()
	if backgroundRect and math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		hovered = true
		local tooltipAddition = ''
		if numGroups >= 1 then
			tooltipAddition = tooltipAddition .. Spring.I18N('ui.unitGroups.shiftclick')..'\n'..Spring.I18N('ui.unitGroups.ctrlclick')..'\n'..Spring.I18N('ui.unitGroups.rightclick')
		end
		tooltipAddition = tooltipAddition .. (tooltipAddition~='' and '\n' or '') .. Spring.I18N('ui.unitGroups.tooltip')
		if WG['autogroup'] ~= nil then
			tooltipAddition = tooltipAddition .. (tooltipAddition~='' and '\n\n' or '') .. "\255\200\255\200" .. Spring.I18N('ui.unitGroups.autogroupTooltip')
		end
		if WG['tooltip'] then
			WG['tooltip'].ShowTooltip('unitgroups', tooltipAddition, nil, nil, Spring.I18N('ui.unitGroups.name'))
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

	if sec > 0.5 then
		sec = 0

		if highlightSelectedGroups and selectionHasChanged then
			selectionHasChanged = nil

			local existingGroups = spGetGroupList()
			local selectedUnitID = {}
			for i = 1, #selectedUnits do
				selectedUnitID[selectedUnits[i]] = true
			end
			local groupUnitCount = {}
			local groupUnitSelectedCount = {}
			for group, _ in pairs(existingGroups) do
				groupUnitSelectedCount[group] = 0
				local groupUnits = Spring.GetGroupUnits(group)
				groupUnitCount[group] = #groupUnits
				for i=1, #groupUnits do
					if selectedUnitID[groupUnits[i]] then
						groupUnitSelectedCount[group] = groupUnitSelectedCount[group] + 1
					end
				end
			end
			local prevSelectedGroups = selectedGroups
			selectedGroups = {}
			for group, _ in pairs(groupUnitSelectedCount) do
				if groupUnitSelectedCount[group] == groupUnitCount[group] then
					selectedGroups[group] = true
				end
			end
			local changed = false
			for group, _ in pairs(selectedGroups) do
				if not prevSelectedGroups[group] then
					doUpdate = true
					break
				end
			end
			if not doUpdate then
				for group, _ in pairs(prevSelectedGroups) do
					if not selectedGroups[group] then
						doUpdate = true
						break
					end
				end
			end
		end

		if WG['buildmenu'] and WG['buildmenu'].getBottomPosition then
			local prevbuildmenuBottomPos = buildmenuBottomPos
			buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
			if buildmenuBottomPos ~= prevbuildmenuBottomPos then
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
					if shift then
						local units = selectedUnits
						local groupUnits = Spring.GetGroupUnits(groupButtons[i][5])
						for i=1, #groupUnits do
							units[#units+1] = groupUnits[i]
						end
						selectedUnits = units
						selectionHasChanged = true
						Spring.SelectUnitArray(units)
					elseif ctrl then
						local units = selectedUnits
						local groupUnits = Spring.GetGroupUnits(groupButtons[i][5])
						local keyGroupUnits = {}
						for i=1, #groupUnits do
							keyGroupUnits[groupUnits[i]] = true
						end
						local newUnits = {}
						for i=1, #units do
							if not keyGroupUnits[units[i]] then
								newUnits[#newUnits+1] = units[i]
							end
						end
						selectedUnits = newUnits
						selectionHasChanged = true
						Spring.SelectUnitArray(selectedUnits)
					else
						selectedUnits = Spring.GetGroupUnits(groupButtons[i][5])
						selectionHasChanged = true
						Spring.SelectUnitArray(selectedUnits)
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
