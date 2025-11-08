local widget = widget ---@type Widget

function widget:GetInfo()
    return {
      name      = "Converter Usage",
      desc      = "Shows the % of converters that are in use, their energy consumption and metal production",
      author    = "Lexon, Floris",
      date      = "05.08.2022",
	  license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true
    }
  end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.80 + (vsx * vsy / 6000000))

local font2

local RectRound, UiElement
local dlistGuishader, dlistCU
local area = {0,0,0,0}

local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamRulesParam = Spring.GetTeamRulesParam

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glGetViewSizes = gl.GetViewSizes
local glDeleteList = gl.DeleteList

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

local function updateUI()
	if WG['topbar'] then
		local freeArea = WG['topbar'].GetFreeArea()
		widgetScale = freeArea[5]
		area[1] = freeArea[1]
		area[2] = freeArea[2]
		area[3] = freeArea[1] + floor(90 * widgetScale)
		if area[3] > freeArea[3] then
			area[3] = freeArea[3]
		end
		area[4] = freeArea[4]
	end
	if dlistGuishader ~= nil then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('converter_usage')
		end
		glDeleteList(dlistGuishader)
	end
	dlistGuishader = glCreateList(function()
		RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0, 0, 1, 1)
	end)

    local fontSize = (area[4] - area[2]) * 0.4
    local color = "\255\255\255\255"
	local tooltipTitle = Spring.I18N('ui.topbar.converter_usage.defaultTooltipTitle')
	local tooltipText = Spring.I18N('ui.topbar.converter_usage.defaultTooltip')

    if dlistCU ~= nil then
        glDeleteList(dlistCU)
    end
	dlistCU = glCreateList(function()
		UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1)

		if WG['guishader'] then
			WG['guishader'].InsertDlist(dlistGuishader, 'converter_usage')
		end

        --Some coloring and tooltip text
        if converterUse < 20 then
            color = "\255\255\000\000" --Red
            tooltipText = tooltipText .. "\n\n\255\255\100\075"..Spring.I18N('ui.topbar.converter_usage.tooManyConverters1Tooltip').."\n\255\255\100\075"..Spring.I18N('ui.topbar.converter_usage.tooManyConverters2Tooltip')
        elseif converterUse < 40 then
            color = "\255\255\100\000" --Orange
            tooltipText = tooltipText .. "\n\n\255\255\120\050"..Spring.I18N('ui.topbar.converter_usage.tooManyConverters1Tooltip').."\n\255\255\120\050"..Spring.I18N('ui.topbar.converter_usage.tooManyConverters2Tooltip')
        elseif converterUse < 50 then
            color = "\255\255\255\000" --Yellow
        elseif converterUse < 70 then
            color = "\255\215\230\100" --Yelleen?
        else
            color = "\255\000\255\000" --Green
        end

        -- converter use
        font2:Begin()
		font2:Print(color .. converterUse .. "%", area[1] + (fontSize * 0.4), area[2] + ((area[4] - area[2]) / 2.05) - (fontSize / 5), fontSize, 'ol')

        fontSize = fontSize * 0.75

        -- energy used
		font2:Print("\255\255\255\000" .. string.formatSI(-eConverted, formatOptions), area[3] - (fontSize * 0.42), area[2] + 3.2 * ((area[4] - area[2]) / 4) - (fontSize / 5), fontSize, 'or')

        -- metal produced
		font2:Print("\255\240\255\240" .. string.formatSI(mConverted, formatOptions), area[3]  -(fontSize * 0.42), area[2] + 0.8 * ((area[4] - area[2]) / 4) - (fontSize / 5), fontSize, 'or')
		font2:End()

        if WG['tooltip'] ~= nil then
            WG['tooltip'].AddTooltip('converter_usage', area, tooltipText, nil, tooltipTitle)
        end
	end)
end

function widget:DrawScreen()
    if dlistCU and dlistGuishader then
        glCallList(dlistCU)
    end
    if area[1] then
        local x, y = spGetMouseState()
        if math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
            Spring.SetMouseCursor('cursornormal')
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
        if WG['guishader'] then
            WG['guishader'].RemoveDlist('converter_usage')
        end
        glDeleteList(dlistGuishader)
    end
    if dlistCU ~= nil then
        glDeleteList(dlistCU)
    end
	WG['converter_usage'] = nil
end

function widget:ViewResize()
    vsx, vsy = glGetViewSizes()

    RectRound = WG.FlowUI.Draw.RectRound
    UiElement = WG.FlowUI.Draw.Element

    font2 = WG['fonts'].getFont(2)
end

function widget:Initialize()
    widget:ViewResize()

	WG['converter_usage'] = {}
	WG['converter_usage'].GetPosition = function()
		return area
	end
end

function widget:GameFrame()
    gameStarted = true

    local myTeamID = spGetMyTeamID()
    eConverted = spGetTeamRulesParam(myTeamID, "mmUse")
    mConverted = eConverted * spGetTeamRulesParam(myTeamID, "mmAvgEffi")
    eConvertedMax = spGetTeamRulesParam(myTeamID, "mmCapacity")
    converterUse = 0

    if eConvertedMax <= 0 then return end

    converterUse = floor(100 * eConverted / eConvertedMax)
    eConverted = floor(eConverted)
    mConvertedRemainder = mConvertedRemainder + (mConverted - floor(mConverted))
    mConverted = floor(mConverted)
    if mConvertedRemainder >= 1 then
      mConverted = mConverted + 1
      mConvertedRemainder = mConvertedRemainder - 1
    end
end

local sec = 0
function widget:Update(dt)
    if not gameStarted then return end

    sec = sec + dt
    if sec <= 0.6 then return end

    sec = 0

    if eConvertedMax > 0 then
        updateUI()
        return
    end

    -- Dont draw if there are no converters
    if dlistGuishader ~= nil then
        if WG['guishader'] then
            WG['guishader'].RemoveDlist('converter_usage')
        end
        dlistGuishader = glDeleteList(dlistGuishader)
    end

    if dlistCU ~= nil then
        dlistCU = glDeleteList(dlistCU)
    end
end
