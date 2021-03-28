function widget:GetInfo()
	return {
		name = "Unit Groups",
		desc = "",
		author = "Floris",
		date = "March 2021",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local showStack = true	-- display different unitdef pics in a showStack

local vsx, vsy = Spring.GetViewGeometry()
local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

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

local uiOpacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local setHeight = 0.055
local height = setHeight * uiScale
local posX = 0
local posY = 0
local hovered = false
local numGroups = 0

local stickToBottom = false
local altPosition = false
local groupButtons = {}

local font, font2, chobbyInterface, buildmenuBottomPosition, dlist, dlistGuishader, backgroundRect

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
	font = WG['fonts'].getFont(fontFile, 1.1, 0.25, 1.2)

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
		if omPosY-omHeight <= 0.01 then
			posX = omPosX + omWidth + (widgetSpaceMargin/vsx)
		else
			posY = omHeight + (widgetSpaceMargin/vsy)
		end
	end
end

function widget:PlayerChanged(playerID)
	if Spring.GetGameFrame() > 1 and Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
end

function widget:Initialize()
	widget:ViewResize()
	widget:PlayerChanged()
end

function widget:Shutdown()
	if dlist then
		gl.DeleteList(dlist)
	end
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('unitgroups')
		dlistGuishader = nil
	end
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

function updateList()
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
			local groupSize = floor(height * vsy)
			local width = ((groupSize-backgroundPadding) * numGroups) + backgroundPadding + backgroundPadding
			backgroundRect = {floor(posX * vsx), floor(posY * vsy), floor(posX * vsx + width), floor(posY * vsy) + groupSize}

			UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 1, 1, ((posY-height > 0 or posX <= 0) and 1 or 0), 0)

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
						backgroundRect[2],
						backgroundRect[1]+backgroundPadding+(groupSize-backgroundPadding)+((groupSize-backgroundPadding)*groupCounter),
						backgroundRect[4]-backgroundPadding
					}

					local unitdefCounts = spGetGroupUnitsCounts(group)

					local udefID_1
					local largestCount_1 = 0
					local unitdefCount = 0
					for uDefID, count in pairs(unitdefCounts) do
						if count > largestCount_1 then
							udefID_1 = uDefID
							largestCount_1 = count
						end
						unitdefCount = unitdefCount + 1
					end
					local udefID_2
					local largestCount_2 = 0
					if unitdefCount > 1 then
						for uDefID, count in pairs(unitdefCounts) do
							if uDefID ~= udefID_1 and count > largestCount_2 then
								udefID_2 = uDefID
								largestCount_2 = count
							end
						end
					end
					local udefID_3
					local largestCount_3 = 0
					if unitdefCount > 2 then
						for uDefID, count in pairs(unitdefCounts) do
							if uDefID ~= udefID_1 and uDefID ~= udefID_2 and count > largestCount_3 then
								udefID_3 = uDefID
								largestCount_3 = count
							end
						end
					end
					local udefID_4
					local largestCount_4 = 0
					if unitdefCount > 3 then
						for uDefID, count in pairs(unitdefCounts) do
							if uDefID ~= udefID_1 and uDefID ~= udefID_2 and uDefID ~= udefID_3 and count > largestCount_4 then
								udefID_4 = uDefID
								largestCount_4 = count
							end
						end
					end

					gl.Color(1,1,1,1)
					groupButtons[#groupButtons+1] = {groupRect[1],groupRect[2],groupRect[3],groupRect[4],group}
					local groupSize = groupRect[3]-groupRect[1]-iconMargin-iconMargin
					local iconSize = floor(groupSize * 0.94)
					local offset = 0
					if showStack then
						if unitdefCount > 4 then
							iconSize = floor(iconSize*0.81)
							offset = floor((groupSize - iconSize) / 4)
						elseif udefID_4 then
							iconSize = floor(iconSize*0.84)
							offset = floor((groupSize - iconSize) / 3)
						elseif udefID_3 then
							iconSize = floor(iconSize*0.88)
							offset = floor((groupSize - iconSize) / 2)
						elseif udefID_2 then
							iconSize = floor(iconSize*0.92)
							offset = groupSize - iconSize
						elseif udefID_4 then
							iconSize = floor(iconSize*0.92)
							offset = groupSize - iconSize
						end
					end

					if unitdefCount > 4 then
						gl.Color(0.15,0.15,0.15,1)
						UiUnit(
							groupRect[1]+iconMargin+(offset*4), groupRect[4]-iconMargin-(offset*4)-iconSize, groupRect[1]+iconMargin+(offset*4)+iconSize, groupRect[4]-iconMargin-(offset*4),
							math.ceil(backgroundPadding*0.5), 1,1,1,1,
							group == hoveredGroup and (b and 0.15 or 0.105) or 0.05,
							nil, nil,
							':lr'..floor(groupSize*1.5)..','..floor(groupSize*1.5)..':unitpics/'..unitBuildPic[udefID_4],
							nil, nil, nil, nil
						)
					end
					if udefID_4 then
						gl.Color(0.6,0.6,0.6,1)
						UiUnit(
							groupRect[1]+iconMargin+(offset*3), groupRect[4]-iconMargin-(offset*3)-iconSize, groupRect[1]+iconMargin+(offset*3)+iconSize, groupRect[4]-iconMargin-(offset*3),
							math.ceil(backgroundPadding*0.5), 1,1,1,1,
							group == hoveredGroup and (b and 0.15 or 0.105) or 0.05,
							nil, nil,
							':lr'..floor(groupSize*1.5)..','..floor(groupSize*1.5)..':unitpics/'..unitBuildPic[udefID_4],
							nil, nil, nil, nil
						)
					end
					if udefID_3 then
						gl.Color(0.66,0.66,0.66,1)
						UiUnit(
							groupRect[1]+iconMargin+(offset*2), groupRect[4]-iconMargin-(offset*2)-iconSize, groupRect[1]+iconMargin+(offset*2)+iconSize, groupRect[4]-iconMargin-(offset*2),
							math.ceil(backgroundPadding*0.5), 1,1,1,1,
							group == hoveredGroup and (b and 0.15 or 0.105) or 0.05,
							nil, nil,
							':lr'..floor(groupSize*1.5)..','..floor(groupSize*1.5)..':unitpics/'..unitBuildPic[udefID_3],
							nil, nil, nil, nil
						)
					end
					if udefID_2 then
						gl.Color(0.82,0.82,0.82,1)
						UiUnit(
							groupRect[1]+iconMargin+offset, groupRect[4]-iconMargin-offset-iconSize, groupRect[1]+iconMargin+offset+iconSize, groupRect[4]-iconMargin-offset,
							math.ceil(backgroundPadding*0.5), 1,1,1,1,
							group == hoveredGroup and (b and 0.15 or 0.105) or 0.05,
							nil, nil,
							':lr'..floor(groupSize*1.5)..','..floor(groupSize*1.5)..':unitpics/'..unitBuildPic[udefID_2],
							nil, nil, nil, nil
						)
					end
					gl.Color(1,1,1,1)
					UiUnit(
						groupRect[1]+iconMargin, groupRect[4]-iconMargin-iconSize, groupRect[1]+iconMargin+iconSize, groupRect[4]-iconMargin,
						math.ceil(backgroundPadding*0.5), 1,1,1,1,
						group == hoveredGroup and (b and 0.15 or 0.105) or 0.05,
						nil, nil,
						':lr'..floor(groupSize*1.5)..','..floor(groupSize*1.5)..':unitpics/'..unitBuildPic[udefID_1],
						nil, nil, nil, nil
					)

					if group == hoveredGroup then
						UiButton(groupRect[1]+iconMargin,groupRect[2]+iconMargin,groupRect[3]-iconMargin,groupRect[4]-iconMargin,  1,1,1,1,  1,1,1,1,  nil, {1,1,1,b and 0.22 or 0}, {1,1,1,b and 0.22 or 0}, nil)
					end

					local fontSize = height*vsy*0.3
					--font2:Begin()
					--font2:Print('\255\200\255\200'..group, groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.94), fontSize, "o")
					--font2:End()
					--font2:Begin()
					--font2:Print('\255\200\255\200'..group, groupRect[3]-iconMargin-(fontSize*0.16), groupRect[2] +iconMargin + (fontSize*0.28), fontSize, "ro")
					--font2:End()
					font2:Begin()
					font2:Print('\255\200\255\200'..group, groupRect[1]+((groupRect[3]-groupRect[1])/2), groupRect[2]+iconMargin + (fontSize*0.28), fontSize, "co")
					font2:End()
					fontSize = fontSize * 0.88
					--font:Begin()
					--font:Print('\255\210\210\210'..spGetGroupUnitsCount(group), groupRect[3]-iconMargin-(fontSize*0.16), groupRect[2] +iconMargin + (fontSize*0.28), fontSize, "ro")
					--font:End()
					font:Begin()
					font:Print('\255\220\220\220'..largestCount_1, groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.94), fontSize, "o")
					font:End()
					--font:Begin()
					--font:Print('\255\225\225\225'..spGetGroupUnitsCount(group), groupRect[1]+iconMargin+(fontSize*0.18), groupRect[4]-iconMargin-(fontSize*0.94), fontSize, "o")
					--font:End()
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
	if dlist then
		gl.CallList(dlist)
	end
end

local sec = 0
function widget:Update(dt)
	local x, y, b, b2, b3 = spGetMouseState()
	if backgroundRect and IsOnRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		hovered = true
		local tooltipAddition = ''
		if numGroups >= 1 then
			tooltipAddition = '\n\255\190\190\190'..Spring.I18N('ui.unitGroups.shiftclick')..'\n\255\190\190\190'..Spring.I18N('ui.unitGroups.ctrlclick')
		end
		WG['tooltip'].ShowTooltip('unitgroups', Spring.I18N('ui.unitGroups.name')..tooltipAddition)
		Spring.SetMouseCursor('cursornormal')
	elseif hovered then
		sec = sec + 0.5
		hovered = false
	end

	sec = sec + dt
	if sec > 0.5 then
		sec = 0

		if WG['buildmenu'] and WG['buildmenu'].getBottomPosition then
			local prevbuildmenuBottomPos = buildmenuBottomPos
			buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
			if buildmenuBottomPos ~= prevbuildmenuBottomPos then
				widget:ViewResize()
			end
		end
		if WG['ordermenu'] then
			local prevOrdermenuPosY = ordermenuPosY
			ordermenuPosY = select(2, WG['ordermenu'].getPosition())
			if ordermenuPosY ~= prevOrdermenuPosY then
				widget:ViewResize()
			end
		end
		if uiScale ~= Spring.GetConfigFloat("ui_scale", 1) then
			uiScale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
		end
		if uiOpacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.6)
		end
		updateList()
	elseif hovered and sec > 0.05 then
		sec = 0
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
						local units = Spring.GetSelectedUnits()
						local groupUnits = Spring.GetGroupUnits(groupButtons[i][5])
						for i=1, #groupUnits do
							units[#units+1] = groupUnits[i]
						end
						Spring.SelectUnitArray(units)
					elseif ctrl then
						local units = Spring.GetSelectedUnits()
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
						Spring.SelectUnitArray(newUnits)
					else
						Spring.SelectUnitArray(Spring.GetGroupUnits(groupButtons[i][5]))
					end
					return true
				end
			end
		end
		return true
	end
end
