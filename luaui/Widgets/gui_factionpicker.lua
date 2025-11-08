local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Factionpicker",
		desc = "",
		author = "Floris",
		date = "May 2020",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetSpectatingState = Spring.GetSpectatingState

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 1) == 1		-- much faster than drawing via DisplayLists only

local factions = {}


local doUpdate
local playSounds = true
local posY = 0.75
local posX = 0
local width = 0
local height = 0
local bgBorderOrg = 0.003
local bgBorder = bgBorderOrg

local myTeamID = Spring.GetMyTeamID()
local stickToBottom = true

local startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
do
	local validStartUnits = string.split(Spring.GetTeamRulesParam(myTeamID, "validStartUnits") or Spring.GetGameRulesParam("validStartUnits"), "|")
	for i, unitID_string in ipairs(validStartUnits) do
		-- TODO: figure out a better approach to this as sidedata faction names and language file keys do not match
		local unitID = tonumber(unitID_string)
		factions[i] = {
			startUnit = unitID,
			faction = string.sub(UnitDefs[unitID].name, 1, 3) }
		if factions[i].faction == "dum" then
			factions[i].faction = "random"
		end
	end
end
if #factions == 0 then
	Spring.Log(gadget:GetInfo().name, LOG.ERROR, "No Start Options Recived")
	return false
end

local factionRect = {}
for i, faction in pairs(factions) do
	factionRect[i] = {}
end

local vsx, vsy = spGetViewGeometry()

local sound_button = 'LuaUI/Sounds/buildbar_waypoint.wav'

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local isSpec = spGetSpectatingState()
local backgroundRect = {}

local math_isInRect = math.isInRect

local glColor = gl.Color
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local font, font2, bgpadding, dlistGuishader, dlistFactionpicker, bpWidth, bpHeight, rectMargin, fontSize

local factionpickerBgTex, factionpickerTex

local RectRound, UiElement, UiUnit

local function drawFactionpickerBackground()
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], 1, 1, ((posY - height > 0 or posX <= 0) and 1 or 0), 0)
end

local function drawFactionpicker()
	local contentPadding = mathFloor((height * vsy * 0.09) * (1 - ((1 - ui_scale) * 0.5)))
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.66)
	font2:Print(Spring.I18N('ui.factionPicker.pick'), backgroundRect[1] + contentPadding, backgroundRect[4] - contentPadding - (fontSize * 0.7), fontSize, "o")

	local contentWidth = mathFloor(backgroundRect[3] - backgroundRect[1] - contentPadding)
	local contentHeight = mathFloor(backgroundRect[4] - backgroundRect[2] - (contentPadding * 1.33))
	local maxCellHeight = mathFloor((contentHeight - (fontSize * 1.1)) + 0.5)
	local maxCellWidth = mathFloor((contentWidth / #factions) + 0.5)
	local cellSize = math.min(maxCellHeight, maxCellWidth)
	local padding = bgpadding

	for i, faction in pairs(factions) do
		factionRect[i] = {
			mathFloor(backgroundRect[3] - padding - (cellSize * i)),
			mathFloor(backgroundRect[2]),
			mathFloor(backgroundRect[3] - padding - (cellSize * (i - 1))),
			mathFloor(backgroundRect[2] + cellSize)
		}
		local disabled = Spring.GetTeamRulesParam(myTeamID, 'startUnit') ~= factions[i].startUnit
		if disabled then
			glColor(0.55, 0.55, 0.55, 1)
		else
			glColor(1, 1, 1, 1)
		end
		UiUnit(factionRect[i][1] + bgpadding, factionRect[i][2] + bgpadding, factionRect[i][3], factionRect[i][4],
			nil,
			1, 1, 1, 1,
			0,
			nil, disabled and 0.033 or nil,
			'#' .. factions[i].startUnit
		)
		-- faction name
		font2:Print((disabled and "\255\170\170\170" or "\255\255\255\255") .. Spring.I18N('units.factions.' .. factions[i].faction), factionRect[i][1] + ((factionRect[i][3] - factionRect[i][1]) * 0.5), factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.22) - (fontSize * 0.5), fontSize * 0.96, "co")

		if WG['tooltip'] ~= nil then
			local text = Spring.I18N('ui.factionPicker.factions.'..factions[i].faction)
			local tooltip = ''
			local maxWidth = WG['tooltip'].getFontsize() * 80
			local textLines, numLines = font2:WrapText(text, maxWidth)
			tooltip = tooltip..string.gsub(textLines, '[\n]', '\n')..'\n'
			WG['tooltip'].AddTooltip('factionpicker_'..i, { factionRect[i][1] + bgpadding, factionRect[i][2] + bgpadding, factionRect[i][3], factionRect[i][4] }, tooltip, nil, Spring.I18N('units.factions.' .. factions[i].faction))
		end
	end
	font2:End()
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], (bgBorder * vsy) * 2)
			end)
			WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:PlayerChanged(playerID)
	isSpec = spGetSpectatingState()
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()

	width = 0.2125
	height = 0.14 * ui_scale

	width = width / (vsx / vsy) * 1.78        -- make smaller for ultrawide screens
	width = width * ui_scale

	-- make pixel aligned
	width = mathFloor(width * vsx) / vsx
	height = mathFloor(height * vsy) / vsy

	local buildmenuBottomPos
	if WG['buildmenu'] then
		buildmenuBottomPos = WG['buildmenu'].getBottomPosition()
	end

	local outlineMult = math.clamp(1/(vsy/1400), 1, 1.5)
	font2 = WG['fonts'].getFont(2)

	local widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiUnit = WG.FlowUI.Draw.Unit

	if WG['minimap'] then
		minimapHeight = WG['minimap'].getHeight()
	end

	if stickToBottom then
		posY = height
		posX = width + (widgetSpaceMargin / vsx)
	else
		if buildmenuBottomPos then
			posX = 0
			posY = height + height + (widgetSpaceMargin / vsy)
		elseif WG['buildmenu'] then
			local posY2, _ = WG['buildmenu'].getSize()
			posY2 = posY2 + (widgetSpaceMargin / vsy)
			posY = posY2 + height
			if WG['minimap'] then
				posY = 1 - (minimapHeight / vsy) - (widgetSpaceMargin / vsy)
			end
			posX = 0
		end
	end

	backgroundRect = { posX * vsx, (posY - height) * vsy, (posX + width) * vsx, posY * vsy }

	dlistFactionpicker = gl.DeleteList(dlistFactionpicker)

	checkGuishader(true)

	doUpdate = true

	fontSize = (height * vsy * 0.125) * (1 - ((1 - ui_scale) * 0.5))

	if factionpickerTex then
		gl.DeleteTexture(factionpickerBgTex)
		factionpickerBgTex = nil
		gl.DeleteTexture(factionpickerTex)
		factionpickerTex = nil
	end
end

function widget:Initialize()
	if isSpec or Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
	end

	if Spring.GetModOptions().scenariooptions then
		local scenarioopts = string.base64Decode(Spring.GetModOptions().scenariooptions)
		scenarioopts = Json.decode(scenarioopts)
		if scenarioopts and scenarioopts.disablefactionpicker == true then
			widgetHandler:RemoveWidget()
			return
		end
	end

	if WG['ordermenu'] then
		stickToBottom = WG['ordermenu'].getBottomPosition()
	end

	widget:ViewResize()
end

function widget:Shutdown()
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('factionpicker')
		dlistGuishader = nil
	end
	dlistFactionpicker = gl.DeleteList(dlistFactionpicker)

	if factionpickerBgTex then
		gl.DeleteTexture(factionpickerBgTex)
		factionpickerBgTex = nil
	end
	if factionpickerTex then
		gl.DeleteTexture(factionpickerTex)
		factionpickerTex = nil
	end

	if WG['tooltip'] ~= nil then
		for i, faction in pairs(factions) do
			WG['tooltip'].RemoveTooltip('factionpicker_'..i)
		end
	end
end

function widget:GameFrame(n)
	widgetHandler:RemoveWidget()
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
		sec = 0
		checkGuishader()

		if WG['minimap'] and minimapHeight ~= WG['minimap'].getHeight() then
			widget:ViewResize()
			doUpdate = true
		end

		if WG['ordermenu'] and stickToBottom ~= WG['ordermenu'].getBottomPosition() then
			stickToBottom = WG['ordermenu'].getBottomPosition()
			widget:ViewResize()
			doUpdate = true
		end
	end
end

function widget:DrawScreen()
	local x, y, b = Spring.GetMouseState()
	if not WG['topbar'] or not WG['topbar'].showingQuit() then
		if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			Spring.SetMouseCursor('cursornormal')
		end
	end

	if startDefID ~= Spring.GetTeamRulesParam(myTeamID, 'startUnit') then
		startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
		doUpdate = true
	end

	if dlistGuishader and WG['guishader'] then
		WG['guishader'].InsertDlist(dlistGuishader, 'factionpicker')
	end

	if useRenderToTexture then
		if not factionpickerBgTex then
			factionpickerBgTex = gl.CreateTexture(mathFloor(width*vsx), mathFloor(height*vsy), {
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})
			if factionpickerBgTex then
				gl.R2tHelper.RenderToTexture(factionpickerBgTex,
					function()
						gl.Translate(-1, -1, 0)
						gl.Scale(2 / (width*vsx), 2 / (height*vsy),	0)
						gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
						drawFactionpickerBackground()
					end,
					useRenderToTexture
				)
			end
		end
	end

	if useRenderToTexture then
		if not factionpickerTex then
			factionpickerTex = gl.CreateTexture(mathFloor(width*vsx)*(vsy<1400 and 2 or 1), mathFloor(height*vsy)*(vsy<1400 and 2 or 1), {
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})
		end
	end

	if factionpickerTex and doUpdate then
		gl.R2tHelper.RenderToTexture(factionpickerTex,
			function()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (width*vsx), 2 / (height*vsy),	0)
				gl.Translate(-backgroundRect[1], -backgroundRect[2], 0)
				drawFactionpicker()
			end,
			useRenderToTexture
		)
		doUpdate = nil
	end

	if useRenderToTexture then
		if factionpickerBgTex then
			-- background element
			gl.R2tHelper.BlendTexRect(factionpickerBgTex, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], useRenderToTexture)
		end
		if factionpickerTex then
			-- content
			gl.R2tHelper.BlendTexRect(factionpickerTex, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], useRenderToTexture)
		end
	else
		if doUpdate then
			dlistFactionpicker = gl.DeleteList(dlistFactionpicker)
			doUpdate = nil
		end
		if not dlistFactionpicker then
			dlistFactionpicker = gl.CreateList(function()
				drawFactionpickerBackground()
				drawFactionpicker()
			end)
		end
		gl.CallList(dlistFactionpicker)
	end

	font2:Begin()
	font2:SetOutlineColor(0, 0, 0, 0.66)
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.66)
	-- highlight
	if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		for i, faction in pairs(factions) do
			if math_isInRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
				glBlending(GL_SRC_ALPHA, GL_ONE)
				RectRound(factionRect[i][1] + bgpadding, factionRect[i][2] + bgpadding, factionRect[i][3], factionRect[i][4], bgpadding, 1, 1, 1, 1, { 0.3, 0.3, 0.3, (b and 0.5 or 0.25) }, { 1, 1, 1, (b and 0.3 or 0.15) })
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

				font2:Print(Spring.I18N('units.factions.' .. factions[i].faction), factionRect[i][1] + ((factionRect[i][3] - factionRect[i][1]) * 0.5), factionRect[i][2] + ((factionRect[i][4] - factionRect[i][2]) * 0.22) - (fontSize * 0.5), fontSize * 0.96, "co")
				break
			end
		end
	end
	font2:End()

end

function widget:MousePress(x, y, button)
	if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then

		for i, faction in pairs(factions) do
			if math_isInRect(x, y, factionRect[i][1], factionRect[i][2], factionRect[i][3], factionRect[i][4]) then
				if playSounds then
					Spring.PlaySoundFile(sound_button, 0.6, 'ui')
				end
				-- tell initial spawn
				Spring.SendLuaRulesMsg('changeStartUnit' .. tostring(factions[i].startUnit))
				break
			end
		end
		return true
	end
end

