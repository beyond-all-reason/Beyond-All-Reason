local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Game info",
		desc = "",
		author = "Floris",
		date = "May 2017",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end

local titlecolor = "\255\255\205\100"
local keycolor = ""
local valuecolor = "\255\255\255\255"
local valuegreycolor = "\255\180\180\180"
local separator = "::"

local font, font2, loadedFontSize, mainDList, titleRect, backgroundGuishader, show
local maxLines = 22
local math_isInRect = math.isInRect

local raptorsEnabled = Spring.Utilities.Gametype.IsRaptors()

local content = ''

local tidal = Game.tidal
local map_tidal = Spring.GetModOptions().map_tidal
local reclaimable_metal = 0
local reclaimable_energy = 0

if map_tidal == "unchanged" then
elseif map_tidal == "low" then
	tidal = 13
elseif map_tidal == "medium" then
	tidal = 18
elseif map_tidal == "high" then
	tidal = 23
end

if Spring.GetTidal then
	tidal = Spring.GetTidal()
end

-- modoptions
local defaultModoptions = VFS.Include("modoptions.lua")
local modoptionsDefault = {}
for key, value in pairs(defaultModoptions) do
	modoptionsDefault[value.key] = {name = value.name, desc = value.desc, def = value.def}
end

local modoptions = Spring.GetModOptionsCopy()
local changedModoptions = {}
local unchangedModoptions = {}
local changedRaptorModoptions = {}
local unchangedRaptorModoptions = {}
for key, value in pairs(modoptions) do
	if string.sub(key, 1, 8) == 'raptor_' then
		if raptorsEnabled then
			if value == modoptionsDefault[key].def then
				unchangedRaptorModoptions[key] = tostring(value)
			else
				changedRaptorModoptions[key] = tostring(value)
			end
		end
	end
end



local function stringifyDefTable(t, path, pathAddition)
	if not path then path = {} end
	path = table.copy(path)
	if pathAddition then
		path[#path+1] = pathAddition
	end
	if #path > 10 then return '...' end
	local text = ''
	local depthSpacing = ''
	for i=1, #path, 1 do
		depthSpacing = depthSpacing .. '     '
	end
	for k, v in pairs(t) do
		if type(v) == "table" then
			text = text .. '\n' .. valuegreycolor .. depthSpacing .. tostring(k) .. ' = {'
			text = text .. stringifyDefTable(v, path, k)
			text = text .. '\n' .. valuegreycolor .. depthSpacing .. '}'
		else
			text = text .. '\n' .. valuegreycolor .. depthSpacing .. tostring(k) .. ' = ' .. tostring(v)
		end
	end
	return text
end

for key, value in pairs(modoptions) do
	if modoptionsDefault[key] and value == modoptionsDefault[key].def then
		unchangedModoptions[key] = tostring(value)
	else
		if not string.find(key, 'tweakunits') and not string.find(key, 'tweakdefs') then
			changedModoptions[key] = tostring(value)
		else
			if string.find(key, 'tweakdefs') then
				local decodeSuccess, postsFuncStr = pcall(string.base64Decode, value)
				changedModoptions[key] = '\n' .. (decodeSuccess and postsFuncStr or '\255\255\100\100 - '..Spring.I18N('ui.gameInfo.decodefailed').. ' - ')
			else
				local success, tweaks = pcall(Spring.Utilities.CustomKeyToUsefulTable, value)
				if success and type(tweaks) == "table" then
					local text = ''
					for name, ud in pairs(tweaks) do
						if UnitDefNames[name] then
							text = text .. '\n' .. valuecolor.. name..valuegreycolor..' = {'
							text = text..stringifyDefTable(ud, {}, name)
							text = text .. '\n' .. '}'
						end
					end
					changedModoptions[key] = text
				else
					changedModoptions[key] = tostring(value)
				end
			end
		end
	end
end

local function SortFunc(myTable)
	local function pairsByKeys(t, f)
		local a = {}
		for n in pairs(t) do
			table.insert(a, n)
		end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
			i = i + 1
			if a[i] == nil then
				return nil
			else
				return a[i], t[a[i]]
			end
		end
		return iter
	end
	local t = {}
	for key,value in pairsByKeys(myTable) do
		table.insert(t, { key = key, value = value })
	end
	return t
end
changedModoptions = SortFunc(changedModoptions)
unchangedModoptions = SortFunc(unchangedModoptions)
changedRaptorModoptions = SortFunc(changedRaptorModoptions)
unchangedRaptorModoptions = SortFunc(unchangedRaptorModoptions)

local screenHeightOrg = 540
local screenWidthOrg = 540
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local startLine = 1

local vsx, vsy = Spring.GetViewGeometry()
local screenX = (vsx * 0.5) - (screenWidth / 2)
local screenY = (vsy * 0.5) + (screenHeight / 2)

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local widgetScale = (vsy / 1080)

local fileLines = {}
local totalFileLines = 0

local showOnceMore = false        -- used because of GUI shader delay

local RectRound, UiElement, UiScroller, elementCorner

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)

	screenX = math.floor((vsx * 0.5) - (screenWidth / 2))
	screenY = math.floor((vsy * 0.5) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller

	if mainDList then
		gl.DeleteList(mainDList)
	end
	mainDList = gl.CreateList(DrawWindow)
end

function DrawTextarea(x, y, width, height, scrollbar)
	local scrollbarOffsetTop = 0    -- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom = 0    -- note: wont add the offset to the top, only to bottom
	local scrollbarMargin = 14 * widgetScale
	local scrollbarWidth = 8 * widgetScale
	local scrollbarPosWidth = 4 * widgetScale

	local fontSizeTitle = 18 * widgetScale
	local fontSizeLine = 15.5 * widgetScale
	local lineSeparator = 2 * widgetScale

	local fontColorLine = { 0.8, 0.77, 0.74, 1 }
	local fontColorCommand = { 0.9, 0.6, 0.2, 1 }

	local textRightOffset = scrollbar and scrollbarMargin + scrollbarWidth + scrollbarWidth or 0
	maxLines = math.floor(height / (lineSeparator + fontSizeTitle))

	-- textarea scrollbar
	if scrollbar then
		if totalFileLines > maxLines or startLine > 1 then
			-- only show scroll above X lines
			local scrollbarTop = y - scrollbarOffsetTop - scrollbarMargin
			local scrollbarBottom = y - scrollbarOffsetBottom - height + scrollbarMargin

			UiScroller(
				math.floor(x + width - scrollbarMargin - scrollbarWidth),
				math.floor(scrollbarBottom - (scrollbarWidth - scrollbarPosWidth)),
				math.floor(x + width - scrollbarMargin),
				math.floor(scrollbarTop + (scrollbarWidth - scrollbarPosWidth)),
				(#fileLines-1) * (lineSeparator + fontSizeTitle),
				(startLine-1) * (lineSeparator + fontSizeTitle)
			)
		end
	end

	-- draw textarea
	if content then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines+1 do
			-- maxlines is not exact, just a failsafe
			if (lineSeparator + fontSizeTitle) * j > height then
				break
			end
			if fileLines[lineKey] == nil then
				break
			end

			local numLines
			local line = fileLines[lineKey]
			if string.find(line, '::') then
				local cmd = string.match(line, '^[ %+a-zA-Z0-9_-]*')        -- escaping the escape: \\ doesnt work in lua !#$@&*()&5$#
				local descr = string.sub(line, string.len(string.match(line, '^[ %+a-zA-Z0-9_-]*::') or '') + 1)
				descr, numLines = font:WrapText(descr, (width - scrollbarMargin - scrollbarWidth - 250 - textRightOffset) * 0.65 * (loadedFontSize / fontSizeLine))
				if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
					break
				end

				font:SetTextColor(fontColorCommand)
				font:Print(cmd, x + (18*widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")

				font:SetTextColor(fontColorLine)
				font:Print(descr, x + (screenWidth*0.58), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				j = j + (numLines - 1)
			else
				-- line
				font:SetTextColor(fontColorLine)
				line = "" .. line
				line, numLines = font:WrapText(line, (width - scrollbarMargin - scrollbarWidth) * (loadedFontSize / fontSizeLine))
				if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
					break
				end
				font:Print(line, x + (18*widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				j = j + (numLines - 1)
			end

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end

function DrawWindow()
	-- title
	local titleFontSize = 18 * widgetScale
	titleRect = { screenX, screenY, math.floor(screenX + (font2:GetTextWidth(Spring.I18N('ui.gameInfo.title')) * titleFontSize) + (titleFontSize*1.5)), math.floor(screenY + (titleFontSize*1.7)) }

	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	gl.Color(0, 0, 0, math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(Spring.I18N('ui.gameInfo.title'), screenX + (titleFontSize * 0.75), screenY + (8*widgetScale), titleFontSize, "on")
	font2:End()

	-- textarea
	DrawTextarea(screenX, screenY - (8 * widgetScale), screenWidth, screenHeight - (24 * widgetScale), 1)
end



function widget:DrawScreen()

	-- draw the help
	if not mainDList then
		mainDList = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then
		-- draw the panel
		glCallList(mainDList)
		if WG['guishader'] then
			if backgroundGuishader then
				backgroundGuishader = glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				-- title
				RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
			end)
			WG['guishader'].InsertDlist(backgroundGuishader, 'gameinfo')
		end
		showOnceMore = false

		local x, y, pressed = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			Spring.SetMouseCursor('cursornormal')
		end

	else
		if backgroundGuishader then
			if WG['guishader'] then
				WG['guishader'].RemoveDlist('gameinfo')
			end
			backgroundGuishader = glDeleteList(backgroundGuishader)
		end
	end
end

function widget:MouseWheel(up, value)

	if show then
		local addLines = value * -3 -- direction is retarded

		startLine = startLine + addLines
		if startLine > totalFileLines-maxLines then
			startLine = totalFileLines-maxLines
		end
		if startLine < 1 then
			startLine = 1
		end

		if mainDList then
			glDeleteList(mainDList)
		end

		mainDList = gl.CreateList(DrawWindow)
		return true
	else
		return false
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then
		return false
	end

	if show then
		-- on window
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			return true
		else
			show = false
		end
	end
end

function toggle()
	local newShow = not show
	if newShow and WG['topbar'] then
		WG['topbar'].hideWindows()
	end
	show = newShow

	return true
end

local function refreshContent()
	content = ''
	content = content .. titlecolor .. Game.gameName .. valuegreycolor .. " (" .. Game.gameMutator .. ") " .. titlecolor .. Game.gameVersion .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.engine') .. separator .. valuegreycolor .. ((Game and Game.version) or (Engine and Engine.version) or Spring.I18N('ui.gameInfo.engineVersionError')) .. "\n"
	content = content .. "\n"

	-- map info
	content = content .. titlecolor .. Game.mapName .. "\n"
	content = content .. valuegreycolor .. Game.mapDescription .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.size') .. separator .. valuegreycolor .. Game.mapX .. valuegreycolor .. " x " .. valuegreycolor .. Game.mapY .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.gravity') .. separator .. valuegreycolor .. Game.gravity .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.hardness') .. separator .. valuegreycolor .. Game.mapHardness .. keycolor .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.tidalStrength') .. separator .. valuegreycolor .. tidal .. keycolor .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.reclaimableMetal') .. separator .. valuegreycolor .. reclaimable_metal .. keycolor .. "\n"
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.reclaimableEnergy') .. separator .. valuegreycolor .. reclaimable_energy .. keycolor .. "\n"

	if Game.windMin == Game.windMax then
		content = content .. keycolor .. Spring.I18N('ui.gameInfo.windStrength') .. separator .. valuegreycolor .. Game.windMin .. valuegreycolor .. "\n"
	else
		content = content .. keycolor .. Spring.I18N('ui.gameInfo.windStrength') .. separator .. valuegreycolor .. Game.windMin .. valuegreycolor .. "  -  " .. valuegreycolor .. Game.windMax .. "\n"
	end
	local vcolor
	if Game.waterDamage == 0 then
		vcolor = valuegreycolor
	else
		vcolor = valuecolor
	end
	content = content .. keycolor .. Spring.I18N('ui.gameInfo.waterDamage') .. separator .. vcolor .. Game.waterDamage .. keycolor .. "\n"
	content = content .. "\n"
	if raptorsEnabled then
		-- filter raptor modoptions
		content = content .. titlecolor .. Spring.I18N('ui.gameInfo.raptorOptions') .. "\n"
		for key, params in pairs(changedRaptorModoptions) do
			content = content .. keycolor .. string.sub(params.key, 9) .. separator .. valuecolor .. params.value .. "\n"
		end
		for key, params in pairs(unchangedRaptorModoptions) do
			content = content .. keycolor .. string.sub(params.key, 9) .. separator .. valuegreycolor .. params.value .. "\n"
		end
		content = content .. "\n"
	end
	content = content .. titlecolor .. Spring.I18N('ui.gameInfo.modOptions') .. "\n"
	for key, params in pairs(changedModoptions) do
		local name = params.key	--modoptionsDefault[params.key].name
		content = content .. keycolor .. name .. separator .. valuecolor .. params.value .. "\n"
	end
	for key, params in pairs(unchangedModoptions) do
		local name = params.key --modoptionsDefault[params.key].name
		content = content .. keycolor .. name .. separator .. valuegreycolor .. params.value .. "\n"
	end

	-- store changelog into array
	fileLines = string.lines(content)
end

local function closeInfoHandler()
  if show then
    show = false

    return true
  end
end

local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeatureResources = Spring.GetFeatureResources
local spGetFeatureTeam = Spring.GetFeatureTeam
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local gaiaTeamId = spGetGaiaTeamID()

function widget:GamePreload()
	for _, featureID in ipairs(spGetAllFeatures()) do
		local metal, _, energy = spGetFeatureResources(featureID)
		if spGetFeatureTeam(featureID) == gaiaTeamId then
			reclaimable_metal = reclaimable_metal + metal
			reclaimable_energy = reclaimable_energy + energy
		end
	end

	refreshContent()
end

function widget:Initialize()
	refreshContent()

	widgetHandler:AddAction("customgameinfo", toggle, nil, 'p')
	widgetHandler:AddAction("customgameinfo_close", closeInfoHandler, nil, 'p')

	WG['gameinfo'] = {}
	WG['gameinfo'].toggle = function(state)
		local newShow = state
		if newShow == nil then
			newShow = not show
		end
		if newShow and WG['topbar'] then
			WG['topbar'].hideWindows()
		end
		show = newShow
	end
	WG['gameinfo'].isvisible = function()
		return show
	end

	for i, line in ipairs(fileLines) do
		totalFileLines = i
	end
	widget:ViewResize()
end

function widget:Shutdown()
	if mainDList then
		glDeleteList(mainDList)
		mainDList = nil
	end
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('gameinfo')
	end
	if backgroundGuishader then
		glDeleteList(backgroundGuishader)
	end
end

function widget:LanguageChanged()
	refreshContent()
	widget:ViewResize()
end
