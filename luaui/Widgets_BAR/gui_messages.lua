function widget:GetInfo()
    return {
        name      = "Messages",
        desc      = "Typewrites messages at the center-bottom of the screen (missions, tutorials)",
        author    = "Floris",
        date      = "September 2019",
        license   = "GNU GPL, v2 or later",
        layer     = 30000,
        enabled   = true
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Widgets can call: WG['messages'].addMessage('message text')
-- Gadgets (unsynced) can call: Script.LuaUI.GadgetAddMessage('message text')
-- plain text (without markup) via: /addmessage message text

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local showTestMessages = false

local charSize = 17
local charDelay = 0.015
local maxLines = 7
local maxLinesScroll = 10
local lineTTL = 15
local fadeTime = 0.4
local fadeDelay = 0.25   -- need to hover this long in order to fadein and respond to CTRL
local backgroundOpacity = 0.2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 34
local fontfileOutlineSize = 7.5
local fontfileOutlineStrength = 1.7
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (0.5 + (vsx*vsy / 5700000))

local bgcorner = "LuaUI/Images/bgcorner.png"

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glDeleteList     = gl.DeleteList
local glCreateList     = gl.CreateList
local glCallList       = gl.CallList
local glTranslate      = gl.Translate
local glColor          = gl.Color

local messageLines = {}
local activationArea = {0,0,0,0}
local activatedHeight = 0
local currentLine = 0
local currentTypewriterLine = 0
local scrolling = false
local lineMaxWidth = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function lines(str)
    local t = {}
    local function helper(line) t[#t+1] = line return "" end
    helper((str:gsub("(.-)\r?\n", helper)))
    return t
end

local function DrawRectRound(px,py,sx,sy,cs)

    local csx = cs
    local csy = cs
    if sx-px < (cs*2) then
        csx = (sx-px)/2
        if csx < 0 then csx = 0 end
    end
    if sy-py < (cs*2) then
        csy = (sy-py)/2
        if csy < 0 then csy = 0 end
    end
    cs = math.min(csx, csy)

    gl.TexCoord(0.8,0.8)
    gl.Vertex(px+cs, py, 0)
    gl.Vertex(sx-cs, py, 0)
    gl.Vertex(sx-cs, sy, 0)
    gl.Vertex(px+cs, sy, 0)

    gl.Vertex(px, py+cs, 0)
    gl.Vertex(px+cs, py+cs, 0)
    gl.Vertex(px+cs, sy-cs, 0)
    gl.Vertex(px, sy-cs, 0)

    gl.Vertex(sx, py+cs, 0)
    gl.Vertex(sx-cs, py+cs, 0)
    gl.Vertex(sx-cs, sy-cs, 0)
    gl.Vertex(sx, sy-cs, 0)

    local offset = 0.05		-- texture offset, because else gaps could show
    local o = offset

    -- top left
    if py <= 0 or px <= 0 then o = 0.5 else o = offset end
    gl.TexCoord(o,o)
    gl.Vertex(px, py, 0)
    gl.TexCoord(o,1-offset)
    gl.Vertex(px+cs, py, 0)
    gl.TexCoord(1-offset,1-offset)
    gl.Vertex(px+cs, py+cs, 0)
    gl.TexCoord(1-offset,o)
    gl.Vertex(px, py+cs, 0)
    -- top right
    if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
    gl.TexCoord(o,o)
    gl.Vertex(sx, py, 0)
    gl.TexCoord(o,1-offset)
    gl.Vertex(sx-cs, py, 0)
    gl.TexCoord(1-offset,1-offset)
    gl.Vertex(sx-cs, py+cs, 0)
    gl.TexCoord(1-offset,o)
    gl.Vertex(sx, py+cs, 0)
    -- bottom left
    if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
    gl.TexCoord(o,o)
    gl.Vertex(px, sy, 0)
    gl.TexCoord(o,1-offset)
    gl.Vertex(px+cs, sy, 0)
    gl.TexCoord(1-offset,1-offset)
    gl.Vertex(px+cs, sy-cs, 0)
    gl.TexCoord(1-offset,o)
    gl.Vertex(px, sy-cs, 0)
    -- bottom right
    if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
    gl.TexCoord(o,o)
    gl.Vertex(sx, sy, 0)
    gl.TexCoord(o,1-offset)
    gl.Vertex(sx-cs, sy, 0)
    gl.TexCoord(1-offset,1-offset)
    gl.Vertex(sx-cs, sy-cs, 0)
    gl.TexCoord(1-offset,o)
    gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
    local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)

    gl.Texture(bgcorner)
    gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
    gl.Texture(false)
end

function IsOnRect(x, y, leftX, bottomY,rightX,TopY)
    return x >= leftX and x <= rightX and y >= bottomY and y <= TopY
end

function widget:ViewResize()
    vsx,vsy = Spring.GetViewGeometry()
    lineMaxWidth = lineMaxWidth / widgetScale
    widgetScale = (0.5 + (vsx*vsy / 5700000))
    lineMaxWidth = lineMaxWidth * widgetScale

    local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
    if (fontfileScale ~= newFontfileScale) then
        fontfileScale = newFontfileScale
        gl.DeleteFont(font)
        font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
    end

    for i, _ in ipairs(messageLines) do
        if messageLines[i][6] then
            glDeleteList(messageLines[i][6])
            messageLines[i][6] = nil
        end
    end

    activationArea = {
        (vsx * 0.31)-(charSize*widgetScale), (vsy * 0.133)+(charSize*0.15*widgetScale),
        (vsx * 0.6), (vsy * 0.210)
    }
    lineMaxWidth = math.max(lineMaxWidth, activationArea[3] - activationArea[1])
    activatedHeight = (1+maxLinesScroll)*charSize*1.15*widgetScale
end

function addMessage(text)
    if text then

        -- determine text typing start time
        local startTime = os.clock()
        if messageLines[#messageLines] then
            if startTime < messageLines[#messageLines][1] + messageLines[#messageLines][3]*charDelay then
                startTime = messageLines[#messageLines][1] + messageLines[#messageLines][3]*charDelay
            else
                currentTypewriterLine = currentTypewriterLine + 1
            end
        else
            currentTypewriterLine = currentTypewriterLine + 1
        end

        local textLines = lines(text)
        for i, line in ipairs(textLines) do

            lineMaxWidth = math.max(lineMaxWidth, font:GetTextWidth(line)*charSize*widgetScale)
            messageLines[#messageLines+1] = {
                startTime,
                line,
                string.len(line),
                0,  -- num typed chars
                0,  -- time passed during typing chars (used to calc 'num typed chars')
                glCreateList(function() end),
                0   -- num chars the displaylist contains
            }
            startTime = startTime + (string.len(line)*charDelay)
        end

        if currentTypewriterLine > #messageLines then
            currentTypewriterLine = #messageLines
        end
        if not scrolling then
            currentLine = currentTypewriterLine
        end
    end
end

function widget:Initialize()
    widget:ViewResize(vsx,vsy)
    widgetHandler:RegisterGlobal('GadgetAddMessage', addMessage)
    WG['messages'] = {}
    WG['messages'].addMessage = function(text)
        addMessage(text)
    end
end

local sec = 0
local testmessaged = 0
function widget:Update(dt)

    local x,y,b = Spring.GetMouseState()
    if WG['topbar'] and WG['topbar'].showingQuit() then
        scrolling = false
    elseif IsOnRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) then
        local alt, ctrl, meta, shift = Spring.GetModKeyState()
        if ctrl and startFadeTime and os.clock() > startFadeTime+fadeDelay then
            scrolling = true
        else
            --scrolling = false
        end
    elseif scrolling and IsOnRect(x, y, activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight) then

    else
        scrolling = false
        currentLine = #messageLines
    end

    -- delayed test msg
    if showTestMessages and not dataRestored and Spring.GetGameFrame() > 30 then
        sec = sec + dt
        if testmessaged < 1 and sec > 3.5 then
            testmessaged = 1
            addMessage("\nStandby we will keep you updated.\nGood luck!")
        end
        if testmessaged < 2 and sec > 12 then --and Spring.GetGameFrame() < 30*11 then
            testmessaged = 2
            addMessage("\n\nEnemies have been detected in your vicinity!\nBetter expand quick.")
        end
    end

    if messageLines[currentTypewriterLine] ~= nil then
        -- continue typewriting line
        if messageLines[currentTypewriterLine][4] <= messageLines[currentTypewriterLine][3] then
            messageLines[currentTypewriterLine][5] = messageLines[currentTypewriterLine][5] + dt
            messageLines[currentTypewriterLine][4] = math.ceil(messageLines[currentTypewriterLine][5]/charDelay)

            -- typewrite next line when complete
            if messageLines[currentTypewriterLine][4] >= messageLines[currentTypewriterLine][3] then
                currentTypewriterLine = currentTypewriterLine + 1
                if currentTypewriterLine > #messageLines then
                    currentTypewriterLine = #messageLines
                end
            end
        end
    end
end

function processLine(i)
    if messageLines[i][6] == nil or messageLines[i][4] ~= messageLines[i][7] then
        messageLines[i][7] = messageLines[i][4]
        local text = string.sub(messageLines[i][2], 1, messageLines[i][4])
        glDeleteList(messageLines[i][6])
        messageLines[i][6] = glCreateList(function()
            font:Begin()
            lineMaxWidth = math.max(lineMaxWidth, font:GetTextWidth(text)*charSize*widgetScale)
            font:Print(text, 0, 0, charSize*widgetScale, "o")
            font:End()
        end)
    end
end

function widget:DrawScreen()
    local x,y,b = Spring.GetMouseState()
    if IsOnRect(x, y, activationArea[1], activationArea[2], activationArea[3], activationArea[4]) or  (scrolling and IsOnRect(x, y, activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight))  then
        hovering = true
        if not startFadeTime then
            startFadeTime = os.clock()
        end
        if scrolling then
            glColor(0,0,0,backgroundOpacity)
            RectRound(activationArea[1], activationArea[2], activationArea[1]+lineMaxWidth+(charSize*2*widgetScale), activationArea[2]+activatedHeight, 6.5*widgetScale)
        else
            local opacity = ((os.clock() - (startFadeTime+fadeDelay)) / fadeTime) * backgroundOpacity
            if opacity > backgroundOpacity then
                opacity = backgroundOpacity
            end
            glColor(0,0,0,opacity)
            RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[4], 6.5*widgetScale)
        end

    else

        if hovering then
            local opacityPercentage = (os.clock() - (startFadeTime+fadeDelay)) / fadeTime
            startFadeTime = os.clock() - math.max((1-opacityPercentage)*fadeTime, 0)
        end
        hovering = false
        if startFadeTime then
            local opacity = backgroundOpacity - (((os.clock() - startFadeTime) / fadeTime) * backgroundOpacity)
            if opacity > 1 then
                opacity = 1
            end
            if opacity <= 0 then
                startFadeTime = nil
            else
                glColor(0,0,0,opacity)
                RectRound(activationArea[1], activationArea[2], activationArea[3], activationArea[4], 6.5*widgetScale)
            end
        end
        scrolling = false
        currentLine = #messageLines
    end

    if messageLines[currentLine] then
        glPushMatrix()
        glTranslate((vsx * 0.31), (vsy * 0.133), 0)
        local displayedLines = 0
        local i = currentLine
        local usedMaxLines = maxLines
        if scrolling then
            usedMaxLines = maxLinesScroll
        end
        while i > 0 do
            glTranslate(0, (charSize*1.15*widgetScale), 0)
            if scrolling or os.clock() - messageLines[i][1] < lineTTL then
                processLine(i)
                glCallList(messageLines[i][6])
            end
            displayedLines = displayedLines + 1
            if displayedLines >= usedMaxLines then
                break
            end
            i = i - 1
        end
        glPopMatrix()

        -- show newly written line when in scrolling mode
        if scrolling and currentLine < #messageLines and os.clock() - messageLines[currentTypewriterLine][1] < lineTTL then
            glPushMatrix()
            glTranslate((vsx * 0.31), (vsy * 0.11), 0)
            processLine(currentTypewriterLine)
            glCallList(messageLines[currentTypewriterLine][6])
            glPopMatrix()
        end

    end
end

function widget:MouseWheel(up, value)
    if scrolling then
        if up then
            currentLine = currentLine - 1
            if currentLine < maxLinesScroll then
                currentLine = maxLinesScroll
            end
        else
            currentLine = currentLine + 1
            if currentLine > #messageLines then
                currentLine = #messageLines
            end
        end
        return true
    else
        return false
    end
end

function widget:WorldTooltip(ttType,data1,data2,data3)
    local x,y,_ = Spring.GetMouseState()
    if #messageLines > 0 and IsOnRect(x, y, activationArea[1],activationArea[2],activationArea[3],activationArea[4]) then
        return "Press\255\255\255\001 CTRL \255\255\255\255to activate chatlog viewing/scrolling"
    end
end

function widget:GameStart()
    if showTestMessages then
        addMessage("\255\230\255\200Commander,\nWe're in a peculiar situation so you have to begin on your own...\nInitiate a base and we'll redirect reinforcements right after...")
    end
end

function widget:GameOver()
    --widgetHandler:RemoveWidget(self)
end

function widget:Shutdown()
    WG['messages'] = nil
    gl.DeleteFont(font)
    for i, _ in ipairs(messageLines) do
        if messageLines[i][6] then
            glDeleteList(messageLines[i][6])
            messageLines[i][6] = nil
        end
    end
end

function widget:TextCommand(command)
    if string.sub(command,1, 11) == "addmessage " then
        addMessage(string.sub(command, 11))
    end
end

function widget:GetConfigData(data)
    for i, _ in ipairs(messageLines) do
        messageLines[i][6] = nil
    end
    savedTable = {}
    savedTable.messageLines = messageLines
    return savedTable
end

function widget:SetConfigData(data)
    if Spring.GetGameFrame() > 0 and data.messageLines ~= nil then
        messageLines = data.messageLines
        currentLine = #messageLines
        currentTypewriterLine = currentLine
        dataRestored = true
    end
end