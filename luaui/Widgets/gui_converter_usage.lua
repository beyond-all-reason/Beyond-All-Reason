local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Converter Usage",
		desc = "Shows the % of converters that are in use, their energy consumption and metal production",
		author = "Lexon, Floris",
		date = "05.08.2022",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local font2

local RectRound, UiElement
local dlistGuishader, dlistBackground, dlistCU
local area = { 0, 0, 0, 0 }

local spGetMyTeamID = Spring.GetLocalTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glGetViewSizes = gl.GetViewSizes
local glDeleteList = gl.DeleteList
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local floor = math.floor

local gameStarted = false

--Current energy converted to metal
local mConverted, eConverted
--Store accumulated converted metal remainder from floor(mConverted) for more accurate conversion display
local mConvertedRemainder = 0

--Energy needed for maximum potential metal production
local eConvertedMax

--Converter efficiency - eConverted / eConvertedMax
--How many converters are active 0 - 100%
local converterUse

local formatOptions = { showSign = true }
local displayedConverterUse, displayedEConverted, displayedMConverted
local displayedWarningLevel
local layoutDirty = true
local currentUseSkew, currentSkewTan
local tooltipDirty = true
local tooltipTitle, defaultTooltipText, warningTooltipText1, warningTooltipText2

local function refreshTooltipText()
	tooltipTitle = Spring.I18N("ui.topbar.converter_usage.defaultTooltipTitle")
	defaultTooltipText = Spring.I18N("ui.topbar.converter_usage.defaultTooltip")
	warningTooltipText1 = Spring.I18N("ui.topbar.converter_usage.tooManyConverters1Tooltip")
	warningTooltipText2 = Spring.I18N("ui.topbar.converter_usage.tooManyConverters2Tooltip")
	tooltipDirty = true
end

local function updateUI()
	local localSkewTan = 0
	local useSkew = false
	local nextWidgetScale = widgetScale
	local nextArea1, nextArea2, nextArea3, nextArea4 = area[1], area[2], area[3], area[4]
	if WG["topbar"] then
		local freeArea = WG["topbar"].GetFreeArea()
		nextWidgetScale = freeArea[5]
		local topbarH = freeArea[4] - freeArea[2]
		local smallVPad = 0
		if WG["topbar"].GetSkewConfig then
			local skewCfg = WG["topbar"].GetSkewConfig()
			useSkew = skewCfg.useSkew
			localSkewTan = skewCfg.skewTan
			if useSkew then
				smallVPad = floor(topbarH * (1 - skewCfg.smallElementHeightFraction))
			end
		end
		nextArea1 = freeArea[1]
		nextArea2 = freeArea[2] + smallVPad
		nextArea3 = freeArea[1] + floor(72 * nextWidgetScale)
		if nextArea3 > freeArea[3] then
			nextArea3 = freeArea[3]
		end
		nextArea4 = freeArea[4]
	end

	local layoutChanged = layoutDirty or widgetScale ~= nextWidgetScale or area[1] ~= nextArea1 or area[2] ~= nextArea2 or area[3] ~= nextArea3 or area[4] ~= nextArea4 or currentUseSkew ~= useSkew or currentSkewTan ~= localSkewTan

	if layoutChanged then
		layoutDirty = false
		widgetScale = nextWidgetScale
		area[1], area[2], area[3], area[4] = nextArea1, nextArea2, nextArea3, nextArea4
		currentUseSkew = useSkew
		currentSkewTan = localSkewTan

		if dlistGuishader ~= nil then
			if WG["guishader"] then
				WG["guishader"].RemoveDlist("converter_usage")
			end
			glDeleteList(dlistGuishader)
		end
		dlistGuishader = glCreateList(function()
			if useSkew then
				local H = area[4] - area[2]
				local skewOffset = H * localSkewTan
				gl.BeginEnd(GL.QUADS, function()
					gl.Vertex(area[1] - skewOffset, area[2])
					gl.Vertex(area[3] - skewOffset, area[2])
					gl.Vertex(area[3], area[4])
					gl.Vertex(area[1], area[4])
				end)
			else
				RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0, 0, 1, 1)
			end
		end)

		if dlistBackground ~= nil then
			glDeleteList(dlistBackground)
		end
		dlistBackground = glCreateList(function()
			local H = area[4] - area[2]
			local skew = useSkew and { blx = -(H * localSkewTan), brx = -(H * localSkewTan) } or nil
			UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, skew)
		end)

		if WG["guishader"] then
			WG["guishader"].InsertDlist(dlistGuishader, "converter_usage")
		end
	end

	local color
	local warningLevel = 0
	if converterUse < 20 then
		color = "\255\255\000\000" --Red
		warningLevel = 2
	elseif converterUse < 40 then
		color = "\255\255\100\000" --Orange
		warningLevel = 1
	elseif converterUse < 50 then
		color = "\255\255\255\000" --Yellow
	elseif converterUse < 70 then
		color = "\255\215\230\100" --Yelleen?
	else
		color = "\255\000\255\000" --Green
	end

	if WG["tooltip"] ~= nil and (layoutChanged or tooltipDirty or warningLevel ~= displayedWarningLevel) then
		local tooltipText = defaultTooltipText
		if warningLevel == 2 then
			tooltipText = tooltipText .. "\n\n\255\255\100\075" .. warningTooltipText1 .. "\n\255\255\100\075" .. warningTooltipText2
		elseif warningLevel == 1 then
			tooltipText = tooltipText .. "\n\n\255\255\120\050" .. warningTooltipText1 .. "\n\255\255\120\050" .. warningTooltipText2
		end
		WG["tooltip"].AddTooltip("converter_usage", area, tooltipText, nil, tooltipTitle)
		tooltipDirty = false
	end
	displayedWarningLevel = warningLevel

	if not layoutChanged and dlistCU ~= nil and converterUse == displayedConverterUse and eConverted == displayedEConverted and mConverted == displayedMConverted then
		return
	end

	if dlistCU ~= nil then
		glDeleteList(dlistCU)
	end
	dlistCU = glCreateList(function()
		local H = area[4] - area[2]
		local fontSize = H * 0.4

		-- converter use
		font2:Begin()
		font2:Print(color .. converterUse .. "%", area[1] + (fontSize * 0.4), area[2] + ((area[4] - area[2]) / 2.05) - (fontSize / 5), fontSize, "ol")

		fontSize = fontSize * 0.75

		-- energy used (right-anchored to skew-adjusted edge at text y)
		local energyY = area[2] + 3.2 * (H / 4) - (fontSize / 5)
		local energyX = area[3] - (useSkew and (H - (energyY - area[2])) * localSkewTan or 0) - (fontSize * 0.35)
		font2:Print("\255\255\255\000" .. string.formatSI(-eConverted, formatOptions), energyX, energyY, fontSize, "or")

		-- metal produced (right-anchored to skew-adjusted edge at text y)
		local metalY = area[2] + 0.8 * (H / 4) - (fontSize / 5)
		local metalX = area[3] - (useSkew and (H - (metalY - area[2])) * localSkewTan or 0) - (fontSize * 0.35)
		font2:Print("\255\240\255\240" .. string.formatSI(mConverted, formatOptions), metalX, metalY, fontSize, "or")
		font2:End()
	end)

	displayedConverterUse = converterUse
	displayedEConverted = eConverted
	displayedMConverted = mConverted
end

function widget:DrawScreen()
	gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	if dlistBackground then
		glCallList(dlistBackground)
	end
	if dlistCU then
		glCallList(dlistCU)
	end
	if area[1] then
		local x, y = spGetMouseState()
		if math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
			Spring.SetMouseCursor("cursornormal")
		end
	end
end

function widget:MousePress(x, y, button)
	if area[1] then
		local x, y = spGetMouseState()
		if math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
			return true
		end
	end
end

function widget:Shutdown()
	if dlistGuishader ~= nil then
		if WG["guishader"] then
			WG["guishader"].RemoveDlist("converter_usage")
		end
		glDeleteList(dlistGuishader)
	end
	if dlistCU ~= nil then
		glDeleteList(dlistCU)
	end
	if dlistBackground ~= nil then
		glDeleteList(dlistBackground)
	end
	if WG["tooltip"] then
		WG["tooltip"].RemoveTooltip("converter_usage")
	end
	WG["converter_usage"] = nil
end

function widget:ViewResize()
	vsx, vsy = glGetViewSizes()

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	font2 = WG["fonts"].getFont(2)
	layoutDirty = true
end

function widget:Initialize()
	widget:ViewResize()
	refreshTooltipText()

	WG["converter_usage"] = {}
	WG["converter_usage"].GetPosition = function()
		return area
	end
end

function widget:LanguageChanged()
	refreshTooltipText()
end

function widget:GameFrame()
	gameStarted = true

	local myTeamID = spGetMyTeamID()
	eConverted = spGetTeamRulesParam(myTeamID, "mmUse")
	if eConverted then
		mConverted = eConverted * spGetTeamRulesParam(myTeamID, "mmAvgEffi")
		eConvertedMax = spGetTeamRulesParam(myTeamID, "mmCapacity")
		converterUse = 0

		if eConvertedMax <= 0 then
			return
		end

		converterUse = floor(100 * eConverted / eConvertedMax)
		eConverted = floor(eConverted)
		mConvertedRemainder = mConvertedRemainder + (mConverted - floor(mConverted))
		mConverted = floor(mConverted)
		if mConvertedRemainder >= 1 then
			mConverted = mConverted + 1
			mConvertedRemainder = mConvertedRemainder - 1
		end
	end
end

local sec = 0
function widget:Update(dt)
	if not gameStarted then
		return
	end

	sec = sec + dt
	if sec <= 0.6 then
		return
	end

	sec = 0

	if eConvertedMax and eConvertedMax > 0 then
		updateUI()
		return
	end

	-- Dont draw if there are no converters
	if dlistGuishader ~= nil then
		if WG["guishader"] then
			WG["guishader"].RemoveDlist("converter_usage")
		end
		glDeleteList(dlistGuishader)
		dlistGuishader = nil
	end

	if dlistBackground ~= nil then
		glDeleteList(dlistBackground)
		dlistBackground = nil
		layoutDirty = true
	end

	if dlistCU ~= nil then
		glDeleteList(dlistCU)
		dlistCU = nil
		displayedConverterUse = nil
	end

	if displayedWarningLevel ~= nil and WG["tooltip"] then
		WG["tooltip"].RemoveTooltip("converter_usage")
	end
	displayedWarningLevel = nil
	tooltipDirty = true
end
