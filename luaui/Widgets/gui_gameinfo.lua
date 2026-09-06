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

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local titlecolor = "\255\255\205\100"
local keycolor = ""
local valuecolor = "\255\255\255\255"
local valuegreycolor = "\255\180\180\180"
local separator = "::"

local font, font2, loadedFontSize, mainDList, titleRect, backgroundGuishader, show
local maxLines = 22
local math_isInRect = math.isInRect

local raptorsEnabled = BAR.Utilities.Gametype.IsRaptors()

local content = ""

-- hover tooltips: filled while the content is built, translated into screen areas while the textarea is drawn
local lineTooltips = {} -- [content line number] = { title = <name>, text = <description> }
local contentLineCount = 0
local hoverRows = {} -- list of { bottom, top, tooltip }
local hoverAreaLeft, hoverAreaRight

-- appends text to the content, optionally attaching a tooltip to every line the text spans
local function addContent(text, tooltip)
	content = content .. text
	local _, addedLines = string.gsub(text, "\n", "")
	if tooltip then
		for line = contentLineCount + 1, contentLineCount + mathMax(addedLines, 1) do
			lineTooltips[line] = tooltip
		end
	end
	contentLineCount = contentLineCount + addedLines
end

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
	modoptionsDefault[value.key] =
		{ name = value.name, desc = value.desc, def = value.def, min = value.min, max = value.max }
end

local modoptions = BAR.GetModOptionsCopy()

-- options that aren't worth listing: modoptions.lua layout helpers and values fed by spads/lobby
local ignoredModoptions = {
	sub_header = true,
	dummyboolfeelfreetotouch = true,
}
local function isIgnoredModoption(key)
	return ignoredModoptions[key] or string.sub(key, 1, 5) == "date_"
end

local changedModoptions = {}
local unchangedModoptions = {}
local changedRaptorModoptions = {}
local unchangedRaptorModoptions = {}
for key, value in pairs(modoptions) do
	if string.sub(key, 1, 8) == "raptor_" then
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
	if not path then
		path = {}
	end
	path = table.copy(path)
	if pathAddition then
		path[#path + 1] = pathAddition
	end
	if #path > 10 then
		return "..."
	end
	local text = ""
	local depthSpacing = ""
	for i = 1, #path, 1 do
		depthSpacing = depthSpacing .. "     "
	end
	for k, v in pairs(t) do
		if type(v) == "table" then
			text = text .. "\n" .. valuegreycolor .. depthSpacing .. tostring(k) .. " = {"
			text = text .. stringifyDefTable(v, path, k)
			text = text .. "\n" .. valuegreycolor .. depthSpacing .. "}"
		else
			text = text .. "\n" .. valuegreycolor .. depthSpacing .. tostring(k) .. " = " .. tostring(v)
		end
	end
	return text
end

-- tweakdefs are lua snippets, so the units they touch are found by matching known unitdef names
local function countTweakedUnitDefs(text)
	local count = 0
	local counted = {}
	for word in string.gmatch(text, "[%a_][%w_]*") do
		if not counted[word] and UnitDefNames[word] then
			counted[word] = true
			count = count + 1
		end
	end
	return count
end

-- every unitdef that got tweaked counts as a change on top of the tweakdefs/tweakunits option itself
local changedModoptionsCount = 0

for key, value in pairs(modoptions) do
	if not isIgnoredModoption(key) then
		if modoptionsDefault[key] and value == modoptionsDefault[key].def then
			unchangedModoptions[key] = tostring(value)
		else
			changedModoptionsCount = changedModoptionsCount + 1
			if not string.find(key, "tweakunits") and not string.find(key, "tweakdefs") then
				changedModoptions[key] = tostring(value)
			else
				if string.find(key, "tweakdefs") then
					local decodeSuccess, postsFuncStr = pcall(string.base64Decode, value)
					changedModoptions[key] = "\n"
						.. (
							decodeSuccess and postsFuncStr
							or "\255\255\100\100 - " .. BAR.I18N("ui.gameInfo.decodefailed") .. " - "
						)
					if decodeSuccess then
						changedModoptionsCount = changedModoptionsCount + countTweakedUnitDefs(postsFuncStr)
					end
				else
					local dataRaw = string.gsub(value, "_", "=")
					local decodeSuccess, postsFuncStr = pcall(string.base64Decode, dataRaw)
					local success, tweaks = pcall(BAR.Utilities.SafeLuaTableParser, postsFuncStr)

					if success and type(tweaks) == "table" then
						local text = ""
						for name, ud in pairs(tweaks) do
							if UnitDefNames[name] then
								changedModoptionsCount = changedModoptionsCount + 1
								text = text .. "\n" .. valuecolor .. name .. valuegreycolor .. " = {"
								text = text .. stringifyDefTable(ud, {}, name)
								text = text .. "\n" .. "}"
							end
						end
						changedModoptions[key] = text
					else
						changedModoptions[key] = tostring(value)
						if decodeSuccess then
							changedModoptionsCount = changedModoptionsCount + countTweakedUnitDefs(postsFuncStr)
						end
					end
				end
			end
		end
	end
end

local function stripColorCodes(text)
	local stripped = string.gsub(text, "\255...", "")
	return stripped
end

-- modoption names/descriptions live in language/<lang>/interface.json under the 'modoptions' namespace,
-- the (english) texts inside modoptions.lua are the fallback for options that aren't translated yet
local function getModoptionName(key)
	local default = modoptionsDefault[key] and modoptionsDefault[key].name
	default = default and stripColorCodes(default) or key
	-- a few names are multi line (lobby layout), here they are shown on a single row
	local name = string.gsub(BAR.I18N("modoptions." .. key .. ".name", { default = default }), "%s*\n%s*", " ")
	return name
end

local function getModoptionDesc(key)
	local default = modoptionsDefault[key] and modoptionsDefault[key].desc or ""
	return BAR.I18N("modoptions." .. key .. ".desc", { default = stripColorCodes(default) })
end

local function appendTooltipLine(text, line)
	return (text ~= "" and text .. "\n" or "") .. line
end

-- description, allowed range, and (when the option isn't at its default) the value it normally has
local function getModoptionTooltipText(key, showDefault)
	local text = getModoptionDesc(key)
	local option = modoptionsDefault[key]
	if option then
		if option.min and option.max then
			text = appendTooltipLine(
				text,
				valuegreycolor
					.. BAR.I18N("ui.gameInfo.range")
					.. ": "
					.. valuecolor
					.. option.min
					.. "  -  "
					.. option.max
			)
		end
		if showDefault and option.def ~= nil then
			text = appendTooltipLine(
				text,
				valuegreycolor .. BAR.I18N("ui.gameInfo.default") .. ": " .. valuecolor .. tostring(option.def)
			)
		end
	end
	return (text ~= "" and text .. "\n\n" or "") .. valuegreycolor .. key
end

-- turns a key -> value table into a list of displayable rows, sorted by the name they are displayed with
local function getModoptionRows(modoptionValues, showDefault)
	local rows = {}
	for key, value in pairs(modoptionValues) do
		local name = getModoptionName(key)
		tableInsert(rows, {
			key = key,
			value = value,
			name = name,
			tooltip = {
				title = name,
				text = getModoptionTooltipText(key, showDefault),
			},
		})
	end
	table.sort(rows, function(a, b)
		local aName, bName = string.lower(a.name), string.lower(b.name)
		if aName == bName then
			return a.key < b.key
		end
		return aName < bName
	end)
	return rows
end

local screenHeightOrg = 540
local screenWidthOrg = 540
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local startLine = 1

local vsx, vsy = spGetViewGeometry()
local screenX = (vsx * 0.5) - (screenWidth / 2)
local screenY = (vsy * 0.5) + (screenHeight / 2)

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local widgetScale = (vsy / 1080)

local fileLines = {}
local totalFileLines = 0

local showOnceMore = false -- used because of GUI shader delay

local RectRound, UiElement, UiScroller, elementCorner

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = (vsy / 1080)

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)

	screenX = mathFloor((vsx * 0.5) - (screenWidth / 2))
	screenY = mathFloor((vsy * 0.5) + (screenHeight / 2))

	font, loadedFontSize = WG.fonts.getFont()
	font2 = WG.fonts.getFont(2)

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller

	if mainDList then
		gl.DeleteList(mainDList)
	end
	mainDList = gl.CreateList(DrawWindow)
end

-- remembers the screen area of a drawn line so the tooltip can be shown when hovering over it
local function addHoverRow(lineKey, y, j, numLines, rowHeight, baselineOffset)
	local tooltip = lineTooltips[lineKey]
	if tooltip then
		hoverRows[#hoverRows + 1] = {
			y - (rowHeight * (j + numLines - 1)) - baselineOffset,
			y - (rowHeight * (j - 1)) - baselineOffset,
			tooltip,
		}
	end
end

function DrawTextarea(x, y, width, height, scrollbar)
	local scrollbarOffsetTop = 0 -- note: won't add the offset to the bottom, only to top
	local scrollbarOffsetBottom = 0 -- note: won't add the offset to the top, only to bottom
	local scrollbarMargin = 14 * widgetScale
	local scrollbarWidth = 8 * widgetScale
	local scrollbarPosWidth = 4 * widgetScale

	local fontSizeTitle = 18 * widgetScale
	local fontSizeLine = 15.5 * widgetScale
	local lineSeparator = 2 * widgetScale

	local fontColorLine = { 0.8, 0.77, 0.74, 1 }
	local fontColorCommand = { 0.9, 0.6, 0.2, 1 }

	local textRightOffset = scrollbar and scrollbarMargin + scrollbarWidth + scrollbarWidth or 0
	maxLines = mathFloor(height / (lineSeparator + fontSizeTitle))

	-- textarea scrollbar
	if scrollbar then
		if totalFileLines > maxLines or startLine > 1 then
			-- only show scroll above X lines
			local scrollbarTop = y - scrollbarOffsetTop - scrollbarMargin
			local scrollbarBottom = y - scrollbarOffsetBottom - height + scrollbarMargin

			UiScroller(
				mathFloor(x + width - scrollbarMargin - scrollbarWidth),
				mathFloor(scrollbarBottom - (scrollbarWidth - scrollbarPosWidth)),
				mathFloor(x + width - scrollbarMargin),
				mathFloor(scrollbarTop + (scrollbarWidth - scrollbarPosWidth)),
				(#fileLines - 1) * (lineSeparator + fontSizeTitle),
				(startLine - 1) * (lineSeparator + fontSizeTitle)
			)
		end
	end

	-- draw textarea
	if content then
		hoverRows = {}
		hoverAreaLeft = x
		hoverAreaRight = x + width - textRightOffset

		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines + 1 do
			-- maxlines is not exact, just a failsafe
			if (lineSeparator + fontSizeTitle) * j > height then
				break
			end
			if fileLines[lineKey] == nil then
				break
			end

			local numLines
			local line = fileLines[lineKey]
			local separatorStart, separatorEnd = string.find(line, separator, 1, true)
			if separatorStart and separatorEnd then
				local cmd = string.sub(line, 1, separatorStart - 1)
				local descr = string.sub(line, separatorEnd + 1)
				local cmdLines, descrLines
				cmd, cmdLines = font:WrapText(
					cmd,
					((screenWidth * 0.58) - (26 * widgetScale)) * (loadedFontSize / fontSizeLine)
				)
				descr, descrLines = font:WrapText(
					descr,
					(width - scrollbarMargin - scrollbarWidth - 250 - textRightOffset)
						* 0.65
						* (loadedFontSize / fontSizeLine)
				)
				numLines = mathMax(cmdLines, descrLines)
				if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
					break
				end

				addHoverRow(lineKey, y, j, numLines, lineSeparator + fontSizeTitle, fontSizeLine * 0.25)

				font:SetTextColor(fontColorCommand)
				font:Print(cmd, x + (18 * widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")

				font:SetTextColor(fontColorLine)
				font:Print(descr, x + (screenWidth * 0.58), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				j = j + (numLines - 1)
			else
				-- line
				font:SetTextColor(fontColorLine)
				line = "" .. line
				line, numLines =
					font:WrapText(line, (width - scrollbarMargin - scrollbarWidth) * (loadedFontSize / fontSizeLine))
				if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
					break
				end
				font:Print(line, x + (18 * widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
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
	titleRect = {
		screenX,
		screenY,
		mathFloor(
			screenX + (font2:GetTextWidth(BAR.I18N("ui.gameInfo.title")) * titleFontSize) + (titleFontSize * 1.5)
		),
		mathFloor(screenY + (titleFontSize * 1.7)),
	}

	UiElement(
		screenX,
		screenY - screenHeight,
		screenX + screenWidth,
		screenY,
		0,
		1,
		1,
		1,
		1,
		1,
		1,
		1,
		WG.FlowUI.clampedOpacity
	)
	gl.Color(0, 0, 0, WG.FlowUI.clampedOpacity)
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(
		BAR.I18N("ui.gameInfo.title"),
		screenX + (titleFontSize * 0.75),
		screenY + (8 * widgetScale),
		titleFontSize,
		"on"
	)
	font2:End()

	-- textarea
	DrawTextarea(screenX, screenY - (8 * widgetScale), screenWidth, screenHeight - (24 * widgetScale), 1)
end

local function getHoveredTooltip(x, y)
	if not hoverAreaLeft or x < hoverAreaLeft or x > hoverAreaRight then
		return nil
	end
	for i = 1, #hoverRows do
		local row = hoverRows[i]
		if y >= row[1] and y <= row[2] then
			return row[3]
		end
	end
end

function widget:DrawScreen()
	-- draw the help
	if not mainDList then
		mainDList = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then
		-- draw the panel
		glCallList(mainDList)
		if WG.guishader then
			if backgroundGuishader then
				backgroundGuishader = glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				-- title
				RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
			end)
			WG.guishader.InsertDlist(backgroundGuishader, "gameinfo")
		end
		showOnceMore = false

		local x, y, _ = Spring.GetMouseState()
		if
			math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)
			or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4])
		then
			Spring.SetMouseCursor("cursornormal")

			if WG.tooltip then
				local tooltip = getHoveredTooltip(x, y)
				if tooltip then
					WG.tooltip.ShowTooltip("gameinfo", tooltip.text, nil, nil, tooltip.title)
				end
			end
		end
	else
		if backgroundGuishader then
			if WG.guishader then
				WG.guishader.RemoveDlist("gameinfo")
			end
			backgroundGuishader = glDeleteList(backgroundGuishader)
		end
	end
end

function widget:MouseWheel(up, value)
	if show then
		local addLines = value * -3 -- direction is retarded

		startLine = startLine + addLines
		if startLine > totalFileLines - maxLines then
			startLine = totalFileLines - maxLines
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
		if
			math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)
			or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4])
		then
			return true
		else
			show = false
		end
	end
end

function toggle()
	local newShow = not show
	if newShow and WG.topbar then
		WG.topbar.hideWindows()
	end
	show = newShow

	return true
end

local function refreshContent()
	content = ""
	lineTooltips = {}
	contentLineCount = 0

	addContent(
		titlecolor
			.. Game.gameName
			.. valuegreycolor
			.. " ("
			.. Game.gameMutator
			.. ") "
			.. titlecolor
			.. Game.gameVersion
			.. "\n"
	)
	addContent(
		keycolor
			.. BAR.I18N("ui.gameInfo.engine")
			.. separator
			.. valuegreycolor
			.. ((Game and Game.version) or (Engine and Engine.version) or BAR.I18N("ui.gameInfo.engineVersionError"))
			.. "\n"
	)
	addContent("\n")

	-- map info
	addContent(titlecolor .. Game.mapName .. "\n")
	addContent(valuegreycolor .. Game.mapDescription .. "\n")
	addContent(
		keycolor
			.. BAR.I18N("ui.gameInfo.size")
			.. separator
			.. valuegreycolor
			.. Game.mapX
			.. valuegreycolor
			.. " x "
			.. valuegreycolor
			.. Game.mapY
			.. "\n"
	)
	addContent(keycolor .. BAR.I18N("ui.gameInfo.gravity") .. separator .. valuegreycolor .. Game.gravity .. "\n")
	addContent(
		keycolor
			.. BAR.I18N("ui.gameInfo.hardness")
			.. separator
			.. valuegreycolor
			.. Game.mapHardness
			.. keycolor
			.. "\n"
	)
	addContent(
		keycolor .. BAR.I18N("ui.gameInfo.tidalStrength") .. separator .. valuegreycolor .. tidal .. keycolor .. "\n"
	)
	addContent(
		keycolor
			.. BAR.I18N("ui.gameInfo.reclaimableMetal")
			.. separator
			.. valuegreycolor
			.. reclaimable_metal
			.. keycolor
			.. "\n"
	)
	addContent(
		keycolor
			.. BAR.I18N("ui.gameInfo.reclaimableEnergy")
			.. separator
			.. valuegreycolor
			.. reclaimable_energy
			.. keycolor
			.. "\n"
	)

	if Game.windMin == Game.windMax then
		addContent(
			keycolor
				.. BAR.I18N("ui.gameInfo.windStrength")
				.. separator
				.. valuegreycolor
				.. Game.windMin
				.. valuegreycolor
				.. "\n"
		)
	else
		addContent(
			keycolor
				.. BAR.I18N("ui.gameInfo.windStrength")
				.. separator
				.. valuegreycolor
				.. Game.windMin
				.. valuegreycolor
				.. "  -  "
				.. valuegreycolor
				.. Game.windMax
				.. "\n"
		)
	end
	local vcolor
	if Game.waterDamage == 0 then
		vcolor = valuegreycolor
	else
		vcolor = valuecolor
	end
	addContent(
		keycolor .. BAR.I18N("ui.gameInfo.waterDamage") .. separator .. vcolor .. Game.waterDamage .. keycolor .. "\n"
	)
	addContent("\n")
	if raptorsEnabled then
		-- filter raptor modoptions
		addContent(titlecolor .. BAR.I18N("ui.gameInfo.raptorOptions") .. "\n")
		for _, params in ipairs(getModoptionRows(changedRaptorModoptions, true)) do
			addContent(keycolor .. params.name .. separator .. valuecolor .. params.value .. "\n", params.tooltip)
		end
		for _, params in ipairs(getModoptionRows(unchangedRaptorModoptions)) do
			addContent(keycolor .. params.name .. separator .. valuegreycolor .. params.value .. "\n", params.tooltip)
		end
		addContent("\n")
	end
	local changedRows = getModoptionRows(changedModoptions, true)
	if #changedRows > 0 then
		addContent(titlecolor .. BAR.I18N("ui.gameInfo.adjustedSettings") .. "\n")
		for _, params in ipairs(changedRows) do
			addContent(keycolor .. params.name .. separator .. valuecolor .. params.value .. "\n", params.tooltip)
		end
		addContent("\n")
	end
	local unchangedRows = getModoptionRows(unchangedModoptions)
	if #unchangedRows > 0 then
		addContent(titlecolor .. BAR.I18N("ui.gameInfo.settings") .. "\n")
		for _, params in ipairs(unchangedRows) do
			addContent(keycolor .. params.name .. separator .. valuegreycolor .. params.value .. "\n", params.tooltip)
		end
	end

	-- store changelog into array
	fileLines = string.lines(content)
	totalFileLines = #fileLines
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

	widgetHandler:AddAction("customgameinfo", toggle, nil, "p")
	widgetHandler:AddAction("customgameinfo_close", closeInfoHandler, nil, "p")

	WG.gameinfo = {}
	WG.gameinfo.toggle = function(state)
		local newShow = state
		if newShow == nil then
			newShow = not show
		end
		if newShow and WG.topbar then
			WG.topbar.hideWindows()
		end
		show = newShow
	end
	WG.gameinfo.isvisible = function()
		return show
	end
	-- amount of modoptions that aren't set to their default value
	WG.gameinfo.getChangedModoptionsCount = function()
		return changedModoptionsCount
	end

	widget:ViewResize()
end

function widget:Shutdown()
	if mainDList then
		glDeleteList(mainDList)
		mainDList = nil
	end
	if WG.guishader then
		WG.guishader.RemoveDlist("gameinfo")
	end
	if WG.tooltip then
		WG.tooltip.RemoveTooltip("gameinfo")
	end
	if backgroundGuishader then
		glDeleteList(backgroundGuishader)
	end
end

function widget:LanguageChanged()
	refreshContent()
	widget:ViewResize()
end
