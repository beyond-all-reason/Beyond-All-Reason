function widget:GetInfo()
	return {
		name = "Unit Groups",
		desc = "Interface shows unit groups via stacked icons",
		author = "Floris",
		date = "March 2021",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local showWhenSpec = true
local showStack = true	-- display different unitdef pics in a showStack
local iconSizeMult = 0.98
local highlightSelectedGroups = true

local vsx, vsy = Spring.GetViewGeometry()
local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local spec = Spring.GetSpectatingState()

local widgetSpaceMargin = Spring.FlowUI.elementMargin
local backgroundPadding = Spring.FlowUI.elementPadding
local elementCorner = Spring.FlowUI.elementCorner
local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local UiButton = Spring.FlowUI.Draw.Button
local UiUnit = Spring.FlowUI.Draw.Unit

local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroupList = Spring.GetGroupList
local spGetGroupUnitsCounts = Spring.GetGroupUnitsCounts
local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spGetMouseState = Spring.GetMouseState
local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local uiOpacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local setHeight = 0.055
local height = setHeight * uiScale
local posX = 0
local posY = 0
local hovered = false
local numGroups = 0
local selectedUnits = Spring.GetSelectedUnits() or {}
local selectionHasChanged = true
local highlightGroups = {}

local stickToBottom = false
local altPosition = false
local groupButtons = {}

local font, font2, chobbyInterface, buildmenuBottomPosition, dlist, dlistGuishader, backgroundRect, ordermenuPosY

local unitBuildPic = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildpicname then
		unitBuildPic[unitDefID] = unitDef.buildpicname
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	height = setHeight * uiScale

	font2 = WG['fonts'].getFont(nil, 1.3, 0.35, 1.4)
	font = WG['fonts'].getFont(fontFile, 1.15, 0.35, 1.25)

	elementCorner = Spring.FlowUI.elementCorner
	backgroundPadding = Spring.FlowUI.elementPadding
	widgetSpaceMargin = Spring.FlowUI.elementMargin

	if WG['buildmenu'] then
		buildmenuBottomPosition = WG['buildmenu'].getBottomPosition()
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
end

function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
	if Spring.GetGameFrame() > 1 and spec then
		--widgetHandler:RemoveWidget(self)
		return
	end
end

function widget:Initialize()
	widget:ViewResize()
	widget:PlayerChanged()
	WG['unitgroups'] = {}
	WG['unitgroups'].getPosition = function()
		return posX, posY, backgroundRect and backgroundRect[3] or posX, backgroundRect and backgroundRect[4] or posY
	end
end

function widget:Shutdown()
	if dlist then
		gl.DeleteList(dlist)
	end
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('unitgroups')
		dlistGuishader = nil
	end
	WG['unitgroups'] = nil
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			--WG['guishader'].DeleteDlist('unitgroups')
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader and backgroundRect then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'unitgroups')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

local function drawIcon(unitDefID, rect, lightness, zoom, texSize, highlighted)
	gl.Color(lightness,lightness,lightness,1)
	UiUnit(
		rect[1], rect[2], rect[3], rect[4],
		ceil(backgroundPadding*0.5), 1,1,1,1,
		zoom,
		nil, highlighted and 0.25 or nil,
		':lr'..texSize..','..texSize..':unitpics/'..unitBuildPic[unitDefID],
		nil, nil, nil, nil
	)
	if highlighted then
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		gl.Color(1,1,1,0.15)
		RectRound(rect[1], rect[2], rect[3], rect[4], min(max(1, floor((rect[3]-rect[1]) * 0.024)), floor((vsy*0.0015)+0.5)))
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
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
	if numGroups == 0 then
		if backgroundRect then
			backgroundRect = nil
			checkGuishader(true)
		end
	else
		dlist = gl.CreateList(function()
			local iconMargin = floor((backgroundPadding * 0.5) + 0.5)
			local groupSize = floor((height * vsy) - (posY-height > 0 and backgroundPadding or 0))
			local width = ((groupSize-backgroundPadding) * numGroups) + backgroundPadding + backgroundPadding
			backgroundRect = {floor(posX * vsx), floor(posY * vsy), floor(posX * vsx + width), floor(posY * vsy) + groupSize + (posY-height > 0 and backgroundPadding or 0)}

			UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], ((posX <= 0) and 0 or 1), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), ((posY-height > 0 and posX > 0) and 1 or 0))

			local hoveredGroup = -1
			local x, y, b, b2, b3 = spGetMouseState()
			if groupButtons then
				for i,v in pairs(groupButtons) do
					if IsOnRect(x, y, groupButtons[i][1], groupButtons[i][2], groupButtons[i][3], groupButtons[i][4]) then
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
						backgroundRect[1]+backgroundPadding+((groupSize-backgroundPadding)*groupCounter),
						backgroundRect[2]+(posY-height > 0 and backgroundPadding or 0),
						backgroundRect[1]+backgroundPadding+(groupSize-backgroundPadding)+((groupSize-backgroundPadding)*groupCounter),
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
					local borderOpacity, iconrect
					local zoom = group == hoveredGroup and (b and 0.15 or 0.105) or 0.05
					local highlightOpacity = 0
					local groupHighlighted = highlightGroups[group]
					if groupHighlighted then
						borderOpacity = 0.2
						zoom = zoom + 0.08
						highlightOpacity = 0.15
					end
					if showStack then
						if udefID_5 then
							drawIcon(
									udefID_5,
									{groupRect[1]+iconMargin+(offset*4), groupRect[4]-iconMargin-(offset*4)-iconSize, groupRect[1]+iconMargin+(offset*4)+iconSize, groupRect[4]-iconMargin-(offset*4)},
									0.33, zoom, texSize, groupHighlighted
							)
						end
						if udefID_4 then
							drawIcon(
									udefID_4,
									{groupRect[1]+iconMargin+(offset*3), groupRect[4]-iconMargin-(offset*3)-iconSize, groupRect[1]+iconMargin+(offset*3)+iconSize, groupRect[4]-iconMargin-(offset*3)},
									0.45, zoom, texSize, groupHighlighted
							)
						end
						if udefID_3 then
							drawIcon(
									udefID_3,
									{groupRect[1]+iconMargin+(offset*2), groupRect[4]-iconMargin-(offset*2)-iconSize, groupRect[1]+iconMargin+(offset*2)+iconSize, groupRect[4]-iconMargin-(offset*2)},
									0.55, zoom, texSize, groupHighlighted
							)
							iconrect = {groupRect[1]+iconMargin+(offset*2), groupRect[4]-iconMargin-(offset*2)-iconSize, groupRect[1]+iconMargin+(offset*2)+iconSize, groupRect[4]-iconMargin-(offset*2)}
						end
						if udefID_2 then
							drawIcon(
									udefID_2,
									{groupRect[1]+iconMargin+offset, groupRect[4]-iconMargin-offset-iconSize, groupRect[1]+iconMargin+offset+iconSize, groupRect[4]-iconMargin-offset},
									0.7, zoom, texSize, groupHighlighted
							)
						end
					end
					drawIcon(
						udefID_1,
						{groupRect[1]+iconMargin, groupRect[4]-iconMargin-iconSize, groupRect[1]+iconMargin+iconSize, groupRect[4]-iconMargin},
						1, zoom, texSize, groupHighlighted
					)

					if group == hoveredGroup then
						UiButton(groupRect[1],groupRect[2],groupRect[3],groupRect[4],  1,1,1,1,  1,1,1,1,  nil, {1,1,1,b and 0.22 or 0}, {1,1,1,b and 0.22 or 0}, nil)
					end

					local fontSize = height*vsy*0.3
					font2:Begin()
					font2:Print('\255\200\255\200'..group, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+iconMargin + (fontSize*0.28), fontSize, "co")
					font2:End()
					fontSize = fontSize * 0.88
					font:Begin()
					font:Print('\255\230\230\230'..(showStack and largestCount_1 or spGetGroupUnitsCount(group)), groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.92), fontSize, "o")
					font:End()

					groupCounter = groupCounter + 1
				end
			end
		end)
		checkGuishader(true)
	end

end

function IsOnRect(x, y, BLcornerX, BLcornerY, TRcornerX, TRcornerY)
	return x >= BLcornerX and x <= TRcornerX and y >= BLcornerY and y <= TRcornerY
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if (not spec or showWhenSpec) and dlist then
		gl.CallList(dlist)
	end
end

local sec = 0
local sec2 = 0
function widget:Update(dt)
	if not (not spec or showWhenSpec) then
		return
	end
	local doUpdate = false
	sec = sec + dt
	sec2 = sec2 + dt

	local x, y, b, b2, b3 = spGetMouseState()
	if backgroundRect and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		hovered = true
		local tooltipAddition = ''
		if numGroups >= 1 then
			tooltipAddition = '\n\255\190\190\190'..Spring.I18N('ui.unitGroups.shiftclick')..'\n\255\190\190\190'..Spring.I18N('ui.unitGroups.ctrlclick')
		end
		WG['tooltip'].ShowTooltip('unitgroups', Spring.I18N('ui.unitGroups.name')..tooltipAddition)
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
			local prevHighlightGroups = highlightGroups
			highlightGroups = {}
			for group, _ in pairs(groupUnitSelectedCount) do
				if groupUnitSelectedCount[group] == groupUnitCount[group] then
					highlightGroups[group] = true
				end
			end
			local changed = false
			for group, _ in pairs(highlightGroups) do
				if not prevHighlightGroups[group] then
					doUpdate = true
					break
				end
			end
			if not doUpdate then
				for group, _ in pairs(prevHighlightGroups) do
					if not highlightGroups[group] then
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
		if uiScale ~= Spring.GetConfigFloat("ui_scale", 1) then
			uiScale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
			doUpdate = true
		end
		if uiOpacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			doUpdate = true
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

local function tableMerge(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end


function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end

	if backgroundRect and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if button == 1 then
			for i,v in pairs(groupButtons) do
				if IsOnRect(x, y, groupButtons[i][1], groupButtons[i][2], groupButtons[i][3], groupButtons[i][4]) then
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
